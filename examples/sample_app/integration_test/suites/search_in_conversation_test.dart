import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sample_app/screens/messages_screen.dart';
import 'package:sample_app/screens/threads_screen.dart' show InboxSearchBar;

import '../config/test_credentials.dart';
import '../helpers_v2/app_launcher.dart';
import '../helpers_v2/assertion_helper.dart';
import '../helpers_v2/cleanup_helper.dart';
import '../helpers_v2/navigation_helper.dart';
import '../helpers_v2/pump_helper.dart';
import '../helpers_v2/search_polls_media_helper.dart';
import '../sdk_user_b/messaging_actions.dart';

/// CometChatSearch — message search (iOS parity), STRICT.
///
/// `search_test.dart` (E2E-053…056) covers name filtering of the Users/Groups
/// lists with tolerant assertions. This suite drives the dedicated
/// `CometChatSearch` screen and asserts one specific outcome per test.
///
///   E2E-130  Search screen opens from the Chats tab search bar
///            → `CometChatSearch` is mounted with the "Search" field.
///   E2E-131  Typing in the search box shows the typed text
///            → the field's controller AND its rendered EditableText hold it.
///   E2E-132  Matching results are displayed for a seeded keyword
///            → a "Message from …" result row carrying the keyword appears.
///   E2E-133  No-results state for a random string
///            → "No records found" is shown and there are zero result rows.
///   E2E-134  Search is case-insensitive
///            → the UPPER-CASED keyword still returns the seeded row.
///   E2E-135  Clear button resets the field and the results
///            → text is empty, rows are gone, the clear button is gone.
///   E2E-136  A result shows the correct message content
///            → the row's preview text equals the seeded message, verbatim.
///   E2E-137  The keyword is present in the result row
///            → every result row on screen contains the keyword.
///   E2E-138  A result shows sender context
///            → the row is titled with User B's name (Semantics + Text).
///   E2E-139  Photos filter shows a seeded image and hides text-only results
///            → in-conversation search, "Photos" chip: the seeded image
///              thumbnail is listed, the seeded text message is not.
///   E2E-140  An emoji message is findable
///            → the result row renders the message with its emoji intact.
///   E2E-141  Spaces-only input is treated as empty
///            → no clear button, no loading, no empty state, no result list.
///   E2E-142  Tapping a result opens the conversation at that message
///            → `MessagesScreen(goToMessageId: <seeded id>)` is pushed and the
///              message is rendered.
///
/// How the app reaches the screen (master_app/lib):
///   * Global — home_screen.dart `_buildConversationsTab` puts an
///     `InboxSearchBar` above the list; its tap runs `_openSearch`, which
///     pushes `CometChatSearch` (scope: conversations + messages). A message
///     tap resolves the peer and pushes `MessagesScreen(goToMessageId: id)`.
///   * In-conversation — messages_screen.dart passes `onSearchTap` to
///     `CometChatMessageHeader`, which adds a "Search" entry to the header's
///     ⋯ (`Icons.more_vert`) `MenuAnchor`; `_openSearchScreen` pushes
///     `CometChatSearch(user:, searchIn: [SearchScope.messages])`.
///
/// What the screen is made of (chat_uikit/lib/chat_ui/src/search):
///   * one `TextField` (hint `Translations.search` = "Search", or
///     `Search in NAME` when scoped), back arrow as prefix, and an
///     `Icons.close` clear button that exists only while the bloc's TRIMMED
///     search text is non-empty;
///   * `SearchFilterChip`s — labels are hardcoded English in
///     `SearchBloc.defaultFilters`: Unread, Groups, Photos, Videos, Audio,
///     Documents, Links;
///   * results: each message row is `Semantics(label: 'Message from <title>')`
///     → title `Text` + `MessagePreviewSubtitle` (a `RichText` for text
///     messages); image rows get a `CometChatImageBubble` thumbnail;
///   * empty state: `Translations.noRecordsFound` = "No records found".
///
/// Seeding: `setUpAll` resets the A↔B conversation, then User B sends (REST) a
/// text message, an emoji message and an image, all tagged with a per-run
/// letters-only token (no digits/underscores, so neither the markdown
/// formatter nor a server tokenizer can split it).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ─── Per-run seed data ─────────────────────────────────────────────────────

  /// Milliseconds-since-epoch spelled with letters a…j → unique, letters only.
  final runLetters = DateTime.now().millisecondsSinceEpoch
      .toString()
      .split('')
      .map((d) => String.fromCharCode('a'.codeUnitAt(0) + int.parse(d)))
      .join();

  final keyword = 'Quokka$runLetters';
  final seededText = 'Parity check $keyword landed safely';
  final emojiKeyword = 'Fiesta$runLetters';
  final seededEmojiText = '$emojiKeyword 🎉🦄';
  final seededImageUrl =
      'https://data-us.cometchat.io/assets/images/avatars/ironman.png'
      '?e2e=$runLetters';

  late int seededTextId;

  setUpAll(() async {
    await CleanupHelper.fullReset();
    seededTextId = await UserBMessaging.sendTextToA(seededText);
    await UserBMessaging.sendTextToA(seededEmojiText);
    await UserBMessaging.sendMediaToA(
      type: 'image',
      url: seededImageUrl,
      mimeType: 'image/png',
      name: 'searchimage$runLetters.png',
      extension: 'png',
    );
    // Give the server-side search index a moment before the first query.
    await Future<void>.delayed(const Duration(seconds: 5));
  });

  tearDownAll(() async {
    await CleanupHelper.fullReset();
  });

  // ─── Finders (all scoped to the mounted CometChatSearch) ───────────────────

  final searchScreen = find.byType(CometChatSearch);

  Finder inSearch(Finder matching) =>
      find.descendant(of: searchScreen, matching: matching);

  // cometchat_search.dart `_buildSearchBar` — the only TextField on the screen.
  Finder searchField() => inSearch(find.byType(TextField));

  // cometchat_search.dart `_buildSearchBar` suffixIcon — Icons.close, built
  // only while `state.searchText.isNotEmpty`.
  Finder clearButton() => inSearch(find.byIcon(Icons.close));

  // cometchat_search.dart `_buildSearchItem` —
  // `Semantics(button: true, label: 'Message from $title')`.
  Finder resultRows() => inSearch(
    KitFinders.semanticsLabelStartsWith('Message from ', skipOffstage: false),
  );

  /// Result rows whose rendered text contains [text].
  Finder resultRowsContaining(String text) => find.ancestor(
    of: inSearch(KitFinders.richTextContaining(text, skipOffstage: false)),
    matching: resultRows(),
  );

  // cometchat_search.dart `_buildEmptyView` — Translations.noRecordsFound.
  Finder emptyState() => inSearch(find.text('No records found'));

  // ─── Flows ─────────────────────────────────────────────────────────────────

  /// Chats tab → tap the inbox search bar → CometChatSearch (global scope).
  Future<void> openGlobalSearch(WidgetTester tester) async {
    await AppLauncher.launchAndLogin(tester);
    AssertionHelper.expectOnHomeScreen();

    // home_screen.dart `_buildConversationsTab` → InboxSearchBar(onTap: …).
    final bar = find.byType(InboxSearchBar);
    final barShown = await pumpUntilFound(
      tester,
      bar,
      timeout: const Duration(seconds: 10),
    );
    expect(
      barShown,
      isTrue,
      reason: 'Chats tab must show the InboxSearchBar that opens search',
    );
    await tester.tap(bar.first);

    final opened = await pumpUntilFound(
      tester,
      searchScreen,
      timeout: const Duration(seconds: 10),
    );
    expect(
      opened,
      isTrue,
      reason: 'tapping the inbox search bar must push CometChatSearch',
    );
  }

  /// Open B's chat → header ⋯ menu → "Search" → CometChatSearch scoped to B.
  Future<void> openInConversationSearch(WidgetTester tester) async {
    await AppLauncher.launchAndLogin(tester);
    await NavigationHelper.openUserBConversation(tester);
    AssertionHelper.expectOnMessagesScreen();

    // cometchat_message_header.dart `_buildOverflowMenu` — IconButton with
    // Icons.more_vert opening a MenuAnchor of MenuItemButtons.
    final overflow = find.descendant(
      of: find.byType(CometChatMessageHeader),
      matching: find.byIcon(Icons.more_vert),
    );
    expect(
      overflow,
      findsOneWidget,
      reason: 'message header must show the ⋯ overflow menu',
    );
    await tester.tap(overflow);

    // `_overflowEntries` — first entry label is Translations.search.
    final searchEntry = find.widgetWithText(MenuItemButton, 'Search');
    final menuShown = await pumpUntilFound(
      tester,
      searchEntry,
      timeout: const Duration(seconds: 5),
    );
    expect(menuShown, isTrue, reason: 'the ⋯ menu must offer a "Search" entry');
    await tester.tap(searchEntry);

    final opened = await pumpUntilFound(
      tester,
      searchScreen,
      timeout: const Duration(seconds: 10),
    );
    expect(
      opened,
      isTrue,
      reason: 'the header "Search" entry must push CometChatSearch',
    );
  }

  /// Type [query] into the search field and release focus.
  Future<void> typeQuery(WidgetTester tester, String query) async {
    expect(
      searchField(),
      findsOneWidget,
      reason: 'CometChatSearch must contain exactly one search TextField',
    );
    await tester.enterText(searchField(), query);
    await tester.pump(const Duration(milliseconds: 300));
    await KitFinders.dropFocus(tester);
  }

  /// Type [query] and wait for a result row containing [expectInRow].
  ///
  /// The message index is eventually consistent, so an empty first answer is
  /// retried once by re-issuing the query (the bloc only searches on a text
  /// CHANGE, hence the clear in between). A second miss is a real failure and
  /// is reported by the caller's assertion, not swallowed here.
  Future<bool> searchAndAwaitRow(
    WidgetTester tester,
    String query,
    String expectInRow,
  ) async {
    await typeQuery(tester, query);
    var found = await pumpUntilFound(
      tester,
      resultRowsContaining(expectInRow),
      timeout: const Duration(seconds: 15),
    );
    if (found) return true;

    await typeQuery(tester, '');
    await pumpFor(tester, const Duration(seconds: 3));
    await typeQuery(tester, query);
    found = await pumpUntilFound(
      tester,
      resultRowsContaining(expectInRow),
      timeout: const Duration(seconds: 20),
    );
    return found;
  }

  group('Search: CometChatSearch screen', () {
    testWidgets('E2E-130: Search screen opens from the Chats tab search bar', (
      tester,
    ) async {
      await openGlobalSearch(tester);

      // Global scope → plain "Search" hint (a scoped search says
      // "Search in <name>"), and no query yet → no clear button.
      expect(
        inSearch(KitFinders.textFieldWithHint('Search')),
        findsOneWidget,
        reason: 'the search screen must show its "Search" text field',
      );
    });

    testWidgets('E2E-131: Typing in the search box shows the typed text', (
      tester,
    ) async {
      await openGlobalSearch(tester);
      const typed = 'hello search box';
      await typeQuery(tester, typed);

      final field = tester.widget<TextField>(searchField());
      expect(
        field.controller?.text,
        typed,
        reason: 'the search field controller must hold the typed text',
      );
      expect(
        find.descendant(of: searchField(), matching: find.text(typed)),
        findsOneWidget,
        reason: 'the typed text must be rendered inside the search field',
      );
    });

    testWidgets(
      'E2E-132: Matching results are displayed for a seeded keyword',
      (tester) async {
        await openGlobalSearch(tester);
        final found = await searchAndAwaitRow(tester, keyword, keyword);

        expect(
          found,
          isTrue,
          reason:
              'searching "$keyword" must list the seeded message as a '
              '"Message from …" result row',
        );
      },
    );

    testWidgets('E2E-133: No-results state is shown for a random string', (
      tester,
    ) async {
      await openGlobalSearch(tester);
      final nonsense = 'zzxqv${runLetters}nomatchwhatsoever';
      await typeQuery(tester, nonsense);

      final shown = await pumpUntilFound(
        tester,
        emptyState(),
        timeout: const Duration(seconds: 20),
      );
      expect(
        shown,
        isTrue,
        reason: 'a query matching nothing must show "No records found"',
      );
      expect(
        resultRows(),
        findsNothing,
        reason: 'the no-results state must not list any message row',
      );
    });

    testWidgets('E2E-134: Search is case-insensitive', (tester) async {
      await openGlobalSearch(tester);
      final upper = keyword.toUpperCase();
      expect(
        upper,
        isNot(keyword),
        reason: 'precondition: the query must differ in case from the seed',
      );

      // The row still renders the ORIGINAL casing, so match on that.
      final found = await searchAndAwaitRow(tester, upper, keyword);
      expect(
        found,
        isTrue,
        reason:
            'searching "$upper" must still find the message seeded as '
            '"$keyword"',
      );
    });

    testWidgets('E2E-135: Clear button resets the field and the results', (
      tester,
    ) async {
      await openGlobalSearch(tester);
      final found = await searchAndAwaitRow(tester, keyword, keyword);
      if (!found) {
        fail(
          'precondition: "$keyword" returned no results, so there is '
          'nothing for the clear button to reset',
        );
      }
      expect(
        clearButton(),
        findsOneWidget,
        reason: 'a non-empty query must show the clear (✕) button',
      );

      await tester.tap(clearButton());
      await pumpFor(tester, const Duration(seconds: 2));

      expect(
        tester.widget<TextField>(searchField()).controller?.text,
        isEmpty,
        reason: 'clear must empty the search field',
      );
      expect(
        resultRows(),
        findsNothing,
        reason: 'clear must remove the previous results',
      );
      expect(
        clearButton(),
        findsNothing,
        reason: 'clear button must disappear once the query is empty',
      );
    });

    testWidgets('E2E-136: A result shows the correct message content', (
      tester,
    ) async {
      await openGlobalSearch(tester);
      final found = await searchAndAwaitRow(tester, keyword, keyword);
      if (!found) fail('precondition: "$keyword" returned no results');

      // message_preview_subtitle.dart `_richText` — the preview is a RichText
      // built from message.text; plain text must equal the seed verbatim.
      final previews = find.descendant(
        of: resultRowsContaining(keyword),
        matching: find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == seededText,
          skipOffstage: false,
        ),
      );
      expect(
        previews,
        findsOneWidget,
        reason: 'the result row must preview exactly "$seededText"',
      );
    });

    testWidgets('E2E-137: The keyword is present in every result row', (
      tester,
    ) async {
      await openGlobalSearch(tester);
      final found = await searchAndAwaitRow(tester, keyword, keyword);
      if (!found) fail('precondition: "$keyword" returned no results');

      final all = resultRows().evaluate().length;
      final withKeyword = resultRowsContaining(keyword).evaluate().length;
      expect(all, greaterThan(0));
      expect(
        withKeyword,
        all,
        reason:
            'every one of the $all result rows must contain the '
            'searched keyword "$keyword"',
      );
    });

    testWidgets('E2E-138: A result shows sender context', (tester) async {
      await openGlobalSearch(tester);
      final found = await searchAndAwaitRow(tester, keyword, keyword);
      if (!found) fail('precondition: "$keyword" returned no results');

      // cometchat_search.dart `_getConversationTitle` — an incoming 1:1
      // message is titled with its sender's name; `_buildSearchItem` puts that
      // in both the Semantics label and the title Text.
      final row = resultRowsContaining(keyword);
      final semantics = tester.widget<Semantics>(row.first);
      expect(
        semantics.properties.label,
        'Message from ${TestCredentials.userBName}',
        reason: 'the row must be labelled with the sender (User B)',
      );
      expect(
        find.descendant(
          of: row,
          matching: find.text(TestCredentials.userBName, skipOffstage: false),
        ),
        findsOneWidget,
        reason: 'the row must display the sender name as its title',
      );
    });

    testWidgets('E2E-140: An emoji message is findable', (tester) async {
      await openGlobalSearch(tester);
      final found = await searchAndAwaitRow(tester, emojiKeyword, '🎉🦄');

      expect(
        found,
        isTrue,
        reason:
            'searching "$emojiKeyword" must list the emoji message with '
            'its emoji rendered intact in the result row',
      );
    });

    testWidgets('E2E-141: Spaces-only input is treated as empty', (
      tester,
    ) async {
      await openGlobalSearch(tester);
      await typeQuery(tester, '     ');
      // search_bloc.dart debounces 500 ms; wait well past it so a wrongly
      // fired search would have had time to paint loading/empty/results.
      await pumpFor(tester, const Duration(seconds: 3));

      // `_onSearchTextChanged` trims → empty → initial state. The clear button
      // is keyed off that same trimmed bloc text, so its absence proves the
      // bloc saw an empty query.
      expect(
        clearButton(),
        findsNothing,
        reason: 'a whitespace-only query must not count as a query',
      );
      expect(
        emptyState(),
        findsNothing,
        reason: 'no search may fire → no "No records found" state',
      );
      expect(
        inSearch(find.byType(CometChatShimmerEffect)),
        findsNothing,
        reason: 'no search may fire → no loading shimmer',
      );
      expect(
        inSearch(find.byType(CustomScrollView)),
        findsNothing,
        reason: 'no search may fire → no results list',
      );
    });

    testWidgets(
      'E2E-142: Tapping a result opens the conversation at that message',
      (tester) async {
        await openGlobalSearch(tester);
        final found = await searchAndAwaitRow(tester, keyword, keyword);
        if (!found) fail('precondition: "$keyword" returned no results');

        await tester.tap(resultRowsContaining(keyword).first);

        // home_screen.dart `_openSearch.onMessageClicked` → `_pushMessages(…,
        // scrollToMessageId: message.id)` → MessagesScreen(goToMessageId:).
        final target = find.byWidgetPredicate(
          (w) => w is MessagesScreen && w.goToMessageId == seededTextId,
        );
        final pushed = await pumpUntilFound(
          tester,
          target,
          timeout: const Duration(seconds: 15),
        );
        expect(
          pushed,
          isTrue,
          reason:
              'tapping the result must push MessagesScreen targeted at '
              'message #$seededTextId',
        );
        // Scoped to the pushed screen's CometChatMessageList: the same text is
        // also in the search row and the Chats-tab subtitle mounted underneath.
        final inList = find.descendant(
          of: find.descendant(
            of: target,
            matching: find.byType(CometChatMessageList),
          ),
          matching: KitFinders.richTextContaining(
            seededText,
            skipOffstage: false,
          ),
        );
        final rendered = await pumpUntilFound(
          tester,
          inList,
          timeout: const Duration(seconds: 25),
        );
        expect(
          rendered,
          isTrue,
          reason: 'the opened conversation must render the searched message',
        );
      },
    );
  });

  group('Search: in-conversation filters', () {
    testWidgets(
      'E2E-139: Photos filter shows a seeded image and hides text results',
      (tester) async {
        await openInConversationSearch(tester);

        // Scoped search → hint "Search in <name>" and, per
        // SearchBloc._resolveAllowedFilters, only message chips.
        expect(
          inSearch(
            KitFinders.textFieldWithHint(
              'Search in ${TestCredentials.userBName}',
            ),
          ),
          findsOneWidget,
          reason: 'in-conversation search must be scoped to User B',
        );

        // search_filter_chip.dart — chip label text; "Photos" is hardcoded
        // English in SearchBloc.defaultFilters.
        final photos = inSearch(
          find.widgetWithText(SearchFilterChip, 'Photos'),
        );
        expect(
          photos,
          findsOneWidget,
          reason: 'message search must offer the "Photos" filter chip',
        );
        await tester.tap(photos);

        // cometchat_search.dart `_mediaThumb` — an image row's trailing widget
        // is a CometChatImageBubble built from the first attachment's URL.
        final seededThumb = inSearch(
          find.byWidgetPredicate(
            // The thumbnail still uses the single-attachment bubble class.
            // ignore: deprecated_member_use
            (w) => w is CometChatImageBubble && w.imageUrl == seededImageUrl,
            skipOffstage: false,
          ),
        );
        final listed = await pumpUntilFound(
          tester,
          seededThumb,
          timeout: const Duration(seconds: 25),
        );
        expect(
          listed,
          isTrue,
          reason: 'the Photos filter must list the seeded image message',
        );

        expect(
          tester.widget<SearchFilterChip>(photos).isSelected,
          isTrue,
          reason: 'the tapped chip must render as selected',
        );
        expect(
          inSearch(KitFinders.richTextContaining(keyword, skipOffstage: false)),
          findsNothing,
          reason: 'the Photos filter must hide the text-only seeded message',
        );
      },
    );
  });
}
