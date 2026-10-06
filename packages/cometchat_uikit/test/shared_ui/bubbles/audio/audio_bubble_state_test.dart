/// Behavioural tests for the audio playback state machine shared by the
/// voice-note bubble, the audio player and the staged-recording tiles
/// (`cometchat_audio_bubble_controller.dart`).
///
/// `video_player` has no implementation in a VM test, so these install a
/// scriptable [FakeVideoPlayerPlatform] (see `test/helpers`) and drive the real
/// [AudioBubbleState] against it: which data source it opens, what it does on
/// play / pause / stop / seek, what it broadcasts on its state stream, and how
/// it recovers from a player that fails or never answers.
library;

import 'dart:async';
import 'dart:io';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_video_player_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlayerPlatform platform;
  late Directory tempDir;

  setUp(() {
    platform = installFakeVideoPlayerPlatform();
    tempDir = Directory.systemTemp.createTempSync('cc_audio_state_test');
    AudioStateManager().clearAll();
  });

  tearDown(() {
    AudioStateManager().clearAll();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A real file on disk, so `fileExistsSync` in the Kit answers true.
  String writeLocalAudio(String name) {
    final file = File('${tempDir.path}/$name')
      ..writeAsBytesSync(<int>[1, 2, 3]);
    return file.path;
  }

  AudioBubbleState state({
    int id = 1,
    String? audioUrl = 'https://files.invalid/clip.m4a',
    String? localPath,
  }) {
    return AudioBubbleState(id: id, audioUrl: audioUrl, localPath: localPath);
  }

  group('initializeController — source selection', () {
    test('opens the network url when there is no local file', () async {
      final s = state();
      await s.initializeController();

      expect(platform.createdUris, ['https://files.invalid/clip.m4a']);
      expect(s.controller?.value.isInitialized, isTrue);
      expect(s.totalDuration, const Duration(seconds: 30));
      expect(s.isInitializing, isFalse);

      s.dispose();
    });

    test('prefers an existing local file over the network url', () async {
      final path = writeLocalAudio('clip.m4a');
      final s = state(localPath: path);
      await s.initializeController();

      expect(platform.createdUris.single, 'file://$path');

      s.dispose();
    });

    test('falls back to the network url when the local path is missing '
        'from disk', () async {
      final s = state(localPath: '${tempDir.path}/never-written.m4a');
      await s.initializeController();

      expect(platform.createdUris.single, 'https://files.invalid/clip.m4a');

      s.dispose();
    });

    test(
      'opens nothing, and stops initializing, with no source at all',
      () async {
        final s = state(audioUrl: null);
        final updates = <AudioStateUpdate>[];
        final sub = s.stateStream.listen(updates.add);

        await s.initializeController();
        await pumpEventQueue();

        expect(platform.createdUris, isEmpty);
        expect(s.controller, isNull);
        expect(s.isInitializing, isFalse);
        // It still announces the attempt and its abandonment, so a bubble that
        // put up a spinner on the first update takes it down again.
        expect(updates.first.isInitializing, isTrue);
        expect(updates.last.isInitializing, isFalse);

        await sub.cancel();
        s.dispose();
      },
    );

    test('an empty audio url counts as no source', () async {
      final s = state(audioUrl: '');
      await s.initializeController();

      expect(platform.createdUris, isEmpty);
      expect(s.controller, isNull);

      s.dispose();
    });
  });

  group('initializeController — re-entrancy', () {
    test(
      'returns immediately when the controller is already initialized',
      () async {
        final s = state();
        await s.initializeController();
        await s.initializeController();

        expect(platform.createdUris, hasLength(1));

        s.dispose();
      },
    );

    test('concurrent callers share one initialization', () async {
      final s = state();
      await Future.wait<void>([
        s.initializeController(),
        s.initializeController(),
        s.initializeController(),
      ]);

      expect(
        platform.createdUris,
        hasLength(1),
        reason: 'the in-flight completer must absorb the extra calls',
      );
      expect(s.isInitializing, isFalse);

      s.dispose();
    });
  });

  group('initializeController — failure paths', () {
    test(
      'a player that cannot be created leaves no controller behind',
      () async {
        platform.failCreate = true;
        final s = state();
        final updates = <AudioStateUpdate>[];
        final sub = s.stateStream.listen(updates.add);

        await s.initializeController();
        await pumpEventQueue();

        expect(s.controller, isNull);
        expect(s.isInitializing, isFalse);
        expect(s.totalDuration, isNull);
        expect(updates.last.isInitializing, isFalse);

        await sub.cancel();
        s.dispose();
      },
    );

    test('a player that opens but reports no media is torn down', () async {
      platform.initializeWithoutDuration = true;
      final s = state();

      await s.initializeController();
      await pumpEventQueue();

      expect(
        s.controller,
        isNull,
        reason: 'an un-initialized controller must not be kept',
      );
      expect(s.totalDuration, isNull);
      expect(s.isInitializing, isFalse);
      expect(platform.log, contains('dispose:1'));

      s.dispose();
    });

    testWidgets('a player that never answers times out and is retried exactly '
        'once', (tester) async {
      platform.hangInitialize = true;
      final s = state();

      unawaited(s.initializeController());
      // First attempt: 6s deadline, then one retry with the same deadline.
      await tester.pump(const Duration(seconds: 7));
      expect(
        platform.createdUris,
        hasLength(2),
        reason: 'the timeout triggers exactly one retry',
      );
      await tester.pump(const Duration(seconds: 7));
      expect(
        platform.createdUris,
        hasLength(2),
        reason: 'the retry does not recurse again on a second timeout',
      );

      expect(s.controller, isNull, reason: 'the wedged player is dropped');
      expect(s.isInitializing, isFalse);

      s.dispose();
    });
  });

  group('playback', () {
    test('playAudio initializes lazily, then plays', () async {
      final s = state();
      expect(s.playState, PlayStates.init);

      await s.playAudio();

      expect(s.playState, PlayStates.playing);
      expect(platform.log, contains('play:1'));

      s.dispose();
    });

    test('playAudio reports stopped when the player cannot be built', () async {
      platform.failCreate = true;
      final s = state();

      await s.playAudio();

      expect(s.playState, PlayStates.stopped);
      expect(platform.log.where((e) => e.startsWith('play:')), isEmpty);

      s.dispose();
    });

    test('a player that refuses to start falls back to stopped', () async {
      final s = state();
      await s.initializeController();
      platform.failPlay = true;

      await s.playAudio();

      expect(
        s.playState,
        PlayStates.stopped,
        reason: 'a throwing play() must not leave the bubble showing "playing"',
      );

      s.dispose();
    });

    test('pauseAudio pauses an initialized player and nothing else', () async {
      final s = state();
      await s.playAudio();
      platform.log.clear();

      await s.pauseAudio();
      expect(s.playState, PlayStates.paused);
      expect(platform.log, contains('pause:1'));

      // An un-initialized state is a no-op rather than an error.
      final never = state(id: 2, audioUrl: null);
      await never.pauseAudio();
      expect(never.playState, PlayStates.init);

      s.dispose();
      never.dispose();
    });

    test('stopAudio pauses, rewinds to zero and clears the position', () async {
      final s = state();
      await s.playAudio();
      await s.seekTo(const Duration(seconds: 12));
      expect(s.currentPosition, const Duration(seconds: 12));
      platform.log.clear();

      await s.stopAudio();

      expect(s.playState, PlayStates.stopped);
      expect(s.currentPosition, Duration.zero);
      expect(platform.log, ['pause:1', 'seek:1:0:00:00.000000']);

      s.dispose();
    });

    test('reaching the end of the media stops playback', () async {
      final s = state();
      await s.playAudio();
      expect(s.playState, PlayStates.playing);

      platform.completePlayback();
      await pumpEventQueue();

      expect(
        s.playState,
        PlayStates.stopped,
        reason: 'the controller listener turns completion into a stop',
      );
      expect(s.currentPosition, Duration.zero);

      s.dispose();
    });
  });

  group('seeking and progress', () {
    test('seekTo moves the player and the reported position', () async {
      final s = state();
      await s.initializeController();

      await s.seekTo(const Duration(seconds: 9));

      expect(s.currentPosition, const Duration(seconds: 9));
      expect(platform.log, contains('seek:1:0:00:09.000000'));

      s.dispose();
    });

    test(
      'seekTo on a state with no player leaves the position alone',
      () async {
        final s = state(audioUrl: null);
        await s.seekTo(const Duration(seconds: 9));

        expect(s.currentPosition, Duration.zero);

        s.dispose();
      },
    );

    test(
      'seekToProgress maps a fraction onto the duration and clamps it',
      () async {
        final s = state();
        await s.initializeController();

        await s.seekToProgress(0.5);
        expect(s.currentPosition, const Duration(seconds: 15));

        await s.seekToProgress(2.0);
        expect(s.currentPosition, const Duration(seconds: 30));

        await s.seekToProgress(-1.0);
        expect(s.currentPosition, Duration.zero);

        s.dispose();
      },
    );

    test('playbackProgress is the position over the duration, and 0 with no '
        'duration', () async {
      final s = state();
      expect(s.playbackProgress, 0.0);

      await s.initializeController();
      await s.seekTo(const Duration(seconds: 15));
      expect(s.playbackProgress, closeTo(0.5, 1e-9));

      await s.seekTo(const Duration(seconds: 45));
      expect(
        s.playbackProgress,
        1.0,
        reason: 'a position past the end still reads as fully played',
      );

      s.dispose();
    });

    test('a zero-length recording reports no progress rather than dividing by '
        'zero', () async {
      platform.duration = Duration.zero;
      final s = state();
      await s.initializeController();

      expect(s.totalDuration, Duration.zero);
      expect(s.playbackProgress, 0.0);

      s.dispose();
    });
  });

  group('state stream', () {
    test('every transition is broadcast with the current snapshot', () async {
      final s = state();
      final updates = <AudioStateUpdate>[];
      final sub = s.stateStream.listen(updates.add);

      await s.playAudio();
      await s.pauseAudio();
      await pumpEventQueue();

      expect(updates.first.id, 1);
      expect(updates.map((u) => u.playState), contains(PlayStates.playing));
      expect(updates.last.playState, PlayStates.paused);
      expect(updates.last.totalDuration, const Duration(seconds: 30));

      await sub.cancel();
      s.dispose();
    });

    test('a disposed state stops broadcasting instead of throwing', () async {
      final s = state();
      await s.initializeController();
      s.dispose();

      // pauseAudio on the disposed state must not add to the closed stream.
      await expectLater(s.pauseAudio(), completes);
    });
  });

  group('updateLocalPath', () {
    test(
      'swaps the source, drops the live player and resets to init',
      () async {
        final s = state();
        await s.playAudio();
        expect(s.playState, PlayStates.playing);
        final newPath = writeLocalAudio('replacement.m4a');

        s.updateLocalPath(newPath);
        await pumpEventQueue();

        expect(s.localPath, newPath);
        expect(s.playState, PlayStates.init);
        expect(s.controller, isNull);
        expect(platform.log, contains('dispose:1'));

        // The next init opens the new local file, not the old network url.
        await s.initializeController();
        expect(platform.createdUris.last, 'file://$newPath');

        s.dispose();
      },
    );
  });

  group('AudioStateManager', () {
    test('returns one state per id and reuses it', () {
      final a = AudioStateManager().getAudioState(7, 'https://a.invalid/x', '');
      final b = AudioStateManager().getAudioState(7, 'https://a.invalid/x', '');

      expect(identical(a, b), isTrue);
    });

    test(
      'a later non-empty local path is pushed into the cached state',
      () async {
        final s = AudioStateManager().getAudioState(
          7,
          'https://a.invalid/x',
          '',
        );
        await s.playAudio();
        final path = writeLocalAudio('late.m4a');

        final again = AudioStateManager().getAudioState(
          7,
          'https://a.invalid/x',
          path,
        );

        expect(identical(again, s), isTrue);
        expect(again.localPath, path);
        expect(
          again.playState,
          PlayStates.init,
          reason: 'the new source resets playback',
        );
      },
    );

    test(
      'an empty or null local path leaves the cached state untouched',
      () async {
        final s = AudioStateManager().getAudioState(
          7,
          'https://a.invalid/x',
          '',
        );
        await s.playAudio();

        AudioStateManager().getAudioState(7, 'https://a.invalid/x', '');
        expect(s.playState, PlayStates.playing);

        AudioStateManager().getAudioState(7, 'https://a.invalid/x', null);
        expect(s.playState, PlayStates.playing);
      },
    );

    test('pauseAllExcept pauses every other player', () async {
      final a = AudioStateManager().getAudioState(1, 'https://a.invalid/1', '');
      final b = AudioStateManager().getAudioState(2, 'https://a.invalid/2', '');
      await a.initializeController();
      await b.playAudio();
      expect(b.playState, PlayStates.playing);

      // Excluding the playing one leaves it alone…
      AudioStateManager().pauseAllExcept(2);
      await pumpEventQueue();
      expect(b.playState, PlayStates.playing);

      // …excluding the other one pauses it.
      AudioStateManager().pauseAllExcept(1);
      await pumpEventQueue();
      expect(b.playState, PlayStates.paused);
      expect(a.playState, PlayStates.paused);
    });

    test('playAudio pauses every other cached player — only one plays at a '
        'time', () async {
      final a = AudioStateManager().getAudioState(1, 'https://a.invalid/1', '');
      final b = AudioStateManager().getAudioState(2, 'https://a.invalid/2', '');
      await a.playAudio();
      await b.playAudio();
      await pumpEventQueue();

      expect(a.playState, PlayStates.paused);
      expect(b.playState, PlayStates.playing);
    });

    test('stopAllAudio stops every player', () async {
      final a = AudioStateManager().getAudioState(1, 'https://a.invalid/1', '');
      final b = AudioStateManager().getAudioState(2, 'https://a.invalid/2', '');
      await a.playAudio();
      await b.playAudio();

      AudioStateManager().stopAllAudio();
      await pumpEventQueue();

      expect(a.playState, PlayStates.stopped);
      expect(b.playState, PlayStates.stopped);
    });

    test('removeAudioState disposes the player and forgets the id', () async {
      final a = AudioStateManager().getAudioState(1, 'https://a.invalid/1', '');
      await a.initializeController();

      AudioStateManager().removeAudioState(1);
      await pumpEventQueue();

      expect(platform.log, contains('dispose:1'));
      final fresh = AudioStateManager().getAudioState(
        1,
        'https://a.invalid/1',
        '',
      );
      expect(
        identical(fresh, a),
        isFalse,
        reason: 'the id is free again after removal',
      );
    });

    test('removeAudioState on an unknown id is a no-op', () {
      expect(() => AudioStateManager().removeAudioState(999), returnsNormally);
    });

    test('clearAll disposes every player and empties the cache', () async {
      final a = AudioStateManager().getAudioState(1, 'https://a.invalid/1', '');
      final b = AudioStateManager().getAudioState(2, 'https://a.invalid/2', '');
      await a.initializeController();
      await b.initializeController();

      AudioStateManager().clearAll();
      await pumpEventQueue();

      expect(platform.log, containsAll(<String>['dispose:1', 'dispose:2']));
      expect(
        identical(
          AudioStateManager().getAudioState(1, 'https://a.invalid/1', ''),
          a,
        ),
        isFalse,
      );
    });
  });
}
