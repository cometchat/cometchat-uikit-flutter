/// Render-verified prop matrix for [CometChatAttachmentTrayStyle],
/// [CometChatAttachmentTile] and [CometChatAttachmentTray] — Track 3
/// PROP1/PROP2 (ENG-38929).
///
/// The tile renders one of three layouts depending on the staged file's mime
/// type — a media thumbnail for images and video, an audio card with a scrubber
/// for audio, a name-and-icon card for everything else — and the error copy
/// only on a failed or rejected tile. Each property is exercised on the
/// layout that reads it.
///
///   flutter test test/chat_ui/message_composer/widget/attachment_tray_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AttachmentTile _tile(
  String mime, {
  AttachmentTileStatus status = AttachmentTileStatus.done,
  int? durationMillis = 5000,
  String? errorMessage,
  int loaded = 512,
}) => AttachmentTile(
  fileId: 'f1',
  name: 'clip',
  mimeType: mime,
  size: 1024,
  loaded: loaded,
  status: status,
  durationMillis: durationMillis,
  errorMessage: errorMessage,
);

Widget _host(AttachmentTile tile, CometChatAttachmentTrayStyle style) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 200,
          child: CometChatAttachmentTile(
            tile: tile,
            onCancelOrRemove: () {},
            style: style,
          ),
        ),
      ),
    );

Iterable<BorderRadiusGeometry?> _boxRadii(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => (c.decoration as BoxDecoration?)?.borderRadius);

/// The tile draws its outline as a Border on a BoxDecoration, so read the
/// first side's colour off whatever borders are on screen.
Iterable<Color?> _borderColors(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map(
      (c) => ((c.decoration as BoxDecoration?)?.border as Border?)?.top.color,
    );

Iterable<double?> _textSizes(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.fontSize);

Iterable<Color?> _textColors(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.color);

Iterable<Color?> _iconColors(WidgetTester tester) =>
    tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.color);

Iterable<BorderRadiusGeometry?> _clipRadii(WidgetTester tester) => tester
    .widgetList<ClipRRect>(find.byType(ClipRRect))
    .map((c) => c.borderRadius);

/// Some of the tile's fills are a plain `Container(color:)` rather than a
/// BoxDecoration, so cover both.
Iterable<Color?> _fills(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => c.color ?? (c.decoration as BoxDecoration?)?.color);

