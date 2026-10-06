import 'package:flutter/foundation.dart';

import '../shared_ui/src/constants/ui_kit_constants.dart';
import '../shared_ui/src/logging/cometchat_log.dart';

/// What becomes of the audio the outgoing call's ringback (`CallTone`) or
/// the incoming call's ringtone (`IncomingRingtone`) handed to the call
/// screen.
///
/// At the hand-over the tone leaves the audio as it is for the Calls engine
/// to take: on Android the communication mode and route the ringback set,
/// and audio focus for a while; on iOS the audio session the tone set up
/// and activated. A call that never joined left it there, until the Calls
/// SDK tore something down: on Android the device stayed in communication
/// mode, on iOS the session stayed active (other apps' music stayed paused)
/// and in the tone's category (round 2 review, C9).
///
/// * [restore]: the call screen gave the call up without joining (the
///   single failed-join exit). Whatever the tone handed over and nobody took
///   goes back as it was before the tone started: the mode and the route,
///   audio focus, the iOS session's category, deactivated so music resumes.
///   On iOS only a session still as the tone left it is touched.
/// * [forget]: the call joined: the Calls engine has the audio now, and the
///   tone forgets what it handed over.
///
/// Package-private (see `lib/src/`). Only Android and iOS implement the
/// channel method; everywhere else this does nothing, and no failure
/// reaches the caller.
abstract final class CallAudioHandover {
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Gives back what a hand-over left behind: see the class doc.
  static Future<void> restore() => _release(restore: true);

  /// Forgets what a hand-over left behind: see the class doc.
  static Future<void> forget() => _release(restore: false);

  static Future<void> _release({required bool restore}) async {
    if (!_supported) return;
    try {
      await UIConstants.channel.invokeMethod<Object?>(
        'releaseHandedOverCallAudio',
        <String, Object?>{'restore': restore},
      );
    } catch (e) {
      ccLog('CallAudioHandover: could not release the handed-over audio: $e');
    }
  }
}
