/// Behaviour pins for [CometChatFilesBubble] — the multi-attachment file
/// card-stack: the "+N more / Show less" collapse, the caption-only fallback,
/// the incoming/outgoing colour split, the "size • TYPE" meta line, and the
/// two tap targets (open the card, or the trailing ↓ "Save as").
///
///   flutter test test/shared_ui/bubbles/media/files_bubble_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

late List<MethodCall> _platformCalls;

const _uikitChannel = MethodChannel('cometchat_chat_uikit');

Attachment _attachment(
  String name, {
  String url = 'https://cdn.test/f',
  String extension = '',
  String mime = 'application/octet-stream',
  int size = 2048,
}) => Attachment(url, name, extension, mime, size);

MediaMessage _message(List<Attachment> attachments, {String? caption}) {
  final message = MediaMessage(
    receiverUid: 'peer',
    receiverType: ReceiverTypeConstants.user,
    type: MessageTypeConstants.file,
    muid: 'files-test',
  );
  message.attachments = attachments;
  message.caption = caption;
  return message;
}

Widget _host(
  MediaMessage message, {
  BubbleAlignment alignment = BubbleAlignment.left,
  CometChatFilesBubbleStyle? style,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: CometChatFilesBubble(
        message: message,
        alignment: alignment,
        style: style,
      ),
    ),
  ),
);

Iterable<String> _texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data)
    .whereType<String>();

/// The caption renders as a [RichText] (formatter pipeline), not a [Text].
String _captionText(WidgetTester tester) => tester
    .widget<RichText>(
      find.descendant(
        of: find.byType(CometChatMediaCaption),
        matching: find.byType(RichText),
      ),
    )
    .text
    .toPlainText();

Iterable<String> _assetNames(WidgetTester tester) => tester
    .widgetList<Image>(find.byType(Image))
    .map((i) => i.image)
    .whereType<AssetImage>()
    .map((a) => a.assetName);

/// The trailing "Save as" glyph on the card at [index].
Finder _downloadGlyph(int index) => find
    .byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == AssetConstants.download,
    )
    .at(index);

