// Render-verified prop matrix for [CometChatMessageListStyle] (PROP1/PROP2,
// ENG-38770 / ENG-38854).
//
// Every test constructs the real CometChatMessageList with a style, pumps it,
// and asserts the style value reached the widget it is supposed to reach.
// Reading a field back off the style object would prove nothing about wiring.

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/widgets/cometchat_message_action_overlay.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' as sdk show Action;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMessageListBloc extends MockBloc<MessageListEvent, MessageListState>
    implements MessageListBloc {}

final _alice = User(uid: 'u1', name: 'Alice');
final _bob = User(uid: 'u2', name: 'Bob');
final _group = Group(guid: 'g1', name: 'Team', type: 'public');

TextMessage _text(String body, {int id = 1, User? sender}) => TextMessage(
  id: id,
  text: body,
  sender: sender ?? _alice,
  receiver: _bob,
  receiverUid: 'u2',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
);

MockMessageListBloc _mock({
  MessageListStatus status = MessageListStatus.loaded,
  List<BaseMessage>? messages,
  String? errorMessage,
}) {
  final msgs = messages ?? <BaseMessage>[_text('hello world')];
  final state = MessageListState(
    status: status,
    messages: msgs,
    loggedInUser: _alice,
    errorMessage: errorMessage,
  );
  final bloc = MockMessageListBloc();
  whenListen(bloc, Stream<MessageListState>.value(state), initialState: state);
  when(() => bloc.operationsStream).thenAnswer(
    (_) => Stream<MessageOperation>.fromIterable([
      MessageOperation.set(msgs, animated: false),
    ]),
  );
  when(() => bloc.findMessageIndex(any())).thenReturn(null);
  when(
    () => bloc.getReceiptNotifierForMessage(any()),
  ).thenReturn(ValueNotifier(MessageReceiptStatus.sent));
  when(
    () => bloc.getThreadReplyCountNotifier(any()),
  ).thenReturn(ValueNotifier<int>(0));
  when(() => bloc.initializeThreadReplyCount(any(), any())).thenAnswer((_) {});
  when(() => bloc.notifyMessageChanged(any())).thenAnswer((_) {});
  return bloc;
}

Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Container _root(WidgetTester tester) => tester.widget<Container>(
  find
      .descendant(
        of: find.byType(CometChatMessageList),
        matching: find.byType(Container),
      )
      .first,
);

/// Every TextStyle actually resolved onto a rendered Text in the tree.
Iterable<TextStyle> _textStyles(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.style)
    .whereType<TextStyle>();

Future<CometChatMessageActionOverlay> _openActions(WidgetTester tester) async {
  final longPress = find.byWidgetPredicate(
    (w) => w is GestureDetector && w.onLongPress != null,
  );
  tester.widget<GestureDetector>(longPress.first).onLongPress!();
  await _settle(tester);
  return tester.widget<CometChatMessageActionOverlay>(
    find.byType(CometChatMessageActionOverlay),
  );
}

