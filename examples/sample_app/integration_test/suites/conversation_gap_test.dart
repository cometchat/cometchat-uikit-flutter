import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart'
    show CometChatOutgoingCall;
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sample_app/screens/login_screen.dart';
import 'package:sample_app/screens/messages_screen.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/test_credentials.dart';
import '../helpers_v2/app_launcher.dart';
import '../helpers_v2/cleanup_helper.dart';
import '../helpers_v2/message_helper.dart';
import '../helpers_v2/pump_helper.dart';
import '../helpers_v2/screen_reach_helper.dart';
import '../sdk_user_b/messaging_actions.dart';

/// Conversation gap E2E (E2E-192 → E2E-198) — iOS "ConversationGapTests" plus
/// strict versions of the two cases a device run flagged as possible app bugs
/// (1TO1-096 cancel call, E2E-003 logout).
///
///   E2E-192  Login with an empty UID is blocked with a visible validation
///            message and does not navigate
///   E2E-193  A conversation row shows the time of its last message
///   E2E-194  A sent message bubble shows the time it was sent
///   E2E-195  Opening a conversation clears the unread badge on THAT row
///   E2E-196  A new-message indicator (count on the scroll-to-bottom button)
///            appears when a message arrives while scrolled up
///   E2E-197  Cancelling an outgoing call returns to the messages screen
///   E2E-198  Logout returns to the login screen and ends the SDK session
///
/// On the two flagged cases — what the source says:
///
/// 1TO1-096. The app path is sound: the header's 'Voice call' button →
/// `CallButtonsBloc._initiateCallWorkflow` → pushes `CometChatOutgoingCall`;
/// its 'Decline' button → `CancelCall` → REST reject('cancelled') →
/// `_popScreen()` pops exactly that one route. The OLD TEST is at fault: it
/// waits a fixed 3s for the call screen, and when the screen is not up yet
/// (the workflow first awaits `CallPermissions.requestForCallType`, a NATIVE
/// dialog WidgetTester cannot answer, then a REST round trip, then a 300ms
/// delayed push) it finds no call_end icon and falls back to
/// `NavigationHelper.goBack`, which pops the MESSAGES screen. Its final
/// "a TextFormField exists" check then fails on HomeScreen — a failure the
/// test manufactured. E2E-197 skips visibly when the microphone permission is
/// not pre-granted and otherwise waits for the real call screen.
///
/// E2E-003. The old test cannot fail unless the app is still on Chats with no
/// login form 6s after tapping Logout, so a red run is a real signal that
/// logout did not navigate. Source suspects, in order: (1)
/// `CometChatUIKit.logout` wraps the host's `onSuccess` in a try/catch that
/// only logs in debug — and the sample app does its navigation INSIDE that
/// callback (home_screen.dart `/logout`), so any throw there is swallowed and
/// the user is stranded on Home with a dead session; (2) `onError` only
/// debugPrints, so a failed logout is also silent. E2E-198 reports which of
/// the two it was by checking `CometChatUIKit.loggedInUser` on failure.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final stamp = DateTime.now().millisecondsSinceEpoch;
  final bUid = TestCredentials.userBUid;
  final bName = TestCredentials.userBName;

  final messageList = find.byType(CometChatMessageList);

  setUp(() async {
    await CleanupHelper.fullReset();
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

  /// 'h:mm am|pm' exactly as the Kit renders a same-day time — both
  /// `CometChatDate._getTime` (lower-cased "h:mm a") and the message list's
  /// `_formatTime` produce this shape.
  String clock(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    return '$h:${t.minute.toString().padLeft(2, '0')} '
        '${t.hour >= 12 ? 'pm' : 'am'}';
  }

  /// The minute the message was sent in, plus its neighbours: the server
  /// stamps sentAt, and its clock and a minute boundary can each shift by one.
  Set<String> clocksAround(DateTime t) => {
    clock(t.subtract(const Duration(minutes: 1))),
    clock(t),
    clock(t.add(const Duration(minutes: 1))),
  };

  String normalise(String s) =>
      s.replaceAll(RegExp(r'\s'), ' ').toLowerCase().trim();

  group('Conversation gaps', () {
    testWidgets(
      'E2E-192: Login with an empty UID is blocked with a visible validation',
      (tester) async {
        await AppLauncher.launchOnly(tester);
        // login_screen.dart: hintText "Enter the UID", button "Continue".
        final field = find.widgetWithText(TextFormField, 'Enter the UID');
        if (!await pumpUntilFound(
          tester,
          field,
          timeout: const Duration(seconds: 15),
        )) {
          fail('The login form is not on screen.');
        }
        await tester.enterText(field, '');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 500));

        final button = find.text('Continue');
        await tester.ensureVisible(button.first);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(button.first, warnIfMissed: false);

        // `_buildContinueButton`: no sample user selected AND empty field →
        // showErrorSnackBar("Please enter a valid UID") and return.
        expect(
          await pumpUntilFound(
            tester,
            find.text('Please enter a valid UID'),
            timeout: const Duration(seconds: 5),
          ),
          isTrue,
          reason: 'An empty UID should raise the visible validation message',
        );
        await pumpFor(tester, const Duration(seconds: 4));
        expect(
          find.byType(LoginScreen),
          findsOneWidget,
          reason: 'An empty UID must leave the user on the login screen',
        );
        expect(
          find.byType(BottomNavigationBar),
          findsNothing,
          reason: 'An empty UID must not navigate to HomeScreen',
        );
      },
    );

    testWidgets(
      'E2E-193: A conversation row shows the time of its last message',
      (tester) async {
        final sentAround = DateTime.now();
        await UserBMessaging.sendTextToA('Row time $stamp');
        await launch(tester);
        await ScreenReach.goToTab(tester, 'Chats');
        final row = ScreenReach.conversationRowForUser(bUid);
        if (!await pumpUntilFound(
          tester,
          row,
          timeout: const Duration(seconds: 20),
        )) {
          fail('User B\'s conversation row never appeared.');
        }

        // cometchat_conversation_list_item.dart `_buildTimestamp`: a
        // CometChatDate(dayDateTimeFormat) → same-day renders 'h:mm am|pm'.
        final dateText = find.descendant(
          of: find.descendant(of: row, matching: find.byType(CometChatDate)),
          matching: find.byType(Text),
        );
        expect(
          dateText,
          findsOneWidget,
          reason: 'The row should render exactly one timestamp',
        );
        final shown = normalise(tester.widget<Text>(dateText).data ?? '');
        expect(
          clocksAround(sentAround),
          contains(shown),
          reason:
              'The row timestamp "$shown" should be the time its last '
              'message was sent (${clock(sentAround)})',
        );
      },
    );

    testWidgets('E2E-194: A sent message bubble shows the time it was sent', (
      tester,
    ) async {
      await CleanupHelper.seedConversation(text: 'Bubble seed $stamp');
      await launch(tester);
      await ScreenReach.openConversationNamed(tester, bName);

      final text = 'Bubble time $stamp';
      final sentAround = DateTime.now();
      await MessageHelper.sendMessage(tester, text);
      if (!await ScreenReach.waitForTextWithin(tester, messageList, text)) {
        fail('The sent message never rendered.');
      }
      // sentAt is only set once the server acknowledges, and the status row
      // draws the time only then (`_getStatusInfoView`: message.sentAt != null).
      final expected = clocksAround(sentAround);
      List<String> captions() =>
          (ScreenReach.textsInEnclosing<CometChatMessageBubble>(
                    tester,
                    text,
                    within: messageList,
                  ) ??
                  const <String>[])
              .map(normalise)
              .toList();
      final end = DateTime.now().add(const Duration(seconds: 15));
      while (DateTime.now().isBefore(end) &&
          !captions().any(expected.contains)) {
        await pumpFor(tester, const Duration(milliseconds: 500));
      }
      expect(
        captions().where(expected.contains),
        hasLength(1),
        reason:
            'The bubble for "$text" should show its send time '
            '(${clock(sentAround)}) exactly once; bubble texts: '
            '${captions()}',
      );
    });

    testWidgets(
      'E2E-195: Opening a conversation clears the unread badge on that row',
      (tester) async {
        // Seeded while A is logged out of the UI, so all three are unread.
        await UserBMessaging.sendMultipleToA(3, prefix: 'Unread $stamp');
        await launch(tester);
        await ScreenReach.goToTab(tester, 'Chats');

        final row = ScreenReach.conversationRowForUser(bUid);
        // Scoped to THE row: `_buildUnreadBadge` → CometChatBadge(count), which
        // renders Text('$count') only when count > 0.
        final badgeText = find.descendant(
          of: find.descendant(of: row, matching: find.byType(CometChatBadge)),
          matching: find.byType(Text),
        );
        if (!await pumpUntilFound(
          tester,
          badgeText,
          timeout: const Duration(seconds: 20),
        )) {
          fail('Precondition: User B\'s row never showed an unread badge.');
        }
        expect(
          tester.widget<Text>(badgeText).data,
          '3',
          reason: 'Precondition: three unread messages were seeded',
        );

        await tester.tap(row.first);
        if (!await ScreenReach.waitForTextWithin(
          tester,
          messageList,
          'Unread $stamp #3',
        )) {
          fail('The conversation did not open on the unread messages.');
        }
        await pumpFor(tester, const Duration(seconds: 3));
        await ScreenReach.goBack(tester);
        if (!await pumpUntilGone(tester, find.byType(MessagesScreen))) {
          fail('Back did not return to the conversations list.');
        }

        expect(
          await pumpUntilGone(tester, badgeText),
          isTrue,
          reason:
              'User B\'s row should lose its unread badge once the '
              'conversation has been opened',
        );
        expect(
          row,
          findsOneWidget,
          reason:
              'The row itself must still be there — the badge being gone '
              'because the row vanished would not count',
        );
      },
    );

    testWidgets(
      'E2E-196: A new-message indicator appears when a message arrives '
      'while scrolled up',
      (tester) async {
        await UserBMessaging.sendMultipleToA(40, prefix: 'Scroll $stamp');
        await launch(tester);
        // Open once and leave so everything is read; the second open then starts
        // at the bottom instead of at the unread anchor.
        await ScreenReach.openConversationNamed(tester, bName);
        await pumpFor(tester, const Duration(seconds: 3));
        await ScreenReach.goBack(tester);
        await ScreenReach.openConversationNamed(tester, bName);
        if (!await ScreenReach.waitForTextWithin(
          tester,
          messageList,
          'Scroll $stamp #40',
        )) {
          fail('The list did not open at the latest message.');
        }

        // The list is reversed: dragging DOWN scrolls towards older messages.
        for (var i = 0; i < 3; i++) {
          await tester.drag(messageList.first, const Offset(0, 500));
          await pumpFor(tester, const Duration(milliseconds: 600));
        }
        if (ScreenReach.textWithin(tester, messageList, 'Scroll $stamp #40') &&
            (ScreenReach.rectOfText(
                  tester,
                  'Scroll $stamp #40',
                  within: messageList,
                )?.overlaps(tester.getRect(messageList.first)) ??
                false)) {
          fail('Precondition: the list did not scroll away from the bottom.');
        }

        final arrival = 'Arrived while scrolled up $stamp';
        await UserBMessaging.sendTextToA(arrival);
        await pumpForRealtime(tester, duration: const Duration(seconds: 8));

        // scroll_to_bottom_button.dart: `unreadCount > 0` draws a count badge
        // (Text) above the button — the Kit's only live new-message indicator.
        final button = find.descendant(
          of: messageList,
          matching: find.byType(ScrollToBottomButton),
        );
        expect(
          button,
          findsOneWidget,
          reason: 'The message list should own a scroll-to-bottom button',
        );
        final count = tester.widget<ScrollToBottomButton>(button).unreadCount;
        expect(
          count,
          greaterThanOrEqualTo(1),
          reason:
              'A message arrived while scrolled up, so the '
              'scroll-to-bottom button should carry a new-message count',
        );
        expect(
          find.descendant(of: button, matching: find.text('$count')),
          findsOneWidget,
          reason: 'The new-message count should be rendered on the button',
        );
      },
    );

    testWidgets(
      'E2E-197: Cancelling an outgoing call returns to the messages screen',
      (tester) async {
        if (kIsWeb) {
          markTestSkipped('Calling is not available in the web test harness.');
          return;
        }
        // The call workflow awaits a NATIVE permission dialog first
        // (call_buttons_bloc.dart `_initiateCallWorkflow`); WidgetTester cannot
        // answer it, so without a pre-grant the call screen can never appear.
        if (!await Permission.microphone.isGranted) {
          markTestSkipped(
            'Microphone permission is not pre-granted on this '
            'device (adb shell pm grant <pkg> android.permission.RECORD_AUDIO '
            '/ xcrun simctl privacy <udid> grant microphone <bundle>), so the '
            'native permission dialog would block the outgoing call.',
          );
          return;
        }
        await CleanupHelper.seedConversation(text: 'Call seed $stamp');
        await launch(tester);
        await ScreenReach.openConversationNamed(tester, bName);

        // cometchat_call_buttons.dart: IconButton(tooltip: voiceCall) =
        // 'Voice call'.
        final voice = find.descendant(
          of: find.byType(CometChatMessageHeader),
          matching: find.byTooltip('Voice call'),
        );
        expect(
          voice,
          findsOneWidget,
          reason: 'The 1:1 header should offer a voice call button',
        );
        await tester.tap(voice);

        final outgoing = find.byType(CometChatOutgoingCall);
        if (!await pumpUntilFound(
          tester,
          outgoing,
          timeout: const Duration(seconds: 25),
        )) {
          fail(
            'Tapping "Voice call" never showed the outgoing call screen '
            '(initiateCall failed, or calling is disabled for this app).',
          );
        }

        // cometchat_outgoing_call.dart: IconButton(tooltip: decline) =
        // 'Decline' → OutgoingCallBloc.add(CancelCall()).
        final decline = find.descendant(
          of: outgoing,
          matching: find.byTooltip('Decline'),
        );
        expect(
          decline,
          findsOneWidget,
          reason: 'The outgoing call screen should offer a cancel button',
        );
        await tester.tap(decline);

        expect(
          await pumpUntilGone(
            tester,
            outgoing,
            timeout: const Duration(seconds: 20),
          ),
          isTrue,
          reason: 'Cancelling should dismiss the outgoing call screen',
        );
        await pumpFor(tester, const Duration(seconds: 3));
        // Exactly ONE route must have been popped: still on B's messages
        // screen, not bounced through to HomeScreen.
        expect(
          find.byType(MessagesScreen),
          findsOneWidget,
          reason: 'Cancelling a call should land back on the messages screen',
        );
        expect(
          find.descendant(
            of: find.byType(CometChatMessageHeader),
            matching: find.text(bName),
          ),
          findsWidgets,
          reason:
              'It should be the same conversation the call was started from',
        );
        expect(
          find.byType(CometChatMessageComposer),
          findsOneWidget,
          reason: 'The composer should be usable again after the call ends',
        );
      },
    );

    testWidgets('E2E-198: Logout returns to the login screen and ends the session', (
      tester,
    ) async {
      await launch(tester);

      // home_screen.dart `_buildProfileMenu`: PopupMenuButton<String> with a
      // '/logout' item whose child is Text('Logout').
      final menu = find.byType(PopupMenuButton<String>);
      expect(
        menu,
        findsOneWidget,
        reason: 'HomeScreen should show the profile menu',
      );
      await tester.tap(menu);
      final logout = find.text('Logout');
      if (!await pumpUntilFound(
        tester,
        logout,
        timeout: const Duration(seconds: 5),
      )) {
        fail('The profile menu has no "Logout" item.');
      }
      await tester.tap(logout.first);

      final onLogin = await pumpUntilFound(
        tester,
        find.byType(LoginScreen),
        timeout: const Duration(seconds: 25),
      );
      if (!onLogin) {
        // Tell the two failure modes apart for whoever reads the red run.
        final sessionEnded = CometChatUIKit.loggedInUser == null;
        fail(
          sessionEnded
              ? 'APP BUG: the SDK session ended (loggedInUser == null) but the '
                    'app never navigated to LoginScreen — the navigation inside '
                    'the logout onSuccess callback did not happen (any exception '
                    'there is swallowed by CometChatUIKit.logout).'
              : 'Logout never completed: 25s after tapping Logout the SDK '
                    'still has a logged-in user and the app is still on Home '
                    '(CometChat.logout failed or never returned; the sample app '
                    'only debugPrints that error).',
        );
      }
      expect(
        find.byType(BottomNavigationBar),
        findsNothing,
        reason:
            'HomeScreen must be gone after logout '
            '(pushAndRemoveUntil clears the stack)',
      );
      expect(
        find.widgetWithText(TextFormField, 'Enter the UID'),
        findsOneWidget,
        reason: 'The login form should be ready for the next user',
      );
      expect(
        CometChatUIKit.loggedInUser,
        isNull,
        reason: 'Logout should end the SDK session, not only navigate',
      );
    });
  });
}
