/// Regression test for ENG-39490 — the real driver of the audio flicker.
///
/// `_buildMessage` created `final bubbleKey = GlobalKey()` on every call, for
/// the action overlay to measure the bubble with, and hung it on the Material
/// wrapping the bubble. A fresh GlobalKey every build means the Material's key
/// changes every build, so `Widget.canUpdate` is false and the framework
/// discards that element and everything under it. Every message's State was
/// recreated whenever the list rebuilt.
///
/// That is why keying the list items was not enough on its own: measured on
/// device, items were being relocated correctly by key and *still* every
/// bubble ran initState again — 15 re-inflations from one text message. With
/// the key stable per message it is 0.
///
/// Audio bubbles showed it because a fresh State starts on a placeholder
/// waveform with no duration and re-runs an async file check before it can
/// paint the real thing.
///
///   flutter test test/chat_ui/message_list/bubble_key_stability_test.dart
library;

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

TextMessage _text({int id = 1, String muid = 'muid-1'}) => TextMessage(
  id: id,
  text: 'hello',
  sender: _me,
  receiver: _them,
  receiverUid: 'u2',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
  muid: muid,
);

MockMessageListBloc _mock(List<BaseMessage> msgs) {
  final state = MessageListState(
    status: MessageListStatus.loaded,
    messages: msgs,
    loggedInUser: _me,
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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Every GlobalKey the list hung on a Material — one per rendered bubble.
List<GlobalKey> _bubbleKeys(WidgetTester tester) => tester
    .widgetList<Material>(find.byType(Material))
    .map((m) => m.key)
    .whereType<GlobalKey>()
    .toList();

void main() {
  setUpAll(() => registerFallbackValue(_text()));
  setUp(() => CometChatUIKit.loggedInUser = _me);
  tearDown(() => CometChatUIKit.loggedInUser = null);

  testWidgets('a bubble keeps the same GlobalKey across rebuilds — ENG-39490', (
    tester,
  ) async {
    final bloc = _mock(<BaseMessage>[_text()]);

    Widget list() => MaterialApp(
      home: Scaffold(
        body: CometChatMessageList(user: _them, messageListBloc: bloc),
      ),
    );

    await tester.pumpWidget(list());
    await _settle(tester);
    final before = _bubbleKeys(tester);
    expect(before, isNotEmpty, reason: 'the bubble should be keyed at all');

    // A fresh widget instance with the same parameters: the State survives,
    // so the item is rebuilt through the same _buildMessage.
    await tester.pumpWidget(list());
    await _settle(tester);
    final after = _bubbleKeys(tester);

    expect(after, hasLength(before.length));
    for (var i = 0; i < before.length; i++) {
      expect(
        identical(before[i], after[i]),
        isTrue,
        reason:
            'a new GlobalKey per build changes the Material\'s key, which '
            'throws the bubble subtree away and recreates every State — that '
            'is the flicker',
      );
    }
  });

  testWidgets('two messages do not share a key', (tester) async {
    final bloc = _mock(<BaseMessage>[
      _text(id: 1, muid: 'a'),
      _text(id: 2, muid: 'b'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CometChatMessageList(user: _them, messageListBloc: bloc),
        ),
      ),
    );
    await _settle(tester);

    final keys = _bubbleKeys(tester);
    expect(keys.length, greaterThanOrEqualTo(2));
    expect(
      keys.map(identityHashCode).toSet(),
      hasLength(keys.length),
      reason: 'sharing a GlobalKey between two live widgets is a hard error',
    );
  });
}
