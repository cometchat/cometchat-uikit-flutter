/// The amplitude→bar pipeline and the seek gestures of
/// [AudioWaveformVisualizer].
///
/// Off web the widget reads amplitudes from the native
/// `cometchat_uikit_shared_audio_intensity` [EventChannel], so the recording
/// half is driven through a mock stream handler: every event the platform could
/// send (double, int, map, junk, error) is pushed by hand and the resulting bar
/// is asserted against the amplification curve. The playback half — tap/drag to
/// seek — is driven with real gestures.
///
///   flutter test test/chat_ui/message_composer/audio_waveform_visualizer_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = EventChannel('cometchat_uikit_shared_audio_intensity');

void main() {
  late List<double> received;
  late List<double> seeks;
  late int listenCount;
  late int cancelCount;
  MockStreamHandlerEventSink? sink;

  var installed = false;

  setUp(() {
    received = <double>[];
    seeks = <double>[];
    listenCount = 0;
    cancelCount = 0;
    sink = null;
    installed = false;
  });

  /// Installs the mock amplitude channel. Must run INSIDE the test body: the
  /// mock delivers events through a stream whose subscription is bound to the
  /// zone it was created in, so a handler installed from `setUp` never
  /// delivers anything to the test's fake-async zone.
  void installChannel() {
    if (installed) return;
    installed = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          _channel,
          MockStreamHandler.inline(
            onListen: (arguments, events) {
              listenCount++;
              sink = events;
            },
            onCancel: (arguments) => cancelCount++,
          ),
        );
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(_channel, null);
  });

  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: Translations.localizationsDelegates,
    supportedLocales: const [Locale('en')],
    home: Scaffold(body: Center(child: child)),
  );

  Future<void> pumpRecorder(
    WidgetTester tester, {
    bool isAnimating = true,
    double width = 300,
  }) async {
    installChannel();
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: width,
          height: 40,
          child: AudioWaveformVisualizer(
            isAnimating: isAnimating,
            onAmplitudeReceived: received.add,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Pushes one platform event and lets it land.
  Future<void> emit(WidgetTester tester, Object? event) async {
    sink!.success(event);
    // The mock sink hands the event to the channel buffer, which drains on its
    // own microtask before the widget's setState can be rendered.
    await tester.pump();
    await tester.pump();
  }

  /// The end values of the bar tweens, in render order.
  List<double> barHeights(WidgetTester tester) => tester
      .widgetList<TweenAnimationBuilder<double>>(
        find.byType(TweenAnimationBuilder<double>),
      )
      .map((w) => w.tween.end!)
      .toList();

  List<Color> barColors(WidgetTester tester) => tester
      .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
      .map((w) => (w.decoration! as BoxDecoration).color!)
      .toList();

  group('AudioWaveformVisualizer — amplitude pipeline', () {
    testWidgets('recording subscribes to the native amplitude channel', (
      tester,
    ) async {
      await pumpRecorder(tester);
      expect(listenCount, 1);
      expect(cancelCount, 0);
    });

    testWidgets('a quiet sample is lifted to the visible floor', (
      tester,
    ) async {
      await pumpRecorder(tester);
      await emit(tester, 0.0);
      expect(received.single, closeTo(0.15, 1e-9));
    });

    testWidgets('the three amplification segments are continuous', (
      tester,
    ) async {
      await pumpRecorder(tester);
      // < 0.1 : 0.15 + a*2.0
      await emit(tester, 0.05);
      // 0.1 … 0.4 : 0.35 + (a - 0.1)*1.17
      await emit(tester, 0.1);
      await emit(tester, 0.25);
      // >= 0.4 : 0.7 + (a - 0.4)*0.5
      await emit(tester, 0.4);
      await emit(tester, 1.0);

      expect(received[0], closeTo(0.25, 1e-9));
      expect(received[1], closeTo(0.35, 1e-9));
      expect(received[2], closeTo(0.5255, 1e-9));
      expect(received[3], closeTo(0.7, 1e-9));
      expect(received[4], closeTo(1.0, 1e-9));
    });

    testWidgets('samples outside 0..1 are clamped at both ends', (
      tester,
    ) async {
      await pumpRecorder(tester);
      await emit(tester, 7.5);
      await emit(tester, -3.0);
      expect(received[0], closeTo(1.0, 1e-9), reason: 'clamped to full scale');
      expect(received[1], closeTo(0.15, 1e-9), reason: 'clamped to the floor');
    });

    testWidgets('an int sample is read as a level, not ignored', (
      tester,
    ) async {
      await pumpRecorder(tester);
      await emit(tester, 1);
      await emit(tester, 0);
      expect(received, [closeTo(1.0, 1e-9), closeTo(0.15, 1e-9)]);
    });

    testWidgets('a map sample is read from amplitude, then level', (
      tester,
    ) async {
      await pumpRecorder(tester);
      await emit(tester, <String, Object?>{'amplitude': 0.5});
      await emit(tester, <String, Object?>{'level': 0.5});
      // `amplitude` wins when both are present.
      await emit(tester, <String, Object?>{'amplitude': 1.0, 'level': 0.0});

      expect(received[0], closeTo(0.75, 1e-9));
      expect(received[1], closeTo(0.75, 1e-9));
      expect(received[2], closeTo(1.0, 1e-9));
    });

    testWidgets('a map with no usable value still produces a floor bar', (
      tester,
    ) async {
      await pumpRecorder(tester);
      await emit(tester, <String, Object?>{'other': 3});
      await emit(tester, <String, Object?>{'amplitude': 'loud'});
      expect(received, [closeTo(0.15, 1e-9), closeTo(0.15, 1e-9)]);
    });

    testWidgets('an event of an unknown shape is dropped entirely', (
      tester,
    ) async {
      await pumpRecorder(tester);
      await emit(tester, 'loud');
      await emit(tester, <Object?>[0.5]);
      expect(received, isEmpty);
      expect(barHeights(tester), isEmpty, reason: 'no bar was added');
    });

    testWidgets(
      'each accepted sample adds one bar, scaled between min and max',
      (tester) async {
        await pumpRecorder(tester);
        await emit(tester, 0.0); // → 0.15
        await emit(tester, 1.0); // → 1.0

        // height = minBarHeight + (maxBarHeight - minBarHeight) * amplitude,
        // with the defaults 6 and 32.
        expect(barHeights(tester), [closeTo(6 + 26 * 0.15, 1e-9), 32.0]);
      },
    );

    testWidgets('only the most recent bars that fit are painted', (
      tester,
    ) async {
      // 30px wide / (4 + 2) per bar ⇒ 5 visible bars.
      await pumpRecorder(tester, width: 30);
      for (final a in [0.0, 0.1, 0.4, 1.0, 0.0, 0.1, 0.4]) {
        await emit(tester, a);
      }
      expect(received.length, 7);

      final heights = barHeights(tester);
      expect(heights.length, 5, reason: 'the window scrolls, it does not grow');
      // The two oldest samples scrolled off; the window ends on the newest.
      expect(heights, [
        closeTo(6 + 26 * 0.7, 1e-9),
        closeTo(6 + 26 * 1.0, 1e-9),
        closeTo(6 + 26 * 0.15, 1e-9),
        closeTo(6 + 26 * 0.35, 1e-9),
        closeTo(6 + 26 * 0.7, 1e-9),
      ]);
    });

    testWidgets('samples that arrive once recording stopped are ignored', (
      tester,
    ) async {
      await pumpRecorder(tester);
      await emit(tester, 1.0);
      expect(received.length, 1);

      // Stop recording: the native subscription is torn down.
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 300,
            height: 40,
            child: AudioWaveformVisualizer(
              isAnimating: false,
              onAmplitudeReceived: received.add,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(cancelCount, 1);

      sink!.success(0.9);
      await tester.pump();
      expect(received.length, 1, reason: 'no longer animating');
    });

    testWidgets('a widget that starts idle subscribes only when it starts'
        ' recording', (tester) async {
      await pumpRecorder(tester, isAnimating: false);
      expect(listenCount, 0);

      await pumpRecorder(tester);
      expect(listenCount, 1);
    });

    testWidgets('leaving the recorder tears the subscription down', (
      tester,
    ) async {
      await pumpRecorder(tester);
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      await tester.pump();
      expect(cancelCount, 1);
    });
  });

  group('AudioWaveformVisualizer — channel errors', () {
    testWidgets('a missing native plugin is retried a moment later', (
      tester,
    ) async {
      await pumpRecorder(tester);
      expect(listenCount, 1);

      sink!.error(
        code: 'error',
        message: 'MissingPluginException(No implementation found)',
      );
      await tester.pump();
      expect(listenCount, 1, reason: 'the retry is delayed');

      await tester.pump(const Duration(milliseconds: 400));
      expect(listenCount, 2, reason: 're-subscribed after the delay');

      // And the retried subscription delivers amplitudes again.
      await emit(tester, 1.0);
      expect(received.single, closeTo(1.0, 1e-9));
    });

    testWidgets('any other stream error is surfaced but not retried', (
      tester,
    ) async {
      await pumpRecorder(tester);
      sink!.error(code: 'AUDIO_ERROR', message: 'mic busy');
      await tester.pump(const Duration(milliseconds: 400));
      expect(listenCount, 1, reason: 'only a missing plugin is retried');
    });

    testWidgets('a missing plugin is not retried once recording has stopped', (
      tester,
    ) async {
      await pumpRecorder(tester);
      sink!.error(
        code: 'error',
        message: 'MissingPluginException(No implementation found)',
      );
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 300,
            height: 40,
            child: AudioWaveformVisualizer(isAnimating: false),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(listenCount, 1);
    });
  });

  group('AudioWaveformVisualizer — seeking', () {
    // 10 bars over 300px: each played bar is one tenth of the track.
    final amplitudes = List<double>.filled(10, 0.5);

    Future<Rect> pumpPlayer(
      WidgetTester tester, {
      bool isAnimating = false,
      bool allowSeeking = true,
      double playbackProgress = 0,
      List<double>? bars,
    }) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 300,
            height: 40,
            child: AudioWaveformVisualizer(
              isAnimating: isAnimating,
              allowSeeking: allowSeeking,
              playbackProgress: playbackProgress,
              amplitudes: bars ?? amplitudes,
              onSeek: seeks.add,
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getRect(find.byType(AudioWaveformVisualizer));
    }

    testWidgets('a tap seeks to the fraction of the track it landed on', (
      tester,
    ) async {
      final box = await pumpPlayer(tester);
      await tester.tapAt(Offset(box.left + 75, box.center.dy));
      await tester.pump();
      expect(seeks.single, closeTo(0.25, 1e-9));
    });

    testWidgets('dragging seeks continuously and lands on the exact release'
        ' position', (tester) async {
      final box = await pumpPlayer(tester);
      final gesture = await tester.startGesture(
        Offset(box.left + 10, box.center.dy),
      );
      await tester.pump();
      // Clear the touch slop so the horizontal drag is recognized.
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.moveTo(Offset(box.left + 150, box.center.dy));
      await tester.pump();

      // Mid-drag the bars recolour to the drag position, not to playback.
      final colors = barColors(tester);
      expect(colors.length, 10);
      expect(
        colors.where((c) => c == colors.first).length,
        5,
        reason: 'half way ⇒ 5 played bars',
      );
      expect(colors.first, isNot(colors.last));

      await gesture.moveTo(Offset(box.left + 270, box.center.dy));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(seeks, isNotEmpty);
      expect(seeks.last, closeTo(0.9, 1e-9), reason: 'the release position');
      expect(seeks.every((s) => s >= 0 && s <= 1), isTrue);
    });

    testWidgets('dragging past either edge clamps instead of overshooting', (
      tester,
    ) async {
      final box = await pumpPlayer(tester);
      final gesture = await tester.startGesture(
        Offset(box.left + 150, box.center.dy),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.moveTo(Offset(box.right + 400, box.center.dy));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(seeks.last, 1.0);

      seeks.clear();
      final gesture2 = await tester.startGesture(
        Offset(box.left + 150, box.center.dy),
      );
      await tester.pump();
      await gesture2.moveBy(const Offset(-40, 0));
      await tester.pump();
      await gesture2.moveTo(Offset(box.left - 400, box.center.dy));
      await tester.pump();
      await gesture2.up();
      await tester.pump();
      expect(seeks.last, 0.0);
    });

    testWidgets('the bars go back to the playback position after the drag', (
      tester,
    ) async {
      final box = await pumpPlayer(tester, playbackProgress: 0.2);
      // Before: 2 of 10 bars played.
      final before = barColors(tester);
      expect(before.where((c) => c == before.first).length, 2);

      final gesture = await tester.startGesture(
        Offset(box.left + 10, box.center.dy),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.moveTo(Offset(box.left + 240, box.center.dy));
      await tester.pump();
      expect(barColors(tester).where((c) => c == before.first).length, 8);

      await gesture.up();
      await tester.pump();
      expect(
        barColors(tester).where((c) => c == before.first).length,
        2,
        reason: 'the drag preview is dropped; playbackProgress rules again',
      );
    });

    testWidgets('while recording, tap and drag never seek', (tester) async {
      final box = await pumpPlayer(tester, isAnimating: true);
      await tester.tapAt(Offset(box.left + 75, box.center.dy));
      await tester.pump();
      await tester.dragFrom(
        Offset(box.left + 10, box.center.dy),
        const Offset(200, 0),
      );
      await tester.pump();
      expect(seeks, isEmpty);
    });

    testWidgets('with seeking disabled, tap and drag never seek', (
      tester,
    ) async {
      final box = await pumpPlayer(tester, allowSeeking: false);
      await tester.tapAt(Offset(box.left + 75, box.center.dy));
      await tester.pump();
      await tester.dragFrom(
        Offset(box.left + 10, box.center.dy),
        const Offset(200, 0),
      );
      await tester.pump();
      expect(seeks, isEmpty);
    });

    testWidgets('a drag on an empty waveform ends without seeking', (
      tester,
    ) async {
      // No bars ⇒ nothing to seek to: the end handler is still wired, and has
      // to no-op because no drag was ever started.
      final box = await pumpPlayer(tester, bars: const []);
      await tester.dragFrom(
        Offset(box.left + 10, box.center.dy),
        const Offset(200, 0),
      );
      await tester.pump();
      expect(seeks, isEmpty);
    });
  });
}
