/// Call-flow parity with the Kotlin UIKit (cometchat-team/uikit-android
/// dev-v6), rows 1, 5, 6, 7 and 12 of the parity matrix:
///
///  1. A call cannot be started while one is active (ACTIVE_CALL).
///  5. A decline that fails on the server is still announced as rejected.
///  6. A caller's cancel dismisses the incoming call only if it is for it.
///  7. A second incoming call during a call is answered with busy.
/// 12. The active call is tracked locally and cleared by session match. The
///     Dart SDK's clearActiveCall is an HTTP call to an endpoint the server
///     does not have, so it is no longer made.
///
/// Rows 1 and 7 make the local record load-bearing, so it is also released
/// wherever a call screen closes for good — a stale record would refuse
/// every later call and bounce every incoming one.
///
///   flutter test test/call_ui/call_flow_parity_test.dart
library;

import 'package:cometchat_chat_uikit/call_ui/src/call_buttons/bloc/call_buttons_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_buttons/bloc/call_buttons_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/calling_configuration.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_display_incoming_call_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_incoming_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_incoming_call_configuration.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show
        CometChatCallEvents,
        CometChatCallEventListener,
        CometChatUIKit,
        Translations,
        UIKitSettingsBuilder;
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/calls_lifecycle.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/call_bloc_harness.dart' show mountCallNavigator;

/// Records what reaches the server. Anything not listed throws, so a change
/// that widens a path fails loudly.
class _FakeDataSource extends Fake implements CallOperationsDataSource {
  final List<(String sessionId, String status)> rejects = [];
  int initiates = 0;
  bool failReject = false;

  @override
  Future<void> waitForCallsSdk() async {}

  @override
  Future<User?> getLoggedInUser() async => _me;

  @override
  Future<Call> rejectCall(String sessionId, String status) async {
    rejects.add((sessionId, status));
    if (failReject) {
      throw CometChatException('ERR_CALL_ENDED', 'The call is ended', '');
    }
    return _call(sessionId, status: status);
  }

  @override
  Future<Call> initiateCall(Call call) async {
    initiates++;
    return call;
  }
}

class _RejectedSpy with CometChatCallEventListener {
  final List<Call> rejected = [];

  @override
  void ccCallRejected(Call call) => rejected.add(call);
}

final _me = User(uid: 'me', name: 'Me');
final _peer = User(uid: 'peer', name: 'Peer');

Call _call(
  String sessionId, {
  int id = 1,
  String status = 'initiated',
  User? initiator,
}) => Call(
  id: id,
  sessionId: sessionId,
  callStatus: status,
  callInitiator: initiator ?? _peer,
  receiverUid: 'me',
  type: 'audio',
  receiverType: 'user',
);

