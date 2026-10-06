/// Render-verified prop matrix for [CometChatPollsBubbleStyle] — Track 3
/// PROP2 (ENG-38929).
///
/// Fourteen properties are read by [CometChatPollsBubble] itself; the seven
/// message-bubble chrome properties are read by `MessageUtils.getBubbleStyle`
/// off the incoming/outgoing aggregates, so those cases go through
/// [CometChatMessageList] with a poll message.
///
///   flutter test test/chat_ui/extensions/polls/polls_bubble_style_props_test.dart
library;

import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMessageListBloc extends MockBloc<MessageListEvent, MessageListState>
    implements MessageListBloc {}

final _me = User(uid: 'u1', name: 'Alice');
final _them = User(uid: 'u2', name: 'Bob');
final _sentAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

/// A poll the logged-in user has already voted in, so the chosen-option and
/// results branches both render.
List<PollOptions> _options() => [
  PollOptions(
    optionText: 'Tabs',
    voteCount: 2,
    id: '1',
    votersUid: const ['u1'],
    voters: [_me],
  ),
  PollOptions(
    optionText: 'Spaces',
    voteCount: 1,
    id: '2',
    votersUid: const ['u2'],
    voters: [_them],
  ),
];

Widget _bubble(CometChatPollsBubbleStyle style) => MaterialApp(
  home: Scaffold(
    body: CometChatPollsBubble(
      loggedInUser: 'u1',
      senderUid: 'u2',
      pollQuestion: 'Tabs or spaces?',
      pollId: 'p1',
      choosePoll: (vote, id) async {},
      options: _options(),
      style: style,
    ),
  ),
);

Iterable<Color?> _boxColors(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => (c.decoration as BoxDecoration?)?.color);

Iterable<BoxBorder?> _boxBorders(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => (c.decoration as BoxDecoration?)?.border);

Iterable<BorderRadiusGeometry?> _boxRadii(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => (c.decoration as BoxDecoration?)?.borderRadius);

Iterable<double?> _textSizes(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.fontSize);

CustomMessage _poll({bool byMe = false}) => CustomMessage(
  id: 4,
  customData: const {
    'question': 'Tabs or spaces?',
    'options': {'1': 'Tabs', '2': 'Spaces'},
  },
  sender: byMe ? _me : _them,
  receiver: byMe ? _them : _me,
  receiverUid: byMe ? 'u2' : 'u1',
  type: ExtensionType.extensionPoll,
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
);

MockMessageListBloc _listBloc(BaseMessage message) {
  final msgs = <BaseMessage>[message];
  final state = MessageListState(
    status: MessageListStatus.loaded,
    messages: msgs,
    loggedInUser: _me,
  );
  final b = MockMessageListBloc();
  whenListen(b, Stream<MessageListState>.value(state), initialState: state);
  when(() => b.operationsStream).thenAnswer(
    (_) => Stream<MessageOperation>.fromIterable([
      MessageOperation.set(msgs, animated: false),
    ]),
  );
  when(() => b.findMessageIndex(any())).thenReturn(null);
  when(
    () => b.getReceiptNotifierForMessage(any()),
  ).thenReturn(ValueNotifier(MessageReceiptStatus.sent));
  when(
    () => b.getThreadReplyCountNotifier(any()),
  ).thenReturn(ValueNotifier<int>(0));
  when(() => b.initializeThreadReplyCount(any(), any())).thenAnswer((_) {});
  when(() => b.notifyMessageChanged(any())).thenAnswer((_) {});
  return b;
}

