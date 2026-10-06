/// Voice notes must not leave the iOS audio session changed — it is shared
/// with calls.
///
/// Making the speaker-routing call reach iOS (ENG-39489) turned on code that
/// had never run: every voice note bubble switched the session as soon as it
/// was built — a received one to playback-only, which has no microphone —
/// and nothing switched it back. A chat with a voice note in it was enough to
/// leave the next call without audio.
///
///   flutter test test/shared_ui/bubbles/voice_note_audio_session_test.dart
library;

import 'dart:io';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show AudioBubbleState;
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/constants/ui_kit_constants.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/presentation/views/bubbles/audio_bubble/voice_note_audio_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<String> sessionCalls;
  late bool nativeChanges;

  setUp(() {
    sessionCalls = [];
    nativeChanges = true;
    VoiceNoteAudioSession.reset();
    VoiceNoteAudioSession.isIOS = () => true;
    VoiceNoteAudioSession.isCallActive = () => false;
    messenger.setMockMethodCallHandler(UIConstants.channel, (call) async {
      sessionCalls.add(call.method);
      return nativeChanges;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(UIConstants.channel, null);
    VoiceNoteAudioSession.reset();
  });

  group('building a voice note bubble', () {
    test('a received voice note does not touch the session', () async {
      final state = AudioBubbleState(
        id: 1,
        audioUrl: 'https://example.com/voice.m4a',
        localPath: null,
      );
      await state.initializeController();

      expect(sessionCalls, isEmpty);
      state.dispose();
      expect(sessionCalls, isEmpty);
    });

    test('your own voice note does not touch the session', () async {
      final dir = await Directory.systemTemp.createTemp('voice_note');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/own.m4a')..writeAsBytesSync([0, 1, 2]);

      final state = AudioBubbleState(
        id: 2,
        audioUrl: null,
        localPath: file.path,
      );
      await state.initializeController();

      expect(sessionCalls, isEmpty);
      state.dispose();
      expect(sessionCalls, isEmpty);
    });
  });

  group('playing a voice note', () {
    test('routes to the speaker, then restores once', () async {
      await VoiceNoteAudioSession.takeForSpeaker(1);
      await VoiceNoteAudioSession.release(1);
      await VoiceNoteAudioSession.release(1);

      expect(sessionCalls, ['setAudioSessionToSpeaker', 'restoreAudioSession']);
    });

    test('only the voice note that changed the session restores it', () async {
      // Tapping play on a second voice note pauses the first; its restore
      // lands after the second has taken the session and must not undo it.
      await VoiceNoteAudioSession.takeForSpeaker(1);
      await VoiceNoteAudioSession.takeForSpeaker(2);
      await VoiceNoteAudioSession.release(1);
      expect(sessionCalls, [
        'setAudioSessionToSpeaker',
        'setAudioSessionToSpeaker',
      ]);

      await VoiceNoteAudioSession.release(2);
      expect(sessionCalls.last, 'restoreAudioSession');
      expect(
        sessionCalls.where((m) => m == 'restoreAudioSession'),
        hasLength(1),
      );
    });

    test('never touches the session during a call', () async {
      VoiceNoteAudioSession.isCallActive = () => true;

      await VoiceNoteAudioSession.takeForSpeaker(1);
      await VoiceNoteAudioSession.release(1);

      expect(sessionCalls, isEmpty);
    });

    test('a session iOS left alone is not restored', () async {
      // iOS refuses when a call is already using the session.
      nativeChanges = false;

      await VoiceNoteAudioSession.takeForSpeaker(1);
      await VoiceNoteAudioSession.release(1);

      expect(sessionCalls, ['setAudioSessionToSpeaker']);
    });

    test('does nothing off iOS', () async {
      VoiceNoteAudioSession.isIOS = () => false;

      await VoiceNoteAudioSession.takeForSpeaker(1);
      await VoiceNoteAudioSession.release(1);

      expect(sessionCalls, isEmpty);
    });
  });
}
