import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../config/test_credentials.dart';
import '../helpers_v2/cleanup_helper.dart';
import '../helpers_v2/composer_depth_helper.dart';
import '../helpers_v2/pump_helper.dart';
import '../sdk_user_b/composer_depth_actions.dart';

/// Mentions in a 1:1 chat — E2E suite (iOS parity, STRICT).
///
///   E2E-114  Typing "@" opens the suggestion list (with at least one row)
///   E2E-115  Typing after "@" filters the rows down to the keyword
///   E2E-116  Picking a row inserts "@Name " and the message goes out as
///            `<@uid:UID> …`, rendered back as a highlighted "@Name" chip
///   E2E-117  Deleting the "@" closes the list; retyping "@" reopens it
///   E2E-118  Two different users mentioned in one message both go out as
///            `<@uid:…>` tokens and both render as chips
///   E2E-119  An incoming `<@uid:A>` mention renders as a highlighted
///            `@<A's name>` chip, never as the raw token
///   E2E-120  A keyword that matches nobody closes the suggestion list
///
/// THE TRAP THIS SUITE IS BUILT AROUND (found by the iOS audit of their own
/// tests): User B's name is ALWAYS on screen in the chat header, so "the name
/// is visible" proves nothing about suggestions. Every suggestion assertion
/// here is scoped to the suggestion-list widget itself —
/// message_composer_suggestion_list.dart wraps it in
/// `Semantics(label: 'Suggestion list with N items')` and each row in
/// `Semantics(label: item.title, button: true)` — and each test first asserts
/// the list is ABSENT before "@" is typed.
///
/// Source facts:
///   * cometchat_mentions_formatter.dart `init`: with no group the formatter
///     uses a plain `UsersRequestBuilder` (limit 10, `searchKeyword` = text
///     after "@"), so in a 1:1 chat the list offers app users, not just the
///     peer. There is no "@all" row outside groups.
///   * `_onChange` is keystroke-driven, so tests type character by character.
///   * Row tap inserts `"@${user.name} "`; `handlePreMessageSend` rewrites it
///     to `"<@uid:${user.uid}>"` on send.
///   * Zero results on a first fetch → `onSearch(null)` → the composer hides
///     the panel (`_onFormatterSearch`).
///   * Bubble side (`getAttributedText` + formatter_utils.dart): a resolved
///     mention is a `WidgetSpan` → `Container(background)` → `Text("@Name")`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final bUid = TestCredentials.userBUid;
  final bName = TestCredentials.userBName;
  final bFirst = bName.split(' ').first;
  final aUid = TestCredentials.userAUid;
  final aName = TestCredentials.userAName;

  setUp(() async {
    await CleanupHelper.fullReset();
    await CleanupHelper.seedConversation();
    await Future<void>.delayed(const Duration(seconds: 1));
  });

  tearDown(() async {
    await CleanupHelper.fullReset();
  });

  /// Open the chat, focus the composer, and prove no suggestion list exists
  /// yet — so a later "list is present" can only be caused by typing "@".
  Future<void> openWithNoSuggestions(WidgetTester tester) async {
    await ComposerDepthHelper.launchIntoChatWithB(tester);
    await ComposerDepthHelper.focusComposer(tester);
    expect(
      ComposerDepthHelper.suggestionList(),
      findsNothing,
      reason:
          'Precondition: no suggestion list before "@" is typed '
          '(the header showing "$bName" must not count)',
    );
  }

  /// Type "@" + the first letters of B's first name and pick B's row.
  Future<void> mentionUserB(WidgetTester tester) async {
    final prefix = bFirst.length > 3 ? bFirst.substring(0, 3) : bFirst;
    await ComposerDepthHelper.typeChars(tester, '@$prefix');
    await ComposerDepthHelper.tapSuggestion(tester, bName);
  }

  Future<String> sendAndReadPayload(WidgetTester tester, String token) async {
    await ComposerDepthHelper.tapSend(tester);
    await ComposerDepthHelper.waitForInList(tester, token);
    final sent = await ComposerDepthActions.waitForMessageFromA(token);
    if (sent == null) {
      fail('No message from User A containing "$token" reached the server');
    }
    return ComposerDepthActions.textOf(sent);
  }

  group('Mentions 1:1: suggestion list', () {
    testWidgets('E2E-114: Typing @ shows the suggestion list', (tester) async {
      await openWithNoSuggestions(tester);

      await ComposerDepthHelper.typeChars(tester, '@');
      await ComposerDepthHelper.waitForSuggestions(tester);

      expect(
        ComposerDepthHelper.suggestionList(),
        findsOneWidget,
        reason: 'Typing "@" must open exactly one suggestion list',
      );
      expect(
        ComposerDepthHelper.suggestionTitles(tester),
        isNotEmpty,
        reason: 'The suggestion list must contain at least one user row',
      );
    });

    testWidgets('E2E-115: Suggestions filter while typing', (tester) async {
      await openWithNoSuggestions(tester);

      await ComposerDepthHelper.typeChars(tester, '@');
      await ComposerDepthHelper.waitForSuggestions(tester);
      final keyword = bFirst.toLowerCase();
      final nonMatching = ComposerDepthHelper.suggestionTitles(
        tester,
      ).where((t) => !t.toLowerCase().contains(keyword)).toSet();
      if (nonMatching.isEmpty) {
        markTestSkipped(
          'Every unfiltered suggestion already matches '
          '"$bFirst" — this app has no second user to filter out',
        );
        return;
      }

      await ComposerDepthHelper.typeChars(tester, bFirst);
      await ComposerDepthHelper.waitForSuggestionRow(tester, bName);

      // The rows that did not match must drop out once the search returns.
      final end = DateTime.now().add(const Duration(seconds: 10));
      Set<String> leftovers() => ComposerDepthHelper.suggestionTitles(
        tester,
      ).toSet().intersection(nonMatching);
      while (leftovers().isNotEmpty && DateTime.now().isBefore(end)) {
        await pumpFor(tester, const Duration(milliseconds: 400));
      }

      expect(
        leftovers(),
        isEmpty,
        reason:
            'After typing "@$bFirst" the list must no longer offer '
            'users that do not match (still listed: ${leftovers()})',
      );
    });

    testWidgets('E2E-117: Deleting and retyping @ reopens suggestions', (
      tester,
    ) async {
      await openWithNoSuggestions(tester);

      await ComposerDepthHelper.typeChars(tester, '@');
      await ComposerDepthHelper.waitForSuggestions(tester);

      // Backspace over the "@".
      await ComposerDepthHelper.setComposerText(tester, '');
      final closed = await pumpUntilGone(
        tester,
        ComposerDepthHelper.suggestionList(),
      );
      if (!closed) {
        fail('Deleting the "@" did not close the suggestion list');
      }

      await ComposerDepthHelper.typeChars(tester, '@');
      await ComposerDepthHelper.waitForSuggestions(tester);

      expect(
        ComposerDepthHelper.suggestionTitles(tester),
        isNotEmpty,
        reason:
            'Retyping "@" after deleting it must reopen the list with '
            'user rows',
      );
    });

    testWidgets('E2E-120: Suggestions close when no user matches', (
      tester,
    ) async {
      await openWithNoSuggestions(tester);

      await ComposerDepthHelper.typeChars(tester, '@');
      await ComposerDepthHelper.waitForSuggestions(tester);

      // Letters-only gibberish that no user name or uid contains.
      await ComposerDepthHelper.typeChars(tester, 'zqxjkvwzqx');
      final closed = await pumpUntilGone(
        tester,
        ComposerDepthHelper.suggestionList(),
        timeout: const Duration(seconds: 15),
      );

      expect(
        closed,
        isTrue,
        reason:
            'A keyword matching nobody must close the suggestion list '
            '(still listed: ${ComposerDepthHelper.suggestionTitles(tester)})',
      );
    });
  });

  group('Mentions 1:1: sending and rendering', () {
    testWidgets(
      'E2E-116: Selecting a suggestion inserts the mention and sends',
      (tester) async {
        await openWithNoSuggestions(tester);
        final tok = ComposerDepthHelper.token('mention');

        await mentionUserB(tester);
        expect(
          ComposerDepthHelper.composerText(tester),
          '@$bName ',
          reason: 'Picking the row must replace "@…" with "@$bName "',
        );
        expect(
          ComposerDepthHelper.suggestionList(),
          findsNothing,
          reason: 'The list must close once a suggestion is picked',
        );

        await ComposerDepthHelper.typeChars(tester, tok);
        final payload = await sendAndReadPayload(tester, tok);

        expect(
          payload,
          '<@uid:$bUid> $tok',
          reason: 'The mention must go out as the <@uid:…> token',
        );
        final chip = ComposerDepthHelper.mentionChipBackground(
          tester,
          '@$bName',
        );
        expect(
          chip,
          isNotNull,
          reason: 'The sent bubble must show the mention as "@$bName"',
        );
        expect(
          chip!.a,
          greaterThan(0),
          reason: 'The mention chip must be highlighted (non-transparent)',
        );
        expect(
          ComposerDepthHelper.listShows(tester, '<@uid:'),
          isFalse,
          reason: 'The raw <@uid:…> token must not be visible',
        );
      },
    );

    testWidgets('E2E-118: Multiple mentions in one message', (tester) async {
      await openWithNoSuggestions(tester);
      final tok = ComposerDepthHelper.token('twomentions');

      await mentionUserB(tester);

      await ComposerDepthHelper.typeChars(tester, '@');
      await ComposerDepthHelper.waitForSuggestions(tester);
      final other = ComposerDepthHelper.suggestionTitles(tester).firstWhere(
        (t) => t != bName && t != 'Suggestion item',
        orElse: () => '',
      );
      if (other.isEmpty) {
        markTestSkipped(
          'No second mentionable user besides "$bName" in this '
          'app — cannot build a two-user mention',
        );
        return;
      }
      await ComposerDepthHelper.tapSuggestion(tester, other);
      expect(
        ComposerDepthHelper.composerText(tester),
        '@$bName @$other ',
        reason: 'Both picked mentions must be in the composer',
      );

      await ComposerDepthHelper.typeChars(tester, tok);
      final payload = await sendAndReadPayload(tester, tok);

      final match = RegExp(
        '^<@uid:${RegExp.escape(bUid)}> <@uid:([^>]+)> ${RegExp.escape(tok)}\$',
      ).firstMatch(payload);
      if (match == null) {
        fail(
          'Expected "<@uid:$bUid> <@uid:OTHER> $tok" but the payload was '
          '"$payload"',
        );
      }
      expect(
        match.group(1),
        isNot(bUid),
        reason: 'The second token must be a different user than the first',
      );
      expect(
        ComposerDepthHelper.mentionChipBackground(tester, '@$bName'),
        isNotNull,
        reason: 'First mention must render as "@$bName"',
      );
      expect(
        ComposerDepthHelper.mentionChipBackground(tester, '@$other'),
        isNotNull,
        reason: 'Second mention must render as "@$other"',
      );
    });

    testWidgets('E2E-119: Incoming mention renders highlighted display name', (
      tester,
    ) async {
      await ComposerDepthHelper.launchIntoChatWithB(tester);
      final tok = ComposerDepthHelper.token('incoming');

      // "<@uid:A> tok" — the same wire syntax the Kit emits.
      await ComposerDepthActions.sendMentionOfAToA(tok);
      await ComposerDepthHelper.waitForInList(tester, tok);

      final chip = ComposerDepthHelper.mentionChipBackground(tester, '@$aName');
      expect(
        chip,
        isNotNull,
        reason: 'The incoming <@uid:$aUid> must render as "@$aName"',
      );
      expect(
        chip!.a,
        greaterThan(0),
        reason: 'The mention chip must be highlighted (non-transparent)',
      );
      expect(
        ComposerDepthHelper.listShows(tester, '<@uid:'),
        isFalse,
        reason: 'The raw <@uid:…> token must not be visible',
      );
    });
  });
}
