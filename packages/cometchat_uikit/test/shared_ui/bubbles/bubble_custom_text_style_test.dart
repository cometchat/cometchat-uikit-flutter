/// A text bubble's `textColor`/`textStyle` and a media caption's `textStyle`
/// must reach the message text itself.
///
/// The bubble puts its resolved style on the parent `TextSpan`, but
/// `FormatterUtils.buildTextSpan` gives every plain-text child a style of its
/// own, and a child's style wins over its parent's. Unless the bubble passes
/// its style down as `textStyle`, the children's palette defaults hide the
/// app's colour and size. These tests read the style set on the plain-text
/// child itself, which is what decides how the text looks.
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _red = Color(0xFFB00020);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

/// The style set on the [TextSpan] that holds [text] inside the first
/// [RichText] that renders it.
TextStyle? _styleOfSpan(WidgetTester tester, String text) {
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    TextStyle? found;
    rich.text.visitChildren((span) {
      if (span is TextSpan && (span.text ?? '').contains(text)) {
        found = span.style;
        return false;
      }
      return true;
    });
    if (found != null) return found;
  }
  return null;
}

void main() {
  group('CometChatTextBubble', () {
    for (final alignment in [BubbleAlignment.left, BubbleAlignment.right]) {
      testWidgets('textColor and textStyle reach the message text '
          '(${alignment.name})', (tester) async {
        await tester.pumpWidget(
          _host(
            CometChatTextBubble(
              text: 'Hello there',
              alignment: alignment,
              style: const CometChatTextBubbleStyle(
                textColor: _red,
                textStyle: TextStyle(fontSize: 30),
              ),
            ),
          ),
        );

        final style = _styleOfSpan(tester, 'Hello there');
        expect(style, isNotNull);
        expect(style!.color, _red);
        expect(style.fontSize, 30);
      });
    }
  });

  group('CometChatMediaCaption', () {
    for (final alignment in [BubbleAlignment.left, BubbleAlignment.right]) {
      testWidgets('textStyle reaches the caption text (${alignment.name})', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            CometChatMediaCaption(
              caption: 'A caption',
              alignment: alignment,
              textStyle: const TextStyle(color: _red, fontSize: 30),
            ),
          ),
        );

        final style = _styleOfSpan(tester, 'A caption');
        expect(style, isNotNull);
        expect(style!.color, _red);
        expect(style.fontSize, 30);
      });
    }
  });
}
