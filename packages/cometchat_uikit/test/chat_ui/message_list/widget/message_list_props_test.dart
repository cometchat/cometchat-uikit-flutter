// Render-verified prop matrix for [CometChatMessageList] (PROP1/PROP2, ENG-38770).
//
// Every test in this file constructs the real widget, pumps it, and asserts on
// something the prop actually changed in the built tree. Constructor-assignment
// assertions ("the widget stored the value") are deliberately absent — they are
// the anti-pattern PROP2 exists to eliminate.
//
// The bloc is injected through the public `messageListBloc` seam, so no SDK
// initialisation is required.

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/widgets/cometchat_message_action_overlay.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/widgets/cometchat_message_swipe.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/message_list/widgets/cometchat_flag_message_dialog.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' as sdk show Action;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMessageListBloc extends MockBloc<MessageListEvent, MessageListState>
    implements MessageListBloc {}

/// Concrete formatter whose output is visible in the rendered separator.
class TestDateFormatter extends DateTimeFormatterCallback {
  @override
  String? today(int? timestamp) => 'FORMATTED_DAY';
  @override
  String? yesterday(int? timestamp) => 'FORMATTED_DAY';
  @override
  String? lastWeek(int? timestamp) => 'FORMATTED_DAY';
  @override
  String? otherDays(int? timestamp) => 'FORMATTED_DAY';
}

/// Formatter whose `time` is visible on the bubble timestamp.
class TestTimeFormatter extends DateTimeFormatterCallback {
  @override
  String? time(int? timestamp) => 'FORMATTED_TIME';
}

final _alice = User(uid: 'u1', name: 'Alice');
final _bob = User(uid: 'u2', name: 'Bob');
final _group = Group(guid: 'g1', name: 'Team', type: 'public');

DateTime _at(int msSinceEpoch) =>
    DateTime.fromMillisecondsSinceEpoch(msSinceEpoch);

TextMessage _text(
  String body, {
  int id = 1,
  User? sender,
  DateTime? sentAt,
  String? category,
}) => TextMessage(
  id: id,
  text: body,
  sender: sender ?? _alice,
  receiver: _bob,
  receiverUid: 'u2',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  category: category,
  sentAt: sentAt ?? _at(1700000000000),
);

