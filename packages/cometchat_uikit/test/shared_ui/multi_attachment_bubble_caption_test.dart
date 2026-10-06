import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A media message's caption is parsed independently of its attachments, so a
/// message can arrive with a caption and no attachments. Every multi-attachment
/// bubble used to bail out on `attachments.isEmpty` before building the
/// caption, rendering a zero-size bubble and silently dropping the user's text.
/// These tests pin that the caption survives, and that a genuinely empty
/// message still collapses.
void main() {
  MediaMessage mediaMessage({
    required String type,
    int attachmentCount = 1,
    String? caption,
  }) {
    final msg = MediaMessage(
      receiverUid: 'uid',
      receiverType: 'user',
      type: type,
      muid: 'm1',
    );
    msg.attachments = [
      for (var i = 0; i < attachmentCount; i++)
        Attachment(
          'https://example.com/f$i.bin',
          'f$i.bin',
          'bin',
          'application/octet-stream',
          1024,
        ),
    ];
    msg.caption = caption;
    return msg;
  }

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  /// Each multi-attachment bubble, built for a given message.
  final builders = <String, Widget Function(MediaMessage)>{
    'images': (m) =>
        CometChatImagesBubble(message: m, alignment: BubbleAlignment.left),
    'videos': (m) =>
        CometChatVideosBubble(message: m, alignment: BubbleAlignment.left),
    'audios': (m) =>
        CometChatAudiosBubble(message: m, alignment: BubbleAlignment.left),
    'files': (m) =>
        CometChatFilesBubble(message: m, alignment: BubbleAlignment.left),
  };

  for (final entry in builders.entries) {
    final name = entry.key;
    final build = entry.value;

    testWidgets('$name bubble keeps the caption when attachments are missing', (
      tester,
    ) async {
      final msg = mediaMessage(
        type: name,
        attachmentCount: 0,
        caption: 'the caption must survive',
      );

      await tester.pumpWidget(host(build(msg)));
      await tester.pump();

      expect(
        find.textContaining('the caption must survive', findRichText: true),
        findsOneWidget,
        reason: 'an attachment-less media message still carries user text',
      );
    });

    testWidgets('$name bubble collapses when there is no caption either', (
      tester,
    ) async {
      final msg = mediaMessage(type: name, attachmentCount: 0);

      await tester.pumpWidget(host(build(msg)));
      await tester.pump();

      final size = tester.getSize(find.byType(SizedBox).first);
      expect(
        size,
        Size.zero,
        reason: 'nothing to show — the bubble should take no space',
      );
    });

    testWidgets('$name bubble treats a whitespace-only caption as empty', (
      tester,
    ) async {
      final msg = mediaMessage(type: name, attachmentCount: 0, caption: '   ');

      await tester.pumpWidget(host(build(msg)));
      await tester.pump();

      final size = tester.getSize(find.byType(SizedBox).first);
      expect(size, Size.zero);
    });
  }
}
