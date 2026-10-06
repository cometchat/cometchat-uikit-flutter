/// The session settings a 1-on-1 call joins with (round 4: P4-C13, P4-C14,
/// P4-C15), and the opener's onError on the call screens the kit opens
/// (P4-C12, done in round 1b, pinned here by identity).
///
/// * A voice call is a `SessionType.audio` session, as on Android (its view
///   model sets VOICE). It used to be a video session with the camera
///   paused: on Android 14+ that asked for the camera foreground service
///   type. The iOS SDK keeps a VIDEO session for AUDIO, so the paused camera
///   and hidden video controls stay: on iOS they are what makes the call
///   voice-only.
/// * The call's type applies on top of a host's settings builder, without
///   changing it, even when one of the host's setters throws: a host builder
///   that did not pause the camera started a voice call with the camera on.
/// * The kit's own settings ask for the earpiece for a voice call and the
///   loudspeaker for a video call (Android honours it; the iOS SDK routes
///   call audio to the loudspeaker); a host builder keeps the audio mode it
///   chose. Nothing re-applies the earpiece after the join any more (round 4
///   review: Android's VOICE session starts on it by itself, and the
///   re-apply through the plugin's private channel could flip a speaker tap
///   back).
///
///   flutter test test/call_ui/call_session_settings_test.dart
@Timeout(Duration(seconds: 60))
library;

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/call_ui/src/call_buttons/bloc/call_buttons_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_buttons/bloc/call_buttons_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/incoming_call/bloc/incoming_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/call_screen_overlay.dart';
import 'package:cometchat_chat_uikit/call_ui/src/ongoing_call/cometchat_ongoing_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/bloc/outgoing_call_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/cometchat_outgoing_call.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/constants/ui_kit_constants.dart'
    show CallTypeConstants;
import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_events.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/call_session_settings.dart';

