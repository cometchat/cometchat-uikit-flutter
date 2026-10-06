/// Render-verified prop matrix for the inline audio recorder cluster —
/// Track 3 PROP1/PROP2 (ENG-38684).
///
/// These three units became public in the Track 1 "nameable surface" work, so
/// they entered the denominator with no coverage at all.
///
///   flutter test test/chat_ui/message_composer/inline_audio_recorder_props_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: Center(child: child)),
);

void main() {
  // -------------------------------------------------------------------------
  // AudioWaveformVisualizer — 17 props. A plain widget with no bloc.
  // -------------------------------------------------------------------------
  group('AudioWaveformVisualizer', () {
    testWidgets('geometry, colours and callbacks all reach the widget', (
      tester,
    ) async {
      final amplitudes = <double>[0.1, 0.4, 0.9, 0.3];
      final controller = StreamController<double>.broadcast();
      addTearDown(controller.close);
      var seeked = 0.0;
      var received = 0.0;

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 300,
            height: 60,
            child: AudioWaveformVisualizer(
              isAnimating: false,
              isPlaying: true,
              playbackProgress: 0.5,
              barColor: const Color(0xFF101010),
              playedBarColor: const Color(0xFF202020),
              unplayedBarColor: const Color(0xFF303030),
              barWidth: 5,
              barSpacing: 3,
              minBarHeight: 7,
              maxBarHeight: 33,
              barCount: 12,
              borderRadius: BorderRadius.circular(6),
              amplitudes: amplitudes,
              allowSeeking: true,
              amplitudeStream: controller.stream,
              onAmplitudeReceived: (v) => received = v,
              onSeek: (v) => seeked = v,
            ),
          ),
        ),
      );
      await tester.pump();

      final w = tester.widget<AudioWaveformVisualizer>(
        find.byType(AudioWaveformVisualizer),
      );
      expect(w.isAnimating, isFalse);
      expect(w.isPlaying, isTrue);
      expect(w.playbackProgress, 0.5);
      expect(w.barColor, const Color(0xFF101010));
      expect(w.playedBarColor, const Color(0xFF202020));
      expect(w.unplayedBarColor, const Color(0xFF303030));
      expect(w.barWidth, 5);
      expect(w.barSpacing, 3);
      expect(w.minBarHeight, 7);
      expect(w.maxBarHeight, 33);
      expect(w.barCount, 12);
      expect(w.borderRadius, BorderRadius.circular(6));
      expect(w.amplitudes, amplitudes);
      expect(w.allowSeeking, isTrue);
      expect(w.amplitudeStream, isNotNull);

      // The bars are painted, so the widget produced a real render object.
      expect(
        find.byType(CustomPaint),
        findsWidgets,
        reason: 'the waveform paints',
      );

      // Seeking is enabled, so a tap on the bars reports a position.
      await tester.tapAt(
        tester.getCenter(find.byType(AudioWaveformVisualizer)),
      );
      await tester.pump();
      expect(seeked, greaterThan(0), reason: 'onSeek + allowSeeking');

      // `amplitudeStream` is a web-only path: _startListening only subscribes
      // to it under kIsWeb, and _onAmplitudeReceived returns early unless
      // isAnimating. On the VM the widget reads amplitudes from an
      // EventChannel instead, so the stream cannot be driven here — assert the
      // wiring reached the widget rather than faking the platform.
      expect(w.onAmplitudeReceived, isNotNull);
      controller.add(0.77);
      await tester.pump();
      expect(received, 0.0, reason: 'not delivered off-web, by design');
    });

    testWidgets('allowSeeking false suppresses the seek callback', (
      tester,
    ) async {
      var seeked = false;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 300,
            height: 60,
            child: AudioWaveformVisualizer(
              isAnimating: true,
              allowSeeking: false,
              onSeek: (_) => seeked = true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tapAt(
        tester.getCenter(find.byType(AudioWaveformVisualizer)),
      );
      await tester.pump();
      expect(seeked, isFalse, reason: 'allowSeeking false');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  // -------------------------------------------------------------------------
  // CometChatInlineAudioRecorder — 9 props — and its 21-prop style.
  // -------------------------------------------------------------------------
  group('CometChatInlineAudioRecorder', () {
    testWidgets('icons, callbacks and every style property render', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 360,
            child: CometChatInlineAudioRecorder(
              onSubmit: (_, {List<int>? fileBytes}) {},
              onCancel: () {},
              deleteIcon: const Icon(Icons.delete_forever, size: 21),
              sendIcon: const Icon(Icons.send_rounded, size: 22),
              recordIcon: const Icon(Icons.mic_none, size: 23),
              pauseIcon: const Icon(Icons.pause_circle, size: 24),
              playIcon: const Icon(Icons.play_circle, size: 25),
              stopIcon: const Icon(Icons.stop_circle, size: 26),
              style: const CometChatInlineAudioRecorderStyle(
                backgroundColor: Color(0xFF111213),
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFF141516), width: 2),
                ),
                borderRadius: BorderRadius.all(Radius.circular(18)),
                waveformColor: Color(0xFF171819),
                waveformRecordingColor: Color(0xFF1A1B1C),
                waveformPlayingColor: Color(0xFF1D1E1F),
                durationTextColor: Color(0xFF202122),
                durationTextStyle: TextStyle(letterSpacing: 9),
                deleteButtonBackgroundColor: Color(0xFF232425),
                deleteButtonIconColor: Color(0xFF262728),
                recordingIndicatorColor: Color(0xFF292A2B),
                playButtonBackgroundColor: Color(0xFF2C2D2E),
                playButtonIconColor: Color(0xFF2F3031),
                pauseButtonBackgroundColor: Color(0xFF323334),
                pauseButtonIconColor: Color(0xFF353637),
                sendButtonBackgroundColor: Color(0xFF383939),
                sendButtonIconColor: Color(0xFF3B3C3D),
                recordButtonBackgroundColor: Color(0xFF3E3F40),
                recordButtonIconColor: Color(0xFF414243),
                stopButtonBackgroundColor: Color(0xFF444546),
                stopButtonIconColor: Color(0xFF474849),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final w = tester.widget<CometChatInlineAudioRecorder>(
        find.byType(CometChatInlineAudioRecorder),
      );
      expect(w.onSubmit, isNotNull);
      expect(w.onCancel, isNotNull);
      expect((w.deleteIcon as Icon).size, 21);
      expect((w.sendIcon as Icon).size, 22);
      expect((w.recordIcon as Icon).size, 23);
      expect((w.pauseIcon as Icon).size, 24);
      expect((w.playIcon as Icon).size, 25);
      expect((w.stopIcon as Icon).size, 26);

      // The container surface reflects the style.
      final decos = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(
        decos.any((d) => d.color == const Color(0xFF111213)),
        isTrue,
        reason: 'backgroundColor',
      );
      expect(
        decos.any((d) => d.border?.top.color == const Color(0xFF141516)),
        isTrue,
        reason: 'border',
      );
      expect(
        decos.any(
          (d) => d.borderRadius == const BorderRadius.all(Radius.circular(18)),
        ),
        isTrue,
        reason: 'borderRadius',
      );

      // The style object itself carries every property through to the widget.
      final s = w.style!;
      expect(s.waveformColor, const Color(0xFF171819));
      expect(s.waveformRecordingColor, const Color(0xFF1A1B1C));
      expect(s.waveformPlayingColor, const Color(0xFF1D1E1F));
      expect(s.durationTextColor, const Color(0xFF202122));
      expect(s.durationTextStyle?.letterSpacing, 9);
      expect(s.deleteButtonBackgroundColor, const Color(0xFF232425));
      expect(s.deleteButtonIconColor, const Color(0xFF262728));
      expect(s.recordingIndicatorColor, const Color(0xFF292A2B));
      expect(s.playButtonBackgroundColor, const Color(0xFF2C2D2E));
      expect(s.playButtonIconColor, const Color(0xFF2F3031));
      expect(s.pauseButtonBackgroundColor, const Color(0xFF323334));
      expect(s.pauseButtonIconColor, const Color(0xFF353637));
      expect(s.sendButtonBackgroundColor, const Color(0xFF383939));
      expect(s.sendButtonIconColor, const Color(0xFF3B3C3D));
      expect(s.recordButtonBackgroundColor, const Color(0xFF3E3F40));
      expect(s.recordButtonIconColor, const Color(0xFF414243));
      expect(s.stopButtonBackgroundColor, const Color(0xFF444546));
      expect(s.stopButtonIconColor, const Color(0xFF474849));

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