void main() {
  setUp(() {
    _platformCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_uikitChannel, (call) async {
          _platformCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_uikitChannel, null);
  });

  group('what gets rendered at all', () {
    testWidgets('no attachments and no caption renders nothing', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_message(const [])));
      await tester.pump();

      expect(find.byType(Text), findsNothing);
      expect(tester.getSize(find.byType(CometChatFilesBubble)), Size.zero);
    });

    testWidgets('a caption with no attachments still renders the caption', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(_message(const [], caption: 'the deck is attached')),
      );
      await tester.pump();

      expect(find.byType(CometChatMediaCaption), findsOneWidget);
      expect(_captionText(tester), 'the deck is attached');
    });

    testWidgets('a caption that is only whitespace is dropped', (tester) async {
      await tester.pumpWidget(
        _host(_message([_attachment('a.pdf')], caption: '   ')),
      );
      await tester.pump();

      expect(find.byType(CometChatMediaCaption), findsNothing);
      expect(_texts(tester), contains('a.pdf'));
    });

    testWidgets('attachments and a caption render both', (tester) async {
      await tester.pumpWidget(
        _host(_message([_attachment('a.pdf')], caption: 'have a look')),
      );
      await tester.pump();

      expect(find.byType(CometChatMediaCaption), findsOneWidget);
      expect(_captionText(tester), 'have a look');
      expect(_texts(tester), contains('a.pdf'));
    });
  });

  group('collapse toggle', () {
    testWidgets('three files show no toggle', (tester) async {
      await tester.pumpWidget(
        _host(_message([for (var i = 0; i < 3; i++) _attachment('doc$i.pdf')])),
      );
      await tester.pump();

      expect(find.text('Show less'), findsNothing);
      expect(_texts(tester).where((t) => t.endsWith('more')), isEmpty);
      expect(_texts(tester).where((t) => t.startsWith('doc')), hasLength(3));
    });

    testWidgets('six files collapse to three plus a "+3 more" toggle that '
        'expands and collapses again', (tester) async {
      await tester.pumpWidget(
        _host(_message([for (var i = 0; i < 6; i++) _attachment('doc$i.pdf')])),
      );
      await tester.pump();

      expect(_texts(tester).where((t) => t.startsWith('doc')), hasLength(3));
      expect(find.text('+3 more'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      await tester.tap(find.text('+3 more'));
      await tester.pumpAndSettle();

      expect(_texts(tester).where((t) => t.startsWith('doc')), hasLength(6));
      expect(find.text('Show less'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();

      expect(_texts(tester).where((t) => t.startsWith('doc')), hasLength(3));
      expect(find.text('+3 more'), findsOneWidget);
    });

    testWidgets('exactly four files collapse to three plus "+1 more"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(_message([for (var i = 0; i < 4; i++) _attachment('doc$i.pdf')])),
      );
      await tester.pump();

      expect(find.text('+1 more'), findsOneWidget);
      expect(_texts(tester).where((t) => t.startsWith('doc')), hasLength(3));
    });
  });

  group('the card itself', () {
    testWidgets('the meta line is "size • TYPE", with the type taken from the '
        'name and falling back to the declared extension', (tester) async {
      await tester.pumpWidget(
        _host(
          _message([
            _attachment('report.pdf', size: 0),
            _attachment('slides', extension: 'pptx', size: 512),
            _attachment('sheet.csv', size: 2048),
          ]),
        ),
      );
      await tester.pump();

      expect(_texts(tester), contains('0 B • PDF'));
      expect(_texts(tester), contains('512 B • PPTX'));
      expect(_texts(tester), contains('2 KB • CSV'));

      await tester.pumpWidget(
        _host(_message([_attachment('movie.mov', size: 5 * 1024 * 1024)])),
      );
      await tester.pump();
      expect(_texts(tester), contains('5.0 MB • MOV'));
    });

    testWidgets('a nameless attachment with an unknown type still renders a '
        'meta line rather than a blank row', (tester) async {
      await tester.pumpWidget(_host(_namelessMessage()));
      await tester.pump();

      expect(_texts(tester), contains('0 B • '));
    });

    testWidgets('outgoing and incoming cards colour the name differently', (
      tester,
    ) async {
      Color? nameColor(WidgetTester t) =>
          t.widget<Text>(find.text('a.pdf')).style?.color;

      await tester.pumpWidget(
        _host(
          _message([_attachment('a.pdf')]),
          alignment: BubbleAlignment.right,
        ),
      );
      await tester.pump();
      expect(nameColor(tester), Colors.white);

      await tester.pumpWidget(
        _host(
          _message([_attachment('a.pdf')]),
          alignment: BubbleAlignment.left,
        ),
      );
      await tester.pump();
      expect(nameColor(tester), isNot(Colors.white));
    });

    testWidgets('a lone file card has no tint; stacked cards do', (
      tester,
    ) async {
      Color? cardFill(WidgetTester t) {
        final c = t.widget<Container>(
          find
              .descendant(
                of: find.byType(InkWell),
                matching: find.byType(Container),
              )
              .first,
        );
        return (c.decoration as BoxDecoration?)?.color;
      }

      await tester.pumpWidget(_host(_message([_attachment('a.pdf')])));
      await tester.pump();
      expect(cardFill(tester), Colors.transparent);

      await tester.pumpWidget(
        _host(_message([_attachment('a.pdf'), _attachment('b.pdf')])),
      );
      await tester.pump();
      expect(cardFill(tester), isNot(Colors.transparent));
    });

    testWidgets('style overrides the card fill and the download tint', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          _message([_attachment('a.pdf')]),
          style: const CometChatFilesBubbleStyle(
            backgroundColor: Color(0xFF0A0B0C),
            downloadIconTint: Color(0xFF0D0E0F),
          ),
        ),
      );
      await tester.pump();

      final fills = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.color ?? (c.decoration as BoxDecoration?)?.color);
      expect(fills, contains(const Color(0xFF0A0B0C)));

      final glyph = tester
          .widgetList<Image>(find.byType(Image))
          .firstWhere(
            (i) =>
                i.image is AssetImage &&
                (i.image as AssetImage).assetName == AssetConstants.download,
          );
      expect(glyph.color, const Color(0xFF0D0E0F));
    });
  });

  group('tap targets', () {
    testWidgets('the trailing glyph asks the platform to save the file, '
        'without opening it', (tester) async {
      await tester.pumpWidget(
        _host(
          _message([
            _attachment(
              'report.pdf',
              url: 'https://cdn.test/report.pdf',
              mime: 'application/pdf',
            ),
          ]),
        ),
      );
      await tester.pump();

      await tester.tap(_downloadGlyph(0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        _platformCalls.map((c) => c.method),
        contains('saveFileWithPicker'),
      );
      final args =
          _platformCalls
                  .firstWhere((c) => c.method == 'saveFileWithPicker')
                  .arguments
              as Map;
      expect(args['url'], 'https://cdn.test/report.pdf');
      expect(args['fileName'], 'report.pdf');
      expect(args['mimeType'], 'application/pdf');
      expect(_platformCalls.map((c) => c.method), isNot(contains('open_file')));
    });

    testWidgets('an attachment with no URL is inert on both taps', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(_message([_attachment('report.pdf', url: '')])),
      );
      await tester.pump();

      await tester.tap(_downloadGlyph(0));
      await tester.pump();
      await tester.tap(find.text('report.pdf'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(_platformCalls, isEmpty);
    });

    testWidgets('a card whose file cannot be fetched is never handed to the '
        'system opener', (tester) async {
      // There is no download directory on a VM test host, so the fetch fails
      // and the card must not call `open_file` with a path it does not have.
      await tester.pumpWidget(
        _host(
          _message([
            _attachment('report.pdf', url: 'https://cdn.test/report.pdf'),
          ]),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('report.pdf'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(_platformCalls.map((c) => c.method), isNot(contains('open_file')));
      // And it is back to an idle card, not a stuck spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_assetNames(tester), contains(AssetConstants.download));
    });
  });

  group('width', () {
    testWidgets('never exceeds maxWidth, and shrinks to 72% of a narrow '
        'screen', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(_message([_attachment('a.pdf')])));
      await tester.pump();
      expect(tester.getSize(find.byType(CometChatFilesBubble)).width, 280);

      tester.view.physicalSize = const Size(300, 800);
      await tester.pumpWidget(_host(_message([_attachment('a.pdf')])));
      await tester.pump();
      expect(
        tester.getSize(find.byType(CometChatFilesBubble)).width,
        closeTo(300 * 0.72, 0.01),
      );
    });
  });
}

/// A message whose single attachment has no name and no declared extension —
/// the degenerate case the meta line still has to survive.
MediaMessage _namelessMessage() =>
    _message([_attachment('', url: 'https://cdn.test/x', size: 0)]);
