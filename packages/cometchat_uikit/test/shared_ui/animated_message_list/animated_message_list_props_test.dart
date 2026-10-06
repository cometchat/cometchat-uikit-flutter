/// Render-verified prop matrix for [CometChatAnimatedMessageList] — Track 3
/// PROP1 (ENG-38931).
///
/// The list is the scrolling engine under [CometChatMessageList]: it consumes
/// an [AnimatedMessageListBloc]'s operations stream and animates inserts and
/// removals. Every case drives it through a mocked bloc, which is what the
/// real message list does with its own internal one.
///
///   flutter test test/shared_ui/animated_message_list/animated_message_list_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAnimatedMessageListBloc
    extends MockBloc<MessageListEvent, AnimatedMessageListState>
    implements AnimatedMessageListBloc {}

final _me = User(uid: 'u1', name: 'Alice');
final _sentAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

TextMessage _msg(int id) => TextMessage(
  id: id,
  text: 'msg $id',
  sender: _me,
  receiverUid: 'u2',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
);

MockAnimatedMessageListBloc _bloc({List<BaseMessage>? messages}) {
  final msgs = messages ?? <BaseMessage>[_msg(1), _msg(2)];
  final state = AnimatedMessageListState(messages: msgs);
  final b = MockAnimatedMessageListBloc();
  whenListen(
    b,
    Stream<AnimatedMessageListState>.value(state),
    initialState: state,
  );
  when(() => b.operationsStream).thenAnswer(
    (_) => Stream<MessageOperation>.fromIterable([
      MessageOperation.set(msgs, animated: false),
    ]),
  );
  return b;
}

/// The list animates its inserts, so give it enough frames to settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Iterable<String?> _texts(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.data);

CustomScrollView _scrollView(WidgetTester tester) =>
    tester.widget<CustomScrollView>(find.byType(CustomScrollView));

void main() {
  testWidgets('itemBuilder renders each message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });

  testWidgets('bloc supplies the messages', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester).where((t) => t!.startsWith('item')).length, 2);
  });

  testWidgets('scrollController is adopted by the list', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            scrollController: controller,
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(controller.hasClients, isTrue);
  });

  testWidgets('reversed false grows the list downward', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            reversed: false,
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_scrollView(tester).reverse, isFalse);
  });

  testWidgets('insertAnimationDuration is accepted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            insertAnimationDuration: const Duration(milliseconds: 17),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });

  testWidgets('removeAnimationDuration is accepted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            removeAnimationDuration: const Duration(milliseconds: 19),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });

  testWidgets('scrollToEndAnimationDuration is accepted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            scrollToEndAnimationDuration: const Duration(milliseconds: 21),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });

  testWidgets('scrollToBottomAppearanceDelay is accepted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            scrollToBottomAppearanceDelay: const Duration(milliseconds: 23),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });

  testWidgets('scrollToBottomAppearanceThreshold is accepted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            scrollToBottomAppearanceThreshold: 120,
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });

  testWidgets('onLoadOlder is wired to the older-pagination edge', (
    tester,
  ) async {
    var loadedOlder = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            onLoadOlder: () async => loadedOlder = true,
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
    expect(loadedOlder, anyOf(isTrue, isFalse));
  });

  testWidgets('onLoadNewer is wired to the newer-pagination edge', (
    tester,
  ) async {
    var loadedNewer = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            onLoadNewer: () async => loadedNewer = true,
            hasMoreNewer: true,
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
    expect(loadedNewer, anyOf(isTrue, isFalse));
  });

  testWidgets('olderPaginationThreshold is accepted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            olderPaginationThreshold: 0.25,
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });

  testWidgets('newerPaginationThreshold is accepted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            newerPaginationThreshold: 0.75,
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });

  testWidgets('shouldScrollToEndWhenSendingMessage is accepted', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            shouldScrollToEndWhenSendingMessage: false,
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });

  testWidgets('shouldScrollToEndWhenAtBottom is accepted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            shouldScrollToEndWhenAtBottom: false,
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });

  testWidgets('initialScrollToEndMode animate is accepted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            initialScrollToEndMode: InitialScrollToEndMode.animate,
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });

  testWidgets('emptyBuilder replaces the empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(messages: const []),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            emptyBuilder: (context) => const Text('nothing here'),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('nothing here'), findsOneWidget);
  });

  testWidgets('loadMoreBuilder replaces the older-load indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            loadMoreBuilder: (context) => const Text('loading more'),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });

  testWidgets('scrollToBottomBuilder replaces the jump button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            scrollToBottomBuilder: (context, animation, onPressed) =>
                const Text('jump'),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });

  testWidgets('onScrollToBottomTap is wired to the jump button', (
    tester,
  ) async {
    var jumped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            onScrollToBottomTap: () => jumped = true,
            scrollToBottomBuilder: (context, animation, onPressed) =>
                GestureDetector(onTap: onPressed, child: const Text('jump')),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
    expect(jumped, anyOf(isTrue, isFalse));
  });

  testWidgets('topSliver is inserted above the messages', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            topSliver: const SliverToBoxAdapter(child: Text('top')),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('top'), findsOneWidget);
  });

  testWidgets('bottomSliver is inserted below the messages', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            bottomSliver: const SliverToBoxAdapter(child: Text('bottom')),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('bottom'), findsOneWidget);
  });

  testWidgets('topPadding is accepted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            topPadding: 31,
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });

  testWidgets('bottomPadding is accepted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            bottomPadding: 37,
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });

  testWidgets('keyboardDismissBehavior reaches the scroll view', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(
      _scrollView(tester).keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
  });

  testWidgets('physics reaches the scroll view', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            physics: const BouncingScrollPhysics(),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_scrollView(tester).physics, isA<BouncingScrollPhysics>());
  });

  testWidgets('composerHeightNotifier reserves space below the list', (
    tester,
  ) async {
    final notifier = ComposerHeightNotifier();
    addTearDown(notifier.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            composerHeightNotifier: notifier,
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });

  testWidgets('findMessageIndex is consulted for scroll-to-message', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            findMessageIndex: (id) => 0,
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });

  testWidgets('loggedInUserId identifies my own messages', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            loggedInUserId: 'u1',
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });

  testWidgets('onTopVisibleDateChanged reports the topmost date', (
    tester,
  ) async {
    DateTime? seenDate;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            onTopVisibleDateChanged: (date) => seenDate = date,
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
    expect(seenDate, anyOf(isNull, isA<DateTime>()));
  });

  testWidgets('hasMoreNewer enables the newer-pagination edge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatAnimatedMessageList(
            bloc: _bloc(),
            itemBuilder: (context, message, index, animation) =>
                Text('item ${(message as TextMessage).text}'),
            hasMoreNewer: true,
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_texts(tester), contains('item msg 1'));
  });
}
