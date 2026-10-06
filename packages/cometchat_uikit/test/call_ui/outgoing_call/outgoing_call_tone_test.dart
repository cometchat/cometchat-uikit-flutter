/// The outgoing call's ringback on its own call-tone player (round 2,
/// P2-C12): what the outgoing call screen asks it to play, and that every
/// way ringing ends stops it. The audio it set up is given back, except when
/// the callee answers: the playback stops at the accept, the audio stays
/// set up, and it is handed to the call right before the call screen opens
/// (round 2 review).
///
/// The stop cases mount the real CometChatOutgoingCall as a route, so its
/// bloc closes the way it does in an app: when the screen goes.
///
///   flutter test test/call_ui/outgoing_call/outgoing_call_tone_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/cometchat_outgoing_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/constants/ui_kit_constants.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_events.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/call_bloc_harness.dart';

/// The call-tone methods the screen used, in order; message sounds and
/// anything else on the channel are left out.
List<String> get _toneCalls => SoundChannelSpy.methods
    .where((String m) => m == 'playCallTone' || m == 'stopCallTone')
    .toList();

/// How every stopCallTone left the audio, in order: `keep` (the callee
/// answered: only the playback stops), `handover` (to the call screen) or
/// `release` (given back as it was).
List<String> get _stops => SoundChannelSpy.calls
    .where((MethodCall c) => c.method == 'stopCallTone')
    .map((MethodCall c) {
      final Map<Object?, Object?> args = c.arguments as Map<Object?, Object?>;
      if (args['keepAudio'] == true) return 'keep';
      if (args['handover'] == true) return 'handover';
      return 'release';
    })
    .toList();

/// The tone played once and was then stopped — once here, where only
/// close() stops it; more than once where ringing ending stops it first and
/// close() stops it again for safety.
void _expectPlayedThenStopped() {
  expect(_toneCalls.first, 'playCallTone');
  expect(_toneCalls.skip(1), isNotEmpty);
  expect(_toneCalls.skip(1), everyElement('stopCallTone'));
}

/// The bloc behind the outgoing call screen on show. It registers itself
/// for the UI Kit's call events, which is where a test can reach it.
OutgoingCallBloc _screenBloc() => CometChatCallEvents.callEventsListener.values
    .whereType<OutgoingCallBloc>()
    .single;

/// Closes [bloc] after the test, giving up after a second: a test that fails
/// before its own close must not leave the bloc listening, where the next
/// test's [_screenBloc] would find two.
Future<void> _closeSoon(OutgoingCallBloc bloc) =>
    bloc.close().timeout(const Duration(seconds: 1), onTimeout: () {});

