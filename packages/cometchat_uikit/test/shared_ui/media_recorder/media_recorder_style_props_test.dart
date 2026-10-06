/// Render-verified prop matrix for [CometChatMediaRecorderStyle] — Track 3
/// PROP2 (ENG-38926).
///
/// The recorder is a state machine: which buttons exist, and which style
/// property colours each one, depends on whether the bloc is recording,
/// paused or completed. Every case below drives that state through the
/// `mediaRecorderBloc` seam and asserts on the widget the state produces.
///
///   flutter test test/shared_ui/media_recorder/media_recorder_style_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockMediaRecorderBloc
    extends MockBloc<MediaRecorderEvent, MediaRecorderState>
    implements MediaRecorderBloc {}

MockMediaRecorderBloc _bloc(MediaRecorderState state) {
  final b = MockMediaRecorderBloc();
  whenListen(b, Stream<MediaRecorderState>.value(state), initialState: state);
  return b;
}

/// Recording, with time on the clock — the state that shows the delete button,
/// the pause button and the stop button all at once.
const _recording = MediaRecorderRecording(
  duration: Duration(seconds: 3),
  amplitudes: [0.4],
);

/// Paused — same buttons, except the pause button becomes the start button.
const _paused = MediaRecorderPaused(
  duration: Duration(seconds: 3),
  amplitudes: [0.4],
);

/// Recording finished — the audio player, the send button and the start button.
const _completed = MediaRecorderCompleted(
  duration: Duration(seconds: 3),
  filePath: '/x.m4a',
);

/// Every `BoxDecoration` colour on screen. The recorder nests several
/// `Container`s per button, so a property is verified by finding its colour
/// among them rather than by index.
Iterable<Color?> _boxColors(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => (c.decoration as BoxDecoration?)?.color);

Iterable<BoxBorder?> _boxBorders(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => (c.decoration as BoxDecoration?)?.border);

Iterable<BorderRadiusGeometry?> _boxRadii(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => (c.decoration as BoxDecoration?)?.borderRadius);

/// Icons are `Image.asset(..., color:)`, so the tint lands on the Image.
Iterable<Color?> _imageColors(WidgetTester tester) =>
    tester.widgetList<Image>(find.byType(Image)).map((i) => i.color);

CometChatAudioPlayer _player(WidgetTester tester) =>
    tester.widget<CometChatAudioPlayer>(find.byType(CometChatAudioPlayer));

