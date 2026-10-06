/// CometChatInlineAudioRecorder — the widget over the native audio channel.
///
/// The recorder talks to the `cometchat_chat_uikit` method channel for every
/// transport action (start/stop/pause/resume/play/seek/extractWaveform/
/// releaseMediaResources). A mock handler on the test binary messenger stands
/// in for the platform, so the whole control surface is exercised: which
/// buttons each state shows, which channel method each tap sends, and what the
/// recorder hands back through `onSubmit` / `onCancel`.
///
/// The widget builds its bloc privately, so tests reach it through the
/// `BlocProvider` it publishes — that is what makes each state reachable
/// without relying on wall-clock recording time.
///
/// `_AnimatedRecordingDot` repeats forever, so this file never calls
/// `pumpAndSettle`.
///
///   flutter test test/chat_ui/message_composer/inline_audio_recorder_widget_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('cometchat_chat_uikit');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late Object? Function(MethodCall call) handler;

  setUp(() {
    calls = [];
    handler = (call) => call.method == 'startRecordingAudio' ? true : null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return handler(call);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  List<String> methods() => calls.map((c) => c.method).toList();

  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: Translations.localizationsDelegates,
    supportedLocales: const [Locale('en')],
    home: Scaffold(body: SizedBox(width: 400, child: child)),
  );

  /// The bloc the widget published through its BlocProvider.
  InlineAudioRecorderBloc blocOf(WidgetTester tester) =>
      BlocProvider.of<InlineAudioRecorderBloc>(
        tester.element(find.byType(AudioWaveformVisualizer)),
      );

  /// Mounts the recorder and settles the `startRecordingAudio` round trip.
  Future<void> mount(
    WidgetTester tester, {
    void Function(String path, {List<int>? fileBytes})? onSubmit,
    VoidCallback? onCancel,
  }) async {
    await tester.pumpWidget(
      wrap(
        CometChatInlineAudioRecorder(onSubmit: onSubmit, onCancel: onCancel),
      ),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// Puts the recorder into a completed take of [duration] with some bars.
  Future<void> completeTake(
    WidgetTester tester, {
    Duration duration = const Duration(seconds: 10),
    String path = '/tmp/take.m4a',
  }) async {
    final bloc = blocOf(tester);
    bloc.add(const UpdateAmplitude(0.2));
    bloc.add(const UpdateAmplitude(0.8));
    bloc.add(RecordingCompleted(filePath: path, duration: duration));
    await tester.pump(const Duration(milliseconds: 10));
  }

  group('start-up', () {
    testWidgets('mounting starts native recording and shows the live chrome', (
      tester,
    ) async {
      await mount(tester);

      expect(methods(), contains('startRecordingAudio'));
      expect(blocOf(tester).state.isRecording, isTrue);

      // Recording chrome: trash, the pulsing dot, pause, send.
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.text('00:00'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a refused start surfaces as an error state', (tester) async {
      handler = (call) => false;
      await mount(tester);

      final state = blocOf(tester).state;
      expect(state.hasError, isTrue);
      expect(state.errorMessage, 'Failed to start recording');

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a throwing platform surfaces the exception text', (
      tester,
    ) async {
      handler = (call) => throw PlatformException(code: 'NO_MIC');
      await mount(tester);

      final state = blocOf(tester).state;
      expect(state.hasError, isTrue);
      expect(state.errorMessage, contains('NO_MIC'));

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('disposal releases the native media resources', (tester) async {
      await mount(tester);
      calls.clear();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));

      expect(methods(), contains('releaseMediaResources'));
    });

    testWidgets('a failed release falls back to stopping the recorder', (
      tester,
    ) async {
      await mount(tester);
      calls.clear();
      handler = (call) {
        if (call.method == 'releaseMediaResources') {
          throw PlatformException(code: 'BUSY');
        }
        return null;
      };

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));

      expect(
        methods(),
        containsAllInOrder(<String>[
          'releaseMediaResources',
          'stopRecordingAudio',
        ]),
      );
    });
  });

  group('transport controls', () {
    testWidgets('pause sends pauseRecordingAudio and swaps in the mic', (
      tester,
    ) async {
      await mount(tester);
      calls.clear();

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump(const Duration(milliseconds: 10));

      expect(methods(), ['pauseRecordingAudio']);
      expect(blocOf(tester).state.isPaused, isTrue);
      // Paused mid-recording: mic to resume, play to preview.
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a true native resume keeps the elapsed duration', (
      tester,
    ) async {
      await mount(tester);
      blocOf(tester).add(const UpdateDuration(Duration(seconds: 6)));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump(const Duration(milliseconds: 10));

      handler = (call) => call.method == 'resumeRecordingAudio' ? true : null;
      calls.clear();
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump(const Duration(milliseconds: 10));

      expect(methods(), ['resumeRecordingAudio']);
      final state = blocOf(tester).state;
      expect(state.isRecording, isTrue);
      expect(
        state.duration,
        greaterThanOrEqualTo(const Duration(seconds: 6)),
        reason: 'a true resume must not restart the clock',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a refused native resume restarts the take from zero', (
      tester,
    ) async {
      await mount(tester);
      final bloc = blocOf(tester);
      bloc.add(const UpdateDuration(Duration(seconds: 6)));
      bloc.add(const UpdateAmplitude(0.5));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump(const Duration(milliseconds: 10));

      handler = (call) => false; // resumeRecordingAudio could not resume
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump(const Duration(milliseconds: 10));

      final state = blocOf(tester).state;
      expect(state.isRecording, isTrue);
      expect(state.duration, Duration.zero);
      expect(state.amplitudes, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the mic on a finished take starts a brand new recording', (
      tester,
    ) async {
      await mount(tester);
      await completeTake(tester);
      calls.clear();

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump(const Duration(milliseconds: 10));

      expect(methods(), ['startRecordingAudio']);
      expect(blocOf(tester).state.isRecording, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('delete stops the recorder, resets state and calls onCancel', (
      tester,
    ) async {
      var cancelled = 0;
      await mount(tester, onCancel: () => cancelled++);
      calls.clear();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump(const Duration(milliseconds: 10));

      expect(methods(), ['stopRecordingAudio']);
      expect(cancelled, 1);
      expect(blocOf(tester).state, const InlineAudioRecorderState());

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('playback', () {
    testWidgets('play starts the native player and extracts a waveform', (
      tester,
    ) async {
      await mount(tester);
      await completeTake(tester);

      handler = (call) {
        if (call.method == 'extractWaveform') return <double>[0.1, 0.5, 0.9];
        if (call.method == 'getPlaybackStatus') {
          return <String, Object?>{'isPlaying': true, 'currentPosition': 2000};
        }
        return null;
      };
      calls.clear();

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump(const Duration(milliseconds: 10));

      expect(methods(), contains('playRecordedAudio'));
      expect(methods(), contains('extractWaveform'));
      final extractCall = calls.firstWhere(
        (c) => c.method == 'extractWaveform',
      );
      expect((extractCall.arguments as Map)['sampleCount'], 50);

      await tester.pump(const Duration(milliseconds: 10));
      final state = blocOf(tester).state;
      expect(state.isPlaying, isTrue);
      expect(state.extractedWaveform, [0.1, 0.5, 0.9]);
      // Playing chrome: the play button becomes a pause button.
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'an empty extraction leaves the recording amplitudes in place',
      (tester) async {
        await mount(tester);
        await completeTake(tester);
        handler = (call) =>
            call.method == 'extractWaveform' ? <double>[] : null;

        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pump(const Duration(milliseconds: 10));

        expect(blocOf(tester).state.extractedWaveform, isEmpty);
        expect(blocOf(tester).state.amplitudes, isNotEmpty);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('pausing playback sends pausePlayingRecordedAudio', (
      tester,
    ) async {
      await mount(tester);
      await completeTake(tester);
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump(const Duration(milliseconds: 10));
      calls.clear();

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump(const Duration(milliseconds: 10));

      expect(methods(), contains('pausePlayingRecordedAudio'));
      expect(blocOf(tester).state.isPaused, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('resuming mid-take uses resume, not a fresh play', (
      tester,
    ) async {
      await mount(tester);
      await completeTake(tester);
      // A position strictly between 0 and the duration is the resume case.
      blocOf(tester).add(const UpdatePlaybackPosition(Duration(seconds: 4)));
      await tester.pump(const Duration(milliseconds: 10));
      calls.clear();

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump(const Duration(milliseconds: 10));

      expect(methods(), contains('resumePlayingRecordedAudio'));
      expect(methods(), isNot(contains('playRecordedAudio')));
      expect(blocOf(tester).state.isPlaying, isTrue);
      expect(
        blocOf(tester).state.currentPosition,
        const Duration(seconds: 4),
        reason: 'resume keeps the position',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the duration readout switches to the playback position', (
      tester,
    ) async {
      await mount(tester);
      await completeTake(tester, duration: const Duration(seconds: 65));
      expect(find.text('01:05'), findsOneWidget);

      blocOf(
        tester,
      ).add(const UpdatePlaybackPosition(Duration(minutes: 2, seconds: 7)));
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.text('02:07'), findsOneWidget);
      expect(find.text('01:05'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('dragging the waveform seeks the native player', (
      tester,
    ) async {
      await mount(tester);
      await completeTake(tester, duration: const Duration(seconds: 10));
      calls.clear();

      final waveform = find.byType(AudioWaveformVisualizer);
      final box = tester.getRect(waveform);
      // Tap three quarters along the bars.
      await tester.tapAt(Offset(box.left + box.width * 0.75, box.center.dy));
      await tester.pump(const Duration(milliseconds: 10));

      final seek = calls.firstWhere((c) => c.method == 'seekRecordedAudio');
      final positionMs = (seek.arguments as Map)['position'] as int;
      expect(positionMs, greaterThan(0));
      expect(positionMs, lessThanOrEqualTo(10000));
      expect(blocOf(tester).state.isPlaying, isTrue);
      expect(blocOf(tester).state.currentPosition.inMilliseconds, positionMs);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the waveform does not seek while recording', (tester) async {
      await mount(tester);
      calls.clear();

      await tester.tapAt(
        tester.getCenter(find.byType(AudioWaveformVisualizer)),
      );
      await tester.pump(const Duration(milliseconds: 10));

      expect(methods(), isNot(contains('seekRecordedAudio')));

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('sending', () {
    testWidgets('send stops the take and submits the returned path', (
      tester,
    ) async {
      String? submitted;
      List<int>? bytes;
      await mount(
        tester,
        onSubmit: (path, {List<int>? fileBytes}) {
          submitted = path;
          bytes = fileBytes;
        },
      );

      blocOf(tester).add(const UpdateDuration(Duration(seconds: 3)));
      await tester.pump(const Duration(milliseconds: 10));

      handler = (call) =>
          call.method == 'stopRecordingAudio' ? '/tmp/voice.m4a' : null;
      calls.clear();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(const Duration(milliseconds: 10));

      expect(methods(), contains('stopRecordingAudio'));
      expect(submitted, '/tmp/voice.m4a');
      expect(bytes, isNull, reason: 'bytes are a web-only payload');
      expect(blocOf(tester).state.isCompleted, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('an empty native path is not submitted', (tester) async {
      var submits = 0;
      await mount(tester, onSubmit: (_, {List<int>? fileBytes}) => submits++);

      blocOf(tester).add(const UpdateDuration(Duration(seconds: 3)));
      await tester.pump(const Duration(milliseconds: 10));

      handler = (call) => call.method == 'stopRecordingAudio' ? '' : null;
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(const Duration(milliseconds: 10));

      expect(submits, 0);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('send is inert until something has been recorded', (
      tester,
    ) async {
      var submits = 0;
      await mount(tester, onSubmit: (_, {List<int>? fileBytes}) => submits++);

      // Fresh recording, duration still zero → nothing to send.
      expect(blocOf(tester).state.duration, Duration.zero);
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(const Duration(milliseconds: 10));

      expect(submits, 0);
      expect(methods(), isNot(contains('stopRecordingAudio')));

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('sending an already-stopped take reuses the stored path', (
      tester,
    ) async {
      String? submitted;
      await mount(
        tester,
        onSubmit: (path, {List<int>? fileBytes}) => submitted = path,
      );

      blocOf(tester).add(const UpdateDuration(Duration(seconds: 3)));
      await tester.pump(const Duration(milliseconds: 10));

      handler = (call) =>
          call.method == 'stopRecordingAudio' ? '/tmp/first.m4a' : null;
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(const Duration(milliseconds: 10));
      expect(submitted, '/tmp/first.m4a');

      // Now completed: a second send must not stop the recorder again.
      submitted = null;
      calls.clear();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(const Duration(milliseconds: 10));

      expect(methods(), isNot(contains('stopRecordingAudio')));
      expect(submitted, '/tmp/first.m4a');

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('custom icons replace every default', (tester) async {
    await tester.pumpWidget(
      wrap(
        const CometChatInlineAudioRecorder(
          deleteIcon: Icon(Icons.delete_forever, key: Key('del')),
          sendIcon: Icon(Icons.send_rounded, key: Key('send')),
          recordIcon: Icon(Icons.mic_none, key: Key('mic')),
          pauseIcon: Icon(Icons.pause_circle, key: Key('pause')),
          playIcon: Icon(Icons.play_circle, key: Key('play')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.byKey(const Key('del')), findsOneWidget);
    expect(find.byKey(const Key('send')), findsOneWidget);
    expect(find.byKey(const Key('pause')), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
