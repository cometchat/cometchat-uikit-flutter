/// Answering a 1-on-1 call during a group meeting (round 3, P3-C21; round 4
/// review: correctness 2 and 6, regression 9, probe D, test gaps R32-R34).
///
/// The accept leaves the meeting first (at most 3 s), then the call's screen
/// replaces the meeting's. What the review found around that leave:
///
/// * The call given up (or a logout) during the leave left the meeting's
///   screen up with its session gone: black, with back doing nothing. It
///   is closed now.
/// * A meeting still connecting kept waiting for its join: one that landed
///   during the leave mounted its view, which joined natively after the
///   leave, under the new call. The meeting's screen stops owning the call
///   before the leave now, so its late join starts nothing.
/// * The meeting's own "left" can arrive after the call's screen has
///   started joining, and ended the new call. The call's screen takes a
///   session end or a participant event before its own native join for the
///   meeting's, and ignores it (on Android it starts its ongoing-call
///   service again, which the plugin stops on every "left").
///
///   flutter test test/call_ui/meeting_accept_test.dart
@Timeout(Duration(seconds: 60))
library;

import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show
        ButtonClickListeners,
        CallSession,
        Participant,
        ParticipantEventListeners,
        SessionSettingsBuilder,
        SessionStatusListeners;
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_display_incoming_call_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_extension_constants.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/calls_lifecycle.dart';

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

/// A data source whose leave can be held ([leaveGate]); `leave asked` is
/// recorded as it is asked for.
class _GatedLeave extends FakeCallOperationsDataSource {
  Completer<void>? leaveGate;

