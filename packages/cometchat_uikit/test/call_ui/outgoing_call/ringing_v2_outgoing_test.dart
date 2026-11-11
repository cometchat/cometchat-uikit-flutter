/// Ringing v2, the caller's side: a call placed with the Calls SDK
/// (`CometChatCalls.initiateCall`) is followed from the session it prepared,
/// not from the chat SDK's deprecated call listener.
///
/// * `OutgoingCallWatch`: the callee's device rings (`onParticipantConnected`),
///   answers (`onParticipantJoined`), or the call ends before the join
///   (`onConnectionClosed`, then the call's status from the server); and the
///   status read while it rings, in case an event does not come.
/// * `OutgoingCallBloc` on those: "ringing" in its state, the call screen on
///   an answer, the screen closed and the record released on a decline.
/// * `CallButtonsBloc`: a call to a user is placed as an audio or video call,
///   with the settings its session is to be prepared with on it, and the
///   buttons come back once its record is released.
/// * `RingingCallMapping`: the chat SDK `Call` built from what the Calls SDK
///   returns.
///
///   flutter test test/call_ui/outgoing_call/ringing_v2_outgoing_test.dart
library;

import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show
        CallSession,
        CallType,
        IncomingCallListener,
        InitiatedCall,
        Participant,
        ParticipantEventListeners,
        ReceiverType,
        SessionStatusListeners,
        SessionType;
import 'package:cometchat_chat_uikit/call_ui/src/call_buttons/bloc/call_buttons_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_buttons/bloc/call_buttons_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/cometchat_outgoing_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_events.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/call_prepare_settings.dart';
import 'package:cometchat_chat_uikit/src/outgoing_call_watch.dart';
import 'package:cometchat_chat_uikit/src/ringing_call_mapping.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show CometChatUIKit;
import 'package:cometchat_sdk/cometchat_sdk.dart' show Call, Group, User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/call_bloc_harness.dart';

/// A Calls SDK session that keeps the listeners put on it, so a test can
/// play its events.
class _FakeSession extends Fake implements CallSession {
  final List<SessionStatusListeners> status = <SessionStatusListeners>[];
  final List<ParticipantEventListeners> participants =
      <ParticipantEventListeners>[];

  @override
  void addSessionStatusListener(SessionStatusListeners listener) =>
      status.add(listener);

  @override
  void removeSessionStatusListener(SessionStatusListeners listener) =>
      status.remove(listener);

  @override
  void addParticipantEventListener(ParticipantEventListeners listener) =>
      participants.add(listener);

  @override
  void removeParticipantEventListener(ParticipantEventListeners listener) =>
      participants.remove(listener);

  void connected(String uid) {
    for (final l in List.of(participants)) {
      l.onParticipantConnected(Participant(uid: uid));
    }
  }

  void joined(String uid) {
    for (final l in List.of(participants)) {
      l.onParticipantJoined(Participant(uid: uid));
    }
  }

  void closed() {
    for (final l in List.of(status)) {
      l.onConnectionClosed();
    }
  }

  /// This call's prepared session connected.
  void sessionConnected() {
    for (final l in List.of(status)) {
      l.onConnected();
    }
  }
}

/// What a watch reported, in order.
class _Reports {
  final List<String> all = <String>[];

  OutgoingCallWatch watch({String? calleeUid = 'peer'}) => OutgoingCallWatch(
    sessionId: 's1',
    callerUid: 'me',
    calleeUid: calleeUid,
    onRinging: () => all.add('ringing'),
    onAnswered: () => all.add('answered'),
    onEnded: (status) => all.add('ended:$status'),
  );
}

