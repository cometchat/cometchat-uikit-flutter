/// Render-verified prop matrix for the message composer's rich-text toolbar
/// cluster — Track 3 PROP1/PROP2 (ENG-38961).
///
/// Every widget and style is constructed inline inside `pumpWidget`; the
/// verifier does not follow a construction across a helper boundary.
///
///   flutter test test/chat_ui/message_composer/rich_text_toolbar_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: Center(child: child)),
);

TextStyle? _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style;

void main() {
  // -------------------------------------------------------------------------
  // CometChatLinkPreviewStyle — 12 props, all rendered by LinkEditDialog.
  // -------------------------------------------------------------------------
  group('CometChatLinkPreviewStyle through LinkEditDialog', () {
    testWidgets('every style property reaches a rendered widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LinkEditDialog(
            initialDisplayText: 'shown text',
            initialUrl: 'https://example.com',
            onSubmit: (_, _) {},
            onCancel: () {},
            style: const CometChatLinkPreviewStyle(
              backgroundColor: Color(0xFF111111),
              borderRadius: BorderRadius.all(Radius.circular(19)),
              titleTextStyle: TextStyle(fontSize: 27),
              labelTextStyle: TextStyle(letterSpacing: 4),
              textFieldBackgroundColor: Color(0xFF222222),
              textFieldBorderColor: Color(0xFF333333),
              textFieldHintColor: Color(0xFF444444),
              textFieldTextColor: Color(0xFF555555),
              buttonBackgroundColor: Color(0xFF666666),
              buttonTextColor: Color(0xFF777777),
              cancelButtonTextColor: Color(0xFF888888),
              errorTextColor: Color(0xFF999999),
            ),
          ),
        ),
      );
      await tester.pump();

      // The dialog surface.
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(
        dialog.backgroundColor,
        const Color(0xFF111111),
        reason: 'backgroundColor',
      );
      expect(
        (dialog.shape as RoundedRectangleBorder).borderRadius,
        const BorderRadius.all(Radius.circular(19)),
        reason: 'borderRadius',
      );

      // Title and field labels.
      expect(
        _styleOf(tester, 'Insert Link')?.fontSize,
        27,
        reason: 'titleTextStyle',
      );
      expect(
        _styleOf(tester, 'Display Text')?.letterSpacing,
        4,
        reason: 'labelTextStyle',
      );

      // Text fields.
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields, isNotEmpty);
      expect(
        fields.any(
          (f) => f.decoration?.hintStyle?.color == const Color(0xFF444444),
        ),
        isTrue,
        reason: 'textFieldHintColor',
      );
      expect(
        fields.any((f) => f.decoration?.fillColor == const Color(0xFF222222)),
        isTrue,
        reason: 'textFieldBackgroundColor',
      );
      expect(
        fields.any((f) {
          final b = f.decoration?.enabledBorder;
          return b is OutlineInputBorder &&
              b.borderSide.color == const Color(0xFF333333);
        }),
        isTrue,
        reason: 'textFieldBorderColor',
      );
      expect(
        fields.any((f) => f.style?.color == const Color(0xFF555555)),
        isTrue,
        reason: 'textFieldTextColor',
      );

      // Action buttons.
      expect(
        _styleOf(tester, 'Cancel')?.color,
        const Color(0xFF888888),
        reason: 'cancelButtonTextColor',
      );
      expect(
        _styleOf(tester, 'Insert')?.color,
        const Color(0xFF777777),
        reason: 'buttonTextColor',
      );
      final insert = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(
        insert.style?.backgroundColor?.resolve(<WidgetState>{}),
        const Color(0xFF666666),
        reason: 'buttonBackgroundColor',
      );
    });

    testWidgets('errorTextColor styles the validation message', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LinkEditDialog(
            initialDisplayText: 'shown text',
            initialUrl: '',
            onSubmit: (_, _) {},
            onCancel: () {},
            style: const CometChatLinkPreviewStyle(
              errorTextColor: Color(0xFFAB1234),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Insert'));
      await tester.pump();

      final errorTexts = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.style?.color == const Color(0xFFAB1234))
          .toList();
      expect(errorTexts, isNotEmpty, reason: 'errorTextColor');
    });
  });

  // -------------------------------------------------------------------------
  // LinkEditDialog — 5 props of its own.
  // -------------------------------------------------------------------------
  group('LinkEditDialog', () {
    testWidgets('initialDisplayText, initialUrl and style seed the dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LinkEditDialog(
            initialDisplayText: 'CometChat',
            initialUrl: 'https://cometchat.com',
            style: const CometChatLinkPreviewStyle(
              backgroundColor: Color(0xFF0A0B0C),
            ),
            onSubmit: (_, _) {},
            onCancel: () {},
          ),
        ),
      );
      await tester.pump();

      final controllers = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((f) => f.controller?.text)
          .toList();
      expect(controllers, contains('CometChat'), reason: 'initialDisplayText');
      expect(
        controllers,
        contains('https://cometchat.com'),
        reason: 'initialUrl',
      );
      expect(
        tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
        const Color(0xFF0A0B0C),
        reason: 'style',
      );
    });

    testWidgets('onSubmit fires with the entered values', (tester) async {
      String? gotText;
      String? gotUrl;
      await tester.pumpWidget(
        _wrap(
          LinkEditDialog(
            initialDisplayText: 'CometChat',
            initialUrl: 'https://cometchat.com',
            onSubmit: (t, u) {
              gotText = t;
              gotUrl = u;
            },
            onCancel: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Insert'));
      await tester.pump();
      expect(gotText, 'CometChat', reason: 'onSubmit display text');
      expect(gotUrl, 'https://cometchat.com', reason: 'onSubmit url');
    });

    testWidgets('onCancel fires from the Cancel button', (tester) async {
      var cancelled = false;
      await tester.pumpWidget(
        _wrap(
          LinkEditDialog(
            initialDisplayText: 'x',
            initialUrl: 'https://example.com',
            onSubmit: (_, _) {},
            onCancel: () => cancelled = true,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(cancelled, isTrue, reason: 'onCancel');
    });
  });

  // -------------------------------------------------------------------------
  // RichTextToolbarButton — 6 props.
  // -------------------------------------------------------------------------
  group('RichTextToolbarButton', () {
    testWidgets('formatType, isActive, style and focusOrder all take effect', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RichTextToolbarButton(
            formatType: FormatType.bold,
            onTap: () {},
            isActive: true,
            isDisabled: false,
            focusOrder: 3,
            style: const CometChatRichTextToolbarStyle(
              activeButtonIconColor: Color(0xFF2211AA),
            ),
          ),
        ),
      );
      await tester.pump();

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, FormatType.bold.icon, reason: 'formatType');
      expect(
        icon.color,
        const Color(0xFF2211AA),
        reason: 'isActive + style.activeButtonIconColor',
      );
      expect(
        find.byType(FocusTraversalOrder),
        findsWidgets,
        reason: 'focusOrder',
      );
      expect(
        tester.widget<Tooltip>(find.byType(Tooltip)).message,
        FormatType.bold.label,
        reason: 'enabled tooltip',
      );
    });

    testWidgets('isDisabled suppresses the tap and swaps the colour', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          RichTextToolbarButton(
            formatType: FormatType.italic,
            onTap: () => tapped = true,
            isDisabled: true,
            style: const CometChatRichTextToolbarStyle(
              disabledButtonIconColor: Color(0xFF778899),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<Icon>(find.byType(Icon)).color,
        const Color(0xFF778899),
        reason: 'isDisabled + style.disabledButtonIconColor',
      );
      await tester.tap(find.byType(InkWell), warnIfMissed: false);
      await tester.pump();
      expect(tapped, isFalse, reason: 'isDisabled suppresses onTap');
    });

    testWidgets('onTap fires when enabled', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          RichTextToolbarButton(
            formatType: FormatType.strikethrough,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(InkWell));
      await tester.pump();
      expect(tapped, isTrue, reason: 'onTap');
    });
  });

  // -------------------------------------------------------------------------
  // CodeBlockButton — 3 props. Renders `{` and `}` as Text, not an Icon.
  // -------------------------------------------------------------------------
  group('CodeBlockButton', () {
    testWidgets('iconColor, iconSize and onTap all take effect', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          CodeBlockButton(
            onTap: () => tapped = true,
            iconColor: const Color(0xFF3344FF),
            iconSize: 29,
          ),
        ),
      );
      await tester.pump();

      expect(
        _styleOf(tester, '{')?.color,
        const Color(0xFF3344FF),
        reason: 'iconColor',
      );
      expect(_styleOf(tester, '{')?.fontSize, 29, reason: 'iconSize');
      await tester.tap(find.byType(GestureDetector).last);
      await tester.pump();
      expect(tapped, isTrue, reason: 'onTap');
    });
  });
}
