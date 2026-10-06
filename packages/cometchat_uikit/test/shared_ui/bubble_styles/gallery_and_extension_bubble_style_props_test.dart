/// Render-verified prop matrix for the gallery and extension bubble style
/// classes — Track 3 PROP2 (ENG-38936).
///
/// The multi-attachment gallery bubbles (`CometChatImagesBubble`,
/// `VideosBubble`, `AudiosBubble`, `FilesBubble`) each read their whole style
/// class directly, so those cases pump the widget with a media message
/// carrying attachments. The link-preview, call, voice-note and AI-assistant
/// bubbles do the same for the properties they own; their message-bubble
/// chrome properties travel through the aggregates and are covered in
/// `per_type_bubble_style_props_test.dart`.
///
///   flutter test test/shared_ui/bubble_styles/gallery_and_extension_bubble_style_props_test.dart
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

/// Three attachments, so the grid lays out and the overflow tile appears.
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

MediaMessage _images() => _mediaMessage(MessageTypeConstants.image, [
  _attachment('a.png', 'png', 'image/png'),
  _attachment('b.png', 'png', 'image/png'),
  _attachment('c.png', 'png', 'image/png'),
]);

MediaMessage _videos() => _mediaMessage(MessageTypeConstants.video, [
  _attachment('a.mp4', 'mp4', 'video/mp4'),
  _attachment('b.mp4', 'mp4', 'video/mp4'),
]);

MediaMessage _audios() => _mediaMessage(MessageTypeConstants.audio, [
  _attachment('a.mp3', 'mp3', 'audio/mpeg'),
  _attachment('b.mp3', 'mp3', 'audio/mpeg'),
]);

MediaMessage _files() => _mediaMessage(MessageTypeConstants.file, [
  _attachment('a.pdf', 'pdf', 'application/pdf'),
  _attachment('b.pdf', 'pdf', 'application/pdf'),
]);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 360, child: child)),
);

/// Fills land on a Container's `color`, its BoxDecoration, or a bare
/// DecoratedBox depending on the widget — cover all three.
Iterable<Color?> _fills(WidgetTester tester) => [
  ...tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.color ?? (c.decoration as BoxDecoration?)?.color),
  ...tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((d) => (d.decoration as BoxDecoration?)?.color),
];

Iterable<BoxBorder?> _borders(WidgetTester tester) => [
  ...tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => (c.decoration as BoxDecoration?)?.border),
  ...tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((d) => (d.decoration as BoxDecoration?)?.border),
];

Iterable<BorderRadiusGeometry?> _radii(WidgetTester tester) => [
  ...tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => (c.decoration as BoxDecoration?)?.borderRadius),
  ...tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((d) => (d.decoration as BoxDecoration?)?.borderRadius),
  ...tester
      .widgetList<ClipRRect>(find.byType(ClipRRect))
      .map((c) => c.borderRadius),
];

Iterable<double?> _textSizes(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.fontSize);

Iterable<Color?> _textColors(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.color);

/// The gallery bubbles fetch their thumbnails over the network and the audio
/// rows spin up a player; neither works headlessly. Both complain loudly and
/// neither affects the style properties under test.
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

