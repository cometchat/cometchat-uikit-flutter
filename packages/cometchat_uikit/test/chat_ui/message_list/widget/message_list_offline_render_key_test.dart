// Render keys (W2, ENG-41092; W1 §2.3, PR #23 §3.2): an own bubble keeps its
// element from compose to ack, and with offline on the row carries the
// state-contract identifier. The row key never depends on the offline gate,
// so a flip mid-session remounts no row (ENG-41552 J).

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

TextMessage _own({required int id}) => TextMessage(
  id: id,
  text: 'hello',
  sender: _me,
  receiver: _them,
  receiverUid: 'u2',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
  muid: 'muid-1',
)..localMessageId = 'local-1';

class _Wired {
  _Wired(BaseMessage first) {
    final state = _state(first);
    whenListen(bloc, states.stream, initialState: state);
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

  static MessageListState _state(BaseMessage m) => MessageListState(
    status: MessageListStatus.loaded,
    messages: [m],
    loggedInUser: _me,
  );

  void show(BaseMessage m, {BaseMessage? replacing}) {
    states.add(_state(m));
    ops.add(
      replacing == null
          ? MessageOperation.set([m], animated: false)
          : MessageOperation.update(replacing, m, 0),
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

List<GlobalKey> _bubbleKeys(WidgetTester tester) => tester
    .widgetList<Material>(find.byType(Material))
    .map((m) => m.key)
    .whereType<GlobalKey>()
    .toList();

Iterable<String> _rowIds(WidgetTester tester) => tester
    .widgetList<Semantics>(find.byType(Semantics))
    .map((s) => s.properties.identifier)
    .whereType<String>()
    .where((id) => id.startsWith('cc.message.'));

void main() {
  setUpAll(() => registerFallbackValue(_own(id: 1)));
  setUp(() => CometChatUIKit.loggedInUser = _me);
  tearDown(() {
    CometChatUIKit.loggedInUser = null;
    CometChat.debugSetOfflineEnabledOverride(null);
  });

  Widget list(MessageListBloc bloc) => MaterialApp(
    home: Scaffold(
      body: CometChatMessageList(user: _them, messageListBloc: bloc),
    ),
  );

  testWidgets('ON: the own bubble is not remounted when its ack lands', (
    tester,
  ) async {
    CometChat.debugSetOfflineEnabledOverride(true);
    final pending = _own(id: 0);
    final w = _Wired(pending);
    await tester.pumpWidget(list(w.bloc));
    w.show(pending);
    await _settle(tester);

    final keys = _bubbleKeys(tester);
    expect(keys, hasLength(1));
    final elementBefore = tester.element(find.byKey(keys.single));
    expect(_rowIds(tester), contains('cc.message.local-1.sent'));

    final acked = _own(id: 9);
    w.show(acked, replacing: pending);
    await _settle(tester);

    final after = _bubbleKeys(tester);
    expect(after, hasLength(1));
    expect(identical(after.single, keys.single), isTrue);
    expect(
      identical(tester.element(find.byKey(after.single)), elementBefore),
      isTrue,
      reason: 'the render key spans compose → ack: same element',
    );
    // The item key is the render key too, so it does not change on ack.
    final itemKeys = tester
        .widgetList<KeyedSubtree>(find.byType(KeyedSubtree))
        .map((k) => k.key)
        .whereType<ValueKey<String>>()
        .map((k) => k.value)
        .where((v) => v.startsWith('local-1-'));
    expect(itemKeys, isNotEmpty);
    expect(_rowIds(tester), contains('cc.message.local-1.sent'));
  });

  testWidgets('OFF: no contract row identifier; the item key is the render '
      'key, as with offline on', (tester) async {
    CometChat.debugSetOfflineEnabledOverride(false);
    final acked = _own(id: 9);
    final w = _Wired(acked);
    await tester.pumpWidget(list(w.bloc));
    w.show(acked);
    await _settle(tester);

    expect(_rowIds(tester), isEmpty);
    final itemKeys = tester
        .widgetList<KeyedSubtree>(find.byType(KeyedSubtree))
        .map((k) => k.key)
        .whereType<ValueKey<String>>()
        .map((k) => k.value);
    expect(itemKeys.where((v) => v.startsWith('local-1-')), isNotEmpty);
  });

  for (final startOn in [true, false]) {
    testWidgets('offline turned ${startOn ? 'off' : 'on'} mid-session: the '
        'row and its bubble stay mounted', (tester) async {
      CometChat.debugSetOfflineEnabledOverride(startOn);
      final acked = _own(id: 9);
      final w = _Wired(acked);
      await tester.pumpWidget(list(w.bloc));
      w.show(acked);
      await _settle(tester);
      final key = _bubbleKeys(tester).single;
      final bubble = tester.element(find.byKey(key));
      // The row's item (KeyedSubtree keyed by the render key).
      Element rowOf(GlobalKey k) => tester.element(
        find.ancestor(
          of: find.byKey(k),
          matching: find.byWidgetPredicate(
            (w) =>
                w is KeyedSubtree &&
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('local-1-'),
          ),
        ),
      );
      final row = rowOf(key);

      CometChat.debugSetOfflineEnabledOverride(!startOn);
      final again = _own(id: 9);
      w.show(again, replacing: acked);
      await _settle(tester);

      final after = _bubbleKeys(tester).single;
      expect(identical(after, key), isTrue);
      expect(identical(tester.element(find.byKey(after)), bubble), isTrue);
      expect(identical(rowOf(after), row), isTrue);
      // The contract identifier follows the gate on the same element.
      expect(
        _rowIds(tester),
        startOn ? isEmpty : contains('cc.message.local-1.sent'),
      );
    });
  }
}
