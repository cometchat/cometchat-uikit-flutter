import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/message_list/cometchat_message_list_style.dart';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CometChatMessageListStyle', () {
    // =====================================================================
    // Default Values
    // =====================================================================

    group('Default Values', () {
      test('all properties are null by default', () {
        const style = CometChatMessageListStyle();
        expect(style.backgroundColor, isNull);
        expect(style.border, isNull);
        expect(style.borderRadius, isNull);
        expect(style.avatarStyle, isNull);
        expect(style.emptyStateTextStyle, isNull);
        expect(style.emptyStateTextColor, isNull);
        expect(style.emptyStateSubtitleStyle, isNull);
        expect(style.emptyStateSubtitleColor, isNull);
        expect(style.errorStateTextStyle, isNull);
        expect(style.errorStateTextColor, isNull);
        expect(style.errorStateSubtitleStyle, isNull);
        expect(style.errorStateSubtitleColor, isNull);
        expect(style.incomingMessageBubbleStyle, isNull);
        expect(style.outgoingMessageBubbleStyle, isNull);
        expect(style.messageInformationStyle, isNull);
        expect(style.messageOptionSheetStyle, isNull);
        expect(style.mentionsStyle, isNull);
        expect(style.actionBubbleStyle, isNull);
        expect(style.reactionListStyle, isNull);
        expect(style.reactionsStyle, isNull);
      });

      test('empty chat greeting properties are null by default', () {
        const style = CometChatMessageListStyle();
        expect(style.emptyChatGreetingTitleTextColor, isNull);
        expect(style.emptyChatGreetingTitleTextStyle, isNull);
        expect(style.emptyChatGreetingSubtitleTextColor, isNull);
        expect(style.emptyChatGreetingSubtitleTextStyle, isNull);
      });
    });

    // =====================================================================
    // Custom Values
    // =====================================================================

    group('Custom Values', () {
      test('constructor accepts all custom values', () {
        const style = CometChatMessageListStyle(
          backgroundColor: Colors.red,
          border: Border(top: BorderSide(color: Colors.blue, width: 2)),
          borderRadius: BorderRadius.all(Radius.circular(12)),
          emptyStateTextColor: Colors.green,
          emptyStateSubtitleColor: Colors.orange,
          errorStateTextColor: Colors.purple,
          errorStateSubtitleColor: Colors.yellow,
          emptyChatGreetingTitleTextColor: Colors.teal,
          emptyChatGreetingSubtitleTextColor: Colors.cyan,
        );
        expect(style.backgroundColor, Colors.red);
        expect(style.borderRadius, const BorderRadius.all(Radius.circular(12)));
        expect(style.emptyStateTextColor, Colors.green);
        expect(style.emptyStateSubtitleColor, Colors.orange);
        expect(style.errorStateTextColor, Colors.purple);
        expect(style.errorStateSubtitleColor, Colors.yellow);
        expect(style.emptyChatGreetingTitleTextColor, Colors.teal);
        expect(style.emptyChatGreetingSubtitleTextColor, Colors.cyan);
      });

      test('constructor accepts TextStyle values', () {
        const textStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
        const style = CometChatMessageListStyle(
          emptyStateTextStyle: textStyle,
          emptyStateSubtitleStyle: textStyle,
          errorStateTextStyle: textStyle,
          errorStateSubtitleStyle: textStyle,
          emptyChatGreetingTitleTextStyle: textStyle,
          emptyChatGreetingSubtitleTextStyle: textStyle,
        );
        expect(style.emptyStateTextStyle, textStyle);
        expect(style.emptyStateSubtitleStyle, textStyle);
        expect(style.errorStateTextStyle, textStyle);
        expect(style.errorStateSubtitleStyle, textStyle);
        expect(style.emptyChatGreetingTitleTextStyle, textStyle);
        expect(style.emptyChatGreetingSubtitleTextStyle, textStyle);
      });
    });

    // =====================================================================
    // copyWith
    // =====================================================================

    group('copyWith', () {
      test('copyWith returns new instance with replaced values', () {
        const original = CometChatMessageListStyle(
          backgroundColor: Colors.red,
          emptyStateTextColor: Colors.green,
        );
        final copied = original.copyWith(backgroundColor: Colors.blue);
        expect(copied.backgroundColor, Colors.blue);
        expect(copied.emptyStateTextColor, Colors.green);
      });

      test('copyWith preserves all values when no arguments passed', () {
        const original = CometChatMessageListStyle(
          backgroundColor: Colors.red,
          emptyStateTextColor: Colors.green,
          errorStateTextColor: Colors.blue,
          emptyChatGreetingTitleTextColor: Colors.teal,
        );
        final copied = original.copyWith();
        expect(copied.backgroundColor, Colors.red);
        expect(copied.emptyStateTextColor, Colors.green);
        expect(copied.errorStateTextColor, Colors.blue);
        expect(copied.emptyChatGreetingTitleTextColor, Colors.teal);
      });

      test('copyWith replaces border and borderRadius', () {
        const original = CometChatMessageListStyle(
          border: Border(top: BorderSide(color: Colors.red)),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        );
        final copied = original.copyWith(
          border: const Border(top: BorderSide(color: Colors.blue, width: 3)),
          borderRadius: const BorderRadius.all(Radius.circular(16)),
        );
        expect(
          copied.borderRadius,
          const BorderRadius.all(Radius.circular(16)),
        );
      });

      test('copyWith replaces empty state styles', () {
        const original = CometChatMessageListStyle(
          emptyStateTextStyle: TextStyle(fontSize: 14),
          emptyStateSubtitleStyle: TextStyle(fontSize: 12),
        );
        final copied = original.copyWith(
          emptyStateTextStyle: const TextStyle(fontSize: 20),
        );
        expect(copied.emptyStateTextStyle?.fontSize, 20);
        expect(copied.emptyStateSubtitleStyle?.fontSize, 12);
      });

      test('copyWith replaces error state styles', () {
        const original = CometChatMessageListStyle(
          errorStateTextStyle: TextStyle(fontSize: 14),
          errorStateSubtitleStyle: TextStyle(fontSize: 12),
        );
        final copied = original.copyWith(
          errorStateTextStyle: const TextStyle(fontSize: 18),
          errorStateSubtitleStyle: const TextStyle(fontSize: 10),
        );
        expect(copied.errorStateTextStyle?.fontSize, 18);
        expect(copied.errorStateSubtitleStyle?.fontSize, 10);
      });

      test('copyWith replaces greeting styles', () {
        const original = CometChatMessageListStyle(
          emptyChatGreetingTitleTextColor: Colors.red,
          emptyChatGreetingSubtitleTextColor: Colors.blue,
        );
        final copied = original.copyWith(
          emptyChatGreetingTitleTextColor: Colors.green,
          emptyChatGreetingSubtitleTextColor: Colors.orange,
        );
        expect(copied.emptyChatGreetingTitleTextColor, Colors.green);
        expect(copied.emptyChatGreetingSubtitleTextColor, Colors.orange);
      });
    });

    // =====================================================================
    // merge
    // =====================================================================

    group('merge', () {
      test('merge with null returns same style', () {
        const style = CometChatMessageListStyle(
          backgroundColor: Colors.red,
          emptyStateTextColor: Colors.green,
        );
        final merged = style.merge(null);
        expect(merged.backgroundColor, Colors.red);
        expect(merged.emptyStateTextColor, Colors.green);
      });

      test('merge replaces non-null values from other', () {
        const base = CometChatMessageListStyle(
          backgroundColor: Colors.red,
          emptyStateTextColor: Colors.green,
          errorStateTextColor: Colors.blue,
        );
        const other = CometChatMessageListStyle(
          backgroundColor: Colors.purple,
          emptyStateTextColor: Colors.orange,
        );
        final merged = base.merge(other);
        expect(merged.backgroundColor, Colors.purple);
        expect(merged.emptyStateTextColor, Colors.orange);
        // errorStateTextColor not in other, so preserved from base
        expect(merged.errorStateTextColor, Colors.blue);
      });

      test('merge preserves base values when other has nulls', () {
        const base = CometChatMessageListStyle(
          backgroundColor: Colors.red,
          border: Border(top: BorderSide(color: Colors.black)),
          emptyStateTextColor: Colors.green,
          errorStateTextColor: Colors.blue,
          emptyChatGreetingTitleTextColor: Colors.teal,
        );
        const other = CometChatMessageListStyle();
        final merged = base.merge(other);
        // All base values preserved since other has all nulls
        expect(merged.backgroundColor, Colors.red);
        expect(merged.emptyStateTextColor, Colors.green);
        expect(merged.errorStateTextColor, Colors.blue);
        expect(merged.emptyChatGreetingTitleTextColor, Colors.teal);
      });

      test('merge replaces greeting styles from other', () {
        const base = CometChatMessageListStyle(
          emptyChatGreetingTitleTextColor: Colors.red,
          emptyChatGreetingSubtitleTextColor: Colors.blue,
        );
        const other = CometChatMessageListStyle(
          emptyChatGreetingTitleTextColor: Colors.green,
        );
        final merged = base.merge(other);
        expect(merged.emptyChatGreetingTitleTextColor, Colors.green);
        expect(merged.emptyChatGreetingSubtitleTextColor, Colors.blue);
      });
    });

    // =====================================================================
    // of(context)
    // =====================================================================

    group('of(context)', () {
      testWidgets('of returns default style', (tester) async {
        late CometChatMessageListStyle resolvedStyle;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                resolvedStyle = CometChatMessageListStyle.of(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(resolvedStyle.backgroundColor, isNull);
        expect(resolvedStyle.border, isNull);
        expect(resolvedStyle.borderRadius, isNull);
      });
    });

    // =====================================================================
    // lerp
    // =====================================================================

    group('lerp', () {
      // Plain Color, not Colors.red and friends. Those are MaterialColor, and
      // Color.lerp returns a plain Color — ColorSwatch's operator== requires a
      // matching type, so the comparison failed even though every channel was
      // identical. The colours themselves are arbitrary; only "t=0 yields the
      // first, t=1 yields the second" is under test.
      const colorA = Color(0xFFFF0000);
      const colorB = Color(0xFF0000FF);
      const colorC = Color(0xFF00FF00);
      const colorD = Color(0xFFFFA500);

      test('lerp at t=0 returns this style', () {
        const styleA = CometChatMessageListStyle(
          backgroundColor: colorA,
          emptyStateTextColor: colorC,
        );
        const styleB = CometChatMessageListStyle(
          backgroundColor: colorB,
          emptyStateTextColor: colorD,
        );
        final result = styleA.lerp(styleB, 0.0);
        expect(result.backgroundColor, colorA);
        expect(result.emptyStateTextColor, colorC);
      });

      test('lerp at t=1 returns other style', () {
        const styleA = CometChatMessageListStyle(
          backgroundColor: colorA,
          emptyStateTextColor: colorC,
        );
        const styleB = CometChatMessageListStyle(
          backgroundColor: colorB,
          emptyStateTextColor: colorD,
        );
        final result = styleA.lerp(styleB, 1.0);
        expect(result.backgroundColor, colorB);
        expect(result.emptyStateTextColor, colorD);
      });

      test('lerp at t=0.5 interpolates colors', () {
        const styleA = CometChatMessageListStyle(backgroundColor: Colors.black);
        const styleB = CometChatMessageListStyle(backgroundColor: Colors.white);
        final result = styleA.lerp(styleB, 0.5);
        // Interpolated color should be between black and white
        expect(result.backgroundColor, isNotNull);
        expect(result.backgroundColor, isNot(Colors.black));
        expect(result.backgroundColor, isNot(Colors.white));
      });

      test('lerp handles null values gracefully', () {
        const styleA = CometChatMessageListStyle(backgroundColor: Colors.red);
        const styleB = CometChatMessageListStyle();
        final result = styleA.lerp(styleB, 0.5);
        // Color.lerp(Colors.red, null, 0.5) returns a partially transparent red
        expect(result.backgroundColor, isNotNull);
      });

      test('lerp with non-CometChatMessageListStyle returns this', () {
        const style = CometChatMessageListStyle(backgroundColor: Colors.red);
        // lerp checks `other is! CometChatMessageListStyle`
        // Since we can't easily pass a non-type, test with same type
        final result = style.lerp(null, 0.5);
        expect(result.backgroundColor, Colors.red);
      });

      test('lerp interpolates borderRadius', () {
        const styleA = CometChatMessageListStyle(
          borderRadius: BorderRadius.all(Radius.circular(0)),
        );
        const styleB = CometChatMessageListStyle(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        );
        final result = styleA.lerp(styleB, 0.5);
        expect(result.borderRadius, isNotNull);
      });

      test('lerp interpolates text styles', () {
        const styleA = CometChatMessageListStyle(
          emptyStateTextStyle: TextStyle(fontSize: 10),
        );
        const styleB = CometChatMessageListStyle(
          emptyStateTextStyle: TextStyle(fontSize: 20),
        );
        final result = styleA.lerp(styleB, 0.5);
        expect(result.emptyStateTextStyle?.fontSize, 15.0);
      });
    });

    // =====================================================================
    // ThemeExtension compliance
    // =====================================================================

    group('ThemeExtension compliance', () {
      test('is a ThemeExtension', () {
        const style = CometChatMessageListStyle();
        expect(style, isA<ThemeExtension<CometChatMessageListStyle>>());
      });

      test('copyWith returns CometChatMessageListStyle', () {
        const style = CometChatMessageListStyle();
        final copied = style.copyWith(backgroundColor: Colors.red);
        expect(copied, isA<CometChatMessageListStyle>());
      });

      test('lerp returns CometChatMessageListStyle', () {
        const styleA = CometChatMessageListStyle();
        const styleB = CometChatMessageListStyle(backgroundColor: Colors.red);
        final result = styleA.lerp(styleB, 0.5);
        expect(result, isA<CometChatMessageListStyle>());
      });
    });

    // =====================================================================
    // Equality
    // =====================================================================

    group('Equality', () {
      test('two default styles are equal by reference pattern', () {
        const style1 = CometChatMessageListStyle();
        const style2 = CometChatMessageListStyle();
        // Both have same null values
        expect(style1.backgroundColor, style2.backgroundColor);
        expect(style1.border, style2.border);
        expect(style1.borderRadius, style2.borderRadius);
      });

      test('styles with same values have same properties', () {
        const style1 = CometChatMessageListStyle(
          backgroundColor: Colors.red,
          emptyStateTextColor: Colors.green,
        );
        const style2 = CometChatMessageListStyle(
          backgroundColor: Colors.red,
          emptyStateTextColor: Colors.green,
        );
        expect(style1.backgroundColor, style2.backgroundColor);
        expect(style1.emptyStateTextColor, style2.emptyStateTextColor);
      });

      test('styles with different values have different properties', () {
        const style1 = CometChatMessageListStyle(backgroundColor: Colors.red);
        const style2 = CometChatMessageListStyle(backgroundColor: Colors.blue);
        expect(style1.backgroundColor, isNot(style2.backgroundColor));
      });
    });
  });
}
