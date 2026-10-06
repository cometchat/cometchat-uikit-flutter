/// MessageListEvent — the Equatable contract.
///
/// Every event in this file is an `Equatable`, and the bloc relies on that:
/// `blocTest`'s `expect`, event de-duplication and `props`-based comparison in
/// the widget layer all break silently if a field is left out of `props`.
/// These tests assert the positive (same fields → equal) and, field by field,
/// the negative (one field differs → not equal), which is what actually pins a
/// missing `props` entry.
///
/// Pure Dart with `Fake` SDK models — no SDK calls.
///
///   flutter test test/chat_ui/message_list/message_list_event_test.dart
library;

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/message_list/bloc/message_list_event.dart';

class FakeMsg extends Fake implements TextMessage {
  FakeMsg(this._id);
  final int _id;
  @override
  int get id => _id;
  @override
  String toString() => 'FakeMsg($_id)';
}

class FakeReceipt extends Fake implements MessageReceipt {
  FakeReceipt(this._id);
  final int _id;
  @override
  int? get messageId => _id;
  @override
  String toString() => 'FakeReceipt($_id)';
}

class FakeReaction extends Fake implements Reaction {
  FakeReaction(this._r);
  final String _r;
  @override
  String get reaction => _r;
  @override
  String toString() => 'FakeReaction($_r)';
}

