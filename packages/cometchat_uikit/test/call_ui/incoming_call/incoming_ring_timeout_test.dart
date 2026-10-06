/// An incoming call nobody acts on is given up locally after 60 seconds
/// (round 3: P3-C10).
///
/// Before: a cancel the Dart SDK lost (its socket drops while the app is
/// inactive), a caller app that was killed, or a caller with no no-answer
/// timer left the phone ringing until the user acted, and every later call
/// was answered busy. The safety stop sends nothing to the server, and goes
/// through the bloc's cancel, so a host that shows the bloc on a screen of
/// its own sees `cancelled` and can close it.
///
/// Fake time throughout (testWidgets).
///
///   flutter test test/call_ui/incoming_call/incoming_ring_timeout_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/call_ui/src/call_operations/data/datasources/call_operations_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_display_incoming_call_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_incoming_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/l10n/translations.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/sound_loop_owner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/call_bloc_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCallOperationsDataSource dataSource;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    SoundChannelSpy.install();
    PermissionChannelStub.install(granted: true);
    incomingRingtoneLoop.reset();
    ActiveCallTracker.ringingCall = null;
  });

  tearDown(() async {
    SoundChannelSpy.remove();
    PermissionChannelStub.remove();
    incomingRingtoneLoop.reset();
    ActiveCallTracker.ringingCall = null;
    ActiveCallTracker.incomingCallSessionId = null;
    ActiveCallTracker.forgetFinishedCalls();
    CallStateService.instance.setActiveIncomingValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
    await CallOperationsServiceLocator.instance.reset();
  });

  Future<void> showBanner(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: CallNavigationContext.navigatorKey,
        localizationsDelegates: Translations.localizationsDelegates,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
    final call = buildCall();
    ActiveCallTracker.ringingCall = call;
    IncomingCallOverlay.show(
      context: CallNavigationContext.navigatorKey.currentContext!,
      call: call,
    );
    await tester.pump();
  }

  testWidgets('P3-N14 / P3-E13: at 59 s the banner still rings; at 61 s it is '
      'gone, the ringtone stopped, the record released, nothing sent', (
    WidgetTester tester,
  ) async {
    expect(ActiveCallTracker.incomingRingTimeout, const Duration(seconds: 60));
    await showBanner(tester);
    SoundChannelSpy.methods.clear();

    await tester.pump(const Duration(seconds: 59));
    expect(find.byType(CometChatIncomingCall), findsOneWidget);
    expect(ActiveCallTracker.ringingCall?.sessionId, 'session_1');
    expect(SoundChannelSpy.methods, isEmpty);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.byType(CometChatIncomingCall), findsNothing);
    expect(ActiveCallTracker.ringingCall, isNull);
    expect(ActiveCallTracker.isBusy, isFalse);
    expect(SoundChannelSpy.methods, contains('stopRingtone'));
    expect(dataSource.rejectCallCount, 0);
    expect(dataSource.calls, isEmpty);
  });

  testWidgets('P3-E11: an accept started at 10 s is not cut off at 61 s, '
      'however long the server takes', (WidgetTester tester) async {
    final Completer<void> server = Completer<void>();
    dataSource.acceptGate = server;
    dataSource.acceptError = const CallOperationsException(message: 'down');
    await showBanner(tester);

    await tester.pump(const Duration(seconds: 10));
    await tester.tap(find.text('Accept'));
    await tester.runAsync(pumpEventQueue);
    expect(dataSource.acceptCallCount, 1);

    await tester.pump(const Duration(seconds: 51));
    await tester.pump();
    expect(find.byType(CometChatIncomingCall), findsOneWidget);
    expect(find.text('Connecting...'), findsOneWidget);

    server.complete();
    await tester.runAsync(pumpEventQueue);
    await tester.pump();
    expect(find.byType(CometChatIncomingCall), findsNothing);
  });

  // The timer stopping is seen through the test binding: a timer still
  // pending when a testWidgets body ends fails the test. The blocs below are
  // closed only after that check (addTearDown).
  testWidgets('a decline stops the timer at the tap', (
    WidgetTester tester,
  ) async {
    final IncomingCallBloc bloc = IncomingCallBloc(
      call: buildCall(),
      disableSoundForCalls: true,
    );
    addTearDown(bloc.close);

    bloc.add(const RejectCall());
    await tester.runAsync(pumpEventQueue);
    await tester.pump(const Duration(seconds: 1));

    expect(bloc.state.status, IncomingCallStatus.rejected);
  });

  testWidgets('an accept stops the timer at the tap', (
    WidgetTester tester,
  ) async {
    dataSource.acceptError = const CallOperationsException(message: 'down');
    final IncomingCallBloc bloc = IncomingCallBloc(
      call: buildCall(),
      disableSoundForCalls: true,
    );
    addTearDown(bloc.close);

    bloc.add(const AcceptCall());
    await tester.runAsync(pumpEventQueue);
    await tester.pump(const Duration(seconds: 1));

    expect(bloc.state.status, IncomingCallStatus.error);
  });

  testWidgets('a bloc a host shows on its own screen moves to cancelled, so '
      'the host can close it (review correction)', (WidgetTester tester) async {
    final IncomingCallBloc bloc = IncomingCallBloc(
      call: buildCall(),
      disableSoundForCalls: true,
    );

    await tester.pump(const Duration(seconds: 59));
    expect(bloc.state.status, IncomingCallStatus.idle);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(bloc.state.status, IncomingCallStatus.cancelled);
    expect(dataSource.calls, isEmpty);
    await tester.runAsync(bloc.close);
  });

  testWidgets('the timer is cancelled when the banner goes for any other '
      'reason: no timer outlives the bloc', (WidgetTester tester) async {
    await showBanner(tester);

    IncomingCallOverlay.dismiss();
    await tester.pump();

    // A pending timer here fails the test.
    expect(find.byType(CometChatIncomingCall), findsNothing);
  });

  testWidgets('a call cancelled by the caller at 20 s is not given up again '
      'at 60 s: the cancel stops the timer', (WidgetTester tester) async {
    final IncomingCallBloc bloc = IncomingCallBloc(
      call: buildCall(),
      disableSoundForCalls: true,
    );
    addTearDown(bloc.close);
    await tester.pump(const Duration(seconds: 20));
    bloc.add(const CallCancelled());
    await tester.pump();

    expect(bloc.state.status, IncomingCallStatus.cancelled);
  });

  // Owner decision 1 (round 3 review): on iOS a suspended app runs no
  // timers. A call that started ringing before the app went away rang again
  // on unlock, past its 60 s, until the timer finally fired.
  group('the 60 s are counted by the wall clock (owner decision 1)', () {
    final DateTime start = DateTime(2026, 10, 1, 12);
    late DateTime clock;

    setUp(() {
      clock = start;
      ActiveCallTracker.now = () => clock;
    });

    tearDown(() => ActiveCallTracker.now = DateTime.now);

    void cycleToForeground(WidgetTester tester) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }

    test('the native ringtone is told when to stop at the latest: 60 s from '
        'the ring\'s start', () async {
      final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
      addTearDown(bloc.close);
      await pumpEventQueue();

      expect(
        SoundChannelSpy.lastArgumentsOf('playRingtone')?['deadlineMs'],
        start.add(const Duration(seconds: 60)).millisecondsSinceEpoch,
      );
    });

    testWidgets('back in the foreground past the 60 s (the app was '
        'suspended, its timer did not run): given up at once, nothing sent', (
      WidgetTester tester,
    ) async {
      await showBanner(tester);
      SoundChannelSpy.methods.clear();

      clock = start.add(const Duration(seconds: 75));
      cycleToForeground(tester);
      await tester.runAsync(pumpEventQueue);
      await tester.pump();

      expect(find.byType(CometChatIncomingCall), findsNothing);
      expect(ActiveCallTracker.ringingCall, isNull);
      expect(SoundChannelSpy.methods, contains('stopRingtone'));
      expect(dataSource.calls, isEmpty);
    });

    testWidgets('back in the foreground within the 60 s: it rings on', (
      WidgetTester tester,
    ) async {
      await showBanner(tester);

      clock = start.add(const Duration(seconds: 30));
      cycleToForeground(tester);
      await tester.runAsync(pumpEventQueue);
      await tester.pump();

      expect(find.byType(CometChatIncomingCall), findsOneWidget);
      IncomingCallOverlay.dismiss();
      await tester.pump();
    });

    testWidgets('a call answered before the app went away is not given up '
        'when it comes back', (WidgetTester tester) async {
      dataSource.acceptGate = Completer<void>();
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
      );
      bloc.add(const AcceptCall());
      await tester.runAsync(pumpEventQueue);

      clock = start.add(const Duration(seconds: 75));
      cycleToForeground(tester);
      await tester.runAsync(pumpEventQueue);

      expect(bloc.state.status, IncomingCallStatus.accepting);
      dataSource.acceptGate!.complete();
      await tester.runAsync(pumpEventQueue);
      await tester.runAsync(bloc.close);
      await tester.pumpAndSettle();
    });
  });
}
