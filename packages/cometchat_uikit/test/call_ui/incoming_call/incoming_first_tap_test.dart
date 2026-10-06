/// The incoming call's first tap wins, the ringtone stops at the tap, the
/// host's hooks never abort the flow, and the banner's dismissals are this
/// call's only (round 3: P3-C03, P3-C04, P3-C06).
///
/// Before: Decline stayed live while an accept was on its way and sent a
/// reject too (a failed one then cleared the record of the call just
/// connected); the phone rang on through the permission prompt and the
/// server round trip; an `onAccept` that threw a StateError stopped the
/// accept part-way; and the bloc's dismissals took down whatever banner was
/// up.
///
///   flutter test test/call_ui/incoming_call/incoming_first_tap_test.dart
@Timeout(Duration(seconds: 60))
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_display_incoming_call_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_incoming_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/sound_loop_owner.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/call_bloc_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCallOperationsDataSource dataSource;
  late CallEventRecorder events;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    PermissionChannelStub.install(granted: true);
    SoundChannelSpy.install();
    incomingRingtoneLoop.reset();
    events = CallEventRecorder('incoming_first_tap_test');
    // Every test's call is session_1: one ended in an earlier test must
    // not count as ended in this one.
    ActiveCallTracker.forgetFinishedCalls();
  });

  tearDown(() async {
    events.dispose();
    SoundChannelSpy.remove();
    PermissionChannelStub.remove();
    incomingRingtoneLoop.reset();
    ActiveCallTracker.ringingCall = null;
    await CallOperationsServiceLocator.instance.reset();
    CallStateService.instance.setActiveIncomingValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  /// Closes [bloc] at the end of the test, after opening every gate a test
  /// may have left shut (an expectation that failed before the test opened
  /// it). Not awaited, and nothing is lost by that: the bloc's close() does
  /// what matters (listeners, timer, the ringtone) before its first await,
  /// and bloc 9.2.1's close() does not wait for a handler in flight (it
  /// cancels the handler's emitter). A handler that never finishes is caught
  /// by the file's timeout instead.
  void closeAtEnd(IncomingCallBloc bloc) {
    addTearDown(() {
      for (final Completer<void>? gate in <Completer<void>?>[
        dataSource.acceptGate,
        dataSource.rejectGate,
        PermissionChannelStub.gate,
      ]) {
        if (gate != null && !gate.isCompleted) gate.complete();
      }
      unawaited(bloc.close());
    });
  }

  /// Stops an accept at the server, so no call screen is shown.
  void failAccept() {
    dataSource.acceptError = const CallOperationsException(
      message: 'Network down',
      code: 'NETWORK',
    );
  }

  // =========================================================================
  // P3-C03: the first tap wins
  // =========================================================================

  group('P3-C03: the first tap wins', () {
    test(
      'P3-E02: Decline while an accept is on its way sends no reject',
      () async {
        final Completer<void> acceptGate = Completer<void>();
        dataSource.acceptGate = acceptGate;
        failAccept();
        final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
        closeAtEnd(bloc);

        bloc.add(const AcceptCall());
        await pumpEventQueue();
        expect(dataSource.acceptCallCount, 1);
        bloc.add(const RejectCall());
        await pumpEventQueue();
        acceptGate.complete();
        await pumpEventQueue();

        expect(dataSource.rejectCallCount, 0);
        expect(events.rejected, isEmpty);
      },
    );

    test(
      'P3-E03: Accept while a decline is on its way sends no accept',
      () async {
        final Completer<void> rejectGate = Completer<void>();
        dataSource.rejectGate = rejectGate;
        final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
        closeAtEnd(bloc);

        bloc.add(const RejectCall());
        await pumpEventQueue();
        bloc.add(const AcceptCall());
        await pumpEventQueue();
        rejectGate.complete();
        await pumpEventQueue();

        expect(dataSource.acceptCallCount, 0);
        expect(PermissionChannelStub.requested, isEmpty);
        expect(dataSource.rejectCallCount, 1);
      },
    );

    for (final IncomingCallStatus acted in <IncomingCallStatus>[
      IncomingCallStatus.rejecting,
      IncomingCallStatus.rejected,
    ]) {
      blocTest<IncomingCallBloc, IncomingCallState>(
        'P3-E03: AcceptCall is ignored once the call is $acted',
        build: () => IncomingCallBloc(call: buildCall()),
        seed: () => IncomingCallState(status: acted),
        act: (IncomingCallBloc bloc) => bloc.add(const AcceptCall()),
        expect: () => const <IncomingCallState>[],
        verify: (_) => expect(dataSource.calls, isEmpty),
      );
    }

    for (final IncomingCallStatus acted in <IncomingCallStatus>[
      IncomingCallStatus.accepting,
      IncomingCallStatus.accepted,
    ]) {
      blocTest<IncomingCallBloc, IncomingCallState>(
        'P3-E02: RejectCall is ignored once the call is $acted',
        build: () => IncomingCallBloc(call: buildCall()),
        seed: () => IncomingCallState(status: acted),
        act: (IncomingCallBloc bloc) => bloc.add(const RejectCall()),
        expect: () => const <IncomingCallState>[],
        verify: (_) => expect(dataSource.calls, isEmpty),
      );
    }

    test('P3-E05: a cancel while the permission prompt is up: the accept '
        'stops there, nothing reaches the server', () async {
      final Completer<void> prompt = Completer<void>();
      PermissionChannelStub.gate = prompt;
      final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
      closeAtEnd(bloc);

      bloc.add(const AcceptCall());
      await pumpEventQueue();
      expect(PermissionChannelStub.requested, isNotEmpty);
      bloc.onIncomingCallCancelled(buildCall());
      await pumpEventQueue();
      prompt.complete();
      await pumpEventQueue();

      expect(dataSource.acceptCallCount, 0);
      expect(dataSource.rejectCallCount, 0);
      expect(bloc.state.status, IncomingCallStatus.cancelled);
    });

    testWidgets('after tapping Accept, Decline is off too (and Accept stays '
        'off)', (WidgetTester tester) async {
      final Completer<void> prompt = Completer<void>();
      PermissionChannelStub.gate = prompt;
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
      );
      closeAtEnd(bloc);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          home: Scaffold(
            body: CometChatIncomingCall(
              call: buildCall(),
              user: User(uid: 'peer', name: 'Peer'),
              incomingCallBloc: bloc,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Accept'));
      await tester.pump();

      final List<TextButton> buttons = tester
          .widgetList<TextButton>(find.byType(TextButton))
          .toList();
      expect(buttons, hasLength(2));
      expect(buttons.every((TextButton b) => b.onPressed == null), isTrue);

      prompt.complete();
      await tester.runAsync(pumpEventQueue);
    });

    testWidgets('after tapping Decline, both buttons are off', (
      WidgetTester tester,
    ) async {
      final Completer<void> rejectGate = Completer<void>();
      dataSource.rejectGate = rejectGate;
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
      );
      closeAtEnd(bloc);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          home: Scaffold(
            body: CometChatIncomingCall(
              call: buildCall(),
              user: User(uid: 'peer', name: 'Peer'),
              incomingCallBloc: bloc,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Decline'));
      await tester.pump();

      final List<TextButton> buttons = tester
          .widgetList<TextButton>(find.byType(TextButton))
          .toList();
      expect(buttons.every((TextButton b) => b.onPressed == null), isTrue);

      rejectGate.complete();
      await tester.runAsync(pumpEventQueue);
    });

    testWidgets('"Connecting..." replaces the subtitle while the accept goes '
        'through', (WidgetTester tester) async {
      final Completer<void> acceptGate = Completer<void>();
      dataSource.acceptGate = acceptGate;
      failAccept();
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
      );
      closeAtEnd(bloc);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          home: Scaffold(
            body: CometChatIncomingCall(
              call: buildCall(),
              user: User(uid: 'peer', name: 'Peer'),
              incomingCallBloc: bloc,
            ),
          ),
        ),
      );
      expect(find.text('Incoming audio call'), findsOneWidget);

      await tester.tap(find.text('Accept'));
      await tester.runAsync(pumpEventQueue);
      await tester.pump();

      expect(find.text('Connecting...'), findsOneWidget);
      expect(find.text('Incoming audio call'), findsNothing);

      acceptGate.complete();
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
      expect(find.text('Connecting...'), findsNothing);
    });
  });

  // =========================================================================
  // P3-C03 (5): the host's hooks are side effects
  // =========================================================================

  group('P3-N17: the host hooks run and the default action goes ahead', () {
    Future<void> mountNavigator(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        navigatorKey: CallNavigationContext.navigatorKey,
        home: const SizedBox.shrink(),
      ),
    );

    testWidgets('an onAccept that throws a StateError is reported as '
        'HOST_CALLBACK_ERROR, and the accept still goes to the server', (
      WidgetTester tester,
    ) async {
      failAccept();
      await mountNavigator(tester);
      final List<Exception> errors = <Exception>[];
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
        onAccept: (BuildContext _, Call _) => throw StateError('host bug'),
        errorCallback: errors.add,
      );
      closeAtEnd(bloc);

      bloc.add(const AcceptCall());
      await tester.runAsync(pumpEventQueue);

      final CometChatException hook = errors.first as CometChatException;
      expect(hook.code, 'HOST_CALLBACK_ERROR');
      expect(hook.details, contains('host bug'));
      expect(dataSource.acceptCallCount, 1);
    });

    testWidgets('an onDecline that throws a StateError is reported, and the '
        'decline still goes to the server', (WidgetTester tester) async {
      await mountNavigator(tester);
      final List<Exception> errors = <Exception>[];
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
        onDecline: (BuildContext _, Call _) => throw StateError('host bug'),
        errorCallback: errors.add,
      );
      closeAtEnd(bloc);

      bloc.add(const RejectCall());
      await tester.runAsync(pumpEventQueue);

      expect((errors.single as CometChatException).code, 'HOST_CALLBACK_ERROR');
      expect(dataSource.rejectCallCount, 1);
      expect(bloc.state.status, IncomingCallStatus.rejected);
    });

    testWidgets('an async onAccept that fails is reported too', (
      WidgetTester tester,
    ) async {
      failAccept();
      await mountNavigator(tester);
      final List<Exception> errors = <Exception>[];
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
        onAccept: (BuildContext _, Call _) async =>
            throw StateError('async host bug'),
        errorCallback: errors.add,
      );
      closeAtEnd(bloc);

      bloc.add(const AcceptCall());
      await tester.runAsync(pumpEventQueue);

      expect(
        errors.whereType<CometChatException>().map(
          (CometChatException e) => e.code,
        ),
        contains('HOST_CALLBACK_ERROR'),
      );
      expect(dataSource.acceptCallCount, 1);
    });
  });

  // =========================================================================
  // P3-C04: the ringtone stops at the tap
  // =========================================================================

  group('P3-C04: ringing stops at the tap', () {
    /// What had happened when the ringtone was stopped: the permission
    /// requests and the server calls made by then.
    late List<String> atStop;

    setUp(() {
      atStop = <String>[];
      SoundChannelSpy.onCall = (MethodCall call) async {
        if (call.method == 'stopRingtone') {
          atStop.add(
            'permissions:${PermissionChannelStub.requested.length} '
            'server:${dataSource.calls.length} '
            'args:${call.arguments}',
          );
        }
      };
    });

    test('P3-E02: Accept stops the sound before the permission prompt and '
        'the accept, keeping the audio for the call', () async {
      failAccept();
      final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
      closeAtEnd(bloc);
      await pumpEventQueue();

      bloc.add(const AcceptCall());
      await pumpEventQueue();

      expect(
        atStop.first,
        'permissions:0 server:0 args:{handover: false, keepAudio: true}',
      );
    });

    test('P3-N05: Decline stops it before the reject, and gives the audio '
        'back', () async {
      final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
      closeAtEnd(bloc);
      await pumpEventQueue();

      bloc.add(const RejectCall());
      await pumpEventQueue();

      expect(
        atStop.first,
        'permissions:0 server:0 args:{handover: false, keepAudio: false}',
      );
      expect(dataSource.rejectCallCount, 1);
    });

    test('P3-N06: a cancel stops it even with no banner to dismiss (a host '
        'showing the bloc on its own screen)', () async {
      final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
      closeAtEnd(bloc);
      await pumpEventQueue();

      bloc.add(const CallCancelled());
      await pumpEventQueue();

      expect(atStop, hasLength(1));
      expect(atStop.single, endsWith('{handover: false, keepAudio: false}'));
    });

    test('P3-E22: a refused permission gives the audio back, even with no '
        'banner whose close would', () async {
      PermissionChannelStub.install(granted: false);
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        errorCallback: (_) {},
      );
      closeAtEnd(bloc);
      await pumpEventQueue();

      bloc.add(const AcceptCall());
      await pumpEventQueue();

      expect(atStop, hasLength(2));
      expect(atStop.first, endsWith('{handover: false, keepAudio: true}'));
      expect(atStop.last, endsWith('{handover: false, keepAudio: false}'));
    });

    test('an accept that fails gives the audio back', () async {
      failAccept();
      final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
      closeAtEnd(bloc);
      await pumpEventQueue();

      bloc.add(const AcceptCall());
      await pumpEventQueue();

      expect(atStop, hasLength(2));
      expect(atStop.last, endsWith('{handover: false, keepAudio: false}'));
    });

    testWidgets('P3-N03: an accepted call hands the audio to the call screen, '
        'and the banner closing stops nothing more', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          home: const SizedBox.shrink(),
        ),
      );
      final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());

      bloc.add(const AcceptCall());
      await tester.runAsync(pumpEventQueue);
      expect(CallScreenOverlay.isShowing, isTrue);
      await tester.runAsync(bloc.close);

      // Paused at the tap, before the prompt; handed over once the accept
      // has landed, before the call screen.
      expect(atStop, <String>[
        'permissions:0 server:0 args:{handover: false, keepAudio: true}',
        'permissions:1 server:1 args:{handover: true, keepAudio: false}',
      ]);

      // The call screen gives up (no Calls SDK here) and clears itself.
      await tester.pumpAndSettle();
    });
  });

  // =========================================================================
  // P3-C06: the bloc's dismissals are this call's only
  // =========================================================================

  group('P3-C06: the bloc dismisses only its own banner', () {
    Future<void> showOtherBanner(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          localizationsDelegates: Translations.localizationsDelegates,
          home: const SizedBox.shrink(),
        ),
      );
      final Call other = buildCall(sessionId: 'other');
      ActiveCallTracker.ringingCall = other;
      IncomingCallOverlay.show(
        context: CallNavigationContext.navigatorKey.currentContext!,
        call: other,
        disableSoundForCalls: true,
      );
      await tester.pump();
    }

    /// Takes the other banner down in the test body: its bloc's ring timer
    /// must not outlive the test.
    Future<void> dismissOtherBanner(WidgetTester tester) async {
      IncomingCallOverlay.dismiss();
      await tester.pump();
    }

    testWidgets('P3-E28: a decline of another call leaves this banner up', (
      WidgetTester tester,
    ) async {
      await showOtherBanner(tester);
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
      );
      closeAtEnd(bloc);

      bloc.add(const RejectCall());
      await tester.runAsync(pumpEventQueue);
      await tester.pump();

      expect(ActiveCallTracker.incomingCallSessionId, 'other');
      expect(ActiveCallTracker.ringingCall?.sessionId, 'other');
      expect(find.byType(CometChatIncomingCall), findsOneWidget);
      await dismissOtherBanner(tester);
    });

    testWidgets('a failed decline of another call leaves this banner up', (
      WidgetTester tester,
    ) async {
      dataSource.rejectError = const CallOperationsException(message: 'down');
      await showOtherBanner(tester);
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
        errorCallback: (_) {},
      );
      closeAtEnd(bloc);

      bloc.add(const RejectCall());
      await tester.runAsync(pumpEventQueue);
      await tester.pump();

      expect(ActiveCallTracker.incomingCallSessionId, 'other');
      expect(find.byType(CometChatIncomingCall), findsOneWidget);
      await dismissOtherBanner(tester);
    });

    testWidgets('a failed accept of another call leaves this banner up', (
      WidgetTester tester,
    ) async {
      failAccept();
      await showOtherBanner(tester);
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
      );
      closeAtEnd(bloc);

      bloc.add(const AcceptCall());
      await tester.runAsync(pumpEventQueue);
      await tester.pump();

      expect(ActiveCallTracker.incomingCallSessionId, 'other');
      expect(find.byType(CometChatIncomingCall), findsOneWidget);
      await dismissOtherBanner(tester);
    });

    testWidgets('a refused permission for another call leaves this banner up', (
      WidgetTester tester,
    ) async {
      PermissionChannelStub.install(granted: false);
      await showOtherBanner(tester);
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
        errorCallback: (_) {},
      );
      closeAtEnd(bloc);

      bloc.add(const AcceptCall());
      await tester.runAsync(pumpEventQueue);
      await tester.pump();

      expect(ActiveCallTracker.incomingCallSessionId, 'other');
      expect(find.byType(CometChatIncomingCall), findsOneWidget);
      await dismissOtherBanner(tester);
    });
  });
}