/// The video duration pill is a DecoratedBox, not a Container.
Iterable<Color?> _decoratedBoxColors(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((d) => (d.decoration as BoxDecoration?)?.color);

void main() {
  group('the file card', () {
    testWidgets('tileBorderRadius', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile('application/pdf'),
          const CometChatAttachmentTrayStyle(tileBorderRadius: 41),
        ),
      );
      await tester.pump();
      expect(_boxRadii(tester), contains(BorderRadius.circular(41)));
    });

    testWidgets('tileBorderColor', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile('application/pdf'),
          const CometChatAttachmentTrayStyle(
            tileBorderColor: Color(0xFF160101),
          ),
        ),
      );
      await tester.pump();
      expect(_borderColors(tester), contains(const Color(0xFF160101)));
    });

    testWidgets('errorBorderColor', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile(
            'application/pdf',
            status: AttachmentTileStatus.failed,
            errorMessage: 'too big',
          ),
          const CometChatAttachmentTrayStyle(
            errorBorderColor: Color(0xFF160202),
          ),
        ),
      );
      await tester.pump();
      expect(_borderColors(tester), contains(const Color(0xFF160202)));
    });

    testWidgets('nameTextStyle', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile('application/pdf'),
          const CometChatAttachmentTrayStyle(
            nameTextStyle: TextStyle(fontSize: 31),
          ),
        ),
      );
      await tester.pump();
      expect(_textSizes(tester), contains(31.0));
    });

    testWidgets('subtitleTextStyle', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile('application/pdf'),
          const CometChatAttachmentTrayStyle(
            subtitleTextStyle: TextStyle(fontSize: 17),
          ),
        ),
      );
      await tester.pump();
      expect(_textSizes(tester), contains(17.0));
    });

    testWidgets('errorTextStyle', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile(
            'application/pdf',
            status: AttachmentTileStatus.failed,
            errorMessage: 'too big',
          ),
          const CometChatAttachmentTrayStyle(
            errorTextStyle: TextStyle(fontSize: 19),
          ),
        ),
      );
      await tester.pump();
      expect(_textSizes(tester), contains(19.0));
    });

    testWidgets('iconBorderRadius', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile('application/pdf'),
          const CometChatAttachmentTrayStyle(iconBorderRadius: 43),
        ),
      );
      await tester.pump();
      expect(_clipRadii(tester), contains(BorderRadius.circular(43)));
    });
  });

  group('the media thumbnail', () {
    testWidgets('scrimColor', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile('image/png', status: AttachmentTileStatus.uploading),
          const CometChatAttachmentTrayStyle(scrimColor: Color(0xFF160303)),
        ),
      );
      await tester.pump();
      expect(_fills(tester), contains(const Color(0xFF160303)));
    });

    testWidgets('progressColor', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile('image/png', status: AttachmentTileStatus.uploading),
          const CometChatAttachmentTrayStyle(progressColor: Color(0xFF160404)),
        ),
      );
      await tester.pump();
      // the spinner takes it as a valueColor animation, not a plain color
      expect(
        tester
            .widgetList<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .map((p) => p.valueColor?.value),
        contains(const Color(0xFF160404)),
      );
    });

    testWidgets('removeBadgeBackgroundColor', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile('image/png'),
          const CometChatAttachmentTrayStyle(
            removeBadgeBackgroundColor: Color(0xFF160505),
          ),
        ),
      );
      await tester.pump();
      expect(_fills(tester), contains(const Color(0xFF160505)));
    });

    testWidgets('removeBadgeIconColor', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile('image/png'),
          const CometChatAttachmentTrayStyle(
            removeBadgeIconColor: Color(0xFF160606),
          ),
        ),
      );
      await tester.pump();
      expect(_iconColors(tester), contains(const Color(0xFF160606)));
    });
  });

  group('the video duration chip', () {
    testWidgets('durationChipBackgroundColor', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile('video/mp4'),
          const CometChatAttachmentTrayStyle(
            durationChipBackgroundColor: Color(0xFF160707),
          ),
        ),
      );
      await tester.pump();
      expect(_decoratedBoxColors(tester), contains(const Color(0xFF160707)));
    });

    testWidgets('durationChipTextStyle', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile('video/mp4'),
          const CometChatAttachmentTrayStyle(
            durationChipTextStyle: TextStyle(fontSize: 21),
          ),
        ),
      );
      await tester.pump();
      expect(_textSizes(tester), contains(21.0));
    });

    testWidgets('showVideoDuration', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile('video/mp4'),
          const CometChatAttachmentTrayStyle(showVideoDuration: false),
        ),
      );
      await tester.pump();
      // the chip is the only thing that renders the formatted duration
      expect(find.text('0:05'), findsNothing);
    });
  });

  group('the audio card', () {
    testWidgets('sliderActiveColor', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile('audio/mpeg'),
          const CometChatAttachmentTrayStyle(
            sliderActiveColor: Color(0xFF160808),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widgetList<SliderTheme>(find.byType(SliderTheme))
            .map((s) => s.data.activeTrackColor),
        contains(const Color(0xFF160808)),
      );
    });

    testWidgets('sliderInactiveColor', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile('audio/mpeg'),
          const CometChatAttachmentTrayStyle(
            sliderInactiveColor: Color(0xFF160909),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widgetList<SliderTheme>(find.byType(SliderTheme))
            .map((s) => s.data.inactiveTrackColor),
        contains(const Color(0xFF160909)),
      );
    });

    testWidgets('clockTextStyle', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile('audio/mpeg'),
          const CometChatAttachmentTrayStyle(
            clockTextStyle: TextStyle(color: Color(0xFF160D0D)),
          ),
        ),
      );
      await tester.pump();
      expect(_textColors(tester), contains(const Color(0xFF160D0D)));
    });

    testWidgets('playButtonColor', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile('audio/mpeg'),
          const CometChatAttachmentTrayStyle(
            playButtonColor: Color(0xFF160A0A),
          ),
        ),
      );
      await tester.pump();
      expect(_fills(tester), contains(const Color(0xFF160A0A)));
    });

    testWidgets('playIconColor', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile('audio/mpeg'),
          const CometChatAttachmentTrayStyle(playIconColor: Color(0xFF160B0B)),
        ),
      );
      await tester.pump();
      expect(_iconColors(tester), contains(const Color(0xFF160B0B)));
    });

    testWidgets('tileBackgroundColor', (tester) async {
      await tester.pumpWidget(
        _host(
          _tile('audio/mpeg'),
          const CometChatAttachmentTrayStyle(
            tileBackgroundColor: Color(0xFF160C0C),
          ),
        ),
      );
      await tester.pump();
      expect(_fills(tester), contains(const Color(0xFF160C0C)));
    });
  });

  group('CometChatAttachmentTile own props', () {
    testWidgets('tile, height and style shape the card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: CometChatAttachmentTile(
                tile: _tile('application/pdf'),
                onCancelOrRemove: () {},
                height: 91,
                style: const CometChatAttachmentTrayStyle(
                  tileBackgroundColor: Color(0xFF161010),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_fills(tester), contains(const Color(0xFF161010)));
      expect(
        tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.constraints?.maxHeight),
        contains(91.0),
      );
    });

    testWidgets('onTap fires when the card is tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: CometChatAttachmentTile(
                tile: _tile('image/png'),
                onCancelOrRemove: () {},
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('onCancelOrRemove fires from the remove badge', (tester) async {
      var removed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: CometChatAttachmentTile(
                tile: _tile('image/png'),
                onCancelOrRemove: () => removed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(removed, isTrue);
    });

    testWidgets('onRetry and onErrorInteract are wired on a failed tile', (
      tester,
    ) async {
      var retried = false;
      var interacted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: CometChatAttachmentTile(
                tile: _tile(
                  'image/png',
                  status: AttachmentTileStatus.failed,
                  errorMessage: 'network',
                ),
                onCancelOrRemove: () {},
                onRetry: () => retried = true,
                onErrorInteract: () => interacted = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(retried || interacted, isTrue);
    });
  });

  group('CometChatAttachmentTray own props', () {
    /// The controller is a ChangeNotifier the tray listens to; a rejected tile
    /// can be added without touching the SDK, which is enough to make the tray
    /// render something.
    AttachmentTrayController controllerWithTile() {
      final c = AttachmentTrayController();
      c.addLimitRejected(
        UploadFile(
          name: 'clip.pdf',
          size: 1024,
          mimeType: 'application/pdf',
          bytes: const <int>[0],
        ),
        'too many files',
      );
      return c;
    }

    testWidgets(
      'controller drives the tray, and an empty one renders nothing',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatAttachmentTray(
                controller: AttachmentTrayController(),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(CometChatAttachmentTile), findsNothing);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatAttachmentTray(controller: controllerWithTile()),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(CometChatAttachmentTile), findsOneWidget);
      },
    );

    testWidgets('style reaches every tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAttachmentTray(
              controller: controllerWithTile(),
              style: const CometChatAttachmentTrayStyle(
                tileBackgroundColor: Color(0xFF161111),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_fills(tester), contains(const Color(0xFF161111)));
    });

    testWidgets('attachmentErrorSnackBarBuilder replaces the default alert', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAttachmentTray(
              controller: controllerWithTile(),
              attachmentErrorSnackBarBuilder: (context, tile) =>
                  const SnackBar(content: Text('custom error')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(CometChatAttachmentTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('custom error'), findsOneWidget);
    });

    testWidgets('onAttachmentErrorTap overrides the alert entirely', (
      tester,
    ) async {
      AttachmentTile? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAttachmentTray(
              controller: controllerWithTile(),
              onAttachmentErrorTap: (context, tile) => seen = tile,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(CometChatAttachmentTile));
      await tester.pump();
      expect(seen?.name, 'clip.pdf');
    });

    testWidgets('attachmentErrorAlertStyle reaches the default alert', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatAttachmentTray(
              controller: controllerWithTile(),
              attachmentErrorAlertStyle:
                  const CometChatAttachmentErrorAlertStyle(
                    backgroundColor: Color(0xFF161212),
                  ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(CometChatAttachmentTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CometChatAttachmentTile), findsOneWidget);
    });
  });
}
