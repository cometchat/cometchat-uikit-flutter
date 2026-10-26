import 'package:flutter/foundation.dart';

import '../../../../../../../call_ui/src/utils/call_state_service.dart';
import '../../../../../logging/cometchat_log.dart';
import '../../../../core/constants/ui_kit_constants.dart';
import '../../../../core/utils/platform_utils/platform_file_utils.dart'
    as platform;

/// Readies the iOS audio session for an audio message about to play.
///
/// iOS has one audio session per app, shared with calls. After a call it
/// was left as the call or its tones had it (a play-and-record, voice-chat
/// session on the earpiece, say), and audio messages played there were not
/// heard until the app restarted: their player only sets the session once,
/// when it is first used. So the session is set to playback, from the
/// loudspeaker, right before each one plays. Never during a call, which owns
/// the session; a ringtone, ringback or voice note that has it keeps it.
class AudioPlaybackSession {
  AudioPlaybackSession._();

  /// Whether the session needs handling here. Only iOS implements the
  /// channel method. Replaceable for tests.
  @visibleForTesting
  static bool Function() isIOS = () => !kIsWeb && platform.platformIsIOS();

  /// Whether a call is in progress. Replaceable for tests.
  @visibleForTesting
  static bool Function() isCallActive = () =>
      CallStateService.instance.isActiveCall.value;

  /// Readies the session. Never throws.
  static Future<void> prepare() async {
    if (!isIOS() || isCallActive()) return;
    try {
      await UIConstants.channel.invokeMethod<bool>(
        'prepareAudioSessionForPlayback',
      );
    } catch (e) {
      ccLog('AudioPlaybackSession: could not ready the session: $e');
    }
  }
}
