import 'package:flutter/foundation.dart';

import '../shared_ui/src/constants/ui_kit_constants.dart';
import '../shared_ui/src/logging/cometchat_log.dart';
import 'sound_loop_owner.dart';

/// The outgoing call's ringback: a looping call tone on a native player of
/// its own, apart from the message sounds `SoundManager` plays.
///
/// Sharing the message player, a message that arrived while the call rang
/// replaced the ringback and the caller went silent; the ringback also
/// played through the media stream from the loudspeaker, and followed the
/// media volume. The native side plays it as a phone call sounds instead:
/// from the earpiece for a voice call and the loudspeaker for a video call,
/// looping, in iOS Silent Mode too, with the audio set up for a call (the
/// iOS audio session, the Android communication mode and route, audio
/// focus), and gives all of that back when it stops.
///
/// How the audio is left when the tone stops depends on why ringing ended:
///
/// * [stop]: the call is over (declined, cancelled, timed out, the screen
///   closed). The audio is given back as it was, so paused music resumes.
/// * [pause]: the callee answered. Only the playback stops: the audio stays
///   set up for a call while the caller grants permissions, so music does
///   not come back for the moment before the call starts.
/// * [handOver]: the call screen is about to open. The Calls engine takes
///   the audio over; the tone forgets it without touching it. Restoring it
///   under the engine cut the call's audio on iOS.
///
/// An accept that ends without a call screen (permissions refused, no
/// navigator) calls [stop], which gives the audio back from [pause]'s state.
///
/// Package-private. It lives under `lib/src/`, which no barrel exports, so
/// none of this is public API; hosts keep choosing the sound through the
/// outgoing call's `customSoundForCalls`, `customSoundForCallsPackage` and
/// `disableSoundForCalls`, and stop it with `SoundManager.stop()` ([stopAll]).
/// The UI Kit's own screens stop only the tone they started.
///
/// Only Android and iOS implement the channel methods. Everywhere else this
/// does nothing, and no failure reaches the caller: a missing ringback must
/// never stop a call from being placed.
class CallTone {
  CallTone._();

  /// The kit's own ringback, in this package's assets. Used when the host
  /// names no sound of its own, or when the host's cannot be found.
  static const String defaultAsset = 'assets/sound/outgoing_call.wav';

  /// Whether the app runs on the web. `kIsWeb` is a compile-time constant,
  /// so this is the only way a test can reach the web guard.
  @visibleForTesting
  static bool isWeb = kIsWeb;

  /// Who started the tone playing now; see [play]'s `owner`.
  static final SoundLoopOwner _loop = SoundLoopOwner();

  /// Forgets who started the tone, for tests.
  @visibleForTesting
  static void debugReset() => _loop.reset();

  static bool get _supported =>
      !isWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Starts the ringback, looping, routed for a voice or a video call.
  ///
  /// [assetPath] is the host's sound, from [package]'s assets (null for the
  /// app's own). Without one, the kit's [defaultAsset] plays, from the kit's
  /// package whatever [package] says.
  ///
  /// A host sound that cannot be found (or played) is looked for in the
  /// app's own assets next, and then the kit's [defaultAsset] plays
  /// instead; the native side tries them in that order. Before 6.2.0
  /// [package] was ignored for the ringback on both platforms, so a host
  /// that named its own app, or `'assets'`, still hears its sound.
  ///
  /// [owner] (the outgoing call's bloc) is who plays it: a [stop], [pause]
  /// or [handOver] that names an owner only acts on the tone that owner
  /// started, so a screen closing late cannot silence the next call's
  /// ringback.
  static Future<void> play({
    String? assetPath,
    String? package,
    required bool isVideo,
    Object? owner,
  }) async {
    if (owner != null) _loop.take(owner);
    if (!_supported) return;
    final bool custom = assetPath != null && assetPath.isNotEmpty;
    try {
      await UIConstants.channel
          .invokeMethod<Object?>('playCallTone', <String, Object?>{
            'assetPath': custom ? assetPath : defaultAsset,
            'package': custom ? package : UIConstants.packageName,
            'isVideo': isVideo,
            'fallbackAssetPath': defaultAsset,
            'fallbackPackage': UIConstants.packageName,
          });
    } catch (e) {
      ccLog('CallTone: could not play the call tone: $e');
    }
  }

  /// Stops the ringback and gives the audio back as it was before it
  /// played: the session (iOS), the communication mode and route (Android),
  /// and audio focus.
  ///
  /// With [owner], only when [owner] started the tone playing now (see
  /// [play]); otherwise it belongs to someone else and keeps playing.
  static Future<void> stop({Object? owner}) async {
    if (owner != null && !_loop.release(owner)) return;
    await _stop(handover: false, keepAudio: false);
  }

  /// Stops the ringback's playback only, when [owner] started it: the
  /// callee answered, and the audio stays set up for the call. [owner]
  /// still owns the tone: [handOver] or [stop] ends it.
  ///
  /// Completes once the native side has done the work queued before it (on
  /// iOS the audio session work runs on a queue of its own), so the Calls
  /// engine never starts on a session the tone is still changing.
  static Future<void> pause({required Object owner}) async {
    if (!_loop.owns(owner)) return;
    await _stop(handover: false, keepAudio: true);
  }

  /// Hands the audio [owner]'s tone set up over to the Calls engine: right
  /// before the call screen opens. The native side forgets the session and
  /// the route without touching them, and on Android keeps audio focus
  /// until the engine takes it (10 seconds at most), so music does not
  /// resume in between.
  static Future<void> handOver({required Object owner}) async {
    if (!_loop.release(owner)) return;
    await _stop(handover: true, keepAudio: false);
  }

  /// Stops the ringback whoever started it, and gives its audio back: what
  /// the host's `SoundManager.stop()` does. The ringback played on the
  /// message player until 6.2.0, where that stop stopped it, and a host
  /// that takes End over with `onCancelled` relies on it (owner decision,
  /// round 2 review). After a hand-over the call's audio is not the tone's
  /// any more: the native side then only makes sure nothing plays.
  static Future<void> stopAll() async {
    _loop.reset();
    await _stop(handover: false, keepAudio: false);
  }

  static Future<void> _stop({
    required bool handover,
    required bool keepAudio,
  }) async {
    if (!_supported) return;
    try {
      await UIConstants.channel.invokeMethod<Object?>(
        'stopCallTone',
        <String, Object?>{'handover': handover, 'keepAudio': keepAudio},
      );
    } catch (e) {
      ccLog('CallTone: could not stop the call tone: $e');
    }
  }
}
