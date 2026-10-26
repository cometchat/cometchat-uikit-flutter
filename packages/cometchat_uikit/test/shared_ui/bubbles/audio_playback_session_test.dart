/// Audio messages must be heard after a call.
///
/// After a call the iOS audio session was left as the call or its tones had
/// it, and an audio file or a received voice note played there was not heard
/// until the app restarted: their player only sets the session once, when it
/// is first used. The session is now readied for playback right before each
/// one plays, except during a call, which owns it.
///
///   flutter test test/shared_ui/bubbles/audio_playback_session_test.dart
library;

import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/constants/ui_kit_constants.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/presentation/views/bubbles/audio_bubble/audio_playback_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<String> sessionCalls;
  late Object? Function() nativeReply;

  setUp(() {
    sessionCalls = [];
    nativeReply = () => true;
    AudioPlaybackSession.isIOS = () => true;
    AudioPlaybackSession.isCallActive = () => false;
    messenger.setMockMethodCallHandler(UIConstants.channel, (call) async {
      sessionCalls.add(call.method);
      return nativeReply();
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(UIConstants.channel, null);
  });

  test(
    'readies the session for playback before an audio message plays',
    () async {
      await AudioPlaybackSession.prepare();

      expect(sessionCalls, ['prepareAudioSessionForPlayback']);
    },
  );

  test('leaves the session to a call that is on', () async {
    AudioPlaybackSession.isCallActive = () => true;

    await AudioPlaybackSession.prepare();

    expect(sessionCalls, isEmpty);
  });

  test('does nothing off iOS', () async {
    AudioPlaybackSession.isIOS = () => false;

    await AudioPlaybackSession.prepare();

    expect(sessionCalls, isEmpty);
  });

  test('a native failure does not stop the audio message playing', () async {
    nativeReply = () => throw PlatformException(code: 'AUDIO_SESSION_ERROR');

    await expectLater(AudioPlaybackSession.prepare(), completes);
    expect(sessionCalls, ['prepareAudioSessionForPlayback']);
  });
}
