import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_extension_constants.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/constants/ui_kit_constants.dart';
import 'package:cometchat_chat_uikit/src/calls_lifecycle.dart';
import 'package:cometchat_chat_uikit/src/calls_sdk_session.dart';

import '../helpers/call_bloc_harness.dart';

// ===========================================================================
// OngoingCallBloc — teardown paths, error paths and disposal.
//
// The peer-left auto-teardown is covered separately in
// ongoing_call_peer_left_test.dart; this file covers everything else the BLoC
// can reach without a live Calls SDK.
//
// Every bloc here joins, as on a device: `installCallJoinDefaults()` puts a
// ready fake Calls SDK behind `CallsSdkSession` (the readiness guard reads
// `CallsSdkSession.instance.isReady`) and grants the permissions, and the
// fake datasource's `startSession` hands back a stand-in call view. The one
// "not ready" test makes the fake Calls SDK fail on purpose.
// ===========================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCallOperationsDataSource dataSource;
  late CallEventRecorder events;
  late FakeCallsSdkGateway gateway;

  OngoingCallBloc buildBloc({
    CallWorkFlow workFlow = CallWorkFlow.defaultCalling,
    OnError? onError,
    String sessionId = 'session_1',
  }) => OngoingCallBloc(
    sessionSettingsBuilder: SessionSettingsBuilder(),
    sessionId: sessionId,
    callWorkFlow: workFlow,
    errorCallback: onError,
  );

  /// Waits until [bloc] has joined. Every teardown below starts from a
  /// joined call, as on a device, where the end button only shows once the
  /// call view is up.
  Future<void> joined(OngoingCallBloc bloc) async {
    if (bloc.state.status == OngoingCallStatus.active) return;
    await bloc.stream.firstWhere(
      (OngoingCallState s) => s.status == OngoingCallStatus.active,
    );
  }

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    events = CallEventRecorder('ongoing_call_bloc_test');
    gateway = await installCallJoinDefaults();
  });

  tearDown(() async {
    removeCallJoinDefaults();
    events.dispose();
    CallEventService.instance.activeCall = null;
    await CallOperationsServiceLocator.instance.reset();
    CallStateService.instance.setActiveCallValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  // =========================================================================
  // Joining
  // =========================================================================

  group('LoadCallingScreen', () {
    test(
      'construction marks a call active, waits for the Calls SDK, then joins',
      () async {
        final OngoingCallBloc bloc = buildBloc();
        addTearDown(bloc.close);

        expect(CallStateService.instance.isActiveCall.value, isTrue);
        final OngoingCallState joined = await bloc.stream.firstWhere(
          (OngoingCallState s) => s.status == OngoingCallStatus.active,
        );
        expect(joined.callingWidget, isA<FakeCallingWidget>());
        expect(dataSource.calls, <String>[
          'waitForCallsSdk',
          'startSession:session_1',
        ]);
      },
    );

    blocTest<OngoingCallBloc, OngoingCallState>(
      'an unready Calls SDK fails with a user-facing message, not a crash',
      setUp: () async {
        // The Calls SDK init fails, so the session is not ready.
        installCallsSdk(
          FakeCallsSdkGateway()
            ..onInit = () async => throw StateError('Calls init failed'),
        );
        expect(await CallsSdkSession.instance.ensureReady(), isFalse);
      },
      build: buildBloc,
      expect: () => const <OngoingCallState>[
        OngoingCallState(),
        OngoingCallState(
          status: OngoingCallStatus.error,
          errorMessage: 'Call service is not ready. Please try again.',
          errorCode: 'CALLS_NOT_READY',
        ),
      ],
      verify: (_) {
        // It must stop before the session: no endCall/endSession churn.
        expect(dataSource.calls, <String>['waitForCallsSdk']);
      },
    );

    blocTest<OngoingCallBloc, OngoingCallState>(
      'an initialised Calls SDK without the Calls login is not ready either',
      setUp: () async {
        // The init succeeds, the login fails: isCallsSdkReady (init only)
        // would let the join through, and it would fail with "User auth
        // token is null".
        installCallsSdk(
          FakeCallsSdkGateway()
            ..onLogin = (_) async => throw StateError('Calls login failed'),
          timeouts: const CallsSdkTimeouts(loginAttempts: 1),
        );
        expect(await CallsSdkSession.instance.ensureReady(), isFalse);
        expect(CallsSdkSession.instance.isInitialized, isTrue);
      },
      build: buildBloc,
      expect: () => const <OngoingCallState>[
        OngoingCallState(),
        OngoingCallState(
          status: OngoingCallStatus.error,
          errorMessage: 'Call service is not ready. Please try again.',
          errorCode: 'CALLS_NOT_READY',
        ),
      ],
      verify: (_) {
        expect(dataSource.calls, <String>['waitForCallsSdk']);
      },
    );
  });

  // =========================================================================
  // End call button
  // =========================================================================

  group('EndCallButtonPressed', () {
    blocTest<OngoingCallBloc, OngoingCallState>(
      'defaultCalling leaves the session first, then ends the call',
      build: buildBloc,
      act: (OngoingCallBloc bloc) async {
        await joined(bloc);
        bloc.add(const EndCallButtonPressed());
      },
      wait: const Duration(milliseconds: 50),
      verify: (OngoingCallBloc bloc) {
        // Order matters: the peer should only be told the call ended once the
        // local RTC session is down.
        expect(
          dataSource.calls.where((String c) => c.startsWith('end')),
          <String>['endSession', 'endCall:session_1'],
        );
        expect(bloc.state.isCallEndedByMe, isTrue);
        expect(bloc.state.status, OngoingCallStatus.ended);
        expect(events.ended.single.category, MessageCategoryConstants.call);
      },
    );

    blocTest<OngoingCallBloc, OngoingCallState>(
      'directCalling (meetings) only ends the session — there is no call',
      build: () => buildBloc(workFlow: CallWorkFlow.directCalling),
      act: (OngoingCallBloc bloc) async {
        await joined(bloc);
        bloc.add(const EndCallButtonPressed());
      },
      wait: const Duration(milliseconds: 50),
      verify: (OngoingCallBloc bloc) {
        expect(dataSource.endCallCount, 0);
        expect(dataSource.endSessionCount, 1);
        expect(bloc.state.status, OngoingCallStatus.ended);
        expect(events.ended, isEmpty);
      },
    );

    blocTest<OngoingCallBloc, OngoingCallState>(
      'a failing endCall still ends the call locally and reports the reason',
      build: () {
        dataSource.endCallError = const CallOperationsException(
          message: 'Call already ended',
        );
        return buildBloc();
      },
      act: (OngoingCallBloc bloc) async {
        await joined(bloc);
        bloc.add(const EndCallButtonPressed());
      },
      wait: const Duration(milliseconds: 50),
      verify: (OngoingCallBloc bloc) {
        expect(bloc.state.status, OngoingCallStatus.error);
        expect(bloc.state.errorMessage, 'Call already ended');
        expect(events.ended, isEmpty);
      },
    );

    blocTest<OngoingCallBloc, OngoingCallState>(
      'a failing quiet endSession does not stop the server-side endCall',
      build: () {
        dataSource.endSessionError = const CallOperationsException(
          message: 'Session already gone',
        );
        return buildBloc();
      },
      act: (OngoingCallBloc bloc) async {
        await joined(bloc);
        bloc.add(const EndCallButtonPressed());
      },
      wait: const Duration(milliseconds: 50),
      verify: (OngoingCallBloc bloc) {
        // The peer still has to be told, even when the local teardown failed.
        expect(dataSource.endCallCount, 1);
        expect(bloc.state.status, OngoingCallStatus.ended);
      },
    );

    test('a failing endCall reports through errorCallback', () async {
      final List<Exception> errors = <Exception>[];
      dataSource.endCallError = const CallOperationsException(
        message: 'Call already ended',
      );
      final OngoingCallBloc bloc = buildBloc(onError: errors.add);
      addTearDown(bloc.close);
      await joined(bloc);

      bloc.add(const EndCallButtonPressed());
      // Match on this teardown's message rather than on any error state.
      await bloc.stream.firstWhere(
        (OngoingCallState s) => s.errorMessage == 'Call already ended',
      );

      final CometChatException error = errors.single as CometChatException;
      expect(error.code, 'ERR');
      expect(error.message, 'Call already ended');
      expect(error.details, 'Call already ended');
    });

    test('a failing endCall after hang-up hands errorCallback the SDK\'s own '
        'exception, code kept (round 1b)', () async {
      final List<Exception> errors = <Exception>[];
      final CometChatException sdkError = CometChatException(
        'ERR_CALL_ENDED',
        'The call has already ended.',
        'Call already ended',
      );
      dataSource.endCallError = CallOperationsException(
        message: 'Call already ended',
        code: 'ERR_CALL_ENDED',
        originalException: sdkError,
      );
      final OngoingCallBloc bloc = buildBloc(onError: errors.add);
      addTearDown(bloc.close);
      await joined(bloc);

      bloc.add(const EndCallButtonPressed());
      await bloc.stream.firstWhere(
        (OngoingCallState s) => s.errorMessage == 'Call already ended',
      );

      expect(errors.single, same(sdkError));
    });

    test('a failing endSession hands errorCallback the Calls SDK\'s code '
        '(round 1b)', () async {
      final List<Exception> errors = <Exception>[];
      dataSource.endSessionError = CallOperationsException(
        message: 'Not in a session',
        code: 'SESSION_NOT_FOUND',
        originalException: CometChatCallsException(
          'SESSION_NOT_FOUND',
          'Not in a session',
          'no active session',
        ),
      );
      final OngoingCallBloc bloc = buildBloc(
        onError: errors.add,
        workFlow: CallWorkFlow.directCalling,
      );
      addTearDown(bloc.close);
      await joined(bloc);

      bloc.add(const EndCallButtonPressed());
      await bloc.stream.firstWhere(
        (OngoingCallState s) => s.status == OngoingCallStatus.error,
      );

      final CometChatException error = errors.single as CometChatException;
      expect(error.code, 'SESSION_NOT_FOUND');
      expect(error.message, 'Not in a session');
      expect(error.details, 'no active session');
    });
  });

  // =========================================================================
  // Session timeout
  // =========================================================================

  group('SessionTimeout', () {
    blocTest<OngoingCallBloc, OngoingCallState>(
      'ends the session without ending the call on the server',
      build: buildBloc,
      act: (OngoingCallBloc bloc) async {
        await joined(bloc);
        bloc.add(const SessionTimeout());
      },
      wait: const Duration(milliseconds: 50),
      verify: (OngoingCallBloc bloc) {
        expect(dataSource.endSessionCount, 1);
        expect(dataSource.endCallCount, 0);
        expect(bloc.state.status, OngoingCallStatus.ended);
      },
    );

    blocTest<OngoingCallBloc, OngoingCallState>(
      'a failing endSession surfaces the reason but still finishes',
      build: () {
        dataSource.endSessionError = const CallOperationsException(
          message: 'Session already gone',
        );
        return buildBloc();
      },
      act: (OngoingCallBloc bloc) async {
        await joined(bloc);
        bloc.add(const SessionTimeout());
      },
      wait: const Duration(milliseconds: 50),
      verify: (OngoingCallBloc bloc) {
        expect(bloc.state.status, OngoingCallStatus.error);
        expect(bloc.state.errorMessage, 'Session already gone');
      },
    );
  });

  // =========================================================================
  // Remote hangup
  // =========================================================================

  group('OngoingCallEnded', () {
    blocTest<OngoingCallBloc, OngoingCallState>(
      'a remote hangup tears down the session, not the call',
      build: buildBloc,
      act: (OngoingCallBloc bloc) async {
        await joined(bloc);
        bloc.add(const OngoingCallEnded());
      },
      wait: const Duration(milliseconds: 50),
      verify: (OngoingCallBloc bloc) {
        // The remote party already ended the call server-side.
        expect(dataSource.endCallCount, 0);
        expect(dataSource.endSessionCount, 1);
        expect(bloc.state.status, OngoingCallStatus.ended);
      },
    );

    blocTest<OngoingCallBloc, OngoingCallState>(
      'a local hangup echoed back as OngoingCallEnded does not end twice',
      build: buildBloc,
      act: (OngoingCallBloc bloc) async {
        await joined(bloc);
        bloc.add(const EndCallButtonPressed());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        // Leaving the RTC session fires onSessionLeft/onConnectionClosed,
        // which the SDK listeners turn into this event.
        bloc.add(const OngoingCallEnded());
      },
      wait: const Duration(milliseconds: 60),
      verify: (_) {
        expect(dataSource.endCallCount, 1);
        expect(dataSource.endSessionCount, 1);
      },
    );

    test('directCalling ignores OngoingCallEnded entirely', () async {
      final OngoingCallBloc bloc = buildBloc(
        workFlow: CallWorkFlow.directCalling,
      );
      addTearDown(bloc.close);
      await joined(bloc);

      bloc.add(const OngoingCallEnded());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Checked before the bloc closes: closing a joined meeting that was
      // never ended leaves its session (the close() safety net).
      expect(dataSource.calls, <String>[
        'waitForCallsSdk',
        'startSession:session_1',
      ]);
      expect(bloc.state.status, OngoingCallStatus.active);
    });

    blocTest<OngoingCallBloc, OngoingCallState>(
      'a failing endSession on a remote hangup still leaves the screen '
      'dismissible',
      build: () {
        dataSource.endSessionError = const CallOperationsException(
          message: 'Session already gone',
        );
        return buildBloc();
      },
      act: (OngoingCallBloc bloc) async {
        await joined(bloc);
        bloc.add(const OngoingCallEnded());
      },
      wait: const Duration(milliseconds: 50),
      verify: (OngoingCallBloc bloc) =>
          expect(bloc.state.status, OngoingCallStatus.error),
    );
  });

  // =========================================================================
  // Screen dismissal — _closeCallScreen's Navigator fallback
  // =========================================================================

  group('_closeCallScreen', () {
    /// Mounts a two-route stack with the call screen on top, which is what
    /// standalone (non-overlay) usage of CometChatOngoingCall looks like.
    Future<void> pumpCallOverMessages(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          home: const Scaffold(body: Text('messages')),
        ),
      );
      unawaited(
        CallNavigationContext.navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('call')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('call'), findsOneWidget);
    }

    testWidgets('ending the call pops the call screen', (
      WidgetTester tester,
    ) async {
      await pumpCallOverMessages(tester);

      final OngoingCallBloc bloc = buildBloc();
      addTearDown(bloc.close);
      await joined(bloc);

      bloc.add(const EndCallButtonPressed());
      await tester.pumpAndSettle();

      expect(find.text('call'), findsNothing);
      expect(find.text('messages'), findsOneWidget);
    });

    testWidgets('a failing endCall still pops the call screen', (
      WidgetTester tester,
    ) async {
      dataSource.endCallError = const CallOperationsException(
        message: 'Call already ended',
      );
      await pumpCallOverMessages(tester);

      final OngoingCallBloc bloc = buildBloc();
      addTearDown(bloc.close);
      await joined(bloc);

      bloc.add(const EndCallButtonPressed());
      await tester.pumpAndSettle();

      expect(bloc.state.status, OngoingCallStatus.error);
      expect(find.text('call'), findsNothing);
    });

    testWidgets('the teardown never pops a second route', (
      WidgetTester tester,
    ) async {
      await pumpCallOverMessages(tester);

      final OngoingCallBloc bloc = buildBloc();
      addTearDown(bloc.close);
      await joined(bloc);

      // _closeCallScreen runs more than once per teardown: explicitly in
      // _onCallEnded and again inside _endCall's fold. The _callScreenClosed
      // latch is what stops the second run popping the screen underneath.
      bloc.add(const EndCallButtonPressed());
      await tester.pumpAndSettle();
      bloc.add(const OngoingCallEnded());
      await tester.pumpAndSettle();

      expect(find.text('messages'), findsOneWidget);
    });

    testWidgets('an overlay-hosted call screen is dismissed, not popped', (
      WidgetTester tester,
    ) async {
      await pumpCallOverMessages(tester);
      CallScreenOverlay.show(
        sessionId: 'session_1',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
      expect(CallScreenOverlay.isShowing, isTrue);

      final OngoingCallBloc bloc = buildBloc();
      addTearDown(bloc.close);
      await joined(bloc);

      bloc.add(const EndCallButtonPressed());
      await tester.pumpAndSettle();

      // The overlay branch wins over the Navigator fallback, so the route
      // stack is left exactly as it was.
      expect(CallScreenOverlay.isShowing, isFalse);
      expect(find.text('call'), findsOneWidget);
    });

    testWidgets('a call screen whose overlay was already taken down pops '
        "nothing of the host's (round 1b)", (WidgetTester tester) async {
      await pumpCallOverMessages(tester);
      CallScreenOverlay.show(
        sessionId: 'session_1',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
      // Built while the overlay shows this call, as the overlay's own screen
      // is.
      final OngoingCallBloc bloc = buildBloc();
      addTearDown(bloc.close);
      await joined(bloc);

      // Something else closed it first: a logout, the remote end.
      CallScreenOverlay.dismiss();
      await tester.pump();

      bloc.add(const EndCallButtonPressed());
      await tester.pumpAndSettle();

      // It used to fall back to Navigator.pop and take the host's screen.
      expect(find.text('call'), findsOneWidget);
      expect(bloc.state.status, OngoingCallStatus.ended);
    });

    testWidgets('nothing is popped when the call screen is the only route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          home: const Scaffold(body: Text('call')),
        ),
      );

      final OngoingCallBloc bloc = buildBloc();
      addTearDown(bloc.close);
      await joined(bloc);

      bloc.add(const EndCallButtonPressed());
      await tester.pumpAndSettle();

      // canPop() is false, so the root route survives.
      expect(find.text('call'), findsOneWidget);
      expect(bloc.state.status, OngoingCallStatus.ended);
    });
  });

  // =========================================================================
  // Error plumbing
  // =========================================================================

  group('handleCallsError', () {
    test('translates a Calls SDK exception for the host callback', () {
      final List<Exception> errors = <Exception>[];
      final OngoingCallBloc bloc = buildBloc(onError: errors.add);
      addTearDown(bloc.close);

      bloc.handleCallsError(
        CometChatCallsException('CALL_ERR', 'Boom', 'stack'),
      );

      final CometChatException error = errors.single as CometChatException;
      expect(error.code, 'CALL_ERR');
      // Each in its own slot (round 1b review). It used to arrive swapped:
      // CometChatException's constructor is (code, details, message), and
      // handleCallsError passed (code, ce.message, ce.details).
      expect(error.message, 'Boom');
      expect(error.details, 'stack');
    });

    test('fills in a default message when the SDK gives none', () {
      final List<Exception> errors = <Exception>[];
      final OngoingCallBloc bloc = buildBloc(onError: errors.add);
      addTearDown(bloc.close);

      bloc.handleCallsError(CometChatCallsException('CALL_ERR', null, null));

      final CometChatException error = errors.single as CometChatException;
      // The fallback is the message a host renders (it used to land in
      // `details`, with an empty message).
      expect(error.message, 'Call error occurred');
      expect(error.details, 'Call error occurred');
    });

    test('is a no-op without an error callback', () {
      final OngoingCallBloc bloc = buildBloc();
      addTearDown(bloc.close);

      expect(
        () => bloc.handleCallsError(
          CometChatCallsException('CALL_ERR', 'Boom', 'stack'),
        ),
        returnsNormally,
      );
    });
  });

  // =========================================================================
  // Disposal
  // =========================================================================

  group('close', () {
    test('makes no Calls SDK calls: no re-init after a session', () async {
      // Call handling started, as after a login: the old re-init (and the
      // deprecated reinitializeAfterSession) only acts then.
      CallsLifecycle.addChatCallListener = (_, _) {};
      CallsLifecycle.removeChatCallListener = (_) {};
      addTearDown(CallsLifecycle.debugReset);
      await CallsLifecycle.start(User(uid: 'uid-1', name: 'One'));
      expect(CallsLifecycle.isStarted, isTrue);
      gateway.calls.clear();

      final OngoingCallBloc bloc = buildBloc();
      await bloc.stream.firstWhere(
        (OngoingCallState s) => s.status == OngoingCallStatus.active,
      );
      // What made the old re-init run a Calls init: the plugin reporting
      // itself not initialised (plugin 5.0.4 after a logout).
      gateway.initialized = false;

      await bloc.close();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(gateway.calls, isEmpty);
    });

    test('clears the active-call flag', () async {
      final OngoingCallBloc bloc = buildBloc();
      expect(CallStateService.instance.isActiveCall.value, isTrue);

      await bloc.close();

      expect(CallStateService.instance.isActiveCall.value, isFalse);
    });

    test('a teardown that lands after close() emits nothing', () async {
      final Completer<void> gate = Completer<void>();
      final _GatedDataSource gated = _GatedDataSource(gate);
      await CallOperationsServiceLocator.instance.reset();
      CallOperationsServiceLocator.instance.setup(dataSource: gated);

      final OngoingCallBloc bloc = buildBloc();
      bloc.add(const SessionTimeout());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Close while endSession is still in flight, then let it finish: the
      // isClosed guards are the only thing stopping an emit-after-close error.
      await bloc.close();
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.isClosed, isTrue);
    });
  });
}

/// A datasource whose `endSession` only completes once a gate is opened.
class _GatedDataSource extends FakeCallOperationsDataSource {
  _GatedDataSource(this._gate);

  final Completer<void> _gate;

  @override
  Future<void> endSession() async {
    calls.add('endSession');
    await _gate.future;
  }
}
