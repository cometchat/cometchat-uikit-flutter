/// When an accept under way gives up (round 3 review: correctness 4, the
/// owner's D-P3-04 A, and the reviewer's GU2).
///
/// The host's hooks are side effects: an `onAccept` that takes the banner
/// down with `IncomingCallOverlay.dismiss()` used to drop the accept
/// silently (the bloc closed with the banner, and a closed bloc gave up),
/// with nothing sent and no `onError`. The accept now gives up only when
/// the call is over for this device: the bloc is cancelled, or the call was
/// ended some other way (a dismiss naming its session: a push cancel, a
/// "call ended"). A logout is the epoch's (see the ownership tests).
///
///   flutter test test/call_ui/incoming_call/incoming_accept_give_up_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
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
import 'package:cometchat_chat_uikit/src/incoming_ringtone.dart';
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
    SoundChannelSpy.install();
    PermissionChannelStub.install(granted: true);
    incomingRingtoneLoop.reset();
    ActiveCallTracker.forgetFinishedCalls();
    events = CallEventRecorder('incoming_accept_give_up_test');
  });

  tearDown(() async {
    events.dispose();
    SoundChannelSpy.remove();
    PermissionChannelStub.remove();
    incomingRingtoneLoop.reset();
    CallScreenOverlay.dismiss();
    ActiveCallTracker.ringingCall = null;
    ActiveCallTracker.incomingCallSessionId = null;
    ActiveCallTracker.forgetFinishedCalls();
    CallEventService.instance.activeCall = null;
    CallStateService.instance.setActiveIncomingValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
    await CallOperationsServiceLocator.instance.reset();
  });

  /// How each stopRingtone left the audio, in order: `keep` (paused for an
  /// accept), `handover` (to the call screen) or `release` (given back).
  List<String> ringtoneStops() => SoundChannelSpy.calls
      .where((MethodCall c) => c.method == 'stopRingtone')
      .map((MethodCall c) {
        final Map<Object?, Object?> args = c.arguments as Map<Object?, Object?>;
        if (args['keepAudio'] == true) return 'keep';
        if (args['handover'] == true) return 'handover';
        return 'release';
      })
      .toList();

  /// Shows the kit's banner for [call], ringing, with [onAccept].
  Future<void> ring(
    WidgetTester tester, {
    Function(BuildContext, Call)? onAccept,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: CallNavigationContext.navigatorKey,
        localizationsDelegates: Translations.localizationsDelegates,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
    final Call call = buildCall();
    ActiveCallTracker.ringingCall = call;
    IncomingCallOverlay.show(
      context: CallNavigationContext.navigatorKey.currentContext!,
      call: call,
      onAccept: onAccept,
    );
    await tester.pump();
    await tester.runAsync(pumpEventQueue);
  }

  Future<void> tapAccept(WidgetTester tester) async {
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.runAsync(pumpEventQueue);
  }

  testWidgets('an onAccept that takes the banner down (no session) does not '
      'drop the accept: it is sent, and the call screen opens', (
    WidgetTester tester,
  ) async {
    final Completer<void> prompt = Completer<void>();
    PermissionChannelStub.gate = prompt;
    await ring(tester, onAccept: (_, _) => IncomingCallOverlay.dismiss());

    await tapAccept(tester);
    // A frame runs before the permission answer: the banner, and its bloc,
    // are gone.
    await tester.pump();
    expect(find.byType(CometChatIncomingCall), findsNothing);
    prompt.complete();
    await tester.runAsync(pumpEventQueue);

    expect(dataSource.acceptCallCount, 1);
    expect(events.accepted.map((Call c) => c.sessionId), <String?>[
      'session_1',
    ]);
    expect(CallScreenOverlay.isShowing, isTrue);
    // Paused at the tap and handed to the call screen: never given back in
    // between (music resuming during "Connecting...").
    expect(ringtoneStops(), <String>['keep', 'handover']);
    expect(IncomingRingtone.isRinging, isFalse);

    CallScreenOverlay.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('GU2: a push cancel taking the banner down by its session '
      'during the permission prompt: no accept reaches the server, and the '
      'ringtone is given back', (WidgetTester tester) async {
    final Completer<void> prompt = Completer<void>();
    PermissionChannelStub.gate = prompt;
    await ring(tester);

    await tapAccept(tester);
    // master_app's FCM / APNs cancel handler.
    IncomingCallOverlay.dismiss(sessionId: 'session_1');
    await tester.pump();
    prompt.complete();
    await tester.runAsync(pumpEventQueue);

    expect(dataSource.acceptCallCount, 0);
    expect(dataSource.rejectCallCount, 0);
    expect(CallScreenOverlay.isShowing, isFalse);
    expect(ringtoneStops(), <String>['keep', 'release']);
    expect(IncomingRingtone.isRinging, isFalse);
  });

  testWidgets('GU2: the server ending the call during the permission prompt '
      '(its banner dismissed by session): no accept', (
    WidgetTester tester,
  ) async {
    final Completer<void> prompt = Completer<void>();
    PermissionChannelStub.gate = prompt;
    await ring(tester);

    await tapAccept(tester);
    CallEventService.instance.onCallEndedMessageReceived(buildCall());
    await tester.pump();
    prompt.complete();
    await tester.runAsync(pumpEventQueue);

    expect(dataSource.acceptCallCount, 0);
    expect(CallScreenOverlay.isShowing, isFalse);
  });

  testWidgets('an onAccept that dismisses this very call by its session '
      'counts as the call being over here: nothing is asked or sent, and '
      'the ringtone is given back', (WidgetTester tester) async {
    await ring(
      tester,
      onAccept: (_, Call call) =>
          IncomingCallOverlay.dismiss(sessionId: call.sessionId),
    );

    await tapAccept(tester);
    await tester.pump();

    expect(PermissionChannelStub.requested, isEmpty);
    expect(dataSource.acceptCallCount, 0);
    expect(ringtoneStops(), <String>['keep', 'release']);
    expect(IncomingRingtone.isRinging, isFalse);
  });

  // Round 3 review, PROBE-6: a cancel landing while the accept request was
  // on its way emitted cancelled and took the banner down, and then the
  // accept's success opened the call screen anyway.
  group('given up while the accept request is on its way', () {
    test('PROBE-6: the accept goes through: no call screen, and the call is '
        'ended so the caller is not left in it', () async {
      final Completer<void> server = Completer<void>();
      dataSource.acceptGate = server;
      final IncomingCallBloc bloc = IncomingCallBloc(call: buildCall());
      addTearDown(bloc.close);
      await pumpEventQueue();
      bloc.add(const AcceptCall());
      await pumpEventQueue();
      expect(dataSource.acceptCallCount, 1);

      bloc.onIncomingCallCancelled(buildCall());
      await pumpEventQueue();
      expect(bloc.state.status, IncomingCallStatus.cancelled);
      server.complete();
      await pumpEventQueue();

      expect(bloc.state.status, IncomingCallStatus.cancelled);
      expect(CallScreenOverlay.isShowing, isFalse);
      expect(events.accepted, isEmpty);
      expect(dataSource.calls, contains('endCall:session_1'));
      expect(CallEventService.instance.activeCall, isNull);
      expect(IncomingRingtone.isRinging, isFalse);
    });

    test('the accept fails: reported to onError, the state stays '
        'cancelled', () async {
      final Completer<void> server = Completer<void>();
      dataSource.acceptGate = server;
      dataSource.acceptError = const CallOperationsException(
        message: 'The call has already been cancelled.',
        code: 'ERR_CALL_CANCELLED',
      );
      final List<Exception> errors = <Exception>[];
      final IncomingCallBloc bloc = IncomingCallBloc(
        call: buildCall(),
        errorCallback: errors.add,
      );
      addTearDown(bloc.close);
      bloc.add(const AcceptCall());
      await pumpEventQueue();

      bloc.onIncomingCallCancelled(buildCall());
      await pumpEventQueue();
      server.complete();
      await pumpEventQueue();

      expect(bloc.state.status, IncomingCallStatus.cancelled);
      expect((errors.single as CometChatException).code, 'ERR_CALL_CANCELLED');
      expect(dataSource.endCallCount, 0);
      expect(CallScreenOverlay.isShowing, isFalse);
    });
  });
}
