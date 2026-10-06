/// A group meeting on screen is not "a call in progress", as on Android.
///
/// Android sets no flag for a meeting — its `CallingState.isActiveMeeting` is
/// never set to true — so during one an incoming 1-on-1 call rings instead
/// of being answered with busy. This used to count any call screen, meetings
/// included. (Since round 5 a meeting on screen does stop another call or
/// meeting from being started or joined, through
/// `ActiveCallTracker.isInCallOrMeeting`: the owner's D06 A.)
///
/// The meeting is shown for real, through `CallScreenOverlay.show` with
/// `CallWorkFlow.directCalling` on a mounted navigator, as the call buttons
/// and the meeting bubble show it.
///
///   flutter test test/call_ui/meeting_not_active_call_test.dart
library;

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show SessionSettingsBuilder;
import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_display_incoming_call_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_extension_constants.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/call_bloc_harness.dart';

Call _call(String sessionId) => Call(
  id: 1,
  sessionId: sessionId,
  callStatus: 'initiated',
  callInitiator: User(uid: 'peer', name: 'Peer'),
  receiverUid: 'me',
  type: 'audio',
  receiverType: 'user',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCallOperationsDataSource dataSource;
  final service = CallEventService.instance;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    await installCallJoinDefaults();
    service.activeCall = null;
    ActiveCallTracker.ringingCall = null;
    ActiveCallTracker.busyRejectDelay = Duration.zero;
    // Every test here rings the same session: one an earlier test finished
    // (in any order: the suite runs with random seeds) would count as a
    // late copy (finishedLately) and neither ring nor be answered busy.
    ActiveCallTracker.forgetFinishedCalls();
  });

  tearDown(() async {
    IncomingCallOverlay.dismiss();
    CallScreenOverlay.dismiss();
    service.activeCall = null;
    ActiveCallTracker.ringingCall = null;
    ActiveCallTracker.busyRejectDelay = const Duration(seconds: 2);
    ActiveCallTracker.forgetFinishedCalls();
    removeCallJoinDefaults();
    SoundChannelSpy.remove();
    CallStateService.instance.setActiveCallValue(false);
    await CallOperationsServiceLocator.instance.reset();
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  /// Shows a group meeting the way the call buttons and the meeting bubble
  /// do.
  Future<void> showMeeting(WidgetTester tester) async {
    await mountCallNavigator(tester);
    CallScreenOverlay.show(
      sessionId: 'meeting',
      sessionSettingsBuilder: SessionSettingsBuilder(),
      callWorkFlow: CallWorkFlow.directCalling,
    );
    await tester.pump();
    expect(CallScreenOverlay.isShowing, isTrue);
  }

  testWidgets('a meeting on screen is not a call in progress', (tester) async {
    await showMeeting(tester);

    expect(ActiveCallTracker.callScreenWorkFlow, CallWorkFlow.directCalling);
    expect(ActiveCallTracker.hasActiveCall, isFalse);
  });

  testWidgets('an incoming call during a meeting rings instead of busy', (
    tester,
  ) async {
    await showMeeting(tester);

    service.onIncomingCallReceived(_call('incoming'));
    await tester.pump(const Duration(milliseconds: 40));

    expect(dataSource.rejectCallCount, 0);
    expect(ActiveCallTracker.ringingCall?.sessionId, 'incoming');
  });

  group('P3-C21: answering a 1-on-1 call during a meeting', () {
    /// The meeting on screen and joined, then the incoming call answered on
    /// its banner's bloc.
    Future<IncomingCallBloc> acceptDuringMeeting(WidgetTester tester) async {
      await showMeeting(tester);
      await tester.pump();
      expect(dataSource.calls, contains('startSession:meeting'));
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: _call('incoming'),
        disableSoundForCalls: true,
      );
      addTearDown(bloc.close);
      bloc.add(const AcceptCall());
      for (int i = 0; i < 4; i++) {
        await tester.pump();
      }
      return bloc;
    }

    testWidgets('the meeting is left first, then the call joins', (
      tester,
    ) async {
      await acceptDuringMeeting(tester);

      final List<String> calls = dataSource.calls;
      expect(calls, contains('startSession:incoming'));
      expect(
        calls.indexOf('endSession'),
        lessThan(calls.indexOf('startSession:incoming')),
      );
      expect(
        calls.indexOf('acceptCall:incoming'),
        lessThan(calls.indexOf('endSession')),
      );
      expect(ActiveCallTracker.callScreenSessionId, 'incoming');
      expect(ActiveCallTracker.callScreenWorkFlow, CallWorkFlow.defaultCalling);
    });

    testWidgets("the meeting's own screen, replaced, leaves nothing again and "
        "leaves the call's state alone", (tester) async {
      await acceptDuringMeeting(tester);
      await tester.pump();

      // One leave: the accept's. The meeting's bloc closed as a replaced
      // screen, which leaves nothing (the session is the call's now).
      expect(dataSource.endSessionCount, 1);
      expect(CallStateService.instance.isActiveCall.value, isTrue);
      expect(ActiveCallTracker.hasActiveCall, isTrue);
    });

    testWidgets('no meeting on screen: nothing is left before the join', (
      tester,
    ) async {
      await mountCallNavigator(tester);
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: _call('incoming'),
        disableSoundForCalls: true,
      );
      addTearDown(bloc.close);
      bloc.add(const AcceptCall());
      for (int i = 0; i < 4; i++) {
        await tester.pump();
      }

      expect(dataSource.calls, contains('startSession:incoming'));
      expect(dataSource.endSessionCount, 0);
    });
  });

  testWidgets('a 1-on-1 call screen, by contrast, is a call in progress', (
    tester,
  ) async {
    await mountCallNavigator(tester);
    CallScreenOverlay.show(
      sessionId: 'one-on-one',
      sessionSettingsBuilder: SessionSettingsBuilder(),
    );
    await tester.pump();

    expect(ActiveCallTracker.hasActiveCall, isTrue);
  });
}
