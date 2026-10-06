/// InlineAudioRecorderBloc — the record/pause/play state machine.
///
/// The bloc owns two real `Timer.periodic`s: a 100ms duration ticker and a
/// 100ms playback poller that calls `getPlaybackStatus` on the
/// `cometchat_chat_uikit` method channel. Both are driven here — the channel
/// through a mock handler on the test binary messenger, so the native side is
/// simulated rather than skipped. Timer assertions are written as
/// "did/didn't advance" rather than exact tick counts, so wall-clock jitter
/// cannot flake them.
///
///   flutter test test/chat_ui/message_composer/inline_audio_recorder_bloc_test.dart
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/message_composer/widgets/inline_audio_recorder/inline_audio_recorder_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_composer/widgets/inline_audio_recorder/inline_audio_recorder_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_composer/widgets/inline_audio_recorder/inline_audio_recorder_state.dart';

const _channel = MethodChannel('cometchat_chat_uikit');

/// Long enough for at least two 100ms ticks.
const _twoTicks = Duration(milliseconds: 260);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final invocations = <MethodCall>[];
  Object? Function(MethodCall call)? handler;

  setUp(() {
    invocations.clear();
    handler = (_) => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          invocations.add(call);
          return handler!(call);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  InlineAudioRecorderBloc makeBloc() {
    final bloc = InlineAudioRecorderBloc();
    addTearDown(bloc.close);
    return bloc;
  }

  test('starts idle with nothing recorded', () {
    final bloc = makeBloc();
    expect(bloc.state.status, InlineAudioRecorderStatus.idle);
    expect(bloc.state.duration, Duration.zero);
    expect(bloc.state.currentPosition, Duration.zero);
    expect(bloc.state.filePath, isNull);
    expect(bloc.state.errorMessage, isNull);
    expect(bloc.state.amplitudes, isEmpty);
    expect(bloc.state.extractedWaveform, isEmpty);
    expect(bloc.state.hasRecording, isFalse);
    expect(bloc.state.isInRecordingSession, isFalse);
  });

  group('recording', () {
    test('StartRecording resets the take and runs the clock', () async {
      final bloc = makeBloc();
      // Dirty the state first so the reset is observable.
      bloc.add(const UpdateAmplitude(0.5));
      bloc.add(const RecordingError('mic busy'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.hasError, isTrue);
      expect(bloc.state.amplitudes, isNotEmpty);

      bloc.add(const StartRecording());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.status, InlineAudioRecorderStatus.recording);
      expect(bloc.state.amplitudes, isEmpty);
      expect(bloc.state.isInRecordingSession, isTrue);

      // FINDING: `_onStartRecording` asks for `filePath: null,
      // errorMessage: null`, but `InlineAudioRecorderState.copyWith` resolves
      // every field with `x ?? this.x`, so a null argument means "keep" and
      // never "clear". Starting a new take therefore inherits the previous
      // take's error text and file path. Pinning the current (wrong)
      // behaviour; the fix belongs in lib/, either as explicit-null
      // sentinels in copyWith or by emitting a fresh state here.
      expect(bloc.state.errorMessage, 'mic busy');

      await Future<void>.delayed(_twoTicks);
      expect(
        bloc.state.duration,
        greaterThan(Duration.zero),
        reason: 'the duration timer ticks while recording',
      );
    });

    test('a retry after a completed take keeps the stale file path', () async {
      final bloc = makeBloc();
      bloc.add(
        const RecordingCompleted(
          filePath: '/tmp/first.m4a',
          duration: Duration(seconds: 3),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.filePath, '/tmp/first.m4a');

      bloc.add(const StartRecording());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // FINDING (same copyWith null-means-keep defect as above): the second
      // take starts while the state still points at the first take's file.
      expect(bloc.state.filePath, '/tmp/first.m4a');
      expect(bloc.state.status, InlineAudioRecorderStatus.recording);
      expect(
        bloc.state.duration,
        Duration.zero,
        reason: 'the duration IS reset — only the nullable fields are not',
      );
    });

    test('PauseRecording freezes the duration; resume restarts it', () async {
      final bloc = makeBloc();
      bloc.add(const StartRecording());
      await Future<void>.delayed(_twoTicks);

      bloc.add(const PauseRecording());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.status, InlineAudioRecorderStatus.paused);
      final frozen = bloc.state.duration;
      expect(frozen, greaterThan(Duration.zero));

      await Future<void>.delayed(_twoTicks);
      expect(bloc.state.duration, frozen, reason: 'the clock is stopped');

      bloc.add(const ResumeRecording());
      await Future<void>.delayed(_twoTicks);
      expect(bloc.state.status, InlineAudioRecorderStatus.recording);
      expect(
        bloc.state.duration,
        greaterThan(frozen),
        reason: 'a true resume continues from where it stopped',
      );
    });

    test(
      'a fresh restart drops the duration, amplitudes and position',
      () async {
        final bloc = makeBloc();
        bloc.add(const StartRecording());
        bloc.add(const UpdateAmplitude(0.4));
        bloc.add(const UpdatePlaybackPosition(Duration(seconds: 3)));
        await Future<void>.delayed(_twoTicks);
        expect(bloc.state.duration, greaterThan(Duration.zero));

        bloc.add(const PauseRecording());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const ResumeRecording(isFreshRestart: true));
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(bloc.state.status, InlineAudioRecorderStatus.recording);
        expect(bloc.state.duration, Duration.zero);
        expect(bloc.state.amplitudes, isEmpty);
        expect(bloc.state.currentPosition, Duration.zero);
      },
    );

    test('StopRecording completes the take and stops the clock', () async {
      final bloc = makeBloc();
      bloc.add(const StartRecording());
      await Future<void>.delayed(_twoTicks);

      bloc.add(const StopRecording());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final stoppedAt = bloc.state.duration;
      expect(bloc.state.status, InlineAudioRecorderStatus.completed);
      expect(bloc.state.hasRecording, isTrue);

      await Future<void>.delayed(_twoTicks);
      expect(bloc.state.duration, stoppedAt);
    });

    test(
      'RecordingCompleted records the path and the final duration',
      () async {
        final bloc = makeBloc();
        bloc.add(const StartRecording());
        await Future<void>.delayed(const Duration(milliseconds: 20));

        bloc.add(
          const RecordingCompleted(
            filePath: '/tmp/take.m4a',
            duration: Duration(seconds: 12),
          ),
        );
        await Future<void>.delayed(_twoTicks);

        expect(bloc.state.status, InlineAudioRecorderStatus.completed);
        expect(bloc.state.filePath, '/tmp/take.m4a');
        expect(
          bloc.state.duration,
          const Duration(seconds: 12),
          reason: 'the reported duration wins and the ticker is stopped',
        );
      },
    );

    test('CancelRecording wipes the recorder back to idle', () async {
      final bloc = makeBloc();
      bloc.add(const StartRecording());
      bloc.add(const UpdateAmplitude(0.9));
      await Future<void>.delayed(_twoTicks);

      bloc.add(const CancelRecording());
      await Future<void>.delayed(_twoTicks);

      expect(bloc.state, const InlineAudioRecorderState());
      expect(
        bloc.state.duration,
        Duration.zero,
        reason: 'both timers were cancelled with the take',
      );
    });

    test('ResetRecorder is the same full wipe', () async {
      final bloc = makeBloc();
      bloc.add(
        const RecordingCompleted(
          filePath: '/tmp/x.m4a',
          duration: Duration(seconds: 2),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.filePath, isNotNull);

      bloc.add(const ResetRecorder());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state, const InlineAudioRecorderState());
    });

    test('RecordingError surfaces the message and halts the clock', () async {
      final bloc = makeBloc();
      bloc.add(const StartRecording());
      await Future<void>.delayed(_twoTicks);
      final atError = bloc.state.duration;

      bloc.add(const RecordingError('microphone permission denied'));
      await Future<void>.delayed(_twoTicks);

      expect(bloc.state.status, InlineAudioRecorderStatus.error);
      expect(bloc.state.hasError, isTrue);
      expect(bloc.state.errorMessage, 'microphone permission denied');
      expect(bloc.state.duration, atError);
    });
  });

  group('amplitudes and waveform', () {
    test('UpdateAmplitude clamps into 0..1 and appends in order', () async {
      final bloc = makeBloc();
      bloc.add(const UpdateAmplitude(-2.0));
      bloc.add(const UpdateAmplitude(0.42));
      bloc.add(const UpdateAmplitude(7.5));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(bloc.state.amplitudes, [0.0, 0.42, 1.0]);
    });

    test('SetExtractedWaveform replaces the stored waveform', () async {
      final bloc = makeBloc();
      bloc.add(const SetExtractedWaveform([0.1, 0.2]));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.extractedWaveform, [0.1, 0.2]);

      bloc.add(const SetExtractedWaveform([0.9]));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.extractedWaveform, [0.9]);
      expect(
        bloc.state.amplitudes,
        isEmpty,
        reason: 'the live amplitudes are a separate list',
      );
    });

    test(
      'UpdateDuration and UpdatePlaybackPosition set their field only',
      () async {
        final bloc = makeBloc();
        bloc.add(const UpdateDuration(Duration(seconds: 9)));
        bloc.add(const UpdatePlaybackPosition(Duration(seconds: 4)));
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(bloc.state.duration, const Duration(seconds: 9));
        expect(bloc.state.currentPosition, const Duration(seconds: 4));
        expect(bloc.state.status, InlineAudioRecorderStatus.idle);
      },
    );
  });

  group('playback polling over the method channel', () {
    test(
      'a playing native player pushes its position into the state',
      () async {
        handler = (call) {
          if (call.method == 'getPlaybackStatus') {
            return <String, Object?>{
              'isPlaying': true,
              'currentPosition': 1234,
            };
          }
          return null;
        };

        final bloc = makeBloc();
        bloc.add(const UpdateDuration(Duration(seconds: 5)));
        bloc.add(const PlayRecording());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(bloc.state.status, InlineAudioRecorderStatus.playing);
        expect(bloc.state.currentPosition, Duration.zero);

        await Future<void>.delayed(_twoTicks);

        expect(invocations.map((c) => c.method), contains('getPlaybackStatus'));
        expect(bloc.state.currentPosition, const Duration(milliseconds: 1234));
        expect(bloc.state.status, InlineAudioRecorderStatus.playing);
      },
    );

    test('a stopped native player completes playback and rewinds', () async {
      handler = (call) => <String, Object?>{
        'isPlaying': false,
        'currentPosition': 900,
      };

      final bloc = makeBloc();
      bloc.add(const UpdateDuration(Duration(seconds: 5)));
      bloc.add(const UpdatePlaybackPosition(Duration(seconds: 2)));
      bloc.add(const PlayRecording());
      await Future<void>.delayed(_twoTicks);

      expect(bloc.state.status, InlineAudioRecorderStatus.completed);
      expect(
        bloc.state.currentPosition,
        Duration.zero,
        reason: 'completion rewinds so the take can be played again',
      );
    });

    test(
      'missing keys in the native payload fall back to not-playing',
      () async {
        handler = (call) => <String, Object?>{};

        final bloc = makeBloc();
        bloc.add(const UpdateDuration(Duration(seconds: 5)));
        bloc.add(const PlayRecording());
        await Future<void>.delayed(_twoTicks);

        expect(bloc.state.status, InlineAudioRecorderStatus.completed);
      },
    );

    test('a non-Map reply is ignored and playback keeps running', () async {
      handler = (call) => 'unexpected';

      final bloc = makeBloc();
      bloc.add(const UpdateDuration(Duration(seconds: 5)));
      bloc.add(const PlayRecording());
      await Future<void>.delayed(_twoTicks);

      expect(bloc.state.status, InlineAudioRecorderStatus.playing);
      expect(bloc.state.currentPosition, Duration.zero);
    });

    test('a channel error is swallowed and leaves the state alone', () async {
      handler = (call) => throw PlatformException(code: 'NO_PLAYER');

      final bloc = makeBloc();
      bloc.add(const UpdateDuration(Duration(seconds: 5)));
      bloc.add(const PlayRecording());
      await Future<void>.delayed(_twoTicks);

      expect(bloc.state.status, InlineAudioRecorderStatus.playing);
      expect(bloc.state.currentPosition, Duration.zero);
    });

    test('PausePlayback stops the poll; ResumePlayback restarts it', () async {
      var position = 100;
      handler = (call) {
        position += 100;
        return <String, Object?>{
          'isPlaying': true,
          'currentPosition': position,
        };
      };

      final bloc = makeBloc();
      bloc.add(const UpdateDuration(Duration(seconds: 5)));
      bloc.add(const PlayRecording());
      await Future<void>.delayed(_twoTicks);

      bloc.add(const PausePlayback());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.status, InlineAudioRecorderStatus.paused);
      final pausedAt = bloc.state.currentPosition;
      final callsWhenPaused = invocations.length;

      await Future<void>.delayed(_twoTicks);
      expect(bloc.state.currentPosition, pausedAt);
      expect(
        invocations.length,
        callsWhenPaused,
        reason: 'the poller is cancelled while paused',
      );

      bloc.add(const ResumePlayback());
      await Future<void>.delayed(_twoTicks);
      expect(bloc.state.status, InlineAudioRecorderStatus.playing);
      expect(invocations.length, greaterThan(callsWhenPaused));
      expect(bloc.state.currentPosition, greaterThan(pausedAt));
    });

    test('SeekToPosition maps progress onto the duration and plays', () async {
      handler = (call) => <String, Object?>{
        'isPlaying': true,
        'currentPosition': 4000,
      };

      final bloc = makeBloc();
      bloc.add(const UpdateDuration(Duration(seconds: 10)));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      bloc.add(const SeekToPosition(0.25));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.status, InlineAudioRecorderStatus.playing);
      expect(bloc.state.currentPosition, const Duration(milliseconds: 2500));
    });

    test('seeking to 0 and to 1 land on the ends of the take', () async {
      handler = (call) => null;
      final bloc = makeBloc();
      bloc.add(const UpdateDuration(Duration(milliseconds: 3333)));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      bloc.add(const SeekToPosition(0));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.currentPosition, Duration.zero);

      bloc.add(const SeekToPosition(1));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.currentPosition, const Duration(milliseconds: 3333));
    });
  });

  test('close cancels both timers so nothing ticks afterwards', () async {
    handler = (call) => <String, Object?>{
      'isPlaying': true,
      'currentPosition': 500,
    };

    final bloc = InlineAudioRecorderBloc();
    bloc.add(const StartRecording());
    bloc.add(const PlayRecording());
    await Future<void>.delayed(_twoTicks);

    await bloc.close();
    final callsAtClose = invocations.length;

    await Future<void>.delayed(_twoTicks);
    expect(
      invocations.length,
      callsAtClose,
      reason: 'a closed bloc must not keep polling the platform',
    );
  });
}