import 'helpers/call_bloc_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("the kit's own settings (no host builder)", () {
    test('P4-C13/P4-C15: a voice call: an audio session, the camera paused '
        'with its controls hidden, on the earpiece', () {
      final SessionSettings s = CallSessionSettings.forCall(
        isVideo: false,
      ).build();

      expect(s.type, SessionType.audio);
      expect(s.startVideoPaused, isTrue);
      expect(s.hideToggleVideoButton, isTrue);
      expect(s.hideSwitchCameraButton, isTrue);
      expect(s.audioMode, AudioMode.earpiece);
      expect(s.layout, LayoutType.tile);
    });

    test('P4-C13/P4-C15: a video call: a video session on the loudspeaker, '
        'the camera on', () {
      final SessionSettings s = CallSessionSettings.forCall(
        isVideo: true,
      ).build();

      expect(s.type, SessionType.video);
      expect(s.startVideoPaused, isFalse);
      expect(s.hideToggleVideoButton, isFalse);
      expect(s.audioMode, AudioMode.speaker);
      expect(s.layout, LayoutType.tile);
    });
  });

  group("P4-C14: the call's type on top of a host's builder", () {
    test('a voice call with a builder that does not pause the camera: an '
        "audio session with the camera paused; the host's builder is left "
        'as it was', () {
      final SessionSettingsBuilder host = SessionSettingsBuilder()
        ..startVideoPaused(false)
        ..setLayout(LayoutType.spotlight);

      final SessionSettings s = CallSessionSettings.forCall(
        isVideo: false,
        hostBuilder: host,
      ).build();

      expect(s.type, SessionType.audio);
      expect(s.startVideoPaused, isTrue);
      expect(s.hideToggleVideoButton, isTrue);
      expect(s.hideSwitchCameraButton, isTrue);
      expect(s.layout, LayoutType.spotlight);

      final SessionSettings after = host.build();
      expect(after.startVideoPaused, isFalse);
      expect(after.type, SessionType.video);
      expect(after.hideToggleVideoButton, isFalse);
      expect(after.hideSwitchCameraButton, isFalse);
    });

    test("a video call keeps the host's paused camera, and is a video "
        'session even on a builder set to audio', () {
      final SessionSettingsBuilder host = SessionSettingsBuilder()
        ..startVideoPaused(true)
        ..setType(SessionType.audio);

      final SessionSettings s = CallSessionSettings.forCall(
        isVideo: true,
        hostBuilder: host,
      ).build();

      expect(s.type, SessionType.video);
      expect(s.startVideoPaused, isTrue);
      expect(host.build().type, SessionType.audio);
    });

    test("a host's setter that throws leaves the host's builder as it "
        'was (round 4 review)', () {
      final _ThrowingBuilder host = _ThrowingBuilder()..startVideoPaused(false);

      expect(
        () => CallSessionSettings.forCall(
          isVideo: false,
          hostBuilder: host,
        ).build(),
        throwsStateError,
      );

      final SessionSettings after = host.build();
      expect(after.type, SessionType.video);
      expect(after.startVideoPaused, isFalse);
      expect(after.hideSwitchCameraButton, isFalse);
      expect(after.hideToggleVideoButton, isFalse);
    });

    test("P4-C15: a host builder keeps the audio mode it chose (the "
        'earpiece is the kit default only)', () {
      final SessionSettingsBuilder host = SessionSettingsBuilder()
        ..setAudioMode(AudioMode.speaker);

      expect(
        CallSessionSettings.forCall(
          isVideo: false,
          hostBuilder: host,
        ).build().audioMode,
        AudioMode.speaker,
      );
      final SessionSettingsBuilder bluetooth = SessionSettingsBuilder()
        ..setAudioMode(AudioMode.bluetooth);
      expect(
        CallSessionSettings.forCall(
          isVideo: true,
          hostBuilder: bluetooth,
        ).build().audioMode,
        AudioMode.bluetooth,
      );
    });
  });

  group('the call screens the kit opens', () {
    late FakeCallOperationsDataSource dataSource;

    setUp(() async {
      await CallOperationsServiceLocator.instance.reset();
      dataSource = FakeCallOperationsDataSource();
      CallOperationsServiceLocator.instance.setup(dataSource: dataSource);
      await installCallJoinDefaults();
      CallEventService.instance.activeCall = null;
      ActiveCallTracker.ringingCall = null;
    });

    tearDown(() async {
      CallScreenOverlay.dismiss();
      removeCallJoinDefaults();
      SoundChannelSpy.remove();
      CallEventService.instance.activeCall = null;
      ActiveCallTracker.ringingCall = null;
      await CallOperationsServiceLocator.instance.reset();
      CallStateService.instance.setActiveCallValue(false);
      CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
    });

    testWidgets('P4-C13: the caller, a voice call: joins as an audio session '
        'on the earpiece, and asks for the microphone only; P4-C12: the '
        "screen reports to the outgoing call's onError", (
      WidgetTester tester,
    ) async {
      await mountCallNavigator(tester);
      void onError(Exception e) {}
      final Call placed = buildCall();
      final OutgoingCallBloc outgoing = OutgoingCallBloc(
        call: placed,
        disableSoundForCalls: true,
        errorCallback: onError,
      );
      addTearDown(outgoing.close);
      PermissionChannelStub.requested.clear();

      outgoing.add(OutgoingCallAccepted(placed));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final SessionSettings joinedWith = dataSource.startedSettings.single;
      expect(joinedWith.type, SessionType.audio);
      expect(joinedWith.audioMode, AudioMode.earpiece);
      expect(PermissionChannelStub.cameraRequested, isFalse);
      final CometChatOngoingCall screen = tester.widget<CometChatOngoingCall>(
        find.byType(CometChatOngoingCall),
      );
      expect(screen.onError, same(onError));
    });

    testWidgets('round 4 review: a voice call placed from the call buttons '
        '(the message header) with no builder of the host\'s: the outgoing '
        'screen gets none, and the call joins with the kit default (an audio '
        'session on the earpiece), as the callee\'s does', (
      WidgetTester tester,
    ) async {
      await mountCallNavigator(tester);
      dataSource.placedSessionId = 'session_1';
      final CallButtonsBloc buttons = CallButtonsBloc(
        user: User(uid: 'peer', name: 'Peer'),
      );

      buttons.add(const InitiateVoiceCall());
      await tester.pump();
      await tester.pumpAndSettle();
      final CometChatOutgoingCall outgoing = tester
          .widget<CometChatOutgoingCall>(find.byType(CometChatOutgoingCall));
      expect(outgoing.sessionSettingsBuilder, isNull);

      _outgoingBloc().onOutgoingCallAccepted(buildCall());
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final SessionSettings joinedWith = dataSource.startedSettings.single;
      expect(joinedWith.type, SessionType.audio);
      expect(joinedWith.audioMode, AudioMode.earpiece);
      expect(joinedWith.startVideoPaused, isTrue);
      expect(
        tester
            .widget<CometChatOngoingCall>(find.byType(CometChatOngoingCall))
            .sessionSettingsBuilder,
        isA<KitCallSessionSettingsBuilder>(),
      );

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(buttons.close);
    });

    testWidgets("the call buttons' own callSettingsBuilder reaches the "
        "outgoing screen, and the call's type is applied on top of it", (
      WidgetTester tester,
    ) async {
      await mountCallNavigator(tester);
      dataSource.placedSessionId = 'session_1';
      final SessionSettingsBuilder host = SessionSettingsBuilder()
        ..setAudioMode(AudioMode.speaker)
        ..setLayout(LayoutType.spotlight);
      final CallButtonsBloc buttons = CallButtonsBloc(
        user: User(uid: 'peer', name: 'Peer'),
        callSettingsBuilder: (User? u, Group? g, bool? audioOnly) => host,
      );

      buttons.add(const InitiateVoiceCall());
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CometChatOutgoingCall>(find.byType(CometChatOutgoingCall))
            .sessionSettingsBuilder,
        same(host),
      );

      _outgoingBloc().onOutgoingCallAccepted(buildCall());
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final SessionSettings joinedWith = dataSource.startedSettings.single;
      expect(joinedWith.type, SessionType.audio);
      expect(joinedWith.audioMode, AudioMode.speaker);
      expect(joinedWith.layout, LayoutType.spotlight);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(buttons.close);
    });

    testWidgets('P4-C14: the callee, a voice call with a host builder that '
        "keeps the camera on: joins as an audio session; the host's builder "
        "is untouched; P4-C12: the incoming call's onError", (
      WidgetTester tester,
    ) async {
      await mountCallNavigator(tester);
      void onError(Exception e) {}
      final SessionSettingsBuilder host = SessionSettingsBuilder()
        ..startVideoPaused(false);
      final IncomingCallBloc incoming = IncomingCallBloc(
        call: buildCall(),
        disableSoundForCalls: true,
        callSettingsBuilder: host,
        errorCallback: onError,
      );
      addTearDown(incoming.close);

      incoming.add(const AcceptCall());
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final SessionSettings joinedWith = dataSource.startedSettings.single;
      expect(joinedWith.type, SessionType.audio);
      expect(joinedWith.startVideoPaused, isTrue);
      expect(host.build().startVideoPaused, isFalse);
      expect(host.build().type, SessionType.video);
      final CometChatOngoingCall screen = tester.widget<CometChatOngoingCall>(
        find.byType(CometChatOngoingCall),
      );
      expect(screen.onError, same(onError));
      expect(screen.sessionSettingsBuilder, isNot(same(host)));
    });

    testWidgets('the callee, a video call on the kit settings: a video '
        'session on the loudspeaker', (WidgetTester tester) async {
      await mountCallNavigator(tester);
      final IncomingCallBloc incoming = IncomingCallBloc(
        call: buildCall(type: CallTypeConstants.videoCall),
        disableSoundForCalls: true,
      );
      addTearDown(incoming.close);

      incoming.add(const AcceptCall());
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final SessionSettings joinedWith = dataSource.startedSettings.single;
      expect(joinedWith.type, SessionType.video);
      expect(joinedWith.audioMode, AudioMode.speaker);
      expect(
        tester
            .widget<CometChatOngoingCall>(find.byType(CometChatOngoingCall))
            .sessionSettingsBuilder,
        isA<KitCallSessionSettingsBuilder>(),
      );
      expect(dataSource.startSessionCount, 1);
    });
  });
}

/// A host builder whose camera-switch setter throws once the call's type is
/// being applied (a host subclass that validates its own settings, say).
class _ThrowingBuilder extends SessionSettingsBuilder {
  bool _armed = false;

  @override
  SessionSettingsBuilder setType(SessionType type) {
    _armed = type == SessionType.audio;
    return super.setType(type);
  }

  @override
  SessionSettingsBuilder hideSwitchCameraButton(bool hide) {
    if (_armed && hide) throw StateError('no hidden camera switch here');
    return super.hideSwitchCameraButton(hide);
  }
}

/// The outgoing call screen's bloc: it listens for the call's events.
OutgoingCallBloc _outgoingBloc() => CometChatCallEvents
    .callEventsListener
    .values
    .whereType<OutgoingCallBloc>()
    .single;
