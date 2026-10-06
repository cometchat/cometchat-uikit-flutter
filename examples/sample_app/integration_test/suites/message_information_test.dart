import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../config/test_credentials.dart';
import '../helpers_v2/app_launcher.dart';
import '../helpers_v2/cleanup_helper.dart';
import '../helpers_v2/message_helper.dart';
import '../helpers_v2/pump_helper.dart';
import '../helpers_v2/screen_reach_helper.dart';
import '../sdk_user_b/group_actions.dart';
import '../sdk_user_b/sdk_user_b.dart';

/// Message Information E2E (E2E-182 → E2E-185).
///
/// The existing 1TO1-079 / GRP-085 only check that an option might exist and
/// then assert "still on the messages screen". They also look for 'Info' on
/// the FIRST page of the long-press overlay, where it never is: Info sits
/// behind the 'More' row (cometchat_message_action_overlay.dart,
/// `_primaryActionOrder`). These go through 'More' and assert on the sheet.
///
/// The sheet is `CometChatMessageInformation` in a modal bottom sheet
/// (chat_uikit/lib/chat_ui/src/message_information/widgets/
/// cometchat_message_information.dart): a header 'Message Information', the
/// message bubble, then — 1:1 — a 'Read' block and a 'Delivered' block each
/// showing `dd/M/yyyy, h:mm a` or the placeholder '----'; — group — one
/// ListTile per member that has at least one receipt timestamp.
///
///   E2E-182  Message Info opens from the long-press options and shows the
///            text of the message it was opened for
///   E2E-183  Before the peer has received the message, Read and Delivered
///            both show the '----' placeholder
///   E2E-184  After User B marks the message delivered then read, both rows
///            show a timestamp and no placeholder is left
///   E2E-185  Group message info lists the member who read the message, by
///            name, with a receipt timestamp
///
/// Receipts are posted with the strict `SdkUserB.post` (throws on non-200), not
/// `UserBReceipts`, which swallows failures and would let a receipt that never
/// happened look like a UI bug.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final stamp = DateTime.now().millisecondsSinceEpoch;
  final groupGuid = 'e2einfo$stamp';
  final groupName = 'E2E Info $stamp';

  final messageList = find.byType(CometChatMessageList);
  final infoSheet = find.byType(CometChatMessageInformation);

  // _convertTime(…, "dd/M/yyyy, h:mm a") — e.g. "17/9/2026, 1:05 PM".
  final receiptTimestamp = RegExp(
    r'^\d{2}/\d{1,2}/\d{4}, \d{1,2}:\d{2}\s?(AM|PM|am|pm)$',
  );

  setUpAll(() async {
    await CleanupHelper.fullReset();
    await CleanupHelper.seedConversation(text: 'Info seed $stamp');
    await UserBGroup.createGroupAsAdmin(groupId: groupGuid, name: groupName);
    await UserBGroup.addMember(TestCredentials.userBUid, groupId: groupGuid);
    await UserBGroup.sendTextToGroup(
      'Info group seed $stamp',
      groupId: groupGuid,
    );
    await Future<void>.delayed(const Duration(seconds: 2));
  });

  tearDownAll(() async {
    await UserBGroup.deleteGroup(groupId: groupGuid);
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

  /// Send [text] as User A through the composer and return its server id,
  /// read back through the same `MessagesRequestBuilder` the Kit uses.
  Future<int> sendAsA(WidgetTester tester, String text, {String? guid}) async {
    await MessageHelper.sendMessage(tester, text);
    if (!await ScreenReach.waitForTextWithin(tester, messageList, text)) {
      fail('The sent message "$text" never rendered in the list.');
    }
    final end = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(end)) {
      final builder = MessagesRequestBuilder()..limit = 30;
      if (guid != null) {
        builder.guid = guid;
      } else {
        builder.uid = TestCredentials.userBUid;
      }
      final page = await builder.build().fetchPrevious(
        onSuccess: null,
        onError: (_) {},
      );
      for (final m in page.reversed) {
        if (m is TextMessage && m.text == text && m.id > 0) return m.id;
      }
      await pumpFor(tester, const Duration(seconds: 1));
    }
    fail(
      'Message "$text" was rendered but never reached the server, so '
      'there is no id to post receipts against.',
    );
  }

  /// long-press → More → 'Info' (translations_en.dart: info = 'Info').
  Future<void> openInfo(WidgetTester tester, String text) async {
    await ScreenReach.chooseMoreOption(tester, text, 'Info');
    if (!await pumpUntilFound(
      tester,
      infoSheet,
      timeout: const Duration(seconds: 10),
    )) {
      fail('Choosing "Info" did not open CometChatMessageInformation.');
    }
    await pumpFor(tester, const Duration(seconds: 2));
  }

  /// Every plain `Text` string rendered inside the info sheet.
  List<String> sheetTexts(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(of: infoSheet, matching: find.byType(Text)),
      )
      .map((t) => t.data ?? '')
      .toList();

  Future<bool> waitForSheet(
    WidgetTester tester,
    bool Function(List<String> texts) condition, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await pumpFor(tester, const Duration(milliseconds: 500));
      if (condition(sheetTexts(tester))) return true;
    }
    return condition(sheetTexts(tester));
  }

  group('Message information', () {
    testWidgets(
      'E2E-182: Message Info opens from the long-press options and shows '
      'the message text',
      (tester) async {
        await launch(tester);
        await ScreenReach.openConversationNamed(
          tester,
          TestCredentials.userBName,
        );
        final text = 'Info shows me $stamp a';
        await sendAsA(tester, text);

        await openInfo(tester, text);

        expect(
          find.descendant(
            of: infoSheet,
            matching: find.text('Message Information'),
          ),
          findsOneWidget,
          reason: 'The sheet should be titled "Message Information"',
        );
        // Scoped to the sheet: the list underneath shows the same text.
        expect(
          ScreenReach.textWithin(tester, infoSheet, text),
          isTrue,
          reason:
              'The info sheet should render the bubble of the message it '
              'was opened for',
        );
      },
    );

    testWidgets(
      'E2E-183: Before the peer receives the message, Read and Delivered '
      'show the placeholder',
      (tester) async {
        await launch(tester);
        await ScreenReach.openConversationNamed(
          tester,
          TestCredentials.userBName,
        );
        final text = 'Info pending $stamp b';
        // User B is REST-only and never acknowledges on its own, so this
        // message is sent but neither delivered nor read.
        await sendAsA(tester, text);

        await openInfo(tester, text);

        final texts = sheetTexts(tester);
        expect(
          texts,
          containsAll(<String>['Read', 'Delivered']),
          reason: 'A 1:1 info sheet should have a Read and a Delivered row',
        );
        expect(
          texts.where((t) => t == '----').length,
          2,
          reason:
              'Both receipt rows should show "----" before any receipt; '
              'sheet texts: $texts',
        );
      },
    );

    testWidgets(
      'E2E-184: After User B marks delivered then read, the info screen '
      'shows both timestamps',
      (tester) async {
        await launch(tester);
        await ScreenReach.openConversationNamed(
          tester,
          TestCredentials.userBName,
        );
        final text = 'Info receipts $stamp c';
        final id = await sendAsA(tester, text);

        // Same endpoints as sdk_user_b/receipt_actions.dart, but failures throw.
        await SdkUserB.post('/messages/$id/delivered', body: {});
        await pumpForRealtime(tester, duration: const Duration(seconds: 3));
        await SdkUserB.post('/messages/$id/read', body: {});
        await pumpForRealtime(tester, duration: const Duration(seconds: 5));

        await openInfo(tester, text);

        final ok = await waitForSheet(
          tester,
          (texts) =>
              texts.where(receiptTimestamp.hasMatch).length == 2 &&
              !texts.contains('----'),
        );
        expect(
          ok,
          isTrue,
          reason:
              'Read and Delivered should each show a dd/M/yyyy, h:mm a '
              'timestamp with no "----" left; sheet texts: '
              '${sheetTexts(tester)}',
        );
      },
    );

    testWidgets(
      'E2E-185: Group message info lists the member who read the message',
      (tester) async {
        await launch(tester);
        await ScreenReach.openConversationNamed(tester, groupName);
        final text = 'Info group $stamp d';
        final id = await sendAsA(tester, text, guid: groupGuid);

        await SdkUserB.post('/messages/$id/delivered', body: {});
        await SdkUserB.post('/messages/$id/read', body: {});
        await pumpForRealtime(tester, duration: const Duration(seconds: 5));

        await openInfo(tester, text);

        // _buildGroupView: ListTile → Text(sender.name) + Read / Delivered rows.
        final memberTile = find.descendant(
          of: infoSheet,
          matching: find.widgetWithText(ListTile, TestCredentials.userBName),
        );
        if (!await pumpUntilFound(
          tester,
          memberTile,
          timeout: const Duration(seconds: 20),
        )) {
          fail(
            'The group info sheet has no receipt row for '
            '"${TestCredentials.userBName}"; sheet texts: '
            '${sheetTexts(tester)}',
          );
        }
        final tileTexts = tester
            .widgetList<Text>(
              find.descendant(of: memberTile, matching: find.byType(Text)),
            )
            .map((t) => t.data ?? '')
            .toList();
        expect(
          tileTexts.where(receiptTimestamp.hasMatch).length,
          2,
          reason:
              'User B\'s row should carry a Read and a Delivered '
              'timestamp; row texts: $tileTexts',
        );
      },
    );
  });
}
