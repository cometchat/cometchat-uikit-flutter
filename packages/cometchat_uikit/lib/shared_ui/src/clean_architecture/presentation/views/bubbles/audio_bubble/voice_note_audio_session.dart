import 'package:flutter/foundation.dart';

import '../../../../../../../call_ui/src/utils/call_state_service.dart';
import '../../../../../logging/cometchat_log.dart';
import '../../../../core/constants/ui_kit_constants.dart';
import '../../../../core/utils/platform_utils/platform_file_utils.dart'
    as platform;

/// Lends the iOS audio session to a voice note for as long as it plays.
///
/// iOS has one audio session per app, shared with calls. After recording, it
/// is left in play-and-record, which sends playback to the earpiece — so the
/// sender's own voice note sounded like nothing played (ENG-39489). Routing it
/// to the loudspeaker fixes that, but the change is global: it used to be made
/// whenever a voice note bubble was built, left in place afterwards, and a
/// received voice note forced playback-only (no microphone). A chat with a
/// voice note in it was enough to leave the next call without audio.
///
/// So the session is changed only while a voice note is actually playing,
/// handed back when it pauses, stops, finishes or is disposed, and never
/// touched during a call. Only one voice note plays at a time; the one that
/// changed the session is the only one that restores it.
class VoiceNoteAudioSession {
  VoiceNoteAudioSession._();

  /// Whether the session needs handling here. Only iOS routes a
  /// play-and-record session to the earpiece; Android's plugin does not
  /// implement these calls. Replaceable for tests.
  @visibleForTesting
  static bool Function() isIOS = () => !kIsWeb && platform.platformIsIOS();

  /// Whether a call is in progress, in which case the call owns the session.
  /// Replaceable for tests.
  @visibleForTesting
  static bool Function() isCallActive = () =>
      CallStateService.instance.isActiveCall.value;

  /// The voice note that changed the session and has not handed it back.
  static int? _owner;

  /// Routes playback to the loudspeaker for the voice note [id] about to play.
  static Future<void> takeForSpeaker(int id) async {
    if (!isIOS() || isCallActive()) return;
    try {
      final changed = await UIConstants.channel.invokeMethod<bool>(
        'setAudioSessionToSpeaker',
      );
      if (changed == true) _owner = id;
    } catch (e) {
      ccLog('VoiceNoteAudioSession: could not route to the speaker: $e');
    }
  }

  /// Hands the session back to what it was, if voice note [id] changed it.
  static Future<void> release(int id) async {
    if (_owner != id) return;
    _owner = null;
    try {
      await UIConstants.channel.invokeMethod<bool>('restoreAudioSession');
    } catch (e) {
      ccLog('VoiceNoteAudioSession: could not restore the session: $e');
    }
  }

  /// Forgets any owner without touching the session. For tests.
  @visibleForTesting
  static void reset() => _owner = null;
}