/// Mounts the app with the real outgoing call screen on top, ringing.
Future<void> ring(WidgetTester tester) async {
  await mountCallNavigator(tester);
  CallEventService.instance.activeCall = buildCall();
  unawaited(
    CallNavigationContext.navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => CometChatOutgoingCall(
          call: buildCall(),
          user: User(uid: 'peer', name: 'Peer'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(CometChatOutgoingCall), findsOneWidget);
  expect(_toneCalls, <String>['playCallTone']);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCallOperationsDataSource dataSource;

  setUp(() async {
    await CallOperationsServiceLocator.instance.reset();
    dataSource = FakeCallOperationsDataSource();
    CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
    PermissionChannelStub.install(granted: true);
    SoundChannelSpy.install();
  });

  tearDown(() async {
    SoundChannelSpy.remove();
    PermissionChannelStub.remove();
    await CallOperationsServiceLocator.instance.reset();
    CallStateService.instance.setActiveOutgoingValue(false);
    CallEventService.instance.activeCall = null;
    // No test leaves a call screen up for the next one, whatever order
    // they run in.
    CallScreenOverlay.dismiss();
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  group('what plays', () {
    test(
      'a voice call rings as a voice call: the kit\'s tone, not video',
      () async {
        final OutgoingCallBloc bloc = OutgoingCallBloc(call: buildCall());
        addTearDown(bloc.close);
        await pumpEventQueue();

        expect(_toneCalls, <String>['playCallTone']);
        expect(
          SoundChannelSpy.lastArgumentsOf('playCallTone'),
          <String, Object?>{
            'assetPath': 'assets/sound/outgoing_call.wav',
            'package': 'cometchat_chat_uikit',
            'isVideo': false,
            'fallbackAssetPath': 'assets/sound/outgoing_call.wav',
            'fallbackPackage': 'cometchat_chat_uikit',
          },
        );
      },
    );

    test('a video call rings as a video call', () async {
      final OutgoingCallBloc bloc = OutgoingCallBloc(
        call: buildCall(type: CallTypeConstants.videoCall),
      );
      addTearDown(bloc.close);
      await pumpEventQueue();

      expect(
        SoundChannelSpy.lastArgumentsOf('playCallTone')?['isVideo'],
        isTrue,
      );
    });

    test('customSoundForCalls and customSoundForCallsPackage reach the '
        'player', () async {
      final OutgoingCallBloc bloc = OutgoingCallBloc(
        call: buildCall(type: CallTypeConstants.videoCall),
        customSoundForCalls: 'sounds/ringback.mp3',
        customSoundForCallsPackage: 'host_sounds',
      );
      addTearDown(bloc.close);
      await pumpEventQueue();

      expect(SoundChannelSpy.lastArgumentsOf('playCallTone'), <String, Object?>{
        'assetPath': 'sounds/ringback.mp3',
        'package': 'host_sounds',
        'isVideo': true,
        'fallbackAssetPath': 'assets/sound/outgoing_call.wav',
        'fallbackPackage': 'cometchat_chat_uikit',
      });
    });

    test('customSoundForCalls alone is the app\'s own asset', () async {
      final OutgoingCallBloc bloc = OutgoingCallBloc(
        call: buildCall(),
        customSoundForCalls: 'sounds/ringback.mp3',
      );
      addTearDown(bloc.close);
      await pumpEventQueue();

      expect(
        SoundChannelSpy.lastArgumentsOf('playCallTone')?['package'],
        isNull,
      );
    });

    test('a screen closing after the next call started leaves the next '
        'ringback playing (round 2, P3-C15)', () async {
      final OutgoingCallBloc first = OutgoingCallBloc(call: buildCall());
      addTearDown(() => _closeSoon(first));
      await pumpEventQueue();
      final OutgoingCallBloc second = OutgoingCallBloc(
        call: buildCall(sessionId: 'session_2'),
      );
      addTearDown(() => _closeSoon(second));
      await pumpEventQueue();

      await first.close();
      await pumpEventQueue();
      expect(_toneCalls, <String>['playCallTone', 'playCallTone']);

      await second.close();
      await pumpEventQueue();
      expect(_toneCalls, <String>[
        'playCallTone',
        'playCallTone',
        'stopCallTone',
      ]);
    });

    test(
      'disableSoundForCalls: nothing plays, and nothing is stopped',
      () async {
        final OutgoingCallBloc bloc = OutgoingCallBloc(
          call: buildCall(),
          disableSoundForCalls: true,
        );
        addTearDown(() => _closeSoon(bloc));
        await pumpEventQueue();
        await bloc.close();
        await pumpEventQueue();

        expect(_toneCalls, isEmpty);
      },
    );
  });

  group('ringing ends, the tone stops', () {
    test('closing the bloc stops it, handing nothing over', () async {
      final OutgoingCallBloc bloc = OutgoingCallBloc(call: buildCall());
      addTearDown(() => _closeSoon(bloc));
      await pumpEventQueue();
      await bloc.close();
      await pumpEventQueue();

      expect(_toneCalls, <String>['playCallTone', 'stopCallTone']);
      expect(SoundChannelSpy.lastArgumentsOf('stopCallTone'), <String, Object?>{
        'handover': false,
        'keepAudio': false,
      });
    });

    testWidgets('the callee declines', (WidgetTester tester) async {
      await ring(tester);

      _screenBloc().onOutgoingCallRejected(buildCall());
      await tester.pumpAndSettle();

      expect(find.byType(CometChatOutgoingCall), findsNothing);
      _expectPlayedThenStopped();
      expect(_stops, everyElement('release'));
    });

    testWidgets('the caller cancels', (WidgetTester tester) async {
      await ring(tester);

      _screenBloc().add(const CancelCall());
      await tester.runAsync(pumpEventQueue);
      await tester.pumpAndSettle();

      expect(dataSource.calls, <String>['rejectCall:session_1:cancelled']);
      expect(find.byType(CometChatOutgoingCall), findsNothing);
      _expectPlayedThenStopped();
      expect(_stops, everyElement('release'));
    });
  });

  // Round 2 review: the accept hand-over. Giving the audio back at the
  // accept let music resume until the call started, and on iOS the release,
  // queued natively, could land on the Calls engine's session and cut the
  // call's audio.
  group('the callee answers: the audio goes to the call (round 2 review)', () {
    testWidgets('the playback stops at the accept; the audio is handed to '
        'the call right before its screen opens, and nothing after', (
      WidgetTester tester,
    ) async {
      // A Calls SDK that joins, so the call screen stays up.
      await installCallJoinDefaults();
      addTearDown(removeCallJoinDefaults);
      await ring(tester);
      final List<String> overlayAtStop = <String>[];
      SoundChannelSpy.onCall = (MethodCall call) async {
        if (call.method == 'stopCallTone') {
          overlayAtStop.add(CallScreenOverlay.isShowing ? 'up' : 'not up');
        }
      };

      _screenBloc().onOutgoingCallAccepted(buildCall());
      await tester.runAsync(pumpEventQueue);
      await tester.pumpAndSettle();

      expect(find.byType(CometChatOutgoingCall), findsNothing);
      expect(CallScreenOverlay.isShowing, isTrue);
      expect(_stops, <String>['keep', 'handover']);
      expect(overlayAtStop, <String>['not up', 'not up']);

      CallScreenOverlay.dismiss();
      await tester.pumpAndSettle();
      expect(_stops, <String>['keep', 'handover']);
    });

    testWidgets('permissions refused at the accept: the audio is given back, '
        'not handed over', (WidgetTester tester) async {
      await ring(tester);
      PermissionChannelStub.install(granted: false);

      _screenBloc().onOutgoingCallAccepted(buildCall());
      await tester.runAsync(pumpEventQueue);
      await tester.pumpAndSettle();

      expect(find.byType(CometChatOutgoingCall), findsNothing);
      expect(CallScreenOverlay.isShowing, isFalse);
      expect(_stops, <String>['keep', 'release']);
    });

    testWidgets('no navigator to show the call screen on: the audio is given '
        'back, not handed over', (WidgetTester tester) async {
      await ring(tester);
      // The app's navigator key no longer reaches a navigator.
      CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();

      _screenBloc().onOutgoingCallAccepted(buildCall());
      await tester.runAsync(pumpEventQueue);
      await tester.pumpAndSettle();

      expect(CallScreenOverlay.isShowing, isFalse);
      expect(_stops, <String>['keep', 'release']);
    });

    testWidgets('the call screen waits for the ringback\'s audio work, one '
        'second at most', (WidgetTester tester) async {
      await installCallJoinDefaults();
      addTearDown(removeCallJoinDefaults);
      await ring(tester);
      // The native side has not answered the accept's stop yet (iOS runs it
      // on a queue of its own, behind whatever came before).
      final Completer<void> native = Completer<void>();
      SoundChannelSpy.onCall = (MethodCall call) async {
        final Map<Object?, Object?>? args =
            call.arguments as Map<Object?, Object?>?;
        if (call.method == 'stopCallTone' && args?['keepAudio'] == true) {
          await native.future;
        }
      };

      _screenBloc().onOutgoingCallAccepted(buildCall());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(CallScreenOverlay.isShowing, isFalse);
      expect(_stops, <String>['keep']);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(CallScreenOverlay.isShowing, isTrue);
      expect(_stops, <String>['keep', 'handover']);

      native.complete();
      CallScreenOverlay.dismiss();
      await tester.pumpAndSettle();
    });

    testWidgets('the screen closed during that wait (a logout, say): no call '
        'screen, and the audio is given back', (WidgetTester tester) async {
      await installCallJoinDefaults();
      addTearDown(removeCallJoinDefaults);
      await ring(tester);
      final Completer<void> native = Completer<void>();
      SoundChannelSpy.onCall = (MethodCall call) async {
        final Map<Object?, Object?>? args =
            call.arguments as Map<Object?, Object?>?;
        if (call.method == 'stopCallTone' && args?['keepAudio'] == true) {
          await native.future;
        }
      };

      _screenBloc().onOutgoingCallAccepted(buildCall());
      await tester.pump();
      // What a logout does to the outgoing call screens.
      ActiveCallTracker.closeOutgoingScreens();
      native.complete();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(CallScreenOverlay.isShowing, isFalse);
      expect(find.byType(CometChatOutgoingCall), findsNothing);
      expect(_stops, <String>['keep', 'release']);
    });
  });

  // Round 2, P2-C06: ringing ends when the call is answered, declined or
  // cancelled, not when the screen's route is disposed after its pop
  // animation.
  group('the tone stops the moment ringing ends (round 2, P2-C06)', () {
    testWidgets('P2-N03: an accept stops it before the permission prompt', (
      WidgetTester tester,
    ) async {
      await mountCallNavigator(tester);
      // The user refuses at the prompt, so no call screen follows. The
      // refusal is set before the prompt opens: a request already waiting
      // answers as the stub stood when it was asked, and reinstalling the
      // stub afterwards let this accept through, leaving a call screen up
      // for whichever test ran next (round 2's order dependence).
      PermissionChannelStub.install(granted: false);
      final Completer<void> prompt = Completer<void>();
      PermissionChannelStub.gate = prompt;
      final OutgoingCallBloc bloc = OutgoingCallBloc(call: buildCall());
      addTearDown(() => _closeSoon(bloc));
      await tester.runAsync(pumpEventQueue);

      bloc.onOutgoingCallAccepted(buildCall());
      await tester.runAsync(pumpEventQueue);

      // The prompt is still up.
      expect(PermissionChannelStub.requested, isNotEmpty);
      expect(bloc.state.status, OutgoingCallStatus.accepted);
      expect(_toneCalls, <String>['playCallTone', 'stopCallTone']);
      expect(_stops, <String>['keep']);

      prompt.complete();
      await tester.runAsync(pumpEventQueue);
      // Refused: no call screen, and the audio is given back.
      expect(CallScreenOverlay.isShowing, isFalse);
      expect(_stops, <String>['keep', 'release']);
      await tester.runAsync(bloc.close);
    });

    testWidgets('P2-N05: End stops it at once, while the cancel is still in '
        'flight', (WidgetTester tester) async {
      await mountCallNavigator(tester);
      final Completer<void> server = Completer<void>();
      dataSource.rejectGate = server;
      final OutgoingCallBloc bloc = OutgoingCallBloc(call: buildCall());
      addTearDown(() => _closeSoon(bloc));
      await tester.runAsync(pumpEventQueue);

      bloc.add(const CancelCall());
      await tester.runAsync(pumpEventQueue);

      // The server has not answered the cancel yet.
      expect(dataSource.calls, <String>['rejectCall:session_1:cancelled']);
      expect(_toneCalls, <String>['playCallTone', 'stopCallTone']);

      server.complete();
      await tester.runAsync(pumpEventQueue);
      await tester.runAsync(bloc.close);
    });

    testWidgets("a host's onCancelledCallTap that takes End over keeps the "
        'tone playing', (WidgetTester tester) async {
      await mountCallNavigator(tester);
      final OutgoingCallBloc bloc = OutgoingCallBloc(
        call: buildCall(),
        onCancelledCallTap: (BuildContext _, Call _) {},
      );
      addTearDown(() => _closeSoon(bloc));
      await tester.runAsync(pumpEventQueue);

      bloc.add(const CancelCall());
      await tester.runAsync(pumpEventQueue);

      expect(_toneCalls, <String>['playCallTone']);
      expect(dataSource.calls, isEmpty);
      await tester.runAsync(bloc.close);
    });

    // Owner decision (round 2 review): the host's SoundManager.stop() stops
    // the ringback, as it did in 6.1.x when the ringback shared the message
    // player. An onCancelled that takes End over relies on it.
    testWidgets("the host's onCancelledCallTap stops the tone with "
        'CometChatUIKit.soundManager.stop(), as in 6.1.x', (
      WidgetTester tester,
    ) async {
      await mountCallNavigator(tester);
      final OutgoingCallBloc bloc = OutgoingCallBloc(
        call: buildCall(),
        onCancelledCallTap: (BuildContext _, Call _) =>
            CometChatUIKit.soundManager.stop(),
      );
      addTearDown(() => _closeSoon(bloc));
      await tester.runAsync(pumpEventQueue);

      bloc.add(const CancelCall());
      await tester.runAsync(pumpEventQueue);

      expect(_toneCalls, <String>['playCallTone', 'stopCallTone']);
      expect(_stops, <String>['release']);
      expect(SoundChannelSpy.methods, contains('stopPlayer'));

      // The tone is no longer the screen's: closing it stops nothing more.
      await tester.runAsync(bloc.close);
      await tester.runAsync(pumpEventQueue);
      expect(_toneCalls, <String>['playCallTone', 'stopCallTone']);
    });

    testWidgets('P2-N06: a decline stops it while the screen is still '
        'closing', (WidgetTester tester) async {
      await ring(tester);

      _screenBloc().onOutgoingCallRejected(buildCall());
      await tester.pump();

      // One frame into the pop: the screen is still on its way out.
      expect(find.byType(CometChatOutgoingCall), findsOneWidget);
      expect(_toneCalls, <String>['playCallTone', 'stopCallTone']);

      await tester.pumpAndSettle();
      expect(find.byType(CometChatOutgoingCall), findsNothing);
      expect(_toneCalls, <String>['playCallTone', 'stopCallTone']);
    });

    testWidgets('the server ending the call stops it too', (
      WidgetTester tester,
    ) async {
      await ring(tester);

      _screenBloc().onCallEndedMessageReceived(
        buildCall()..callStatus = CallStatusConstants.unanswered,
      );
      await tester.pump();

      expect(_toneCalls, <String>['playCallTone', 'stopCallTone']);
      await tester.pumpAndSettle();
    });
  });
}
