/// The bubble factories — Track 3 TEST3 / construction coverage (ENG-38684).
///
/// Six exported factories that no test had ever constructed. They are the
/// layer that decides which bubble a message becomes: the message list looks
/// up a factory by `category_type`, hands it the message and an alignment,
/// and renders whatever comes back. Every custom bubble an integrator
/// registers goes through the same lookup.
///
/// Two things are worth asserting and neither is the widget's own appearance,
/// which the bubble prop matrices already cover:
///
///   * the key derivation, because `deleted` has to win over the message's
///     own category and type or a deleted message renders its old content;
///   * what each factory pulls off the message and passes down, because a
///     field dropped here is a bubble that renders empty for a message that
///     had the data all along.
///
///   flutter test test/shared_ui/bubbles/bubble_factories_test.dart
library;

// CometChatFileBubble is deprecated but is still what FileBubbleFactory
// builds, so these cases have to name it.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

final _sentAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

class _FakeUser extends Fake implements User {
  _FakeUser(this.uid);
  @override
  final String uid;
  @override
  String get name => 'Alice';
}

class _FakeAttachment extends Fake implements Attachment {
  _FakeAttachment({
    this.fileUrl = 'https://example.com/report.pdf',
    this.fileName = 'report.pdf',
  });

  @override
  final String fileUrl;
  @override
  final String fileName;
  @override
  String get fileMimeType => 'application/pdf';
  @override
  String get fileExtension => 'pdf';
  @override
  int get fileSize => 2400000;
}

class _FakeTextMessage extends Fake implements TextMessage {
  _FakeTextMessage({
    this.text = 'Hello',
    this.category = 'message',
    this.type = 'text',
    this.deletedAt,
  });

  @override
  final String text;
  @override
  int get id => 1;
  @override
  final String category;
  @override
  final String type;
  @override
  final DateTime? deletedAt;
  @override
  User? get sender => _FakeUser('u1');
  @override
  DateTime? get sentAt => _sentAt;
  @override
  Map<String, dynamic>? get metadata => null;
}

class _FakeMediaMessage extends Fake implements MediaMessage {
  _FakeMediaMessage({
    this.type = 'file',
    this.category = 'message',
    this.attachment,
    this.deletedAt,
  });

  @override
  final String type;
  @override
  int get id => 2;
  @override
  final String category;
  @override
  final Attachment? attachment;
  @override
  Map<String, dynamic>? get metadata => null;
  @override
  final DateTime? deletedAt;
  @override
  User? get sender => _FakeUser('u1');
  @override
  DateTime? get sentAt => _sentAt;
}

