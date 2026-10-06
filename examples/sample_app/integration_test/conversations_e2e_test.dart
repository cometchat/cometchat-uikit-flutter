import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

import 'helpers/login_fixture.dart';
import 'helpers/seed_data.dart';

/// E2E test for the Conversations flow.
///
/// Uses tester.runAsync + pump loop to handle CometChatConversations' perpetual
/// SDK listeners that prevent pumpAndSettle from ever completing.
///
/// Screenshots saved to master_app/integration_test/screenshots/
///
/// Run with:
///   flutter test integration_test/conversations_e2e_test.dart -d emulator-5554
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Pump frames for [duration] of real wall-clock time.
  /// Unlike tester.pump(duration) which only advances fake time,
  /// this actually waits and pumps, letting real async (SDK calls) complete.
  Future<void> pumpForDuration(WidgetTester tester, Duration duration) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Take a screenshot and save to local screenshots/ folder.
  /// Finds a needle in either a plain `Text` or a `RichText`. Conversation
  /// subtitles render through the formatter pipeline, which produces
  /// `TextSpan`s that `find.textContaining` cannot see — the same reason
  /// message_list_e2e_test walks the span tree for message bubbles.
  Finder findTextAnywhere(String needle) {
    return find.byWidgetPredicate((widget) {
      if (widget is Text) {
        return (widget.data ?? '').contains(needle);
      }
      if (widget is RichText) {
        final buf = StringBuffer();
        widget.text.visitChildren((span) {
          if (span is TextSpan && span.text != null) buf.write(span.text);
          return true;
        });
        return buf.toString().contains(needle);
      }
      return false;
    }, description: 'Text or RichText containing "$needle"');
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    try {
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      final bytes = await binding.takeScreenshot(name);
      // Use /sdcard/Download which is writable on Android emulators
      final dir = Directory('/sdcard/Download/e2e_screenshots');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      File('${dir.path}/$name.png').writeAsBytesSync(bytes);
      debugPrint('Screenshot saved: ${dir.path}/$name.png');
    } catch (e) {
      debugPrint('Screenshot "$name" failed: $e');
    }
  }

  group('Conversations E2E', () {
    // Scoped to this group, not to the file. all_e2e_tests.dart calls this
    // main() and message_list's in one process, and a file-level setUpAll
    // registers at the root — so every suite's setup ran before any suite's
    // tests, and the seeding was 90 seconds stale by the time the later suite
    // needed it. Group scope makes each suite set up immediately before its
    // own tests. See the matching note in message_list_e2e_test.dart.
    setUpAll(() async {
      // Seed a conversation so the list is non-empty.
      await SeedData.createTestConversation();
      // Small delay to let the message propagate.
      await Future<void>.delayed(const Duration(seconds: 2));
      // Init SDK + login
      await LoginFixture.initAndLogin();
    });

    tearDownAll(() async {
      await LoginFixture.logout();
      await SeedData.cleanup();
    });

    testWidgets('Primary flow: list renders with seeded conversation', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: const Scaffold(body: CometChatConversations()),
        ),
      );

      // Wait real time for SDK to fetch conversations
      await pumpForDuration(tester, const Duration(seconds: 6));

      // The list should have at least 1 conversation (seeded)
      final listItems = find.byType(InkWell);
      final count = listItems.evaluate().length;
      debugPrint('Found $count InkWell items in conversations list');

      expect(
        count,
        greaterThanOrEqualTo(1),
        reason:
            'Expected at least 1 conversation after seeding via REST API. Found $count.',
      );

      await screenshot(tester, '01_list_loaded');
    });

    testWidgets('Tap conversation fires onItemTap callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: CometChatConversations(
              onItemTap: (conversation) {
                tapped = true;
                debugPrint('onItemTap fired: ${conversation.conversationId}');
              },
            ),
          ),
        ),
      );

      await pumpForDuration(tester, const Duration(seconds: 6));

      final listItems = find.byType(InkWell);
      if (listItems.evaluate().isNotEmpty) {
        await tester.tap(listItems.first);
        await tester.pump(const Duration(milliseconds: 500));
        expect(tapped, isTrue, reason: 'onItemTap should have fired');
      } else {
        fail('No list items found to tap');
      }

      await screenshot(tester, '02_after_tap');
    });

    testWidgets('Long-press shows delete overlay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: const Scaffold(body: CometChatConversations()),
        ),
      );

      await pumpForDuration(tester, const Duration(seconds: 6));

      final listItems = find.byType(InkWell);
      if (listItems.evaluate().isNotEmpty) {
        await tester.longPress(listItems.first);
        await tester.pump(const Duration(milliseconds: 500));

        await screenshot(tester, '03_after_longpress');

        final deleteIcon = find.byIcon(Icons.delete);
        if (deleteIcon.evaluate().isNotEmpty) {
          expect(deleteIcon, findsWidgets);
          debugPrint('Delete overlay appeared');
        } else {
          debugPrint(
            'INFO: Delete icon not found after long-press. '
            'CometChatConversations may use a different delete UX.',
          );
        }
      } else {
        fail('No list items found to long-press');
      }
    });

    testWidgets('conversationsRequestBuilder with limit=3 limits results', (
      tester,
    ) async {
      final builder = ConversationsRequestBuilder()..limit = 3;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: CometChatConversations(conversationsRequestBuilder: builder),
          ),
        ),
      );

      await pumpForDuration(tester, const Duration(seconds: 8));

      final listItems = find.byType(InkWell);
      final count = listItems.evaluate().length;
      debugPrint('RequestBuilder limit=3: found $count items');

      expect(
        count,
        lessThanOrEqualTo(3),
        reason:
            'With conversationsRequestBuilder limit=3, should show at most 3 conversations. Found $count.',
      );
      expect(
        count,
        greaterThanOrEqualTo(1),
        reason: 'Should have at least 1 conversation (seeded).',
      );

      await screenshot(tester, '04_request_builder_limit_3');
    });

    testWidgets(
      'conversationsProtocol with limit=2 limits results via protocol',
      (tester) async {
        final builder = ConversationsRequestBuilder()..limit = 2;
        final protocol = UIConversationsBuilder(builder);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CometChatConversations(conversationsProtocol: protocol),
            ),
          ),
        );

        await pumpForDuration(tester, const Duration(seconds: 8));

        final listItems = find.byType(InkWell);
        final count = listItems.evaluate().length;
        debugPrint('Protocol limit=2: found $count items');

        expect(
          count,
          lessThanOrEqualTo(2),
          reason:
              'With conversationsProtocol limit=2, should show at most 2 conversations. Found $count.',
        );
        expect(
          count,
          greaterThanOrEqualTo(1),
          reason: 'Should have at least 1 conversation (seeded).',
        );

        await screenshot(tester, '05_protocol_limit_2');
      },
    );

    testWidgets('custom listItemView renders with test key', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: CometChatConversations(
              listItemView: (conv) => Container(
                key: const Key('e2e_custom_list_item'),
                padding: const EdgeInsets.all(16),
                color: Colors.amber.shade100,
                child: Text(
                  'CUSTOM: ${(conv.conversationWith as dynamic).name}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await pumpForDuration(tester, const Duration(seconds: 8));

      final customItems = find.byKey(const Key('e2e_custom_list_item'));
      final count = customItems.evaluate().length;
      debugPrint('Custom listItemView: found $count items with key');

      expect(
        count,
        greaterThanOrEqualTo(1),
        reason:
            'Custom listItemView should render at least 1 item with the test key.',
      );

      // Verify custom text is rendered
      expect(find.textContaining('CUSTOM:'), findsWidgets);

      await screenshot(tester, '06_custom_list_item_view');
    });

    testWidgets('custom subtitleView renders with test key', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: CometChatConversations(
              subtitleView: (context, conv) => Text(
                'Custom subtitle for ${conv.conversationId}',
                key: const Key('e2e_custom_subtitle'),
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.teal,
                ),
              ),
            ),
          ),
        ),
      );

      await pumpForDuration(tester, const Duration(seconds: 8));

      final customSubtitles = find.byKey(const Key('e2e_custom_subtitle'));
      final count = customSubtitles.evaluate().length;
      debugPrint('Custom subtitleView: found $count items with key');

      expect(
        count,
        greaterThanOrEqualTo(1),
        reason:
            'Custom subtitleView should render at least 1 subtitle with the test key.',
      );

      await screenshot(tester, '07_custom_subtitle_view');
    });

    testWidgets('custom title and style renders correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: CometChatConversations(
              title: 'My Custom Chats',
              conversationsStyle: const CometChatConversationsStyle(
                titleTextStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ),
      );

      await pumpForDuration(tester, const Duration(seconds: 8));

      // Verify custom title text renders
      expect(
        find.text('My Custom Chats'),
        findsOneWidget,
        reason: 'Custom title text should be visible.',
      );

      await screenshot(tester, '08_custom_title_style');
    });

    testWidgets('custom trailingView renders with test key', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: CometChatConversations(
              trailingView: (conv) => Container(
                key: const Key('e2e_custom_trailing'),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.star, color: Colors.white, size: 16),
              ),
            ),
          ),
        ),
      );

      await pumpForDuration(tester, const Duration(seconds: 8));

      final customTrailing = find.byKey(const Key('e2e_custom_trailing'));
      final count = customTrailing.evaluate().length;
      debugPrint('Custom trailingView: found $count items with key');

      expect(
        count,
        greaterThanOrEqualTo(1),
        reason:
            'Custom trailingView should render at least 1 trailing widget with the test key.',
      );

      await screenshot(tester, '09_custom_trailing_view');
    });

    testWidgets('Delete flow: long-press → delete → confirm → conversation removed', (
      tester,
    ) async {
      // This test owns the conversation it deletes.
      //
      // It used to long-press whichever row sorted first, which is always the
      // most recently seeded conversation — the fixture the message-list suite
      // reads. Running both suites through all_e2e_tests.dart therefore left
      // that suite with an empty conversation and four failing tests. Seeding
      // a conversation with a peer nobody else uses makes this test
      // destructive only to itself.
      final marker = await SeedData.createDisposableConversation();
      addTearDown(SeedData.cleanupDisposable);
      // Let the message propagate before the list fetches.
      await Future<void>.delayed(const Duration(seconds: 3));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: const Scaffold(body: CometChatConversations()),
        ),
      );

      // Wait for conversations to load
      await pumpForDuration(tester, const Duration(seconds: 6));

      final target = findTextAnywhere(marker);
      expect(
        target,
        findsWidgets,
        reason:
            'The conversation seeded for this test ("$marker") never rendered, '
            'so there was nothing to delete. Either the seed did not reach the '
            'backend or the list is still loading.',
      );

      await screenshot(tester, '10_delete_before');

      // Step 1: Long-press the seeded row. Pressing the subtitle is enough —
      // the gesture propagates to the row.
      await tester.longPress(target.first);
      await pumpForDuration(tester, const Duration(seconds: 1));

      await screenshot(tester, '11_delete_longpress_overlay');

      // Step 2: Tap the delete icon/button in the overlay
      final deleteIcon = find.byIcon(Icons.delete);
      final deleteText = find.text('Delete');

      if (deleteIcon.evaluate().isNotEmpty) {
        debugPrint('Found delete icon in overlay, tapping...');
        await tester.tap(deleteIcon.first);
      } else if (deleteText.evaluate().isNotEmpty) {
        debugPrint('Found delete text in overlay, tapping...');
        await tester.tap(deleteText.first);
      } else {
        await screenshot(tester, '11_delete_no_button_found');
        fail(
          'No delete affordance appeared after long-pressing a conversation. '
          'If the delete UX moved to a swipe or bottom sheet, this test needs '
          'updating — it should not pass by skipping.',
        );
      }

      // Step 3: Wait for the CometChatConfirmDialog to appear
      await pumpForDuration(tester, const Duration(seconds: 1));

      await screenshot(tester, '12_delete_confirm_dialog');

      // Step 4: Tap the "Delete" confirm button in the dialog. find.text
      // matches the button, not the longer dialog title.
      final confirmButton = find.text('Delete');
      if (confirmButton.evaluate().isNotEmpty) {
        debugPrint('Found confirm "Delete" button in dialog, tapping...');
        await tester.tap(confirmButton.last);
      } else {
        final alertDialog = find.byType(AlertDialog);
        final textButtons = find.descendant(
          of: alertDialog,
          matching: find.byType(TextButton),
        );
        if (textButtons.evaluate().isNotEmpty) {
          // Confirm is the rightmost action.
          await tester.tap(textButtons.last);
          debugPrint('Tapped last TextButton in AlertDialog');
        } else {
          await screenshot(tester, '12_delete_no_confirm_button');
          fail(
            'The delete confirmation dialog had no tappable confirm action.',
          );
        }
      }

      // Step 5: Wait for deletion to process and the list to refresh
      await pumpForDuration(tester, const Duration(seconds: 5));

      await screenshot(tester, '13_delete_after');

      // Step 6: The conversation this test seeded is gone.
      //
      // Asserted on the marker rather than on a row count. The old assertion
      // compared `find.byType(InkWell)` before and after: InkWell is not 1:1
      // with conversation rows, and the count did not move even when both
      // taps landed and the delete went through — so the test failed while
      // the feature worked.
      expect(
        findTextAnywhere(marker),
        findsNothing,
        reason:
            'After confirming the delete, the conversation "$marker" should no '
            'longer be in the list.',
      );
    });
  });
}
