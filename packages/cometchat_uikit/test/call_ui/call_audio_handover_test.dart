/// What becomes of the audio the ringback or the ringtone handed to the call
/// screen (round 4; the round 2 review's C9): given back when the call never
/// joined, forgotten once it did. The native side is a device check; here,
/// what reaches the UI Kit's channel.
///
///   flutter test test/call_ui/call_audio_handover_test.dart
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/src/call_audio_handover.dart';

import 'helpers/call_bloc_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SoundChannelSpy.install);
  tearDown(() {
    SoundChannelSpy.remove();
    debugDefaultTargetPlatformOverride = null;
  });

  Map<Object?, Object?>? lastRelease() =>
      SoundChannelSpy.lastArgumentsOf('releaseHandedOverCallAudio');

  for (final TargetPlatform platform in <TargetPlatform>[
    TargetPlatform.android,
    TargetPlatform.iOS,
  ]) {
    test('${platform.name}: restore asks for the audio back', () async {
      debugDefaultTargetPlatformOverride = platform;
      await CallAudioHandover.restore();
      expect(lastRelease(), <Object?, Object?>{'restore': true});
    });

    test('${platform.name}: forget only drops what was handed over', () async {
      debugDefaultTargetPlatformOverride = platform;
      await CallAudioHandover.forget();
      expect(lastRelease(), <Object?, Object?>{'restore': false});
    });
  }

  test('elsewhere nothing is asked', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await CallAudioHandover.restore();
    expect(SoundChannelSpy.methods, isEmpty);
  });

  test('a native side without the method fails quietly', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('cometchat_chat_uikit'),
          (MethodCall call) async => throw MissingPluginException(),
        );
    await expectLater(CallAudioHandover.restore(), completes);
  });
}
