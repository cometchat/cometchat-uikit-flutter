import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show LayoutType, SessionSettingsBuilder;
import 'package:cometchat_sdk/cometchat_sdk.dart' show Group, User;

import '../call_ui/src/calling_configuration.dart';
import 'call_session_settings.dart';

/// The session settings a group meeting joins with: one resolver for the
/// host who starts it from the call buttons and for every member who joins
/// it from its bubble (round 5, P5-C05; the owner's D04 A).
///
/// Package-private (see `lib/src/`).
///
/// The host and the members used to read different builders, and a
/// member's audio Join wrote the audio flags into the app's own
/// `groupSessionSettingsBuilder` (the plugin's setters change the builder
/// they are called on): every later Join, video ones included, started
/// with the camera paused and the video toggle hidden.
abstract final class MeetingSessionSettings {
  /// The settings for a meeting; with [isAudioOnly], an audio meeting.
  ///
  /// The first of these that is set:
  /// 1. [settingsFactory], called with the meeting's [group]: the call
  ///    buttons' `callSettingsBuilder` for the host, and
  ///    `CallButtonsConfiguration.callSettingsBuilder` for a member's Join;
  /// 2. the [configuration]'s `groupSessionSettingsBuilder`;
  /// 3. [hostFallback]: the host's `outgoingCallConfiguration`
  ///    `sessionSettingsBuilder`, kept for the host only, as in 6.1.x;
  /// 4. the UI Kit's own: the tile layout.
  ///
  /// An audio meeting gets the audio session type, the camera paused and
  /// the video toggle and camera switch hidden on top of whichever it is
  /// ([CallTypeSessionSettingsBuilder], round 4). They are applied when the
  /// call screen builds the settings and taken off again at once, so the
  /// app's builder never keeps them. Android runs the audio type as a
  /// VOICE session. The iOS Calls SDK ignores the type and keeps a video
  /// session, so on iOS the paused camera and the hidden controls are what
  /// keep an audio meeting voice-only: they are needed, not a leftover.
  ///
  /// A video meeting joins with the builder as it is.
  static SessionSettingsBuilder resolve({
    required bool isAudioOnly,
    SessionSettingsBuilder Function(
      User? user,
      Group? group,
      bool? isAudioOnly,
    )?
    settingsFactory,
    Group? group,
    CallingConfiguration? configuration,
    SessionSettingsBuilder? hostFallback,
  }) {
    final SessionSettingsBuilder base =
        settingsFactory?.call(null, group, isAudioOnly) ??
        configuration?.groupSessionSettingsBuilder ??
        hostFallback ??
        SessionSettingsBuilder().setLayout(LayoutType.tile);
    if (!isAudioOnly) return base;
    return CallTypeSessionSettingsBuilder(base, isVideo: false);
  }
}
