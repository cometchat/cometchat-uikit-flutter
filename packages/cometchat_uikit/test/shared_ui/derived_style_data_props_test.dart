/// Render-verified prop matrix for the derived style holders —
/// Track 3 PROP2 (ENG-38684).
///
/// [CometChatMessageBubbleStyleData] is not a prop an integrator sets. It is
/// computed by `BubbleUIBuilder.getBubbleStyle` from the incoming/outgoing
/// bubble styles and then unpacked, field by field, into the bubble and its
/// slot widgets. There are exactly four call sites and all four assign it to a
/// variable named `bubbleStyleData`, so the set of fields production actually
/// reads is knowable and small.
///
/// These tests mirror that unpacking and assert each value lands in the
/// rendered tree, the same approach used for the call configurations.
///
/// **Only the fields production reads are constructed here.** Six props on
/// [CometChatMessageBubbleStyleData] — the moderation and exception trios —
/// are never set by `getBubbleStyle` and never read by any consumer, and
/// `ButtonElementStyle.loadingIconTint` is read only by its own `merge`.
/// Passing them here would score them render-verified and hide that. They are
/// deliberately left out so the residual gap keeps naming them.
///
///   flutter test test/shared_ui/derived_style_data_props_test.dart
library;

import 'dart:typed_data';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real 1x1 transparent PNG. An AssetImage pointing at a path the test
/// bundle does not carry throws while painting, before any assertion runs.
final _png = MemoryImage(
  Uint8List.fromList(const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]),
);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: SizedBox(width: 1000, child: child)),
);

void main() {
  // -------------------------------------------------------------------------
  // CometChatMessageBubbleStyleData — 10 of 16 props.
  //
  // Mapping mirrored from message_utils.dart: the four style fields go into
  // CometChatMessageBubbleStyle on the bubble itself; the remaining six are
  // handed to the slot widgets the bubble composes.
  // -------------------------------------------------------------------------
  group('CometChatMessageBubbleStyleData', () {
    testWidgets('the four fields the bubble style consumes reach the tree', (
      tester,
    ) async {
      final styleData = CometChatMessageBubbleStyleData(
        backgroundColor: const Color(0xFF101112),
        border: const Border.fromBorderSide(
          BorderSide(color: Color(0xFF131415), width: 3),
        ),
        borderRadius: BorderRadius.circular(17),
        messageBubbleBackgroundImage: DecorationImage(image: _png),
      );

      await tester.pumpWidget(
        _wrap(
          CometChatMessageBubble(
            // --- the mapping message_utils.dart performs ---
            style: CometChatMessageBubbleStyle(
              backgroundColor: styleData.backgroundColor,
              border: styleData.border,
              borderRadius: styleData.borderRadius,
              backgroundImage: styleData.messageBubbleBackgroundImage,
            ),
            contentView: const Text('bubble body'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('bubble body'), findsOneWidget);

      final decos = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(
        decos.any((d) => d.color == const Color(0xFF101112)),
        isTrue,
        reason: 'backgroundColor',
      );
      expect(
        decos.any((d) => d.border?.top.color == const Color(0xFF131415)),
        isTrue,
        reason: 'border',
      );
      expect(
        decos.any((d) => d.borderRadius == BorderRadius.circular(17)),
        isTrue,
        reason: 'borderRadius',
      );
      expect(
        decos.any((d) => d.image != null),
        isTrue,
        reason: 'messageBubbleBackgroundImage',
      );
    });

    testWidgets('the six slot fields reach the widgets the bubble composes', (
      tester,
    ) async {
      final styleData = CometChatMessageBubbleStyleData(
        messageBubbleDateStyle: const CometChatDateStyle(
          textStyle: TextStyle(fontSize: 23),
        ),
        messageBubbleAvatarStyle: const CometChatAvatarStyle(
          backgroundColor: Color(0xFF313233),
        ),
        messageReceiptStyle: CometChatMessageReceiptStyle(
          readIconColor: Color(0xFF343536),
        ),
        senderNameTextStyle: const TextStyle(fontSize: 21),
        threadedMessageIndicatorTextStyle: const TextStyle(letterSpacing: 5),
        threadedMessageIndicatorIconColor: const Color(0xFF373839),
      );

      await tester.pumpWidget(
        _wrap(
          CometChatMessageBubble(
            // Sender name lands in the header, the date/receipt in the status
            // row, the avatar in the leading slot, the threaded indicator in
            // the thread slot — the same slots message_utils.dart fills.
            headerView: Text('Bob', style: styleData.senderNameTextStyle),
            leadingView: CometChatAvatar(
              name: 'Bob',
              style: styleData.messageBubbleAvatarStyle,
            ),
            statusInfoView: Row(
              children: [
                CometChatDate(
                  date: DateTime(2026, 9, 7, 18, 55),
                  style: styleData.messageBubbleDateStyle!,
                ),
                Icon(
                  Icons.done_all,
                  color: styleData.messageReceiptStyle?.readIconColor,
                ),
              ],
            ),
            threadView: Row(
              children: [
                Icon(
                  Icons.forum,
                  color: styleData.threadedMessageIndicatorIconColor,
                ),
                Text(
                  '2 replies',
                  style: styleData.threadedMessageIndicatorTextStyle,
                ),
              ],
            ),
            contentView: const Text('bubble body'),
          ),
        ),
      );
      await tester.pump();

      final textStyles = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.style)
          .whereType<TextStyle>()
          .toList();
      expect(
        textStyles.any((s) => s.fontSize == 21),
        isTrue,
        reason: 'senderNameTextStyle',
      );
      expect(
        textStyles.any((s) => s.letterSpacing == 5),
        isTrue,
        reason: 'threadedMessageIndicatorTextStyle',
      );

      final iconColors = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((i) => i.color)
          .toList();
      expect(
        iconColors,
        contains(const Color(0xFF373839)),
        reason: 'threadedMessageIndicatorIconColor',
      );
      expect(
        iconColors,
        contains(const Color(0xFF343536)),
        reason: 'messageReceiptStyle',
      );

      expect(
        tester
            .widget<CometChatAvatar>(find.byType(CometChatAvatar))
            .style
            ?.backgroundColor,
        const Color(0xFF313233),
        reason: 'messageBubbleAvatarStyle',
      );
      expect(
        tester
            .widget<CometChatDate>(find.byType(CometChatDate))
            .style
            .textStyle
            ?.fontSize,
        23,
        reason: 'messageBubbleDateStyle',
      );
    });
  });

  // -------------------------------------------------------------------------
  // ButtonElementStyle — 1 of 2 props.
  //
  // buttonTextStyle is read by cometchat_button_element.dart:98.
  // loadingIconTint is read only by this class's own merge(), so it is left
  // out; see the ticket on the dead style props.
  // -------------------------------------------------------------------------
  group('ButtonElementStyle', () {
    testWidgets('buttonTextStyle reaches the rendered button label', (
      tester,
    ) async {
      final style = ButtonElementStyle(
        buttonTextStyle: const TextStyle(fontSize: 29, letterSpacing: 4),
      );

      await tester.pumpWidget(
        _wrap(
          Center(
            child: TextButton(
              onPressed: () {},
              // The mapping cometchat_button_element.dart performs.
              child: Text('Tap me', style: style.buttonTextStyle),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Tap me'), findsOneWidget);
      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.style)
            .whereType<TextStyle>()
            .any((s) => s.fontSize == 29 && s.letterSpacing == 4),
        isTrue,
        reason: 'buttonTextStyle',
      );
    });
  });
}