void main() {
  final msgA = FakeMsg(1);
  final msgB = FakeMsg(2);

  group('LoadMessages', () {
    test('all five fields take part in equality', () {
      const base = LoadMessages(
        conversationWith: 'u1',
        conversationType: 'user',
        parentMessageId: 7,
        types: ['text'],
        categories: ['message'],
      );

      expect(
        base,
        const LoadMessages(
          conversationWith: 'u1',
          conversationType: 'user',
          parentMessageId: 7,
          types: ['text'],
          categories: ['message'],
        ),
      );
      expect(
        base,
        isNot(
          const LoadMessages(
            conversationWith: 'u2',
            conversationType: 'user',
            parentMessageId: 7,
            types: ['text'],
            categories: ['message'],
          ),
        ),
      );
      expect(
        base,
        isNot(
          const LoadMessages(
            conversationWith: 'u1',
            conversationType: 'group',
            parentMessageId: 7,
            types: ['text'],
            categories: ['message'],
          ),
        ),
      );
      expect(
        base,
        isNot(
          const LoadMessages(
            conversationWith: 'u1',
            conversationType: 'user',
            parentMessageId: 8,
            types: ['text'],
            categories: ['message'],
          ),
        ),
      );
      expect(
        base,
        isNot(
          const LoadMessages(
            conversationWith: 'u1',
            conversationType: 'user',
            parentMessageId: 7,
            types: ['image'],
            categories: ['message'],
          ),
        ),
      );
      expect(
        base,
        isNot(
          const LoadMessages(
            conversationWith: 'u1',
            conversationType: 'user',
            parentMessageId: 7,
            types: ['text'],
            categories: ['call'],
          ),
        ),
      );
    });

    test('the optional fields default to null and compare as such', () {
      const bare = LoadMessages(conversationWith: 'u1', conversationType: 'u');
      expect(bare.parentMessageId, isNull);
      expect(bare.types, isNull);
      expect(bare.categories, isNull);
      expect(
        bare,
        const LoadMessages(conversationWith: 'u1', conversationType: 'u'),
      );
    });
  });

  test('the payload-free events are const-equal singletons', () {
    expect(const LoadOlderMessages(), const LoadOlderMessages());
    expect(const LoadNewerMessages(), const LoadNewerMessages());
    expect(const RefreshMessages(), const RefreshMessages());
    expect(const SyncMessages(), const SyncMessages());
    expect(const ResetUnreadState(), const ResetUnreadState());
    expect(const ForceEmptyState(), const ForceEmptyState());
    // Different types with identical (empty) props must still differ.
    expect(const LoadOlderMessages(), isNot(const LoadNewerMessages()));
    expect(const RefreshMessages(), isNot(const SyncMessages()));
    expect(const ResetUnreadState(), isNot(const ForceEmptyState()));
  });

  group('single-message events', () {
    test('compare on the message they carry', () {
      expect(MessageReceived(msgA), MessageReceived(msgA));
      expect(MessageReceived(msgA), isNot(MessageReceived(msgB)));
      expect(MessageEdited(msgA), MessageEdited(msgA));
      expect(MessageEdited(msgA), isNot(MessageEdited(msgB)));
      expect(MessageDeleted(msgA), MessageDeleted(msgA));
      expect(MessageDeleted(msgA), isNot(MessageDeleted(msgB)));
      expect(MarkMessageAsRead(msgA), MarkMessageAsRead(msgA));
      expect(MarkMessageAsUnread(msgA), MarkMessageAsUnread(msgA));
      expect(MarkMessageAsUnread(msgA), isNot(MarkMessageAsUnread(msgB)));
    });

    test('the same message under different event types is not equal', () {
      expect(MessageReceived(msgA), isNot(MessageEdited(msgA)));
      expect(MessageDeleted(msgA), isNot(MessageReceived(msgA)));
    });
  });

  test('MessagePinSaveChanged separates the pin and save scopes', () {
    expect(
      MessagePinSaveChanged(msgA, isPinScope: true),
      MessagePinSaveChanged(msgA, isPinScope: true),
    );
    // The scope flag is the whole point of the event — it must be in props.
    expect(
      MessagePinSaveChanged(msgA, isPinScope: true),
      isNot(MessagePinSaveChanged(msgA, isPinScope: false)),
    );
    expect(
      MessagePinSaveChanged(msgA, isPinScope: true),
      isNot(MessagePinSaveChanged(msgB, isPinScope: true)),
    );
  });

  test('receipt events compare on the receipt', () {
    final r1 = FakeReceipt(1);
    final r2 = FakeReceipt(2);
    expect(DeliveryReceiptReceived(r1), DeliveryReceiptReceived(r1));
    expect(DeliveryReceiptReceived(r1), isNot(DeliveryReceiptReceived(r2)));
    expect(ReadReceiptReceived(r1), ReadReceiptReceived(r1));
    expect(ReadReceiptReceived(r1), isNot(ReadReceiptReceived(r2)));
    expect(ReadReceiptReceived(r1), isNot(DeliveryReceiptReceived(r1)));
  });

  test('SetActiveConversation treats null as a distinct value', () {
    expect(
      const SetActiveConversation('c1'),
      const SetActiveConversation('c1'),
    );
    expect(
      const SetActiveConversation('c1'),
      isNot(const SetActiveConversation('c2')),
    );
    expect(
      const SetActiveConversation(null),
      isNot(const SetActiveConversation('c1')),
    );
    expect(
      const SetActiveConversation(null),
      const SetActiveConversation(null),
    );
  });

  group('animated-list mutation events', () {
    test('InsertMessage compares message, index and animated', () {
      expect(InsertMessage(msgA), InsertMessage(msgA));
      expect(InsertMessage(msgA).index, isNull);
      expect(InsertMessage(msgA).animated, isTrue);
      expect(InsertMessage(msgA, index: 2), isNot(InsertMessage(msgA)));
      expect(InsertMessage(msgA, animated: false), isNot(InsertMessage(msgA)));
      expect(InsertMessage(msgA), isNot(InsertMessage(msgB)));
    });

    test('InsertAllMessages compares the whole list', () {
      expect(InsertAllMessages([msgA, msgB]), InsertAllMessages([msgA, msgB]));
      expect(
        InsertAllMessages([msgA, msgB]),
        isNot(InsertAllMessages([msgB, msgA])),
      );
      expect(
        InsertAllMessages([msgA], index: 1),
        isNot(InsertAllMessages([msgA])),
      );
      expect(
        InsertAllMessages([msgA], animated: false),
        isNot(InsertAllMessages([msgA])),
      );
    });

    test('UpdateMessage keeps both old and new in props', () {
      expect(UpdateMessage(msgA, msgB), UpdateMessage(msgA, msgB));
      // Swapping the pair must not compare equal — order is meaningful.
      expect(UpdateMessage(msgA, msgB), isNot(UpdateMessage(msgB, msgA)));
    });

    test('RemoveMessage compares message and animated', () {
      expect(RemoveMessage(msgA), RemoveMessage(msgA));
      expect(RemoveMessage(msgA).animated, isTrue);
      expect(RemoveMessage(msgA, animated: false), isNot(RemoveMessage(msgA)));
    });

    test('SetMessages compares the list and animated', () {
      expect(SetMessages([msgA]), SetMessages([msgA]));
      expect(SetMessages([msgA]), isNot(SetMessages([msgA, msgB])));
      expect(SetMessages([msgA], animated: false), isNot(SetMessages([msgA])));
    });
  });

  test('the boolean paging flags compare on their flag', () {
    expect(const SetLoadingOlder(true), const SetLoadingOlder(true));
    expect(const SetLoadingOlder(true), isNot(const SetLoadingOlder(false)));
    expect(const SetLoadingNewer(true), const SetLoadingNewer(true));
    expect(const SetLoadingNewer(true), isNot(const SetLoadingNewer(false)));
    expect(const SetHasMoreOlder(true), const SetHasMoreOlder(true));
    expect(const SetHasMoreOlder(true), isNot(const SetHasMoreOlder(false)));
    expect(const SetHasMoreNewer(true), const SetHasMoreNewer(true));
    expect(const SetHasMoreNewer(true), isNot(const SetHasMoreNewer(false)));
    // Same flag value, different event type.
    expect(const SetLoadingOlder(true), isNot(const SetLoadingNewer(true)));
    expect(const SetHasMoreOlder(true), isNot(const SetHasMoreNewer(true)));
  });

  test('JumpToMessage compares on the target id', () {
    expect(
      const JumpToMessage(messageId: 5),
      const JumpToMessage(messageId: 5),
    );
    expect(
      const JumpToMessage(messageId: 5),
      isNot(const JumpToMessage(messageId: 6)),
    );
  });

  group('reaction events', () {
    test('AddReaction and RemoveReaction compare message and emoji', () {
      expect(
        AddReaction(message: msgA, reaction: '👍'),
        AddReaction(message: msgA, reaction: '👍'),
      );
      expect(
        AddReaction(message: msgA, reaction: '👍'),
        isNot(AddReaction(message: msgA, reaction: '🎉')),
      );
      expect(
        AddReaction(message: msgA, reaction: '👍'),
        isNot(AddReaction(message: msgB, reaction: '👍')),
      );
      expect(
        RemoveReaction(message: msgA, reaction: '👍'),
        RemoveReaction(message: msgA, reaction: '👍'),
      );
      // Add and Remove of the same reaction must never collapse into one.
      expect(
        AddReaction(message: msgA, reaction: '👍'),
        isNot(RemoveReaction(message: msgA, reaction: '👍')),
      );
    });

    test('the SDK reaction events compare all four fields', () {
      final reaction = FakeReaction('👍');
      final other = FakeReaction('🎉');

      expect(
        ReactionAddedFromSDK(
          messageId: 1,
          reaction: reaction,
          receiverId: 'u1',
          receiverType: 'user',
        ),
        ReactionAddedFromSDK(
          messageId: 1,
          reaction: reaction,
          receiverId: 'u1',
          receiverType: 'user',
        ),
      );
      expect(
        ReactionAddedFromSDK(messageId: 1, reaction: reaction),
        isNot(ReactionAddedFromSDK(messageId: 2, reaction: reaction)),
      );
      expect(
        ReactionAddedFromSDK(messageId: 1, reaction: reaction),
        isNot(ReactionAddedFromSDK(messageId: 1, reaction: other)),
      );
      expect(
        ReactionAddedFromSDK(
          messageId: 1,
          reaction: reaction,
          receiverId: 'u1',
        ),
        isNot(ReactionAddedFromSDK(messageId: 1, reaction: reaction)),
      );
      expect(
        ReactionAddedFromSDK(
          messageId: 1,
          reaction: reaction,
          receiverType: 'group',
        ),
        isNot(ReactionAddedFromSDK(messageId: 1, reaction: reaction)),
      );
      expect(
        ReactionRemovedFromSDK(messageId: 1, reaction: reaction),
        ReactionRemovedFromSDK(messageId: 1, reaction: reaction),
      );
      expect(
        ReactionRemovedFromSDK(messageId: 1, reaction: reaction),
        isNot(ReactionAddedFromSDK(messageId: 1, reaction: reaction)),
      );
    });
  });

  test('LoadFromUnread compares both conversation coordinates', () {
    expect(
      const LoadFromUnread(conversationWith: 'u1', conversationType: 'user'),
      const LoadFromUnread(conversationWith: 'u1', conversationType: 'user'),
    );
    expect(
      const LoadFromUnread(conversationWith: 'u1', conversationType: 'user'),
      isNot(
        const LoadFromUnread(conversationWith: 'u2', conversationType: 'user'),
      ),
    );
    expect(
      const LoadFromUnread(conversationWith: 'u1', conversationType: 'user'),
      isNot(
        const LoadFromUnread(conversationWith: 'u1', conversationType: 'group'),
      ),
    );
  });

  test('MessageSentByUser compares message and status', () {
    expect(
      MessageSentByUser(message: msgA, status: 'sent'),
      MessageSentByUser(message: msgA, status: 'sent'),
    );
    expect(
      MessageSentByUser(message: msgA, status: 'sent'),
      isNot(MessageSentByUser(message: msgA, status: 'inProgress')),
    );
    expect(
      MessageSentByUser(message: msgA, status: 'sent'),
      isNot(MessageSentByUser(message: msgB, status: 'sent')),
    );
  });

  test('LoadLastAgentConversation compares on the agent uid', () {
    expect(
      const LoadLastAgentConversation(conversationWith: 'agent'),
      const LoadLastAgentConversation(conversationWith: 'agent'),
    );
    expect(
      const LoadLastAgentConversation(conversationWith: 'agent'),
      isNot(const LoadLastAgentConversation(conversationWith: 'other')),
    );
  });
}
