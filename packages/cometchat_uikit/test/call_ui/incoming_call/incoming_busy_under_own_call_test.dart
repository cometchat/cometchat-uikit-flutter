/// An incoming call still ringing when the user's own call comes up is
/// answered busy (owner decision 2, round 3 review; correctness 1).
///
/// Before: the user places W while X rings (allowed since round 2), W is
/// answered, and the call screen covered X's banner. X's ringtone and
/// vibration went on for up to 60 s with nothing on screen to stop them,
/// and X's caller rang on. A group meeting joined while X rang did the
/// same. Android's sample closes its incoming snackbar and stops the sound
/// on any "outgoing call accepted".
///
/// Now X is answered busy through the same path as a call that arrives
/// during a call: its banner closes, the ringtone and vibration stop (their
/// audio handed to the call starting), it stops counting as ringing and is
/// remembered, and `busy` goes to the server.
///
///   flutter test test/call_ui/incoming_call/incoming_busy_under_own_call_test.dart
library;

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show SessionSettingsBuilder;
import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_display_incoming_call_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/cometchat_incoming_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/bloc/ongoing_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_extension_constants.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/incoming_ringtone.dart';
import 'package:cometchat_chat_uikit/src/sound_loop_owner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/call_bloc_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final CallEventService service = CallEventService.instance;
  late FakeCallOperationsDataSource dataSource;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    SoundChannelSpy.install();
    PermissionChannelStub.install(granted: true);
    incomingRingtoneLoop.reset();
    service.activeCall = null;
    ActiveCallTracker.ringingCall = null;
    ActiveCallTracker.busyRejectDelay = Duration.zero;
    ActiveCallTracker.forgetFinishedCalls();
  });

  tearDown(() async {
    SoundChannelSpy.remove();
    PermissionChannelStub.remove();
    incomingRingtoneLoop.reset();
    CallScreenOverlay.dismiss();
    service.activeCall = null;
    ActiveCallTracker.ringingCall = null;
    ActiveCallTracker.incomingCallSessionId = null;
    ActiveCallTracker.busyRejectDelay = const Duration(seconds: 2);
    ActiveCallTracker.forgetFinishedCalls();
    CallStateService.instance.setActiveIncomingValue(false);
    CallStateService.instance.setActiveCallValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
    await CallOperationsServiceLocator.instance.reset();
  });

  /// How each stopRingtone left the audio, in order.
  List<String> ringtoneStops() => SoundChannelSpy.calls
      .where((MethodCall c) => c.method == 'stopRingtone')
      .map((MethodCall c) {
        final Map<Object?, Object?> args = c.arguments as Map<Object?, Object?>;
        if (args['keepAudio'] == true) return 'keep';
        if (args['handover'] == true) return 'handover';
        return 'release';
      })
      .toList();

  /// Lets the frame, the channel and the busy reject's (zero) delay run.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(pumpEventQueue);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(pumpEventQueue);
  }

  /// X rings on the kit's banner, as CallEventService shows it.
  Future<void> ringX(WidgetTester tester) async {
    await mountCallNavigator(tester);
    SoundChannelSpy.install();
    service.onIncomingCallReceived(buildCall(sessionId: 'X'));
    await tester.pump();
    await tester.runAsync(pumpEventQueue);
    expect(find.byType(CometChatIncomingCall), findsOneWidget);
    expect(IncomingRingtone.isRinging, isTrue);
  }

  for (final CallWorkFlow workFlow in <CallWorkFlow>[
    CallWorkFlow.defaultCalling,
    CallWorkFlow.directCalling,
  ]) {
    final String what = workFlow == CallWorkFlow.defaultCalling
        ? 'a call the user placed is answered'
        : 'the user joins a group meeting';

    testWidgets('$what while X rings: X is answered busy, its banner closes '
        'and its ringtone stops, handed to the call', (
      WidgetTester tester,
    ) async {
      await ringX(tester);

      CallScreenOverlay.show(
        sessionId: 'W',
        sessionSettingsBuilder: SessionSettingsBuilder(),
        callWorkFlow: workFlow,
      );
      await settle(tester);

      expect(find.byType(CometChatIncomingCall), findsNothing);
      expect(ActiveCallTracker.ringingCall, isNull);
      expect(ActiveCallTracker.finishedLately('X'), isTrue);
      expect(IncomingRingtone.isRinging, isFalse);
      expect(ringtoneStops(), <String>['handover']);
      expect(dataSource.calls, contains('rejectCall:X:busy'));

      CallScreenOverlay.dismiss();
      await tester.pumpAndSettle();
    });
  }

  testWidgets('X\'s own call screen (X answered here) rejects nothing', (
    WidgetTester tester,
  ) async {
    await ringX(tester);

    await tester.tap(find.text('Accept'));
    await settle(tester);

    // The call screen came up for X (and, with no Calls SDK here, closed
    // again).
    expect(dataSource.acceptCallCount, 1);
    expect(dataSource.rejectCallCount, 0);
    CallScreenOverlay.dismiss();
    await tester.pumpAndSettle();
  });

  // Mutation BUSY4: the same-session guard. A host that accepts through
  // CometChatUIKitCalls.acceptCall and opens the call screen itself, before
  // its banner is dismissed, still has the call as the ringing one.
  testWidgets('the call screen for the ringing call itself (a host\'s own '
      'accept, banner not yet dismissed) does not answer it busy', (
    WidgetTester tester,
  ) async {
    await ringX(tester);

    CallScreenOverlay.show(
      sessionId: 'X',
      sessionSettingsBuilder: SessionSettingsBuilder(),
    );
    await settle(tester);

    expect(dataSource.rejectCallCount, 0);
    CallScreenOverlay.dismiss();
    IncomingCallOverlay.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('a call screen with nothing ringing rejects nothing', (
    WidgetTester tester,
  ) async {
    await mountCallNavigator(tester);

    CallScreenOverlay.show(
      sessionId: 'W',
      sessionSettingsBuilder: SessionSettingsBuilder(),
    );
    await settle(tester);

    expect(dataSource.rejectCallCount, 0);
    expect(SoundChannelSpy.methods, isNot(contains('stopRingtone')));
    CallScreenOverlay.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('a host\'s own bloc ringing for X (no banner) stops ringing '
      'too', (WidgetTester tester) async {
    await mountCallNavigator(tester);
    ActiveCallTracker.ringingCall = buildCall(sessionId: 'X');
    final IncomingCallBloc bloc = IncomingCallBloc(
      call: buildCall(sessionId: 'X'),
    );
    await tester.runAsync(pumpEventQueue);
    expect(IncomingRingtone.isRinging, isTrue);

    CallScreenOverlay.show(
      sessionId: 'W',
      sessionSettingsBuilder: SessionSettingsBuilder(),
    );
    await settle(tester);

    expect(IncomingRingtone.isRinging, isFalse);
    expect(dataSource.calls, contains('rejectCall:X:busy'));
    await tester.runAsync(bloc.close);
    CallScreenOverlay.dismiss();
    await tester.pumpAndSettle();
  });

  test('a call screen a host shows itself (not the overlay) joining while X '
      'rings answers X busy too', () async {
    await installCallJoinDefaults();
    addTearDown(removeCallJoinDefaults);
    ActiveCallTracker.ringingCall = buildCall(sessionId: 'X');
    final OngoingCallBloc ongoing = OngoingCallBloc(
      sessionSettingsBuilder: SessionSettingsBuilder(),
      sessionId: 'W',
      callWorkFlow: CallWorkFlow.directCalling,
    );
    addTearDown(ongoing.close);

    await ongoing.stream.firstWhere(
      (OngoingCallState s) => s.status == OngoingCallStatus.active,
    );
    await pumpEventQueue();

    expect(ActiveCallTracker.ringingCall, isNull);
    expect(dataSource.calls, contains('rejectCall:X:busy'));
  });
}
