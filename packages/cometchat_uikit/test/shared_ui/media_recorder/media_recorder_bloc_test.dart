/// [MediaRecorderBloc] — the state machine behind the voice-note recorder.
///
/// The bloc owns a 100ms periodic timer that only runs while recording; every
/// transition out of recording must cancel it, and so must `close()`. A leaked
/// timer is caught here by `testWidgets` itself, which fails a test that ends
/// with one pending — so the tick-count assertions and the absence of that
/// failure together pin the timer's whole lifecycle.
///
/// Tick *values* are deliberately not asserted: `_startTimer` reads
/// `DateTime.now()`, which the fake clock does not control. Tick *counts* are,
/// because the fake clock does control when `Timer.periodic` fires.
///
///   flutter test test/shared_ui/media_recorder/media_recorder_bloc_test.dart
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/presentation/views/components/media_recorder/media_recorder_bloc.dart';

/// Counts what the bloc dispatches to itself, so the periodic timer's ticks
/// can be counted without depending on the values it computes.
class SpyBloc extends MediaRecorderBloc {
  final List<MediaRecorderEvent> dispatched = [];

  @override
  void add(MediaRecorderEvent event) {
    dispatched.add(event);
    super.add(event);
  }

  int get ticks => dispatched.whereType<UpdateTimerEvent>().length;
}

