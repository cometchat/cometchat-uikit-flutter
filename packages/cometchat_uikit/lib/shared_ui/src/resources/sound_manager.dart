import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../cometchat_uikit_shared.dart';
import '../../../src/call_tone.dart';
import '../../../src/incoming_ringtone.dart';
import '../logging/cometchat_log.dart';
import '../clean_architecture/core/utils/platform_utils/platform_file_utils.dart'
    as platform;

///[SoundManager] is an utility component that provides an audio player
class SoundManager {
  ///[SoundManager] is a singleton class so use this to initialize the instance of this class.
  static final SoundManager _instance = SoundManager._internal();

  ///This method is used to get the instance of this class.
  factory SoundManager() => _instance;

  SoundManager._internal();

  /// Who rings when a host plays [Sound.incomingCall] on a loop itself.
  static final Object _hostRingtone = Object();

  /// Plays [sound], or [customSound] from [packageName]'s assets.
  ///
  /// [Sound.incomingCall] rings as an incoming call: on the incoming
  /// ringtone's own player, with the vibration, following the phone's ring
  /// settings as the incoming call banner does (see
  /// `CometChatIncomingCall.disableSoundForCalls`). For it, [customSound] is
  /// looked for in [packageName]'s assets, then in the app's own, and the
  /// UI Kit's ringtone plays when it is not found. It plays once unless
  /// [isLooping].
  ///
  /// Every other sound plays on the message sounds' player, as before 6.2.0:
  /// [packageName] is not used to find a [customSound] there, and on iOS the
  /// UI Kit's own message and call sounds may not be found.
  ///
  /// While an incoming call rings, the sounds that play once are skipped,
  /// not queued: the message sounds, and a one-shot [Sound.incomingCall].
  /// On one shared player they used to replace the ringtone for good, and a
  /// ding over a ringing phone helps no one. A looping sound still plays (a
  /// looping [Sound.incomingCall] takes the ringtone over). This holds with
  /// the phone in Silent or Vibrate mode too, and it does not apply while a
  /// banner rings with `disableSoundForCalls`: it rings nothing.
  void play({
    required Sound sound,
    String? customSound,
    String? packageName, // Use it only when using other plugin
    bool? isLooping = false,
  }) async {
    if (kIsWeb) return;

    if (sound == Sound.incomingCall) {
      // A one-shot ringtone over an incoming call ringing now would replace
      // its looping ringtone on the one native player, for good, and its
      // end would give the audio back while the call still rang.
      if (isLooping != true && IncomingRingtone.isRinging) {
        ccLog('SoundManager: $sound not played, an incoming call is ringing');
        return;
      }
      final bool custom = customSound != null && customSound.isNotEmpty;
      await IncomingRingtone.play(
        assetPath: customSound,
        package: custom ? packageName : null,
        looping: isLooping == true,
        // A ringtone that plays once rings no one's phone for long: only a
        // looping one holds the message sounds back.
        owner: isLooping == true ? _hostRingtone : null,
      );
      return;
    }

    if (isLooping != true && IncomingRingtone.isRinging) {
      ccLog('SoundManager: $sound not played, an incoming call is ringing');
      return;
    }

    String soundPath = "";

    if (customSound != null && customSound.isNotEmpty) {
      soundPath = customSound;
    } else {
      soundPath = _getDefaultSoundPath(sound);
      packageName ??= UIConstants.packageName;
      if (platform.platformIsAndroid()) {
        soundPath = "packages/$packageName/$soundPath";
      }
    }
    try {
      await UIConstants.channel.invokeMethod("playCustomSound", {
        'assetAudioPath': soundPath,
        'package': packageName,
        'isLooping': isLooping,
      });
    } catch (e) {
      if (e.toString().contains('AUDIO_FOCUS_FAILED')) {
        ccLog('Audio focus not available. Notification sound skipped.');
      } else {
        ccLog('Error playing sound: $e');
      }
    }
  }

  /// Stops what the UI Kit is playing: a message sound, the incoming
  /// call's ringtone (and its vibration), and the outgoing call's ringback.
  /// Since 6.2.0 the ringtone and the ringback play on players of their own,
  /// but they still stop here, as they did before. An `onCancelled` that
  /// takes an outgoing call's End over can stop the ringback with it.
  ///
  /// An incoming call's `onAccept` and `onDecline` need not call it: the
  /// UI Kit stops the ringtone at the tap. Calling it there does harm: at
  /// Accept it gives the audio back while the call connects (music resumes
  /// during "Connecting..."), and at Decline it also stops the ringback of
  /// a call the user is placing.
  ///
  /// The UI Kit's own call screens do not call this: each stops only the
  /// sound it started, so one closing cannot silence the next call's.
  void stop() async {
    if (kIsWeb) return;
    unawaited(CallTone.stopAll());
    unawaited(IncomingRingtone.stopAll());
    await UIConstants.channel.invokeMethod("stopPlayer", {});
  }

  String _getDefaultSoundPath(Sound sound) {
    String soundType = "assets/beep.mp3";
    switch (sound) {
      case Sound.incomingMessage:
        soundType = "assets/sound/incoming_message.wav";
        break;
      case Sound.outgoingMessage:
        soundType = "assets/sound/outgoing_message.wav";
        break;
      case Sound.incomingMessageFromOther:
        soundType = "assets/sound/incoming_message.wav";
        break;
      case Sound.outgoingCall:
        soundType = "assets/sound/outgoing_call.wav";
        break;
      case Sound.incomingCall:
        soundType = "assets/sound/incoming_call.wav";
        break;
    }

    return soundType;
  }
}

enum Sound {
  incomingMessage,
  outgoingMessage,
  incomingMessageFromOther,
  outgoingCall,
  incomingCall,
}
