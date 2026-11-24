// Offline ON scroll anchoring (W2, ENG-41092; PR #23 §3.3): when a read
// merges rows in below the viewport while the user is scrolled up, the first
// visible row stays where it is on screen. With offline off the list behaves
// as today (the rows are pushed).

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMessageListBloc extends MockBloc<MessageListEvent, MessageListState>
    implements MessageListBloc {}

final _me = User(uid: 'u1', name: 'Alice');
final _them = User(uid: 'u2', name: 'Bob');

TextMessage _m(int id) => TextMessage(
  id: id,
  text: 'row $id',
  sender: _them,
  receiver: _me,
  receiverUid: 'u1',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: DateTime.fromMillisecondsSinceEpoch(1700000000000 + id * 1000),
);

List<BaseMessage> _range(int from, int to) => [
  for (var i = from; i <= to; i++) _m(i),
];

class _Wired {
  _Wired(List<BaseMessage> rows) {
    whenListen(bloc, states.stream, initialState: _state(rows));
    when(() => bloc.operationsStream).thenAnswer((_) => ops.stream);
    when(() => bloc.findMessageIndex(any())).thenReturn(null);
    when(
      () => bloc.getReceiptNotifierForMessage(any()),
    ).thenReturn(ValueNotifier(MessageReceiptStatus.sent));
    when(
      () => bloc.getThreadReplyCountNotifier(any()),
    ).thenReturn(ValueNotifier<int>(0));
    when(
      () => bloc.initializeThreadReplyCount(any(), any()),
    ).thenAnswer((_) {});
    when(() => bloc.notifyMessageChanged(any())).thenAnswer((_) {});
  }

  final bloc = MockMessageListBloc();
  final states = StreamController<MessageListState>.broadcast();
  final ops = StreamController<MessageOperation>.broadcast();

  static MessageListState _state(List<BaseMessage> rows) => MessageListState(
    status: MessageListStatus.loaded,
    messages: rows,
    loggedInUser: _me,
  );

  void show(List<BaseMessage> rows, {List<BaseMessage>? old}) {
    states.add(_state(rows));
    ops.add(
      old == null
          ? MessageOperation.set(rows, animated: false)
          : MessageOperation.set(rows, oldMessages: old, animated: true),
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _row(int id) => find.text('row $id', findRichText: true);

/// The id and top of the first row fully inside the middle of the screen.
(int, double) _visibleRow(WidgetTester tester, int from, int to) {
  for (var id = to; id >= from; id--) {
    final f = _row(id);
    if (f.evaluate().isEmpty) continue;
    final dy = tester.getTopLeft(f).dy;
    if (dy > 150 && dy < 400) return (id, dy);
  }
  throw StateError('no row in the middle of the screen');
}

void main() {
  setUpAll(() => registerFallbackValue(_m(1)));
  setUp(() => CometChatUIKit.loggedInUser = _me);
  tearDown(() {
    CometChatUIKit.loggedInUser = null;
    CometChat.debugSetOfflineEnabledOverride(null);
  });

  Future<double> mergeBelowWhileScrolledUp(
    WidgetTester tester, {
    double offset = 120,
    ScrollController? scroll,
  }) async {
    final controller = scroll ?? ScrollController();
    addTearDown(controller.dispose);
    final rows = _range(1, 40);
    final w = _Wired(rows);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatMessageList(
            user: _them,
            messageListBloc: w.bloc,
            scrollController: controller,
          ),
        ),
      ),
    );
    w.show(rows);
    await _settle(tester);

    // Scrolled away from the bottom, inside the laid-out region.
    controller.jumpTo(offset);
    await _settle(tester);
    final (id, before) = offset == 0 ? (35, 0.0) : _visibleRow(tester, 1, 40);

    // A read merges three newer rows in below the viewport.
    final merged = [...rows, ..._range(41, 43)];
    w.show(merged, old: rows);
    await _settle(tester);
    expect(_row(id), findsOneWidget);
    return tester.getTopLeft(_row(id)).dy - before;
  }

  testWidgets('ON: the first visible row stays put when rows merge in below', (
    tester,
  ) async {
    CometChat.debugSetOfflineEnabledOverride(true);
    final moved = await mergeBelowWhileScrolledUp(tester);
    expect(moved.abs(), lessThan(1.0));
  });

  testWidgets('OFF: today\'s list pushes the rows up', (tester) async {
    CometChat.debugSetOfflineEnabledOverride(false);
    final moved = await mergeBelowWhileScrolledUp(tester);
    expect(moved, lessThan(-20.0), reason: 'the control: rows are pushed');
  });

  testWidgets('ON: at the bottom the list stays pinned to the newest row', (
    tester,
  ) async {
    CometChat.debugSetOfflineEnabledOverride(true);
    final controller = ScrollController();
    await mergeBelowWhileScrolledUp(tester, offset: 0, scroll: controller);
    expect(controller.offset, 0);
    expect(_row(43), findsOneWidget);
  });
}
