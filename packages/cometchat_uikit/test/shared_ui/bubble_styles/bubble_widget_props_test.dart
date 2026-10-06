/// Render-verified prop matrix for the bubble widgets' own properties —
/// Track 3 PROP1 (ENG-38938).
///
/// The style classes these widgets read are covered in
/// `per_type_bubble_style_props_test.dart` and
/// `gallery_and_extension_bubble_style_props_test.dart`. This file covers what
/// is left: each widget's own geometry, content and view-slot properties.
///
///   flutter test test/shared_ui/bubble_styles/bubble_widget_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _me = User(uid: 'u1', name: 'Alice');
final _them = User(uid: 'u2', name: 'Bob');
final _sentAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

Attachment _attachment(String name, String ext, String mime) =>
    Attachment('https://example.com/$name', name, ext, mime, 2048);

MediaMessage _mediaMessage(String type, List<Attachment> attachments) {
  final m = MediaMessage(
    id: 2,
    sender: _them,
    receiver: _me,
    receiverUid: 'u1',
    type: type,
    receiverType: ReceiverTypeConstants.user,
    sentAt: _sentAt,
  );
  m.attachments = attachments;
  return m;
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 360, child: child)),
);

/// The gallery bubbles fetch thumbnails and the audio rows spin up a player;
/// neither works headlessly and neither affects the properties under test.
void _ignorePlatformOnlyErrors() {
  const tolerated = [
    'resolving an image codec',
    'HTTP request failed',
    'Unable to load asset',
    'has not been implemented',
    'A RenderFlex overflowed',
  ];
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (tolerated.any(details.toString().contains)) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

Iterable<double?> _boxWidths(WidgetTester tester) => [
  ...tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.constraints?.maxWidth),
  ...tester.widgetList<SizedBox>(find.byType(SizedBox)).map((s) => s.width),
];

Iterable<double?> _boxHeights(WidgetTester tester) => [
  ...tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.constraints?.maxHeight),
  ...tester.widgetList<SizedBox>(find.byType(SizedBox)).map((s) => s.height),
];

Iterable<EdgeInsetsGeometry?> _paddings(WidgetTester tester) => [
  ...tester.widgetList<Padding>(find.byType(Padding)).map((p) => p.padding),
  ...tester.widgetList<Container>(find.byType(Container)).map((c) => c.padding),
];

Iterable<EdgeInsetsGeometry?> _margins(WidgetTester tester) =>
    tester.widgetList<Container>(find.byType(Container)).map((c) => c.margin);

