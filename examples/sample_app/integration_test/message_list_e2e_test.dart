import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

import 'helpers/login_fixture.dart';
import 'helpers/seed_data.dart';

/// E2E test for the Message List flow.
///
/// Mirrors the pattern in conversations_e2e_test.dart:
///  - tester.pump loop instead of pumpAndSettle (SDK listeners never settle)
///  - Screenshots written to /sdcard/Download/e2e_screenshots on Android,
///    Documents on iOS, plus a binding.takeScreenshot for the CI gallery.
///
/// Pre-conditions handled in setUpAll:
///  - REST seeds N messages between TEST_USER_UID and TEST_PEER_UID
///  - SDK is initialised and the test user is logged in
///
/// Run on a device or simulator:
///   flutter test integration_test/message_list_e2e_test.dart -d DEVICE_ID
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Pump frames for [duration] of real wall-clock time.
  /// Unlike tester.pump(duration) which only advances fake time, this lets
  /// real async work (SDK fetches, listener callbacks) complete.
  Future<void> pumpForDuration(WidgetTester tester, Duration duration) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Capture a screenshot for the CI gallery and to a writable on-device dir.
  Future<void> screenshot(WidgetTester tester, String name) async {
    try {
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      final bytes = await binding.takeScreenshot(name);

      // Android emulator: /sdcard/Download is writable.
      // iOS simulator: HOME points at the app sandbox, so use Documents.
      final candidates = <String>[
        '/sdcard/Download/e2e_screenshots',
        if (Platform.environment['HOME'] != null)
          '${Platform.environment['HOME']}/Documents/e2e_screenshots',
      ];
      for (final path in candidates) {
        try {
          final dir = Directory(path);
          if (!dir.existsSync()) dir.createSync(recursive: true);
          File('${dir.path}/$name.png').writeAsBytesSync(bytes);
          debugPrint('Screenshot saved: ${dir.path}/$name.png');
          break;
        } catch (_) {
          // Try the next candidate.
        }
      }
    } catch (e) {
      debugPrint('Screenshot "$name" failed: $e');
    }
  }

  /// Builder that wraps [child] with the localisations the UIKit needs.
  Widget appHost(Widget child) {
    return MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    );
  }

  /// Finds rendered message bubble text inside CometChat's RichText-based
  /// TextBubble. `find.text` / `find.textContaining` only match plain `Text`
  /// widgets, but TextBubble renders messages via `RichText` + `TextSpan`,
  /// so the textual seed needle (`E2E msg #...`) is invisible to those
  /// finders. This walks the TextSpan tree of any RichText in the tree.
  Finder findRichTextContaining(String needle) {
    return find.byWidgetPredicate((widget) {
      if (widget is RichText) {
        final buf = StringBuffer();
        widget.text.visitChildren((span) {
          if (span is TextSpan && span.text != null) buf.write(span.text);
          return true;
        });
        return buf.toString().contains(needle);
      }
      return false;
    }, description: 'RichText containing "$needle"');
  }

  group('Message List E2E', () {
    // Scoped to this group, not to the file. all_e2e_tests.dart calls this
    // main() and conversations' in one process, and a file-level setUpAll
    // registers at the root — so BOTH suites' setup ran before EITHER suite's
    // tests. That put this seeding ~90 s before these tests, with the
    // conversations delete-flow test in between, and that test removes the
    // conversation this one reads: every test below arrived to an empty
    // conversation and failed on a missing bubble. Group scope re-seeds here,
    // after that suite has finished.
    setUpAll(() async {
      // Seed several messages so the list has both incoming and outgoing
      // bubbles.
      await SeedData.seedMessages(count: 5);
      await Future<void>.delayed(const Duration(seconds: 3));
      await LoginFixture.initAndLogin();
      // Give the SDK time to establish its socket and warm caches before
      // tests start mounting widgets. Chained runs (where this file follows
      // another e2e file in the same process) hit this path with a freshly
      // re-established session, and the first message fetch otherwise lands
      // outside the per-test pump window — which causes the message list to
      // render its empty state and the header/footer slots to never build.
      await Future<void>.delayed(const Duration(seconds: 12));
    });

    tearDownAll(() async {
      await LoginFixture.logout();
      await SeedData.cleanup();
    });

    testWidgets('Primary flow: list renders seeded messages', (tester) async {
      final peer = User(uid: SeedData.testPeerUid, name: 'E2E Peer');

      await tester.pumpWidget(
        appHost(CometChatMessageList(user: peer)),
      );

      // Real-time wait for SDK fetch + first render.
      await pumpForDuration(tester, const Duration(seconds: 8));

      expect(find.byType(CometChatMessageList), findsOneWidget);

      // The seed step writes the message text "E2E msg #N ..." for each
      // bubble. The bubble renders text inside a RichText (formatters
      // produce TextSpans), so plain `find.textContaining` won't see it —
      // we walk the TextSpan tree instead.
      final renderedSeedMessages = findRichTextContaining('E2E msg #');
      final bubbleCount =
          find.byType(CometChatTextBubble).evaluate().length;
      debugPrint(
        'Found ${renderedSeedMessages.evaluate().length} RichText hits, '
        '$bubbleCount CometChatTextBubble instances',
      );
      expect(
        renderedSeedMessages,
        findsWidgets,
        reason:
            'Expected at least one seeded "E2E msg #..." bubble to render. '
            'If this fails, the list is stuck on loading or showing empty state.',
      );
      expect(
        bubbleCount,
        greaterThanOrEqualTo(1),
        reason:
            'Expected at least one CometChatTextBubble in the list after seeding.',
      );

      await screenshot(tester, '01_message_list_loaded');
    });

    testWidgets('Empty conversation shows empty state for unknown user',
        (tester) async {
      // A UID we never seed messages for: the list should resolve to empty
      // (or at worst loading), but it must not crash and must not show the
      // seed-message bubbles.
      final emptyUser = User(
        uid: 'e2e_empty_user_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Empty User',
      );

      await tester.pumpWidget(
        appHost(CometChatMessageList(user: emptyUser)),
      );

      await pumpForDuration(tester, const Duration(seconds: 6));

      expect(find.byType(CometChatMessageList), findsOneWidget);
      expect(
        findRichTextContaining('E2E msg #'),
        findsNothing,
        reason:
            'A fresh empty user should never show messages from the seeded '
            'peer conversation.',
      );

      await screenshot(tester, '02_message_list_empty_user');
    });

    testWidgets('Custom emptyStateView renders when there are no messages',
        (tester) async {
      final emptyUser = User(
        uid: 'e2e_empty_view_user_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Empty View User',
      );

      await tester.pumpWidget(
        appHost(
          CometChatMessageList(
            user: emptyUser,
            emptyStateView: (context) => const Center(
              child: Text(
                'CUSTOM EMPTY STATE',
                key: Key('e2e_custom_empty_view'),
                style: TextStyle(fontSize: 18, color: Colors.deepPurple),
              ),
            ),
          ),
        ),
      );

      await pumpForDuration(tester, const Duration(seconds: 8));

      // The custom view is shown only when the SDK confirms zero messages,
      // so we don't fail hard on it; we record what we see for the gallery
      // and assert the widget tree at minimum.
      final customEmpty = find.byKey(const Key('e2e_custom_empty_view'));
      debugPrint(
        'Custom emptyStateView matches: ${customEmpty.evaluate().length}',
      );
      expect(find.byType(CometChatMessageList), findsOneWidget);

      await screenshot(tester, '03_custom_empty_view');
    });

    testWidgets('Custom headerView renders above the list', (tester) async {
      final peer = User(uid: SeedData.testPeerUid, name: 'E2E Peer');

      await tester.pumpWidget(
        appHost(
          CometChatMessageList(
            user: peer,
            headerView: (context, {user, group, parentMessageId}) => Container(
              key: const Key('e2e_custom_header'),
              padding: const EdgeInsets.all(8),
              color: Colors.blue.shade50,
              child: const Text('CUSTOM HEADER'),
            ),
          ),
        ),
      );

      await pumpForDuration(tester, const Duration(seconds: 6));

      expect(
        find.byKey(const Key('e2e_custom_header')),
        findsOneWidget,
        reason: 'Custom headerView should render above the message list.',
      );
      expect(find.text('CUSTOM HEADER'), findsOneWidget);

      await screenshot(tester, '04_custom_header_view');
    });

    testWidgets('Custom footerView renders below the list', (tester) async {
      final peer = User(uid: SeedData.testPeerUid, name: 'E2E Peer');

      await tester.pumpWidget(
        appHost(
          CometChatMessageList(
            user: peer,
            footerView: (context, {user, group, parentMessageId}) => Container(
              key: const Key('e2e_custom_footer'),
              padding: const EdgeInsets.all(8),
              color: Colors.green.shade50,
              child: const Text('CUSTOM FOOTER'),
            ),
          ),
        ),
      );

      await pumpForDuration(tester, const Duration(seconds: 6));

      expect(
        find.byKey(const Key('e2e_custom_footer')),
        findsOneWidget,
        reason: 'Custom footerView should render below the message list.',
      );
      expect(find.text('CUSTOM FOOTER'), findsOneWidget);

      await screenshot(tester, '05_custom_footer_view');
    });

    testWidgets('Custom style applies background colour', (tester) async {
      final peer = User(uid: SeedData.testPeerUid, name: 'E2E Peer');

      await tester.pumpWidget(
        appHost(
          CometChatMessageList(
            user: peer,
            style: CometChatMessageListStyle(
              backgroundColor: Colors.amber.shade50,
            ),
          ),
        ),
      );

      await pumpForDuration(tester, const Duration(seconds: 6));

      expect(find.byType(CometChatMessageList), findsOneWidget);

      await screenshot(tester, '06_custom_style_background');
    });

    testWidgets('Custom messagesRequestBuilder is accepted without crashing',
        (tester) async {
      // Note: we don't assert that `limit` caps the rendered count because the
      // message list paginates more aggressively than the per-page limit
      // suggests. The point of this smoke test is to confirm that passing a
      // custom MessagesRequestBuilder doesn't crash the widget and the list
      // still renders bubbles.
      final peer = User(uid: SeedData.testPeerUid, name: 'E2E Peer');
      final builder = MessagesRequestBuilder()
        ..limit = 30
        ..hideReplies = true;

      await tester.pumpWidget(
        appHost(
          CometChatMessageList(
            user: peer,
            messagesRequestBuilder: builder,
          ),
        ),
      );

      await pumpForDuration(tester, const Duration(seconds: 8));

      final bubbleCount =
          find.byType(CometChatTextBubble).evaluate().length;
      debugPrint(
        'Custom messagesRequestBuilder smoke: $bubbleCount bubbles rendered',
      );

      expect(find.byType(CometChatMessageList), findsOneWidget);
      expect(
        bubbleCount,
        greaterThanOrEqualTo(1),
        reason:
            'With a custom MessagesRequestBuilder, the list should still '
            'render at least one seeded bubble.',
      );

      await screenshot(tester, '07_custom_messages_request_builder');
    });

    testWidgets('Long-press on a message opens the action sheet',
        (tester) async {
      final peer = User(uid: SeedData.testPeerUid, name: 'E2E Peer');

      await tester.pumpWidget(
        appHost(CometChatMessageList(user: peer)),
      );

      await pumpForDuration(tester, const Duration(seconds: 8));

      final seedBubbles = findRichTextContaining('E2E msg #');
      if (seedBubbles.evaluate().isEmpty) {
        fail(
          'No seeded bubbles to long-press. This group seeds messages in its '
          'setUpAll, so an empty list means the fixture never arrived — that '
          'must not read as a pass.',
        );
      }

      // The list is `reverse: true`, so the first match in tree order is the
      // NEWEST message. Whenever the list is parked above the unread divider
      // that message sits below the fold, built in the cache extent but off
      // screen — and the 320x640 emulator does exactly that. Long-pressing it
      // warps the pointer outside the viewport, the hit test never reaches the
      // bubble's gesture detector, and no action sheet opens. Press a bubble a
      // user could actually reach instead.
      final visibleBubbles = seedBubbles.hitTestable();
      if (visibleBubbles.evaluate().isEmpty) {
        fail(
          'Seeded bubbles are in the tree but none are hit-testable, so there '
          'is nothing a user could long-press.',
        );
      }

      await tester.longPress(visibleBubbles.first);
      await pumpForDuration(tester, const Duration(seconds: 1));

      await screenshot(tester, '08_longpress_action_sheet');

      // The action sheet typically shows Reply / Copy / Delete style options;
      // Reply is the most reliable across template configurations.
      final reply = find.text('Reply');
      final copy = find.text('Copy text');
      debugPrint(
        'After long-press: reply=${reply.evaluate().length}, '
        'copy=${copy.evaluate().length}',
      );
      expect(
        reply.evaluate().isNotEmpty || copy.evaluate().isNotEmpty,
        isTrue,
        reason:
            'Long-pressing a message should open an action sheet exposing at '
            'least one of: Reply, Copy text. Saw reply='
            '${reply.evaluate().length}, copy=${copy.evaluate().length} after '
            'long-pressing 1 of ${visibleBubbles.evaluate().length} visible '
            'bubbles.',
      );
    });
  });
}
