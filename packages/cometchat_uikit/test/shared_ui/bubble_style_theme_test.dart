import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The multi-attachment bubbles resolve their style class from the app theme
/// (ThemeExtension) and merge the widget-level `style:` on top — the same
/// convention as every other UIKit bubble. These tests pin that wiring.
void main() {
  MediaMessage fileMessage({int count = 1}) {
    final msg = MediaMessage(
      receiverUid: 'uid',
      receiverType: 'user',
      type: 'file',
      muid: 'm1',
    );
    msg.attachments = [
      for (var i = 0; i < count; i++)
        Attachment(
          'https://example.com/f$i.pdf',
          'f$i.pdf',
          'pdf',
          'application/pdf',
          1024,
        ),
    ];
    return msg;
  }

  Widget host(
    Widget child, {
    List<ThemeExtension<dynamic>> extensions = const [],
  }) {
    return MaterialApp(
      theme: ThemeData(extensions: extensions),
      home: Scaffold(body: Center(child: child)),
    );
  }

  /// The file card's Container whose decoration carries the card fill.
  Color? cardColorOf(WidgetTester tester) {
    final containers = tester.widgetList<Container>(find.byType(Container));
    for (final c in containers) {
      final d = c.decoration;
      if (d is BoxDecoration && d.color != null && d.borderRadius != null) {
        return d.color;
      }
    }
    return null;
  }

  testWidgets('FilesBubble reads CometChatFilesBubbleStyle from the theme', (
    tester,
  ) async {
    const themed = Color(0xFF123456);
    await tester.pumpWidget(
      host(
        CometChatFilesBubble(
          message: fileMessage(),
          alignment: BubbleAlignment.left,
        ),
        extensions: const [CometChatFilesBubbleStyle(backgroundColor: themed)],
      ),
    );
    await tester.pump();
    expect(cardColorOf(tester), themed);
  });

  testWidgets('widget-level style wins over the theme extension', (
    tester,
  ) async {
    const themed = Color(0xFF123456);
    const widgetLevel = Color(0xFF654321);
    await tester.pumpWidget(
      host(
        CometChatFilesBubble(
          message: fileMessage(),
          alignment: BubbleAlignment.left,
          style: const CometChatFilesBubbleStyle(backgroundColor: widgetLevel),
        ),
        extensions: const [CometChatFilesBubbleStyle(backgroundColor: themed)],
      ),
    );
    await tester.pump();
    expect(cardColorOf(tester), widgetLevel);
  });

  testWidgets(
    'a lone file card has a fully transparent fill (reads as the message)',
    (tester) async {
      await tester.pumpWidget(
        host(
          CometChatFilesBubble(
            message: fileMessage(),
            alignment: BubbleAlignment.left,
          ),
        ),
      );
      await tester.pump();
      expect(cardColorOf(tester), Colors.transparent);
    },
  );

  testWidgets('stacked file cards keep the translucent tint', (tester) async {
    await tester.pumpWidget(
      host(
        CometChatFilesBubble(
          message: fileMessage(count: 2),
          alignment: BubbleAlignment.left,
        ),
      ),
    );
    await tester.pump();
    expect(cardColorOf(tester), isNot(Colors.transparent));
  });

  testWidgets('FilesBubble applies themed card spacing between stacked cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        CometChatFilesBubble(
          message: fileMessage(count: 2),
          alignment: BubbleAlignment.left,
        ),
        extensions: const [CometChatFilesBubbleStyle(cardSpacing: 9)],
      ),
    );
    await tester.pump();
    // The gap between the two file cards uses the themed spacing.
    final gaps = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .where((s) => s.height == 9);
    expect(gaps.length, 1);
  });
}
