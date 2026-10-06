import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/constants/ui_kit_constants.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';

import '../helpers/call_bloc_harness.dart';

// ===========================================================================
// IncomingCallBloc — event -> state behaviour
//
// Seams used here (see helpers/call_bloc_harness.dart):
//   * accept/reject go through CallOperationsServiceLocator's injected
//     datasource;
//   * ringing/stop-ringing go through SoundManager's platform channel;
//   * the pre-accept permission gate goes through permission_handler's
//     platform channel;
//   * ccCallAccepted / ccCallRejected are plain in-process UI Kit events;
//   * the host's onAccept/onDecline callbacks need a BuildContext behind
//     CallNavigationContext.navigatorKey, so those two cases are widget tests.
//
// Not assertable from a VM test:
//   * what CallScreenOverlay.show() was handed (session settings, workflow) —
//     the overlay exposes only `isShowing`;
//   * IncomingCallOverlay.dismiss() — a no-op here because nothing showed it.
// ===========================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCallOperationsDataSource dataSource;
  late CallEventRecorder events;

  IncomingCallBloc buildBloc({
    Call? call,
    bool? disableSoundForCalls,
    String? customSoundForCalls,
    String? customSoundForCallsPackage,
    void Function(BuildContext, Call)? onAccept,
    void Function(BuildContext, Call)? onDecline,
    OnError? onError,
  }) => IncomingCallBloc(
    call: call ?? buildCall(),
    disableSoundForCalls: disableSoundForCalls,
    customSoundForCalls: customSoundForCalls,
    customSoundForCallsPackage: customSoundForCallsPackage,
    onAccept: onAccept,
    onDecline: onDecline,
    errorCallback: onError,
  );

  /// Stops the accept flow at the server call.
  ///
  /// Only one test in this file may run the accept flow to completion:
  /// success ends in `CallScreenOverlay.show()`, and with no Navigator mounted
  /// the entry it creates is never inserted, so the next `show()`/`dismiss()`
  /// trips OverlayEntry's "removed only once" assert. Every other test that
  /// gets past the permission gate stops here instead.
  void failAccept() {
    dataSource.acceptError = const CallOperationsException(
      message: 'Call already ended',
      code: 'CALL_ENDED',
    );
  }

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    PermissionChannelStub.install(granted: true);
    SoundChannelSpy.install();
    events = CallEventRecorder('incoming_call_bloc_test');
    // Every test's call is session_1: one ended in an earlier test must
    // not count as ended in this one.
    ActiveCallTracker.forgetFinishedCalls();
    CometChatUIKit.loggedInUser = testMe;
  });

  tearDown(() async {
    CometChatUIKit.loggedInUser = null;
    events.dispose();
    SoundChannelSpy.remove();
    PermissionChannelStub.remove();
    await CallOperationsServiceLocator.instance.reset();
    CallStateService.instance.setActiveIncomingValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  // =========================================================================
  // Ringing / construction / disposal
  // =========================================================================

  group('ringing', () {
    test(
      'construction marks an incoming call active and plays the ringtone',
      () async {
        final IncomingCallBloc bloc = buildBloc();
        addTearDown(bloc.close);

        expect(CallStateService.instance.isActiveIncomingCall.value, isTrue);

        // The ringtone's play is unawaited; let its channel call land.
        await Future<void>.delayed(Duration.zero);
        expect(SoundChannelSpy.methods, <String>['playRingtone']);
        final Map<Object?, Object?>? args = SoundChannelSpy.lastArgumentsOf(
          'playRingtone',
        );
        expect(args?['looping'], isTrue);
        expect(args?['vibrate'], isTrue);
        expect(args?['assetPath'], 'assets/sound/incoming_call.wav');
        expect(args?['package'], 'cometchat_chat_uikit');
      },
    );

    test('a custom sound asset and package override the defaults', () async {
      final IncomingCallBloc bloc = buildBloc(
        customSoundForCalls: 'assets/my_ringtone.wav',
        customSoundForCallsPackage: 'host_app',
      );
      addTearDown(bloc.close);

      await Future<void>.delayed(Duration.zero);
      final Map<Object?, Object?>? args = SoundChannelSpy.lastArgumentsOf(
        'playRingtone',
      );
      expect(args?['assetPath'], 'assets/my_ringtone.wav');
      expect(args?['package'], 'host_app');
      // Looked for in the app's own assets next, then the kit's ringtone
      // plays (round 3, P3-C14).
      expect(args?['fallbackAssetPath'], 'assets/sound/incoming_call.wav');
      expect(args?['fallbackPackage'], 'cometchat_chat_uikit');
    });

    test(
      'disableSoundForCalls suppresses both the ring and the stop',
      () async {
        final IncomingCallBloc bloc = buildBloc(disableSoundForCalls: true);
        await Future<void>.delayed(Duration.zero);
        expect(SoundChannelSpy.methods, isEmpty);

        await bloc.close();
        await Future<void>.delayed(Duration.zero);
        expect(SoundChannelSpy.methods, isEmpty);
      },
    );

    test('a banner closed after the next one started leaves the next '
        'ringtone playing (round 2, P3-C15)', () async {
      final IncomingCallBloc first = buildBloc();
      await Future<void>.delayed(Duration.zero);
      final IncomingCallBloc second = buildBloc(
        call: buildCall(sessionId: 'session_2'),
      );
      await Future<void>.delayed(Duration.zero);
      SoundChannelSpy.methods.clear();

      await first.close();
      await Future<void>.delayed(Duration.zero);
      expect(SoundChannelSpy.methods, isNot(contains('stopRingtone')));

      await second.close();
      await Future<void>.delayed(Duration.zero);
      expect(SoundChannelSpy.methods, <String>['stopRingtone']);
    });

    test('an outgoing call screen closing does not stop the incoming '
        'ringtone, nor a banner the ringback (round 2, P3-C15)', () async {
      final IncomingCallBloc incoming = buildBloc();
      final OutgoingCallBloc outgoing = OutgoingCallBloc(
        call: buildCall(sessionId: 'placed'),
      );
      await Future<void>.delayed(Duration.zero);
      SoundChannelSpy.methods.clear();

      await outgoing.close();
      await Future<void>.delayed(Duration.zero);
      expect(SoundChannelSpy.methods, isNot(contains('stopRingtone')));

      await incoming.close();
      await Future<void>.delayed(Duration.zero);
      expect(SoundChannelSpy.methods, <String>['stopCallTone', 'stopRingtone']);
    });

    test('a banner closing while the caller\'s ringback plays stops its '
        'ringtone only: the kit\'s own stop is not SoundManager.stop(), '
        'which is the host\'s (round 2 review)', () async {
      final OutgoingCallBloc outgoing = OutgoingCallBloc(
        call: buildCall(sessionId: 'placed'),
      );
      addTearDown(outgoing.close);
      final IncomingCallBloc incoming = buildBloc();
      await Future<void>.delayed(Duration.zero);
      SoundChannelSpy.methods.clear();

      await incoming.close();
      await Future<void>.delayed(Duration.zero);
      expect(SoundChannelSpy.methods, <String>['stopRingtone']);
    });

    test('close() stops the ringtone and clears the active flag', () async {
      final IncomingCallBloc bloc = buildBloc();
      await Future<void>.delayed(Duration.zero);

      await bloc.close();
      await Future<void>.delayed(Duration.zero);

      expect(SoundChannelSpy.methods, contains('stopRingtone'));
      expect(SoundChannelSpy.lastArgumentsOf('stopRingtone'), <String, Object?>{
        'handover': false,
        'keepAudio': false,
      });
      expect(CallStateService.instance.isActiveIncomingCall.value, isFalse);
    });
  });

  // =========================================================================
  // Accept
  // =========================================================================

  group('close releases the ringing record (round 1b)', () {
    tearDown(() {
      ActiveCallTracker.ringingCall = null;
      CallEventService.instance.activeCall = null;
    });

    test('a banner taken down while ringing: ringingCall is released, the '
        'active call is not, nothing is declined', () async {
      ActiveCallTracker.ringingCall = buildCall();
      CallEventService.instance.activeCall = buildCall(sessionId: 'active');
      final IncomingCallBloc bloc = buildBloc();

      await bloc.close();

      expect(ActiveCallTracker.ringingCall, isNull);
      expect(
        (CallEventService.instance.activeCall as Call?)?.sessionId,
        'active',
      );
      expect(dataSource.calls, isEmpty);
    });

    test("only this call's ringing record", () async {
      ActiveCallTracker.ringingCall = buildCall(sessionId: 'another');
      final IncomingCallBloc bloc = buildBloc();

      await bloc.close();

      expect(ActiveCallTracker.ringingCall?.sessionId, 'another');
    });

    for (final IncomingCallStatus answering in <IncomingCallStatus>[
      IncomingCallStatus.accepting,
      IncomingCallStatus.accepted,
    ]) {
      blocTest<IncomingCallBloc, IncomingCallState>(
        'nothing is released once the call is $answering',
        setUp: () => ActiveCallTracker.ringingCall = buildCall(),
        build: buildBloc,
        seed: () => IncomingCallState(status: answering),
        verify: (_) =>
            expect(ActiveCallTracker.ringingCall?.sessionId, 'session_1'),
      );
    }
  });

  group('AcceptCall', () {
    /// Runs the accept flow to completion with a Navigator mounted, so
    /// `CallScreenOverlay.show()` inserts its entry for real.
    ///
    /// Without a Navigator the call screen is not shown at all
    /// (NO_NAVIGATOR) — hence every accept test that is not about the
    /// overlay stops at the permission gate or at [failAccept].
    Future<IncomingCallBloc> acceptWithOverlay(
      WidgetTester tester, {
      SessionSettingsBuilder? callSettingsBuilder,
      String type = CallTypeConstants.audioCall,
      OnError? onError,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          home: const SizedBox.shrink(),
        ),
      );

      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(type: type),
        disableSoundForCalls: true,
        callSettingsBuilder: callSettingsBuilder,
        errorCallback: onError,
      );
      addTearDown(bloc.close);

      bloc.add(const AcceptCall());
      await tester.pump();
      return bloc;
    }

    testWidgets("the call screen reports to the incoming call's onError: a "
        'join that fails reaches the host (round 1b)', (
      WidgetTester tester,
    ) async {
      final List<Exception> errors = <Exception>[];
      final int shownBefore = ActiveCallTracker.callScreenGeneration;
      await acceptWithOverlay(tester, onError: errors.add);
      // The call screen was shown for the call.
      expect(ActiveCallTracker.callScreenGeneration, shownBefore + 1);

      // No Calls SDK in this test, so the call screen cannot join: it
      // closes at once and tells the incoming call's onError.
      await tester.pumpAndSettle();

      expect(CallScreenOverlay.isShowing, isFalse);
      expect((errors.single as CometChatException).code, 'CALLS_NOT_READY');
    });

    testWidgets(
      'accepting -> accepted, dispatches ccCallAccepted and opens the call '
      'screen',
      (WidgetTester tester) async {
        // The call screen can join: a ready Calls SDK.
        await installCallJoinDefaults();
        addTearDown(removeCallJoinDefaults);
        final IncomingCallBloc bloc = await acceptWithOverlay(tester);

        expect(bloc.state.status, IncomingCallStatus.accepted);
        expect(bloc.state.isDisabled, isFalse);
        expect(dataSource.calls, contains('acceptCall:session_1'));
        expect(events.ordered, <String>['accepted:session_1']);
        expect(CallScreenOverlay.isShowing, isTrue);
        expect(ActiveCallTracker.callScreenSessionId, 'session_1');

        CallScreenOverlay.dismiss();
        await tester.pumpAndSettle();
        expect(CallScreenOverlay.isShowing, isFalse);
      },
    );

    testWidgets('a host-supplied SessionSettingsBuilder joins with its own '
        'settings and is left as it was (P4-C14)', (WidgetTester tester) async {
      await installCallJoinDefaults();
      addTearDown(removeCallJoinDefaults);
      final SessionSettingsBuilder custom = SessionSettingsBuilder()
        ..setLayout(LayoutType.spotlight);
      final IncomingCallBloc bloc = await acceptWithOverlay(
        tester,
        callSettingsBuilder: custom,
        type: CallTypeConstants.videoCall,
      );
      await tester.pump();

      expect(bloc.state.status, IncomingCallStatus.accepted);
      expect(CallScreenOverlay.isShowing, isTrue);
      // The call joined with the host's settings, as a video call.
      final SessionSettings joinedWith = dataSource.startedSettings.single;
      expect(joinedWith.layout, LayoutType.spotlight);
      expect(joinedWith.type, SessionType.video);
      // The BLoC must not overwrite the host's builder with its own
      // audio-only workaround defaults.
      expect(custom.build().hideToggleVideoButton, isFalse);

      CallScreenOverlay.dismiss();
      await tester.pumpAndSettle();
    });

    blocTest<IncomingCallBloc, IncomingCallState>(
      'an audio call asks only for the microphone',
      build: () {
        failAccept();
        return buildBloc();
      },
      act: (IncomingCallBloc bloc) => bloc.add(const AcceptCall()),
      verify: (_) {
        expect(PermissionChannelStub.requested, isNotEmpty);
        expect(PermissionChannelStub.cameraRequested, isFalse);
      },
    );

    blocTest<IncomingCallBloc, IncomingCallState>(
      'a video call also asks for the camera',
      build: () {
        failAccept();
        return buildBloc(call: buildCall(type: CallTypeConstants.videoCall));
      },
      act: (IncomingCallBloc bloc) => bloc.add(const AcceptCall()),
      verify: (_) => expect(PermissionChannelStub.cameraRequested, isTrue),
    );

    blocTest<IncomingCallBloc, IncomingCallState>(
      'denied permissions reject the call on the server and surface an error',
      build: () {
        PermissionChannelStub.install(granted: false);
        return buildBloc();
      },
      act: (IncomingCallBloc bloc) => bloc.add(const AcceptCall()),
      expect: () => const <IncomingCallState>[
        IncomingCallState(
          status: IncomingCallStatus.accepting,
          isDisabled: true,
        ),
        // The buttons stay off: the call is declined on the server (round
        // 3 review).
        IncomingCallState(
          status: IncomingCallStatus.error,
          isDisabled: true,
          errorMessage: 'Microphone permission denied',
        ),
      ],
      verify: (_) {
        // The caller must be told: a denial is turned into a real rejection.
        expect(dataSource.calls, contains('rejectCall:session_1:rejected'));
        expect(dataSource.acceptCallCount, 0);
        expect(events.ordered, <String>['rejected:session_1']);
      },
    );

    test('after a refused permission declined the call, Accept and Decline '
        'are ignored (round 3 review)', () async {
      PermissionChannelStub.install(granted: false);
      final IncomingCallBloc bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const AcceptCall());
      await bloc.stream.firstWhere(
        (IncomingCallState s) => s.status == IncomingCallStatus.error,
      );
      PermissionChannelStub.install(granted: true);
      dataSource.calls.clear();

      bloc.add(const AcceptCall());
      bloc.add(const RejectCall());
      await pumpEventQueue();

      expect(dataSource.calls, isEmpty);
      expect(bloc.state.status, IncomingCallStatus.error);
      expect(bloc.state.isDisabled, isTrue);
    });

    test('FT2: after a failed accept (not a refusal) Accept can be tapped '
        'again', () async {
      dataSource.acceptError = const CallOperationsException(
        message: 'Network down',
        code: 'NETWORK',
      );
      final IncomingCallBloc bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const AcceptCall());
      await bloc.stream.firstWhere(
        (IncomingCallState s) => s.status == IncomingCallStatus.error,
      );
      expect(bloc.state.isDisabled, isFalse);
      dataSource.acceptError = null;

      bloc.add(const AcceptCall());
      await pumpEventQueue();

      expect(dataSource.acceptCallCount, 2);
    });

    test(
      'denied permissions reach onError as PERMISSION_DENIED (round 1b)',
      () async {
        PermissionChannelStub.install(granted: false);
        final List<Exception> errors = <Exception>[];
        final IncomingCallBloc bloc = buildBloc(onError: errors.add);
        addTearDown(bloc.close);

        bloc.add(const AcceptCall());
        await bloc.stream.firstWhere(
          (IncomingCallState s) => s.status == IncomingCallStatus.error,
        );

        final CometChatException error = errors.single as CometChatException;
        expect(error.code, 'PERMISSION_DENIED');
        expect(error.details, 'microphone');
        expect(error.message, 'Microphone permission denied');
      },
    );

    test(
      'a permanently denied camera on a video call reaches onError as '
      'PERMISSION_PERMANENTLY_DENIED, naming only the camera (round 1b)',
      () async {
        PermissionChannelStub.install(
          granted: false,
          permanentlyDenied: true,
          grantedPermissions: <Permission>{Permission.microphone},
        );
        final List<Exception> errors = <Exception>[];
        final IncomingCallBloc bloc = buildBloc(
          call: buildCall(type: CallTypeConstants.videoCall),
          onError: errors.add,
        );
        addTearDown(bloc.close);

        bloc.add(const AcceptCall());
        await bloc.stream.firstWhere(
          (IncomingCallState s) => s.status == IncomingCallStatus.error,
        );

        final CometChatException error = errors.single as CometChatException;
        expect(error.code, 'PERMISSION_PERMANENTLY_DENIED');
        expect(error.details, 'camera');
        expect(error.errorParams?['permissions'], <String>['camera']);
      },
    );

    test('a decline that fails after the refusal reaches onError too, SDK '
        'code kept (round 1b review)', () async {
      PermissionChannelStub.install(granted: false);
      final CometChatException sdkError = CometChatException(
        'ERR_CALL_CANCELLED',
        'The caller cancelled the call.',
        'Call cancelled',
      );
      dataSource.rejectError = CallOperationsException(
        message: 'Call cancelled',
        code: 'ERR_CALL_CANCELLED',
        originalException: sdkError,
      );
      final List<Exception> errors = <Exception>[];
      final IncomingCallBloc bloc = buildBloc(onError: errors.add);
      addTearDown(bloc.close);

      bloc.add(const AcceptCall());
      await bloc.stream.firstWhere(
        (IncomingCallState s) => s.status == IncomingCallStatus.error,
      );

      expect((errors.first as CometChatException).code, 'PERMISSION_DENIED');
      expect(errors.last, same(sdkError));
      expect(errors, hasLength(2));
    });

    test('an errorCallback that throws does not stop the refusal (round 1b '
        'review)', () async {
      PermissionChannelStub.install(granted: false);
      ActiveCallTracker.ringingCall = buildCall();
      addTearDown(() => ActiveCallTracker.ringingCall = null);
      final IncomingCallBloc bloc = buildBloc(
        onError: (Exception e) => throw StateError('host bug'),
      );
      addTearDown(bloc.close);

      bloc.add(const AcceptCall());
      await bloc.stream
          .firstWhere(
            (IncomingCallState s) => s.status == IncomingCallStatus.error,
          )
          .timeout(const Duration(seconds: 5));

      expect(ActiveCallTracker.ringingCall, isNull);
    });

    blocTest<IncomingCallBloc, IncomingCallState>(
      'a denied video call names the camera in the error too',
      build: () {
        PermissionChannelStub.install(granted: false);
        return buildBloc(call: buildCall(type: CallTypeConstants.videoCall));
      },
      act: (IncomingCallBloc bloc) => bloc.add(const AcceptCall()),
      verify: (IncomingCallBloc bloc) => expect(
        bloc.state.errorMessage,
        'Microphone/camera permission denied',
      ),
    );

    blocTest<IncomingCallBloc, IncomingCallState>(
      'a failing acceptCall surfaces the failure message and re-enables the '
      'buttons',
      build: () {
        failAccept();
        return buildBloc();
      },
      act: (IncomingCallBloc bloc) => bloc.add(const AcceptCall()),
      expect: () => const <IncomingCallState>[
        IncomingCallState(
          status: IncomingCallStatus.accepting,
          isDisabled: true,
        ),
        IncomingCallState(
          status: IncomingCallStatus.error,
          errorMessage: 'Call already ended',
        ),
      ],
      verify: (_) => expect(events.ordered, isEmpty),
    );

    test('a failing acceptCall reports through errorCallback', () async {
      final List<Exception> errors = <Exception>[];
      failAccept();
      final IncomingCallBloc bloc = buildBloc(onError: errors.add);
      addTearDown(bloc.close);

      bloc.add(const AcceptCall());
      await bloc.stream.firstWhere(
        (IncomingCallState s) => s.status == IncomingCallStatus.error,
      );

      expect(errors, hasLength(1));
      // The failure's own code is kept (round 1b; it used to be 'ERR'), and
      // the reason is the message a host renders, not only the details.
      final CometChatException error = errors.single as CometChatException;
      expect(error.code, 'CALL_ENDED');
      expect(error.message, 'Call already ended');
      expect(error.details, 'Call already ended');
    });

    test('a failing acceptCall hands errorCallback the SDK\'s own exception '
        '(round 1b)', () async {
      final List<Exception> errors = <Exception>[];
      final CometChatException sdkError = CometChatException(
        'ERR_CALL_ENDED',
        'The call has already ended.',
        'Call already ended',
      );
      dataSource.acceptError = CallOperationsException(
        message: 'Call already ended',
        code: 'ERR_CALL_ENDED',
        originalException: sdkError,
      );
      final IncomingCallBloc bloc = buildBloc(onError: errors.add);
      addTearDown(bloc.close);

      bloc.add(const AcceptCall());
      await bloc.stream.firstWhere(
        (IncomingCallState s) => s.status == IncomingCallStatus.error,
      );

      expect(errors.single, same(sdkError));
    });

    blocTest<IncomingCallBloc, IncomingCallState>(
      'a null session id fails before any permission or SDK work',
      build: () => buildBloc(call: NullSessionCall()),
      act: (IncomingCallBloc bloc) => bloc.add(const AcceptCall()),
      expect: () => const <IncomingCallState>[
        IncomingCallState(
          status: IncomingCallStatus.accepting,
          isDisabled: true,
        ),
        IncomingCallState(
          status: IncomingCallStatus.error,
          errorMessage: 'Session ID is null',
        ),
      ],
      verify: (_) {
        expect(dataSource.calls, isEmpty);
        expect(PermissionChannelStub.requested, isEmpty);
      },
    );

    test('onAccept is skipped when no navigator context exists', () async {
      int calls = 0;
      failAccept();
      final IncomingCallBloc bloc = buildBloc(
        onAccept: (BuildContext _, Call _) => calls++,
      );
      addTearDown(bloc.close);

      bloc.add(const AcceptCall());
      await bloc.stream.firstWhere(
        (IncomingCallState s) => s.status != IncomingCallStatus.accepting,
      );

      // The accept itself still proceeds — the host hook is best-effort.
      expect(calls, 0);
      expect(dataSource.acceptCallCount, 1);
    });

    testWidgets('onAccept receives the navigator context and the call', (
      WidgetTester tester,
    ) async {
      failAccept();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          home: const SizedBox.shrink(),
        ),
      );

      final Call call = buildCall();
      final List<Call> seen = <Call>[];
      final IncomingCallBloc bloc = buildBloc(
        call: call,
        disableSoundForCalls: true,
        onAccept: (BuildContext _, Call c) => seen.add(c),
      );
      addTearDown(bloc.close);

      bloc.add(const AcceptCall());
      await tester.pumpAndSettle();

      expect(seen, <Call>[call]);
      expect(dataSource.acceptCallCount, 1);
    });

    testWidgets('a throwing onAccept is reported, not fatal', (
      WidgetTester tester,
    ) async {
      failAccept();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          home: const SizedBox.shrink(),
        ),
      );

      final List<Exception> errors = <Exception>[];
      final IncomingCallBloc bloc = buildBloc(
        disableSoundForCalls: true,
        onAccept: (BuildContext _, Call _) =>
            throw CometChatException('HOST_ERR', 'host blew up', ''),
        onError: errors.add,
      );
      addTearDown(bloc.close);

      bloc.add(const AcceptCall());
      await tester.pumpAndSettle();

      // The host's exception is forwarded, and the accept still goes ahead.
      expect(errors.whereType<CometChatException>().first.code, 'HOST_ERR');
      expect(dataSource.acceptCallCount, 1);
    });

    for (final IncomingCallStatus blocked in <IncomingCallStatus>[
      IncomingCallStatus.cancelled,
      IncomingCallStatus.accepted,
    ]) {
      blocTest<IncomingCallBloc, IncomingCallState>(
        'AcceptCall is ignored once the call is $blocked',
        build: buildBloc,
        seed: () => IncomingCallState(status: blocked),
        act: (IncomingCallBloc bloc) => bloc.add(const AcceptCall()),
        expect: () => const <IncomingCallState>[],
        verify: (_) => expect(dataSource.calls, isEmpty),
      );
    }

    blocTest<IncomingCallBloc, IncomingCallState>(
      'a second AcceptCall while accepting does not accept twice',
      build: () {
        failAccept();
        return buildBloc();
      },
      act: (IncomingCallBloc bloc) {
        bloc
          ..add(const AcceptCall())
          ..add(const AcceptCall());
      },
      verify: (_) => expect(dataSource.acceptCallCount, 1),
    );
  });

  // =========================================================================
  // Reject
  // =========================================================================

  group('RejectCall', () {
    blocTest<IncomingCallBloc, IncomingCallState>(
      'rejecting -> rejected, and dispatches ccCallRejected',
      build: buildBloc,
      act: (IncomingCallBloc bloc) => bloc.add(const RejectCall()),
      expect: () => const <IncomingCallState>[
        IncomingCallState(
          status: IncomingCallStatus.rejecting,
          isDisabled: true,
        ),
        IncomingCallState(status: IncomingCallStatus.rejected),
      ],
      verify: (_) {
        expect(dataSource.calls, <String>['rejectCall:session_1:rejected']);
        expect(events.rejected.single.category, MessageCategoryConstants.call);
      },
    );

    blocTest<IncomingCallBloc, IncomingCallState>(
      'rejecting never asks for microphone or camera',
      build: buildBloc,
      act: (IncomingCallBloc bloc) => bloc.add(const RejectCall()),
      verify: (_) => expect(PermissionChannelStub.requested, isEmpty),
    );

    blocTest<IncomingCallBloc, IncomingCallState>(
      'a failing rejectCall surfaces the failure message and still announces '
      'the decline',
      build: () {
        dataSource.rejectError = const CallOperationsException(
          message: 'Network down',
        );
        return buildBloc();
      },
      act: (IncomingCallBloc bloc) => bloc.add(const RejectCall()),
      expect: () => const <IncomingCallState>[
        IncomingCallState(
          status: IncomingCallStatus.rejecting,
          isDisabled: true,
        ),
        IncomingCallState(
          status: IncomingCallStatus.error,
          errorMessage: 'Network down',
        ),
      ],
      // The decline is still announced, as Kotlin does: the local active
      // call, call buttons and chat bubble would otherwise stay as if the
      // call were still ringing.
      verify: (_) => expect(events.ordered, <String>['rejected:session_1']),
    );

    blocTest<IncomingCallBloc, IncomingCallState>(
      'a null session id fails before calling the server',
      build: () => buildBloc(call: NullSessionCall()),
      act: (IncomingCallBloc bloc) => bloc.add(const RejectCall()),
      expect: () => const <IncomingCallState>[
        IncomingCallState(
          status: IncomingCallStatus.rejecting,
          isDisabled: true,
        ),
        IncomingCallState(
          status: IncomingCallStatus.error,
          errorMessage: 'Session ID is null',
        ),
      ],
      verify: (_) => expect(dataSource.calls, isEmpty),
    );

    test('a failing rejectCall reports through errorCallback', () async {
      final List<Exception> errors = <Exception>[];
      dataSource.rejectError = const CallOperationsException(
        message: 'Network down',
      );
      final IncomingCallBloc bloc = buildBloc(onError: errors.add);
      addTearDown(bloc.close);

      bloc.add(const RejectCall());
      await bloc.stream.firstWhere(
        (IncomingCallState s) => s.status == IncomingCallStatus.error,
      );

      expect(errors, hasLength(1));
    });

    test('a failing rejectCall hands errorCallback the SDK\'s own exception '
        '(round 1b)', () async {
      final List<Exception> errors = <Exception>[];
      final CometChatException sdkError = CometChatException(
        'ERR_CALL_CANCELLED',
        'The caller cancelled the call.',
        'Call cancelled',
      );
      dataSource.rejectError = CallOperationsException(
        message: 'Call cancelled',
        code: 'ERR_CALL_CANCELLED',
        originalException: sdkError,
      );
      final IncomingCallBloc bloc = buildBloc(onError: errors.add);
      addTearDown(bloc.close);

      bloc.add(const RejectCall());
      await bloc.stream.firstWhere(
        (IncomingCallState s) => s.status == IncomingCallStatus.error,
      );

      expect(errors.single, same(sdkError));
    });

    for (final IncomingCallStatus blocked in <IncomingCallStatus>[
      IncomingCallStatus.cancelled,
      IncomingCallStatus.rejected,
    ]) {
      blocTest<IncomingCallBloc, IncomingCallState>(
        'RejectCall is ignored once the call is $blocked',
        build: buildBloc,
        seed: () => IncomingCallState(status: blocked),
        act: (IncomingCallBloc bloc) => bloc.add(const RejectCall()),
        expect: () => const <IncomingCallState>[],
        verify: (_) => expect(dataSource.calls, isEmpty),
      );
    }

    blocTest<IncomingCallBloc, IncomingCallState>(
      'a second RejectCall while rejecting does not reject twice',
      build: buildBloc,
      act: (IncomingCallBloc bloc) {
        bloc
          ..add(const RejectCall())
          ..add(const RejectCall());
      },
      verify: (_) => expect(dataSource.rejectCallCount, 1),
    );

    test('onDecline is skipped when no navigator context exists', () async {
      int calls = 0;
      final IncomingCallBloc bloc = buildBloc(
        onDecline: (BuildContext _, Call _) => calls++,
      );
      addTearDown(bloc.close);

      bloc.add(const RejectCall());
      await bloc.stream.firstWhere(
        (IncomingCallState s) => s.status == IncomingCallStatus.rejected,
      );

      expect(calls, 0);
      expect(dataSource.rejectCallCount, 1);
    });

    testWidgets('onDecline receives the navigator context and the call', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          home: const SizedBox.shrink(),
        ),
      );

      final Call call = buildCall();
      final List<Call> seen = <Call>[];
      final IncomingCallBloc bloc = buildBloc(
        call: call,
        disableSoundForCalls: true,
        onDecline: (BuildContext _, Call c) => seen.add(c),
      );
      addTearDown(bloc.close);

      bloc.add(const RejectCall());
      await tester.pumpAndSettle();

      expect(seen, <Call>[call]);
      expect(bloc.state.status, IncomingCallStatus.rejected);
    });

    testWidgets('a throwing onDecline is reported, not fatal', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          home: const SizedBox.shrink(),
        ),
      );

      final List<Exception> errors = <Exception>[];
      final IncomingCallBloc bloc = buildBloc(
        disableSoundForCalls: true,
        onDecline: (BuildContext _, Call _) =>
            throw CometChatException('HOST_ERR', 'host blew up', ''),
        onError: errors.add,
      );
      addTearDown(bloc.close);

      bloc.add(const RejectCall());
      await tester.pumpAndSettle();

      expect(errors.whereType<CometChatException>().first.code, 'HOST_ERR');
      expect(bloc.state.status, IncomingCallStatus.rejected);
      expect(dataSource.rejectCallCount, 1);
    });
  });

  // =========================================================================
  // Remote cancellation
  // =========================================================================

  group('CallCancelled', () {
    blocTest<IncomingCallBloc, IncomingCallState>(
      'moves to cancelled without touching the server',
      build: buildBloc,
      act: (IncomingCallBloc bloc) => bloc.add(const CallCancelled()),
      expect: () => const <IncomingCallState>[
        IncomingCallState(status: IncomingCallStatus.cancelled),
      ],
      verify: (_) {
        expect(dataSource.calls, isEmpty);
        expect(events.ordered, isEmpty);
      },
    );

    blocTest<IncomingCallBloc, IncomingCallState>(
      'the SDK onIncomingCallCancelled callback drives the same transition',
      build: buildBloc,
      act: (IncomingCallBloc bloc) => bloc.onIncomingCallCancelled(buildCall()),
      expect: () => const <IncomingCallState>[
        IncomingCallState(status: IncomingCallStatus.cancelled),
      ],
    );

    // "Ongoing" / "rejected" / "busy" reach every CallListener. For this
    // very call while nobody acted on it here, the same user answered or
    // declined it on another device (round 3, P3-C08 / P3-E32 / P3-E33):
    // it is given up here as a cancel is. Anything else is ignored.
    for (final String event in <String>['ongoing', 'rejected']) {
      void deliver(IncomingCallBloc bloc, Call call) => event == 'ongoing'
          ? bloc.onOutgoingCallAccepted(call)
          : bloc.onOutgoingCallRejected(call);

      blocTest<IncomingCallBloc, IncomingCallState>(
        'P3-E32/E33: "$event" for this call while idle cancels it',
        build: buildBloc,
        act: (IncomingCallBloc bloc) => deliver(bloc, byMe(buildCall())),
        expect: () => const <IncomingCallState>[
          IncomingCallState(status: IncomingCallStatus.cancelled),
        ],
        verify: (_) => expect(dataSource.calls, isEmpty),
      );

      blocTest<IncomingCallBloc, IncomingCallState>(
        'P3-E32/E33: "$event" for another call is ignored',
        build: buildBloc,
        act: (IncomingCallBloc bloc) =>
            deliver(bloc, byMe(buildCall(sessionId: 'someone_else'))),
        expect: () => const <IncomingCallState>[],
      );

      // Round 3 review: "ongoing" reaches every member of a group call when
      // one of them joins. Taken for this user answering elsewhere, it
      // closed every other member's banner, and nobody else could join.
      blocTest<IncomingCallBloc, IncomingCallState>(
        '"$event" for this call by someone other than the logged-in user '
        '(another member of a group call) is ignored: it rings on',
        build: () => buildBloc(
          call: buildCall(receiverType: ReceiverTypeConstants.group),
        ),
        act: (IncomingCallBloc bloc) => deliver(
          bloc,
          byOther(buildCall(receiverType: ReceiverTypeConstants.group)),
        ),
        expect: () => const <IncomingCallState>[],
      );

      blocTest<IncomingCallBloc, IncomingCallState>(
        '"$event" naming no actor is not taken for this user',
        build: buildBloc,
        act: (IncomingCallBloc bloc) => deliver(bloc, buildCall()),
        expect: () => const <IncomingCallState>[],
      );

      blocTest<IncomingCallBloc, IncomingCallState>(
        '"$event" by this user, with nobody logged in to compare with, is '
        'not taken for them',
        setUp: () => CometChatUIKit.loggedInUser = null,
        build: buildBloc,
        act: (IncomingCallBloc bloc) => deliver(bloc, byMe(buildCall())),
        expect: () => const <IncomingCallState>[],
      );

      // Accepting with the request out is covered with a real accept in
      // incoming_handled_elsewhere_test.dart: while the permission prompt
      // is up (no request yet) the answer came from another device.
      blocTest<IncomingCallBloc, IncomingCallState>(
        'P3-E32/E33: "$event" for this call while rejecting is this '
        "device's own echo: ignored",
        build: buildBloc,
        seed: () => const IncomingCallState(
          status: IncomingCallStatus.rejecting,
          isDisabled: true,
        ),
        act: (IncomingCallBloc bloc) => deliver(bloc, byMe(buildCall())),
        expect: () => const <IncomingCallState>[],
      );
    }

    blocTest<IncomingCallBloc, IncomingCallState>(
      'a cancellation blocks a later accept attempt',
      build: buildBloc,
      act: (IncomingCallBloc bloc) async {
        bloc.add(const CallCancelled());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AcceptCall());
      },
      expect: () => const <IncomingCallState>[
        IncomingCallState(status: IncomingCallStatus.cancelled),
      ],
      verify: (_) => expect(dataSource.calls, isEmpty),
    );
  });

  // =========================================================================
  // Subtitle helper
  // =========================================================================

  group('getSubtitle', () {
    Future<String> subtitleFor(WidgetTester tester, String callType) async {
      final IncomingCallBloc bloc = buildBloc(
        call: buildCall(type: callType),
        disableSoundForCalls: true,
      );
      addTearDown(bloc.close);

      late String subtitle;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          home: Builder(
            builder: (BuildContext context) {
              subtitle = bloc.getSubtitle(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      // Its 60 s ring timeout must not outlive the test.
      await tester.runAsync(bloc.close);
      return subtitle;
    }

    testWidgets('an audio call reads as an incoming audio call', (
      WidgetTester tester,
    ) async {
      expect(
        await subtitleFor(tester, CallTypeConstants.audioCall),
        'Incoming audio call',
      );
    });

    testWidgets('a video call reads as an incoming video call', (
      WidgetTester tester,
    ) async {
      expect(
        await subtitleFor(tester, CallTypeConstants.videoCall),
        'Incoming video call',
      );
    });

    // Round 3 review: a call with no type read as a video call, next to the
    // phone icon, and was answered as a voice call.
    testWidgets('a call with no type reads as a voice call, as its icon and '
        'its accept do', (WidgetTester tester) async {
      expect(await subtitleFor(tester, ''), 'Incoming audio call');
    });
  });
}