Call _placed({String sessionId = 'session_1'}) => Call(
  sessionId: sessionId,
  callStatus: 'initiated',
  receiverUid: 'peer',
  receiverType: 'user',
  type: 'audio',
  callInitiator: User(uid: 'me', name: 'Me'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSession session;
  late List<String> fetched;
  late String? serverStatus;
  late Map<String, IncomingCallListener> incoming;

  /// The terminal push for [sessionId] reaching the Calls SDK with [reason].
  void pushEnded(String sessionId, String reason) {
    for (final l in List.of(incoming.values)) {
      l.onIncomingCallEnded(InitiatedCall(sessionId: sessionId), reason);
    }
  }

  setUp(() {
    session = _FakeSession();
    fetched = <String>[];
    serverStatus = null;
    incoming = <String, IncomingCallListener>{};
    OutgoingCallWatch.addIncomingCallListener = (id, l) => incoming[id] = l;
    OutgoingCallWatch.removeIncomingCallListener = incoming.remove;
    OutgoingCallWatch.pushWait = Duration.zero;
    OutgoingCallWatch.session = () => session;
    OutgoingCallWatch.fetchStatus = (sessionId) async {
      fetched.add(sessionId);
      return serverStatus;
    };
  });

  tearDown(OutgoingCallWatch.debugReset);

  group('OutgoingCallWatch', () {
    test('the callee preparing the session is ringing, once; the caller\'s '
        'own and anyone else\'s are not', () {
      final reports = _Reports();
      reports.watch().start();

      session.connected('me');
      session.connected('stranger');
      session.connected('peer');
      session.connected('peer');

      expect(reports.all, <String>['ringing']);
    });

    test('the callee joining is the answer, and nothing after it counts', () {
      final reports = _Reports();
      reports.watch().start();

      session.joined('me');
      session.joined('peer');
      session.closed();
      session.joined('peer');

      expect(reports.all, <String>['answered']);
      expect(fetched, isEmpty);
    });

    test('a group call is answered by anyone but the caller', () {
      final reports = _Reports();
      reports.watch(calleeUid: null).start();

      session.joined('me');
      session.joined('member');

      expect(reports.all, <String>['answered']);
    });

    for (final status in ['rejected', 'busy', 'cancelled', 'unanswered']) {
      test('the session closing before the join ends it as the server '
          'says: $status', () async {
        final reports = _Reports();
        reports.watch().start();
        serverStatus = status;

        session.sessionConnected();
        session.closed();
        await pumpEventQueue();

        expect(fetched, <String>['s1']);
        expect(reports.all, <String>['ended:$status']);
      });
    }

    for (final status in ['ongoing', 'initiated', null]) {
      test('closed while the server says $status: ended, not an answer (the '
          'callee\'s ringer prepared the session)', () async {
        final reports = _Reports();
        reports.watch().start();
        serverStatus = status;

        session.sessionConnected();
        session.closed();
        await pumpEventQueue();

        expect(reports.all, <String>['ended:ended']);
      });
    }

    test('a close before this call\'s session connected is the last call\'s: '
        'ignored', () async {
      final reports = _Reports();
      reports.watch().start();
      serverStatus = 'rejected';

      session.closed();
      await pumpEventQueue();

      expect(fetched, isEmpty);
      expect(reports.all, isEmpty);
    });

    for (final (reason, status) in [
      ('rejected', 'rejected'),
      ('declined', 'rejected'),
      ('busy', 'busy'),
      ('cancelled', 'cancelled'),
      ('unanswered', 'unanswered'),
      ('ended', 'ended'),
    ]) {
      test('the terminal push ends it with no room event: $reason', () {
        final reports = _Reports();
        reports.watch().start();

        pushEnded('s1', reason);

        expect(reports.all, <String>['ended:$status']);
        expect(fetched, isEmpty);
      });
    }

    test('a terminal push for another call, or one that is an answer, is '
        'ignored', () {
      final reports = _Reports();
      reports.watch().start();

      pushEnded('other', 'rejected');
      pushEnded('s1', 'ongoing');
      pushEnded('s1', 'answeredElsewhere');

      expect(reports.all, isEmpty);
    });

    test('the push arriving while a close waits for it wins: its reason, and '
        'no read', () async {
      OutgoingCallWatch.pushWait = const Duration(hours: 1);
      final reports = _Reports();
      final watch = reports.watch()..start();
      serverStatus = 'rejected';

      session.sessionConnected();
      session.closed();
      pushEnded('s1', 'busy');
      await pumpEventQueue();

      expect(reports.all, <String>['ended:busy']);
      expect(fetched, isEmpty);
      watch.stop();
    });

    test('stopped: its incoming call listener is removed', () {
      final reports = _Reports();
      final watch = reports.watch()..start();
      expect(incoming, hasLength(1));

      watch.stop();
      pushEnded('s1', 'rejected');

      expect(incoming, isEmpty);
      expect(reports.all, isEmpty);
    });

    testWidgets('nothing is read while it rings', (tester) async {
      final reports = _Reports();
      final watch = reports.watch()..start();
      serverStatus = 'ongoing';

      await tester.pump(const Duration(seconds: 30));

      expect(fetched, isEmpty);
      expect(reports.all, isEmpty);
      watch.stop();
    });

    test('stopped: its listeners are off the session and nothing is '
        'reported', () async {
      final reports = _Reports();
      final watch = reports.watch()..start();
      expect(session.status, hasLength(1));
      expect(session.participants, hasLength(1));

      watch.stop();
      session.connected('peer');
      session.joined('peer');

      expect(session.status, isEmpty);
      expect(session.participants, isEmpty);
      expect(reports.all, isEmpty);
    });
  });

  group('OutgoingCallBloc on the prepared session', () {
    late FakeCallOperationsDataSource dataSource;
    late List<Exception> errors;

    setUp(() async {
      await CallOperationsServiceLocator.instance.reset();
      dataSource = FakeCallOperationsDataSource();
      CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
      errors = <Exception>[];
    });

    tearDown(() async {
      SoundChannelSpy.remove();
      removeCallJoinDefaults();
      await CallOperationsServiceLocator.instance.reset();
      CallStateService.instance.setActiveOutgoingValue(false);
      CallEventService.instance.activeCall = null;
      CallScreenOverlay.dismiss();
      CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
    });

    OutgoingCallBloc screenBloc() => CometChatCallEvents
        .callEventsListener
        .values
        .whereType<OutgoingCallBloc>()
        .single;

    Future<void> ring(WidgetTester tester) async {
      await installCallJoinDefaults();
      await mountCallNavigator(tester);
      CallEventService.instance.activeCall = _placed();
      unawaited(
        CallNavigationContext.navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => CometChatOutgoingCall(
              call: _placed(),
              user: User(uid: 'peer', name: 'Peer'),
              onError: errors.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CometChatOutgoingCall), findsOneWidget);
    }

    testWidgets('it listens on the session from the start', (tester) async {
      await ring(tester);

      expect(session.participants, hasLength(1));
      expect(session.status, hasLength(1));
    });

    testWidgets('the callee\'s device ringing: the state says so and the '
        'screen goes from "Calling..." to "Ringing..."', (tester) async {
      await ring(tester);
      expect(screenBloc().state.isCalleeRinging, isFalse);
      expect(find.text('Calling...'), findsOneWidget);
      expect(find.text('Ringing...'), findsNothing);

      session.connected('peer');
      await tester.pump();
      // A frame more for the screen to show the new state.
      await tester.pump();

      expect(screenBloc().state.isCalleeRinging, isTrue);
      expect(find.byType(CometChatOutgoingCall), findsOneWidget);
      expect(find.text('Ringing...'), findsOneWidget);
      expect(find.text('Calling...'), findsNothing);
    });

    testWidgets('the callee joining: the call screen opens and joins the '
        'call, and the listeners come off', (tester) async {
      await ring(tester);

      session.joined('peer');
      await tester.pumpAndSettle();

      expect(find.byType(CometChatOutgoingCall), findsNothing);
      expect(CallScreenOverlay.isShowing, isTrue);
      expect(dataSource.calls, contains('startSession:session_1'));
      expect(session.participants, isEmpty);
      expect(errors, isEmpty);
    });

    testWidgets('a decline: the screen closes, the record is released, and '
        'nothing goes to the server', (tester) async {
      await ring(tester);
      serverStatus = 'rejected';

      session.sessionConnected();
      session.closed();
      await tester.pumpAndSettle();

      expect(find.byType(CometChatOutgoingCall), findsNothing);
      expect(CallScreenOverlay.isShowing, isFalse);
      expect(CallEventService.instance.activeCall, isNull);
      expect(dataSource.calls, isEmpty);
      expect(errors, isEmpty);
    });

    testWidgets('End sends the cancel (on the Calls SDK since ringing v2) '
        'and announces the call it returns', (tester) async {
      await ring(tester);
      final spy = CallEventRecorder('ringing_v2_end');
      addTearDown(spy.dispose);

      screenBloc().add(const CancelCall());
      await tester.pumpAndSettle();
      final rejected = spy.rejected;

      expect(dataSource.calls, <String>['rejectCall:session_1:cancelled']);
      expect(rejected.single.sessionId, 'session_1');
      expect(find.byType(CometChatOutgoingCall), findsNothing);
      expect(session.participants, isEmpty);
    });
  });

  group('CallButtonsBloc placing a call', () {
    late FakeCallOperationsDataSource dataSource;

    setUp(() async {
      await CallOperationsServiceLocator.instance.reset();
      dataSource = FakeCallOperationsDataSource()
        ..placedSessionId = 'placed-v2';
      CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
      CometChatUIKit.loggedInUser = testMe;
    });

    tearDown(() async {
      SoundChannelSpy.remove();
      removeCallJoinDefaults();
      CometChatUIKit.loggedInUser = null;
      await CallOperationsServiceLocator.instance.reset();
      CallStateService.instance.setActiveOutgoingValue(false);
      CallEventService.instance.activeCall = null;
      CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
      ActiveCallTracker.debugResetPlacingCall();
    });

    for (final video in [false, true]) {
      testWidgets('a ${video ? 'video' : 'voice'} call is placed with that '
          'type and the settings it is prepared with', (tester) async {
        await installCallJoinDefaults();
        await mountCallNavigator(tester);
        final bloc = CallButtonsBloc(
          user: User(uid: 'peer', name: 'Peer'),
        );

        bloc.add(video ? const InitiateVideoCall() : const InitiateVoiceCall());
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(dataSource.calls.first, 'initiateCall:peer');
        final placed = dataSource.initiatedCalls.single;
        expect(placed.type, video ? CallType.video : CallType.audio);
        expect(placed.receiverType, ReceiverType.user);
        expect((placed.receiver as User?)?.uid, 'peer');
        final settings = CallPrepareSettings.of(placed);
        expect(settings, isNotNull);
        expect(settings!.type, video ? SessionType.video : SessionType.audio);
        await tester.runAsync(bloc.close);
      });
    }

    testWidgets('the buttons come back once the placed call\'s record is '
        'released, and not for another call', (tester) async {
      await installCallJoinDefaults();
      await mountCallNavigator(tester);
      final bloc = CallButtonsBloc(
        user: User(uid: 'peer', name: 'Peer'),
      );
      bloc.add(const InitiateVoiceCall());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(bloc.state.isCallInProgress, isTrue);

      ActiveCallTracker.release('someone-else');
      await tester.pump();
      expect(bloc.state.isCallInProgress, isTrue);

      ActiveCallTracker.release('placed-v2');
      await tester.pump();
      expect(bloc.state.isCallInProgress, isFalse);
      expect(bloc.state.isDisabled, isFalse);
      await tester.runAsync(bloc.close);
    });
  });

  group('RingingCallMapping', () {
    final placed = InitiatedCall(
      sessionId: 's9',
      messageId: '42',
      conversationId: 'me_user_peer',
      sender: 'me',
      receiver: 'peer',
      receiverType: ReceiverType.user,
      type: CallType.video,
      initiatedAt: 1700000000000,
      callerName: 'Me',
    );

    test('a placed call keeps the server\'s message, session and parties', () {
      final peer = User(uid: 'peer', name: 'Peer');
      final call = RingingCallMapping.fromInitiated(placed, receiver: peer);

      expect(call.id, 42);
      expect(call.sessionId, 's9');
      expect(call.callStatus, 'initiated');
      expect(call.type, 'video');
      expect(call.receiverType, 'user');
      expect(call.receiverUid, 'peer');
      expect(call.conversationId, 'me_user_peer');
      expect(call.category, 'call');
      expect((call.callInitiator as User).uid, 'me');
      expect((call.callInitiator as User).name, 'Me');
      expect(call.sender?.uid, 'me');
      expect(call.callReceiver, same(peer));
      expect(call.receiver, same(peer));
      expect(
        call.initiatedAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
    });

    test('the given caller and a group receiver are used as they are', () {
      final me = User(uid: 'me', name: 'Me Myself');
      final group = Group(guid: 'g1', name: 'G', type: 'public');
      final call = RingingCallMapping.fromInitiated(
        placed,
        caller: me,
        receiver: group,
      );

      expect(call.callInitiator, same(me));
      expect(call.callReceiver, same(group));
    });

    test('a status change keeps the call and claims no call message', () {
      final call = RingingCallMapping.fromInitiated(placed);

      final declined = RingingCallMapping.withStatus(call, 'rejected');

      expect(declined.id, 0);
      expect(declined.callStatus, 'rejected');
      expect(declined.sessionId, 's9');
      expect(declined.callInitiator, same(call.callInitiator));
    });
  });
}
