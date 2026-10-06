/// `CometChatAIAssistantBubble` — the completed (non-streaming) AI answer.
///
/// The bubble has two shapes: the ordered `getElements()` blocks (text →
/// GptMarkdown, card → CometChatCardView, anything else skipped) and the
/// legacy `text`/`message.text` fallback with its copy affordance. Neither had
/// ever been pumped; only the style class was exercised, through
/// `ai_view_styles_props_test.dart`.
///
///   flutter test test/shared_ui/views/ai_assistant_bubble_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

const _card = <String, dynamic>{
  'version': '1.0',
  'body': [
    {
      'id': 'btn1',
      'type': 'button',
      'label': 'Option A',
      'action': {'type': 'openUrl', 'url': 'https://example.invalid/a'},
    },
  ],
  'fallbackText': 'Select an option',
};

/// Records the card actions the bubble forwards onto the UI event bus.
class _CardActionSpy with CometChatUIEventListener {
  final List<(BaseMessage, CometChatCardActionEvent)> actions = [];

  @override
  void ccCardActionClicked(BaseMessage message, dynamic action) {
    actions.add((message, action as CometChatCardActionEvent));
  }
}

AIAssistantMessage _message({
  String? text,
  List<AIAssistantElement>? elements,
}) {
  final message = AIAssistantMessage(
    id: 7,
    text: text,
    receiverUid: 'priya',
    type: MessageTypeConstants.text,
    receiverType: ReceiverTypeConstants.user,
  );
  if (elements != null) message.setElements(elements);
  return message;
}

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  // Loose constraints: the bubble sizes itself from MediaQuery.
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