void main() {
  setUpAll(() => registerFallbackValue(_text('fallback')));

  // BubbleUIBuilder.getBubbleStyle decides sent-vs-received from the global
  // CometChatUIKit.loggedInUser, not from the bloc state, so the outgoing
  // bubble path is only reachable with that global set.
  setUp(() => CometChatUIKit.loggedInUser = _alice);
  tearDown(() => CometChatUIKit.loggedInUser = null);

  group('container decoration', () {
    testWidgets('backgroundColor paints the root decoration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              style: const CometChatMessageListStyle(
                backgroundColor: Color(0xFF102030),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        (_root(tester).decoration as BoxDecoration).color,
        const Color(0xFF102030),
      );
    });

    testWidgets('border paints the root decoration', (tester) async {
      const border = Border.fromBorderSide(
        BorderSide(color: Color(0xFF445566), width: 3),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              style: const CometChatMessageListStyle(border: border),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect((_root(tester).decoration as BoxDecoration).border, border);
    });

    testWidgets('borderRadius paints the root decoration', (tester) async {
      final radius = BorderRadius.circular(19);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              style: CometChatMessageListStyle(borderRadius: radius),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect((_root(tester).decoration as BoxDecoration).borderRadius, radius);
    });
  });

  group('bubble styles', () {
    testWidgets('outgoingMessageBubbleStyle reaches the outgoing bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              style: const CometChatMessageListStyle(
                outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
                  backgroundColor: Color(0xFF778899),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatMessageBubble>(find.byType(CometChatMessageBubble))
            .style
            ?.backgroundColor,
        const Color(0xFF778899),
      );
    });

    testWidgets('incomingMessageBubbleStyle reaches the incoming bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(messages: [_text('hi', sender: _bob)]),
              style: const CometChatMessageListStyle(
                incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
                  backgroundColor: Color(0xFF223344),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatMessageBubble>(find.byType(CometChatMessageBubble))
            .style
            ?.backgroundColor,
        const Color(0xFF223344),
      );
    });

    testWidgets('avatarStyle reaches the sender avatar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              group: _group,
              messageListBloc: _mock(messages: [_text('hi', sender: _bob)]),
              avatarVisibility: true,
              style: const CometChatMessageListStyle(
                avatarStyle: CometChatAvatarStyle(
                  backgroundColor: Color(0xFF9911AA),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatAvatar>(find.byType(CometChatAvatar).first)
            .style
            ?.backgroundColor,
        const Color(0xFF9911AA),
      );
    });

    testWidgets('actionBubbleStyle reaches the group action bubble', (
      tester,
    ) async {
      final action = sdk.Action(
        id: 7,
        message: 'Bob joined',
        sender: _bob,
        receiver: _group,
        receiverUid: 'g1',
        type: MessageTypeConstants.groupActions,
        receiverType: ReceiverTypeConstants.group,
        category: MessageCategoryConstants.action,
        sentAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              group: _group,
              messageListBloc: _mock(messages: [action]),
              style: const CometChatMessageListStyle(
                actionBubbleStyle: CometChatActionBubbleStyle(
                  backgroundColor: Color(0xFF3355FF),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatActionBubble>(find.byType(CometChatActionBubble))
            .style
            ?.backgroundColor,
        const Color(0xFF3355FF),
      );
    });
  });

  group('reactions', () {
    testWidgets('reactionsStyle reaches the reaction strip', (tester) async {
      final reacted = _text('with reactions')
        ..reactions = [ReactionCount(reaction: '🔥', count: 2)];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(messages: [reacted]),
              style: CometChatMessageListStyle(
                reactionsStyle: CometChatReactionsStyle(
                  backgroundColor: Color(0xFF667788),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatReactions>(find.byType(CometChatReactions).first)
            .style
            ?.backgroundColor,
        const Color(0xFF667788),
      );
    });

    testWidgets('reactionListStyle reaches the reaction info sheet', (
      tester,
    ) async {
      final reacted = _text('with reactions')
        ..reactions = [ReactionCount(reaction: '🔥', count: 2)];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(messages: [reacted]),
              style: CometChatMessageListStyle(
                reactionListStyle: CometChatReactionListStyle(
                  backgroundColor: const Color(0xFF556677),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      tester
          .widget<CometChatReactions>(find.byType(CometChatReactions).first)
          .onReactionLongPress!('🔥');
      await _settle(tester);
      expect(
        tester
            .widget<CometChatReactionList>(find.byType(CometChatReactionList))
            .style
            ?.backgroundColor,
        const Color(0xFF556677),
      );
    });
  });

  group('option sheet and message information', () {
    testWidgets('messageOptionSheetStyle maps onto the action overlay', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              style: CometChatMessageListStyle(
                messageOptionSheetStyle: CometChatMessageOptionSheetStyle(
                  backgroundColor: const Color(0xFF010203),
                  borderRadius: BorderRadius.circular(11),
                  titleTextStyle: const TextStyle(fontSize: 23),
                  titleColor: const Color(0xFF040506),
                  iconColor: const Color(0xFF070809),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      final overlayStyle = (await _openActions(tester)).style;
      expect(overlayStyle?.optionsBackgroundColor, const Color(0xFF010203));
      expect(overlayStyle?.optionsBorderRadius, BorderRadius.circular(11));
      expect(overlayStyle?.optionTitleStyle?.fontSize, 23);
      expect(overlayStyle?.optionTitleStyle?.color, const Color(0xFF040506));
      expect(overlayStyle?.optionIconColor, const Color(0xFF070809));
    });

    testWidgets('messageInformationStyle reaches the information sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              style: const CometChatMessageListStyle(
                messageInformationStyle: CometChatMessageInformationStyle(
                  backgroundColor: Color(0xFFAABBCC),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      final overlay = await _openActions(tester);
      overlay.actionItems
          .firstWhere((a) => a.id == 'messageInformation')
          .onItemClick();
      await _settle(tester);
      expect(
        tester
            .widget<CometChatMessageInformation>(
              find.byType(CometChatMessageInformation),
            )
            .messageInformationStyle
            ?.backgroundColor,
        const Color(0xFFAABBCC),
      );
    });
  });

  group('mentions', () {
    testWidgets('mentionsStyle reaches the default mentions formatter', (
      tester,
    ) async {
      final style = CometChatMentionsStyle(
        mentionTextColor: const Color(0xFF12AB34),
      );
      CometChatMentionsFormatter? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              style: CometChatMessageListStyle(mentionsStyle: style),
              templates: [
                CometChatMessageTemplate(
                  type: MessageTypeConstants.text,
                  category: MessageCategoryConstants.message,
                  contentView:
                      (
                        message,
                        context,
                        alignment, {
                        additionalConfigurations,
                      }) {
                        seen = additionalConfigurations?.textFormatters
                            ?.whereType<CometChatMentionsFormatter>()
                            .firstOrNull;
                        return const Text('C');
                      },
                ),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        seen,
        isNotNull,
        reason: 'the default formatter set includes a mentions formatter',
      );
      expect(seen!.style?.mentionTextColor, const Color(0xFF12AB34));
    });
  });

  group('error state', () {
    Widget errorList(CometChatMessageListStyle style) => MaterialApp(
      home: Scaffold(
        body: CometChatMessageList(
          user: _bob,
          messageListBloc: _mock(
            status: MessageListStatus.error,
            messages: const [],
            errorMessage: 'boom',
          ),
          style: style,
        ),
      ),
    );

    testWidgets('errorStateTextStyle reaches the error title', (tester) async {
      await tester.pumpWidget(
        errorList(
          const CometChatMessageListStyle(
            errorStateTextStyle: TextStyle(fontSize: 41),
          ),
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(41.0));
    });

    testWidgets('errorStateTextColor reaches the error title', (tester) async {
      await tester.pumpWidget(
        errorList(
          const CometChatMessageListStyle(
            errorStateTextColor: Color(0xFF00FF11),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF00FF11)),
      );
    });

    testWidgets('errorStateSubtitleStyle reaches the error subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        errorList(
          const CometChatMessageListStyle(
            errorStateSubtitleStyle: TextStyle(fontSize: 42),
          ),
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(42.0));
    });

    testWidgets('errorStateSubtitleColor reaches the error subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        errorList(
          const CometChatMessageListStyle(
            errorStateSubtitleColor: Color(0xFF00FF22),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF00FF22)),
      );
    });
  });

  group('empty state', () {
    Widget emptyList(CometChatMessageListStyle style) => MaterialApp(
      home: Scaffold(
        body: CometChatMessageList(
          user: _bob,
          messageListBloc: _mock(
            status: MessageListStatus.empty,
            messages: const [],
          ),
          style: style,
        ),
      ),
    );

    testWidgets('emptyStateTextStyle reaches the empty title', (tester) async {
      await tester.pumpWidget(
        emptyList(
          const CometChatMessageListStyle(
            emptyStateTextStyle: TextStyle(fontSize: 43),
          ),
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(43.0));
    });

    testWidgets('emptyStateTextColor reaches the empty title', (tester) async {
      await tester.pumpWidget(
        emptyList(
          const CometChatMessageListStyle(
            emptyStateTextColor: Color(0xFF00FF33),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF00FF33)),
      );
    });

    testWidgets('emptyStateSubtitleStyle reaches the empty subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        emptyList(
          const CometChatMessageListStyle(
            emptyStateSubtitleStyle: TextStyle(fontSize: 44),
          ),
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(44.0));
    });

    testWidgets('emptyStateSubtitleColor reaches the empty subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        emptyList(
          const CometChatMessageListStyle(
            emptyStateSubtitleColor: Color(0xFF00FF44),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF00FF44)),
      );
    });
  });

  group('AI greeting state', () {
    final aiUser = User(uid: 'ai1', name: 'Assistant', role: AIConstants.aiRole)
      ..metadata = {
        'greetingMessage': 'Hello there',
        'introductoryMessage': 'Ask me anything',
      };

    Widget greetingList(CometChatMessageListStyle style) => MaterialApp(
      home: Scaffold(
        body: CometChatMessageList(
          user: aiUser,
          messageListBloc: _mock(
            status: MessageListStatus.empty,
            messages: const [],
          ),
          style: style,
        ),
      ),
    );

    testWidgets('emptyChatGreetingTitleTextStyle reaches the greeting title', (
      tester,
    ) async {
      await tester.pumpWidget(
        greetingList(
          const CometChatMessageListStyle(
            emptyChatGreetingTitleTextStyle: TextStyle(fontSize: 45),
          ),
        ),
      );
      await _settle(tester);
      expect(_textStyles(tester).map((s) => s.fontSize), contains(45.0));
    });

    testWidgets('emptyChatGreetingTitleTextColor reaches the greeting title', (
      tester,
    ) async {
      await tester.pumpWidget(
        greetingList(
          const CometChatMessageListStyle(
            emptyChatGreetingTitleTextColor: Color(0xFF00FF55),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _textStyles(tester).map((s) => s.color),
        contains(const Color(0xFF00FF55)),
      );
    });

    testWidgets(
      'emptyChatGreetingSubtitleTextStyle reaches the greeting subtitle',
      (tester) async {
        await tester.pumpWidget(
          greetingList(
            const CometChatMessageListStyle(
              emptyChatGreetingSubtitleTextStyle: TextStyle(fontSize: 46),
            ),
          ),
        );
        await _settle(tester);
        expect(_textStyles(tester).map((s) => s.fontSize), contains(46.0));
      },
    );

    testWidgets(
      'emptyChatGreetingSubtitleTextColor reaches the greeting subtitle',
      (tester) async {
        await tester.pumpWidget(
          greetingList(
            const CometChatMessageListStyle(
              emptyChatGreetingSubtitleTextColor: Color(0xFF00FF66),
            ),
          ),
        );
        await _settle(tester);
        expect(
          _textStyles(tester).map((s) => s.color),
          contains(const Color(0xFF00FF66)),
        );
      },
    );
  });
}
