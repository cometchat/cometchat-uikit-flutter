/// One failed-join exit, closing at once (round 4: P4-C01 with the owner's
/// "close at once", the round 2 review's C9, the round 3 review's
/// `mayHaveMediaSession` leak), and the ongoing-call service started by the
/// call screen itself (the owner's "service start B", P4-C04, P4-C13).
///
/// Round 1b made every failed join release the record and report the real
/// code; the screen still came down only on the next frame, from the
/// widget's build. Now the bloc closes it at once, before onError, leaves
/// the media session when one may be up (which also stops the Android
/// ongoing-call service), and gives back the audio the ringback or the
/// ringtone handed to the call: nothing else would, and a call that never
/// joined left the device in call audio (Android communication mode, an
/// active iOS session). There is no error screen. Nothing goes to the
/// server.
///
/// The Android service used to start inside the Calls SDK's success, before
/// the screen knew it was still wanted: a join landing after its screen
/// closed started a service nothing stopped, and the late join was undone
/// by stopping the service app-wide. The screen now starts it once it is
/// known to be the one on show, with the call's type.
///
///   flutter test test/call_ui/ongoing_call/ongoing_call_join_failure_test.dart
@Timeout(Duration(seconds: 60))
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/start_session_deadline.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/cometchat_ongoing_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_extension_constants.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/call_session_settings.dart';
import 'package:cometchat_chat_uikit/src/calls_sdk_session.dart';

