/// [CometChatMessagePreviewStyle]'s three theme-extension operations —
/// `merge`, `copyWith` and `lerp` — plus the default close button that only
/// renders when the host supplies no icon of its own.
///
///   flutter test test/chat_ui/message_composer/message_preview_style_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = Color(0xFF000000);
const _b = Color(0xFFFFFFFF);

CometChatMessagePreviewStyle _full({Color color = _a, double fontSize = 10}) =>
    CometChatMessagePreviewStyle(
      messagePreviewBackground: color,
      messagePreviewBorder: Border.all(color: color),
      messagePreviewBorderRadius: BorderRadius.circular(fontSize),
      messagePreviewTitleStyle: TextStyle(fontSize: fontSize),
      messagePreviewTitleColor: color,
      messagePreviewSubtitleStyle: TextStyle(fontSize: fontSize),
      messagePreviewSubtitleColor: color,
      closeIconColor: color,
      replyMessagePreviewCloseIconColor: color,
    );

void main() {
  group('CometChatMessagePreviewStyle — defaults', () {
    test('every field starts null', () {
      const style = CometChatMessagePreviewStyle();
      expect(style.messagePreviewBackground, isNull);
      expect(style.messagePreviewBorder, isNull);
      expect(style.messagePreviewBorderRadius, isNull);
      expect(style.messagePreviewTitleStyle, isNull);
      expect(style.messagePreviewTitleColor, isNull);
      expect(style.messagePreviewSubtitleStyle, isNull);
      expect(style.messagePreviewSubtitleColor, isNull);
      expect(style.closeIconColor, isNull);
      expect(style.replyMessagePreviewCloseIconColor, isNull);
    });
  });

  group('CometChatMessagePreviewStyle — merge', () {
    test('merging null keeps this style untouched', () {
      final style = _full();
      expect(style.merge(null), same(style));
    });

    test('the other style wins field by field, null falls back', () {
      final base = _full();
      final merged = base.merge(
        const CometChatMessagePreviewStyle(closeIconColor: _b),
      );
      expect(merged.closeIconColor, _b, reason: 'overridden');
      expect(merged.messagePreviewBackground, _a, reason: 'kept');
      expect(merged.replyMessagePreviewCloseIconColor, _a);
    });
  });

  group('CometChatMessagePreviewStyle — copyWith', () {
    test('no arguments leaves every field as it was', () {
      final style = _full();
      final copy = style.copyWith();

      expect(copy.messagePreviewBackground, style.messagePreviewBackground);
      expect(copy.messagePreviewBorder, style.messagePreviewBorder);
      expect(copy.messagePreviewBorderRadius, style.messagePreviewBorderRadius);
      expect(copy.messagePreviewTitleStyle, style.messagePreviewTitleStyle);
      expect(copy.messagePreviewTitleColor, style.messagePreviewTitleColor);
      expect(
        copy.messagePreviewSubtitleStyle,
        style.messagePreviewSubtitleStyle,
      );
      expect(
        copy.messagePreviewSubtitleColor,
        style.messagePreviewSubtitleColor,
      );
      expect(copy.closeIconColor, style.closeIconColor);
      expect(
        copy.replyMessagePreviewCloseIconColor,
        style.replyMessagePreviewCloseIconColor,
      );
      expect(copy, isNot(same(style)), reason: 'a new instance either way');
    });

    test('each named argument replaces only its own field', () {
      final base = _full();

      expect(
        base.copyWith(messagePreviewBackground: _b).messagePreviewBackground,
        _b,
      );
      expect(
        base.copyWith(messagePreviewBackground: _b).closeIconColor,
        _a,
        reason: 'the rest is untouched',
      );
      expect(
        base
            .copyWith(messagePreviewBorder: const Border(top: BorderSide()))
            .messagePreviewBorder,
        const Border(top: BorderSide()),
      );
      expect(
        base
            .copyWith(messagePreviewBorderRadius: BorderRadius.circular(99))
            .messagePreviewBorderRadius,
        BorderRadius.circular(99),
      );
      expect(
        base
            .copyWith(messagePreviewTitleStyle: const TextStyle(fontSize: 42))
            .messagePreviewTitleStyle
            ?.fontSize,
        42,
      );
      expect(
        base.copyWith(messagePreviewTitleColor: _b).messagePreviewTitleColor,
        _b,
      );
      expect(
        base
            .copyWith(
              messagePreviewSubtitleStyle: const TextStyle(fontSize: 43),
            )
            .messagePreviewSubtitleStyle
            ?.fontSize,
        43,
      );
      expect(
        base
            .copyWith(messagePreviewSubtitleColor: _b)
            .messagePreviewSubtitleColor,
        _b,
      );
      expect(base.copyWith(closeIconColor: _b).closeIconColor, _b);
      expect(
        base
            .copyWith(replyMessagePreviewCloseIconColor: _b)
            .replyMessagePreviewCloseIconColor,
        _b,
      );
    });

    test('copyWith cannot clear a field back to null', () {
      // Every parameter is nullable-with-fallback, so passing null is the same
      // as passing nothing.
      expect(_full().copyWith(closeIconColor: null).closeIconColor, _a);
    });
  });

  group('CometChatMessagePreviewStyle — lerp', () {
    test('lerping against a foreign extension returns this', () {
      final style = _full();
      expect(style.lerp(null, 0.5), same(style));
    });

    test('t = 0 and t = 1 land exactly on the two ends', () {
      final from = _full(color: _a, fontSize: 10);
      final to = _full(color: _b, fontSize: 20);

      final start = from.lerp(to, 0);
      expect(start.messagePreviewBackground, _a);
      expect(start.messagePreviewTitleColor, _a);
      expect(start.messagePreviewSubtitleStyle?.fontSize, 10);
      expect(start.messagePreviewBorderRadius, BorderRadius.circular(10));
      expect(start.messagePreviewBorder, from.messagePreviewBorder);

      final end = from.lerp(to, 1);
      expect(end.messagePreviewBackground, _b);
      expect(end.closeIconColor, _b);
      expect(end.replyMessagePreviewCloseIconColor, _b);
      expect(end.messagePreviewTitleStyle?.fontSize, 20);
      expect(end.messagePreviewBorderRadius, BorderRadius.circular(20));
    });

    test('halfway interpolates the continuous fields', () {
      final mid = _full(
        color: _a,
        fontSize: 10,
      ).lerp(_full(color: _b, fontSize: 20), 0.5);
      expect(mid.messagePreviewBackground, Color.lerp(_a, _b, 0.5));
      expect(mid.messagePreviewTitleStyle?.fontSize, 15);
      expect(mid.messagePreviewBorderRadius, BorderRadius.circular(15));
    });

    test('the border snaps at the midpoint instead of interpolating', () {
      final from = CometChatMessagePreviewStyle(
        messagePreviewBorder: Border.all(color: _a),
      );
      final to = CometChatMessagePreviewStyle(
        messagePreviewBorder: Border.all(color: _b),
      );
      expect(
        from.lerp(to, 0.49).messagePreviewBorder,
        from.messagePreviewBorder,
      );
      expect(from.lerp(to, 0.5).messagePreviewBorder, to.messagePreviewBorder);
    });
  });

  group('CometChatMessagePreview — the default close button', () {
    Widget host({Icon? icon, bool hide = false, VoidCallback? onClose}) =>
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: CometChatMessagePreview(
              messagePreviewTitle: 'Alice',
              messagePreviewSubtitle: 'see you there',
              messagePreviewCloseButtonIcon: icon,
              hideCloseButton: hide,
              onCloseClick: onClose,
              messagePreviewStyle: const CometChatMessagePreviewStyle(
                closeIconColor: Color(0xFF00FF00),
              ),
            ),
          ),
        );

    testWidgets('with no icon supplied it draws a tinted close glyph that'
        ' calls back', (tester) async {
      var closed = false;
      await tester.pumpWidget(host(onClose: () => closed = true));

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('see you there'), findsOneWidget);

      final icon = tester.widget<Icon>(find.byIcon(Icons.close));
      expect(icon.size, 16);
      expect(
        icon.color,
        const Color(0xFF00FF00),
        reason: 'the style wins over the palette default',
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(closed, isTrue);
    });

    testWidgets('with no style it falls back to the theme icon colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: Builder(
              builder: (context) => CometChatMessagePreview(
                messagePreviewTitle: 'Alice',
                messagePreviewSubtitle: 'see you there',
                onCloseClick: () {},
              ),
            ),
          ),
        ),
      );

      final palette = CometChatThemeHelper.getColorPalette(
        tester.element(find.byIcon(Icons.close)),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.close)).color,
        palette.iconSecondary,
      );
      expect(palette.iconSecondary, isNotNull);
    });

    testWidgets('a supplied icon replaces the default one', (tester) async {
      await tester.pumpWidget(host(icon: const Icon(Icons.cancel)));
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('hideCloseButton removes it entirely', (tester) async {
      await tester.pumpWidget(host(hide: true));
      expect(find.byIcon(Icons.close), findsNothing);
    });
  });
}
