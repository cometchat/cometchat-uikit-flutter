/// Regression tests for ENG-39490 — sending any message rebuilt every bubble
/// in the list from scratch.
///
/// The list is reversed, so inserting one message shifts every visual index by
/// one and each slot comes to hold a *different* message. The identity key
/// used to sit inside each item's own subtree rather than on the widget the
/// sliver delegate returns, so the key the framework saw at a slot no longer
/// matched the element's, `Widget.canUpdate` said false, and the element was
/// thrown away and re-inflated. Every item's State was recreated on every
/// insert — a plain text message was enough to do it.
///
/// Audio bubbles showed it worst: a fresh State starts on a placeholder
/// waveform with no duration and re-runs an async file-exists check before it
/// can paint the real thing, which is the strobe QA filmed.
///
/// These pin the property that makes element reuse possible: every item the
/// delegate emits carries a per-message key, and that key does not change when
/// the message is acknowledged. Whether reuse then happens is Flutter's own
/// contract; the visible flicker needs a device to confirm.
///
///   flutter test test/shared_ui/animated_message_list/item_state_identity_test.dart
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

TextMessage _msg(int id, {required String muid}) => TextMessage(
  id: id,
  text: 'msg $id',
  sender: _me,
  receiverUid: 'u2',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
  muid: muid,
);

MockAnimatedMessageListBloc _bloc(List<BaseMessage> messages) {
  final state = AnimatedMessageListState(messages: messages);
  final b = MockAnimatedMessageListBloc();
  whenListen(
    b,
    Stream<AnimatedMessageListState>.value(state),
    initialState: state,
  );
  when(
    () => b.operationsStream,
  ).thenAnswer((_) => const Stream<MessageOperation>.empty());
  return b;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The identity keys the sliver delegate put on its children, in render order.
List<String> _itemKeys(WidgetTester tester) => tester
    .widgetList<RepaintBoundary>(find.byType(RepaintBoundary))
    .map((w) => w.key)
    .whereType<ValueKey<String>>()
    .map((k) => k.value)
    .where((v) => v.startsWith('muid:') || v.startsWith('id:'))
    .toList();

Future<List<String>> _keysFor(
  WidgetTester tester,
  List<BaseMessage> messages,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CometChatAnimatedMessageList(
          bloc: _bloc(messages),
          reversed: true,
          itemBuilder: (context, message, index, animation) =>
              Text('msg ${(message as TextMessage).id}'),
        ),
      ),
    ),
  );
  await _settle(tester);
  return _itemKeys(tester);
}

void main() {
  testWidgets('every item carries a per-message identity key — ENG-39490', (
    tester,
  ) async {
    final keys = await _keysFor(tester, <BaseMessage>[
      _msg(1, muid: 'a'),
      _msg(2, muid: 'b'),
      _msg(3, muid: 'c'),
    ]);

    expect(
      keys,
      hasLength(3),
      reason:
          'the widget the delegate returns must be keyed, or an index shift '
          're-inflates every item',
    );
    expect(
      keys.toSet(),
      hasLength(keys.length),
      reason: 'keys must be distinct or two messages share an element',
    );
    expect(keys.toSet(), {'muid:a', 'muid:b', 'muid:c'});
  });

  testWidgets('the key does not change when a message is acknowledged', (
    tester,
  ) async {
    // Optimistic: the server has not answered, so id is still 0.
    final pending = await _keysFor(tester, <BaseMessage>[
      _msg(0, muid: 'pending-muid'),
    ]);
    // Acknowledged: a real id arrives; the composer preserves the muid.
    final acked = await _keysFor(tester, <BaseMessage>[
      _msg(4321, muid: 'pending-muid'),
    ]);

    expect(
      acked,
      pending,
      reason:
          "keying on id would re-key the sender's own message the moment it "
          'was acknowledged, and rebuild that bubble for nothing',
    );
  });

  testWidgets('a message with no muid still gets a key', (tester) async {
    final keys = await _keysFor(tester, <BaseMessage>[_msg(7, muid: '')]);
    expect(keys, ['id:7']);
  });
}