/// A mocked [MessageListBloc] that publishes [messages] through both the
/// bloc state and the operations stream the widget's animated list consumes.
MockMessageListBloc _mock({
  MessageListStatus status = MessageListStatus.loaded,
  List<BaseMessage>? messages,
  String? errorMessage,
  int unreadCount = 0,
}) {
  final msgs = messages ?? <BaseMessage>[_text('hello world')];
  final state = MessageListState(
    status: status,
    messages: msgs,
    loggedInUser: _alice,
    errorMessage: errorMessage,
    unreadCount: unreadCount,
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

/// Drives the animated list's operation queue and any bubble animations.
Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The root [Container] the widget wraps everything in — carries padding,
/// margin, height, width and the style-driven decoration.
Container _root(WidgetTester tester) => tester.widget<Container>(
  find
      .descendant(
        of: find.byType(CometChatMessageList),
        matching: find.byType(Container),
      )
      .first,
);

/// Opens the message-action overlay by invoking the long-press callback the
/// rendered tree actually carries, then returns the pushed overlay widget.
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

List<String> _actionIds(CometChatMessageActionOverlay overlay) =>
    overlay.actionItems.map((a) => a.id).toList();

/// A template that captures the [AdditionalConfigurations] the list builds
/// for the option menu, so props with no downstream renderer are still
/// verified where the widget hands them off.
CometChatMessageTemplate _capturingTemplate(
  void Function(AdditionalConfigurations?) onConfigurations,
) => CometChatMessageTemplate(
  type: MessageTypeConstants.text,
  category: MessageCategoryConstants.message,
  options: (loggedInUser, message, context, group, configurations) {
    onConfigurations(configurations);
    return <CometChatMessageOption>[];
  },
);

/// A bloc whose status transitions from `initial` to [status], so the widget's
/// BlocConsumer listener (which fires on status change) actually runs.
MockMessageListBloc _mockTransition(
  MessageListStatus status, {
  List<BaseMessage>? messages,
  String? errorMessage,
}) {
  final msgs = messages ?? <BaseMessage>[_text('hello world')];
  const initial = MessageListState(status: MessageListStatus.initial);
  final settled = MessageListState(
    status: status,
    messages: msgs,
    loggedInUser: _alice,
    errorMessage: errorMessage,
  );
  final bloc = MockMessageListBloc();
  whenListen(
    bloc,
    Stream<MessageListState>.fromIterable([initial, settled]),
    initialState: initial,
  );
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

/// Every event the widget dispatched onto the injected bloc.
List<MessageListEvent> _events(MockMessageListBloc bloc) =>
    verify(() => bloc.add(captureAny())).captured.cast<MessageListEvent>();

/// A template whose content view is identifiable in the tree and which
/// captures the [AdditionalConfigurations] the list builds for it.
CometChatMessageTemplate _contentTemplate(
  String label, {
  void Function(AdditionalConfigurations?)? onConfigurations,
}) => CometChatMessageTemplate(
  type: MessageTypeConstants.text,
  category: MessageCategoryConstants.message,
  contentView: (message, context, alignment, {additionalConfigurations}) {
    onConfigurations?.call(additionalConfigurations);
    return Text(label);
  },
);

/// A bloc whose thread-reply notifier reports [replies], so the thread view
/// actually renders.
MockMessageListBloc _mockWithThread(int replies) {
  final bloc = _mock(messages: [_text('hello world')]);
  when(
    () => bloc.getThreadReplyCountNotifier(any()),
  ).thenReturn(ValueNotifier<int>(replies));
  return bloc;
}

TextMessage _reacted(String body) {
  final m = _text(body);
  m.reactions = [ReactionCount(reaction: '🔥', count: 2, reactedByMe: true)];
  return m;
}

/// A bloc that publishes [message] as an `insert` operation — the only
/// operation the smart-replies trigger listens to.
MockMessageListBloc _mockInserting(BaseMessage message) {
  final msgs = <BaseMessage>[message];
  final state = MessageListState(
    status: MessageListStatus.loaded,
    messages: msgs,
    loggedInUser: _alice,
  );
  final bloc = MockMessageListBloc();
  whenListen(bloc, Stream<MessageListState>.value(state), initialState: state);
  when(() => bloc.operationsStream).thenAnswer(
    (_) => Stream<MessageOperation>.fromIterable([
      MessageOperation.insert(message, 0, animated: false),
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

/// A bloc that reports `empty` (which publishes conversation starters) and
/// then `loaded` (the status whose content path actually renders the bottom
/// panel).
/// Stays on `empty` — the status conversation starters are published on, and
/// the one the panel has to render under (ENG-38853).
MockMessageListBloc _mockEmpty() {
  const initial = MessageListState(status: MessageListStatus.initial);
  const empty = MessageListState(status: MessageListStatus.empty);
  final bloc = MockMessageListBloc();
  whenListen(
    bloc,
    Stream<MessageListState>.fromIterable([initial, empty]),
    initialState: initial,
  );
  when(() => bloc.operationsStream).thenAnswer(
    (_) => Stream<MessageOperation>.fromIterable([
      MessageOperation.set(const <BaseMessage>[], animated: false),
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

MockMessageListBloc _mockEmptyThenLoaded() {
  final msgs = <BaseMessage>[_text('hello world')];
  const initial = MessageListState(status: MessageListStatus.initial);
  const empty = MessageListState(status: MessageListStatus.empty);
  final loaded = MessageListState(
    status: MessageListStatus.loaded,
    messages: msgs,
    loggedInUser: _alice,
  );
  final bloc = MockMessageListBloc();
  whenListen(
    bloc,
    Stream<MessageListState>.fromIterable([initial, empty, loaded]),
    initialState: initial,
  );
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

void main() {
  setUpAll(() {
    registerFallbackValue(_text('fallback'));
    registerFallbackValue(
      const LoadMessages(conversationWith: 'u2', conversationType: 'user'),
    );
  });

  group('layout', () {
    testWidgets('padding reaches the root container', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              padding: const EdgeInsets.all(21),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_root(tester).padding, const EdgeInsets.all(21));
    });

    testWidgets('margin reaches the root container', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              margin: const EdgeInsets.only(left: 17),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_root(tester).margin, const EdgeInsets.only(left: 17));
    });

    testWidgets('height reaches the root container', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              height: 321,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(tester.getSize(find.byType(CometChatMessageList)).height, 321);
    });

    testWidgets('width reaches the root container', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CometChatMessageList(
                user: _bob,
                messageListBloc: _mock(),
                width: 234,
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(tester.getSize(find.byType(CometChatMessageList)).width, 234);
    });

    testWidgets('style paints its backgroundColor on the root container', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              style: const CometChatMessageListStyle(
                backgroundColor: Color(0xFF123456),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        (_root(tester).decoration as BoxDecoration).color,
        const Color(0xFF123456),
      );
    });
  });

  group('slot views', () {
    testWidgets('headerView renders above the list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              headerView: (context, {user, group, parentMessageId}) =>
                  const Text('HEADER_SLOT'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('HEADER_SLOT'), findsOneWidget);
    });

    testWidgets('footerView renders below the list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              footerView: (context, {user, group, parentMessageId}) =>
                  const Text('FOOTER_SLOT'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('FOOTER_SLOT'), findsOneWidget);
    });

    testWidgets('emptyStateView renders on the empty status', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(
                status: MessageListStatus.empty,
                messages: const [],
              ),
              emptyStateView: (context) => const Text('EMPTY_SLOT'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('EMPTY_SLOT'), findsOneWidget);
    });

    testWidgets('emptyChatGreetingView wins over emptyStateView', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(
                status: MessageListStatus.empty,
                messages: const [],
              ),
              emptyStateView: (context) => const Text('EMPTY_SLOT'),
              emptyChatGreetingView: (context) => const Text('GREETING_SLOT'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('GREETING_SLOT'), findsOneWidget);
      expect(find.text('EMPTY_SLOT'), findsNothing);
    });

    testWidgets('errorStateView renders on the error status', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(
                status: MessageListStatus.error,
                messages: const [],
                errorMessage: 'boom',
              ),
              errorStateView: (context) => const Text('ERROR_SLOT'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('ERROR_SLOT'), findsOneWidget);
    });

    testWidgets('errorStateText renders when no errorStateView is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(
                status: MessageListStatus.error,
                messages: const [],
                errorMessage: 'boom',
              ),
              errorStateText: 'ERROR_COPY',
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('ERROR_COPY'), findsOneWidget);
    });

    testWidgets('loadingStateView renders on the loading status', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(
                status: MessageListStatus.loading,
                messages: const [],
              ),
              loadingStateView: (context) => const Text('LOADING_SLOT'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('LOADING_SLOT'), findsOneWidget);
    });
  });

  group('identity and data sources', () {
    testWidgets('user is handed to the header slot', (tester) async {
      User? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              headerView: (context, {user, group, parentMessageId}) {
                seen = user;
                return Text('U:${user?.uid}');
              },
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(seen?.uid, 'u2');
      expect(find.text('U:u2'), findsOneWidget);
    });

    testWidgets('group is handed to the header slot', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              group: _group,
              messageListBloc: _mock(),
              headerView: (context, {user, group, parentMessageId}) =>
                  Text('G:${group?.guid}'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('G:g1'), findsOneWidget);
    });

    testWidgets('parentMessageId is handed to the header slot', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              parentMessageId: 99,
              headerView: (context, {user, group, parentMessageId}) =>
                  Text('P:$parentMessageId'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('P:99'), findsOneWidget);
    });

    testWidgets('messageListBloc drives the rendered messages', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(messages: [_text('INJECTED_BODY')]),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        find.textContaining('INJECTED_BODY', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('scrollController is attached to the real list', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              scrollController: controller,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(controller.hasClients, isTrue);
    });
  });

  group('bubble alignment and adornments', () {
    testWidgets('alignment standard right-aligns the logged-in user bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(user: _bob, messageListBloc: _mock()),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatMessageBubble>(find.byType(CometChatMessageBubble))
            .alignment,
        BubbleAlignment.right,
      );
    });

    testWidgets('alignment leftAligned left-aligns the logged-in user bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              alignment: ChatAlignment.leftAligned,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatMessageBubble>(find.byType(CometChatMessageBubble))
            .alignment,
        BubbleAlignment.left,
      );
    });

    testWidgets('avatarVisibility shows the sender avatar in a group', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              group: _group,
              messageListBloc: _mock(messages: [_text('hi', sender: _bob)]),
              avatarVisibility: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatAvatar), findsWidgets);
    });

    testWidgets('avatarVisibility false hides the sender avatar', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              group: _group,
              messageListBloc: _mock(messages: [_text('hi', sender: _bob)]),
              avatarVisibility: false,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatAvatar), findsNothing);
    });

    testWidgets('hideTimestamp removes the bubble timestamp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideTimestamp: true,
              hideDateSeparator: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((d) => RegExp(r'\d{1,2}:\d{2}').hasMatch(d));
      expect(texts, isEmpty);
    });

    testWidgets('hideTimestamp false keeps the bubble timestamp', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideTimestamp: false,
              hideDateSeparator: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((d) => RegExp(r'\d{1,2}:\d{2}').hasMatch(d));
      expect(texts, isNotEmpty);
    });

    testWidgets('datePattern builds the bubble timestamp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideDateSeparator: true,
              datePattern: (message) => 'STAMP_${message.id}',
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('STAMP_1'), findsOneWidget);
    });

    testWidgets('dateTimeFormatterCallback time builds the bubble timestamp, '
        'and datePattern wins over it', (tester) async {
      Future<void> pump({String Function(BaseMessage)? datePattern}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                key: UniqueKey(),
                user: _bob,
                messageListBloc: _mock(),
                hideDateSeparator: true,
                hideStickyDate: true,
                dateTimeFormatterCallback: TestTimeFormatter(),
                datePattern: datePattern,
              ),
            ),
          ),
        );
        await _settle(tester);
      }

      await pump();
      expect(find.text('FORMATTED_TIME'), findsOneWidget);

      await pump(datePattern: (message) => 'STAMP_${message.id}');
      expect(find.text('STAMP_1'), findsOneWidget);
      expect(find.text('FORMATTED_TIME'), findsNothing);
    });

    testWidgets('receiptsVisibility renders a receipt on outgoing messages', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              receiptsVisibility: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatReceipt), findsWidgets);
    });

    testWidgets('receiptsVisibility false renders no receipt', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              receiptsVisibility: false,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatReceipt), findsNothing);
    });
  });

  group('bloc configuration threaded on the non-injected path', () {
    // These three props are consumed only when the widget builds its own
    // MessageListBloc. The bloc is read back through the BlocProvider the
    // widget publishes, so the value is verified where it lands, not where
    // it was assigned. The SDK is uninitialised, so its async failure is
    // absorbed — the synchronous build path is what is under test.
    testWidgets(
      'hideReplies, hideDeletedMessages and withParent reach the bloc',
      (tester) async {
        MessageListBloc? built;
        await runZonedGuarded(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: CometChatMessageList(
                  user: _bob,
                  hideReplies: false,
                  hideDeletedMessages: true,
                  withParent: false,
                  headerView: (context, {user, group, parentMessageId}) {
                    built = BlocProvider.of<MessageListBloc>(context);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          );
          await tester.pump();
        }, (error, stack) {});
        expect(built, isNotNull);
        expect(built!.hideReplies, isFalse);
        expect(built!.hideDeletedMessages, isTrue);
        expect(built!.withParent, isFalse);
      },
    );

    testWidgets('the same three props carry their opposite values', (
      tester,
    ) async {
      MessageListBloc? built;
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                user: _bob,
                hideReplies: true,
                hideDeletedMessages: false,
                withParent: true,
                headerView: (context, {user, group, parentMessageId}) {
                  built = BlocProvider.of<MessageListBloc>(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        await tester.pump();
      }, (error, stack) {});
      expect(built!.hideReplies, isTrue);
      expect(built!.hideDeletedMessages, isFalse);
      expect(built!.withParent, isTrue);
    });
  });

  group('message options', () {
    // Each option prop is verified by the action item it removes from the
    // overlay the list actually pushes — not by reading the field back.
    testWidgets('all default options are present for an outgoing message', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(user: _bob, messageListBloc: _mock()),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _actionIds(await _openActions(tester)),
        containsAll(<String>[
          'replyMessage',
          'replyInThreadMessage',
          'shareMessage',
          'copyMessage',
          'editMessage',
          'messageInformation',
          'deleteMessage',
        ]),
      );
    });

    testWidgets('hideReplyOption removes the reply action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideReplyOption: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _actionIds(await _openActions(tester)),
        isNot(contains('replyMessage')),
      );
    });

    testWidgets('hideReplyInThreadOption removes the thread-reply action', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideReplyInThreadOption: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _actionIds(await _openActions(tester)),
        isNot(contains('replyInThreadMessage')),
      );
    });

    testWidgets('hideShareMessageOption removes the share action', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideShareMessageOption: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _actionIds(await _openActions(tester)),
        isNot(contains('shareMessage')),
      );
    });

    testWidgets('hideCopyMessageOption removes the copy action', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideCopyMessageOption: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _actionIds(await _openActions(tester)),
        isNot(contains('copyMessage')),
      );
    });

    testWidgets('hideEditMessageOption removes the edit action', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideEditMessageOption: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _actionIds(await _openActions(tester)),
        isNot(contains('editMessage')),
      );
    });

    testWidgets(
      'hideMessageInfoOption removes the message-information action',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                user: _bob,
                messageListBloc: _mock(),
                hideMessageInfoOption: true,
              ),
            ),
          ),
        );
        await _settle(tester);
        expect(
          _actionIds(await _openActions(tester)),
          isNot(contains('messageInformation')),
        );
      },
    );

    testWidgets('hideDeleteMessageOption removes the delete action', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideDeleteMessageOption: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _actionIds(await _openActions(tester)),
        isNot(contains('deleteMessage')),
      );
    });

    testWidgets('hideMessagePrivatelyOption removes the private-reply action', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              group: _group,
              messageListBloc: _mock(messages: [_text('hi', sender: _bob)]),
              hideMessagePrivatelyOption: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _actionIds(await _openActions(tester)),
        isNot(contains('sendMessagePrivately')),
      );
    });

    testWidgets('showMarkAsUnreadOption adds the mark-as-unread action', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              group: _group,
              messageListBloc: _mock(messages: [_text('hi', sender: _bob)]),
              showMarkAsUnreadOption: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_actionIds(await _openActions(tester)), contains('markAsUnread'));
    });

    testWidgets('hideFlagOption removes the report action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              group: _group,
              messageListBloc: _mock(messages: [_text('hi', sender: _bob)]),
              hideFlagOption: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        _actionIds(await _openActions(tester)),
        isNot(contains('reportMessage')),
      );
    });

    testWidgets('hideTranslateMessageOption reaches the template contract', (
      tester,
    ) async {
      // The v6 option set has no translate entry, so this prop has no action
      // item to remove. It is verified at the hand-off the list actually
      // makes — the AdditionalConfigurations passed to template.options.
      AdditionalConfigurations? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideTranslateMessageOption: true,
              templates: [_capturingTemplate((c) => seen = c)],
            ),
          ),
        ),
      );
      await _settle(tester);
      await _openActions(tester);
      expect(seen?.hideTranslateMessageOption, isTrue);
    });
  });

  group('reactions', () {
    testWidgets('favoriteReactions reach the action overlay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              favoriteReactions: const ['🔥', '🎉'],
            ),
          ),
        ),
      );
      await _settle(tester);
      expect((await _openActions(tester)).favoriteReactions, ['🔥', '🎉']);
    });

    testWidgets('addReactionIcon reaches the action overlay', (tester) async {
      const icon = Icon(Icons.add_reaction, key: Key('ADD_REACTION'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              addReactionIcon: icon,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect((await _openActions(tester)).addReactionIcon, same(icon));
    });

    testWidgets('disableReactions hides the reaction strip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              disableReactions: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect((await _openActions(tester)).hideReactions, isTrue);
    });

    testWidgets('hideReactionOption hides the reaction strip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideReactionOption: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect((await _openActions(tester)).hideReactions, isTrue);
    });

    testWidgets('reactions are shown when neither flag is set', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              disableReactions: false,
              hideReactionOption: false,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect((await _openActions(tester)).hideReactions, isFalse);
    });

    testWidgets('addMoreReactionTap fires from the overlay', (tester) async {
      BaseMessage? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              addMoreReactionTap: (message) => tapped = message,
            ),
          ),
        ),
      );
      await _settle(tester);
      final overlay = await _openActions(tester);
      overlay.onAddReactionTap!(_text('hello world'));
      expect(tapped, isNotNull);
    });
  });

  group('lifecycle callbacks', () {
    testWidgets('onLoad fires with the loaded messages', (tester) async {
      List<BaseMessage>? loaded;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mockTransition(MessageListStatus.loaded),
              onLoad: (messages) => loaded = messages,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(loaded, isNotNull);
      expect(loaded, hasLength(1));
    });

    testWidgets('onEmpty fires on the empty status', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mockTransition(
                MessageListStatus.empty,
                messages: const [],
              ),
              onEmpty: () => fired = true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(fired, isTrue);
    });

    testWidgets('onError fires on the error status', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mockTransition(
                MessageListStatus.error,
                messages: const [],
                errorMessage: 'boom',
              ),
              onError: (e) => fired = true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(fired, isTrue);
    });

    testWidgets('stateCallBack hands out the list controller', (tester) async {
      Object? controller;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              stateCallBack: (state) => controller = state,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(controller, isNotNull);
    });
  });

  group('swipe, separators and group actions', () {
    testWidgets('enableSwipeToReply arms the swipe wrapper', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              enableSwipeToReply: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatMessageSwipe>(find.byType(CometChatMessageSwipe))
            .enabled,
        isTrue,
      );
    });

    testWidgets('enableSwipeToReply false disarms the swipe wrapper', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              enableSwipeToReply: false,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatMessageSwipe>(find.byType(CometChatMessageSwipe))
            .enabled,
        isFalse,
      );
    });

    testWidgets('hideDateSeparator removes the day separator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideDateSeparator: true,
              hideStickyDate: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatDate), findsNothing);
    });

    testWidgets('hideDateSeparator false keeps the day separator', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideDateSeparator: false,
              hideStickyDate: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatDate), findsWidgets);
    });

    testWidgets('dateSeparatorPattern rewrites the separator label', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideStickyDate: true,
              dateSeparatorPattern: (date) => 'SEPARATOR_LABEL',
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('SEPARATOR_LABEL'), findsOneWidget);
    });

    testWidgets('dateSeparatorStyle reaches the separator widget', (
      tester,
    ) async {
      const style = CometChatDateStyle(textStyle: TextStyle(fontSize: 27));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideStickyDate: true,
              dateSeparatorStyle: style,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatDate>(find.byType(CometChatDate).first)
            .style
            .textStyle
            ?.fontSize,
        27,
      );
    });

    testWidgets('dateTimeFormatterCallback reaches the separator widget', (
      tester,
    ) async {
      final formatter = TestDateFormatter();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideStickyDate: true,
              dateTimeFormatterCallback: formatter,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatDate>(find.byType(CometChatDate).first)
            .dateTimeFormatterCallback,
        same(formatter),
      );
    });

    testWidgets('hideStickyDate removes the floating date header', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideStickyDate: true,
              hideDateSeparator: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatDate), findsNothing);
    });

    testWidgets('hideGroupActionMessages collapses group action messages', (
      tester,
    ) async {
      final action = sdk.Action(
        id: 7,
        sender: _bob,
        receiver: _group,
        receiverUid: 'g1',
        type: MessageTypeConstants.groupActions,
        receiverType: ReceiverTypeConstants.group,
        category: MessageCategoryConstants.action,
        sentAt: _at(1700000000000),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              group: _group,
              messageListBloc: _mock(messages: [action]),
              hideGroupActionMessages: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatMessageBubble), findsNothing);
    });
  });

  group('receipt icons', () {
    testWidgets('sentIcon, deliveredIcon, readIcon and waitIcon reach '
        'the receipt widget', (tester) async {
      const sent = Icon(Icons.done, key: Key('SENT'));
      const delivered = Icon(Icons.done_all, key: Key('DELIVERED'));
      const read = Icon(Icons.remove_red_eye, key: Key('READ'));
      const wait = Icon(Icons.schedule, key: Key('WAIT'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              receiptsVisibility: true,
              sentIcon: sent,
              deliveredIcon: delivered,
              readIcon: read,
              waitIcon: wait,
            ),
          ),
        ),
      );
      await _settle(tester);
      final receipt = tester.widget<CometChatReceipt>(
        find.byType(CometChatReceipt).first,
      );
      expect(receipt.sentIcon, same(sent));
      expect(receipt.deliveredIcon, same(delivered));
      expect(receipt.readIcon, same(read));
      expect(receipt.waitIcon, same(wait));
    });
  });

  group('templates and formatters', () {
    testWidgets('templates replaces the rendered content view', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              templates: [_contentTemplate('TEMPLATE_CONTENT')],
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('TEMPLATE_CONTENT'), findsOneWidget);
    });

    testWidgets('addTemplate overrides the default for its type/category', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              addTemplate: [_contentTemplate('ADDED_CONTENT')],
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('ADDED_CONTENT'), findsOneWidget);
    });

    testWidgets('textFormatters reach the content view configurations', (
      tester,
    ) async {
      final formatter = CometChatMentionsFormatter();
      AdditionalConfigurations? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              textFormatters: [formatter],
              templates: [
                _contentTemplate('C', onConfigurations: (c) => seen = c),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(seen?.textFormatters, contains(formatter));
    });

    testWidgets('additionalConfigurations is passed through verbatim', (
      tester,
    ) async {
      final configurations = AdditionalConfigurations(
        hideCopyMessageOption: true,
      );
      AdditionalConfigurations? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              additionalConfigurations: configurations,
              templates: [
                _contentTemplate('C', onConfigurations: (c) => seen = c),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(seen, same(configurations));
    });

    testWidgets('enableMultipleAttachments reaches the content view '
        'configurations', (tester) async {
      AdditionalConfigurations? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              enableMultipleAttachments: true,
              templates: [
                _contentTemplate('C', onConfigurations: (c) => seen = c),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(seen?.enableMultipleAttachments, isTrue);
    });
  });

  group('load-time bloc events', () {
    testWidgets('goToMessageId dispatches a jump instead of a normal load', (
      tester,
    ) async {
      final bloc = _mock();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: bloc,
              goToMessageId: 4242,
            ),
          ),
        ),
      );
      // _waitForJumpTarget arms a 5s fallback timer; drain it so the test
      // does not end with a pending timer.
      await _settle(tester);
      await tester.pump(const Duration(seconds: 6));
      expect(_events(bloc).whereType<JumpToMessage>().single.messageId, 4242);
    });

    testWidgets('startFromUnreadMessages dispatches LoadFromUnread', (
      tester,
    ) async {
      final bloc = _mock();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: bloc,
              startFromUnreadMessages: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_events(bloc).whereType<LoadFromUnread>(), isNotEmpty);
    });

    testWidgets('startFromUnreadMessages false dispatches LoadMessages', (
      tester,
    ) async {
      final bloc = _mock();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: bloc,
              startFromUnreadMessages: false,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_events(bloc).whereType<LoadMessages>(), isNotEmpty);
    });

    testWidgets(
      'messagesRequestBuilder supplies the parentMessageId fallback',
      (tester) async {
        final bloc = _mock();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                user: _bob,
                messageListBloc: bloc,
                messagesRequestBuilder: MessagesRequestBuilder()
                  ..parentMessageId = 555,
              ),
            ),
          ),
        );
        await _settle(tester);
        expect(
          _events(bloc).whereType<LoadMessages>().single.parentMessageId,
          555,
        );
      },
    );
  });

  group('moderation and bloc-level toggles', () {
    testWidgets('hideModerationView drives the moderation visibility flag', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideModerationView: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(ModerationCheckUtil.instance.hideModerationStatus, isTrue);
    });

    testWidgets('hideModerationView false clears the moderation flag', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(),
              hideModerationView: false,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(ModerationCheckUtil.instance.hideModerationStatus, isFalse);
    });

    testWidgets('disableReceipts and disableSoundForMessages reach the bloc', (
      tester,
    ) async {
      MessageListBloc? built;
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                user: _bob,
                disableReceipts: true,
                disableSoundForMessages: true,
                headerView: (context, {user, group, parentMessageId}) {
                  built = BlocProvider.of<MessageListBloc>(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        await tester.pump();
      }, (error, stack) {});
      expect(built!.disableReceipts, isTrue);
      expect(built!.disableSoundForMessages, isTrue);
    });
  });

  group('incoming sound', () {
    // What the bloc does with these is covered, down to the platform call, by
    // message_list_incoming_sound_test.dart. Here: the widget hands them on.
    testWidgets('customSoundForMessages and customSoundForMessagePackage '
        'reach the bloc', (tester) async {
      MessageListBloc? built;
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                user: _bob,
                customSoundForMessages: 'sounds/ping.mp3',
                customSoundForMessagePackage: 'my_sounds',
                headerView: (context, {user, group, parentMessageId}) {
                  built = BlocProvider.of<MessageListBloc>(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        await tester.pump();
      }, (error, stack) {});
      expect(built!.customSoundForMessages, 'sounds/ping.mp3');
      expect(built!.customSoundForMessagePackage, 'my_sounds');
    });
  });

  group('threads', () {
    testWidgets('hideThreadView removes the thread-replies row', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mockWithThread(3),
              hideThreadView: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatMessageBubble>(find.byType(CometChatMessageBubble))
            .threadView,
        isNull,
      );
    });

    testWidgets('hideThreadView false keeps the thread-replies row', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mockWithThread(3),
              hideThreadView: false,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        tester
            .widget<CometChatMessageBubble>(find.byType(CometChatMessageBubble))
            .threadView,
        isNotNull,
      );
    });

    testWidgets('onThreadRepliesClick fires when the thread row is tapped', (
      tester,
    ) async {
      BaseMessage? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mockWithThread(3),
              onThreadRepliesClick: (message, context, {template}) =>
                  opened = message,
            ),
          ),
        ),
      );
      await _settle(tester);
      final threadTap = find.descendant(
        of: find.byType(CometChatMessageBubble),
        matching: find.byWidgetPredicate(
          (w) => w is GestureDetector && w.onTap != null,
        ),
      );
      tester.widget<GestureDetector>(threadTap.first).onTap!();
      await _settle(tester);
      expect(opened, isNotNull);
    });
  });

  group('reaction callbacks', () {
    testWidgets('onReactionClick fires from a reaction chip', (tester) async {
      String? clicked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(messages: [_reacted('with reactions')]),
              onReactionClick: (reaction, message) => clicked = reaction,
            ),
          ),
        ),
      );
      await _settle(tester);
      tester
          .widget<CometChatReactions>(find.byType(CometChatReactions).first)
          .onReactionTap!('🔥');
      expect(clicked, '🔥');
    });

    testWidgets('onReactionLongPress fires from a reaction chip', (
      tester,
    ) async {
      String? held;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(messages: [_reacted('with reactions')]),
              onReactionLongPress: (reaction, message) => held = reaction,
            ),
          ),
        ),
      );
      await _settle(tester);
      tester
          .widget<CometChatReactions>(find.byType(CometChatReactions).first)
          .onReactionLongPress!('🔥');
      expect(held, '🔥');
    });

    testWidgets('reactionsRequestBuilder and onReactionListItemClick reach '
        'the reaction list sheet', (tester) async {
      final builder = ReactionsRequestBuilder()..messageId = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mock(messages: [_reacted('with reactions')]),
              reactionsRequestBuilder: builder,
              onReactionListItemClick: (reaction, message) {},
            ),
          ),
        ),
      );
      await _settle(tester);
      tester
          .widget<CometChatReactions>(find.byType(CometChatReactions).first)
          .onReactionLongPress!('🔥');
      await _settle(tester);
      final list = tester.widget<CometChatReactionList>(
        find.byType(CometChatReactionList),
      );
      expect(list.reactionRequestBuilder, same(builder));
      expect(list.onReactionListItemClick, isNotNull);
    });
  });

  group('flag dialog', () {
    testWidgets(
      'flagReasonLocalizer and hideFlagRemarkField reach the dialog',
      (tester) async {
        String localizer(String reason) => 'LOCALIZED_$reason';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                group: _group,
                messageListBloc: _mock(messages: [_text('hi', sender: _bob)]),
                flagReasonLocalizer: localizer,
                hideFlagRemarkField: true,
              ),
            ),
          ),
        );
        await _settle(tester);
        final overlay = await _openActions(tester);
        final report = overlay.actionItems.firstWhere(
          (a) => a.id == 'reportMessage',
        );
        report.onItemClick();
        await _settle(tester);
        final dialog = tester.widget<CometChatFlagMessageDialog>(
          find.byType(CometChatFlagMessageDialog),
        );
        expect(dialog.hideFlagRemarkField, isTrue);
        expect(dialog.flagReasonLocalizer, isNotNull);
      },
    );
  });

  group('AI panels', () {
    testWidgets(
      'enableConversationStarters renders the starter panel while empty',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                user: _bob,
                messageListBloc: _mockEmpty(),
                enableConversationStarters: true,
              ),
            ),
          ),
        );
        await _settle(tester);
        expect(find.byType(CometChatAIConversationStarterView), findsOneWidget);
      },
    );

    testWidgets('enableConversationStarters false publishes no starter panel', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mockEmptyThenLoaded(),
              enableConversationStarters: false,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(CometChatAIConversationStarterView), findsNothing);
    });

    // Smart replies are triggered by an *insert* operation on an incoming
    // message whose text passes the smartRepliesKeywords gate.
    testWidgets('enableSmartReplies shows the panel once the delay elapses', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mockInserting(
                _text('what time is it?', sender: _bob),
              ),
              enableSmartReplies: true,
              smartRepliesDelayDuration: 3000,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        find.byType(CometChatAISmartRepliesView),
        findsNothing,
        reason: 'the debounce delay has not elapsed yet',
      );
      await tester.pump(const Duration(milliseconds: 3500));
      expect(find.byType(CometChatAISmartRepliesView), findsOneWidget);
    });

    testWidgets('enableSmartReplies false never shows the panel', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mockInserting(
                _text('what time is it?', sender: _bob),
              ),
              enableSmartReplies: false,
              smartRepliesDelayDuration: 1000,
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byType(CometChatAISmartRepliesView), findsNothing);
    });

    testWidgets('smartRepliesDelayDuration governs when the panel appears', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mockInserting(
                _text('what time is it?', sender: _bob),
              ),
              enableSmartReplies: true,
              smartRepliesDelayDuration: 8000,
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 4000));
      expect(
        find.byType(CometChatAISmartRepliesView),
        findsNothing,
        reason: '4s into an 8s debounce',
      );
      await tester.pump(const Duration(milliseconds: 4500));
      expect(find.byType(CometChatAISmartRepliesView), findsOneWidget);
    });

    testWidgets('smartRepliesKeywords suppresses a non-matching message', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mockInserting(
                _text('thanks a lot', sender: _bob),
              ),
              enableSmartReplies: true,
              smartRepliesDelayDuration: 1000,
              smartRepliesKeywords: const ['refund'],
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byType(CometChatAISmartRepliesView), findsNothing);
    });

    testWidgets('smartRepliesKeywords admits a matching message', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: _bob,
              messageListBloc: _mockInserting(
                _text('I need a refund', sender: _bob),
              ),
              enableSmartReplies: true,
              smartRepliesDelayDuration: 1000,
              smartRepliesKeywords: const ['refund'],
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byType(CometChatAISmartRepliesView), findsOneWidget);
    });
  });

  group('AI conversation', () {
    final aiUser = User(uid: 'ai1', name: 'Assistant', role: AIConstants.aiRole)
      ..metadata = {
        AIConstants.suggestedMessages: ['Ask me anything'],
      };

    testWidgets('hideSuggestedMessages removes the greeting suggestions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: aiUser,
              messageListBloc: _mock(
                status: MessageListStatus.empty,
                messages: const [],
              ),
              hideSuggestedMessages: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('Ask me anything'), findsNothing);
    });

    testWidgets('hideSuggestedMessages false keeps the greeting suggestions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: aiUser,
              messageListBloc: _mock(
                status: MessageListStatus.empty,
                messages: const [],
              ),
              hideSuggestedMessages: false,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('Ask me anything'), findsOneWidget);
    });

    testWidgets('suggestedMessages replaces the metadata suggestions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: aiUser,
              messageListBloc: _mock(
                status: MessageListStatus.empty,
                messages: const [],
              ),
              suggestedMessages: const ['Plan my week', 'Summarise this'],
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('Plan my week'), findsOneWidget);
      expect(find.text('Summarise this'), findsOneWidget);
      expect(find.text('Ask me anything'), findsNothing);
    });

    testWidgets('loadLastAgentConversation dispatches the history load', (
      tester,
    ) async {
      final bloc = _mock(status: MessageListStatus.empty, messages: const []);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CometChatMessageList(
              user: aiUser,
              messageListBloc: bloc,
              loadLastAgentConversation: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(_events(bloc).whereType<LoadLastAgentConversation>(), isNotEmpty);
    });
  });
  // Props the 6.2.0 CHANGELOG had deprecated as no-ops. The v6 docs list the
  // four list props, and Android applies an outgoing messagePreviewStyle, so
  // they take effect instead.
  group('mentions, empty-state text and the reply preview', () {
    /// Every plain text the bubbles render, whether a mention is its own
    /// widget or a span inside the message's rich text.
    String renderedText(WidgetTester tester) => tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .join(' | ');

    /// Wraps [list] the way every test in this group pumps it.
    Widget host(CometChatMessageList list) =>
        MaterialApp(home: Scaffold(body: list));

    testWidgets('mentionAllLabel replaces the @all label in bubbles', (
      tester,
    ) async {
      final message = _text('<@all:all> standup in five');
      Future<void> pump({String? mentionAllLabel}) async {
        await tester.pumpWidget(
          host(
            CometChatMessageList(
              key: UniqueKey(),
              user: _bob,
              messageListBloc: _mock(messages: [message]),
              mentionAllLabel: mentionAllLabel,
            ),
          ),
        );
        await _settle(tester);
      }

      await pump();
      expect(renderedText(tester), isNot(contains('@Everyone')));

      await pump(mentionAllLabel: 'Everyone');
      expect(renderedText(tester), contains('@Everyone'));
      expect(renderedText(tester), isNot(contains('<@all:all>')));
    });

    testWidgets('mentionAllLabelId makes that id format as @all', (
      tester,
    ) async {
      final message = _text('<@all:engineering> standup in five');
      Future<void> pump({String? mentionAllLabelId}) async {
        await tester.pumpWidget(
          host(
            CometChatMessageList(
              key: UniqueKey(),
              user: _bob,
              messageListBloc: _mock(messages: [message]),
              mentionAllLabelId: mentionAllLabelId,
            ),
          ),
        );
        await _settle(tester);
      }

      // By default only "all" is an @all id, so the token stays raw.
      await pump();
      expect(renderedText(tester), contains('<@all:engineering>'));

      await pump(mentionAllLabelId: 'engineering');
      expect(renderedText(tester), isNot(contains('<@all:engineering>')));
    });

    testWidgets('disableMentions renders mentions unformatted', (tester) async {
      final message = _text('<@uid:u2> ping')..mentionedUsers = [_bob];
      Future<void> pump({bool? disableMentions}) async {
        await tester.pumpWidget(
          host(
            CometChatMessageList(
              key: UniqueKey(),
              user: _bob,
              messageListBloc: _mock(messages: [message]),
              disableMentions: disableMentions,
            ),
          ),
        );
        await _settle(tester);
      }

      await pump();
      expect(renderedText(tester), contains('@Bob'));

      await pump(disableMentions: true);
      expect(renderedText(tester), isNot(contains('@Bob')));
      expect(renderedText(tester), contains('<@uid:u2>'));
    });

    testWidgets('disableMentions also drops a mentions formatter passed in '
        'textFormatters', (tester) async {
      final message = _text('<@uid:u2> ping')..mentionedUsers = [_bob];
      Future<void> pump({bool? disableMentions}) async {
        await tester.pumpWidget(
          host(
            CometChatMessageList(
              key: UniqueKey(),
              user: _bob,
              messageListBloc: _mock(messages: [message]),
              textFormatters: [CometChatMentionsFormatter()],
              disableMentions: disableMentions,
            ),
          ),
        );
        await _settle(tester);
      }

      await pump();
      expect(renderedText(tester), contains('@Bob'));

      await pump(disableMentions: true);
      expect(renderedText(tester), isNot(contains('@Bob')));
    });

    testWidgets('emptyStateText is shown on the empty status', (tester) async {
      Future<void> pump({String? emptyStateText}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                key: UniqueKey(),
                user: _bob,
                messageListBloc: _mock(
                  status: MessageListStatus.empty,
                  messages: const [],
                ),
                emptyStateText: emptyStateText,
              ),
            ),
          ),
        );
        await _settle(tester);
      }

      await pump();
      expect(find.text('NOTHING_HERE_YET'), findsNothing);

      await pump(emptyStateText: 'NOTHING_HERE_YET');
      expect(find.text('NOTHING_HERE_YET'), findsOneWidget);
    });

    testWidgets('an outgoing bubble style\'s messagePreviewStyle reaches the '
        'reply preview', (tester) async {
      const background = Color(0xFF13579B);
      const titleColor = Color(0xFFB97531);
      // Alice is the logged-in user, so her reply is an outgoing bubble.
      final reply = _text('sounds good', id: 2)
        ..quotedMessageId = 1
        ..quotedMessage = _text('lunch?', id: 1, sender: _bob);

      Future<void> pump({CometChatMessagePreviewStyle? previewStyle}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CometChatMessageList(
                key: UniqueKey(),
                user: _bob,
                messageListBloc: _mock(messages: [reply]),
                style: CometChatMessageListStyle(
                  outgoingMessageBubbleStyle:
                      CometChatOutgoingMessageBubbleStyle(
                        messagePreviewStyle: previewStyle,
                      ),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);
      }

      Iterable<Color?> previewBackgrounds() => tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(CometChatMessagePreview),
              matching: find.byType(Container),
            ),
          )
          .map((c) => (c.decoration as BoxDecoration?)?.color);

      Color? previewTitleColor() => tester
          .widget<Text>(
            find.descendant(
              of: find.byType(CometChatMessagePreview),
              matching: find.text('Bob'),
            ),
          )
          .style
          ?.color;

      await pump();
      expect(find.byType(CometChatMessagePreview), findsOneWidget);
      expect(previewBackgrounds(), isNot(contains(background)));
      expect(previewTitleColor(), isNot(titleColor));

      await pump(
        previewStyle: const CometChatMessagePreviewStyle(
          messagePreviewBackground: background,
          // A colour inside the text style beats the default white.
          messagePreviewTitleStyle: TextStyle(color: titleColor),
        ),
      );
      expect(previewBackgrounds(), contains(background));
      expect(previewTitleColor(), titleColor);
    });
  });
}
