import 'package:flutter/foundation.dart';

import '../shared_ui/src/constants/ui_kit_constants.dart';
import '../shared_ui/src/logging/cometchat_log.dart';
import 'active_call_tracker.dart';
import 'sound_loop_owner.dart';

/// The incoming call's ringtone, and its vibration, on a native player of
/// its own, apart from the message sounds and the outgoing call's ringback.
///
/// It used to loop on the message sounds' player: on Android at media
/// volume, even in Silent and Vibrate mode; on iOS it was not found at all
/// (its package was not part of the lookup), and would have played once. A
/// message arriving while it rang replaced it for good, and the phone never
/// vibrated. The native side now rings as the phone's own ringer does (the
/// owner's "system-like" rule):
///
/// * Android: the ringtone usage, so the ring volume and Silent and Vibrate
///   mode apply; Do Not Disturb as for a caller who is not a contact (it
///   rings only when DND is off or lets calls from anyone through); no audio
///   mode or speaker changes; it vibrates as the phone's settings say
///   (never in Silent mode, always in Vibrate mode, in Sound mode by
///   "Vibrate while ringing", the ramping ringer, and from Android 13 the
///   ring vibration intensity); audio focus only while it can be heard,
///   given back when it stops.
/// * iOS: looping, from the loudspeaker, silent with the Ring/Silent switch
///   on Silent, vibrating every 2 s; the audio session is given back when it
///   stops. It rings only while the app is in the foreground and unlocked
///   (iOS silences this audio in the background and on the lock screen); it
///   starts again when the app comes back, if the call still rings and is
///   within its deadline (60 s from the ring's start), and a watchdog brings
///   it back if something else stopped it meanwhile.
///
/// Over a call in progress (a group meeting the incoming call rings over,
/// or any Calls SDK session joined and not left: [callActive]) it leaves the
/// call's audio alone and plays quieter. On iOS a voice note recording or
/// playing is left alone the same way. See the native `RingtonePlayer.kt`
/// and the Swift plugin's `playRingtone`.
///
/// How the audio is left when it stops depends on why ringing ended, as for
/// the ringback (`CallTone`): [stop] when the call is over (music resumes),
/// [pause] when it is answered (only the sound and vibration stop), and
/// [handOver] right before the call screen opens (the Calls engine takes
/// the audio over).
///
/// Package-private (see `lib/src/`). Hosts choose the sound through the
/// incoming call's `customSoundForCalls`, `customSoundForCallsPackage` and
/// `disableSoundForCalls` (which also turns the vibration off), play it with
/// `SoundManager.play(sound: Sound.incomingCall)`, and stop it with
/// `SoundManager.stop()` ([stopAll]).
///
/// Only Android and iOS implement the channel methods. Everywhere else this
/// does nothing, and no failure reaches the caller.
class IncomingRingtone {
  IncomingRingtone._();

  /// The kit's own ringtone, in this package's assets. Used when the host
  /// names no sound of its own, or when the host's cannot be found.
  static const String defaultAsset = 'assets/sound/incoming_call.wav';

  /// Whether the app runs on the web; see `CallTone.isWeb`.
  @visibleForTesting
  static bool isWeb = kIsWeb;

  static bool get _supported =>
      !isWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Whether an incoming call rings now: someone started the ringtone and
  /// has not stopped it. Message sounds are held back meanwhile (see
  /// `SoundManager.play`).
  static bool get isRinging => incomingRingtoneLoop.isTaken;

