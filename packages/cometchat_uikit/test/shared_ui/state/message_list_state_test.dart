/// Behaviour tests for MessageListState and the Result wrapper —
/// Track 3 TEST3 (ENG-38684).
///
/// `message_list_state.dart` was at zero line coverage. These are Equatable
/// states, so the thing worth testing is what `props` declares: two states
/// that differ only in a field left out of `props` compare equal, and a bloc
/// consumer will not rebuild. That is a silent class of bug, so each state's
/// identity is pinned here.
///
///   flutter test test/shared_ui/state/message_list_state_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

MessageEntity _msg(String id, {String text = 'hello'}) => MessageEntity(
  id: id,
  text: text,
  senderId: 'u1',
  senderName: 'Alice',
  timestamp: 1788787200,
);

void main() {
  // -------------------------------------------------------------------------
  group('Result', () {
    test('Success reports success and folds to the success branch', () {
      const r = Success<int>(42);
      expect(r.isSuccess, isTrue);
      expect(r.isFailure, isFalse);
      expect(r.fold((f) => -1, (v) => v), 42);
    });

    test('Failure reports failure and folds to the failure branch', () {
      const r = Failure(message: 'boom', code: 'E1');
      expect(r.isFailure, isTrue);
      expect(r.isSuccess, isFalse);
      expect(r.fold((f) => f.message, (v) => 'unused'), 'boom');
    });

    test('Failure toString names the message and code', () {
      const f = Failure(message: 'boom', code: 'E1');
      expect(f.toString(), contains('boom'));
      expect(f.toString(), contains('E1'));
    });
  });

  // -------------------------------------------------------------------------
  group('MessageListSuccess', () {
    MessageListSuccess build() => MessageListSuccess(
      messages: [_msg('1')],
      hasMoreData: true,
      totalCount: 10,
    );

    test('equality is by messages, hasMoreData and totalCount', () {
      expect(build(), build());
      expect(
        build(),
        isNot(
          MessageListSuccess(
            messages: [_msg('1')],
            hasMoreData: false,
            totalCount: 10,
          ),
        ),
        reason: 'hasMoreData participates in equality',
      );
      expect(
        build(),
        isNot(
          MessageListSuccess(
            messages: [_msg('2')],
            hasMoreData: true,
            totalCount: 10,
          ),
        ),
        reason: 'the message list participates in equality',
      );
    });

    test('copyWith replaces only what it is given', () {
      final base = build();
      final copy = base.copyWith(hasMoreData: false);
      expect(copy.hasMoreData, isFalse);
      expect(copy.totalCount, 10);
      expect(copy.messages, base.messages);
    });

    test('copyWith with no arguments equals the original', () {
      expect(build().copyWith(), build());
    });
  });

  // -------------------------------------------------------------------------
  group('MessageListError', () {
    test('errorMessage surfaces the failure message', () {
      const state = MessageListError(
        failure: Failure(message: 'network down', code: 'ERR_CONNECTION'),
      );
      expect(state.errorMessage, 'network down');
    });

    test('most failures are recoverable', () {
      const state = MessageListError(
        failure: Failure(message: 'network down', code: 'ERR_CONNECTION'),
      );
      expect(state.isRecoverable, isTrue);
    });

    test('INVALID_PARAMS is the one unrecoverable code', () {
      const state = MessageListError(
        failure: Failure(message: 'bad request', code: 'INVALID_PARAMS'),
      );
      expect(state.isRecoverable, isFalse);
    });

    test('a failure with no code is treated as recoverable', () {
      const state = MessageListError(failure: Failure(message: 'unknown'));
      expect(state.isRecoverable, isTrue);
    });

    test('cached messages participate in equality', () {
      const f = Failure(message: 'x');
      expect(
        MessageListError(failure: f, cachedMessages: [_msg('1')]),
        isNot(const MessageListError(failure: f)),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('the remaining states declare their identity', () {
    test('MessageListLoading is keyed by its cached messages', () {
      expect(
        MessageListLoading(cachedMessages: [_msg('1')]),
        MessageListLoading(cachedMessages: [_msg('1')]),
      );
      expect(
        MessageListLoading(cachedMessages: [_msg('1')]),
        isNot(MessageListLoading(cachedMessages: [_msg('2')])),
      );
    });

    test('MessageListLoadingMore is keyed by its current messages', () {
      expect(
        MessageListLoadingMore(currentMessages: [_msg('1')]),
        MessageListLoadingMore(currentMessages: [_msg('1')]),
      );
    });

    test('MessageListSearching is keyed by query and previous messages', () {
      expect(
        MessageListSearching(query: 'a', previousMessages: [_msg('1')]),
        MessageListSearching(query: 'a', previousMessages: [_msg('1')]),
      );
      expect(
        MessageListSearching(query: 'a', previousMessages: [_msg('1')]),
        isNot(MessageListSearching(query: 'b', previousMessages: [_msg('1')])),
        reason: 'the query participates in equality',
      );
    });

    test('MessageListSending is keyed by the pending text', () {
      expect(
        MessageListSending(currentMessages: const [], tempMessageText: 'hi'),
        MessageListSending(currentMessages: const [], tempMessageText: 'hi'),
      );
      expect(
        MessageListSending(currentMessages: const [], tempMessageText: 'hi'),
        isNot(
          MessageListSending(currentMessages: const [], tempMessageText: 'bye'),
        ),
      );
    });

    test('MessageListMessageSent is keyed by the new message', () {
      expect(
        MessageListMessageSent(messages: const [], newMessage: _msg('1')),
        MessageListMessageSent(messages: const [], newMessage: _msg('1')),
      );
      expect(
        MessageListMessageSent(messages: const [], newMessage: _msg('1')),
        isNot(
          MessageListMessageSent(messages: const [], newMessage: _msg('2')),
        ),
      );
    });

    test('MessageListMessageDeleted is keyed by the deleted id', () {
      expect(
        MessageListMessageDeleted(messages: const [], deletedMessageId: '1'),
        MessageListMessageDeleted(messages: const [], deletedMessageId: '1'),
      );
      expect(
        MessageListMessageDeleted(messages: const [], deletedMessageId: '1'),
        isNot(
          MessageListMessageDeleted(messages: const [], deletedMessageId: '2'),
        ),
      );
    });

    test('the singleton states compare equal to themselves', () {
      expect(const MessageListInitial(), const MessageListInitial());
      expect(const MessageListEmpty(), const MessageListEmpty());
      expect(const MessageListInitial(), isNot(const MessageListEmpty()));
    });
  });
}