void main() {
  // =========================================================================
  group('the text fallback', () {
    testWidgets('renders the `text` prop through GptMarkdown', (tester) async {
      await tester.pumpWidget(
        _host(const CometChatAIAssistantBubble(text: 'Hello from the model')),
      );
      await tester.pump();

      expect(find.byType(GptMarkdown), findsOneWidget);
      expect(
        tester.widget<GptMarkdown>(find.byType(GptMarkdown)).data,
        'Hello from the model',
      );
    });

    testWidgets("the message's own text wins over the `text` prop", (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CometChatAIAssistantBubble(
            text: 'ignored',
            message: _message(text: 'from the message'),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<GptMarkdown>(find.byType(GptMarkdown)).data,
        'from the message',
      );
    });

    testWidgets('empty content renders no copy button', (tester) async {
      await tester.pumpWidget(_host(const CometChatAIAssistantBubble()));
      await tester.pump();

      expect(find.byIcon(Icons.content_copy_rounded), findsNothing);
    });

    testWidgets('the copy button puts the content on the clipboard and '
        'confirms it', (tester) async {
      final copied = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') copied.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(
        _host(const CometChatAIAssistantBubble(text: 'copy me')),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.content_copy_rounded));
      await tester.pump();

      expect(copied, hasLength(1));
      expect((copied.single.arguments as Map)['text'], 'copy me');
      expect(find.text('Copied to clipboard'), findsOneWidget);
    });

    testWidgets('the copy affordance is announced as a button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const CometChatAIAssistantBubble(text: 'copy me')),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel('Copy'),
        findsOneWidget,
        reason: 'the icon carries the translated Copy label',
      );
      handle.dispose();
    });
  });

  // =========================================================================
  group('geometry and style', () {
    testWidgets('width defaults to 70% of the screen', (tester) async {
      await tester.pumpWidget(
        _host(const CometChatAIAssistantBubble(text: 'sized')),
      );
      await tester.pump();

      final screen =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(
        tester.getSize(find.byType(CometChatAIAssistantBubble)).width,
        screen * 0.7,
      );
    });

    testWidgets('an explicit width and height override the default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const CometChatAIAssistantBubble(
            text: 'sized',
            width: 210,
            height: 120,
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byType(CometChatAIAssistantBubble)),
        const Size(210, 120),
      );
    });

    testWidgets('backgroundColor, border and borderRadius reach the box', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CometChatAIAssistantBubble(
            text: 'styled',
            style: CometChatAIAssistantBubbleStyle(
              backgroundColor: const Color(0xFF123456),
              border: Border.all(color: const Color(0xFF654321), width: 2),
              borderRadius: BorderRadius.circular(19),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(CometChatAIAssistantBubble),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFF123456));
      expect((decoration.border! as Border).top.width, 2);
      expect(decoration.borderRadius, BorderRadius.circular(19));
    });

    testWidgets('textColor wins over textStyle colour', (tester) async {
      await tester.pumpWidget(
        _host(
          const CometChatAIAssistantBubble(
            text: 'styled',
            style: CometChatAIAssistantBubbleStyle(
              textStyle: TextStyle(color: Color(0xFF00FF00), fontSize: 25),
              textColor: Color(0xFFFF0000),
            ),
          ),
        ),
      );
      await tester.pump();

      final style = tester.widget<GptMarkdown>(find.byType(GptMarkdown)).style;
      expect(style?.color, const Color(0xFFFF0000));
      expect(style?.fontSize, 25, reason: 'the rest of textStyle survives');
    });
  });

  // =========================================================================
  group('ordered element blocks', () {
    testWidgets('a text element renders instead of the fallback text, and '
        'suppresses the copy button', (tester) async {
      await tester.pumpWidget(
        _host(
          CometChatAIAssistantBubble(
            text: 'fallback',
            message: _message(
              text: 'fallback',
              elements: [AIAssistantElement(type: 'text', data: 'block one')],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<GptMarkdown>(find.byType(GptMarkdown)).data,
        'block one',
      );
      expect(find.byIcon(Icons.content_copy_rounded), findsNothing);
    });

    testWidgets('an empty text element contributes no block', (tester) async {
      await tester.pumpWidget(
        _host(
          CometChatAIAssistantBubble(
            message: _message(
              elements: [
                AIAssistantElement(type: 'text', data: ''),
                AIAssistantElement(type: 'text', data: 'kept'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(GptMarkdown), findsOneWidget);
      expect(tester.widget<GptMarkdown>(find.byType(GptMarkdown)).data, 'kept');
    });

    testWidgets('several text elements render in order', (tester) async {
      await tester.pumpWidget(
        _host(
          CometChatAIAssistantBubble(
            message: _message(
              elements: [
                AIAssistantElement(type: 'text', data: 'first'),
                AIAssistantElement(type: 'text', data: 'second'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final blocks = tester
          .widgetList<GptMarkdown>(find.byType(GptMarkdown))
          .map((g) => g.data)
          .toList();
      expect(blocks, ['first', 'second']);
    });

    testWidgets('an unknown element type is skipped without an empty block', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CometChatAIAssistantBubble(
            message: _message(
              elements: [
                AIAssistantElement(type: 'graph', data: {'points': 1}),
                AIAssistantElement(type: 'text', data: 'after the graph'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(GptMarkdown), findsOneWidget);
      expect(
        tester.widget<GptMarkdown>(find.byType(GptMarkdown)).data,
        'after the graph',
      );
    });

    testWidgets('an empty element list falls back to the text render', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CometChatAIAssistantBubble(
            message: _message(text: 'fallback body', elements: const []),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<GptMarkdown>(find.byType(GptMarkdown)).data,
        'fallback body',
      );
      expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);
    });

    testWidgets('a card element renders the card', (tester) async {
      await tester.pumpWidget(
        _host(
          CometChatAIAssistantBubble(
            message: _message(
              elements: [
                AIAssistantElement(
                  type: 'card',
                  data: <String, dynamic>{'card': _card, 'cardId': 'c1'},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CometChatCardView), findsOneWidget);
      expect(find.text('Option A'), findsOneWidget);
    });

    testWidgets('a card element with no card payload renders nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CometChatAIAssistantBubble(
            message: _message(
              elements: [
                AIAssistantElement(
                  type: 'card',
                  data: <String, dynamic>{'cardId': 'c1'},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CometChatCardView), findsNothing);
    });

    testWidgets('a card element whose data is not a map renders nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CometChatAIAssistantBubble(
            message: _message(
              elements: [AIAssistantElement(type: 'card', data: 'not a map')],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CometChatCardView), findsNothing);
    });

    testWidgets('tapping a card button reports the action with this message', (
      tester,
    ) async {
      final spy = _CardActionSpy();
      CometChatUIEvents.addUiListener('ai-assistant-bubble-card', spy);
      addTearDown(
        () => CometChatUIEvents.removeUiListener('ai-assistant-bubble-card'),
      );

      final message = _message(
        elements: [
          AIAssistantElement(
            type: 'card',
            data: <String, dynamic>{'card': _card, 'cardId': 'c1'},
          ),
        ],
      );
      await tester.pumpWidget(
        _host(CometChatAIAssistantBubble(message: message)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Option A'));
      await tester.pump();

      expect(spy.actions, hasLength(1));
      expect(spy.actions.single.$1, same(message));
      expect(spy.actions.single.$2.elementId, 'btn1');
    });

    testWidgets('a card renders against the ambient brightness', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CometChatAIAssistantBubble(
            message: _message(
              elements: [
                AIAssistantElement(
                  type: 'card',
                  data: <String, dynamic>{'card': _card, 'cardId': 'c1'},
                ),
              ],
            ),
          ),
          theme: ThemeData.dark(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<CometChatCardView>(find.byType(CometChatCardView))
            .themeMode,
        CometChatCardThemeMode.dark,
      );
    });
  });

  // =========================================================================
  group('the markdown sub-builders', () {
    testWidgets('a fenced code block goes through the code block builder', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const CometChatAIAssistantBubble(
            text: '```dart\nvoid main() {}\n```',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CometChatAiAssistantCodeBlock), findsOneWidget);
      expect(find.text('dart'), findsOneWidget);
    });

    testWidgets('a markdown table goes through the table builder', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const CometChatAIAssistantBubble(
            text: '| Region | Seats |\n| --- | --- |\n| EMEA | 42 |\n',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CometChatAiAssistantTableBuilder), findsOneWidget);
      expect(find.text('EMEA'), findsOneWidget);
    });

    testWidgets('inline code goes through the highlight builder', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const CometChatAIAssistantBubble(text: 'call `build()` first')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CometchatHighlightBuilder), findsOneWidget);
      expect(find.text('build()'), findsOneWidget);
    });

    testWidgets('an inline link goes through the link builder', (tester) async {
      await tester.pumpWidget(
        _host(
          const CometChatAIAssistantBubble(
            text: 'see [docs](https://example.invalid/d)',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CometchatLinkBuilder), findsOneWidget);
      expect(
        tester
            .widget<CometchatLinkBuilder>(find.byType(CometchatLinkBuilder))
            .url,
        'https://example.invalid/d',
      );
    });
  });
}
