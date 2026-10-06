import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../config/test_credentials.dart';
import '../helpers_v2/app_launcher.dart';
import '../helpers_v2/cleanup_helper.dart';
import '../helpers_v2/pump_helper.dart';
import '../helpers_v2/screen_reach_helper.dart';
import '../sdk_user_b/messaging_actions.dart';

/// Saved messages E2E (E2E-178 → E2E-181) — a screen with no coverage before.
///
/// How the sample app reaches it (master_app/lib/screens/home_screen.dart,
/// `_buildProfileMenu`): the app-bar avatar `PopupMenuButton<String>` →
/// "Saved Messages" pushes `CometChatSavedMessages`. Save / Unsave live on the
/// "More" page of the long-press overlay and apply without a confirm dialog;
/// unsaving FROM the saved list is a row long-press plus an "Unsave" confirm
/// (chat_uikit/lib/chat_ui/src/saved_messages/cometchat_saved_messages.dart).
///
///   E2E-178  Saving a message from the long-press options saves it on the
///            server (savedAt set) and confirms with the "Message saved" toast
///   E2E-179  A saved message appears in the Saved Messages screen
///   E2E-180  Unsaving from the Saved Messages screen removes the row and
///            clears savedAt on the server
///   E2E-181  The saved list still holds the message after leaving the screen
///            and re-entering it (a fresh fetch, not leftover widget state)
///
/// The saved list is account-wide and outlives a run, so every message text is
/// unique per run and tearDown unsaves exactly what the test saved.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final stamp = DateTime.now().millisecondsSinceEpoch;
  final savedIds = <int>{};

  final messageList = find.byType(CometChatMessageList);
  final savedScreen = find.byType(CometChatSavedMessages);

  setUpAll(() async {
    await CleanupHelper.fullReset();
  });

  tearDown(() async {
    for (final id in savedIds) {
      try {
        await CometChat.unsaveMessage(id, onSuccess: null, onError: (_) {});
      } catch (_) {
        // Already unsaved, or no SDK session — nothing left to restore.
      }
    }
    savedIds.clear();
  });

  tearDownAll(() async {
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

  /// The Kit gates Save behind `CometChat.isSaveMessageEnabled()`
  /// (message_template_utils.dart) — skip visibly when the backend has it off.
  bool saveDisabled() {
    if (CometChat.isSaveMessageEnabled()) return false;
    markTestSkipped(
      'Saved messages are disabled for this CometChat app '
      '(CometChat.isSaveMessageEnabled() == false).',
    );
    return true;
  }

  Future<void> saveViaSdk(int id) async {
    CometChatException? error;
    final updated = await CometChat.saveMessage(
      id,
      onSuccess: null,
      onError: (e) => error = e,
    );
    if (updated == null) {
      fail(
        'Setup: could not save message $id: ${error?.code} '
        '${error?.message}',
      );
    }
    savedIds.add(id);
  }

  Future<BaseMessage> serverCopy(int id) async {
    final m = await CometChat.getMessageDetails(id);
    if (m == null) fail('Could not read message $id back from the server.');
    return m;
  }

  /// Save [text] through the UI: long-press → More → 'Save message'
  /// (translations_en.dart: saveMessageOption).
  Future<void> saveThroughUi(WidgetTester tester, String text, int id) async {
    await ScreenReach.openConversationNamed(tester, TestCredentials.userBName);
    if (!await ScreenReach.waitForTextWithin(tester, messageList, text)) {
      fail('The message to save never rendered.');
    }
    await ScreenReach.chooseMoreOption(tester, text, 'Save message');
    savedIds.add(id);
  }

  group('Saved messages', () {
    testWidgets(
      'E2E-178: Saving a message from the long-press options saves it on '
      'the server',
      (tester) async {
        final text = 'Save me $stamp a';
        final id = await UserBMessaging.sendTextToA(text);
        await launch(tester);
        if (saveDisabled()) return;
        await saveThroughUi(tester, text, id);

        // translations_en.dart: messageSavedToast = 'Message saved'.
        expect(
          await pumpUntilFound(
            tester,
            find.text('Message saved'),
            timeout: const Duration(seconds: 15),
          ),
          isTrue,
          reason: 'Saving should confirm with the "Message saved" toast',
        );
        expect(
          (await serverCopy(id)).savedAt,
          isNotNull,
          reason: 'The server copy of message $id should carry savedAt',
        );
      },
    );

    testWidgets(
      'E2E-179: A saved message appears in the Saved Messages screen',
      (tester) async {
        final text = 'Saved view $stamp b';
        final id = await UserBMessaging.sendTextToA(text);
        await launch(tester);
        if (saveDisabled()) return;
        await saveThroughUi(tester, text, id);
        await pumpUntilFound(
          tester,
          find.text('Message saved'),
          timeout: const Duration(seconds: 15),
        );
        await ScreenReach.goBack(tester);

        await ScreenReach.openSavedMessages(tester);
        expect(
          await ScreenReach.waitForTextWithin(tester, savedScreen, text),
          isTrue,
          reason: 'The Saved Messages screen should list the saved message',
        );
      },
    );

    testWidgets(
      'E2E-180: Unsaving from the Saved Messages screen removes the row',
      (tester) async {
        final text = 'Unsave me $stamp c';
        final id = await UserBMessaging.sendTextToA(text);
        await launch(tester);
        if (saveDisabled()) return;
        await saveViaSdk(id);
        await ScreenReach.openSavedMessages(tester);
        if (!await ScreenReach.waitForTextWithin(tester, savedScreen, text)) {
          fail('Precondition: the saved row for "$text" is not listed.');
        }

        // Rows carry no unsave icon; unsave is the row's onLongPress →
        // confirm dialog 'Unsave message?' with unsaveButton = 'Unsave'.
        final row = ScreenReach.centerOfText(tester, text, within: savedScreen);
        await tester.longPressAt(row!);
        if (!await pumpUntilFound(
          tester,
          find.text('Unsave message?'),
          timeout: const Duration(seconds: 5),
        )) {
          fail(
            'Long-pressing a saved row did not open the unsave confirmation.',
          );
        }
        await tester.tap(find.text('Unsave'));

        expect(
          await ScreenReach.waitForTextGoneWithin(tester, savedScreen, text),
          isTrue,
          reason: 'The unsaved message should leave the Saved Messages screen',
        );
        expect(
          (await serverCopy(id)).savedAt,
          isNull,
          reason: 'The server copy of message $id should no longer be saved',
        );
      },
    );

    testWidgets(
      'E2E-181: The saved list survives leaving and re-entering the screen',
      (tester) async {
        final text = 'Saved survives $stamp d';
        final id = await UserBMessaging.sendTextToA(text);
        await launch(tester);
        if (saveDisabled()) return;
        await saveViaSdk(id);

        await ScreenReach.openSavedMessages(tester);
        if (!await ScreenReach.waitForTextWithin(tester, savedScreen, text)) {
          fail('Precondition: the saved row was not listed on first entry.');
        }
        await ScreenReach.goBack(tester);
        if (!await pumpUntilGone(tester, savedScreen)) {
          fail('Back did not leave the Saved Messages screen.');
        }

        // Re-entry builds a NEW CometChatSavedMessages state, so this can only
        // be satisfied by a fresh server fetch.
        await ScreenReach.openSavedMessages(tester);
        expect(
          await ScreenReach.waitForTextWithin(tester, savedScreen, text),
          isTrue,
          reason: 'The saved message should still be listed after re-entering',
        );
      },
    );
  });
}
