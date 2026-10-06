import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../config/test_credentials.dart';
import '../helpers_v2/app_launcher.dart';
import '../helpers_v2/cleanup_helper.dart';
import '../helpers_v2/pump_helper.dart';
import '../helpers_v2/screen_reach_helper.dart';
import '../sdk_user_b/group_actions.dart';
import '../sdk_user_b/messaging_actions.dart';

/// Pinned messages E2E (E2E-172 → E2E-177) — a screen with no coverage before.
///
/// How the sample app reaches it (master_app/lib/screens/messages_screen.dart):
/// the message header's ⋯ menu → "Pinned Messages" pushes
/// `CometChatPinnedMessages`; a row tap pops it and calls `_openPinnedMessage`,
/// which scrolls the mounted list via `CometChatMessageListController`.
/// Pin / Unpin live on the SECOND page ("More") of the long-press overlay and
/// take effect without a confirm dialog; unpinning FROM the pinned list is a
/// row long-press followed by an "Unpin" confirm.
///
///   E2E-172  Pinning a message from the long-press options pins it on the
///            server (pinnedAt set) and confirms with the "Message pinned" toast
///   E2E-173  A pinned message appears in the conversation's pinned-messages
///            view
///   E2E-174  Unpinning from the pinned-messages view removes the row and
///            clears pinnedAt on the server
///   E2E-175  A message pinned in another conversation does not appear in this
///            conversation's pinned-messages view
///   E2E-176  A live pin in a group whose id has this group's id as a prefix
///            (g1 vs g10) is not added to this group's open pinned view
///            — the 6.2.0 substring-match scoping fix
///   E2E-177  Tapping a pinned message closes the pinned view and jumps the
///            message list to that message
///
/// Every message is sent by User B over REST so its id is known, which lets
/// each test verify server state through `CometChat.getMessageDetails` and lets
/// tearDown unpin exactly what the test pinned, pass or fail.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final stamp = DateTime.now().millisecondsSinceEpoch;
  // guidLong has guidShort as a strict prefix: 'group_<guidLong>' CONTAINS
  // guidShort, which is exactly what the old substring test tripped over.
  final guidShort = 'e2epin$stamp';
  final guidLong = '${guidShort}0';
  final nameShort = 'E2E Pin Short $stamp';
  final nameLong = 'E2E Pin Long $stamp';

  /// Ids pinned by the running test; unpinned in tearDown even on failure.
  final pinnedIds = <int>{};

  final messageList = find.byType(CometChatMessageList);
  final pinnedScreen = find.byType(CometChatPinnedMessages);

  setUpAll(() async {
    await CleanupHelper.fullReset();
    for (final g in [(guidShort, nameShort), (guidLong, nameLong)]) {
      await UserBGroup.createGroupAsAdmin(groupId: g.$1, name: g.$2);
      await UserBGroup.addMember(TestCredentials.userBUid, groupId: g.$1);
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  });

  tearDown(() async {
    for (final id in pinnedIds) {
      try {
        await CometChat.unpinMessage(id, onSuccess: null, onError: (_) {});
      } catch (_) {
        // Already unpinned, or the SDK session is gone — nothing to restore.
      }
    }
    pinnedIds.clear();
  });

  tearDownAll(() async {
    await UserBGroup.deleteGroup(groupId: guidShort);
    await UserBGroup.deleteGroup(groupId: guidLong);
    await CleanupHelper.fullReset();
  });

  Future<void> launch(WidgetTester tester) async {
    await AppLauncher.launchAndLogin(tester);
    if (!await pumpUntilFound(
      tester,
      find.byType(BottomNavigationBar),
      timeout: const Duration(seconds: 20),
    )) {
      fail('The app did not reach HomeScreen after login.');
    }
  }

  /// Visible skip when the backend has the feature off — the Kit hides both the
  /// option and the header entry behind `CometChat.isPinMessageEnabled()`
  /// (message_template_utils.dart / cometchat_message_header.dart).
  bool pinDisabled() {
    if (CometChat.isPinMessageEnabled()) return false;
    markTestSkipped(
      'Pinned messages are disabled for this CometChat app '
      '(CometChat.isPinMessageEnabled() == false).',
    );
    return true;
  }

  /// Pin through the SDK as test SETUP (not the behaviour under test).
  Future<void> pinViaSdk(int id) async {
    CometChatException? error;
    final updated = await CometChat.pinMessage(
      id,
      onSuccess: null,
      onError: (e) => error = e,
    );
    if (updated == null) {
      fail(
        'Setup: could not pin message $id: ${error?.code} '
        '${error?.message}',
      );
    }
    pinnedIds.add(id);
  }

  Future<BaseMessage> serverCopy(int id) async {
    final m = await CometChat.getMessageDetails(id);
    if (m == null) fail('Could not read message $id back from the server.');
    return m;
  }

  group('Pinned messages', () {
    testWidgets(
      'E2E-172: Pinning a message from the long-press options pins it on '
      'the server',
      (tester) async {
        final text = 'Pin me $stamp a';
        final id = await UserBMessaging.sendTextToA(text);
        await launch(tester);
        if (pinDisabled()) return;
        await ScreenReach.openConversationNamed(
          tester,
          TestCredentials.userBName,
        );
        if (!await ScreenReach.waitForTextWithin(tester, messageList, text)) {
          fail('The message to pin never rendered.');
        }

        // translations_en.dart: pinMessageOption = 'Pin message'.
        await ScreenReach.chooseMoreOption(tester, text, 'Pin message');
        pinnedIds.add(id);

        // translations_en.dart: messagePinnedToast = 'Message pinned'
        // (CometChatThreadToast renders it as a Text in the root overlay).
        expect(
          await pumpUntilFound(
            tester,
            find.text('Message pinned'),
            timeout: const Duration(seconds: 15),
          ),
          isTrue,
          reason: 'Pinning should confirm with the "Message pinned" toast',
        );
        expect(
          (await serverCopy(id)).pinnedAt,
          isNotNull,
          reason: 'The server copy of message $id should carry pinnedAt',
        );
      },
    );

    testWidgets(
      'E2E-173: A pinned message appears in the pinned-messages view',
      (tester) async {
        final text = 'Pinned view $stamp b';
        final id = await UserBMessaging.sendTextToA(text);
        await launch(tester);
        if (pinDisabled()) return;
        await ScreenReach.openConversationNamed(
          tester,
          TestCredentials.userBName,
        );
        if (!await ScreenReach.waitForTextWithin(tester, messageList, text)) {
          fail('The message to pin never rendered.');
        }
        await ScreenReach.chooseMoreOption(tester, text, 'Pin message');
        pinnedIds.add(id);
        await pumpUntilFound(
          tester,
          find.text('Message pinned'),
          timeout: const Duration(seconds: 15),
        );

        await ScreenReach.openPinnedMessages(tester);
        // Scoped to the pinned screen: the message list underneath renders the
        // same text and must not be what satisfies this.
        expect(
          await ScreenReach.waitForTextWithin(tester, pinnedScreen, text),
          isTrue,
          reason: 'The pinned view should list the message that was pinned',
        );
      },
    );

    testWidgets(
      'E2E-174: Unpinning from the pinned-messages view removes the row',
      (tester) async {
        final text = 'Unpin me $stamp c';
        final id = await UserBMessaging.sendTextToA(text);
        await launch(tester);
        if (pinDisabled()) return;
        await pinViaSdk(id);
        await ScreenReach.openConversationNamed(
          tester,
          TestCredentials.userBName,
        );
        await ScreenReach.openPinnedMessages(tester);
        if (!await ScreenReach.waitForTextWithin(tester, pinnedScreen, text)) {
          fail('Precondition: the pinned row for "$text" is not in the view.');
        }

        // cometchat_pinned_messages.dart: rows carry no unpin icon; unpin is the
        // row's onLongPress → CometChatConfirmDialog with 'Unpin message?' and a
        // confirm button labelled unpinButton = 'Unpin'.
        final rowCenter = ScreenReach.centerOfText(
          tester,
          text,
          within: pinnedScreen,
        );
        await tester.longPressAt(rowCenter!);
        if (!await pumpUntilFound(
          tester,
          find.text('Unpin message?'),
          timeout: const Duration(seconds: 5),
        )) {
          fail(
            'Long-pressing a pinned row did not open the unpin confirmation.',
          );
        }
        await tester.tap(find.text('Unpin'));

        expect(
          await ScreenReach.waitForTextGoneWithin(tester, pinnedScreen, text),
          isTrue,
          reason: 'The unpinned message should leave the pinned view',
        );
        expect(
          (await serverCopy(id)).pinnedAt,
          isNull,
          reason: 'The server copy of message $id should no longer be pinned',
        );
      },
    );

    testWidgets(
      'E2E-175: A pin in another conversation does not appear in this '
      'pinned-messages view',
      (tester) async {
        final dmText = 'Pinned in DM $stamp d';
        final groupText = 'Pinned in group $stamp d';
        final dmId = await UserBMessaging.sendTextToA(dmText);
        final groupId = await UserBGroup.sendTextToGroup(
          groupText,
          groupId: guidShort,
        );
        await launch(tester);
        if (pinDisabled()) return;
        await pinViaSdk(dmId);
        await pinViaSdk(groupId);

        await ScreenReach.openConversationNamed(tester, nameShort);
        await ScreenReach.openPinnedMessages(tester);

        // Positive control first: without it, an empty/broken view would pass.
        if (!await ScreenReach.waitForTextWithin(
          tester,
          pinnedScreen,
          groupText,
        )) {
          fail(
            'Control: the group\'s own pin is not listed, so the absence of '
            'the other conversation\'s pin would prove nothing.',
          );
        }
        expect(
          ScreenReach.textWithin(tester, pinnedScreen, dmText),
          isFalse,
          reason:
              'A message pinned in the 1:1 conversation must not be '
              'listed in the group\'s pinned view',
        );
      },
    );

    testWidgets(
      'E2E-176: A live pin in a group whose id extends this group\'s id is '
      'not added to this pinned view',
      (tester) async {
        final ownText = 'Short group pin $stamp e';
        final foreignText = 'Long group pin $stamp e';
        final ownId = await UserBGroup.sendTextToGroup(
          ownText,
          groupId: guidShort,
        );
        final foreignId = await UserBGroup.sendTextToGroup(
          foreignText,
          groupId: guidLong,
        );
        await launch(tester);
        if (pinDisabled()) return;

        await ScreenReach.openConversationNamed(tester, nameShort);
        await ScreenReach.openPinnedMessages(tester);

        // With the SHORT group's pinned view open, pin in the LONG group and
        // publish the same kit event the message list publishes after a pin
        // (cometchat_message_list.dart `_handlePinToggle`). The view's
        // `_inScope` must reject it: 'group_<long>' contains '<short>'.
        Future<void> pinLive(int id) async {
          CometChatException? error;
          final updated = await CometChat.pinMessage(
            id,
            onSuccess: null,
            onError: (e) => error = e,
          );
          if (updated == null) {
            fail('Setup: live pin of $id failed: ${error?.code}');
          }
          pinnedIds.add(id);
          CometChatMessageEvents.ccMessagePinned(updated);
        }

        await pinLive(foreignId);
        // Positive control through the SAME live channel, pinned afterwards: once
        // it shows, the foreign event has certainly been processed too.
        await pinLive(ownId);
        if (!await ScreenReach.waitForTextWithin(
          tester,
          pinnedScreen,
          ownText,
        )) {
          fail(
            'Control: a live pin in THIS group never reached the open pinned '
            'view, so the live channel is not working and the negative '
            'assertion would prove nothing.',
          );
        }
        expect(
          ScreenReach.textWithin(tester, pinnedScreen, foreignText),
          isFalse,
          reason:
              'A pin from group "$guidLong" leaked into the pinned view '
              'of group "$guidShort" (substring conversation-id match)',
        );
      },
    );

    testWidgets(
      'E2E-177: Tapping a pinned message jumps the message list to it',
      (tester) async {
        final target = 'Jump target $stamp f';
        final targetId = await UserBMessaging.sendTextToA(target);
        // Bury it well past one screen and past the list's first page.
        await UserBMessaging.sendMultipleToA(40, prefix: 'Jump filler $stamp');
        await launch(tester);
        if (pinDisabled()) return;
        await pinViaSdk(targetId);

        // Open once so the fillers are marked read — the sample app passes
        // startFromUnreadMessages: true, which would otherwise open the list AT
        // the target and make the jump a no-op.
        await ScreenReach.openConversationNamed(
          tester,
          TestCredentials.userBName,
        );
        await pumpFor(tester, const Duration(seconds: 3));
        await ScreenReach.goBack(tester);
        await ScreenReach.openConversationNamed(
          tester,
          TestCredentials.userBName,
        );
        if (!await ScreenReach.waitForTextWithin(
          tester,
          messageList,
          'Jump filler $stamp #40',
        )) {
          fail('The list did not open at the latest message.');
        }
        if (ScreenReach.textWithin(tester, messageList, target)) {
          fail(
            'Precondition: the target is already built in the list, so a '
            'jump could not be told apart from doing nothing.',
          );
        }

        await ScreenReach.openPinnedMessages(tester);
        final row = ScreenReach.centerOfText(
          tester,
          target,
          within: pinnedScreen,
        );
        if (row == null) fail('The pinned row for the target is not listed.');
        await tester.tapAt(row);

        expect(
          await pumpUntilGone(tester, pinnedScreen),
          isTrue,
          reason: 'Tapping a pinned row should close the pinned view',
        );
        expect(
          await ScreenReach.waitForTextWithin(tester, messageList, target),
          isTrue,
          reason: 'The message list should load and show the pinned message',
        );
        final rect = ScreenReach.rectOfText(
          tester,
          target,
          within: messageList,
        )!;
        final listRect = tester.getRect(messageList.first);
        expect(
          listRect.overlaps(rect),
          isTrue,
          reason:
              'The pinned message should be scrolled INTO the viewport '
              '(bubble $rect vs list $listRect), not merely built off-screen',
        );
      },
    );
  });
}