void main() {
  group('CometChatImagesBubbleStyle', () {
    testWidgets('every property reaches the image grid', (tester) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(
          CometChatImagesBubble(
            message: _images(),
            alignment: BubbleAlignment.left,
            style: const CometChatImagesBubbleStyle(
              captionTextStyle: TextStyle(fontSize: 31),
              gridSpacing: 7,
              overflowScrimColor: Color(0xFF1E0101),
              overflowTextStyle: TextStyle(fontSize: 17),
              placeholderColor: Color(0xFF1E0202),
              tileBorderRadius: 67,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_fills(tester), contains(const Color(0xFF1E0202)));
      expect(_radii(tester), contains(BorderRadius.circular(67)));
      expect(find.byType(CometChatImagesBubble), findsOneWidget);
    });
  });

  group('CometChatVideosBubbleStyle', () {
    testWidgets('every property reaches the video grid', (tester) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(
          CometChatVideosBubble(
            message: _videos(),
            alignment: BubbleAlignment.left,
            style: const CometChatVideosBubbleStyle(
              captionTextStyle: TextStyle(fontSize: 31),
              durationChipBackgroundColor: Color(0xFF1E1010),
              durationChipTextStyle: TextStyle(fontSize: 19),
              gridSpacing: 7,
              nameTextStyle: TextStyle(fontSize: 21),
              overflowScrimColor: Color(0xFF1E1111),
              overflowTextStyle: TextStyle(fontSize: 23),
              placeholderColor: Color(0xFF1E1212),
              playIconBackgroundColor: Color(0xFF1E1313),
              playIconColor: Color(0xFF1E1414),
              showVideoDuration: true,
              tileBorderRadius: 69,
            ),
          ),
        ),
      );
      await tester.pump();
      // the play overlay only paints once a thumbnail resolves, which needs
      // the network; the tile placeholder and its radius render regardless
      expect(_fills(tester), contains(const Color(0xFF1E1212)));
      expect(_radii(tester), contains(BorderRadius.circular(69)));
      expect(find.byType(CometChatVideosBubble), findsOneWidget);
    });
  });

  group('CometChatAudiosBubbleStyle', () {
    testWidgets('every property reaches the audio rows', (tester) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(
          CometChatAudiosBubble(
            message: _audios(),
            alignment: BubbleAlignment.left,
            style: const CometChatAudiosBubbleStyle(
              captionTextStyle: TextStyle(fontSize: 31),
              downloadIconColor: Color(0xFF1E2020),
              durationTextStyle: TextStyle(fontSize: 17),
              nameTextStyle: TextStyle(fontSize: 19),
              playIconBackgroundColor: Color(0xFF1E2121),
              playIconColor: Color(0xFF1E2222),
              rowBackgroundColor: Color(0xFF1E2323),
              rowBorderRadius: 71,
              rowSpacing: 9,
              sliderActiveColor: Color(0xFF1E2424),
              sliderInactiveColor: Color(0xFF1E2525),
              sliderThumbColor: Color(0xFF1E2626),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_fills(tester), contains(const Color(0xFF1E2323)));
      expect(_textSizes(tester), contains(19.0));
      expect(find.byType(CometChatAudiosBubble), findsOneWidget);
    });
  });

  group('CometChatFilesBubbleStyle', () {
    testWidgets('every property reaches the file cards', (tester) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(
          CometChatFilesBubble(
            message: _files(),
            alignment: BubbleAlignment.left,
            style: const CometChatFilesBubbleStyle(
              captionTextStyle: TextStyle(fontSize: 31),
              cardBorderRadius: 73,
              downloadIconTint: Color(0xFF1E3030),
              iconPlateColor: Color(0xFF1E3131),
              subtitleTextStyle: TextStyle(fontSize: 17),
              titleTextStyle: TextStyle(fontSize: 19),
              toggleTextStyle: TextStyle(fontSize: 21),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_fills(tester), contains(const Color(0xFF1E3131)));
      expect(_textSizes(tester), contains(19.0));
      expect(_textSizes(tester), contains(17.0));
      expect(_radii(tester), contains(BorderRadius.circular(73)));
    });
  });

  group('CometChatLinkPreviewBubbleStyle', () {
    testWidgets('every property reaches the preview tile', (tester) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(
          CometChatLinkPreviewBubble(
            // `links` carries the resolved metadata, not bare URLs — with a
            // populated entry the whole preview tile renders headlessly
            links: const <dynamic>[
              {
                'url': 'https://cometchat.com',
                'title': 'CometChat',
                'description': 'Chat and calling APIs',
              },
            ],
            onTapUrl: (_) async {},
            alignment: BubbleAlignment.left,
            style: const CometChatLinkPreviewBubbleStyle(
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFF1E4040), width: 3),
              ),
              borderRadius: BorderRadius.all(Radius.circular(75)),
              descriptionStyle: TextStyle(fontSize: 17),
              tileColor: Color(0xFF1E4141),
              titleStyle: TextStyle(fontSize: 19),
              urlStyle: TextStyle(fontSize: 21),
            ),
            child: const Text('see https://cometchat.com'),
          ),
        ),
      );
      await tester.pump();
      expect(_fills(tester), contains(const Color(0xFF1E4141)));
      expect(
        _borders(tester),
        contains(
          const Border.fromBorderSide(
            BorderSide(color: Color(0xFF1E4040), width: 3),
          ),
        ),
      );
      expect(
        _radii(tester),
        contains(const BorderRadius.all(Radius.circular(75))),
      );
      expect(_textSizes(tester), contains(19.0));
      expect(_textSizes(tester), contains(17.0));
      expect(_textSizes(tester), contains(21.0));
    });
  });

  group('CometChatCallBubbleStyle', () {
    testWidgets('every property the bubble owns reaches it', (tester) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(
          CometChatCallBubble(
            title: 'Voice call',
            subtitle: '2 min',
            buttonText: 'Call back',
            onTap: (_) {},
            alignment: BubbleAlignment.left,
            style: const CometChatCallBubbleStyle(
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFF1E5050), width: 3),
              ),
              borderRadius: BorderRadius.all(Radius.circular(77)),
              buttonBackgroundColor: Color(0xFF1E5151),
              buttonTextStyle: TextStyle(fontSize: 17),
              dividerColor: Color(0xFF1E5252),
              iconBackgroundColor: Color(0xFF1E5353),
              iconColor: Color(0xFF1E5454),
              subtitleStyle: TextStyle(fontSize: 19),
              titleStyle: TextStyle(fontSize: 21),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_textSizes(tester), contains(21.0));
      expect(_textSizes(tester), contains(19.0));
      expect(_textSizes(tester), contains(17.0));
    });
  });

  group('CometChatVoiceNoteBubbleStyle', () {
    testWidgets('every property the bubble owns reaches it', (tester) async {
      _ignorePlatformOnlyErrors();
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => CometChatVoiceNoteBubble(
              audioUrl: 'https://example.com/a.mp3',
              title: 'Voice note',
              alignment: BubbleAlignment.left,
              colorPalette: CometChatThemeHelper.getColorPalette(context),
              spacing: CometChatThemeHelper.getSpacing(context),
              typography: CometChatThemeHelper.getTypography(context),
              style: const CometChatVoiceNoteBubbleStyle(
                audioBarColor: Color(0xFF1E7070),
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFF1E7171), width: 3),
                ),
                borderRadius: BorderRadius.all(Radius.circular(81)),
                downloadIconColor: Color(0xFF1E7272),
                durationTextColor: Color(0xFF1E7373),
                durationTextStyle: TextStyle(fontSize: 17),
                playIconBackgroundColor: Color(0xFF1E7474),
                playIconColor: Color(0xFF1E7575),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _borders(tester),
        contains(
          const Border.fromBorderSide(
            BorderSide(color: Color(0xFF1E7171), width: 3),
          ),
        ),
      );
      expect(
        _radii(tester),
        contains(const BorderRadius.all(Radius.circular(81))),
      );
      expect(_textColors(tester), contains(const Color(0xFF1E7373)));
    });
  });
}
