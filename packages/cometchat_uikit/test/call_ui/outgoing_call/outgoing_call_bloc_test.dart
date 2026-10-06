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
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/cometchat_outgoing_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/constants/ui_kit_constants.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_events.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';

import '../helpers/call_bloc_harness.dart';

// ===========================================================================
// OutgoingCallBloc — event -> state behaviour
//
// Seams used here:
//   * cancel goes through CallOperationsServiceLocator's injected datasource;
//   * ringback goes through SoundManager's platform channel;
//   * the post-accept permission gate goes through permission_handler's
//     platform channel;
//   * screen dismissal goes through CallNavigationContext.navigatorKey, so
//     the tests that care about it mount a real Navigator.
//
// Not reachable from a VM test:
//   * what CallScreenOverlay.show() was handed after an accept — only
//     `isShowing` is observable, and inserting the entry needs a Navigator.
// ===========================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCallOperationsDataSource dataSource;
  late CallEventRecorder events;

  OutgoingCallBloc buildBloc({
    Call? call,
    bool? disableSoundForCalls,
    String? customSoundForCalls,
    String? customSoundForCallsPackage,
    void Function(BuildContext, Call)? onCancelledCallTap,
    OnError? onError,
  }) => OutgoingCallBloc(
    call: call ?? buildCall(),
    disableSoundForCalls: disableSoundForCalls,
    customSoundForCalls: customSoundForCalls,
    customSoundForCallsPackage: customSoundForCallsPackage,
    onCancelledCallTap: onCancelledCallTap,
    errorCallback: onError,
  );

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    PermissionChannelStub.install(granted: true);
    SoundChannelSpy.install();
    events = CallEventRecorder('outgoing_call_bloc_test');
  });

  tearDown(() async {
    events.dispose();
    SoundChannelSpy.remove();
    PermissionChannelStub.remove();
    await CallOperationsServiceLocator.instance.reset();
    CallStateService.instance.setActiveOutgoingValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  // =========================================================================
  // Dialling / construction / disposal
  // =========================================================================

  group('dialling', () {
    test(
      'construction marks an outgoing call active and plays ringback',
      () async {
        final OutgoingCallBloc bloc = buildBloc();
        addTearDown(bloc.close);

        expect(CallStateService.instance.isActiveOutgoingCall.value, isTrue);
        expect(CometChatCallEvents.callEventsListener, isNotEmpty);

        await Future<void>.delayed(Duration.zero);
        expect(SoundChannelSpy.methods, <String>['playCallTone']);
        expect(
          SoundChannelSpy.lastArgumentsOf('playCallTone')?['assetPath'],
          'assets/sound/outgoing_call.wav',
        );
        expect(
          SoundChannelSpy.lastArgumentsOf('playCallTone')?['isVideo'],
          isFalse,
        );
      },
    );

    test('a custom sound asset and package override the defaults', () async {
      final OutgoingCallBloc bloc = buildBloc(
        customSoundForCalls: 'assets/my_ringback.wav',
        customSoundForCallsPackage: 'host_app',
      );
      addTearDown(bloc.close);

      await Future<void>.delayed(Duration.zero);
      expect(
        SoundChannelSpy.lastArgumentsOf('playCallTone')?['assetPath'],
        'assets/my_ringback.wav',
      );
      expect(
        SoundChannelSpy.lastArgumentsOf('playCallTone')?['package'],
        'host_app',
      );
    });

    test(
      'disableSoundForCalls suppresses both the ring and the stop',
      () async {
        final OutgoingCallBloc bloc = buildBloc(disableSoundForCalls: true);
        await Future<void>.delayed(Duration.zero);
        expect(SoundChannelSpy.methods, isEmpty);

        await bloc.close();
        await Future<void>.delayed(Duration.zero);
        expect(SoundChannelSpy.methods, isEmpty);
      },
    );

    test(
      'close() stops ringback, clears the flag and drops the event listener',
      () async {
        final OutgoingCallBloc bloc = buildBloc();
        await Future<void>.delayed(Duration.zero);
        expect(CometChatCallEvents.callEventsListener, isNotEmpty);

        await bloc.close();
        await Future<void>.delayed(Duration.zero);

        expect(SoundChannelSpy.methods, contains('stopCallTone'));
        expect(CallStateService.instance.isActiveOutgoingCall.value, isFalse);
        // Only the test's own recorder is left registered.
        expect(CometChatCallEvents.callEventsListener.values, <Object>[events]);
      },
    );
  });

  // =========================================================================
  // Cancel
  // =========================================================================

  group('CancelCall', () {
    blocTest<OutgoingCallBloc, OutgoingCallState>(
      'cancels with the cancelled status so the callee stops ringing',
      build: buildBloc,
      act: (OutgoingCallBloc bloc) => bloc.add(const CancelCall()),
      expect: () => const <OutgoingCallState>[
        OutgoingCallState(
          status: OutgoingCallStatus.cancelling,
          isCallRejected: true,
        ),
        // End stays dead: the screen is closing, and re-enabling it let a
        // second tap send another cancel (ENG-39486).
        OutgoingCallState(
          status: OutgoingCallStatus.rejected,
          isCallRejected: true,
        ),
      ],
      verify: (_) {
        // 'cancelled', not 'rejected': the receiver only gets
        // onIncomingCallCancelled (and dismisses its overlay) for the former.
        expect(dataSource.calls, <String>['rejectCall:session_1:cancelled']);
        expect(events.rejected.single.category, MessageCategoryConstants.call);
      },
    );

    blocTest<OutgoingCallBloc, OutgoingCallState>(
      'a failing cancel closes quietly and keeps End dead',
      build: () {
        dataSource.rejectError = const CallOperationsException(
          message: 'Network down',
        );
        // The best-effort endCall that follows (round 2) finds no call in
        // progress, as when the callee has not answered.
        dataSource.endCallError = const CallOperationsException(
          message: 'Call not in progress',
        );
        return buildBloc();
      },
      act: (OutgoingCallBloc bloc) => bloc.add(const CancelCall()),
      expect: () => const <OutgoingCallState>[
        OutgoingCallState(
          status: OutgoingCallStatus.cancelling,
          isCallRejected: true,
        ),
        // As Kotlin: a cancel that fails is almost always a call that has
        // already finished, so the screen closes instead of raising an error
        // (the "Something went wrong" of ENG-39486). The failure still goes
        // to errorCallback — see the next test.
        OutgoingCallState(
          status: OutgoingCallStatus.rejected,
          isCallRejected: true,
        ),
      ],
      verify: (_) => expect(events.ordered, isEmpty),
    );

    test('a failing cancel reports through errorCallback', () async {
      final List<Exception> errors = <Exception>[];
      dataSource.rejectError = const CallOperationsException(
        message: 'Network down',
      );
      final OutgoingCallBloc bloc = buildBloc(onError: errors.add);
      addTearDown(bloc.close);

      bloc.add(const CancelCall());
      await bloc.stream.firstWhere(
        (OutgoingCallState s) => s.status == OutgoingCallStatus.rejected,
      );

      // No SDK exception behind this failure: the code falls back to ERR
      // and the reason is the message, where a host reads it.
      final CometChatException error = errors.single as CometChatException;
      expect(error.code, 'ERR');
      expect(error.message, 'Network down');
      expect(error.details, 'Network down');
    });

    test("a failing cancel with no SDK exception keeps the datasource's code "
        '(round 2, P2-C02)', () async {
      final List<Exception> errors = <Exception>[];
      dataSource.rejectError = const CallOperationsException(
        message: 'Call not found',
        code: 'ERR_CALL_NOT_FOUND',
      );
      final OutgoingCallBloc bloc = buildBloc(onError: errors.add);
      addTearDown(bloc.close);

      bloc.add(const CancelCall());
      await bloc.stream.firstWhere(
        (OutgoingCallState s) => s.status == OutgoingCallStatus.rejected,
      );

      final CometChatException error = errors.first as CometChatException;
      expect(error.code, 'ERR_CALL_NOT_FOUND');
      expect(error.message, 'Call not found');
    });

    test('an errorCallback that throws does not stop the close (round 1b '
        'review)', () async {
      dataSource.rejectError = const CallOperationsException(
        message: 'Network down',
      );
      final OutgoingCallBloc bloc = buildBloc(
        onError: (Exception e) => throw StateError('host bug'),
      );
      addTearDown(bloc.close);

      bloc.add(const CancelCall());
      await bloc.stream
          .firstWhere(
            (OutgoingCallState s) => s.status == OutgoingCallStatus.rejected,
          )
          .timeout(const Duration(seconds: 5));
    });

    test('a failing cancel hands errorCallback the SDK\'s own exception, code '
        'kept (round 1b)', () async {
      final List<Exception> errors = <Exception>[];
      final CometChatException sdkError = CometChatException(
        'ERR_CALL_ENDED',
        'The call has already ended.',
        'Call already ended',
      );
      dataSource.rejectError = CallOperationsException(
        message: 'Call already ended',
        code: 'ERR_CALL_ENDED',
        originalException: sdkError,
      );
      final OutgoingCallBloc bloc = buildBloc(onError: errors.add);
      addTearDown(bloc.close);

      bloc.add(const CancelCall());
      await bloc.stream.firstWhere(
        (OutgoingCallState s) => s.status == OutgoingCallStatus.rejected,
      );

      expect(errors.single, same(sdkError));
    });

    blocTest<OutgoingCallBloc, OutgoingCallState>(
      'a null session id fails before calling the server',
      build: () => buildBloc(call: NullSessionCall()),
      act: (OutgoingCallBloc bloc) => bloc.add(const CancelCall()),
      expect: () => const <OutgoingCallState>[
        OutgoingCallState(
          status: OutgoingCallStatus.cancelling,
          isCallRejected: true,
        ),
        OutgoingCallState(
          status: OutgoingCallStatus.error,
          errorMessage: 'Session ID is null',
        ),
      ],
      verify: (_) => expect(dataSource.calls, isEmpty),
    );

    blocTest<OutgoingCallBloc, OutgoingCallState>(
      'a second CancelCall after the first completes is ignored',
      build: () => buildBloc(disableSoundForCalls: true),
      act: (OutgoingCallBloc bloc) async {
        bloc.add(const CancelCall());
        await bloc.stream.firstWhere(
          (OutgoingCallState s) => s.status == OutgoingCallStatus.rejected,
        );
        bloc.add(const CancelCall());
      },
      // A finished cancel now ends on `rejected, isCallRejected: true`, and
      // the guard also covers the terminal statuses, so a second tap sends
      // nothing to the server and does not close the screen again.
      verify: (_) => expect(dataSource.rejectCallCount, 1),
    );

    blocTest<OutgoingCallBloc, OutgoingCallState>(
      'a second CancelCall while the first is still cancelling is ignored',
      build: () => buildBloc(disableSoundForCalls: true),
      seed: () =>
          const OutgoingCallState(status: OutgoingCallStatus.cancelling),
      act: (OutgoingCallBloc bloc) => bloc.add(const CancelCall()),
      expect: () => const <OutgoingCallState>[],
      verify: (_) => expect(dataSource.calls, isEmpty),
    );

    blocTest<OutgoingCallBloc, OutgoingCallState>(
      'CancelCall is ignored once the callee has rejected',
      build: buildBloc,
      seed: () => const OutgoingCallState(isCallRejected: true),
      act: (OutgoingCallBloc bloc) => bloc.add(const CancelCall()),
      expect: () => const <OutgoingCallState>[],
      verify: (_) => expect(dataSource.calls, isEmpty),
    );

    test(
      'onCancelledCallTap is skipped when no navigator context exists',
      () async {
        int taps = 0;
        final OutgoingCallBloc bloc = buildBloc(
          onCancelledCallTap: (BuildContext _, Call _) => taps++,
        );
        addTearDown(bloc.close);

        bloc.add(const CancelCall());
        await bloc.stream.firstWhere(
          (OutgoingCallState s) => s.status == OutgoingCallStatus.rejected,
        );

        expect(taps, 0);
        expect(dataSource.rejectCallCount, 1);
      },
    );

    testWidgets(
      'onCancelledCallTap takes over completely — no server cancel at all',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: CallNavigationContext.navigatorKey,
            home: const SizedBox.shrink(),
          ),
        );

        final Call call = buildCall();
        final List<Call> taps = <Call>[];
        final OutgoingCallBloc bloc = buildBloc(
          call: call,
          disableSoundForCalls: true,
          onCancelledCallTap: (BuildContext _, Call c) => taps.add(c),
        );
        addTearDown(bloc.close);

        bloc.add(const CancelCall());
        await tester.pumpAndSettle();

        expect(taps, <Call>[call]);
        // The handler returns early: no state change, no rejectCall, and so
        // nothing tells the callee to stop ringing. That is the host's job
        // once it opts in.
        expect(bloc.state, const OutgoingCallState());
        expect(dataSource.calls, isEmpty);

        // Closed here: the no-answer timer runs on while the host has it
        // (round 2, P2-C07), and closing sends no second cancel.
        await tester.runAsync(bloc.close);
        expect(dataSource.calls, isEmpty);
      },
    );

    testWidgets('a throwing onCancelledCallTap falls back to a real cancel', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );

      final OutgoingCallBloc bloc = buildBloc(
        disableSoundForCalls: true,
        onCancelledCallTap: (BuildContext _, Call _) =>
            throw StateError('host blew up'),
      );
      addTearDown(bloc.close);

      bloc.add(const CancelCall());
      await tester.pumpAndSettle();

      // The early `return` is inside the try, so a throwing host hook does
      // not swallow the cancel — the BLoC carries on and tells the server.
      expect(dataSource.calls, <String>['rejectCall:session_1:cancelled']);
      expect(bloc.state.status, OutgoingCallStatus.rejected);
    });

    testWidgets('a cancelled call produces no conversation record', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );

      final OutgoingCallBloc bloc = buildBloc(disableSoundForCalls: true);
      addTearDown(bloc.close);

      bloc.add(const CancelCall());
      await tester.pumpAndSettle();

      // FINDING: cancelling an outgoing call leaves no record in the
      // conversation. The only thing the BLoC broadcasts is ccCallRejected,
      // and nothing in the UI Kit turns that into a message: no
      // CometChatMessageEvents.ccMessageSent, no call bubble, no conversation
      // update. The caller and the callee are both left with a call that never
      // appears in the chat, while an *answered* call does get an end-call
      // record via OngoingCallBloc's ccCallEnded.
      expect(events.ordered, <String>['rejected:session_1']);
      expect(events.ended, isEmpty);
    });
  });

  // =========================================================================
  // Remote accept
  // =========================================================================

  group('OutgoingCallAccepted', () {
    /// Runs the accept flow to completion with a Navigator mounted, so
    /// `CallScreenOverlay.show()` inserts its entry for real. With no
    /// Navigator the call screen is not shown at all (NO_NAVIGATOR), which
    /// is why every other accept test denies permissions instead.
    Future<OutgoingCallBloc> acceptWithOverlay(
      WidgetTester tester, {
      SessionSettingsBuilder? callSettingsBuilder,
      String type = CallTypeConstants.audioCall,
      OnError? onError,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          home: const Scaffold(body: Text('messages')),
        ),
      );
      unawaited(
        CallNavigationContext.navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('outgoing call')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final OutgoingCallBloc bloc = OutgoingCallBloc(
        call: buildCall(type: type),
        disableSoundForCalls: true,
        callSettingsBuilder: callSettingsBuilder,
        errorCallback: onError,
      );
      addTearDown(bloc.close);

      bloc.add(OutgoingCallAccepted(buildCall(type: type)));
      await tester.pump();
      return bloc;
    }

    testWidgets("the call screen reports to the outgoing call's onError: a "
        'join that fails reaches the host (round 1b)', (
      WidgetTester tester,
    ) async {
      final List<Exception> errors = <Exception>[];
      await acceptWithOverlay(tester, onError: errors.add);
      expect(CallScreenOverlay.isShowing, isTrue);

      // No Calls SDK in this test, so the call screen cannot join.
      await tester.pumpAndSettle();

      expect(CallScreenOverlay.isShowing, isFalse);
      expect((errors.single as CometChatException).code, 'CALLS_NOT_READY');
    });

    testWidgets('moves to accepted, pops the dialler and opens the call '
        'screen', (WidgetTester tester) async {
      final OutgoingCallBloc bloc = await acceptWithOverlay(tester);

      expect(bloc.state.status, OutgoingCallStatus.accepted);
      expect(CallScreenOverlay.isShowing, isTrue);

      await tester.pumpAndSettle();
      expect(find.text('outgoing call'), findsNothing);
      // The call screen the overlay hosts tears itself down once it finds the
      // Calls SDK unavailable, which also clears the static entry.
      expect(CallScreenOverlay.isShowing, isFalse);
    });

    testWidgets('a host-supplied SessionSettingsBuilder is used as-is', (
      WidgetTester tester,
    ) async {
      final SessionSettingsBuilder custom = SessionSettingsBuilder()
        ..setLayout(LayoutType.spotlight);
      final OutgoingCallBloc bloc = await acceptWithOverlay(
        tester,
        callSettingsBuilder: custom,
      );

      expect(bloc.state.status, OutgoingCallStatus.accepted);
      expect(CallScreenOverlay.isShowing, isTrue);
      // An audio call would otherwise get the startVideoPaused workaround;
      // the host's builder must not be rewritten.
      expect(custom.build().hideToggleVideoButton, isFalse);

      await tester.pumpAndSettle();
    });

    blocTest<OutgoingCallBloc, OutgoingCallState>(
      'an audio call asks only for the microphone',
      build: () {
        PermissionChannelStub.install(granted: false);
        return buildBloc(disableSoundForCalls: true);
      },
      act: (OutgoingCallBloc bloc) =>
          bloc.add(OutgoingCallAccepted(buildCall())),
      verify: (_) {
        expect(PermissionChannelStub.requested, isNotEmpty);
        expect(PermissionChannelStub.cameraRequested, isFalse);
      },
    );

    blocTest<OutgoingCallBloc, OutgoingCallState>(
      'a video call also asks for the camera',
      build: () {
        PermissionChannelStub.install(granted: false);
        return buildBloc(disableSoundForCalls: true);
      },
      act: (OutgoingCallBloc bloc) => bloc.add(
        OutgoingCallAccepted(buildCall(type: CallTypeConstants.videoCall)),
      ),
      verify: (_) => expect(PermissionChannelStub.cameraRequested, isTrue),
    );

    blocTest<OutgoingCallBloc, OutgoingCallState>(
      'denied permissions stop short of joining the call',
      build: () {
        PermissionChannelStub.install(granted: false);
        return buildBloc(disableSoundForCalls: true);
      },
      act: (OutgoingCallBloc bloc) =>
          bloc.add(OutgoingCallAccepted(buildCall())),
      // End goes dead on accept, as in Kotlin: cancelling an accepted call
      // fails, and the permission prompt can keep this screen up a while.
      expect: () => const <OutgoingCallState>[
        OutgoingCallState(
          status: OutgoingCallStatus.accepted,
          isCallRejected: true,
        ),
      ],
      verify: (_) => expect(events.ordered, isEmpty),
    );

    test('denied permissions after the accept release the call and reach '
        'onError, with nothing sent to the server (round 1b)', () async {
      PermissionChannelStub.install(granted: false);
      CallEventService.instance.activeCall = buildCall();
      addTearDown(() => CallEventService.instance.activeCall = null);
      final List<Exception> errors = <Exception>[];
      final OutgoingCallBloc bloc = buildBloc(
        disableSoundForCalls: true,
        onError: errors.add,
      );
      addTearDown(bloc.close);

      bloc.add(OutgoingCallAccepted(buildCall()));
      await pumpEventQueue();

      final CometChatException error = errors.single as CometChatException;
      expect(error.code, 'PERMISSION_DENIED');
      expect(error.details, 'microphone');
      expect(CallEventService.instance.activeCall, isNull);
      // Android parity: no endCall, no reject.
      expect(dataSource.calls, isEmpty);
    });

    test('accepted with no overlay to show the call on: the record is '
        'released, no call screen is recorded, onError gets NO_NAVIGATOR, '
        'and no endCall goes out (round 2, P2-C09; owner: never endCall on '
        'an unexpected end)', () async {
      CallEventService.instance.activeCall = buildCall();
      addTearDown(() => CallEventService.instance.activeCall = null);
      final List<Exception> errors = <Exception>[];
      final OutgoingCallBloc bloc = buildBloc(
        disableSoundForCalls: true,
        onError: errors.add,
      );
      addTearDown(bloc.close);

      bloc.add(OutgoingCallAccepted(buildCall()));
      await pumpEventQueue();

      expect(CallScreenOverlay.isShowing, isFalse);
      expect(ActiveCallTracker.callScreenSessionId, isNull);
      expect(ActiveCallTracker.callScreenWorkFlow, isNull);
      expect(CallEventService.instance.activeCall, isNull);
      expect((errors.single as CometChatException).code, 'NO_NAVIGATOR');
      expect(dataSource.calls, isEmpty);
    });

    test('a permanently denied camera after a video accept is '
        'PERMISSION_PERMANENTLY_DENIED (round 1b)', () async {
      PermissionChannelStub.install(granted: false, permanentlyDenied: true);
      final List<Exception> errors = <Exception>[];
      final OutgoingCallBloc bloc = buildBloc(
        disableSoundForCalls: true,
        onError: errors.add,
      );
      addTearDown(bloc.close);

      bloc.add(
        OutgoingCallAccepted(buildCall(type: CallTypeConstants.videoCall)),
      );
      await pumpEventQueue();

      final CometChatException error = errors.single as CometChatException;
      expect(error.code, 'PERMISSION_PERMANENTLY_DENIED');
      expect(error.details, 'microphone,camera');
    });

    blocTest<OutgoingCallBloc, OutgoingCallState>(
      'the SDK onOutgoingCallAccepted callback drives the same transition',
      build: () {
        PermissionChannelStub.install(granted: false);
        return buildBloc(disableSoundForCalls: true);
      },
      act: (OutgoingCallBloc bloc) => bloc.onOutgoingCallAccepted(buildCall()),
      expect: () => const <OutgoingCallState>[
        OutgoingCallState(
          status: OutgoingCallStatus.accepted,
          isCallRejected: true,
        ),
      ],
    );
  });

  // =========================================================================
  // Remote reject
  // =========================================================================

  group('OutgoingCallRejected', () {
    blocTest<OutgoingCallBloc, OutgoingCallState>(
      'moves to rejected without touching the server',
      build: () => buildBloc(disableSoundForCalls: true),
      act: (OutgoingCallBloc bloc) =>
          bloc.add(OutgoingCallRejected(buildCall())),
      expect: () => const <OutgoingCallState>[
        OutgoingCallState(
          status: OutgoingCallStatus.rejected,
          isCallRejected: true,
        ),
      ],
      verify: (_) {
        expect(dataSource.calls, isEmpty);
        expect(events.ordered, isEmpty);
      },
    );

    blocTest<OutgoingCallBloc, OutgoingCallState>(
      'the SDK onOutgoingCallRejected callback drives the same transition',
      build: () => buildBloc(disableSoundForCalls: true),
      act: (OutgoingCallBloc bloc) => bloc.onOutgoingCallRejected(buildCall()),
      expect: () => const <OutgoingCallState>[
        OutgoingCallState(
          status: OutgoingCallStatus.rejected,
          isCallRejected: true,
        ),
      ],
    );
  });

  // =========================================================================
  // Screen dismissal — _popScreen
  // =========================================================================

  group('_popScreen', () {
    /// Mounts a two-route stack: the "messages" screen with the outgoing call
    /// screen pushed on top, mirroring how the UI Kit presents a call.
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
            builder: (_) => const Scaffold(body: Text('outgoing call')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('outgoing call'), findsOneWidget);
    }

    testWidgets('a remote reject pops the outgoing call screen', (
      WidgetTester tester,
    ) async {
      await pumpCallOverMessages(tester);

      final OutgoingCallBloc bloc = buildBloc(disableSoundForCalls: true);
      addTearDown(bloc.close);

      bloc.add(OutgoingCallRejected(buildCall()));
      await tester.pumpAndSettle();

      expect(find.text('outgoing call'), findsNothing);
      expect(find.text('messages'), findsOneWidget);
    });

    testWidgets('a late reject after the user already cancelled does not pop '
        'the chat', (WidgetTester tester) async {
      await pumpCallOverMessages(tester);

      final OutgoingCallBloc bloc = buildBloc(disableSoundForCalls: true);
      addTearDown(bloc.close);

      bloc.add(const CancelCall());
      await tester.pumpAndSettle();
      expect(find.text('messages'), findsOneWidget);

      // The server's rejection can still be in flight when the caller hangs
      // up; the SDK delivers it after the cancel has already popped.
      bloc.add(OutgoingCallRejected(buildCall()));
      await tester.pumpAndSettle();

      // The screen closes once: the second close is a no-op, so the messages
      // screen underneath survives. It used to be popped as well, leaving the
      // user on an empty navigator.
      expect(find.text('messages'), findsOneWidget);
      expect(
        CallNavigationContext.navigatorKey.currentState!.canPop(),
        isFalse,
      );
    });

    testWidgets('a failed cancel still pops the call screen', (
      WidgetTester tester,
    ) async {
      dataSource.rejectError = const CallOperationsException(
        message: 'Network down',
      );
      await pumpCallOverMessages(tester);

      final OutgoingCallBloc bloc = buildBloc(disableSoundForCalls: true);
      addTearDown(bloc.close);

      bloc.add(const CancelCall());
      await tester.pumpAndSettle();

      // The user must not be stranded on a call screen just because the
      // cancel request failed.
      expect(bloc.state.status, OutgoingCallStatus.rejected);
      expect(find.text('outgoing call'), findsNothing);
    });

    testWidgets('a denied post-accept permission pops the call screen', (
      WidgetTester tester,
    ) async {
      PermissionChannelStub.install(granted: false);
      await pumpCallOverMessages(tester);

      final OutgoingCallBloc bloc = buildBloc(disableSoundForCalls: true);
      addTearDown(bloc.close);

      bloc.add(OutgoingCallAccepted(buildCall()));
      await tester.pumpAndSettle();

      expect(find.text('outgoing call'), findsNothing);
      expect(find.text('messages'), findsOneWidget);
    });
  });

  // =========================================================================
  // Round 1b: the screen goes away without the bloc closing it
  // =========================================================================

  group('the screen is removed from outside (round 1b)', () {
    tearDown(() => CallEventService.instance.activeCall = null);

    test('while ringing: the call is cancelled on the server and its record '
        'released', () async {
      CallEventService.instance.activeCall = buildCall();
      final OutgoingCallBloc bloc = buildBloc(disableSoundForCalls: true);

      await bloc.close();
      await pumpEventQueue();

      expect(dataSource.calls, <String>['rejectCall:session_1:cancelled']);
      expect(CallEventService.instance.activeCall, isNull);
      expect(events.ordered, <String>['rejected:session_1']);
    });

    test("a call with no session releases no other call's record (round 1b "
        'review)', () async {
      CallEventService.instance.activeCall = buildCall(sessionId: 'other');
      ActiveCallTracker.ringingCall = buildCall(sessionId: 'ringing');
      addTearDown(() => ActiveCallTracker.ringingCall = null);
      final OutgoingCallBloc bloc = buildBloc(
        call: NullSessionCall(),
        disableSoundForCalls: true,
      );

      await bloc.close();

      expect(
        (CallEventService.instance.activeCall as Call?)?.sessionId,
        'other',
      );
      expect(ActiveCallTracker.ringingCall?.sessionId, 'ringing');
    });

    test('a cancel that fails reaches onError with the SDK code', () async {
      final CometChatException sdkError = CometChatException(
        'ERR_CALL_ENDED',
        'The call has already ended.',
        'Call already ended',
      );
      dataSource.rejectError = CallOperationsException(
        message: 'Call already ended',
        code: 'ERR_CALL_ENDED',
        originalException: sdkError,
      );
      CallEventService.instance.activeCall = buildCall();
      final List<Exception> errors = <Exception>[];
      final OutgoingCallBloc bloc = buildBloc(
        disableSoundForCalls: true,
        onError: errors.add,
      );

      await bloc.close();
      await pumpEventQueue();

      expect(errors.single, same(sdkError));
      expect(CallEventService.instance.activeCall, isNull);
    });

    blocTest<OutgoingCallBloc, OutgoingCallState>(
      'once answered (the permission prompt still up): released, not '
      'cancelled or ended',
      setUp: () => CallEventService.instance.activeCall = buildCall(),
      build: () => buildBloc(disableSoundForCalls: true),
      seed: () => const OutgoingCallState(
        status: OutgoingCallStatus.accepted,
        isCallRejected: true,
      ),
      verify: (_) {
        expect(dataSource.calls, isEmpty);
        expect(CallEventService.instance.activeCall, isNull);
      },
    );

    testWidgets('after the hand-off to the call screen nothing is cancelled '
        'and the record stays with the call', (WidgetTester tester) async {
      // The call screen joins, so it keeps the record too.
      await installCallJoinDefaults();
      addTearDown(removeCallJoinDefaults);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          home: const Scaffold(body: Text('messages')),
        ),
      );
      CallEventService.instance.activeCall = buildCall();
      final OutgoingCallBloc bloc = buildBloc(disableSoundForCalls: true);
      bloc.add(OutgoingCallAccepted(buildCall()));
      await tester.pump();
      expect(CallScreenOverlay.isShowing, isTrue);

      await tester.runAsync(bloc.close);

      expect(dataSource.calls, isNot(contains(startsWith('rejectCall'))));
      expect(CallEventService.instance.activeCall, isNotNull);
      CallScreenOverlay.dismiss();
      await tester.pumpAndSettle();
    });

    testWidgets("the host's onCancelledCallTap owns the cancel: closing sends "
        'no second one', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          home: const Scaffold(body: Text('messages')),
        ),
      );
      CallEventService.instance.activeCall = buildCall();
      final OutgoingCallBloc bloc = buildBloc(
        disableSoundForCalls: true,
        onCancelledCallTap: (BuildContext _, Call _) {},
      );
      bloc.add(const CancelCall());
      await tester.pump();

      await tester.runAsync(bloc.close);

      expect(dataSource.calls, isEmpty);
      expect(CallEventService.instance.activeCall, isNull);
    });

    testWidgets('a host pushAndRemoveUntil over the real outgoing screen '
        'cancels the call', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          localizationsDelegates: Translations.localizationsDelegates,
          home: const Scaffold(body: Text('messages')),
        ),
      );
      CallEventService.instance.activeCall = buildCall();
      unawaited(
        CallNavigationContext.navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => CometChatOutgoingCall(
              call: buildCall(),
              user: User(uid: 'peer', name: 'Peer'),
              disableSoundForCalls: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CometChatOutgoingCall), findsOneWidget);

      // What a host does on its own navigation, e.g. going to the login
      // screen: the outgoing call screen goes without the bloc closing it.
      unawaited(
        CallNavigationContext.navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('elsewhere')),
          ),
          (Route<dynamic> _) => false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(pumpEventQueue);

      expect(find.byType(CometChatOutgoingCall), findsNothing);
      expect(dataSource.calls, <String>['rejectCall:session_1:cancelled']);
      expect(CallEventService.instance.activeCall, isNull);
    });
  });
}