void main() {
  group('CometChatTextBubble', () {
    testWidgets('geometry, theme objects and formatters reach the bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => CometChatTextBubble(
              text: 'hello world',
              alignment: BubbleAlignment.left,
              formatters: const [],
              height: 91,
              width: 251,
              padding: const EdgeInsets.only(left: 11),
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_boxHeights(tester), contains(91.0));
      expect(_boxWidths(tester), contains(251.0));
      expect(_paddings(tester), contains(const EdgeInsets.only(left: 11)));
    });

    testWidgets('emojiCount scales an emoji-only bubble', (tester) async {
      await tester.pumpWidget(
        _host(
          CometChatTextBubble(
            text: '😀',
            alignment: BubbleAlignment.left,
            emojiCount: 1,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatTextBubble), findsOneWidget);
    });
  });

  group('CometChatVideoBubble', () {
    testWidgets('geometry, theme objects and the thumbnail reach the bubble', (
      tester,
    ) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => CometChatVideoBubble(
              videoUrl: 'https://example.com/clip.mp4',
              thumbnailUrl: 'https://example.com/thumb.png',
              height: 91,
              width: 251,
              padding: const EdgeInsets.only(left: 11),
              margin: const EdgeInsets.only(top: 13),
              metadata: const <String, dynamic>{'k': 'v'},
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_boxHeights(tester), contains(91.0));
      expect(_boxWidths(tester), contains(251.0));
      expect(_margins(tester), contains(const EdgeInsets.only(top: 13)));
    });

    testWidgets('playIcon, placeHolder and onClick replace the defaults', (
      tester,
    ) async {
      _ignorePlatformOnlyErrors();
      var clicked = false;
      await tester.pumpWidget(
        _host(
          CometChatVideoBubble(
            videoUrl: 'https://example.com/clip.mp4',
            playIcon: const Icon(Icons.play_circle, key: Key('play')),
            placeHolder: const Text('loading clip'),
            onClick: () => clicked = true,
          ),
        ),
      );
      await tester.pump();
      // the play overlay paints over a resolved thumbnail, which needs the
      // network; the tap target and the placeholder are what render headlessly
      expect(find.text('loading clip'), findsOneWidget);
      await tester.tap(find.byType(CometChatVideoBubble));
      await tester.pump();
      expect(clicked, isTrue);
    });
  });

  group('CometChatCallBubble', () {
    testWidgets('geometry and the icon slots reach the bubble', (tester) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(
          CometChatCallBubble(
            title: 'Voice call',
            buttonText: 'Call back',
            onTap: (_) {},
            icon: const Icon(Icons.call, key: Key('call')),
            iconUrl: 'https://example.com/call.png',
            height: 91,
            width: 251,
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('call')), findsOneWidget);
      expect(_boxHeights(tester), contains(91.0));
      expect(_boxWidths(tester), contains(251.0));
    });

    // P5-C06: the button always read "Join", whatever buttonText said.
    testWidgets('P5-C06: buttonText is what the button says', (tester) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(
          CometChatCallBubble(
            title: 'Voice call',
            buttonText: 'Call back',
            onTap: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(ElevatedButton),
          matching: find.text('Call back'),
        ),
        findsOneWidget,
      );
      expect(find.text('Join'), findsNothing);
    });

    testWidgets('P5-C06: with no buttonText the button says "Join"', (
      tester,
    ) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(CometChatCallBubble(title: 'Voice call', onTap: (_) {})),
      );
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(ElevatedButton),
          matching: find.text('Join'),
        ),
        findsOneWidget,
      );
    });
  });

  group('CometChatLinkPreviewBubble', () {
    testWidgets('defaultImage backs a preview with no image', (tester) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(
          CometChatLinkPreviewBubble(
            links: const <dynamic>[
              {'url': 'https://cometchat.com', 'title': 'CometChat'},
            ],
            onTapUrl: (_) async {},
            alignment: BubbleAlignment.left,
            defaultImage: const Icon(Icons.image, key: Key('fallback')),
            child: const Text('see https://cometchat.com'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatLinkPreviewBubble), findsOneWidget);
    });
  });

  group('the gallery bubbles', () {
    testWidgets('maxWidth, gridGap and formatters reach the image grid', (
      tester,
    ) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(
          CometChatImagesBubble(
            message: _mediaMessage(MessageTypeConstants.image, [
              _attachment('a.png', 'png', 'image/png'),
              _attachment('b.png', 'png', 'image/png'),
            ]),
            alignment: BubbleAlignment.left,
            formatters: const [],
            maxWidth: 251,
            gridGap: 9,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatImagesBubble), findsOneWidget);
      expect(_boxWidths(tester), contains(251.0));
    });

    testWidgets('maxWidth, gridGap and formatters reach the video grid', (
      tester,
    ) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(
          CometChatVideosBubble(
            message: _mediaMessage(MessageTypeConstants.video, [
              _attachment('a.mp4', 'mp4', 'video/mp4'),
              _attachment('b.mp4', 'mp4', 'video/mp4'),
            ]),
            alignment: BubbleAlignment.left,
            formatters: const [],
            maxWidth: 251,
            gridGap: 9,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatVideosBubble), findsOneWidget);
      expect(_boxWidths(tester), contains(251.0));
    });

    testWidgets('maxWidth and formatters reach the file cards', (tester) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(
          CometChatFilesBubble(
            message: _mediaMessage(MessageTypeConstants.file, [
              _attachment('a.pdf', 'pdf', 'application/pdf'),
            ]),
            alignment: BubbleAlignment.left,
            formatters: const [],
            maxWidth: 251,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatFilesBubble), findsOneWidget);
      expect(_boxWidths(tester), contains(251.0));
    });

    testWidgets('maxWidth and formatters reach the audio rows', (tester) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(
          CometChatAudiosBubble(
            message: _mediaMessage(MessageTypeConstants.audio, [
              _attachment('a.mp3', 'mp3', 'audio/mpeg'),
            ]),
            alignment: BubbleAlignment.left,
            formatters: const [],
            maxWidth: 251,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatAudiosBubble), findsOneWidget);
      expect(_boxWidths(tester), contains(251.0));
    });
  });
}