void main() {
  const oneSecond = Duration(seconds: 1);

  // =========================================================================
  // State predicates
  // =========================================================================

  group('state predicates', () {
    test('each state answers exactly one of the four questions', () {
      const initial = MediaRecorderInitial();
      const ready = MediaRecorderReady();
      const recording = MediaRecorderRecording(
        duration: oneSecond,
        amplitudes: [0.5],
      );
      const paused = MediaRecorderPaused(duration: oneSecond, amplitudes: []);
      const completed = MediaRecorderCompleted(
        duration: oneSecond,
        filePath: '/tmp/a.m4a',
      );
      const error = MediaRecorderError(error: 'nope');

      final flags = {
        initial: [false, false, false, false, false],
        ready: [false, false, false, false, true],
        recording: [true, false, false, false, false],
        paused: [false, true, false, false, false],
        completed: [false, false, true, false, true],
        error: [false, false, false, true, false],
      };

      flags.forEach((state, expected) {
        expect(
          [
            state.isRecording,
            state.isPaused,
            state.isCompleted,
            state.hasError,
            state.canRecord,
          ],
          expected,
          reason: '${state.runtimeType}',
        );
      });
    });

    test('recording and completed carry their payload', () {
      const recording = MediaRecorderRecording(
        duration: oneSecond,
        amplitudes: [0.1, 0.2],
      );
      expect(recording.duration, oneSecond);
      expect(recording.amplitudes, [0.1, 0.2]);
      expect(recording.filePath, isNull);

      const completed = MediaRecorderCompleted(
        duration: oneSecond,
        filePath: '/tmp/a.m4a',
      );
      expect(completed.filePath, '/tmp/a.m4a');
      expect(completed.amplitudes, isEmpty);

      const error = MediaRecorderError(error: 'nope');
      expect(error.error, 'nope');
      expect(error.duration, Duration.zero);
    });

    test('copyWith replaces only what it is given', () {
      const base = MediaRecorderRecording(
        duration: oneSecond,
        amplitudes: [0.1],
      );

      expect(
        base.copyWith(duration: const Duration(seconds: 2)),
        const MediaRecorderRecording(
          duration: Duration(seconds: 2),
          amplitudes: [0.1],
        ),
      );
      expect(
        base.copyWith(amplitudes: const [0.9]),
        const MediaRecorderRecording(duration: oneSecond, amplitudes: [0.9]),
      );
      expect(base.copyWith(), base);
    });

    test('states of different classes are never equal', () {
      // Equatable compares props only, so two different empty states would
      // collide and the bloc would swallow a real transition.
      const ready = MediaRecorderReady();
      const initial = MediaRecorderInitial();
      expect(ready, isNot(equals(initial)));
      expect(ready.props, initial.props);

      expect(
        const MediaRecorderRecording(duration: oneSecond, amplitudes: []),
        isNot(
          equals(
            const MediaRecorderPaused(duration: oneSecond, amplitudes: []),
          ),
        ),
      );
    });
  });

  // =========================================================================
  // Event props
  // =========================================================================

  group('event props', () {
    test('valueless events are const-equal but distinct from one another', () {
      expect(const StartRecordingEvent(), const StartRecordingEvent());
      expect(const StopRecordingEvent(), const StopRecordingEvent());
      expect(
        const InitializeRecorderEvent(),
        isNot(equals(const StartRecordingEvent())),
      );
      expect(
        const PauseRecordingEvent(),
        isNot(equals(const ResumeRecordingEvent())),
      );
      expect(
        const CancelRecordingEvent(),
        isNot(equals(const StopRecordingEvent())),
      );

      // Two const literals are canonicalized to the same object, so that
      // comparison never reaches `props`. A separately allocated instance
      // does, and must still compare equal.
      // ignore: prefer_const_constructors
      final fresh = StartRecordingEvent();
      expect(identical(fresh, const StartRecordingEvent()), isFalse);
      expect(fresh, const StartRecordingEvent());
      expect(fresh.props, isEmpty);
      // ignore: prefer_const_constructors
      expect(fresh, isNot(equals(StopRecordingEvent())));
    });

    test('valued events compare on their payload', () {
      expect(
        const UpdateTimerEvent(oneSecond),
        const UpdateTimerEvent(oneSecond),
      );
      expect(
        const UpdateTimerEvent(oneSecond),
        isNot(equals(const UpdateTimerEvent(Duration.zero))),
      );

      expect(
        const UpdateVisualizerEvent([0.1]),
        const UpdateVisualizerEvent([0.1]),
      );
      expect(
        const UpdateVisualizerEvent([0.1]),
        isNot(equals(const UpdateVisualizerEvent([0.2]))),
      );

      expect(const RecordingErrorEvent('a'), const RecordingErrorEvent('a'));
      expect(
        const RecordingErrorEvent('a'),
        isNot(equals(const RecordingErrorEvent('b'))),
      );
    });
  });

  // =========================================================================
  // Transitions
  // =========================================================================

  group('transitions', () {
    testWidgets('initialize moves from initial to ready', (tester) async {
      final bloc = SpyBloc();
      addTearDown(() => tester.runAsync(bloc.close));

      expect(bloc.state, const MediaRecorderInitial());
      bloc.add(const InitializeRecorderEvent());
      await tester.pump();
      expect(bloc.state, const MediaRecorderReady());
      expect(bloc.state.canRecord, isTrue);
    });

    testWidgets('start begins at zero and ticks every 100ms', (tester) async {
      final bloc = SpyBloc();
      addTearDown(() => tester.runAsync(bloc.close));

      bloc.add(const StartRecordingEvent());
      await tester.pump();
      expect(bloc.state, isA<MediaRecorderRecording>());
      expect(bloc.state.duration, Duration.zero);
      expect(bloc.state.amplitudes, isEmpty);
      expect(bloc.ticks, 0);

      await tester.pump(const Duration(milliseconds: 350));
      expect(bloc.ticks, 3, reason: 'one tick per 100ms, no more');

      // Still recording — a tick must not change the state class.
      expect(bloc.state, isA<MediaRecorderRecording>());

      bloc.add(const StopRecordingEvent());
      await tester.pump(const Duration(milliseconds: 350));
      expect(bloc.ticks, 3, reason: 'stop cancels the timer');
    });

    testWidgets('stop completes with the duration reached and no file', (
      tester,
    ) async {
      final bloc = SpyBloc();
      addTearDown(() => tester.runAsync(bloc.close));

      bloc.add(const StartRecordingEvent());
      await tester.pump();
      bloc.add(const UpdateTimerEvent(Duration(seconds: 7)));
      await tester.pump();
      bloc.add(const StopRecordingEvent());
      await tester.pump();

      expect(bloc.state, isA<MediaRecorderCompleted>());
      expect(bloc.state.duration, const Duration(seconds: 7));
      expect(
        bloc.state.filePath,
        isNull,
        reason: 'the bloc never learns the path; the record service sets it',
      );
      expect(bloc.state.canRecord, isTrue, reason: 'ready for another take');
    });

    testWidgets('pause keeps the duration and amplitudes, and stops ticking', (
      tester,
    ) async {
      final bloc = SpyBloc();
      addTearDown(() => tester.runAsync(bloc.close));

      bloc.add(const StartRecordingEvent());
      await tester.pump();
      bloc.add(const UpdateTimerEvent(Duration(seconds: 2)));
      bloc.add(const UpdateVisualizerEvent([0.3, 0.6]));
      await tester.pump();

      bloc.add(const PauseRecordingEvent());
      await tester.pump();
      expect(bloc.state, isA<MediaRecorderPaused>());
      expect(bloc.state.duration, const Duration(seconds: 2));
      expect(bloc.state.amplitudes, [0.3, 0.6]);

      final ticksAtPause = bloc.ticks;
      await tester.pump(const Duration(milliseconds: 500));
      expect(bloc.ticks, ticksAtPause, reason: 'a paused recorder is silent');
    });

    testWidgets('pause from a non-recording state is inert', (tester) async {
      final bloc = SpyBloc();
      addTearDown(() => tester.runAsync(bloc.close));

      bloc.add(const InitializeRecorderEvent());
      await tester.pump();
      bloc.add(const PauseRecordingEvent());
      await tester.pump();

      expect(bloc.state, const MediaRecorderReady());
    });

    testWidgets('resume continues from the paused duration and ticks again', (
      tester,
    ) async {
      final bloc = SpyBloc();
      addTearDown(() => tester.runAsync(bloc.close));

      bloc.add(const StartRecordingEvent());
      await tester.pump();
      bloc.add(const UpdateTimerEvent(Duration(seconds: 2)));
      bloc.add(const UpdateVisualizerEvent([0.3]));
      await tester.pump();
      bloc.add(const PauseRecordingEvent());
      await tester.pump();

      final ticksAtPause = bloc.ticks;
      bloc.add(const ResumeRecordingEvent());
      await tester.pump();

      expect(bloc.state, isA<MediaRecorderRecording>());
      expect(bloc.state.duration, const Duration(seconds: 2));
      expect(bloc.state.amplitudes, [0.3]);

      await tester.pump(const Duration(milliseconds: 250));
      expect(bloc.ticks, ticksAtPause + 2);

      bloc.add(const CancelRecordingEvent());
      await tester.pump();
    });

    testWidgets('resume from a state that is not paused is inert', (
      tester,
    ) async {
      final bloc = SpyBloc();
      addTearDown(() => tester.runAsync(bloc.close));

      bloc.add(const InitializeRecorderEvent());
      await tester.pump();
      bloc.add(const ResumeRecordingEvent());
      await tester.pump(const Duration(milliseconds: 500));

      expect(bloc.state, const MediaRecorderReady());
      expect(bloc.ticks, 0, reason: 'no timer may start');
    });

    testWidgets('cancel throws the take away and returns to ready', (
      tester,
    ) async {
      final bloc = SpyBloc();
      addTearDown(() => tester.runAsync(bloc.close));

      bloc.add(const StartRecordingEvent());
      await tester.pump();
      bloc.add(const UpdateTimerEvent(Duration(seconds: 9)));
      await tester.pump();

      bloc.add(const CancelRecordingEvent());
      await tester.pump();

      expect(bloc.state, const MediaRecorderReady());
      expect(
        bloc.state.duration,
        Duration.zero,
        reason: 'cancel discards, it does not keep the elapsed time',
      );

      final ticksAtCancel = bloc.ticks;
      await tester.pump(const Duration(milliseconds: 500));
      expect(bloc.ticks, ticksAtCancel);
    });

    testWidgets('an error stops the timer and carries the message', (
      tester,
    ) async {
      final bloc = SpyBloc();
      addTearDown(() => tester.runAsync(bloc.close));

      bloc.add(const StartRecordingEvent());
      await tester.pump(const Duration(milliseconds: 150));
      final ticksBefore = bloc.ticks;

      bloc.add(const RecordingErrorEvent('microphone busy'));
      await tester.pump();

      expect(bloc.state, isA<MediaRecorderError>());
      expect(bloc.state.error, 'microphone busy');
      expect(bloc.state.hasError, isTrue);
      expect(bloc.state.canRecord, isFalse);

      await tester.pump(const Duration(milliseconds: 500));
      expect(bloc.ticks, ticksBefore);
    });
  });

  // =========================================================================
  // Updates only apply while recording
  // =========================================================================

  group('timer and visualizer updates', () {
    testWidgets('both are ignored unless the bloc is recording', (
      tester,
    ) async {
      final bloc = SpyBloc();
      addTearDown(() => tester.runAsync(bloc.close));

      bloc.add(const InitializeRecorderEvent());
      await tester.pump();

      bloc.add(const UpdateTimerEvent(Duration(seconds: 5)));
      bloc.add(const UpdateVisualizerEvent([0.9]));
      await tester.pump();

      expect(bloc.state, const MediaRecorderReady());
      expect(bloc.state.duration, Duration.zero);
      expect(bloc.state.amplitudes, isEmpty);
    });

    testWidgets('a paused recorder ignores them too', (tester) async {
      final bloc = SpyBloc();
      addTearDown(() => tester.runAsync(bloc.close));

      bloc.add(const StartRecordingEvent());
      await tester.pump();
      bloc.add(const UpdateTimerEvent(Duration(seconds: 2)));
      await tester.pump();
      bloc.add(const PauseRecordingEvent());
      await tester.pump();

      bloc.add(const UpdateTimerEvent(Duration(seconds: 30)));
      bloc.add(const UpdateVisualizerEvent([0.9]));
      await tester.pump();

      expect(bloc.state.duration, const Duration(seconds: 2));
      expect(bloc.state.amplitudes, isEmpty);
    });

    testWidgets('each update leaves the other field alone', (tester) async {
      final bloc = SpyBloc();
      addTearDown(() => tester.runAsync(bloc.close));

      bloc.add(const StartRecordingEvent());
      await tester.pump();

      bloc.add(const UpdateVisualizerEvent([0.1, 0.2, 0.3]));
      await tester.pump();
      expect(bloc.state.amplitudes, [0.1, 0.2, 0.3]);
      expect(bloc.state.duration, Duration.zero);

      bloc.add(const UpdateTimerEvent(Duration(seconds: 4)));
      await tester.pump();
      expect(bloc.state.duration, const Duration(seconds: 4));
      expect(bloc.state.amplitudes, [0.1, 0.2, 0.3]);

      bloc.add(const CancelRecordingEvent());
      await tester.pump();
    });
  });

  // =========================================================================
  // close()
  // =========================================================================

  testWidgets('close() cancels a running timer', (tester) async {
    final bloc = SpyBloc();

    bloc.add(const StartRecordingEvent());
    await tester.pump(const Duration(milliseconds: 150));
    expect(bloc.ticks, 1);

    // If close() left the periodic timer running, the test framework would
    // fail this test with "A Timer is still pending".
    await tester.runAsync(bloc.close);
    expect(bloc.isClosed, isTrue);
  });
}
