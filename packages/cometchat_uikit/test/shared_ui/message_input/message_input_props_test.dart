/// Render-verified prop matrix for [CometChatMessageInput] and
/// [CometChatMessageInputStyle] — Track 3 PROP1 (ENG-38922).
///
///   flutter test test/shared_ui/message_input/message_input_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

TextField _rawField(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

void main() {
  group('text and controller', () {
    testWidgets('text seeds the field', (tester) async {
      await tester.pumpWidget(
        _wrap(const CometChatMessageInput(text: 'SEEDED')),
      );
      await _settle(tester);
      expect(find.text('SEEDED'), findsOneWidget);
    });

    testWidgets('textEditingController drives the field', (tester) async {
      final controller = TextEditingController(text: 'FROM_CONTROLLER');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(CometChatMessageInput(textEditingController: controller)),
      );
      await _settle(tester);
      expect(find.text('FROM_CONTROLLER'), findsOneWidget);
    });

    testWidgets('placeholderText sets the hint', (tester) async {
      await tester.pumpWidget(
        _wrap(const CometChatMessageInput(placeholderText: 'SAY_SOMETHING')),
      );
      await _settle(tester);
      expect(_rawField(tester).decoration?.hintText, 'SAY_SOMETHING');
    });

    testWidgets('onChange fires as the text changes', (tester) async {
      String? typed;
      await tester.pumpWidget(
        _wrap(CometChatMessageInput(onChange: (t) => typed = t)),
      );
      await _settle(tester);
      await tester.enterText(find.byType(TextFormField), 'hello');
      await _settle(tester);
      expect(typed, 'hello');
    });

    testWidgets('onTap fires when the field is tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(CometChatMessageInput(onTap: () => tapped = true)),
      );
      await _settle(tester);
      await tester.tap(find.byType(TextFormField));
      await _settle(tester);
      expect(tapped, isTrue);
    });

    testWidgets('focusNode is attached to the field', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(_wrap(CometChatMessageInput(focusNode: node)));
      await _settle(tester);
      node.requestFocus();
      await _settle(tester);
      expect(node.hasFocus, isTrue);
    });

    testWidgets('maxLine limits the field', (tester) async {
      await tester.pumpWidget(_wrap(const CometChatMessageInput(maxLine: 4)));
      await _settle(tester);
      expect(_rawField(tester).maxLines, 4);
    });

    testWidgets('onContentInserted arms rich content insertion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CometChatMessageInput(onContentInserted: (content) {})),
      );
      await _settle(tester);
      expect(_rawField(tester).contentInsertionConfiguration, isNotNull);
    });

    testWidgets('onPasteImage is accepted by the input', (tester) async {
      await tester.pumpWidget(
        _wrap(CometChatMessageInput(onPasteImage: () async => true)),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatMessageInput>(find.byType(CometChatMessageInput))
            .onPasteImage,
        isNotNull,
      );
    });
  });

  group('layout and slots', () {
    testWidgets('height, width, margin and padding size the input', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatMessageInput(
            height: 90,
            width: 250,
            margin: EdgeInsets.all(7),
            padding: EdgeInsets.all(8),
          ),
        ),
      );
      await _settle(tester);
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.margin, const EdgeInsets.all(7));
      expect(container.padding, const EdgeInsets.all(8));
    });

    testWidgets('layout switches the composer arrangement', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatMessageInput(
            layout: CometChatComposerLayout.doubleLine,
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatMessageInput>(find.byType(CometChatMessageInput))
            .layout,
        CometChatComposerLayout.doubleLine,
      );
    });

    testWidgets('primaryButtonView, secondaryButtonView and '
        'auxiliaryButtonView render their slots', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatMessageInput(
            layout: CometChatComposerLayout.doubleLine,
            primaryButtonView: Text('PRIMARY'),
            secondaryButtonView: Text('SECONDARY'),
            auxiliaryButtonView: Text('AUX'),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('PRIMARY'), findsOneWidget);
      expect(find.text('SECONDARY'), findsOneWidget);
      expect(find.text('AUX'), findsOneWidget);
    });

    testWidgets('auxiliaryButtonsAlignment positions the auxiliary slot', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatMessageInput(
            layout: CometChatComposerLayout.doubleLine,
            auxiliaryButtonView: Text('AUX'),
            auxiliaryButtonsAlignment: AuxiliaryButtonsAlignment.left,
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatMessageInput>(find.byType(CometChatMessageInput))
            .auxiliaryButtonsAlignment,
        AuxiliaryButtonsAlignment.left,
      );
      expect(find.text('AUX'), findsOneWidget);
    });

    testWidgets('hideBottomView removes the bottom row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatMessageInput(
            layout: CometChatComposerLayout.doubleLine,
            auxiliaryButtonView: Text('AUX'),
            hideBottomView: true,
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('AUX'), findsNothing);
    });
  });

  group('code block mode', () {
    testWidgets('showCodeBlockIndicator switches to the code block input', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatMessageInput(
            showCodeBlockIndicator: true,
            placeholderText: 'CODE_HINT',
          ),
        ),
      );
      await _settle(tester);
      expect(_rawField(tester).decoration?.hintText, 'CODE_HINT');
    });

    testWidgets('codeBlockContent seeds the code block field', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatMessageInput(
            showCodeBlockIndicator: true,
            text: '```print(1)```',
            codeBlockContent: 'print(1)',
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('print(1)'), findsOneWidget);
    });

    testWidgets('codeBlockIndicatorColor outlines the code block', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatMessageInput(
            showCodeBlockIndicator: true,
            codeBlockIndicatorColor: Color(0xFF0B0101),
          ),
        ),
      );
      await _settle(tester);
      final borders = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.border)
          .whereType<Border>();
      expect(
        borders.map((b) => b.top.color),
        contains(const Color(0xFF0B0101)),
      );
    });
  });

  group('style', () {
    testWidgets('backgroundColor, border and borderRadius shape the surface', (
      tester,
    ) async {
      final border = Border.all(color: const Color(0xFF0B0202), width: 3);
      await tester.pumpWidget(
        _wrap(
          CometChatMessageInput(
            style: CometChatMessageInputStyle(
              backgroundColor: const Color(0xFF0B0303),
              border: border,
              borderRadius: BorderRadius.circular(19),
            ),
          ),
        ),
      );
      await _settle(tester);
      final decorations = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>();
      expect(
        decorations.map((d) => d.color),
        contains(const Color(0xFF0B0303)),
      );
      expect(decorations.map((d) => d.border), contains(border));
      expect(
        decorations.map((d) => d.borderRadius),
        contains(BorderRadius.circular(19)),
      );
    });

    testWidgets('textStyle, textColor, placeholderTextStyle and '
        'placeholderColor style the text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatMessageInput(
            style: CometChatMessageInputStyle(
              textStyle: TextStyle(fontSize: 17),
              textColor: Color(0xFF0B0404),
              placeholderTextStyle: TextStyle(fontSize: 15),
              placeholderColor: Color(0xFF0B0505),
            ),
          ),
        ),
      );
      await _settle(tester);
      final field = _rawField(tester);
      expect(field.style?.fontSize, 17.0);
      expect(field.style?.color, const Color(0xFF0B0404));
      expect(field.decoration?.hintStyle?.fontSize, 15.0);
      expect(field.decoration?.hintStyle?.color, const Color(0xFF0B0505));
    });

    testWidgets('filledColor fills the field', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatMessageInput(
            style: CometChatMessageInputStyle(filledColor: Color(0xFF0B0606)),
          ),
        ),
      );
      await _settle(tester);
      expect(_rawField(tester).decoration?.fillColor, const Color(0xFF0B0606));
    });

    testWidgets('dividerTint and dividerHeight draw the divider', (
      tester,
    ) async {
      // The divider belongs to the two-row layout.
      await tester.pumpWidget(
        _wrap(
          const CometChatMessageInput(
            layout: CometChatComposerLayout.doubleLine,
            auxiliaryButtonView: Text('AUX'),
            style: CometChatMessageInputStyle(
              dividerTint: Color(0xFF0B0707),
              dividerHeight: 5,
            ),
          ),
        ),
      );
      await _settle(tester);
      final dividers = tester.widgetList<Divider>(find.byType(Divider));
      expect(dividers.map((d) => d.color), contains(const Color(0xFF0B0707)));
      expect(dividers.map((d) => d.thickness), contains(5.0));
    });
  });
}
