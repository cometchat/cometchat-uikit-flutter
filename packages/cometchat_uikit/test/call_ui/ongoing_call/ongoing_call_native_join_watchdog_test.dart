/// A call view that never reports the native join fails the call after 30 s
/// (round 4, P4-C19 with the owner's "30 s watchdog").
///
/// The 30 s join bound covered only the Calls SDK's token and verification.
/// The native join happens once the call view is mounted; it had no bound,
/// and its errors never reach Dart (the iOS plugin only prints them). A call
/// that never connected stayed on a blank call view. Now, once the view is on
/// screen, `onSessionJoined` or any participant event must arrive within
/// 30 s; otherwise the call is given up as a failed join: the screen closes,
/// the record is released, the session left, onError gets JOIN_TIMEOUT, and
/// nothing is sent to the server. Also: the handed-over audio is forgotten
/// once the session joins (the Calls engine has it). Nothing re-applies the
/// earpiece after the join any more (round 4 review: Android's VOICE session
/// starts on it by itself, and the iOS SDK routes call audio to the
/// loudspeaker whatever is asked).
///
///   flutter test test/call_ui/ongoing_call/ongoing_call_native_join_watchdog_test.dart
@Timeout(Duration(seconds: 60))
library;

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/call_session_settings.dart';

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
    // On, at the owner's 30 s (the defaults turn it off).
    ActiveCallTracker.nativeJoinTimeout = const Duration(seconds: 30);
    errors = <Exception>[];
    service.activeCall = buildCall();
  });

  tearDown(() async {
    CallScreenOverlay.dismiss();
    removeCallJoinDefaults();
    service.activeCall = null;
    await CallOperationsServiceLocator.instance.reset();
    CallStateService.instance.setActiveCallValue(false);
    CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
  });

  /// Shows `session_1`'s call screen with [settings] and lets its view
  /// appear (the frame after the join).
  Future<void> showJoined(
    WidgetTester tester, {
    SessionSettingsBuilder? settings,
  }) async {
    await mountCallNavigator(tester);
    CallScreenOverlay.show(
      sessionId: 'session_1',
      sessionSettingsBuilder: settings ?? SessionSettingsBuilder(),
      onError: errors.add,
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(FakeCallingWidget), findsOneWidget);
  }

  void sdkSessionJoined() {
    for (final SessionStatusListeners l in List.of(
      CallSession.getInstance()!.sessionStatusListeners,
    )) {
      l.onSessionJoined();
    }
  }

  void sdkParticipants(List<Participant> participants) {
    for (final ParticipantEventListeners l in List.of(
      CallSession.getInstance()!.participantEventListeners,
    )) {
      l.onParticipantListChanged(participants);
    }
  }

  /// How each `releaseHandedOverCallAudio` asked to leave the audio.
  List<bool> handedOverReleases() => <bool>[
    for (final MethodCall c in SoundChannelSpy.calls)
      if (c.method == 'releaseHandedOverCallAudio')
        (c.arguments as Map<Object?, Object?>)['restore']! as bool,
  ];

  testWidgets('P4-N17/P4-E05: no join reported 30 s after the view appeared: '
      'a failed join (JOIN_TIMEOUT), no endCall', (WidgetTester tester) async {
    await showJoined(tester);

    await tester.pump(const Duration(seconds: 29));
    expect(CallScreenOverlay.isShowing, isTrue);
    expect(errors, isEmpty);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    final CometChatException error = errors.single as CometChatException;
    expect(error.code, 'JOIN_TIMEOUT');
    expect(CallScreenOverlay.isShowing, isFalse);
    expect(service.activeCall, isNull);
    expect(dataSource.endSessionCount, 1);
    expect(dataSource.endCallCount, 0);
    expect(handedOverReleases(), <bool>[true]);
  });

  testWidgets('onSessionJoined at 5 s: no failure at 60 s; the handed-over '
      'audio is forgotten', (WidgetTester tester) async {
    await showJoined(tester);

    await tester.pump(const Duration(seconds: 5));
    sdkSessionJoined();
    await tester.pump();
    await tester.pump(const Duration(seconds: 55));

    expect(errors, isEmpty);
    expect(CallScreenOverlay.isShowing, isTrue);
    expect(dataSource.endSessionCount, 0);
    expect(handedOverReleases(), <bool>[false]);
  });

  testWidgets('a participant event at 3 s counts as joined too', (
    WidgetTester tester,
  ) async {
    await showJoined(tester);

    await tester.pump(const Duration(seconds: 3));
    sdkParticipants(<Participant>[Participant(uid: 'peer')]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 60));

    expect(errors, isEmpty);
    expect(CallScreenOverlay.isShowing, isTrue);
  });

  testWidgets('the call ended before 30 s: no JOIN_TIMEOUT later', (
    WidgetTester tester,
  ) async {
    await showJoined(tester);

    await tester.pump(const Duration(seconds: 10));
    CallSession.getInstance()!.buttonClickListeners.toList().forEach(
      (ButtonClickListeners l) => l.onLeaveSessionButtonClicked(),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 40));

    expect(errors, isEmpty);
    expect(dataSource.endCallCount, 1);
  });

  testWidgets('counted from when the view is on screen, not from the join: '
      'no frame, no count', (WidgetTester tester) async {
    await mountCallNavigator(tester);
    CallScreenOverlay.show(
      sessionId: 'session_1',
      sessionSettingsBuilder: SessionSettingsBuilder(),
      onError: errors.add,
    );
    // The first frame builds the screen, which starts the join; the view
    // comes back without another frame drawn (an app in the background).
    await tester.pump();
    await tester.idle();
    await tester.binding.delayed(const Duration(seconds: 40));
    expect(errors, isEmpty);

    // A frame: the view is on screen now, and the 30 s count starts.
    await tester.pump();
    await tester.pump(const Duration(seconds: 29));
    expect(errors, isEmpty);
    await tester.pump(const Duration(seconds: 2));
    expect((errors.single as CometChatException).code, 'JOIN_TIMEOUT');
  });

  testWidgets('round 4 review: nothing re-applies the audio mode once the '
      'session joins, and the plugin\'s private device list is never asked '
      'for (a voice call on the kit settings or a video call)', (
    WidgetTester tester,
  ) async {
    await showJoined(
      tester,
      settings: CallSessionSettings.forCall(isVideo: false),
    );
    sdkSessionJoined();
    await tester.pump();
    await tester.pump();
    CallScreenOverlay.dismiss();
    await tester.pump();

    await showJoined(
      tester,
      settings: CallSessionSettings.forCall(isVideo: true),
    );
    sdkSessionJoined();
    await tester.pump();
    await tester.pump();

    expect(CallsPluginChannelRecorder.methods, isNot(contains('setAudioMode')));
    expect(
      CallsPluginChannelRecorder.methods,
      isNot(contains('getAvailableAudioDevices')),
    );
  });
}
