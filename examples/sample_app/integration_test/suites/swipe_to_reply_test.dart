import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../config/test_credentials.dart';
import '../helpers_v2/app_launcher.dart';
import '../helpers_v2/cleanup_helper.dart';
import '../helpers_v2/composer_depth_helper.dart';
import '../helpers_v2/pump_helper.dart';
import '../sdk_user_b/composer_depth_actions.dart';
import '../sdk_user_b/group_actions.dart';
import '../sdk_user_b/messaging_actions.dart';

/// Swipe-to-reply — E2E suite (iOS parity, STRICT).
///
/// Supersedes nothing: 1TO1-081 (message_actions_test.dart) and 1TO1-087/088
/// (composer_test.dart) stay as they are, but both only require "the composer
/// still exists" and therefore pass with swipe-to-reply broken. Each case here
/// fails if the gesture, the preview or the quoted reply is broken.
///
///   E2E-121  Swiping a bubble opens the reply preview above the input and the
///            preview quotes the swiped message's text
///   E2E-122  Sending the reply removes the preview and empties the composer
///   E2E-123  The sent reply carries `quotedMessageId` of the original and its
///            bubble shows the quoted original
///   E2E-124  Several quick swipes on two bubbles leave exactly ONE preview,
///            quoting the last bubble swiped
///   E2E-125  A swipe while the message-options overlay is open does not start
///            a reply; swipe works again once the overlay is closed
///   E2E-126  Swipe still works on an older bubble after scrolling the list
///   E2E-127  Swiping a group action message ("… added …") opens no preview,
///            while a text bubble in the same group does
///   E2E-128  The preview's close button removes it, and the next message
///            sent is not a reply
///
/// Source facts:
///   * cometchat_message_swipe.dart — RIGHTWARD horizontal drag only, fires at
///     `swipeThreshold = 60` px, bubble travel capped at 80 px, snaps back.
///   * cometchat_message_list.dart `_canSwipe` — disabled for unsent
///     (`id <= 0`), deleted, `action`/`call` category, agentic and moderated
///     messages; enabled by default in the sample app
///     (`component_toggles.dart`: `enableSwipeToReply = true`).
///   * Swipe fires `CometChatMessageEvents.ccReplyToMessage`; the composer
///     shows `CometChatMessagePreview` (with a close button) in
///     `_buildInlinePreview`. A sent reply's bubble reuses the same widget
///     with `hideCloseButton: true` for the quoted block.
///   * The long-press options are a separate non-opaque route
///     (`showMessageActionOverlay` → `PageRouteBuilder`, barrier + full-screen
///     `GestureDetector`), so pointers cannot reach the list beneath it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final stamp = DateTime.now().millisecondsSinceEpoch;
  final groupGuid = 'e2e_swipe_$stamp';
  final groupName = 'E2E Swipe $stamp';

  setUpAll(() async {
    // Group fixture for E2E-127: creating it as User A and adding User B
    // produces a real "<A> added <B>" action message in its history.
    await UserBGroup.createGroupAsAdmin(groupId: groupGuid, name: groupName);
    await Future<void>.delayed(const Duration(seconds: 1));
    await UserBGroup.addMember(TestCredentials.userBUid, groupId: groupGuid);
    await Future<void>.delayed(const Duration(seconds: 2));
  });

  tearDownAll(() async {
    await UserBGroup.deleteGroup(groupId: groupGuid);
    await CleanupHelper.fullReset();
  });

  setUp(() async {
    await CleanupHelper.fullReset();
    await CleanupHelper.seedConversation();
    await Future<void>.delayed(const Duration(seconds: 1));
  });

  tearDown(() async {
    await CleanupHelper.fullReset();
  });

  /// Open the chat with B and have B send a fresh, swipeable message.
  /// Returns (text, id).
  Future<(String, int)> openChatWithIncoming(
    WidgetTester tester,
    String prefix,
  ) async {
    await ComposerDepthHelper.launchIntoChatWithB(tester);
    final text = 'swipe ${ComposerDepthHelper.token(prefix)}';
    final id = await UserBMessaging.sendTextToA(text);
    await ComposerDepthHelper.waitForInList(tester, text);
    expect(
      ComposerDepthHelper.composerReplyPreview(),
      findsNothing,
      reason: 'Precondition: no reply preview before any swipe',
    );
    return (text, id);
  }

  /// Swipe [text] and require the composer preview to open.
  Future<void> swipeAndRequirePreview(WidgetTester tester, String text) async {
    await ComposerDepthHelper.swipeMessage(tester, text);
    final opened = await pumpUntilFound(
      tester,
      ComposerDepthHelper.composerReplyPreview(),
      timeout: const Duration(seconds: 5),
    );
    if (!opened) {
      fail('Swiping "$text" to the right did not open the reply preview');
    }
  }

  group('Swipe to reply: preview', () {
    testWidgets('E2E-121: Swipe opens the reply preview', (tester) async {
      final (text, _) = await openChatWithIncoming(tester, 'open');

      await ComposerDepthHelper.swipeMessage(tester, text);
      await pumpUntilFound(
        tester,
        ComposerDepthHelper.composerReplyPreview(),
        timeout: const Duration(seconds: 5),
      );

      expect(
        ComposerDepthHelper.composerReplyPreview(),
        findsOneWidget,
        reason:
            'A rightward swipe past 60px must open the reply preview '
            'above the input',
      );
      expect(
        ComposerDepthHelper.textUnder(
          tester,
          ComposerDepthHelper.composerReplyPreview(),
        ),
        contains(text),
        reason: 'The preview must quote the swiped message',
      );
    });

    testWidgets('E2E-128: Closing the preview with its close button', (
      tester,
    ) async {
      final (text, _) = await openChatWithIncoming(tester, 'close');
      await swipeAndRequirePreview(tester, text);

      final close = ComposerDepthHelper.composerReplyPreviewClose();
      if (close.evaluate().isEmpty) {
        fail('The reply preview has no close (Icons.close) button');
      }
      await tester.tap(close.first);
      final closed = await pumpUntilGone(
        tester,
        ComposerDepthHelper.composerReplyPreview(),
      );
      expect(
        closed,
        isTrue,
        reason: 'Tapping the close button must remove the reply preview',
      );

      // Cancelling must really cancel: the next message is not a reply.
      final tok = ComposerDepthHelper.token('notareply');
      await ComposerDepthHelper.focusComposer(tester);
      await ComposerDepthHelper.typeAppend(tester, tok);
      await ComposerDepthHelper.tapSend(tester);
      final sent = await ComposerDepthActions.waitForMessageFromA(tok);
      if (sent == null) fail('Message "$tok" never reached the server');
      expect(
        ComposerDepthActions.quotedMessageIdOf(sent),
        isNull,
        reason:
            'A message sent after closing the preview must not quote '
            'the swiped message',
      );
    });

    testWidgets('E2E-124: Multiple quick swipes leave exactly one preview', (
      tester,
    ) async {
      await ComposerDepthHelper.launchIntoChatWithB(tester);
      final first = 'swipe ${ComposerDepthHelper.token('qfirst')}';
      final last = 'swipe ${ComposerDepthHelper.token('qlast')}';
      await UserBMessaging.sendTextToA(first);
      await UserBMessaging.sendTextToA(last);
      await ComposerDepthHelper.waitForInList(tester, last);
      await ComposerDepthHelper.waitForInList(tester, first);

      // Back-to-back swipes with no settling time in between.
      for (final target in [first, last, first, last]) {
        final center = ComposerDepthHelper.centerInList(tester, target);
        if (center == null) fail('"$target" is not laid out in the list');
        await tester.dragFrom(center, const Offset(160, 0));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await pumpFor(tester, const Duration(seconds: 2));

      expect(
        ComposerDepthHelper.composerReplyPreview(),
        findsOneWidget,
        reason: 'Rapid swipes must leave exactly one reply preview',
      );
      final quoted = ComposerDepthHelper.textUnder(
        tester,
        ComposerDepthHelper.composerReplyPreview(),
      );
      expect(
        quoted,
        contains(last),
        reason: 'The surviving preview must quote the LAST bubble swiped',
      );
      expect(
        quoted,
        isNot(contains(first)),
        reason: 'The earlier swipe target must have been replaced',
      );
    });
  });

  group('Swipe to reply: sending', () {
    testWidgets('E2E-122: Sending the reply clears the preview', (
      tester,
    ) async {
      final (text, _) = await openChatWithIncoming(tester, 'clear');
      await swipeAndRequirePreview(tester, text);

      final reply = ComposerDepthHelper.token('replyclears');
      await ComposerDepthHelper.focusComposer(tester);
      await ComposerDepthHelper.typeAppend(tester, reply);
      await ComposerDepthHelper.tapSend(tester);
      await ComposerDepthHelper.waitForInList(tester, reply);

      final closed = await pumpUntilGone(
        tester,
        ComposerDepthHelper.composerReplyPreview(),
      );
      expect(
        closed,
        isTrue,
        reason: 'The reply preview must disappear once the reply is sent',
      );
      expect(
        ComposerDepthHelper.composerText(tester),
        isEmpty,
        reason: 'The composer must be empty after the reply is sent',
      );
    });

    testWidgets('E2E-123: Sent reply shows the quoted original in its bubble', (
      tester,
    ) async {
      final (text, originalId) = await openChatWithIncoming(tester, 'quote');
      await swipeAndRequirePreview(tester, text);

      final reply = ComposerDepthHelper.token('replyquotes');
      await ComposerDepthHelper.focusComposer(tester);
      await ComposerDepthHelper.typeAppend(tester, reply);
      await ComposerDepthHelper.tapSend(tester);
      await ComposerDepthHelper.waitForInList(tester, reply);

      final sent = await ComposerDepthActions.waitForMessageFromA(reply);
      if (sent == null) fail('Reply "$reply" never reached the server');
      expect(
        ComposerDepthActions.quotedMessageIdOf(sent),
        '$originalId',
        reason: 'The reply payload must reference the swiped message',
      );

      expect(
        ComposerDepthHelper.quotedBlocksInList(
          tester,
        ).any((block) => block.contains(text)),
        isTrue,
        reason:
            'The reply bubble must show a quoted block with the original '
            'text',
      );
    });
  });

  group('Swipe to reply: robustness', () {
    testWidgets(
      'E2E-125: Swipe while the message options are open does nothing',
      (tester) async {
        final (text, _) = await openChatWithIncoming(tester, 'overlay');

        // Measure the bubble BEFORE opening the overlay: the overlay flies the
        // bubble over with a Hero, which leaves only a placeholder in the list.
        final bubble = ComposerDepthHelper.centerInList(tester, text);
        if (bubble == null) fail('"$text" is not laid out in the list');

        await tester.longPressAt(bubble);
        await pumpFor(tester, const Duration(seconds: 1));
        if (ComposerDepthHelper.actionOverlay().evaluate().isEmpty) {
          fail('Long-press did not open CometChatMessageActionOverlay');
        }

        // Same gesture, same spot — but the options route is on top.
        await ComposerDepthHelper.swipeAt(tester, bubble);

        // Close the overlay through one of its own actions ("Copy" — en l10n).
        final copy = find.descendant(
          of: ComposerDepthHelper.actionOverlay(),
          matching: find.text('Copy'),
        );
        if (copy.evaluate().isEmpty) {
          fail(
            'The options overlay was closed by the swipe, or has no "Copy" '
            'action to close it with',
          );
        }
        await tester.tap(copy.first);
        final gone = await pumpUntilGone(
          tester,
          ComposerDepthHelper.actionOverlay(),
        );
        if (!gone) fail('The options overlay did not close');
        await pumpFor(tester, const Duration(seconds: 1));

        expect(
          ComposerDepthHelper.composerReplyPreview(),
          findsNothing,
          reason:
              'A swipe made while the options overlay is open must not '
              'start a reply',
        );

        // …and nothing is left broken: the same bubble can be swiped now.
        await ComposerDepthHelper.swipeMessage(tester, text);
        await pumpUntilFound(
          tester,
          ComposerDepthHelper.composerReplyPreview(),
          timeout: const Duration(seconds: 5),
        );
        expect(
          ComposerDepthHelper.composerReplyPreview(),
          findsOneWidget,
          reason: 'Swipe-to-reply must work again after the overlay closes',
        );
      },
    );

    testWidgets('E2E-126: Swipe works after scrolling the list', (
      tester,
    ) async {
      await ComposerDepthHelper.launchIntoChatWithB(tester);

      // Enough history to scroll on any phone or tablet.
      final texts = <String>[];
      for (var i = 0; i < 40; i++) {
        final t = 'scrollrow ${ComposerDepthHelper.token('r')}';
        texts.add(t);
        await UserBMessaging.sendTextToA(t);
      }
      final newest = texts.last;
      await ComposerDepthHelper.waitForInList(tester, newest);

      // The list is `ListView.builder(reverse: true)`: dragging DOWN reveals
      // older messages.
      final rect = ComposerDepthHelper.listRect(tester);
      for (var i = 0; i < 3; i++) {
        await tester.dragFrom(rect.center, const Offset(0, 300));
        await pumpFor(tester, const Duration(milliseconds: 800));
      }
      final newestCenter = ComposerDepthHelper.centerInList(tester, newest);
      if (newestCenter != null && rect.contains(newestCenter)) {
        fail('The message list did not scroll — newest message still visible');
      }

      // Pick the older bubble closest to the middle of the viewport.
      String? target;
      var best = double.infinity;
      for (final t in texts) {
        final c = ComposerDepthHelper.centerInList(tester, t);
        if (c == null || !rect.deflate(60).contains(c)) continue;
        final d = (c.dy - rect.center.dy).abs();
        if (d < best) {
          best = d;
          target = t;
        }
      }
      if (target == null) {
        fail('No seeded message is inside the viewport after scrolling');
      }

      await ComposerDepthHelper.swipeMessage(tester, target);
      await pumpUntilFound(
        tester,
        ComposerDepthHelper.composerReplyPreview(),
        timeout: const Duration(seconds: 5),
      );

      expect(
        ComposerDepthHelper.composerReplyPreview(),
        findsOneWidget,
        reason:
            'Swiping an older bubble after scrolling must open the reply '
            'preview',
      );
      expect(
        ComposerDepthHelper.textUnder(
          tester,
          ComposerDepthHelper.composerReplyPreview(),
        ),
        contains(target),
        reason: 'The preview must quote the bubble that was swiped',
      );
    });

    testWidgets('E2E-127: Swipe on a group action message does nothing', (
      tester,
    ) async {
      final text = 'swipe ${ComposerDepthHelper.token('grp')}';
      await UserBGroup.sendTextToGroup(text, groupId: groupGuid);

      await AppLauncher.launchAndLogin(tester);
      await ComposerDepthHelper.openGroupByName(tester, groupName);
      await ComposerDepthHelper.waitForInList(tester, text);

      // "<A> added <B>" — CometChatActionBubble(text: action.message).
      final action = ComposerDepthHelper.centerOfActionBubble(tester, 'added');
      if (action == null) {
        fail(
          'No "added" CometChatActionBubble in the group — the action '
          'message fixture is missing (or hideGroupActionMessages is on)',
        );
      }

      await ComposerDepthHelper.swipeAt(tester, action);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(
        ComposerDepthHelper.composerReplyPreview(),
        findsNothing,
        reason: 'Swiping a group action message must not start a reply',
      );

      // Control: the very same gesture on a text bubble in this group DOES
      // open the preview — so the negative above is not a dead gesture.
      await ComposerDepthHelper.swipeMessage(tester, text);
      await pumpUntilFound(
        tester,
        ComposerDepthHelper.composerReplyPreview(),
        timeout: const Duration(seconds: 5),
      );
      expect(
        ComposerDepthHelper.composerReplyPreview(),
        findsOneWidget,
        reason: 'Control: a text bubble in the same group must be swipeable',
      );
    });
  });
}