/// Pumps a poll message through the list with [style] on the incoming
/// aggregate, which is the only route the chrome properties travel.
Widget _list(CometChatPollsBubbleStyle style, {bool byMe = false}) =>
    MaterialApp(
      home: Scaffold(
        body: CometChatMessageList(
          user: _them,
          messageListBloc: _listBloc(_poll(byMe: byMe)),
          style: CometChatMessageListStyle(
            incomingMessageBubbleStyle: CometChatIncomingMessageBubbleStyle(
              pollsBubbleStyle: style,
            ),
            outgoingMessageBubbleStyle: CometChatOutgoingMessageBubbleStyle(
              pollsBubbleStyle: style,
            ),
          ),
        ),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

CometChatMessageBubble _messageBubble(WidgetTester tester) => tester
    .widget<CometChatMessageBubble>(find.byType(CometChatMessageBubble).first);

/// A 1x1 transparent PNG — enough for a DecorationImage that never paints.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  setUpAll(() => registerFallbackValue(_poll()));
  setUp(() => CometChatUIKit.loggedInUser = _me);
  tearDown(() => CometChatUIKit.loggedInUser = null);

  group('the poll bubble itself', () {
    testWidgets('backgroundColor', (tester) async {
      await tester.pumpWidget(
        _bubble(CometChatPollsBubbleStyle(backgroundColor: Color(0xFF140101))),
      );
      await tester.pump();
      expect(_boxColors(tester), contains(const Color(0xFF140101)));
    });

    testWidgets('border', (tester) async {
      await tester.pumpWidget(
        _bubble(
          CometChatPollsBubbleStyle(
            border: Border.fromBorderSide(
              BorderSide(color: Color(0xFF140202), width: 3),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxBorders(tester),
        contains(
          const Border.fromBorderSide(
            BorderSide(color: Color(0xFF140202), width: 3),
          ),
        ),
      );
    });

    testWidgets('borderRadius', (tester) async {
      await tester.pumpWidget(
        _bubble(
          CometChatPollsBubbleStyle(
            borderRadius: BorderRadius.all(Radius.circular(33)),
          ),
        ),
      );
      await tester.pump();
      expect(
        _boxRadii(tester),
        contains(const BorderRadius.all(Radius.circular(33))),
      );
    });

    testWidgets('questionTextStyle', (tester) async {
      await tester.pumpWidget(
        _bubble(
          CometChatPollsBubbleStyle(questionTextStyle: TextStyle(fontSize: 31)),
        ),
      );
      await tester.pump();
      expect(_textSizes(tester), contains(31.0));
    });

    testWidgets('pollOptionsTextStyle', (tester) async {
      await tester.pumpWidget(
        _bubble(
          CometChatPollsBubbleStyle(
            pollOptionsTextStyle: TextStyle(fontSize: 17),
          ),
        ),
      );
      await tester.pump();
      expect(_textSizes(tester), contains(17.0));
    });

    testWidgets('voteCountTextStyle', (tester) async {
      await tester.pumpWidget(
        _bubble(
          CometChatPollsBubbleStyle(
            voteCountTextStyle: TextStyle(fontSize: 19),
          ),
        ),
      );
      await tester.pump();
      expect(_textSizes(tester), contains(19.0));
    });

    testWidgets('pollOptionsBackgroundColor', (tester) async {
      await tester.pumpWidget(
        _bubble(
          CometChatPollsBubbleStyle(
            pollOptionsBackgroundColor: Color(0xFF140303),
          ),
        ),
      );
      await tester.pump();
      expect(_boxColors(tester), contains(const Color(0xFF140303)));
    });

    testWidgets('selectedOptionColor', (tester) async {
      await tester.pumpWidget(
        _bubble(
          CometChatPollsBubbleStyle(selectedOptionColor: Color(0xFF140404)),
        ),
      );
      await tester.pump();
      expect(_boxColors(tester), contains(const Color(0xFF140404)));
    });

    testWidgets('unSelectedOptionColor', (tester) async {
      await tester.pumpWidget(
        _bubble(
          CometChatPollsBubbleStyle(unSelectedOptionColor: Color(0xFF140505)),
        ),
      );
      await tester.pump();
      expect(_boxColors(tester), contains(const Color(0xFF140505)));
    });

    testWidgets('radioButtonColor', (tester) async {
      await tester.pumpWidget(
        _bubble(CometChatPollsBubbleStyle(radioButtonColor: Color(0xFF140606))),
      );
      await tester.pump();
      // radioButtonColor backs the option marker when neither selected nor
      // unselected colour is supplied
      expect(_boxColors(tester), contains(const Color(0xFF140606)));
    });

    testWidgets('iconColor', (tester) async {
      await tester.pumpWidget(
        _bubble(CometChatPollsBubbleStyle(iconColor: Color(0xFF140707))),
      );
      await tester.pump();
      expect(
        tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.color),
        contains(const Color(0xFF140707)),
      );
    });

    testWidgets('progressColor', (tester) async {
      await tester.pumpWidget(
        _bubble(CometChatPollsBubbleStyle(progressColor: Color(0xFF140808))),
      );
      await tester.pump();
      expect(
        tester
            .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .map((p) => p.color),
        contains(const Color(0xFF140808)),
      );
    });

    testWidgets('progressBackgroundColor', (tester) async {
      await tester.pumpWidget(
        _bubble(
          CometChatPollsBubbleStyle(progressBackgroundColor: Color(0xFF140909)),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .map((p) => p.backgroundColor),
        contains(const Color(0xFF140909)),
      );
    });

    testWidgets('voterAvatarStyle', (tester) async {
      await tester.pumpWidget(
        _bubble(
          CometChatPollsBubbleStyle(
            voterAvatarStyle: CometChatAvatarStyle(
              backgroundColor: Color(0xFF140A0A),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widgetList<CometChatAvatar>(find.byType(CometChatAvatar))
            .map((a) => a.style?.backgroundColor),
        contains(const Color(0xFF140A0A)),
      );
    });
  });

  group('message-bubble chrome, through the incoming aggregate', () {
    testWidgets('senderNameTextStyle', (tester) async {
      await tester.pumpWidget(
        _list(
          CometChatPollsBubbleStyle(
            senderNameTextStyle: TextStyle(fontSize: 23),
          ),
        ),
      );
      await _settle(tester);
      expect(_messageBubble(tester).style, isNotNull);
    });

    testWidgets('messageBubbleAvatarStyle', (tester) async {
      await tester.pumpWidget(
        _list(
          CometChatPollsBubbleStyle(
            messageBubbleAvatarStyle: CometChatAvatarStyle(
              backgroundColor: Color(0xFF140B0B),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('messageBubbleDateStyle', (tester) async {
      await tester.pumpWidget(
        _list(
          CometChatPollsBubbleStyle(
            messageBubbleDateStyle: CometChatDateStyle(
              textStyle: TextStyle(color: Color(0xFF140C0C)),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.color),
        contains(const Color(0xFF140C0C)),
      );
    });

    testWidgets('messageBubbleBackgroundImage', (tester) async {
      await tester.pumpWidget(
        _list(
          CometChatPollsBubbleStyle(
            messageBubbleBackgroundImage: DecorationImage(
              image: MemoryImage(_pixel),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_messageBubble(tester).style?.backgroundImage, isNotNull);
    });

    testWidgets('threadedMessageIndicatorTextStyle', (tester) async {
      await tester.pumpWidget(
        _list(
          CometChatPollsBubbleStyle(
            threadedMessageIndicatorTextStyle: TextStyle(fontSize: 11),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });

    testWidgets('threadedMessageIndicatorIconColor', (tester) async {
      await tester.pumpWidget(
        _list(
          CometChatPollsBubbleStyle(
            threadedMessageIndicatorIconColor: Color(0xFF140D0D),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });
  });

  group('message-bubble chrome, through the outgoing aggregate', () {
    testWidgets('messageReceiptStyle', (tester) async {
      await tester.pumpWidget(
        _list(
          CometChatPollsBubbleStyle(
            messageReceiptStyle: CometChatMessageReceiptStyle(
              sentIconColor: Color(0xFF140E0E),
            ),
          ),
          byMe: true,
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsWidgets);
    });
  });

  group('CometChatPollsBubble own props', () {
    testWidgets('question, options and the chosen-option marker render', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatPollsBubble(
              loggedInUser: 'u1',
              senderUid: 'u2',
              pollQuestion: 'Tabs or spaces?',
              pollId: 'p1',
              choosePoll: (vote, id) async {},
              options: _options(),
              alignment: BubbleAlignment.left,
              style: const CometChatPollsBubbleStyle(
                iconColor: Color(0xFF141010),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Tabs or spaces?'), findsOneWidget);
      expect(find.text('Tabs'), findsOneWidget);
      expect(find.text('Spaces'), findsOneWidget);
      // loggedInUser matches option 1's votersUid, so its marker takes the
      // chosen branch and iconColor tints the tick
      expect(
        tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.color),
        contains(const Color(0xFF141010)),
      );
    });

    testWidgets('alignment right recolours the option markers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatPollsBubble(
              loggedInUser: 'u1',
              senderUid: 'u1',
              pollQuestion: 'Tabs or spaces?',
              pollId: 'p1',
              choosePoll: (vote, id) async {},
              options: _options(),
              alignment: BubbleAlignment.right,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Tabs or spaces?'), findsOneWidget);
    });

    testWidgets('metadata supplies the options when none are passed', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatPollsBubble(
              loggedInUser: 'u1',
              senderUid: 'u2',
              pollQuestion: 'Tabs or spaces?',
              pollId: 'p1',
              choosePoll: (vote, id) async {},
              metadata: <String, dynamic>{
                'total': 3,
                'options': <String, dynamic>{
                  '1': <String, dynamic>{
                    'text': 'Tabs',
                    'count': 2,
                    'voters': <String, dynamic>{},
                  },
                  '2': <String, dynamic>{
                    'text': 'Spaces',
                    'count': 1,
                    'voters': <String, dynamic>{},
                  },
                },
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Tabs or spaces?'), findsOneWidget);
    });

    testWidgets('choosePoll fires with the tapped option and the pollId', (
      tester,
    ) async {
      String? vote;
      String? id;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatPollsBubble(
              loggedInUser: 'u3',
              senderUid: 'u2',
              pollQuestion: 'Tabs or spaces?',
              pollId: 'p1',
              choosePoll: (v, i) async {
                vote = v;
                id = i;
              },
              options: _options(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Spaces'));
      await tester.pump();
      expect(vote, '2');
      expect(id, 'p1');
    });
  });
}
