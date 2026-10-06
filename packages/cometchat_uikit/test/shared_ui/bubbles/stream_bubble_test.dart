/// Behavioural tests for the AI streaming bubble
/// (`views/stream_bubble/cometchat_stream_bubble.dart`).
///
/// The bubble subscribes to [CometChatStreamService] for its run and rebuilds
/// itself from the events it receives. The service is an ordinary singleton
/// with no SDK call on the path used here, so a test can push real
/// `AIAssistant*Event`s through `handleIncomingEvent` and assert on what the
/// bubble ends up showing — the streamed text, the tool-call execution line and
/// its rollback, the card placeholder → card transition, and the error strip.
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every test gets its own run id so the singleton service cannot leak state
/// between them.
int _nextRunId = 9000;

/// Records the card actions the bubble forwards onto the UI event bus.
class _CardActionSpy with CometChatUIEventListener {
  final List<(BaseMessage, CometChatCardActionEvent)> actions = [];

  @override
  void ccCardActionClicked(BaseMessage message, dynamic action) {
    actions.add((message, action as CometChatCardActionEvent));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = CometChatStreamService();
  late int runId;
  late StreamMessage message;

  setUp(() {
    runId = _nextRunId++;
    service.streamDelay = const Duration(milliseconds: 1);
    // The service's connected flag is singleton state: a previous test that
    // disconnected would make every later onDisconnected a no-op.
    service.onConnected();
    service.cleanupAll();
    message = StreamMessage(
      text: '',
      id: runId,
      runId: runId,
      receiverUid: 'priya',
      receiverType: ReceiverTypeConstants.user,
      metadata: {AIConstants.aiShimmer: false},
    );
    service.registerMessage(message);
    service.setMessageIdForRun(runId, runId);
  });

  tearDown(() {
    service.stopStreamingForRunId(runId);
    service.cleanupAll();
  });

  Widget host(Widget child, {ThemeData? theme}) => MaterialApp(
    theme: theme,
    localizationsDelegates: Translations.localizationsDelegates,
    supportedLocales: const [Locale('en')],
    // Loose constraints: the bubble sizes itself off MediaQuery, and the
    // streamed cards size themselves off it too.
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  );

  Future<void> pumpBubble(
    WidgetTester tester, {
    StreamMessage? msg,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      host(CometChatStreamBubble(message: msg ?? message), theme: theme),
    );
    await tester.pump();
  }

  /// Pushes [event] into the run and lets the bubble's queued callback run.
  Future<void> send(WidgetTester tester, AIAssistantBaseEvent event) async {
    service.handleIncomingEvent(runId, event);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 5));
    }
  }

  AIAssistantContentReceivedEvent content(String delta) =>
      AIAssistantContentReceivedEvent(
        id: runId,
        type: AgenticKeys.textMessageContent,
        delta: delta,
      );

  group('text streaming', () {
    testWidgets('the bubble opens on the message text it was given', (
      tester,
    ) async {
      final seeded = StreamMessage(
        text: 'Thinking…',
        id: runId,
        runId: runId,
        receiverUid: 'priya',
        receiverType: ReceiverTypeConstants.user,
        metadata: {AIConstants.aiShimmer: false},
      );
      await pumpBubble(tester, msg: seeded);

      expect(
        find.textContaining('Thinking…', findRichText: true),
        findsWidgets,
      );
    });

    testWidgets(
      'text_message_start clears the text and turns the shimmer off',
      (tester) async {
        final seeded = StreamMessage(
          text: 'stale',
          id: runId,
          runId: runId,
          receiverUid: 'priya',
          receiverType: ReceiverTypeConstants.user,
          metadata: {AIConstants.aiShimmer: true},
        );
        service.registerMessage(seeded);
        await pumpBubble(tester, msg: seeded);
        expect(find.textContaining('stale', findRichText: true), findsWidgets);

        await send(
          tester,
          AIAssistantRunStartedEvent(
            id: runId,
            type: AgenticKeys.textMessageStart,
          ),
        );

        expect(find.textContaining('stale', findRichText: true), findsNothing);
        expect(
          service.getMessageById(runId)?.metadata?[AIConstants.aiShimmer],
          isFalse,
        );
      },
    );

    testWidgets('deltas accumulate into the rendered text', (tester) async {
      await pumpBubble(tester);

      await send(tester, content('Hello'));
      await send(tester, content(' world'));

      expect(
        find.textContaining('Hello world', findRichText: true),
        findsWidgets,
      );
      expect(service.getBufferContent(runId), 'Hello world');
      expect(service.getMessageById(runId)?.text, 'Hello world');
    });

    testWidgets('an empty delta is ignored — no buffer, no rebuild', (
      tester,
    ) async {
      await pumpBubble(tester);
      await send(tester, content('Hi'));

      await send(tester, content(''));

      expect(service.getBufferContent(runId), 'Hi');
    });

    testWidgets('an event with no run id is dropped', (tester) async {
      await pumpBubble(tester);
      await send(tester, content('Hi'));

      await send(
        tester,
        AIAssistantContentReceivedEvent(
          type: AgenticKeys.textMessageContent,
          delta: 'ghost',
        ),
      );

      expect(service.getBufferContent(runId), 'Hi');
      expect(find.textContaining('ghost', findRichText: true), findsNothing);
    });

    testWidgets('text_message_end replaces the text with the whole buffer', (
      tester,
    ) async {
      await pumpBubble(tester);
      await send(tester, content('par'));
      await send(tester, content('tial'));
      // A delta that never reached the message would still be in the buffer.
      service.getOrCreateBuffer(runId).write('!');

      await send(
        tester,
        AIAssistantMessageEndedEvent(
          id: runId,
          type: AgenticKeys.textMessageEnd,
        ),
      );

      expect(service.getMessageById(runId)?.text, 'partial!');
      expect(find.textContaining('partial!', findRichText: true), findsWidgets);
    });

    testWidgets('FINDING: text_message_end is keyed by run id while '
        'text_message_content is keyed by message id, so the two disagree when '
        'they differ', (tester) async {
      // Deltas land (content looks the message up by messageId)…
      const messageId = 77001;
      final msg = StreamMessage(
        text: '',
        id: messageId,
        runId: runId,
        receiverUid: 'priya',
        receiverType: ReceiverTypeConstants.user,
        metadata: {AIConstants.aiShimmer: false},
      );
      service.registerMessage(msg);
      service.setMessageIdForRun(runId, messageId);
      await pumpBubble(tester, msg: msg);

      await send(tester, content('abc'));
      expect(service.getMessageById(messageId)?.text, 'abc');

      // …but the end event looks it up by runId (`getMessageById(runId)`),
      // finds nothing, and silently skips the final replace. The buffer holds
      // the authoritative text and is never applied.
      service.getOrCreateBuffer(runId).write('-final');
      await send(
        tester,
        AIAssistantMessageEndedEvent(
          id: runId,
          type: AgenticKeys.textMessageEnd,
        ),
      );

      expect(
        service.getMessageById(messageId)?.text,
        'abc',
        reason: 'current behaviour: the buffered final text is dropped',
      );
      expect(service.getBufferContent(runId), 'abc-final');
    });
  });

  group('markdown builders', () {
    testWidgets('a fenced code block streams into the Kit code-block view', (
      tester,
    ) async {
      await pumpBubble(tester);

      await send(tester, content('```dart\nvoid main() {}\n```'));

      expect(find.byType(CometChatAiAssistantCodeBlock), findsOneWidget);
      final block = tester.widget<CometChatAiAssistantCodeBlock>(
        find.byType(CometChatAiAssistantCodeBlock),
      );
      expect(block.language, contains('dart'));
      expect(block.codes, contains('void main() {}'));
    });

    testWidgets('a markdown table streams into the Kit table view', (
      tester,
    ) async {
      await pumpBubble(tester);

      await send(tester, content('| a | b |\n| --- | --- |\n| 1 | 2 |\n'));

      expect(find.byType(CometChatAiAssistantTableBuilder), findsOneWidget);
    });

    testWidgets('inline code and links use the Kit builders', (tester) async {
      await pumpBubble(tester);

      await send(
        tester,
        content('Run `flutter test` then see [docs](https://docs.invalid).'),
      );

      expect(find.byType(CometchatHighlightBuilder), findsOneWidget);
      expect(find.byType(CometchatLinkBuilder), findsOneWidget);
      final link = tester.widget<CometchatLinkBuilder>(
        find.byType(CometchatLinkBuilder),
      );
      expect(link.url, 'https://docs.invalid');
    });
  });

  group('tool calls', () {
    testWidgets('a tool call appends its execution line and takes it away '
        'again when the tool ends', (tester) async {
      await pumpBubble(tester);
      await send(tester, content('Looking that up'));

      await send(
        tester,
        AIAssistantToolStartedEvent(
          id: runId,
          type: AgenticKeys.toolCallStart,
          executionText: 'Searching the catalogue…',
        ),
      );
      expect(
        find.textContaining('Searching the catalogue…', findRichText: true),
        findsWidgets,
      );

      await send(
        tester,
        AIAssistantToolEndedEvent(id: runId, type: AgenticKeys.toolCallEnd),
      );

      expect(
        find.textContaining('Searching the catalogue…', findRichText: true),
        findsNothing,
      );
      expect(
        service.getMessageById(runId)?.text,
        'Looking that up',
        reason: 'the pre-tool text is restored verbatim',
      );
    });

    testWidgets('two tool calls in a row restore the original text, not the '
        'first tool line', (tester) async {
      await pumpBubble(tester);
      await send(tester, content('Base'));

      await send(
        tester,
        AIAssistantToolStartedEvent(
          id: runId,
          type: AgenticKeys.toolCallStart,
          executionText: 'first',
        ),
      );
      await send(
        tester,
        AIAssistantToolStartedEvent(
          id: runId,
          type: AgenticKeys.toolCallStart,
          executionText: 'second',
        ),
      );
      await send(
        tester,
        AIAssistantToolEndedEvent(id: runId, type: AgenticKeys.toolCallEnd),
      );

      expect(service.getMessageById(runId)?.text, 'Base');
    });

    testWidgets('a tool end with no matching start leaves the text alone', (
      tester,
    ) async {
      await pumpBubble(tester);
      await send(tester, content('Base'));

      await send(
        tester,
        AIAssistantToolEndedEvent(id: runId, type: AgenticKeys.toolCallEnd),
      );

      expect(service.getMessageById(runId)?.text, 'Base');
    });

    testWidgets('a tool event for a run with no message mapping is dropped', (
      tester,
    ) async {
      await pumpBubble(tester);
      service.removeMessageIdMapping(runId);
      await send(
        tester,
        AIAssistantToolStartedEvent(
          id: runId,
          type: AgenticKeys.toolCallStart,
          executionText: 'orphan',
        ),
      );

      expect(find.textContaining('orphan', findRichText: true), findsNothing);
    });
  });

  group('cards', () {
    const card = <String, dynamic>{
      'version': '1.0',
      'body': [
        {'id': 't1', 'type': 'text', 'content': 'Streamed card content'},
      ],
      'fallbackText': 'Streamed card fallback',
    };

    testWidgets('card_start puts up a labelled placeholder', (tester) async {
      await pumpBubble(tester);

      await send(
        tester,
        AIAssistantCardStartedEvent(
          id: runId,
          type: AgenticKeys.cardStart,
          cardId: 'c1',
          executionText: 'Generating a recommendation…',
        ),
      );

      expect(find.byKey(const ValueKey('card_loading_c1')), findsOneWidget);
      expect(find.text('Generating a recommendation…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('a placeholder with no execution text is just a spinner', (
      tester,
    ) async {
      await pumpBubble(tester);

      await send(
        tester,
        AIAssistantCardStartedEvent(
          id: runId,
          type: AgenticKeys.cardStart,
          cardId: 'c1',
        ),
      );

      final placeholder = find.byKey(const ValueKey('card_loading_c1'));
      expect(placeholder, findsOneWidget);
      expect(
        find.descendant(of: placeholder, matching: find.byType(Text)),
        findsNothing,
        reason: 'no execution text means no label under the spinner',
      );
    });

    testWidgets('the card event replaces the placeholder with the card', (
      tester,
    ) async {
      await pumpBubble(tester);
      await send(
        tester,
        AIAssistantCardStartedEvent(
          id: runId,
          type: AgenticKeys.cardStart,
          cardId: 'c1',
        ),
      );

      await send(
        tester,
        AIAssistantCardReceivedEvent(
          id: runId,
          type: AgenticKeys.card,
          cardId: 'c1',
          card: card,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey('card_rendered_c1')), findsOneWidget);
      expect(find.byKey(const ValueKey('card_loading_c1')), findsNothing);
      expect(find.text('Streamed card content'), findsOneWidget);
    });

    testWidgets(
      'a card with no id, and one with no payload, are both ignored',
      (tester) async {
        await pumpBubble(tester);

        await send(
          tester,
          AIAssistantCardStartedEvent(
            id: runId,
            type: AgenticKeys.cardStart,
            cardId: '',
          ),
        );
        await send(
          tester,
          AIAssistantCardReceivedEvent(
            id: runId,
            type: AgenticKeys.card,
            cardId: 'c9',
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets('several cards stack in arrival order', (tester) async {
      await pumpBubble(tester);

      await send(
        tester,
        AIAssistantCardStartedEvent(
          id: runId,
          type: AgenticKeys.cardStart,
          cardId: 'a',
        ),
      );
      await send(
        tester,
        AIAssistantCardStartedEvent(
          id: runId,
          type: AgenticKeys.cardStart,
          cardId: 'b',
        ),
      );

      final loaders = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && w.key.toString().contains('card_'),
      );
      expect(loaders, findsNWidgets(2));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('card_loading_a'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('card_loading_b'))).dy,
        ),
      );
    });

    testWidgets('card_end is a no-op — a rendered card stays on screen', (
      tester,
    ) async {
      await pumpBubble(tester);
      await send(
        tester,
        AIAssistantCardReceivedEvent(
          id: runId,
          type: AgenticKeys.card,
          cardId: 'c1',
          card: card,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await send(
        tester,
        AIAssistantCardEndedEvent(
          id: runId,
          type: AgenticKeys.cardEnd,
          cardId: 'c1',
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey('card_rendered_c1')), findsOneWidget);
    });

    testWidgets('tapping a card button reports the action with THIS message', (
      tester,
    ) async {
      final spy = _CardActionSpy();
      CometChatUIEvents.addUiListener('stream-bubble-card-action', spy);
      addTearDown(
        () => CometChatUIEvents.removeUiListener('stream-bubble-card-action'),
      );
      await pumpBubble(tester);

      await send(
        tester,
        AIAssistantCardReceivedEvent(
          id: runId,
          type: AgenticKeys.card,
          cardId: 'c1',
          card: const <String, dynamic>{
            'version': '1.0',
            'body': [
              {
                'id': 'btn1',
                'type': 'button',
                'label': 'Option A',
                'action': {'type': 'openUrl', 'url': 'https://example.com/a'},
              },
            ],
            'fallbackText': 'Select an option',
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Option A'));
      await tester.pump();

      expect(spy.actions, hasLength(1));
      expect(spy.actions.single.$1, same(message));
      expect(spy.actions.single.$2.elementId, 'btn1');
    });

    testWidgets('a card renders against the ambient brightness', (
      tester,
    ) async {
      await pumpBubble(tester, theme: ThemeData.dark());
      await send(
        tester,
        AIAssistantCardReceivedEvent(
          id: runId,
          type: AgenticKeys.card,
          cardId: 'c1',
          card: card,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final view = tester.widget<CometChatCardView>(
        find.byType(CometChatCardView),
      );
      expect(view.themeMode, CometChatCardThemeMode.dark);
    });
  });

  group('errors', () {
    testWidgets('a dropped connection surfaces the error strip', (
      tester,
    ) async {
      await pumpBubble(tester);
      await send(tester, content('half a sen'));
      final context = tester.element(find.byType(CometChatStreamBubble));

      service.onDisconnected(context);
      await tester.pump();
      await tester.pump();

      final t = Translations.of(
        tester.element(find.byType(CometChatStreamBubble)),
      );
      expect(find.text(t.somethingWentWrongTryAgain), findsOneWidget);
      // The text streamed so far is kept — the error is additive.
      expect(
        find.textContaining('half a sen', findRichText: true),
        findsWidgets,
      );
    });

    testWidgets('a connection error surfaces its own details', (tester) async {
      await pumpBubble(tester);
      // The run has to be live for the service to route the error to it.
      await send(tester, content('working'));
      final context = tester.element(find.byType(CometChatStreamBubble));

      service.onConnectionError(
        CometChatException('ERR_X', 'details', 'the gateway went away'),
        context,
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('the gateway went away'), findsOneWidget);
    });

    testWidgets('no error, no strip', (tester) async {
      await pumpBubble(tester);
      await send(tester, content('fine'));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.textContaining('Disconnected', findRichText: true),
        findsNothing,
      );
    });
  });

  group('appearance', () {
    testWidgets('a shimmering message paints a gradient, a settled one does '
        'not', (tester) async {
      final shimmering = StreamMessage(
        text: 'loading',
        id: runId,
        runId: runId,
        receiverUid: 'priya',
        receiverType: ReceiverTypeConstants.user,
        metadata: {AIConstants.aiShimmer: true},
      );
      await pumpBubble(tester, msg: shimmering);

      expect(
        tester
            .widget<CometChatShimmerEffect>(find.byType(CometChatShimmerEffect))
            .linearGradient,
        isNotNull,
      );

      await pumpBubble(tester);
      expect(
        tester
            .widget<CometChatShimmerEffect>(find.byType(CometChatShimmerEffect))
            .linearGradient,
        isNull,
      );
    });

    testWidgets('an explicit width and height win over the 70%-of-screen '
        'default', (tester) async {
      await tester.pumpWidget(
        host(CometChatStreamBubble(message: message, width: 180, height: 90)),
      );
      await tester.pump();

      final box = tester.getSize(
        find
            .descendant(
              of: find.byType(CometChatStreamBubble),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(box.width, 180);
      expect(box.height, 90);
    });

    testWidgets('the widget-level style beats the theme default', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          CometChatStreamBubble(
            message: message,
            style: const CometChatAIAssistantBubbleStyle(
              backgroundColor: Color(0xFF123456),
            ),
          ),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(CometChatStreamBubble),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (container.decoration as BoxDecoration?)?.color,
        const Color(0xFF123456),
      );
    });
  });
}