/// Pumps whatever [factory] builds, resolving the theme from the context the
/// way the message list does.
Future<void> _pumpFactory(
  WidgetTester tester,
  Widget Function(BuildContext context) build,
) async {
  await mockNetworkImagesFor(
    () => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Builder(builder: build)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  // ---------------------------------------------------------------------------
  group('BubbleFactory key derivation', () {
    test('a live message keys on category and type', () {
      expect(
        BubbleFactory.getFactoryKey(
          _FakeTextMessage(category: 'message', type: 'text'),
        ),
        'message_text',
      );
      expect(
        BubbleFactory.getFactoryKey(
          _FakeMediaMessage(category: 'message', type: 'image'),
        ),
        'message_image',
      );
    });

    test('a deleted message keys on `deleted`, whatever it used to be', () {
      // This is the branch that matters: without it a deleted text message
      // would still resolve to the text factory and re-render its content.
      expect(
        BubbleFactory.getFactoryKey(
          _FakeTextMessage(
            category: 'message',
            type: 'text',
            deletedAt: _sentAt,
          ),
        ),
        'deleted',
      );
      expect(
        BubbleFactory.getFactoryKey(
          _FakeMediaMessage(type: 'image', deletedAt: _sentAt),
        ),
        'deleted',
      );
    });

    test('createKey builds the same shape the lookup expects', () {
      expect(BubbleFactory.createKey('message', 'text'), 'message_text');
      expect(
        BubbleFactory.createKey('message', 'text'),
        BubbleFactory.getFactoryKey(_FakeTextMessage()),
      );
    });

    test('a custom category and type produce a registrable key', () {
      expect(
        BubbleFactory.createKey('custom', 'poll'),
        BubbleFactory.getFactoryKey(
          _FakeTextMessage(category: 'custom', type: 'poll'),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('TextBubbleFactory', () {
    testWidgets('renders the message text', (tester) async {
      final factory = TextBubbleFactory();

      await _pumpFactory(
        tester,
        (context) => factory.build(
          context,
          _FakeTextMessage(text: 'Hello there'),
          BubbleAlignment.left,
        ),
      );

      expect(find.byType(CometChatTextBubble), findsOneWidget);
      expect(
        tester
            .widget<CometChatTextBubble>(find.byType(CometChatTextBubble))
            .text,
        'Hello there',
      );
    });

    testWidgets('passes the alignment straight through', (tester) async {
      final factory = TextBubbleFactory();

      await _pumpFactory(
        tester,
        (context) =>
            factory.build(context, _FakeTextMessage(), BubbleAlignment.right),
      );

      expect(
        tester
            .widget<CometChatTextBubble>(find.byType(CometChatTextBubble))
            .alignment,
        BubbleAlignment.right,
      );
    });

    testWidgets('picks the outgoing style on the right and the incoming '
        'style on the left', (tester) async {
      const incoming = CometChatTextBubbleStyle(
        backgroundColor: Color(0xFF111111),
      );
      const outgoing = CometChatTextBubbleStyle(
        backgroundColor: Color(0xFF222222),
      );
      final factory = TextBubbleFactory(
        incomingStyle: incoming,
        outgoingStyle: outgoing,
      );

      await _pumpFactory(
        tester,
        (context) =>
            factory.build(context, _FakeTextMessage(), BubbleAlignment.left),
      );
      expect(
        tester
            .widget<CometChatTextBubble>(find.byType(CometChatTextBubble))
            .style
            ?.backgroundColor,
        const Color(0xFF111111),
      );

      await _pumpFactory(
        tester,
        (context) =>
            factory.build(context, _FakeTextMessage(), BubbleAlignment.right),
      );
      expect(
        tester
            .widget<CometChatTextBubble>(find.byType(CometChatTextBubble))
            .style
            ?.backgroundColor,
        const Color(0xFF222222),
      );
    });

    testWidgets(
      'an ordinary message keeps its formatters and scales no emoji',
      (tester) async {
        final factory = TextBubbleFactory();

        await _pumpFactory(
          tester,
          (context) => factory.build(
            context,
            _FakeTextMessage(text: 'Just words'),
            BubbleAlignment.left,
          ),
        );

        final bubble = tester.widget<CometChatTextBubble>(
          find.byType(CometChatTextBubble),
        );
        expect(bubble.emojiCount, 0);
        // FormatterUtils.ensureMarkdownFormatter always supplies at least the
        // markdown formatter, so a text message is never handed a null list.
        expect(bubble.formatters, isNotNull);
      },
    );

    testWidgets('an emoji-only message is scaled and its formatters dropped', (
      tester,
    ) async {
      // Both halves matter: running the markdown formatter over scaled emoji
      // is what the null is avoiding.
      final factory = TextBubbleFactory();

      await _pumpFactory(
        tester,
        (context) => factory.build(
          context,
          _FakeTextMessage(text: '😀😀'),
          BubbleAlignment.left,
        ),
      );

      final bubble = tester.widget<CometChatTextBubble>(
        find.byType(CometChatTextBubble),
      );
      expect(bubble.emojiCount, 2);
      expect(bubble.formatters, isNull);
    });

    testWidgets('an emoji run past the scaling limit renders unscaled', (
      tester,
    ) async {
      final tooMany = '😀' * (EmojiUtils.maxScaledCount + 1);
      final factory = TextBubbleFactory();

      await _pumpFactory(
        tester,
        (context) => factory.build(
          context,
          _FakeTextMessage(text: tooMany),
          BubbleAlignment.left,
        ),
      );

      final bubble = tester.widget<CometChatTextBubble>(
        find.byType(CometChatTextBubble),
      );
      expect(bubble.emojiCount, 0);
      expect(bubble.formatters, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('DeletedBubbleFactory', () {
    testWidgets('renders the localized deleted-message label', (tester) async {
      final factory = DeletedBubbleFactory();

      await _pumpFactory(
        tester,
        (context) => factory.build(
          context,
          _FakeTextMessage(deletedAt: _sentAt),
          BubbleAlignment.left,
        ),
      );

      expect(find.byIcon(Icons.block), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('an explicit text style wins over the derived one', (
      tester,
    ) async {
      const style = TextStyle(fontSize: 14, color: Color(0xFF00FF00));
      final factory = DeletedBubbleFactory(textStyle: style);

      await _pumpFactory(
        tester,
        (context) => factory.build(
          context,
          _FakeTextMessage(deletedAt: _sentAt),
          BubbleAlignment.left,
        ),
      );

      expect(tester.widget<Text>(find.byType(Text)).style, style);
    });

    testWidgets('FIXED — the label shrinks instead of overflowing the row', (
      tester,
    ) async {
      // The factory builds its own Row — Icon, gap, Text — and the Text had no
      // flex factor, so it could not shrink and the Row overflowed.
      //
      // CometChatDeletedBubble had exactly this layout and exactly this bug;
      // 6.2.0 fixed it by wrapping the label in a Flexible (A11Y3). The
      // factory was a second copy of the layout the fix never reached, which
      // mattered because the message list renders deleted messages through the
      // factory. ENG-39099.
      //
      // A narrow viewport is the cheapest way to show it; a large system text
      // size or a longer localized string does the same on a normal phone,
      // which is why DeletedBubbleFactory now also sits in the A11Y3 harness.
      final factory = DeletedBubbleFactory();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 60,
              child: Builder(
                builder: (context) => factory.build(
                  context,
                  _FakeTextMessage(deletedAt: _sentAt),
                  BubbleAlignment.left,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Flexible), findsOneWidget);
    });

    testWidgets('an explicit icon colour wins over the derived one', (
      tester,
    ) async {
      final factory = DeletedBubbleFactory(iconColor: const Color(0xFFFF0000));

      await _pumpFactory(
        tester,
        (context) => factory.build(
          context,
          _FakeTextMessage(deletedAt: _sentAt),
          BubbleAlignment.right,
        ),
      );

      expect(
        tester.widget<Icon>(find.byIcon(Icons.block)).color,
        const Color(0xFFFF0000),
      );
    });

    testWidgets('outgoing and incoming derive different colours', (
      tester,
    ) async {
      final factory = DeletedBubbleFactory();

      await _pumpFactory(
        tester,
        (context) => factory.build(
          context,
          _FakeTextMessage(deletedAt: _sentAt),
          BubbleAlignment.left,
        ),
      );
      final incoming = tester.widget<Icon>(find.byIcon(Icons.block)).color;

      await _pumpFactory(
        tester,
        (context) => factory.build(
          context,
          _FakeTextMessage(deletedAt: _sentAt),
          BubbleAlignment.right,
        ),
      );
      final outgoing = tester.widget<Icon>(find.byIcon(Icons.block)).color;

      expect(incoming, isNotNull);
      expect(outgoing, isNotNull);
      expect(incoming, isNot(outgoing));
    });
  });

  // ---------------------------------------------------------------------------
  group('FileBubbleFactory', () {
    testWidgets('unpacks the attachment onto the bubble', (tester) async {
      final factory = FileBubbleFactory();
      final message = _FakeMediaMessage(attachment: _FakeAttachment());

      await _pumpFactory(
        tester,
        (context) => factory.build(context, message, BubbleAlignment.left),
      );

      final bubble = tester.widget<CometChatFileBubble>(
        find.byType(CometChatFileBubble),
      );
      expect(bubble.title, 'report.pdf');
      expect(bubble.fileUrl, 'https://example.com/report.pdf');
      expect(bubble.fileMimeType, 'application/pdf');
      expect(bubble.fileExtension, 'pdf');
      expect(bubble.fileSize, 2400000);
      expect(bubble.id, message.id);
      expect(bubble.dateTime, _sentAt);
    });

    testWidgets('a message with no attachment still builds a bubble', (
      tester,
    ) async {
      // The whole attachment is nullable on the SDK model, so this is a
      // payload the factory has to survive rather than throw on.
      final factory = FileBubbleFactory();

      await _pumpFactory(
        tester,
        (context) =>
            factory.build(context, _FakeMediaMessage(), BubbleAlignment.left),
      );

      final bubble = tester.widget<CometChatFileBubble>(
        find.byType(CometChatFileBubble),
      );
      expect(bubble.fileUrl, isNull);
      expect(bubble.title, isNull);
    });

    testWidgets('the style is handed to the bubble', (tester) async {
      const style = CometChatFileBubbleStyle(titleColor: Color(0xFF0C5F66));
      final factory = FileBubbleFactory(style: style);

      await _pumpFactory(
        tester,
        (context) => factory.build(
          context,
          _FakeMediaMessage(attachment: _FakeAttachment()),
          BubbleAlignment.left,
        ),
      );

      expect(
        tester
            .widget<CometChatFileBubble>(find.byType(CometChatFileBubble))
            .style
            ?.titleColor,
        const Color(0xFF0C5F66),
      );
    });

    testWidgets('downloadIcon replaces the bubble\'s download button icon', (
      tester,
    ) async {
      const tint = Color(0xFF7A1B3C);
      Future<void> pump(FileBubbleFactory factory) => _pumpFactory(
        tester,
        (context) => factory.build(
          context,
          _FakeMediaMessage(attachment: _FakeAttachment()),
          BubbleAlignment.left,
        ),
      );

      await pump(
        FileBubbleFactory(
          style: const CometChatFileBubbleStyle(downloadIconTint: tint),
        ),
      );
      expect(find.byIcon(Icons.cloud_download), findsNothing);

      await pump(
        FileBubbleFactory(
          style: const CometChatFileBubbleStyle(downloadIconTint: tint),
          downloadIcon: const Icon(Icons.cloud_download),
        ),
      );
      expect(find.byIcon(Icons.cloud_download), findsOneWidget);
      // Tinted like the default icon it replaces.
      expect(
        IconTheme.of(tester.element(find.byIcon(Icons.cloud_download))).color,
        tint,
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('ImageBubbleFactory', () {
    testWidgets('takes the image url off the attachment', (tester) async {
      final factory = ImageBubbleFactory();

      await _pumpFactory(
        tester,
        (context) => factory.build(
          context,
          _FakeMediaMessage(
            type: 'image',
            attachment: _FakeAttachment(
              fileUrl: 'https://example.com/photo.png',
              fileName: 'photo.png',
            ),
          ),
          BubbleAlignment.left,
        ),
      );

      expect(
        tester
            .widget<CometChatImageBubble>(find.byType(CometChatImageBubble))
            .imageUrl,
        'https://example.com/photo.png',
      );
    });

    testWidgets('carries the placeholder and its package through', (
      tester,
    ) async {
      final factory = ImageBubbleFactory(
        placeholderImage: 'assets/placeholder.png',
        placeholderImagePackageName: 'my_package',
      );

      await _pumpFactory(
        tester,
        (context) => factory.build(
          context,
          _FakeMediaMessage(type: 'image', attachment: _FakeAttachment()),
          BubbleAlignment.left,
        ),
      );

      final bubble = tester.widget<CometChatImageBubble>(
        find.byType(CometChatImageBubble),
      );
      expect(bubble.placeholderImage, 'assets/placeholder.png');
      expect(bubble.placeHolderImagePackageName, 'my_package');
    });

    testWidgets('an onClick supplied to the factory reaches the bubble', (
      tester,
    ) async {
      var tapped = false;
      final factory = ImageBubbleFactory(onClick: () => tapped = true);

      await _pumpFactory(
        tester,
        (context) => factory.build(
          context,
          _FakeMediaMessage(type: 'image', attachment: _FakeAttachment()),
          BubbleAlignment.left,
        ),
      );

      tester
          .widget<CometChatImageBubble>(find.byType(CometChatImageBubble))
          .onClick
          ?.call();
      expect(tapped, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('VideoBubbleFactory', () {
    testWidgets('takes the video url off the attachment', (tester) async {
      final factory = VideoBubbleFactory();

      await _pumpFactory(
        tester,
        (context) => factory.build(
          context,
          _FakeMediaMessage(
            type: 'video',
            attachment: _FakeAttachment(
              fileUrl: 'https://example.com/clip.mp4',
              fileName: 'clip.mp4',
            ),
          ),
          BubbleAlignment.left,
        ),
      );

      expect(
        tester
            .widget<CometChatVideoBubble>(find.byType(CometChatVideoBubble))
            .videoUrl,
        'https://example.com/clip.mp4',
      );
    });

    testWidgets('a custom play icon reaches the bubble', (tester) async {
      const playIcon = Icon(Icons.play_circle);
      final factory = VideoBubbleFactory(playIcon: playIcon);

      await _pumpFactory(
        tester,
        (context) => factory.build(
          context,
          _FakeMediaMessage(type: 'video', attachment: _FakeAttachment()),
          BubbleAlignment.left,
        ),
      );

      expect(
        tester
            .widget<CometChatVideoBubble>(find.byType(CometChatVideoBubble))
            .playIcon,
        same(playIcon),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('AudioBubbleFactory', () {
    testWidgets('unpacks the attachment and threads the theme through', (
      tester,
    ) async {
      final factory = AudioBubbleFactory();
      final message = _FakeMediaMessage(
        type: 'audio',
        attachment: _FakeAttachment(
          fileUrl: 'https://example.com/note.m4a',
          fileName: 'note.m4a',
        ),
      );

      await _pumpFactory(
        tester,
        (context) => factory.build(
          context,
          message,
          BubbleAlignment.right,
          colorPalette: CometChatThemeHelper.getColorPalette(context),
          typography: CometChatThemeHelper.getTypography(context),
          spacing: CometChatThemeHelper.getSpacing(context),
        ),
      );

      final player = tester.widget<CometChatAudioPlayer>(
        find.byType(CometChatAudioPlayer),
      );
      expect(player.audioUrl, 'https://example.com/note.m4a');
      expect(player.title, 'note.m4a');
      expect(player.id, message.id);
      expect(player.alignment, BubbleAlignment.right);
      // The audio player is one of the few bubbles that takes its theme as
      // parameters rather than reading the context, so the factory has to
      // forward all three.
      expect(player.colorPalette, isNotNull);
      expect(player.typography, isNotNull);
      expect(player.spacing, isNotNull);
    });

    testWidgets('custom play and pause icons reach the player', (tester) async {
      const play = Icon(Icons.play_arrow);
      const pause = Icon(Icons.pause);
      final factory = AudioBubbleFactory(playIcon: play, pauseIcon: pause);

      await _pumpFactory(
        tester,
        (context) => factory.build(
          context,
          _FakeMediaMessage(type: 'audio', attachment: _FakeAttachment()),
          BubbleAlignment.left,
        ),
      );

      final player = tester.widget<CometChatAudioPlayer>(
        find.byType(CometChatAudioPlayer),
      );
      expect(player.playIcon, same(play));
      expect(player.pauseIcon, same(pause));
    });
  });
}