  /// Starts the ringtone, looping when [looping], with the vibration when
  /// [vibrate].
  ///
  /// [assetPath] is the host's sound, from [package]'s assets (null for the
  /// app's own). Without one, the kit's [defaultAsset] plays. A host sound
  /// that cannot be found is looked for in the app's own assets next, and
  /// then the kit's [defaultAsset] plays instead (the native side tries them
  /// in that order): before 6.2.0 [package] was ignored for custom sounds,
  /// so a host that named its own app, or `'assets'`, still hears its sound.
  ///
  /// [owner] (the incoming call's bloc) is who rings: a [stop], [pause] or
  /// [handOver] that names an owner only acts on the ringtone that owner
  /// started, so a banner closing late cannot silence the next call's.
  ///
  /// [deadline] is when ringing ends at the latest, by the wall clock: the
  /// incoming call's 60 s from when it started ringing. The native side
  /// does not ring past it, whatever the Dart side is doing: on iOS the app
  /// may have been suspended through it (its timers do not run then), and
  /// the ringtone it paused in the background, or that an interruption
  /// stopped, is not brought back for a call already given up.
  static Future<void> play({
    String? assetPath,
    String? package,
    bool looping = true,
    bool vibrate = true,
    Object? owner,
    DateTime? deadline,
  }) async {
    if (owner != null) incomingRingtoneLoop.take(owner);
    if (!_supported) return;
    final bool custom = assetPath != null && assetPath.isNotEmpty;
    try {
      await UIConstants.channel.invokeMethod<Object?>(
        'playRingtone',
        <String, Object?>{
          'assetPath': custom ? assetPath : defaultAsset,
          'package': custom ? package : UIConstants.packageName,
          'fallbackAssetPath': defaultAsset,
          'fallbackPackage': UIConstants.packageName,
          'looping': looping,
          'vibrate': vibrate,
          // A call is on: the kit's call screen is up (a group meeting:
          // a 1-on-1 call would have answered this one busy), or a
          // session was joined and not left (a host's own call screen, or
          // its own CometChatUIKitCalls.startSession). Its audio is not
          // the ringtone's to take: on iOS the ringtone switched the
          // call's session to soloAmbient (the microphone dropped) and a
          // decline then deactivated it; on Android it took focus from
          // the call.
          'callActive': callActive,
          'deadlineMs': deadline?.millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      ccLog('IncomingRingtone: could not play the ringtone: $e');
    }
  }

  /// Whether a call is on, whose audio the ringtone must leave alone: the
  /// kit's call screen is up, or a Calls SDK session was joined and not left
  /// since ([ActiveCallTracker.mayHaveMediaSession]).
  static bool get callActive =>
      ActiveCallTracker.callScreenSessionId != null ||
      ActiveCallTracker.mayHaveMediaSession;

  /// Stops the ringtone and the vibration, and gives the audio back.
  ///
  /// With [owner], only when [owner] started the ringtone ringing now;
  /// otherwise it belongs to someone else and keeps ringing.
  static Future<void> stop({Object? owner}) async {
    if (owner != null && !incomingRingtoneLoop.release(owner)) return;
    await _stop(handover: false, keepAudio: false);
  }

  /// Stops the sound and the vibration only, when [owner] started them: the
  /// call was answered, and the audio stays as it is for the call. [owner]
  /// still owns the ringtone: [handOver] or [stop] ends it.
  ///
  /// Completes once the native side has done the work queued before it.
  static Future<void> pause({required Object owner}) async {
    if (!incomingRingtoneLoop.owns(owner)) return;
    await _stop(handover: false, keepAudio: true);
  }

  /// Hands the audio [owner]'s ringtone held over to the Calls engine,
  /// right before the call screen opens: the native side forgets it
  /// without touching it.
  static Future<void> handOver({required Object owner}) async {
    if (!incomingRingtoneLoop.release(owner)) return;
    await _stop(handover: true, keepAudio: false);
  }

  /// Hands the ringtone's audio to a call that is starting, whoever started
  /// it ringing: the user's own call came up while another call rang, and
  /// that one is answered busy (`rejectRingingAsBusy`). Giving the audio
  /// back instead could land on the call's session as the Calls engine
  /// takes it.
  static Future<void> handOverAll() async {
    incomingRingtoneLoop.reset();
    await _stop(handover: true, keepAudio: false);
  }

  /// Stops the ringtone whoever started it, and gives its audio back: what
  /// the host's `SoundManager.stop()` does, as it did when the ringtone
  /// played on the message sounds' player.
  static Future<void> stopAll() async {
    incomingRingtoneLoop.reset();
    await _stop(handover: false, keepAudio: false);
  }

  static Future<void> _stop({
    required bool handover,
    required bool keepAudio,
  }) async {
    if (!_supported) return;
    try {
      await UIConstants.channel.invokeMethod<Object?>(
        'stopRingtone',
        <String, Object?>{'handover': handover, 'keepAudio': keepAudio},
      );
    } catch (e) {
      ccLog('IncomingRingtone: could not stop the ringtone: $e');
    }
  }
}
