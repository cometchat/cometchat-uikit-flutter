/// Behaviour tests for [ReplyUtils.getQuotedMessageId].
///
/// This is the guard that stops a reply landing in the wrong chat: the reply
/// preview survives a conversation switch, so the composer re-checks that the
/// quoted message still belongs to the conversation it is about to send into.
/// A wrong answer here posts someone's reply into a stranger's chat, and the
/// file was at zero coverage.
///
///   flutter test test/shared_ui/utils/reply_utils_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

final _alice = User(uid: 'u1', name: 'Alice');
final _bob = User(uid: 'u2', name: 'Bob');
final _team = Group(guid: 'g1', name: 'Team', type: 'public');
final _other = Group(guid: 'g2', name: 'Other', type: 'public');

TextMessage _message({
  required int id,
  AppEntity? receiver,
  String? conversationId,
}) => TextMessage(
  id: id,
  text: 'quoted',
  receiverUid: 'u2',
  receiverType: CometChatReceiverType.user,
  type: MessageTypeConstants.text,
  sender: _alice,
  receiver: receiver,
  conversationId: conversationId,
);

void main() {
  // -------------------------------------------------------------------------
  group('no quoted message', () {
    test('null yields the sentinel', () {
      expect(ReplyUtils.getQuotedMessageId(user: _bob), -1);
    });

    test('an unsent message (id 0 or negative) yields the sentinel', () {
      // A message still in flight has no server id to quote.
      for (final id in [0, -1, -99]) {
        expect(
          ReplyUtils.getQuotedMessageId(
            quotedMessage: _message(
              id: id,
              receiver: _bob,
              conversationId: 'u1_user_u2',
            ),
            user: _bob,
          ),
          -1,
          reason: 'id $id',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  group('one-to-one chats', () {
    test('a message from this conversation is quotable', () {
      expect(
        ReplyUtils.getQuotedMessageId(
          quotedMessage: _message(
            id: 42,
            receiver: _bob,
            conversationId: 'u1_user_u2',
          ),
          user: _bob,
        ),
        42,
      );
    });

    test('a message from a different conversation is refused', () {
      // The user switched chats while the reply preview was still up.
      expect(
        ReplyUtils.getQuotedMessageId(
          quotedMessage: _message(
            id: 42,
            receiver: _bob,
            conversationId: 'u1_user_u9',
          ),
          user: _bob,
        ),
        -1,
      );
    });

    test('a missing or empty conversation id is refused', () {
      for (final id in [null, '']) {
        expect(
          ReplyUtils.getQuotedMessageId(
            quotedMessage: _message(id: 42, receiver: _bob, conversationId: id),
            user: _bob,
          ),
          -1,
          reason: 'conversationId ${id ?? 'null'}',
        );
      }
    });

    test('the uid must be a whole underscore-separated segment', () {
      // A substring match would let "u2" pass inside "xu2x" and quote into
      // the wrong chat; the check splits on underscores first.
      expect(
        ReplyUtils.getQuotedMessageId(
          quotedMessage: _message(
            id: 42,
            receiver: _bob,
            conversationId: 'u1_user_xu2x',
          ),
          user: _bob,
        ),
        -1,
      );
    });

    test('a group message is refused while a 1-1 chat is open', () {
      // The receiver type decides which check runs; a group-receiver message
      // matches neither arm.
      expect(
        ReplyUtils.getQuotedMessageId(
          quotedMessage: _message(
            id: 42,
            receiver: _team,
            conversationId: 'u1_user_u2',
          ),
          user: _bob,
        ),
        -1,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('group chats', () {
    test('a message from this group is quotable', () {
      expect(
        ReplyUtils.getQuotedMessageId(
          quotedMessage: _message(id: 42, receiver: _team),
          group: _team,
        ),
        42,
      );
    });

    test('a message from another group is refused', () {
      expect(
        ReplyUtils.getQuotedMessageId(
          quotedMessage: _message(id: 42, receiver: _other),
          group: _team,
        ),
        -1,
      );
    });

    test('a group check does not need a conversation id', () {
      // The guid comparison is enough, so a message with no conversationId
      // is still quotable in its own group.
      expect(
        ReplyUtils.getQuotedMessageId(
          quotedMessage: _message(id: 42, receiver: _team, conversationId: ''),
          group: _team,
        ),
        42,
      );
    });

    test('a 1-1 message is refused while a group is open', () {
      expect(
        ReplyUtils.getQuotedMessageId(
          quotedMessage: _message(
            id: 42,
            receiver: _bob,
            conversationId: 'u1_user_u2',
          ),
          group: _team,
        ),
        -1,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('neither a user nor a group', () {
    test('with no conversation context at all nothing is quotable', () {
      expect(
        ReplyUtils.getQuotedMessageId(
          quotedMessage: _message(
            id: 42,
            receiver: _bob,
            conversationId: 'u1_user_u2',
          ),
        ),
        -1,
      );
    });

    test('a message with no receiver is refused in both modes', () {
      expect(
        ReplyUtils.getQuotedMessageId(
          quotedMessage: _message(id: 42, conversationId: 'u1_user_u2'),
          user: _bob,
        ),
        -1,
      );
      expect(
        ReplyUtils.getQuotedMessageId(
          quotedMessage: _message(id: 42),
          group: _team,
        ),
        -1,
      );
    });

    test('a user takes precedence when both are supplied', () {
      // The 1-1 arm is tested first, so a user-receiver message resolves even
      // with a group also in hand.
      expect(
        ReplyUtils.getQuotedMessageId(
          quotedMessage: _message(
            id: 42,
            receiver: _bob,
            conversationId: 'u1_user_u2',
          ),
          user: _bob,
          group: _team,
        ),
        42,
      );
      // ...and a group-receiver message then falls to the group arm.
      expect(
        ReplyUtils.getQuotedMessageId(
          quotedMessage: _message(id: 43, receiver: _team),
          user: _bob,
          group: _team,
        ),
        43,
      );
    });
  });
}
