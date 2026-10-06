import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../config/test_credentials.dart';
import '../helpers_v2/app_launcher.dart';
import '../helpers_v2/assertion_helper.dart';
import '../helpers_v2/cleanup_helper.dart';
import '../helpers_v2/navigation_helper.dart';
import '../helpers_v2/pump_helper.dart';
import '../helpers_v2/search_polls_media_helper.dart';
import '../sdk_user_b/messaging_actions.dart';

/// Polls extension (iOS parity), STRICT.
///
///   E2E-143  Poll option is offered in the attachment sheet
///            → the composer "+" popup contains a "Poll" row.
///   E2E-144  Create-poll form opens with a question and two option fields
///            → `CometChatCreatePoll` shows the "Ask Question" field and
///              exactly two "Add" option fields.
///   E2E-145  Cannot submit with an empty question
///            → the validation banner appears and the form stays open.
///   E2E-146  Cannot submit with fewer than two options
///            → the validation banner appears and the form stays open.
///   E2E-147  Add option / remove option works
///            → "+ Add Option" makes three fields; emptying the third makes two.
///   E2E-148  Creating a poll posts a poll bubble with the question and options
///            → a `CometChatPollsBubble` with that question + options renders,
///              AND the server holds an `extension_poll` message from A with
///              the same question.
///   E2E-149  Voting on an option updates its count
///            → that option's `voteCount` becomes 1 and lists User A as voter.
///   E2E-150  A poll message sent by User B renders a poll bubble in A's chat
///            → a `CometChatPollsBubble` with B's question + options renders.
///
/// Where things come from (chat_uikit/lib):
///   * composer_attachment_utils.dart `getAttachmentOptions` appends
///     `pollsOption` (title `Translations.poll` = "Poll") LAST, unless
///     `hidePollsOption` is set. master_app's `_buildComposer` does not set it.
///     NOTE: the Kit does NOT gate this on the extension being enabled.
///   * cometchat_message_composer.dart `_handleCreatePoll` →
///     `showCometChatCreatePoll` (modal bottom sheet) → `CometChatCreatePoll`.
///   * cometchat_create_poll.dart: title "Create Poll"; question
///     `TextFormField` hint `Translations.askQuestion` = "Ask Question"; option
///     `TextFormField`s (hint `Translations.add` = "Add") inside a
///     `ReorderableListView`; "+ Add Option" adds one (max 12); there is no
///     remove button — an option is removed by EMPTYING its text while three
///     or more exist (`_removeEmptyOptions`); "Create" `ElevatedButton`;
///     validation banner `Translations.pollEmptyString`.
///   * message_template_utils.dart `getPollMessageTemplate` →
///     `CometChatPollsBubble(pollQuestion:, options:)`; a tap on an option
///     calls the extension's `/v2/vote`.
///
/// Extension availability. Creating and voting need the server-side "polls"
/// extension. It is probed explicitly with `CometChat.isExtensionEnabled`
/// after login; when it is off, E2E-143…149 call
/// `markTestSkipped('polls extension disabled on the test app')` — a visible
/// skip, never a pass. When it is on, a missing "Poll" row is a FAILURE.
///
/// E2E-150 does not go through the extension, so it always runs. The
/// extension's REST contract is not in this repo: the SDK builds
/// `https://polls-<region>.<extensionDomain>/v2/create` from runtime settings
/// (`extensionDomain`, `chatApiVersion`) and authenticates with the logged-in
/// user's auth token, none of which the REST harness has. Instead User B sends
/// the wire shape a poll has — a custom message of type `extension_poll` with
/// `customData {question, options}` — which `getPollMessageTemplate` renders
/// through its documented "no vote data yet" fallback. That proves the bubble
/// renders an incoming poll; it cannot prove cross-user vote sync.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const skipReason = 'polls extension disabled on the test app';
  // cometchat_create_poll.dart / translations_en.dart `pollEmptyString`.
  const validationMessage =
      'Please fill in all required fields before creating a poll.';

  final run = DateTime.now().millisecondsSinceEpoch;

  setUpAll(() async {
    await CleanupHelper.fullReset();
    await CleanupHelper.seedConversation(text: 'SeedForPolls');
    await Future<void>.delayed(const Duration(seconds: 1));
  });

  tearDownAll(() async {
    // Polls are messages in the shared A↔B conversation; clear them.
    await CleanupHelper.fullReset();
  });

  // ─── Finders ───────────────────────────────────────────────────────────────

  final form = find.byType(CometChatCreatePoll);

  Finder inForm(Finder matching) =>
      find.descendant(of: form, matching: matching);

  // `_buildQuestionInput` — hintText: Translations.askQuestion.
  Finder questionField() =>
      inForm(KitFinders.textFieldWithHint('Ask Question'));

  // `getTextKey` — option fields live in the ReorderableListView, hint "Add".
  Finder optionFields() => find.descendant(
    of: inForm(find.byType(ReorderableListView)),
    matching: KitFinders.textFieldWithHint('Add'),
  );

  // Submit — `ElevatedButton` whose child is Text(Translations.create).
  Finder createButton() =>
      inForm(find.widgetWithText(ElevatedButton, 'Create'));

  Finder validationBanner() => inForm(find.text(validationMessage));

  /// The poll bubble showing [question].
  Finder pollBubble(String question) => find.byWidgetPredicate(
    (w) => w is CometChatPollsBubble && w.pollQuestion == question,
    skipOffstage: false,
  );

  // ─── Flows ─────────────────────────────────────────────────────────────────

  bool? pollsEnabled;

  /// Launch, open B's chat, and report whether the polls extension is on.
  /// Returns false after calling `markTestSkipped` — callers must `return`.
  Future<bool> openChatOrSkip(WidgetTester tester) async {
    await AppLauncher.launchAndLogin(tester);
    pollsEnabled ??= await SdkProbe.isExtensionEnabled(
      ExtensionConstants.polls,
    );
    if (pollsEnabled != true) {
      markTestSkipped(skipReason);
      return false;
    }
    await NavigationHelper.openUserBConversation(tester);
    AssertionHelper.expectOnMessagesScreen();
    return true;
  }

  /// "+" → "Poll" → wait for the create-poll sheet.
  Future<void> openCreatePollForm(WidgetTester tester) async {
    await KitFinders.openAttachmentOverlay(tester);
    final pollRow = KitFinders.attachmentOption('Poll');
    expect(
      pollRow,
      findsOneWidget,
      reason: 'attachment popup must offer "Poll" when the extension is on',
    );
    await tester.ensureVisible(pollRow);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(pollRow);

    final opened = await pumpUntilFound(
      tester,
      form,
      timeout: const Duration(seconds: 8),
    );
    expect(
      opened,
      isTrue,
      reason: 'tapping "Poll" must open the CometChatCreatePoll sheet',
    );
    await pumpFor(tester, const Duration(seconds: 1)); // sheet slide-in
  }

  Future<void> fillQuestion(WidgetTester tester, String question) async {
    await tester.enterText(questionField(), question);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> fillOption(WidgetTester tester, int index, String text) async {
    await tester.enterText(optionFields().at(index), text);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> tapCreate(WidgetTester tester) async {
    await KitFinders.dropFocus(tester);
    await tester.ensureVisible(createButton());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(createButton());
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Create a poll through the UI and wait for its bubble.
  Future<void> createPollViaUi(
    WidgetTester tester, {
    required String question,
    required List<String> options,
  }) async {
    await openCreatePollForm(tester);
    await fillQuestion(tester, question);
    for (var i = 0; i < options.length; i++) {
      await fillOption(tester, i, options[i]);
    }
    await tapCreate(tester);

    // `createPoll` pops the sheet on success and shows
    // Translations.somethingWrong on failure.
    final closed = await pumpUntilGone(
      tester,
      form,
      timeout: const Duration(seconds: 20),
    );
    expect(
      closed,
      isTrue,
      reason: 'a valid poll must be accepted and close the create sheet',
    );

    final rendered = await pumpUntilFound(
      tester,
      pollBubble(question),
      timeout: const Duration(seconds: 25),
    );
    expect(
      rendered,
      isTrue,
      reason: 'the created poll "$question" must appear as a poll bubble',
    );
  }

  group('Polls: create form', () {
    testWidgets('E2E-143: Poll option is offered in the attachment sheet', (
      tester,
    ) async {
      if (!await openChatOrSkip(tester)) return;

      await KitFinders.openAttachmentOverlay(tester);
      expect(
        KitFinders.attachmentOption('Poll'),
        findsOneWidget,
        reason:
            'with the polls extension enabled, the attachment popup '
            'must contain a "Poll" row',
      );
    });

    testWidgets(
      'E2E-144: Create-poll form opens with a question and two option fields',
      (tester) async {
        if (!await openChatOrSkip(tester)) return;
        await openCreatePollForm(tester);

        expect(
          questionField(),
          findsOneWidget,
          reason: 'the form must have one "Ask Question" field',
        );
        // CometChatCreatePoll.defaultAnswers == 2.
        expect(
          optionFields(),
          findsNWidgets(2),
          reason: 'the form must start with exactly two option fields',
        );
      },
    );

    testWidgets('E2E-145: Cannot submit a poll with an empty question', (
      tester,
    ) async {
      if (!await openChatOrSkip(tester)) return;
      await openCreatePollForm(tester);

      await fillOption(tester, 0, 'Alpha');
      await fillOption(tester, 1, 'Beta');
      expect(
        validationBanner(),
        findsNothing,
        reason: 'precondition: no validation banner before submitting',
      );
      await tapCreate(tester);

      final shown = await pumpUntilFound(
        tester,
        validationBanner(),
        timeout: const Duration(seconds: 5),
      );
      expect(
        shown,
        isTrue,
        reason:
            'submitting without a question must show the validation '
            'banner',
      );
      expect(
        form,
        findsOneWidget,
        reason: 'an invalid poll must not close the create sheet',
      );
    });

    testWidgets('E2E-146: Cannot submit a poll with fewer than two options', (
      tester,
    ) async {
      if (!await openChatOrSkip(tester)) return;
      await openCreatePollForm(tester);

      await fillQuestion(tester, 'Only one option $run');
      await fillOption(tester, 0, 'Lonely');
      expect(
        validationBanner(),
        findsNothing,
        reason: 'precondition: no validation banner before submitting',
      );
      await tapCreate(tester);

      final shown = await pumpUntilFound(
        tester,
        validationBanner(),
        timeout: const Duration(seconds: 5),
      );
      expect(
        shown,
        isTrue,
        reason: 'submitting with one option must show the validation banner',
      );
      expect(
        form,
        findsOneWidget,
        reason: 'an invalid poll must not close the create sheet',
      );
    });

    testWidgets('E2E-147: Add option and remove option work', (tester) async {
      if (!await openChatOrSkip(tester)) return;
      await openCreatePollForm(tester);
      expect(
        optionFields(),
        findsNWidgets(2),
        reason: 'precondition: the form starts with two option fields',
      );

      // "+ Add Option" — Text("+ ${Translations.addOption}").
      final addOption = inForm(find.text('+ Add Option'));
      expect(
        addOption,
        findsOneWidget,
        reason: 'the form must offer "+ Add Option"',
      );
      await tester.ensureVisible(addOption);
      await tester.tap(addOption);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        optionFields(),
        findsNWidgets(3),
        reason: '"+ Add Option" must add a third option field',
      );

      // Removal has no button: emptying an option while ≥3 exist removes it
      // (`onChanged` → `_removeEmptyOptions`). enterText('') on an
      // already-empty field fires no change, so type first, then clear.
      await fillOption(tester, 2, 'Temporary');
      await fillOption(tester, 2, '');
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        optionFields(),
        findsNWidgets(2),
        reason: 'emptying the third option must remove its field',
      );
    });
  });

  group('Polls: create and vote', () {
    testWidgets(
      'E2E-148: Creating a poll posts a poll bubble with the question '
      'and options',
      (tester) async {
        if (!await openChatOrSkip(tester)) return;

        final question = 'Which colour wins $run';
        final options = ['Crimson $run', 'Indigo $run'];
        await createPollViaUi(tester, question: question, options: options);

        final bubble = tester.widget<CometChatPollsBubble>(
          pollBubble(question).first,
        );
        expect(
          bubble.options?.map((o) => o.optionText).toList(),
          options,
          reason: 'the poll bubble must list exactly the options entered',
        );

        // What actually went out: the extension posts a custom message of type
        // `extension_poll` whose customData carries the question + options.
        final sent = await SdkProbe.waitForCustomMessageFromA(
          type: ExtensionType.extensionPoll,
          where: (m) => m.customData?['question'] == question,
        );
        final sentOptions = sent.customData?['options'];
        final sentTexts = sentOptions is Map
            ? sentOptions.values.map((v) => v.toString()).toList()
            : (sentOptions as List).map((v) => v.toString()).toList();
        expect(
          sentTexts,
          containsAll(options),
          reason: 'the server-side poll message must carry both options',
        );
      },
    );

    testWidgets('E2E-149: Voting on an option updates its vote count', (
      tester,
    ) async {
      if (!await openChatOrSkip(tester)) return;

      final question = 'Vote on this $run';
      final chosen = 'Yes $run';
      final other = 'No $run';
      await createPollViaUi(
        tester,
        question: question,
        options: [chosen, other],
      );

      // Re-read the bubble widget every time: a vote arrives as an edited
      // message, which rebuilds the bubble with fresh PollOptions.
      PollOptions optionNamed(String text) {
        final bubbles = pollBubble(question).evaluate();
        if (bubbles.isEmpty) fail('poll bubble "$question" left the tree');
        return (bubbles.first.widget as CometChatPollsBubble).options!
            .firstWhere((o) => o.optionText == text);
      }

      expect(
        optionNamed(chosen).voteCount,
        0,
        reason: 'precondition: a fresh poll has no votes',
      );

      // cometchat_polls_bubble.dart `_buildRadio` — the whole option row is a
      // GestureDetector; its label is Text(optionText).
      final optionLabel = find.descendant(
        of: pollBubble(question),
        matching: find.text(chosen),
      );
      expect(optionLabel, findsOneWidget);
      await tester.ensureVisible(optionLabel);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(optionLabel);

      // The vote round-trips through the extension and comes back as an
      // edited message carrying @injected.extensions.polls.results.
      final end = DateTime.now().add(const Duration(seconds: 25));
      while (DateTime.now().isBefore(end) &&
          optionNamed(chosen).voteCount != 1) {
        await pumpFor(tester, const Duration(milliseconds: 500));
      }

      expect(
        optionNamed(chosen).voteCount,
        1,
        reason: 'voting for "$chosen" must raise its count to 1',
      );
      expect(
        optionNamed(chosen).votersUid,
        contains(TestCredentials.userAUid),
        reason: 'User A must be listed as a voter of the chosen option',
      );
      expect(
        optionNamed(other).voteCount,
        0,
        reason: 'the option that was not chosen must stay at 0',
      );
    });
  });

  group('Polls: incoming', () {
    testWidgets(
      'E2E-150: A poll message sent by User B renders a poll bubble in '
      "A's chat",
      (tester) async {
        // Deliberately NOT gated on the extension: see the suite header.
        final question = 'Poll from B $run';
        final options = ['Tea $run', 'Coffee $run'];
        await UserBMessaging.sendCustomMessageToA(
          subType: ExtensionType.extensionPoll,
          customData: {'question': question, 'options': options},
        );

        await AppLauncher.launchAndLogin(tester);
        await NavigationHelper.openUserBConversation(tester);
        AssertionHelper.expectOnMessagesScreen();

        final rendered = await pumpUntilFound(
          tester,
          pollBubble(question),
          timeout: const Duration(seconds: 25),
        );
        expect(
          rendered,
          isTrue,
          reason: "B's poll must render as a CometChatPollsBubble for A",
        );

        final bubble = tester.widget<CometChatPollsBubble>(
          pollBubble(question).first,
        );
        expect(
          bubble.options?.map((o) => o.optionText).toList(),
          options,
          reason: "the bubble must list B's options in order",
        );
        expect(
          bubble.senderUid,
          TestCredentials.userBUid,
          reason: 'the bubble must be attributed to User B',
        );
      },
    );
  });
}
