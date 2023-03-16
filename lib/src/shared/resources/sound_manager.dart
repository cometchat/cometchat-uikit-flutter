import 'dart:io' show Platform;

import '../../../flutter_chat_ui_kit.dart';

class SoundManager {
  static play(
      {required Sound sound,
      String? customSound,
      String? packageName // Use it only when using other plugin
      }) async {
    String _soundPath = "";

    if (customSound != null && customSound.isNotEmpty) {
      _soundPath = customSound;

      if (Platform.isAndroid && packageName != null && packageName.isNotEmpty) {
        _soundPath = "packages/$packageName/" + _soundPath;
      }
    } else {
      _soundPath = _getDefaultSoundPath(sound);
      packageName ??= UIConstants.packageName;
      if (Platform.isAndroid) {
        //if (packageName != null && packageName.isNotEmpty) {
        _soundPath = "packages/$packageName/" + _soundPath;
        // } else {
        //   _soundPath = "packages/${UIConstants.packageName}/" + _soundPath;
        // }
      }
    }

    await UIConstants.channel.invokeMethod("playCustomSound",
        {'assetAudioPath': _soundPath, 'package': packageName});
  }

  static String _getDefaultSoundPath(Sound sound) {
    String _soundType = "assets/beep.mp3";
    switch (sound) {
      case Sound.incomingMessage:
        _soundType = "assets/sound/incoming_message.wav";
        break;
      case Sound.outgoingMessage:
        _soundType = "assets/sound/outgoing_message.wav";
        break;
      case Sound.incomingMessageFromOther:
        _soundType = "assets/sound/incoming_message.wav";
        break;
      default:
        _soundType = "assets/beep.mp3";
        break;
    }

    return _soundType;
  }
}

enum Sound { incomingMessage, outgoingMessage, incomingMessageFromOther }
