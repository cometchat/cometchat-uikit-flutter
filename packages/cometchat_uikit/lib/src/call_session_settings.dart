import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show
        AudioMode,
        LayoutType,
        SessionSettings,
        SessionSettingsBuilder,
        SessionType;

/// The session settings the UI Kit's 1-on-1 call screens join with.
///
/// Package-private (see `lib/src/`). The outgoing and incoming call use
/// [CallSessionSettings.forCall]: the kit's own default
/// ([KitCallSessionSettingsBuilder]) when the host gave no builder,
/// otherwise the host's with the call's type applied on top
/// ([CallTypeSessionSettingsBuilder]).
///
/// What the call's type means, and what each platform does with it (Calls
/// plugin 5.0.8, native Calls SDK 5.0.4):
///
/// * A voice call is a `SessionType.audio` session. Android maps it to its
///   VOICE session, as Android's own view model does: no video track, no
///   camera prompt, no camera dot, and the ongoing-call service asks only
///   for the microphone foreground-service type. The iOS SDK does not
///   recognise the type (it matches only "video" and "voice") and keeps a
///   VIDEO session, so on iOS the paused camera and the hidden video toggle
///   and camera switch are what make the call voice-only. Those three are
///   load-bearing on iOS, not a safety net: keep them until the iOS SDK maps
///   AUDIO.
/// * The kit's own default asks a voice call for the earpiece and a video
///   call for the loudspeaker. Android starts a VOICE session on the
///   earpiece by itself (a headset wins); the iOS SDK applies the session's
///   audio mode on Android only and routes call audio to the loudspeaker,
///   so on iOS a voice call starts on the loudspeaker. A host's builder
///   keeps the audio mode the host chose.
abstract final class CallSessionSettings {
  /// The settings for a 1-on-1 call of the given type: [hostBuilder] with
  /// the call's type applied on top ([CallTypeSessionSettingsBuilder]), or
  /// the kit's own default ([KitCallSessionSettingsBuilder]) when the host
  /// gave none.
  static SessionSettingsBuilder forCall({
    required bool isVideo,
    SessionSettingsBuilder? hostBuilder,
  }) {
    if (hostBuilder == null) {
      return KitCallSessionSettingsBuilder(isVideo: isVideo);
    }
    return CallTypeSessionSettingsBuilder(hostBuilder, isVideo: isVideo);
  }
}

/// The UI Kit's own settings for a 1-on-1 call, used when the host gives
/// none: the tile layout, and for a voice call the audio session type, the
/// camera paused with its controls hidden, and the earpiece (see
/// [CallSessionSettings] for what each platform makes of these).
final class KitCallSessionSettingsBuilder extends SessionSettingsBuilder {
  /// The kit's settings for a voice call or, with [isVideo], a video call.
  KitCallSessionSettingsBuilder({required this.isVideo}) {
    setLayout(LayoutType.tile);
    if (isVideo) {
      setType(SessionType.video);
      setAudioMode(AudioMode.speaker);
    } else {
      setType(SessionType.audio);
      // Load-bearing on iOS, whose SDK keeps a VIDEO session for AUDIO.
      startVideoPaused(true);
      hideSwitchCameraButton(true);
      hideToggleVideoButton(true);
      setAudioMode(AudioMode.earpiece);
    }
  }

  /// Whether these are a video call's settings.
  final bool isVideo;
}

/// A host's session settings builder with a 1-on-1 call's type applied on
/// top, without changing the host's builder (round 4, P4-C14).
///
/// A host builder used to be taken as it was: a voice call with a builder
/// that did not pause the camera started with the camera on. Android applies
/// the call's session type onto whatever builder it is given.
///
/// Only [build] does anything: it reads what the host's builder holds, sets
/// the call's type on it (for a voice call also the paused camera and the
/// hidden video toggle and camera switch, which iOS needs: see
/// [CallSessionSettings]), builds, and puts those four back as they were,
/// even when a setter or the build throws, so a builder the host reuses
/// never carries a voice call's settings into its next video call. The
/// plugin's builder keeps its fields private and has no copy, so setting and
/// restoring is the only way that does not depend on the plugin's version.
///
/// Do not configure this builder itself: its setters change its own unused
/// fields, not the host's. Configure the host's builder.
final class CallTypeSessionSettingsBuilder extends SessionSettingsBuilder {
  /// [host] with the type of a voice call, or with [isVideo] a video call.
  CallTypeSessionSettingsBuilder(this.host, {required this.isVideo});

  /// The host's builder.
  final SessionSettingsBuilder host;

  /// Whether the call is a video call.
  final bool isVideo;

  @override
  SessionSettings build() {
    final SessionSettings before = host.build();
    try {
      if (isVideo) {
        host.setType(SessionType.video);
      } else {
        host
            .setType(SessionType.audio)
            .startVideoPaused(true)
            .hideSwitchCameraButton(true)
            .hideToggleVideoButton(true);
      }
      return host.build();
    } finally {
      host
          .setType(before.type)
          .startVideoPaused(before.startVideoPaused)
          .hideSwitchCameraButton(before.hideSwitchCameraButton)
          .hideToggleVideoButton(before.hideToggleVideoButton);
    }
  }
}
