/// The composer's two small pure helpers: the reply-preview icon and the
/// message-type subtitle both the reply and edit previews show.
///
///   flutter test test/chat_ui/message_composer/composer_utils_test.dart
library;

import 'package:cometchat_chat_uikit/chat_ui/src/message_composer/utils/composer_attachment_utils.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) {
          ctx = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return ctx;
}

MediaMessage _media(String type) =>
    MediaMessage(receiverUid: 'bob', receiverType: 'user', type: type);

void main() {
  group('ComposerUtils.getReplyIcon', () {
    testWidgets('a text message gets no icon at all', (tester) async {
      final ctx = await _context(tester);
      final text = TextMessage(
        text: 'hi',
        receiverUid: 'bob',
        receiverType: 'user',
        type: CometChatMessageType.text,
      );
      expect(ComposerUtils.getReplyIcon(text, ctx, null), isNull);
    });

    testWidgets('each media kind gets its own glyph, in the given colour', (
      tester,
    ) async {
      final ctx = await _context(tester);
      const tint = Color(0xFF123456);

      IconData? iconFor(String type) {
        final widget = ComposerUtils.getReplyIcon(_media(type), ctx, tint);
        return (widget as Icon?)?.icon;
      }

      expect(iconFor(CometChatMessageType.image), Icons.image_outlined);
      expect(iconFor(CometChatMessageType.video), Icons.videocam_outlined);
      expect(iconFor(CometChatMessageType.audio), Icons.mic_outlined);
      expect(
        iconFor(CometChatMessageType.file),
        Icons.insert_drive_file_outlined,
      );
      // Anything else still gets a generic paperclip rather than nothing.
      expect(iconFor('hologram'), Icons.attachment_outlined);

      final icon =
          ComposerUtils.getReplyIcon(
                _media(CometChatMessageType.image),
                ctx,
                tint,
              )
              as Icon;
      expect(icon.color, tint);
      expect(icon.size, 14);
    });
  });

  group('ComposerAttachmentUtils.getMessageTypeToSubtitle', () {
    testWidgets('every known message type maps to its localized label', (
      tester,
    ) async {
      final ctx = await _context(tester);
      final t = Translations.of(ctx);

      String subtitle(String type) =>
          ComposerAttachmentUtils.getMessageTypeToSubtitle(type, ctx);

      expect(subtitle(MessageTypeConstants.text), t.text);
      expect(subtitle(MessageTypeConstants.image), t.messageImage);
      expect(subtitle(MessageTypeConstants.video), t.messageVideo);
      expect(subtitle(MessageTypeConstants.file), t.messageFile);
      expect(subtitle(MessageTypeConstants.audio), t.messageAudio);
      expect(subtitle(ExtensionType.extensionPoll), t.poll);
      expect(subtitle(ExtensionType.document), t.collaborativeDocument);
      expect(subtitle(ExtensionType.whiteboard), t.collaborativeWhiteboard);
      expect(subtitle(ExtensionType.sticker), t.customMessageSticker);

      // Every label is real copy, not the raw type name.
      for (final type in [
        MessageTypeConstants.text,
        MessageTypeConstants.image,
        MessageTypeConstants.video,
        MessageTypeConstants.file,
        MessageTypeConstants.audio,
      ]) {
        expect(subtitle(type), isNotEmpty);
      }
      expect(subtitle(MessageTypeConstants.image), isNot('image'));
    });

    testWidgets('an unknown type falls back to the type string itself', (
      tester,
    ) async {
      final ctx = await _context(tester);
      expect(
        ComposerAttachmentUtils.getMessageTypeToSubtitle('hologram', ctx),
        'hologram',
      );
      expect(ComposerAttachmentUtils.getMessageTypeToSubtitle('', ctx), '');
    });
  });
}
