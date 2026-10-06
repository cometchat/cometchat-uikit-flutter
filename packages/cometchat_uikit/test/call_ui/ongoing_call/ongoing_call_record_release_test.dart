/// A call screen that cannot join releases the call record and tells the
/// host why (round 1b: P1-C05, the release/onError halves of P2-C10 and
/// P4-C01).
///
/// Every way the join fails — the Calls SDK not ready, the permissions
/// refused, the SDK refusing the join, no answer within 30 s — used to only
/// show an error. The record stayed, so the device looked busy: the call
/// buttons refused with ACTIVE_CALL and every incoming call was answered
/// busy until an event for that session or a logout. onError never fired.
///
/// Owner decision (Android parity): nothing goes to the server on a failed
/// join. No endCall, no reject.
///
///   flutter test test/call_ui/ongoing_call/ongoing_call_record_release_test.dart
library;

import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/start_session_deadline.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_extension_constants.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/calls_sdk_session.dart';

import '../helpers/call_bloc_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCallOperationsDataSource dataSource;
  late List<Exception> errors;
  final CallEventService service = CallEventService.instance;

  OngoingCallBloc buildBloc({
    String sessionId = 'session_1',
    SessionSettingsBuilder? settings,
  }) => OngoingCallBloc(
    sessionSettingsBuilder: settings ?? SessionSettingsBuilder(),
    sessionId: sessionId,
    callWorkFlow: CallWorkFlow.defaultCalling,
    errorCallback: errors.add,
  );

  Future<OngoingCallState> failed(OngoingCallBloc bloc) => bloc.stream
      .firstWhere((OngoingCallState s) => s.status == OngoingCallStatus.error);

  /// The Calls SDK init fails, so the session is never ready.
  Future<void> makeCallsSdkUnready() async {
    installCallsSdk(
      FakeCallsSdkGateway()
        ..onInit = () async => throw StateError('Calls init failed'),
    );
    expect(await CallsSdkSession.instance.ensureReady(), isFalse);
  }

  CometChatException onlyError() => errors.single as CometChatException;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    await installCallJoinDefaults();
    errors = <Exception>[];
    service.activeCall = buildCall();
  });

  tearDown(() async {
    removeCallJoinDefaults();
    service.activeCall = null;
    ActiveCallTracker.ringingCall = null;
    CallScreenOverlay.dismiss();
    await CallOperationsServiceLocator.instance.reset();
    CallStateService.instance.setActiveCallValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  test('Calls SDK not ready: the record is released and onError gets '
      'CALLS_NOT_READY', () async {
    await makeCallsSdkUnready();
    final OngoingCallBloc bloc = buildBloc();
    addTearDown(bloc.close);

    await failed(bloc);

    expect(service.activeCall, isNull);
    expect(ActiveCallTracker.hasActiveCall, isFalse);
    expect(onlyError().code, 'CALLS_NOT_READY');
    expect(onlyError().message, 'Call service is not ready. Please try again.');
    expect(dataSource.startSessionCount, 0);
    expect(dataSource.endCallCount, 0);
  });

  test('permissions refused at the join: released, PERMISSION_DENIED, no '
      'server call', () async {
    PermissionChannelStub.install(granted: false);
    final OngoingCallBloc bloc = buildBloc();
    addTearDown(bloc.close);

    await failed(bloc);

    expect(service.activeCall, isNull);
    expect(onlyError().code, 'PERMISSION_DENIED');
    expect(onlyError().details, 'microphone,camera');
    expect(dataSource.calls, <String>['waitForCallsSdk']);
  });

  test('permissions permanently refused: PERMISSION_PERMANENTLY_DENIED, '
      'naming only the microphone for an audio call', () async {
    PermissionChannelStub.install(granted: false, permanentlyDenied: true);
    final OngoingCallBloc bloc = buildBloc(
      settings: SessionSettingsBuilder()
        ..startVideoPaused(true)
        ..hideToggleVideoButton(true),
    );
    addTearDown(bloc.close);

    await failed(bloc);

    expect(service.activeCall, isNull);
    expect(onlyError().code, 'PERMISSION_PERMANENTLY_DENIED');
    expect(onlyError().details, 'microphone');
  });

  test('the Calls SDK refuses the join: released, JOIN_FAILED carrying the '
      "SDK's code, and no endCall", () async {
    dataSource.startSessionError = CallOperationsException(
      message: 'Invalid call token',
      code: 'ERR_INVALID_TOKEN',
      originalException: CometChatCallsException(
        'ERR_INVALID_TOKEN',
        'Invalid call token',
        'token expired',
      ),
    );
    final OngoingCallBloc bloc = buildBloc();
    addTearDown(bloc.close);

    final OngoingCallState state = await failed(bloc);

    expect(service.activeCall, isNull);
    expect(state.errorMessage, 'Invalid call token');
    final CometChatException error = onlyError();
    expect(error.code, 'JOIN_FAILED');
    expect(error.message, 'Invalid call token');
    expect(error.details, 'ERR_INVALID_TOKEN: token expired');
    expect(error.errorParams, <String, dynamic>{
      'sdkCode': 'ERR_INVALID_TOKEN',
      'sdkMessage': 'Invalid call token',
      'sdkDetails': 'token expired',
    });
    // Android parity: a failed join sends nothing to the server.
    expect(dataSource.endCallCount, 0);
    expect(dataSource.rejectCallCount, 0);
  });

  testWidgets('no answer within 30 s: released, JOIN_TIMEOUT', (
    WidgetTester tester,
  ) async {
    // A start that never answers, behind the real 30 s limit.
    dataSource.onStartSession = (_) => joinWithDeadline((_, _) {});
    final OngoingCallBloc bloc = buildBloc();

    await tester.pump(const Duration(seconds: 29));
    expect(bloc.state.status, OngoingCallStatus.loading);
    expect(service.activeCall, isNotNull, reason: 'still joining');

    await tester.pump(const Duration(seconds: 2));
    expect(bloc.state.status, OngoingCallStatus.error);
    expect(service.activeCall, isNull);
    final CometChatException error = onlyError();
    expect(error.code, 'JOIN_TIMEOUT');
    expect(
      error.message,
      'Could not join the call. Check your connection and try again.',
    );
    expect(dataSource.endCallCount, 0);

    await tester.runAsync(bloc.close);
  });

  test('an onError that throws does not stop the error state (round 1b '
      'review)', () async {
    await makeCallsSdkUnready();
    final OngoingCallBloc bloc = OngoingCallBloc(
      sessionSettingsBuilder: SessionSettingsBuilder(),
      sessionId: 'session_1',
      callWorkFlow: CallWorkFlow.defaultCalling,
      errorCallback: (Exception e) => throw StateError('host bug'),
    );
    addTearDown(bloc.close);

    await failed(bloc).timeout(const Duration(seconds: 5));

    expect(service.activeCall, isNull);
  });

  test('the release is session-matched: a record for another call is '
      'kept', () async {
    service.activeCall = buildCall(sessionId: 'session_2');
    await makeCallsSdkUnready();
    final OngoingCallBloc bloc = buildBloc();
    addTearDown(bloc.close);

    await failed(bloc);

    expect((service.activeCall as Call?)?.sessionId, 'session_2');
    expect(onlyError().code, 'CALLS_NOT_READY');
  });

  testWidgets('a call screen in CallScreenOverlay that cannot join is gone '
      'before onError, and the device is free for the next call (P4-C01: '
      'close at once)', (WidgetTester tester) async {
    await makeCallsSdkUnready();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: CallNavigationContext.navigatorKey,
        home: const Scaffold(body: Text('messages')),
      ),
    );

    // What a host retrying from onError would find (round 1b review).
    bool? busyAtOnError;
    bool? screenUpAtOnError;
    CallScreenOverlay.show(
      sessionId: 'session_1',
      sessionSettingsBuilder: SessionSettingsBuilder(),
      onError: (Exception e) {
        busyAtOnError = ActiveCallTracker.hasActiveCall;
        screenUpAtOnError = CallScreenOverlay.isShowing;
        errors.add(e);
      },
    );
    expect(ActiveCallTracker.hasActiveCall, isTrue);

    await tester.pumpAndSettle();

    // Closed at once, before onError (the owner's choice; there is no
    // error screen): it used to go only on the next frame, which in the
    // background on iOS can be a long time coming.
    expect(screenUpAtOnError, isFalse);
    expect(busyAtOnError, isFalse);

    expect(CallScreenOverlay.isShowing, isFalse);
    expect(ActiveCallTracker.hasActiveCall, isFalse);
    expect(service.activeCall, isNull);
    expect(onlyError().code, 'CALLS_NOT_READY');
    expect(find.text('messages'), findsOneWidget);
  });

  group('a join that lands after its screen closed (round 1b review)', () {
    // The Calls SDK starts the Android ongoing-call service ("Call in
    // progress") on every successful join. A join that went through after
    // its screen had closed left that service running with nothing to stop
    // it.
    const MethodChannel plugin = MethodChannel('cometchatcalls_plugin');
    late List<String> native;

    setUp(() {
      native = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(plugin, (MethodCall call) async {
            native.add(call.method);
            return null;
          });
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(plugin, null);
    });

    /// A bloc whose join is on its way, then its screen closing, then the
    /// join answering with [answer].
    Future<void> closeThenAnswer(
      void Function(Completer<Widget> join) answer,
    ) async {
      final Completer<Widget> join = Completer<Widget>();
      dataSource.onStartSession = (_) => join.future;
      final OngoingCallBloc bloc = buildBloc();
      while (dataSource.startSessionCount == 0) {
        await pumpEventQueue();
      }
      await bloc.close();
      answer(join);
      await pumpEventQueue();
    }

    test('went through: nothing was started for it, so nothing is stopped '
        '(round 4: the call screen starts the service only while it is on '
        'show)', () async {
      await closeThenAnswer(
        (Completer<Widget> join) => join.complete(const FakeCallingWidget()),
      );

      expect(native, isEmpty);
      expect(errors, isEmpty);
      // The join set the "maybe in a session" mark; no view will mount.
      expect(ActiveCallTracker.mayHaveMediaSession, isFalse);
    });

    test('failed: there is nothing to stop', () async {
      await closeThenAnswer(
        (Completer<Widget> join) => join.completeError(
          const CallOperationsException(message: 'join failed', code: 'ERR'),
        ),
      );

      expect(native, isEmpty);
    });

    testWidgets('went through after another call screen replaced it: that '
        'call keeps the service', (WidgetTester tester) async {
      await mountCallNavigator(tester);
      final Completer<Widget> firstJoin = Completer<Widget>();
      dataSource.onStartSession = (String sessionId) => sessionId == 'session_1'
          ? firstJoin.future
          : Future<Widget>.value(const FakeCallingWidget());
      CallScreenOverlay.show(
        sessionId: 'session_1',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
      for (int i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(dataSource.calls, contains('startSession:session_1'));

      // The next call's screen replaces it; the first one's bloc closes.
      CallScreenOverlay.show(
        sessionId: 'session_2',
        sessionSettingsBuilder: SessionSettingsBuilder(),
      );
      for (int i = 0; i < 4; i++) {
        await tester.pump();
      }

      firstJoin.complete(const FakeCallingWidget());
      await tester.pump();

      // Only session_2's screen started the service; the late join of the
      // replaced screen neither starts nor stops it.
      expect(native, <String>['launchOngoingCallService']);
      expect(ActiveCallTracker.mayHaveMediaSession, isTrue);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