import '../helpers/call_bloc_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final CallEventService service = CallEventService.instance;
  late FakeCallOperationsDataSource dataSource;
  late List<Exception> errors;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    await installCallJoinDefaults();
    SoundChannelSpy.install();
    errors = <Exception>[];
    service.activeCall = buildCall();
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    CallScreenOverlay.dismiss();
    SoundChannelSpy.remove();
    removeCallJoinDefaults();
    service.activeCall = null;
    await CallOperationsServiceLocator.instance.reset();
    CallStateService.instance.setActiveCallValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  /// The Calls SDK init fails, so the session is never ready.
  Future<void> makeCallsSdkUnready() async {
    installCallsSdk(
      FakeCallsSdkGateway()
        ..onInit = () async => throw StateError('Calls init failed'),
    );
    expect(await CallsSdkSession.instance.ensureReady(), isFalse);
  }

  /// How each `releaseHandedOverCallAudio` asked to leave the audio: true to
  /// restore, false to forget.
  List<bool> handedOverReleases() => <bool>[
    for (final MethodCall c in SoundChannelSpy.calls)
      if (c.method == 'releaseHandedOverCallAudio')
        (c.arguments as Map<Object?, Object?>)['restore']! as bool,
  ];

  /// Shows the call screen for `session_1` in the overlay, with [onError]
  /// recording what it reports and what the device looked like then.
  void showCallScreen({
    SessionSettingsBuilder? settings,
    void Function()? atOnError,
  }) {
    CallScreenOverlay.show(
      sessionId: 'session_1',
      sessionSettingsBuilder: settings ?? SessionSettingsBuilder(),
      onError: (Exception e) {
        atOnError?.call();
        errors.add(e);
      },
    );
  }

  group('P4-C01: every failed join closes the screen at once', () {
    testWidgets('CALLS_NOT_READY: closed before onError, the state carries '
        'the code, no leave (no session was asked for), the audio given '
        'back', (WidgetTester tester) async {
      await makeCallsSdkUnready();
      await mountCallNavigator(tester);
      bool? screenUpAtOnError;
      bool? activeFlagAtOnError;
      showCallScreen(
        atOnError: () {
          screenUpAtOnError = CallScreenOverlay.isShowing;
          activeFlagAtOnError = CallStateService.instance.isActiveCall.value;
        },
      );
      await tester.pump();
      await tester.pump();

      expect((errors.single as CometChatException).code, 'CALLS_NOT_READY');
      expect(screenUpAtOnError, isFalse);
      expect(activeFlagAtOnError, isFalse);
      expect(CallScreenOverlay.isShowing, isFalse);
      expect(service.activeCall, isNull);
      expect(dataSource.endSessionCount, 0);
      expect(dataSource.endCallCount, 0);
      expect(handedOverReleases(), <bool>[true]);
    });

    test('the error state carries the code onError got (P4-C01: '
        'OngoingCallState.errorCode)', () async {
      PermissionChannelStub.install(granted: false, permanentlyDenied: true);
      final OngoingCallBloc bloc = OngoingCallBloc(
        sessionSettingsBuilder: SessionSettingsBuilder(),
        sessionId: 'session_1',
        callWorkFlow: CallWorkFlow.defaultCalling,
        errorCallback: errors.add,
      );
      addTearDown(bloc.close);

      final OngoingCallState failed = await bloc.stream.firstWhere(
        (OngoingCallState s) => s.status == OngoingCallStatus.error,
      );

      expect(failed.errorCode, 'PERMISSION_PERMANENTLY_DENIED');
      expect(
        (errors.single as CometChatException).code,
        'PERMISSION_PERMANENTLY_DENIED',
      );
      expect(dataSource.startSessionCount, 0);
    });

    test('a permission request that throws fails the join with the '
        "platform's code", () async {
      PermissionChannelStub.install(granted: true);
      PermissionChannelStub.requestError = PlatformException(
        code: 'ERROR_ALREADY_REQUESTING_PERMISSIONS',
        message: 'A request for permissions is already running',
      );
      final OngoingCallBloc bloc = OngoingCallBloc(
        sessionSettingsBuilder: SessionSettingsBuilder(),
        sessionId: 'session_1',
        callWorkFlow: CallWorkFlow.defaultCalling,
        errorCallback: errors.add,
      );
      addTearDown(bloc.close);

      final OngoingCallState failed = await bloc.stream.firstWhere(
        (OngoingCallState s) => s.status == OngoingCallStatus.error,
      );

      expect(failed.errorCode, 'ERROR_ALREADY_REQUESTING_PERMISSIONS');
      expect(service.activeCall, isNull);
      expect(dataSource.startSessionCount, 0);
    });

    testWidgets('JOIN_TIMEOUT the Calls SDK never answers: the session is '
        'left, the "maybe in a session" mark cleared (round 3 review), and '
        'the audio restored after the leave', (WidgetTester tester) async {
      dataSource.onStartSession = (_) => joinWithDeadline((_, _) {});
      await mountCallNavigator(tester);
      showCallScreen();
      await tester.pump();
      await tester.pump();
      expect(ActiveCallTracker.mayHaveMediaSession, isTrue);

      await tester.pump(const Duration(seconds: 31));
      await tester.pump();

      expect((errors.single as CometChatException).code, 'JOIN_TIMEOUT');
      expect(CallScreenOverlay.isShowing, isFalse);
      expect(dataSource.endSessionCount, 1);
      expect(dataSource.endCallCount, 0);
      expect(ActiveCallTracker.mayHaveMediaSession, isFalse);
      expect(handedOverReleases(), <bool>[true]);
    });

    testWidgets('JOIN_FAILED: the Calls SDK refused (nothing to leave), the '
        'screen closed, the audio restored', (WidgetTester tester) async {
      dataSource.startSessionError = const CallOperationsException(
        message: 'Invalid call token',
        code: 'ERR_INVALID_TOKEN',
      );
      await mountCallNavigator(tester);
      showCallScreen();
      await tester.pump();
      await tester.pump();

      expect((errors.single as CometChatException).code, 'JOIN_FAILED');
      expect(CallScreenOverlay.isShowing, isFalse);
      expect(dataSource.endSessionCount, 0);
      expect(handedOverReleases(), <bool>[true]);
    });

    testWidgets('the widget no longer takes the screen down from its build: '
        'an error state it is handed pops nothing', (
      WidgetTester tester,
    ) async {
      // A host's own bloc in the error state, on a screen the host pushed.
      // The widget used to pop it (or dismiss the overlay) on the next
      // frame; the bloc closes its own screen now, once.
      const OngoingCallState failed = OngoingCallState(
        status: OngoingCallStatus.error,
        errorMessage: 'Call service is not ready. Please try again.',
        errorCode: 'CALLS_NOT_READY',
      );
      final _MockOngoingCallBloc bloc = _MockOngoingCallBloc();
      whenListen(
        bloc,
        Stream<OngoingCallState>.value(failed),
        initialState: failed,
      );
      when(() => bloc.isClosed).thenReturn(false);
      await mountCallNavigator(tester);
      unawaited(
        CallNavigationContext.navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => CometChatOngoingCall(
              sessionId: 'session_1',
              sessionSettingsBuilder: SessionSettingsBuilder(),
              bloc: bloc,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(CometChatOngoingCall), findsOneWidget);
      expect(find.text('chat'), findsNothing);
    });

    testWidgets('a failed join after the screen joined (the native '
        'watchdog) leaves the session, which stops the service, and restores '
        'the audio only after the leave', (WidgetTester tester) async {
      ActiveCallTracker.nativeJoinTimeout = const Duration(seconds: 30);
      final List<String> order = <String>[];
      await mountCallNavigator(tester);
      SoundChannelSpy.onCall = (MethodCall c) async {
        if (c.method == 'releaseHandedOverCallAudio') {
          order.add('restore after ${dataSource.endSessionCount} leave(s)');
        }
      };
      showCallScreen();
      await tester.pump();
      await tester.pump();
      expect(CallsPluginChannelRecorder.methods, <String>[
        'launchOngoingCallService',
      ]);

      await tester.pump(const Duration(seconds: 31));
      await tester.pump();

      expect((errors.single as CometChatException).code, 'JOIN_TIMEOUT');
      expect(order, <String>['restore after 1 leave(s)']);
      expect(dataSource.endCallCount, 0);
      expect(CallScreenOverlay.isShowing, isFalse);
    });
  });

  group('the Android ongoing-call service starts from the call screen', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    test('P4-C13: a voice call on the kit settings starts it as a voice call '
        '(isVideo false), once joined', () async {
      final OngoingCallBloc bloc = OngoingCallBloc(
        sessionSettingsBuilder: CallSessionSettings.forCall(isVideo: false),
        sessionId: 'session_1',
        callWorkFlow: CallWorkFlow.defaultCalling,
      );
      addTearDown(bloc.close);
      await bloc.stream.firstWhere(
        (OngoingCallState s) => s.status == OngoingCallStatus.active,
      );

      expect(
        CallsPluginChannelRecorder.argumentsOf('launchOngoingCallService'),
        <Object?>[
          <Object?, Object?>{'isVideo': false},
        ],
      );
    });

    test('P4-C13: a video call starts it as a video call', () async {
      final OngoingCallBloc bloc = OngoingCallBloc(
        sessionSettingsBuilder: CallSessionSettings.forCall(isVideo: true),
        sessionId: 'session_1',
        callWorkFlow: CallWorkFlow.defaultCalling,
      );
      addTearDown(bloc.close);
      await bloc.stream.firstWhere(
        (OngoingCallState s) => s.status == OngoingCallStatus.active,
      );

      expect(
        CallsPluginChannelRecorder.argumentsOf('launchOngoingCallService'),
        <Object?>[
          <Object?, Object?>{'isVideo': true},
        ],
      );
    });

    test('a call screen that fails before joining starts nothing', () async {
      await makeCallsSdkUnready();
      final OngoingCallBloc bloc = OngoingCallBloc(
        sessionSettingsBuilder: SessionSettingsBuilder(),
        sessionId: 'session_1',
        callWorkFlow: CallWorkFlow.defaultCalling,
      );
      addTearDown(bloc.close);
      await bloc.stream.firstWhere(
        (OngoingCallState s) => s.status == OngoingCallStatus.error,
      );

      expect(CallsPluginChannelRecorder.methods, isEmpty);
    });

    test('P4-C04: End while connecting (the bloc still open): the join that '
        'lands afterwards starts nothing and shows nothing', () async {
      final Completer<Widget> join = Completer<Widget>();
      dataSource.onStartSession = (_) => join.future;
      final OngoingCallBloc bloc = OngoingCallBloc(
        sessionSettingsBuilder: SessionSettingsBuilder(),
        sessionId: 'session_1',
        callWorkFlow: CallWorkFlow.defaultCalling,
      );
      addTearDown(bloc.close);
      while (dataSource.startSessionCount == 0) {
        await pumpEventQueue();
      }
      bloc.add(const EndCallButtonPressed());
      await pumpEventQueue();

      join.complete(const FakeCallingWidget());
      await pumpEventQueue();

      expect(bloc.isClosed, isFalse);
      expect(CallsPluginChannelRecorder.methods, isEmpty);
      expect(bloc.state.callingWidget, isNull);
      expect(ActiveCallTracker.mayHaveMediaSession, isFalse);
      expect(dataSource.endCallCount, 1);
    });

    test('P4-C04: a join that lands after its screen closed starts nothing '
        'and stops nothing', () async {
      final Completer<Widget> join = Completer<Widget>();
      dataSource.onStartSession = (_) => join.future;
      final OngoingCallBloc bloc = OngoingCallBloc(
        sessionSettingsBuilder: SessionSettingsBuilder(),
        sessionId: 'session_1',
        callWorkFlow: CallWorkFlow.defaultCalling,
      );
      while (dataSource.startSessionCount == 0) {
        await pumpEventQueue();
      }
      await bloc.close();
      join.complete(const FakeCallingWidget());
      await pumpEventQueue();

      expect(CallsPluginChannelRecorder.methods, isEmpty);
      expect(ActiveCallTracker.mayHaveMediaSession, isFalse);
    });
  });
}

class _MockOngoingCallBloc extends MockBloc<OngoingCallEvent, OngoingCallState>
    implements OngoingCallBloc {}