  @override
  Future<void> endSession() async {
    calls.add('leave asked');
    await leaveGate?.future;
    await super.endSession();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _GatedLeave dataSource;
  final CallEventService service = CallEventService.instance;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = _GatedLeave();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    await installCallJoinDefaults();
    service.activeCall = null;
    ActiveCallTracker.ringingCall = null;
    // Every test answers the same session: one that another test finished
    // would count as a late copy (finishedLately) and never ring.
    ActiveCallTracker.forgetFinishedCalls();
    CometChatUIKit.loggedInUser = User(uid: 'me', name: 'Me');
  });

  tearDown(() async {
    IncomingCallOverlay.dismiss();
    CallScreenOverlay.dismiss();
    service.activeCall = null;
    ActiveCallTracker.ringingCall = null;
    ActiveCallTracker.forgetFinishedCalls();
    CometChatUIKit.loggedInUser = null;
    removeCallJoinDefaults();
    SoundChannelSpy.remove();
    CallStateService.instance.setActiveCallValue(false);
    await CallOperationsServiceLocator.instance.reset();
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  /// The meeting on screen; with [joinHeld] its join stays on its way (the
  /// meeting still connecting), and the completer lands it.
  Future<Completer<Widget>?> showMeeting(
    WidgetTester tester, {
    bool joinHeld = false,
  }) async {
    await mountCallNavigator(tester);
    Completer<Widget>? meetingJoin;
    if (joinHeld) {
      meetingJoin = Completer<Widget>();
      dataSource.onStartSession = (String sid) => sid == 'meeting'
          ? meetingJoin!.future
          : Future<Widget>.value(const FakeCallingWidget());
    }
    CallScreenOverlay.show(
      sessionId: 'meeting',
      sessionSettingsBuilder: SessionSettingsBuilder(),
      callWorkFlow: CallWorkFlow.directCalling,
    );
    await tester.pump();
    await tester.pump();
    expect(dataSource.calls, contains('startSession:meeting'));
    return meetingJoin;
  }

  /// Answers `incoming` on its banner's bloc.
  Future<IncomingCallBloc> accept(WidgetTester tester) async {
    final IncomingCallBloc bloc = IncomingCallBloc(
      call: _call('incoming'),
      disableSoundForCalls: true,
    );
    addTearDown(bloc.close);
    // A test that fails with the meeting's leave still held must not hang
    // in the close above: the leave goes through first.
    addTearDown(() {
      final Completer<void>? gate = dataSource.leaveGate;
      if (gate != null && !gate.isCompleted) gate.complete();
    });
    bloc.add(const AcceptCall());
    for (int i = 0; i < 4; i++) {
      await tester.pump();
    }
    return bloc;
  }

  bool meetingScreenUp() =>
      CallScreenOverlay.isShowing &&
      ActiveCallTracker.callScreenSessionId == 'meeting';

  void sdkSession(void Function(SessionStatusListeners l) event) {
    for (final SessionStatusListeners l in List.of(
      CallSession.getInstance()!.sessionStatusListeners,
    )) {
      event(l);
    }
  }

  void sdkParticipants(List<Participant> participants) {
    for (final ParticipantEventListeners l in List.of(
      CallSession.getInstance()!.participantEventListeners,
    )) {
      l.onParticipantListChanged(participants);
    }
  }

  List<Object?> launches() =>
      CallsPluginChannelRecorder.argumentsOf('launchOngoingCallService');

  testWidgets('probe D: the caller hangs up while the meeting is being left: '
      "the meeting's screen goes too, and the app is freed", (
    WidgetTester tester,
  ) async {
    await showMeeting(tester);
    dataSource.leaveGate = Completer<void>();
    await accept(tester);
    expect(dataSource.calls, contains('acceptCall:incoming'));
    expect(dataSource.calls, contains('leave asked'));

    service.onCallEndedMessageReceived(_call('incoming'));
    dataSource.leaveGate!.complete();
    for (int i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(meetingScreenUp(), isFalse);
    expect(CallScreenOverlay.isShowing, isFalse);
    expect(dataSource.calls, isNot(contains('startSession:incoming')));
    expect(CallStateService.instance.isActiveCall.value, isFalse);
  });

  testWidgets('R33: a logout while the meeting is being left: no call screen '
      'is opened for the accepted call, and the meeting is gone', (
    WidgetTester tester,
  ) async {
    await showMeeting(tester);
    dataSource.leaveGate = Completer<void>();
    await accept(tester);

    CallsLifecycle.tearDownLocalCalls();
    dataSource.leaveGate!.complete();
    for (int i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(CallScreenOverlay.isShowing, isFalse);
    expect(dataSource.calls, isNot(contains('startSession:incoming')));
    expect(CallStateService.instance.isActiveCall.value, isFalse);
  });

  testWidgets('R32: a meeting leave that never returns: the call joins after '
      '3 s anyway', (WidgetTester tester) async {
    await showMeeting(tester);
    dataSource.leaveGate = Completer<void>();
    await accept(tester);
    await tester.pump(const Duration(milliseconds: 2900));
    expect(dataSource.calls, isNot(contains('startSession:incoming')));

    await tester.pump(const Duration(milliseconds: 200));
    for (int i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(dataSource.calls, contains('startSession:incoming'));
    expect(ActiveCallTracker.callScreenSessionId, 'incoming');
    dataSource.leaveGate!.complete();
  });

  testWidgets('correctness 6: a meeting still connecting whose join lands '
      'during the leave starts nothing for it', (WidgetTester tester) async {
    final Completer<Widget> meetingJoin = (await showMeeting(
      tester,
      joinHeld: true,
    ))!;
    dataSource.leaveGate = Completer<void>();
    await accept(tester);

    meetingJoin.complete(const FakeCallingWidget());
    await tester.pump();
    await tester.pump();
    expect(launches(), isEmpty, reason: "the meeting's join started nothing");
    expect(find.byType(FakeCallingWidget), findsNothing);

    dataSource.leaveGate!.complete();
    for (int i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(ActiveCallTracker.callScreenSessionId, 'incoming');
    expect(launches(), hasLength(1), reason: "the call's own");
  });

  group("regression 9: the meeting's late events reach the call's screen", () {
    /// The meeting left, the call's screen up and joined (its view back),
    /// but its native join not reported yet.
    Future<void> answerOverMeeting(WidgetTester tester) async {
      await showMeeting(tester);
      CallsPluginChannelRecorder.calls.clear();
      await accept(tester);
      await tester.pump();
      expect(ActiveCallTracker.callScreenSessionId, 'incoming');
      expect(find.byType(FakeCallingWidget), findsOneWidget);
      expect(launches(), hasLength(1));
    }

    testWidgets("the meeting's late \"left\" is ignored: the call stays, and "
        'its service is started again', (WidgetTester tester) async {
      await answerOverMeeting(tester);

      sdkSession((SessionStatusListeners l) => l.onSessionLeft());
      await tester.pump(Duration.zero);
      await tester.pump();

      expect(ActiveCallTracker.callScreenSessionId, 'incoming');
      expect(CallScreenOverlay.isShowing, isTrue);
      expect(dataSource.endSessionCount, 1, reason: "the meeting's leave");
      expect(dataSource.endCallCount, 0);
      expect(launches(), hasLength(2));
    });

    testWidgets("once the call joined natively, its own \"left\" ends it", (
      WidgetTester tester,
    ) async {
      await answerOverMeeting(tester);
      sdkSession((SessionStatusListeners l) => l.onSessionJoined());
      await tester.pump();

      sdkSession((SessionStatusListeners l) => l.onSessionLeft());
      await tester.pump(Duration.zero);
      await tester.pump();

      expect(CallScreenOverlay.isShowing, isFalse);
      expect(dataSource.endSessionCount, 2);
    });

    testWidgets("the meeting's members do not arm the call's peer-left rule", (
      WidgetTester tester,
    ) async {
      await answerOverMeeting(tester);

      sdkParticipants(<Participant>[
        Participant(uid: 'me'),
        Participant(uid: 'member'),
      ]);
      await tester.pump();
      sdkParticipants(<Participant>[]);
      await tester.pump();
      await tester.pump();
      expect(dataSource.endCallCount, 0);
      expect(CallScreenOverlay.isShowing, isTrue);

      // Its own join, then its own peer, who then leaves: the rule ends it.
      sdkSession((SessionStatusListeners l) => l.onSessionJoined());
      await tester.pump();
      sdkParticipants(<Participant>[
        Participant(uid: 'me'),
        Participant(uid: 'peer'),
      ]);
      await tester.pump();
      sdkParticipants(<Participant>[]);
      await tester.pump(Duration.zero);
      await tester.pump();

      expect(dataSource.endCallCount, 1);
    });

    testWidgets('End still works in the window', (WidgetTester tester) async {
      await answerOverMeeting(tester);

      for (final ButtonClickListeners l in List.of(
        CallSession.getInstance()!.buttonClickListeners,
      )) {
        l.onLeaveSessionButtonClicked();
      }
      await tester.pump(Duration.zero);
      await tester.pump();

      expect(CallScreenOverlay.isShowing, isFalse);
      expect(dataSource.endCallCount, 1);
    });
  });

  group('the session left before a join counts for the next join only', () {
    tearDown(() => ActiveCallTracker.now = DateTime.now);

    test('taken once, then forgotten', () {
      ActiveCallTracker.noteLeftBeforeJoin('meeting');
      expect(ActiveCallTracker.takeLeftBeforeJoin(), 'meeting');
      expect(ActiveCallTracker.takeLeftBeforeJoin(), isNull);
    });

    test('older than 15 s: not counted', () {
      DateTime clock = DateTime(2026, 10, 1, 12);
      ActiveCallTracker.now = () => clock;
      ActiveCallTracker.noteLeftBeforeJoin('meeting');
      clock = clock.add(const Duration(seconds: 16));
      expect(ActiveCallTracker.takeLeftBeforeJoin(), isNull);
    });

    test('a logout forgets it', () {
      ActiveCallTracker.noteLeftBeforeJoin('meeting');
      CallsLifecycle.tearDownLocalCalls();
      expect(ActiveCallTracker.takeLeftBeforeJoin(), isNull);
    });
  });
}