void main() {
  group('the recorder container', () {
    testWidgets('backgroundColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                backgroundColor: Color(0xFF110101),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_boxColors(tester), contains(const Color(0xFF110101)));
    });

    testWidgets('border', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFF110202), width: 3),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxBorders(tester),
        contains(
          const Border.fromBorderSide(
            BorderSide(color: Color(0xFF110202), width: 3),
          ),
        ),
      );
    });

    testWidgets('borderRadius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                borderRadius: BorderRadius.all(Radius.circular(17)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxRadii(tester),
        contains(const BorderRadius.all(Radius.circular(17))),
      );
    });
  });

  group('the recording clock', () {
    testWidgets('textColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(textColor: Color(0xFF110303)),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.color),
        contains(const Color(0xFF110303)),
      );
    });

    testWidgets('textStyle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                textStyle: TextStyle(fontSize: 19, color: Color(0xFF110404)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.style?.fontSize),
        contains(19.0),
      );
    });
  });

  group('the record indicator', () {
    testWidgets('recordIndicatorColor tints the pulsing rings', (tester) async {
      const ring = Color(0xFF0A0B0C);
      Future<void> pump({Color? recordIndicatorColor}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMediaRecorder(
                key: UniqueKey(),
                mediaRecorderBloc: _bloc(_recording),
                style: CometChatMediaRecorderStyle(
                  recordIndicatorColor: recordIndicatorColor,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pump();
      expect(_boxColors(tester), isNot(contains(ring.withValues(alpha: .05))));

      await pump(recordIndicatorColor: ring);
      // The outer and inner rings, at the alphas the background colour used.
      expect(_boxColors(tester), contains(ring.withValues(alpha: .05)));
      expect(_boxColors(tester), contains(ring.withValues(alpha: .1)));
    });

    testWidgets('recordIndicatorColor beats recordIndicatorBackgroundColor '
        'on the rings only', (tester) async {
      const ring = Color(0xFF0A0B0C);
      const fill = Color(0xFF110505);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                recordIndicatorColor: ring,
                recordIndicatorBackgroundColor: fill,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_boxColors(tester), contains(ring.withValues(alpha: .05)));
      expect(_boxColors(tester), isNot(contains(fill.withValues(alpha: .05))));
      // The indicator itself keeps the background colour.
      expect(_boxColors(tester), contains(fill));
    });

    testWidgets('recordIndicatorBackgroundColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                recordIndicatorBackgroundColor: Color(0xFF110505),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_boxColors(tester), contains(const Color(0xFF110505)));
    });

    testWidgets('recordIndicatorBorderRadius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                recordIndicatorBorderRadius: BorderRadius.all(
                  Radius.circular(21),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxRadii(tester),
        contains(const BorderRadius.all(Radius.circular(21))),
      );
    });

    testWidgets('recordIndicatorBorder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                recordIndicatorBorder: Border.fromBorderSide(
                  BorderSide(color: Color(0xFF110606), width: 4),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxBorders(tester),
        contains(
          const Border.fromBorderSide(
            BorderSide(color: Color(0xFF110606), width: 4),
          ),
        ),
      );
    });

    testWidgets('recordIndicatorIconColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                recordIndicatorIconColor: Color(0xFF110707),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_imageColors(tester), contains(const Color(0xFF110707)));
    });
  });

  group('the delete button', () {
    testWidgets('deleteButtonIconColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                deleteButtonIconColor: Color(0xFF110808),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_imageColors(tester), contains(const Color(0xFF110808)));
    });

    testWidgets('deleteButtonBackgroundColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                deleteButtonBackgroundColor: Color(0xFF110909),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_boxColors(tester), contains(const Color(0xFF110909)));
    });

    testWidgets('deleteButtonBorderRadius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                deleteButtonBorderRadius: BorderRadius.all(Radius.circular(23)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxRadii(tester),
        contains(const BorderRadius.all(Radius.circular(23))),
      );
    });

    testWidgets('deleteButtonBorder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                deleteButtonBorder: Border.fromBorderSide(
                  BorderSide(color: Color(0xFF110A0A), width: 5),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxBorders(tester),
        contains(
          const Border.fromBorderSide(
            BorderSide(color: Color(0xFF110A0A), width: 5),
          ),
        ),
      );
    });
  });

  group('the pause button — recording', () {
    testWidgets('pauseButtonIconColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                pauseButtonIconColor: Color(0xFF110B0B),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_imageColors(tester), contains(const Color(0xFF110B0B)));
    });

    testWidgets('pauseButtonBackgroundColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                pauseButtonBackgroundColor: Color(0xFF110C0C),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_boxColors(tester), contains(const Color(0xFF110C0C)));
    });

    testWidgets('pauseButtonBorderRadius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                pauseButtonBorderRadius: BorderRadius.all(Radius.circular(25)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxRadii(tester),
        contains(const BorderRadius.all(Radius.circular(25))),
      );
    });

    testWidgets('pauseButtonBorder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                pauseButtonBorder: Border.fromBorderSide(
                  BorderSide(color: Color(0xFF110D0D), width: 6),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxBorders(tester),
        contains(
          const Border.fromBorderSide(
            BorderSide(color: Color(0xFF110D0D), width: 6),
          ),
        ),
      );
    });
  });

  group('the stop button', () {
    testWidgets('stopButtonIconColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                stopButtonIconColor: Color(0xFF110E0E),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_imageColors(tester), contains(const Color(0xFF110E0E)));
    });

    testWidgets('stopButtonBackgroundColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                stopButtonBackgroundColor: Color(0xFF110F0F),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_boxColors(tester), contains(const Color(0xFF110F0F)));
    });

    testWidgets('stopButtonBorderRadius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                stopButtonBorderRadius: BorderRadius.all(Radius.circular(27)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxRadii(tester),
        contains(const BorderRadius.all(Radius.circular(27))),
      );
    });

    testWidgets('stopButtonBorder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              style: CometChatMediaRecorderStyle(
                stopButtonBorder: Border.fromBorderSide(
                  BorderSide(color: Color(0xFF111010), width: 7),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxBorders(tester),
        contains(
          const Border.fromBorderSide(
            BorderSide(color: Color(0xFF111010), width: 7),
          ),
        ),
      );
    });
  });

  group('the start button — paused', () {
    testWidgets('startButtonIconColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_paused),
              style: CometChatMediaRecorderStyle(
                startButtonIconColor: Color(0xFF111111),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_imageColors(tester), contains(const Color(0xFF111111)));
    });

    testWidgets('startButtonBackgroundColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_paused),
              style: CometChatMediaRecorderStyle(
                startButtonBackgroundColor: Color(0xFF111212),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_boxColors(tester), contains(const Color(0xFF111212)));
    });

    testWidgets('startButtonBorderRadius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_paused),
              style: CometChatMediaRecorderStyle(
                startButtonBorderRadius: BorderRadius.all(Radius.circular(29)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxRadii(tester),
        contains(const BorderRadius.all(Radius.circular(29))),
      );
    });

    testWidgets('startButtonBorder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_paused),
              style: CometChatMediaRecorderStyle(
                startButtonBorder: Border.fromBorderSide(
                  BorderSide(color: Color(0xFF111313), width: 8),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxBorders(tester),
        contains(
          const Border.fromBorderSide(
            BorderSide(color: Color(0xFF111313), width: 8),
          ),
        ),
      );
    });
  });

  group('the send button and player — completed', () {
    testWidgets('sendButtonIconColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_completed),
              style: CometChatMediaRecorderStyle(
                sendButtonIconColor: Color(0xFF111414),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_imageColors(tester), contains(const Color(0xFF111414)));
    });

    testWidgets('sendButtonBackgroundColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_completed),
              style: CometChatMediaRecorderStyle(
                sendButtonBackgroundColor: Color(0xFF111515),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_boxColors(tester), contains(const Color(0xFF111515)));
    });

    testWidgets('sendButtonBorderRadius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_completed),
              style: CometChatMediaRecorderStyle(
                sendButtonBorderRadius: BorderRadius.all(Radius.circular(31)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxRadii(tester),
        contains(const BorderRadius.all(Radius.circular(31))),
      );
    });

    testWidgets('sendButtonBorder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_completed),
              style: CometChatMediaRecorderStyle(
                sendButtonBorder: Border.fromBorderSide(
                  BorderSide(color: Color(0xFF111616), width: 9),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxBorders(tester),
        contains(
          const Border.fromBorderSide(
            BorderSide(color: Color(0xFF111616), width: 9),
          ),
        ),
      );
    });

    testWidgets('playButtonIconColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_completed),
              style: CometChatMediaRecorderStyle(
                playButtonIconColor: Color(0xFF111717),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_player(tester).style?.playIconColor, const Color(0xFF111717));
    });

    testWidgets('audioBubbleStyle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_completed),
              style: CometChatMediaRecorderStyle(
                audioBubbleStyle: CometChatVoiceNoteBubbleStyle(
                  backgroundColor: Color(0xFF111818),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_player(tester).style?.backgroundColor, const Color(0xFF111818));
    });
  });

  group('CometChatMediaRecorder own props', () {
    testWidgets('padding wraps the recorder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              padding: const EdgeInsets.only(left: 37),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.padding),
        contains(const EdgeInsets.only(left: 37)),
      );
    });

    testWidgets('the five button icons replace their defaults', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_recording),
              deleteButtonIcon: const Icon(Icons.delete, key: Key('del')),
              pauseButtonIcon: const Icon(Icons.pause, key: Key('pause')),
              stopButtonIcon: const Icon(Icons.stop, key: Key('stop')),
              startButtonIcon: const Icon(Icons.mic, key: Key('start')),
              sendButtonIcon: const Icon(Icons.send, key: Key('send')),
            ),
          ),
        ),
      );
      await tester.pump();
      // recording shows delete, pause and stop
      expect(find.byKey(const Key('del')), findsOneWidget);
      expect(find.byKey(const Key('pause')), findsOneWidget);
      expect(find.byKey(const Key('stop')), findsOneWidget);
    });

    testWidgets(
      'startButtonIcon and sendButtonIcon reach the completed state',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMediaRecorder(
                mediaRecorderBloc: _bloc(_completed),
                startButtonIcon: const Icon(Icons.mic, key: Key('start')),
                sendButtonIcon: const Icon(Icons.send, key: Key('send')),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(const Key('start')), findsOneWidget);
        expect(find.byKey(const Key('send')), findsOneWidget);
      },
    );

    testWidgets(
      'onClose fires instead of popping when the delete button is tapped',
      (tester) async {
        var closed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMediaRecorder(
                mediaRecorderBloc: _bloc(_recording),
                onClose: () => closed = true,
                deleteButtonIcon: const Icon(Icons.delete, key: Key('del')),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('del')));
        await tester.pump();
        expect(closed, isTrue);
      },
    );

    testWidgets('onSubmit receives the recorded file path', (tester) async {
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMediaRecorder(
              mediaRecorderBloc: _bloc(_completed),
              onSubmit: (_, path) => submitted = path,
              sendButtonIcon: const Icon(Icons.send, key: Key('send')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('send')));
      await tester.pump();
      expect(submitted, '/x.m4a');
    });
  });
}
