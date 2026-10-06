/// The call tone's Dart side (round 2, P2-C12): what it asks the native
/// player for, where it does nothing, and that no platform failure reaches
/// the call that plays it.
///
///   flutter test test/call_ui/call_tone_test.dart
library;

import 'package:cometchat_chat_uikit/src/call_tone.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _channel = MethodChannel('cometchat_chat_uikit');

/// Invocations the channel received, in order.
final List<MethodCall> _calls = <MethodCall>[];

/// Answers the kit's channel, recording each call; [answer] decides what
/// comes back (or throws).
void _install([Future<Object?> Function(MethodCall call)? answer]) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (MethodCall call) async {
        _calls.add(call);
        return answer == null ? null : answer(call);
      });
}

Map<Object?, Object?>? _argsOf(String method) =>
    _calls.lastWhere((MethodCall c) => c.method == method).arguments
        as Map<Object?, Object?>?;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _calls.clear();
    _install();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    CallTone.isWeb = kIsWeb;
    debugDefaultTargetPlatformOverride = null;
    CallTone.debugReset();
  });

  group('what the native player is asked for', () {
    test('a host sound, its package and the call type go through', () async {
      await CallTone.play(
        assetPath: 'sounds/ring.mp3',
        package: 'host_sounds',
        isVideo: true,
      );

      expect(_calls.map((MethodCall c) => c.method), <String>['playCallTone']);
      expect(_argsOf('playCallTone'), <String, Object?>{
        'assetPath': 'sounds/ring.mp3',
        'package': 'host_sounds',
        'isVideo': true,
        'fallbackAssetPath': 'assets/sound/outgoing_call.wav',
        'fallbackPackage': 'cometchat_chat_uikit',
      });
    });

    test('a host sound with no package is looked up in the app', () async {
      await CallTone.play(assetPath: 'sounds/ring.mp3', isVideo: false);

      expect(_argsOf('playCallTone'), <String, Object?>{
        'assetPath': 'sounds/ring.mp3',
        'package': null,
        'isVideo': false,
        'fallbackAssetPath': 'assets/sound/outgoing_call.wav',
        'fallbackPackage': 'cometchat_chat_uikit',
      });
    });

    test('with no host sound, the kit\'s ringback plays from the kit\'s own '
        'package, whatever package was named', () async {
      await CallTone.play(package: 'host_sounds', isVideo: false);

      expect(_argsOf('playCallTone'), <String, Object?>{
        'assetPath': 'assets/sound/outgoing_call.wav',
        'package': 'cometchat_chat_uikit',
        'isVideo': false,
        'fallbackAssetPath': 'assets/sound/outgoing_call.wav',
        'fallbackPackage': 'cometchat_chat_uikit',
      });
    });

    test('the kit\'s ringback goes along as the fallback for a host sound '
        'that cannot be found (round 2 review)', () async {
      await CallTone.play(
        assetPath: 'sounds/ring.mp3',
        package: 'my_app',
        isVideo: false,
      );

      final Map<Object?, Object?>? args = _argsOf('playCallTone');
      expect(args?['assetPath'], 'sounds/ring.mp3');
      expect(args?['package'], 'my_app');
      expect(args?['fallbackAssetPath'], CallTone.defaultAsset);
      expect(args?['fallbackPackage'], 'cometchat_chat_uikit');
    });

    test('stop gives the audio back', () async {
      await CallTone.stop();
      expect(_argsOf('stopCallTone'), <String, Object?>{
        'handover': false,
        'keepAudio': false,
      });
    });

    test('iOS gets the same calls as Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await CallTone.play(isVideo: false);
      await CallTone.stop();

      expect(_calls.map((MethodCall c) => c.method), <String>[
        'playCallTone',
        'stopCallTone',
      ]);
    });
  });

  group('only who started the tone stops it (round 2, P3-C15)', () {
    final Object first = Object();
    final Object second = Object();

    List<String> methods() => _calls.map((MethodCall c) => c.method).toList();

    test('a stop naming someone else leaves the tone playing', () async {
      await CallTone.play(isVideo: false, owner: first);
      await CallTone.stop(owner: second);

      expect(methods(), <String>['playCallTone']);

      await CallTone.stop(owner: first);
      expect(methods(), <String>['playCallTone', 'stopCallTone']);
    });

    test(
      'the next call\'s tone is not stopped by the call before it',
      () async {
        await CallTone.play(isVideo: false, owner: first);
        await CallTone.play(isVideo: true, owner: second);
        await CallTone.stop(owner: first);

        expect(methods(), <String>['playCallTone', 'playCallTone']);

        await CallTone.stop(owner: second);
        expect(methods().last, 'stopCallTone');
      },
    );

    test('an owner stops its tone once', () async {
      await CallTone.play(isVideo: false, owner: first);
      await CallTone.stop(owner: first);
      await CallTone.stop(owner: first);

      expect(methods(), <String>['playCallTone', 'stopCallTone']);
    });
  });

  // Round 2 review, the accept hand-over: the callee answering stops only
  // the playback, the call screen takes the audio over, and an accept that
  // opens no call screen gives it back.
  group('the accept hand-over (round 2 review)', () {
    final Object owner = Object();
    final Object someoneElse = Object();

    List<Object?> stops() => _calls
        .where((MethodCall c) => c.method == 'stopCallTone')
        .map((MethodCall c) => c.arguments)
        .toList();

    const Map<String, Object?> keep = <String, Object?>{
      'handover': false,
      'keepAudio': true,
    };
    const Map<String, Object?> handover = <String, Object?>{
      'handover': true,
      'keepAudio': false,
    };
    const Map<String, Object?> release = <String, Object?>{
      'handover': false,
      'keepAudio': false,
    };

    test('pause keeps the audio, and the tone stays its owner\'s: a hand-over '
        'follows, and nothing after it', () async {
      await CallTone.play(isVideo: false, owner: owner);
      await CallTone.pause(owner: owner);
      await CallTone.handOver(owner: owner);
      await CallTone.stop(owner: owner);

      expect(stops(), <Object?>[keep, handover]);
    });

    test('an accept that opens no call screen gives the audio back', () async {
      await CallTone.play(isVideo: false, owner: owner);
      await CallTone.pause(owner: owner);
      await CallTone.stop(owner: owner);
      await CallTone.handOver(owner: owner);

      expect(stops(), <Object?>[keep, release]);
    });

    test('only the owner pauses or hands over', () async {
      await CallTone.play(isVideo: false, owner: owner);
      await CallTone.pause(owner: someoneElse);
      await CallTone.handOver(owner: someoneElse);

      expect(stops(), isEmpty);
    });
  });

  group('where there is no native player', () {
    test('on the web it does nothing', () async {
      CallTone.isWeb = true;

      await CallTone.play(isVideo: true);
      await CallTone.stop();

      expect(_calls, isEmpty);
    });

    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      test('on ${platform.name} it does nothing', () async {
        debugDefaultTargetPlatformOverride = platform;

        await CallTone.play(isVideo: false);
        await CallTone.stop();

        expect(_calls, isEmpty);
      });
    }
  });

  group('no failure reaches the caller', () {
    test('a platform with no handler (MissingPluginException)', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);

      await expectLater(CallTone.play(isVideo: false), completes);
      await expectLater(CallTone.stop(), completes);
    });

    test('a native error (PlatformException)', () async {
      _install(
        (MethodCall call) =>
            throw PlatformException(code: 'AUDIO', message: call.method),
      );

      await expectLater(CallTone.play(isVideo: true), completes);
      await expectLater(CallTone.stop(), completes);
      expect(_calls.map((MethodCall c) => c.method), <String>[
        'playCallTone',
        'stopCallTone',
      ]);
    });
  });
}