Future<void> _settle([int ms = 40]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeDataSource dataSource;
  final service = CallEventService.instance;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = _FakeDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    CometChatUIKit.loggedInUser = _me;
    service.activeCall = null;
    ActiveCallTracker.ringingCall = null;
    ActiveCallTracker.busyRejectDelay = Duration.zero;
    ActiveCallTracker.forgetFinishedCalls();
  });

  tearDown(() async {
    service.activeCall = null;
    ActiveCallTracker.ringingCall = null;
    CometChatUIKit.loggedInUser = null;
    ActiveCallTracker.busyRejectDelay = const Duration(seconds: 2);
    await CallOperationsServiceLocator.instance.reset();
  });

  // -------------------------------------------------------------------------
  group('row 12 — the active call is local and matched by session', () {
    test('an event about another call leaves the active one alone', () {
      service.activeCall = _call('ours');
      service.onOutgoingCallRejected(_call('someone_elses', id: 99));
      expect((service.activeCall as Call?)?.sessionId, 'ours');
    });

    test('the same call clears it even when its id differs', () {
      // The Call an event carries need not share the stored one's id; the old
      // id match missed and left the record behind.
      service.activeCall = _call('ours', id: 1);
      service.ccCallRejected(_call('ours', id: 777, status: 'rejected'));
      expect(service.activeCall, isNull);
    });

    test('release ignores another session and clears its own', () {
      service.activeCall = _call('ours');
      ActiveCallTracker.release('other');
      expect(service.activeCall, isNotNull);
      ActiveCallTracker.release('ours');
      expect(service.activeCall, isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('row 7 — a second incoming call is answered with busy', () {
    test(
      'rejected as busy while a call is active; the first is kept',
      () async {
        service.activeCall = _call('ongoing');

        service.onIncomingCallReceived(_call('second', id: 2));
        await _settle();

        expect(dataSource.rejects, [('second', 'busy')]);
        expect(
          (service.activeCall as Call?)?.sessionId,
          'ongoing',
          reason: 'the bounced call must never become the active one',
        );
      },
    );

    test('rings normally when no call is active', () async {
      service.onIncomingCallReceived(_call('rings-1'));
      await _settle();

      expect(dataSource.rejects, isEmpty);
      expect(ActiveCallTracker.ringingCall?.sessionId, 'rings-1');
    });

    test('a second call while the first is still ringing is busy', () async {
      // Android's app checks its ringing record (CallManager) as well as the
      // SDK's active call.
      service.onIncomingCallReceived(_call('ringing-a'));
      service.onIncomingCallReceived(_call('ringing-b', id: 2));
      await _settle();

      expect(dataSource.rejects, [('ringing-b', 'busy')]);
      expect(ActiveCallTracker.ringingCall?.sessionId, 'ringing-a');
    });

    test('the same call arriving twice is not answered with busy', () async {
      // Duplicate pushes deliver the same call again — that is not a second
      // call, and bouncing it would reject the call the user is looking at.
      service.onIncomingCallReceived(_call('dup-1'));
      service.onIncomingCallReceived(_call('dup-1'));
      await _settle();

      expect(dataSource.rejects, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Android keeps two records. The chat SDK's active call is set when this
  // device places or answers a call, and an ONGOING event only refreshes it
  // for the same session. The app's CallManager holds the incoming call that
  // is ringing. Call buttons check only the first; the busy check checks both.
  group('the two active-call records, as Android keeps them', () {
    test('a late "ongoing" for a finished call does not bring it back', () {
      // The SDK sends "ongoing" to every listener. Setting the record from it
      // left a finished call active — every later call refused, every
      // incoming one answered with busy — until logout.
      service.onOutgoingCallAccepted(_call('over', status: 'ongoing'));

      expect(service.activeCall, isNull);
      expect(ActiveCallTracker.hasActiveCall, isFalse);
    });

    test('"ongoing" for another call leaves ours alone', () {
      service.activeCall = _call('ours');
      service.onOutgoingCallAccepted(_call('other', id: 9, status: 'ongoing'));

      expect((service.activeCall as Call?)?.sessionId, 'ours');
      expect(service.activeCall?.id, 1);
    });

    test('"ongoing" for our call refreshes it', () {
      service.activeCall = _call('ours');
      service.onOutgoingCallAccepted(_call('ours', id: 5, status: 'ongoing'));

      expect(service.activeCall?.id, 5);
    });

    testWidgets('a ringing call does not stop the user placing one', (
      tester,
    ) async {
      // A call is only placed with a navigator to show it on (round 1b).
      await mountCallNavigator(tester);
      // Android's call buttons check only the SDK's active call, which an
      // incoming call does not set.
      service.onIncomingCallReceived(_call('ringing'));
      await tester.pump();
      expect(ActiveCallTracker.hasActiveCall, isFalse);

      // Past the active-call check the bloc asks for mic permission; grant it.
      const permissions = MethodChannel(
        'flutter.baseflow.com/permissions/methods',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(permissions, (call) async {
        const granted = 1;
        if (call.method == 'requestPermissions') {
          return {for (final p in call.arguments as List) p: granted};
        }
        return granted;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(permissions, null));

      final errors = <Exception>[];
      final bloc = CallButtonsBloc(user: _peer, errorCallback: errors.add);
      bloc.add(const InitiateVoiceCall());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 500));

      expect(errors, isEmpty);
      expect(dataSource.initiates, 1);
      await tester.runAsync(bloc.close);
      IncomingCallOverlay.dismiss();
    });

    test('answering moves the call from ringing to active', () async {
      service.onIncomingCallReceived(_call('answer-1'));
      await _settle();

      service.ccCallAccepted(_call('answer-1', status: 'ongoing'));

      expect(ActiveCallTracker.ringingCall, isNull);
      expect((service.activeCall as Call?)?.sessionId, 'answer-1');
      expect(ActiveCallTracker.hasActiveCall, isTrue);
    });

    test('a cancel clears the ringing call', () async {
      service.onIncomingCallReceived(_call('cancel-1'));
      await _settle();

      service.onIncomingCallCancelled(_call('cancel-1', status: 'cancelled'));

      expect(ActiveCallTracker.ringingCall, isNull);
    });

    test('a cancel for another call leaves the ringing one', () async {
      service.onIncomingCallReceived(_call('cancel-2'));
      await _settle();

      service.onIncomingCallCancelled(
        _call('other', id: 9, status: 'cancelled'),
      );

      expect(ActiveCallTracker.ringingCall?.sessionId, 'cancel-2');
    });
  });

  // -------------------------------------------------------------------------
  group('row 1 — no new call while one is active', () {
    test(
      'initiating is refused with ACTIVE_CALL and nothing is sent',
      () async {
        service.activeCall = _call('ongoing');
        final errors = <Exception>[];
        final bloc = CallButtonsBloc(user: _peer, errorCallback: errors.add);

        bloc.add(const InitiateVoiceCall());
        await _settle();

        expect(dataSource.initiates, 0);
        expect(errors, hasLength(1));
        expect((errors.single as CometChatException).code, 'ACTIVE_CALL');
        expect(bloc.state.isDisabled, isFalse, reason: 'buttons stay usable');
        await bloc.close();
      },
    );
  });

  // -------------------------------------------------------------------------
  group('row 5 — a failed decline is still announced', () {
    test('ccCallRejected fires even when the reject fails', () async {
      final spy = _RejectedSpy();
      CometChatCallEvents.addCallEventsListener('row5', spy);
      addTearDown(() => CometChatCallEvents.removeCallEventsListener('row5'));
      dataSource.failReject = true;

      final bloc = IncomingCallBloc(
        call: _call('incoming'),
        disableSoundForCalls: true,
      );
      bloc.add(const RejectCall());
      await _settle();

      expect(dataSource.rejects, hasLength(1));
      expect(
        spy.rejected.map((c) => c.sessionId),
        ['incoming'],
        reason:
            'without it the local active call, call buttons and chat bubble '
            'all stayed as if the call were still ringing',
      );
      await bloc.close();
    });
  });

  // -------------------------------------------------------------------------
  group('row 6 — a cancel only dismisses its own call', () {
    test('a cancel for another session is ignored', () async {
      final bloc = IncomingCallBloc(
        call: _call('ringing'),
        disableSoundForCalls: true,
      );

      bloc.onIncomingCallCancelled(_call('someone_elses', id: 9));
      await _settle();
      expect(bloc.state.status, isNot(IncomingCallStatus.cancelled));

      bloc.onIncomingCallCancelled(_call('ringing', status: 'cancelled'));
      await _settle();
      expect(bloc.state.status, IncomingCallStatus.cancelled);
      await bloc.close();
    });
  });

  // -------------------------------------------------------------------------
  group('the active call is released when a call screen closes for good', () {
    test('a failed cancel — no event is emitted — still releases it', () async {
      final outgoing = _call('placed', initiator: _me);
      service.activeCall = outgoing;
      dataSource.failReject = true;

      final bloc = OutgoingCallBloc(call: outgoing, disableSoundForCalls: true);
      bloc.add(const CancelCall());
      await _settle();

      expect(
        service.activeCall,
        isNull,
        reason:
            'left set, it would refuse the next call and bounce the next '
            'incoming one as busy',
      );
      await bloc.close();
    });

    test("the echo of this device's busy reply to a third caller leaves the "
        'call it is placing alone (round 2, P2-C05)', () async {
      // A is ringing B; C calls A and is answered busy. The chat SDK routes
      // the echo of that busy by who performed it, so it reaches every call
      // listener as onOutgoingCallRejected — for C's call, not A's.
      final outgoing = _call('placed', initiator: _me);
      service.activeCall = outgoing;
      final bloc = OutgoingCallBloc(call: outgoing, disableSoundForCalls: true);

      service.onIncomingCallReceived(_call('from-c', id: 7));
      await _settle();
      expect(dataSource.rejects, [('from-c', 'busy')]);

      final echo = _call('from-c', id: 7, status: 'busy');
      service.onOutgoingCallRejected(echo);
      bloc.onOutgoingCallRejected(echo);
      await _settle();

      expect(bloc.state.status, OutgoingCallStatus.idle);
      expect(bloc.state.isCallRejected, isFalse);
      expect((service.activeCall as Call?)?.sessionId, 'placed');
      await bloc.close();
    });

    test('a decline by the callee releases it', () async {
      final outgoing = _call('placed', initiator: _me);
      service.activeCall = outgoing;

      final bloc = OutgoingCallBloc(call: outgoing, disableSoundForCalls: true);
      bloc.onOutgoingCallRejected(_call('placed', id: 5, status: 'rejected'));
      await _settle();

      expect(service.activeCall, isNull);
      await bloc.close();
    });
  });

  // -------------------------------------------------------------------------
  // Round 1b: the ringing record must not outlive the banner. A banner that
  // cannot be shown, or that something other than the SDK takes down, left
  // the device "busy" until that call's cancel arrived over the socket —
  // which may never happen — so every later incoming call was answered busy.
  group('the ringing record goes with its banner (round 1b)', () {
    tearDown(() {
      IncomingCallOverlay.dismiss();
      CometChatUIKit.authenticationSettings = null;
      CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
    });

    testWidgets('no navigator: released after the wait for one, '
        'NO_NAVIGATOR to the incoming onError, nothing declined, and the next '
        'call is not answered busy', (tester) async {
      final errors = <Exception>[];
      CometChatUIKit.authenticationSettings =
          (UIKitSettingsBuilder()
                ..appId = 'app'
                ..enableCalls = true
                ..callingConfiguration = CallingConfiguration(
                  incomingCallConfiguration: CometChatIncomingCallConfiguration(
                    onError: errors.add,
                  ),
                ))
              .build();
      CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();

      service.onIncomingCallReceived(_call('no-nav-1'));
      expect(ActiveCallTracker.ringingCall?.sessionId, 'no-nav-1');

      // It waits up to a second for a navigator to appear.
      await tester.pump(const Duration(milliseconds: 1100));

      expect(ActiveCallTracker.ringingCall, isNull);
      expect((errors.single as CometChatException).code, 'NO_NAVIGATOR');
      expect(dataSource.rejects, isEmpty, reason: 'push may still ring it');

      service.onIncomingCallReceived(_call('no-nav-2', id: 2));
      expect(ActiveCallTracker.ringingCall?.sessionId, 'no-nav-2');
      await tester.pump(const Duration(milliseconds: 1100));

      expect(dataSource.rejects, isEmpty, reason: 'not answered busy');
    });

    testWidgets('no navigator and an incoming onError that throws: the call '
        'is still released (round 1b review)', (tester) async {
      CometChatUIKit.authenticationSettings =
          (UIKitSettingsBuilder()
                ..appId = 'app'
                ..enableCalls = true
                ..callingConfiguration = CallingConfiguration(
                  incomingCallConfiguration: CometChatIncomingCallConfiguration(
                    onError: (Exception e) => throw StateError('host bug'),
                  ),
                ))
              .build();
      CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();

      service.onIncomingCallReceived(_call('no-nav-3'));
      await tester.pump(const Duration(milliseconds: 1100));

      expect(tester.takeException(), isNull);
      expect(ActiveCallTracker.ringingCall, isNull);
    });

    testWidgets("dismiss() takes the banner's call off the ringing record; a "
        'dismiss for another call leaves both', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          localizationsDelegates: Translations.localizationsDelegates,
          home: const SizedBox(),
        ),
      );
      final ringing = _call('banner-1');
      ActiveCallTracker.ringingCall = ringing;
      service.activeCall = _call('active-1', id: 3);
      IncomingCallOverlay.show(
        context: CallNavigationContext.navigatorKey.currentContext!,
        call: ringing,
        disableSoundForCalls: true,
      );
      await tester.pump();
      expect(ActiveCallTracker.incomingCallSessionId, 'banner-1');

      IncomingCallOverlay.dismiss(sessionId: 'someone-else');
      expect(ActiveCallTracker.ringingCall?.sessionId, 'banner-1');
      expect(ActiveCallTracker.incomingCallSessionId, 'banner-1');

      // What master_app's push handlers do on a cancel push.
      IncomingCallOverlay.dismiss();
      expect(ActiveCallTracker.ringingCall, isNull);
      expect(ActiveCallTracker.incomingCallSessionId, isNull);
      expect(
        (service.activeCall as Call?)?.sessionId,
        'active-1',
        reason: 'only the ringing record',
      );
      expect(dataSource.rejects, isEmpty);
      await tester.pump();
    });

    testWidgets('the same call shown again keeps its ringing record when the '
        'banner it replaced goes (round 1b review)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          localizationsDelegates: Translations.localizationsDelegates,
          home: const SizedBox(),
        ),
      );
      final ringing = _call('banner-3');
      ActiveCallTracker.ringingCall = ringing;
      for (var i = 0; i < 2; i++) {
        IncomingCallOverlay.show(
          context: CallNavigationContext.navigatorKey.currentContext!,
          call: ringing,
          disableSoundForCalls: true,
        );
        await tester.pump();
      }
      // The first banner's bloc closes with its widget.
      await tester.pump();

      expect(ActiveCallTracker.incomingCallSessionId, 'banner-3');
      expect(ActiveCallTracker.ringingCall?.sessionId, 'banner-3');

      IncomingCallOverlay.dismiss();
      await tester.pump();
      expect(ActiveCallTracker.ringingCall, isNull);
    });

    test('a dismiss aimed at a call with no banner up still releases its '
        'ringing record', () {
      ActiveCallTracker.ringingCall = _call('banner-2');

      IncomingCallOverlay.dismiss(sessionId: 'banner-2');

      expect(ActiveCallTracker.ringingCall, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Round 3, P3-C09: a call that stopped ringing while the banner waited for
  // a navigator is not shown. It rang (until the 60 s timeout) for a call
  // that was over.
  group('P3-C09: no banner for a call that stopped ringing', () {
    tearDown(() {
      IncomingCallOverlay.dismiss();
      CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
    });

    testWidgets('P3-E15 / P3-E33: a call that stops ringing during the wait '
        'for a navigator (here: declined on another device) is not shown '
        'when one appears', (tester) async {
      CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
      service.onIncomingCallReceived(_call('waiting-1'));
      await tester.pump(const Duration(milliseconds: 250));

      service.onOutgoingCallRejected(_call('waiting-1', status: 'rejected'));
      expect(ActiveCallTracker.ringingCall, isNull);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          localizationsDelegates: Translations.localizationsDelegates,
          home: const SizedBox(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1100));

      expect(find.byType(CometChatIncomingCall), findsNothing);
      expect(ActiveCallTracker.incomingCallSessionId, isNull);
      expect(dataSource.rejects, isEmpty);
    });

    testWidgets('a caller\'s cancel during the wait: no banner even for the '
        'moment before the cancel\'s own dismiss', (tester) async {
      CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
      service.onIncomingCallReceived(_call('waiting-3'));
      await tester.pump(const Duration(milliseconds: 250));

      service.onIncomingCallCancelled(_call('waiting-3'));
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          localizationsDelegates: Translations.localizationsDelegates,
          home: const SizedBox(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(ActiveCallTracker.incomingCallSessionId, isNull);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(CometChatIncomingCall), findsNothing);
    });

    testWidgets('a call still ringing when the navigator appears is shown', (
      tester,
    ) async {
      CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
      service.onIncomingCallReceived(_call('waiting-2'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          localizationsDelegates: Translations.localizationsDelegates,
          home: const SizedBox(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(ActiveCallTracker.incomingCallSessionId, 'waiting-2');
      IncomingCallOverlay.dismiss();
      await tester.pump();
    });
  });

  // -------------------------------------------------------------------------
  // Round 3, P3-C23: a late "initiated" for a call this device already
  // finished (a socket reconnect, a duplicate push) neither rings nor is
  // answered busy.
  group('P3-C23: calls finished lately are not rung again', () {
    late DateTime clock;

    setUp(() {
      clock = DateTime(2026, 10, 1, 12);
      ActiveCallTracker.now = () => clock;
    });

    tearDown(() => ActiveCallTracker.now = DateTime.now);

    test('a released call arriving again: no banner, no busy reply', () async {
      ActiveCallTracker.release('finished-1');

      service.onIncomingCallReceived(_call('finished-1'));
      await _settle();

      expect(ActiveCallTracker.ringingCall, isNull);
      expect(dataSource.rejects, isEmpty);
    });

    test('...not even while another call is on, where any other call is '
        'answered busy', () async {
      ActiveCallTracker.release('finished-2');
      service.activeCall = _call('ongoing-2', id: 9);

      service.onIncomingCallReceived(_call('finished-2'));
      await _settle();

      expect(dataSource.rejects, isEmpty);
    });

    test('two minutes later it rings: a session is not refused for good', () {
      ActiveCallTracker.release('finished-3');
      clock = clock.add(const Duration(minutes: 2, seconds: 1));

      service.onIncomingCallReceived(_call('finished-3'));

      expect(ActiveCallTracker.ringingCall?.sessionId, 'finished-3');
    });

    test('only the last 20 are remembered', () {
      for (var i = 0; i < 21; i++) {
        ActiveCallTracker.release('lru-$i');
      }

      expect(ActiveCallTracker.finishedLately('lru-0'), isFalse);
      expect(ActiveCallTracker.finishedLately('lru-1'), isTrue);
      expect(ActiveCallTracker.finishedLately('lru-20'), isTrue);
    });

    test('a logout (or a user switch) forgets them', () {
      ActiveCallTracker.release('finished-4');
      CallsLifecycle.tearDownLocalCalls();

      expect(ActiveCallTracker.finishedLately('finished-4'), isFalse);
    });

    test('a call declined here is one of them', () async {
      service.onIncomingCallReceived(_call('declined-1'));
      service.ccCallRejected(_call('declined-1', status: 'rejected'));

      expect(ActiveCallTracker.finishedLately('declined-1'), isTrue);
    });
  });
}
