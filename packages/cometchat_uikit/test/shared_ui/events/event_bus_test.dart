/// Behaviour tests for the four UI Kit event buses and the SDK bridge that
/// feeds the message bus.
///
///   CometChatMessageEvents  / CometChatMessageEventListener
///   CometChatUIEvents       / CometChatUIEventListener
///   CometChatCallEvents     / CometChatCallEventListener
///   CometChatUserEvents     / CometChatUserEventListener
///   ChatSDKEventInitializer (the MessageListener the kit installs on the SDK)
///
/// Each bus is a static `Map<String, listener>` plus one `forEach` per event.
/// What is worth pinning is not that the map exists but that (a) an added
/// listener is reached with the exact payload the caller passed, (b) a removed
/// listener stops being reached, (c) every registered listener is reached —
/// not just the first — and (d) a listener that overrides nothing does not
/// blow up, because the mixins' no-op bodies are the contract that lets an
/// integrator implement one method out of thirty.
///
/// `ChatSDKEventInitializer` is the translation layer between the SDK's
/// `MessageListener` and the kit's bus. Two of its methods are not pure
/// forwarding — `onMessageEdited` / `onMessageDeleted` narrow an interactive
/// message first, and `onInteractiveMessageReceived` fans one SDK callback out
/// to four different kit events by `type`. Those are the branches with real
/// behaviour in them.
///
///   flutter test test/shared_ui/events/event_bus_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' as cc show Action;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Fixtures ────────────────────────────────────────────────────────────────

final _alice = User(uid: 'u1', name: 'Alice');
final _bob = User(uid: 'u2', name: 'Bob');
final _team = Group(guid: 'g1', name: 'Team', type: GroupTypeConstants.public);
final _sentAt = DateTime.utc(2024, 1, 1, 12);

TextMessage _text([String body = 'hello']) => TextMessage(
  id: 1,
  text: body,
  sender: _alice,
  receiver: _bob,
  receiverUid: 'u2',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
);

MediaMessage _media() => MediaMessage(
  id: 2,
  sender: _alice,
  receiver: _bob,
  receiverUid: 'u2',
  type: MessageTypeConstants.image,
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
);

CustomMessage _custom() => CustomMessage(
  id: 3,
  customData: const {'k': 'v'},
  sender: _alice,
  receiver: _bob,
  receiverUid: 'u2',
  type: 'sticker',
  receiverType: ReceiverTypeConstants.user,
  sentAt: _sentAt,
);

TypingIndicator _typing() => TypingIndicator(
  sender: _alice,
  receiverId: 'u2',
  receiverType: ReceiverTypeConstants.user,
);

MessageReceipt _receipt([int messageId = 1]) => MessageReceipt(
  messageId: messageId,
  sender: _bob,
  receiverType: ReceiverTypeConstants.user,
  receiverId: 'u1',
  timestamp: _sentAt,
  receiptType: MessageReceipt.receiptTypeRead,
);

TransientMessage _transient() => TransientMessage(
  receiverId: 'u2',
  receiverType: ReceiverTypeConstants.user,
  data: const {'live_reaction': '❤️'},
  sender: _alice,
);

InteractionReceipt _interactionReceipt() => InteractionReceipt(
  messageId: 7,
  sender: _bob,
  receiverType: ReceiverTypeConstants.user,
  receiverId: 'u1',
  interactions: const [],
);

ReactionEvent _reactionEvent() =>
    ReactionEvent(receiverId: 'u2', receiverType: ReceiverTypeConstants.user);

InteractiveMessage _interactive({
  required String type,
  Map<String, dynamic>? data,
}) => InteractiveMessage(
  id: 11,
  receiverUid: 'u2',
  receiverType: ReceiverTypeConstants.user,
  type: type,
  sender: _alice,
  receiver: _bob,
  conversationId: 'u1_user_u2',
  interactiveData: data ?? <String, dynamic>{},
  interactionGoal: InteractionGoal(
    type: InteractionGoalTypeConstants.none,
    elementIds: const [],
  ),
);

// ─── Recorders ───────────────────────────────────────────────────────────────

/// One recorded emission: the event name and the arguments it carried.
class _Call {
  _Call(this.name, this.args);

  final String name;
  final List<Object?> args;

  @override
  String toString() => '$name$args';
}

/// Records every message-bus event, so a test can assert both which event
/// fired and what payload reached the listener.
class _MessageRecorder with CometChatMessageEventListener {
  final List<_Call> calls = [];

  List<String> get names => calls.map((c) => c.name).toList();

  _Call get only {
    expect(calls, hasLength(1));
    return calls.single;
  }

  @override
  void ccMessageSent(BaseMessage message, MessageSendStatus messageStatus) =>
      calls.add(_Call('ccMessageSent', [message, messageStatus]));

  @override
  void ccMessageEdited(BaseMessage message, MessageEditStatus status) =>
      calls.add(_Call('ccMessageEdited', [message, status]));

  @override
  void ccMessageDeleted(BaseMessage message, EventStatus messageStatus) =>
      calls.add(_Call('ccMessageDeleted', [message, messageStatus]));

  @override
  void ccMessageRead(BaseMessage message) =>
      calls.add(_Call('ccMessageRead', [message]));

  @override
  void ccThreadSubscriptionChanged(int parentMessageId, bool subscribed) =>
      calls.add(
        _Call('ccThreadSubscriptionChanged', [parentMessageId, subscribed]),
      );

  @override
  void ccMessagePinned(BaseMessage message) =>
      calls.add(_Call('ccMessagePinned', [message]));

  @override
  void ccMessageUnpinned(BaseMessage message) =>
      calls.add(_Call('ccMessageUnpinned', [message]));

  @override
  void ccMessageSaved(BaseMessage message) =>
      calls.add(_Call('ccMessageSaved', [message]));

  @override
  void ccMessageUnsaved(BaseMessage message) =>
      calls.add(_Call('ccMessageUnsaved', [message]));

  @override
  void ccLiveReaction(String reaction) =>
      calls.add(_Call('ccLiveReaction', [reaction]));

  @override
  void ccMessageForwarded(
    BaseMessage message,
    List<User>? usersSent,
    List<Group>? groupsSent,
    MessageSendStatus status,
  ) => calls.add(
    _Call('ccMessageForwarded', [message, usersSent, groupsSent, status]),
  );

  @override
  void ccReplyToMessage(BaseMessage message) =>
      calls.add(_Call('ccReplyToMessage', [message]));

  @override
  void onTextMessageReceived(TextMessage textMessage) =>
      calls.add(_Call('onTextMessageReceived', [textMessage]));

  @override
  void onMediaMessageReceived(MediaMessage mediaMessage) =>
      calls.add(_Call('onMediaMessageReceived', [mediaMessage]));

  @override
  void onCustomMessageReceived(CustomMessage customMessage) =>
      calls.add(_Call('onCustomMessageReceived', [customMessage]));

  @override
  void onTypingStarted(TypingIndicator typingIndicator) =>
      calls.add(_Call('onTypingStarted', [typingIndicator]));

  @override
  void onTypingEnded(TypingIndicator typingIndicator) =>
      calls.add(_Call('onTypingEnded', [typingIndicator]));

  @override
  void onMessagesDelivered(MessageReceipt messageReceipt) =>
      calls.add(_Call('onMessagesDelivered', [messageReceipt]));

  @override
  void onMessagesRead(MessageReceipt messageReceipt) =>
      calls.add(_Call('onMessagesRead', [messageReceipt]));

  @override
  void onMessageEdited(BaseMessage message) =>
      calls.add(_Call('onMessageEdited', [message]));

  @override
  void onMessageDeleted(BaseMessage message) =>
      calls.add(_Call('onMessageDeleted', [message]));

  @override
  void onTransientMessageReceived(TransientMessage message) =>
      calls.add(_Call('onTransientMessageReceived', [message]));

  @override
  void onFormMessageReceived(FormMessage formMessage) =>
      calls.add(_Call('onFormMessageReceived', [formMessage]));

  @override
  void onCardMessageReceived(CometChatInteractiveCardMessage cardMessage) =>
      calls.add(_Call('onCardMessageReceived', [cardMessage]));

  @override
  void onCustomInteractiveMessageReceived(
    CustomInteractiveMessage customInteractiveMessage,
  ) => calls.add(
    _Call('onCustomInteractiveMessageReceived', [customInteractiveMessage]),
  );

  @override
  void onInteractionGoalCompleted(InteractionReceipt receipt) =>
      calls.add(_Call('onInteractionGoalCompleted', [receipt]));

  @override
  void onSchedulerMessageReceived(SchedulerMessage schedulerMessage) =>
      calls.add(_Call('onSchedulerMessageReceived', [schedulerMessage]));

  @override
  void onMessageReactionAdded(ReactionEvent reactionEvent) =>
      calls.add(_Call('onMessageReactionAdded', [reactionEvent]));

  @override
  void onMessageReactionRemoved(ReactionEvent reactionEvent) =>
      calls.add(_Call('onMessageReactionRemoved', [reactionEvent]));

  @override
  void onMessagesDeliveredToAll(MessageReceipt messageReceipt) =>
      calls.add(_Call('onMessagesDeliveredToAll', [messageReceipt]));

  @override
  void onMessagesReadByAll(MessageReceipt messageReceipt) =>
      calls.add(_Call('onMessagesReadByAll', [messageReceipt]));

  @override
  void onMessageModerated(BaseMessage message) =>
      calls.add(_Call('onMessageModerated', [message]));
}

/// A listener that overrides nothing: every call must land on the mixin's own
/// no-op body. Registered alongside the recorder in every message-bus test, so
/// an emission that the mixin cannot absorb fails the test it fired in.
class _SilentMessageListener with CometChatMessageEventListener {}

class _UiRecorder with CometChatUIEventListener {
  final List<_Call> calls = [];

  _Call get only {
    expect(calls, hasLength(1));
    return calls.single;
  }

  @override
  void showPanel(
    Map<String, dynamic>? id,
    CustomUIPosition uiPosition,
    WidgetBuilder child,
  ) => calls.add(_Call('showPanel', [id, uiPosition, child]));

  @override
  void hidePanel(Map<String, dynamic>? id, CustomUIPosition uiPosition) =>
      calls.add(_Call('hidePanel', [id, uiPosition]));

  @override
  void ccActiveChatChanged(
    Map<String, dynamic>? id,
    BaseMessage? lastMessage,
    User? user,
    Group? group,
    int unreadMessageCount,
  ) => calls.add(
    _Call('ccActiveChatChanged', [
      id,
      lastMessage,
      user,
      group,
      unreadMessageCount,
    ]),
  );

  @override
  void openChat(User? user, Group? group) =>
      calls.add(_Call('openChat', [user, group]));

  @override
  void ccComposeMessage(String text, MessageEditStatus status) =>
      calls.add(_Call('ccComposeMessage', [text, status]));

  @override
  void lockBottomPadding(Map<String, dynamic>? id, double height) =>
      calls.add(_Call('lockBottomPadding', [id, height]));

  @override
  void unlockBottomPadding(Map<String, dynamic>? id) =>
      calls.add(_Call('unlockBottomPadding', [id]));

  @override
  void requestComposerFocus(Map<String, dynamic>? id) =>
      calls.add(_Call('requestComposerFocus', [id]));

  @override
  void ccAgentChatThreadResolved({
    required String receiverId,
    required int parentMessageId,
  }) => calls.add(
    _Call('ccAgentChatThreadResolved', [receiverId, parentMessageId]),
  );

  @override
  void ccCardActionClicked(BaseMessage message, dynamic action) =>
      calls.add(_Call('ccCardActionClicked', [message, action]));
}

class _SilentUiListener with CometChatUIEventListener {}

class _CallRecorder with CometChatCallEventListener {
  final List<_Call> calls = [];

  @override
  void ccOutgoingCall(Call call) => calls.add(_Call('ccOutgoingCall', [call]));

  @override
  void ccCallAccepted(Call call) => calls.add(_Call('ccCallAccepted', [call]));

  @override
  void ccCallRejected(Call call) => calls.add(_Call('ccCallRejected', [call]));

  @override
  void ccCallEnded(Call call) => calls.add(_Call('ccCallEnded', [call]));
}

class _SilentCallListener with CometChatCallEventListener {}

class _UserRecorder with CometChatUserEventListener {
  final List<_Call> calls = [];

  @override
  void ccUserBlocked(User user) => calls.add(_Call('ccUserBlocked', [user]));

  @override
  void ccUserUnblocked(User user) =>
      calls.add(_Call('ccUserUnblocked', [user]));
}

class _SilentUserListener with CometChatUserEventListener {}

class _GroupRecorder with CometChatGroupEventListener {
  final List<_Call> calls = [];

  List<String> get names => calls.map((c) => c.name).toList();

  _Call get only {
    expect(calls, hasLength(1));
    return calls.single;
  }

  @override
  void ccGroupCreated(Group group) =>
      calls.add(_Call('ccGroupCreated', [group]));

  @override
  void ccGroupDeleted(Group group) =>
      calls.add(_Call('ccGroupDeleted', [group]));

  @override
  void ccGroupLeft(cc.Action message, User leftUser, Group leftGroup) =>
      calls.add(_Call('ccGroupLeft', [message, leftUser, leftGroup]));

  @override
  void ccGroupMemberScopeChanged(
    cc.Action message,
    User updatedUser,
    String scopeChangedTo,
    String scopeChangedFrom,
    Group group,
  ) => calls.add(
    _Call('ccGroupMemberScopeChanged', [
      message,
      updatedUser,
      scopeChangedTo,
      scopeChangedFrom,
      group,
    ]),
  );

  @override
  void ccGroupMemberBanned(
    cc.Action message,
    User bannedUser,
    User bannedBy,
    Group bannedFrom,
  ) => calls.add(
    _Call('ccGroupMemberBanned', [message, bannedUser, bannedBy, bannedFrom]),
  );

  @override
  void ccGroupMemberKicked(
    cc.Action message,
    User kickedUser,
    User kickedBy,
    Group kickedFrom,
  ) => calls.add(
    _Call('ccGroupMemberKicked', [message, kickedUser, kickedBy, kickedFrom]),
  );

  @override
  void ccGroupMemberUnbanned(
    cc.Action message,
    User unbannedUser,
    User unbannedBy,
    Group unbannedFrom,
  ) => calls.add(
    _Call('ccGroupMemberUnbanned', [
      message,
      unbannedUser,
      unbannedBy,
      unbannedFrom,
    ]),
  );

  @override
  void ccGroupMemberJoined(User joinedUser, Group joinedGroup) =>
      calls.add(_Call('ccGroupMemberJoined', [joinedUser, joinedGroup]));

  @override
  void ccGroupMemberAdded(
    List<cc.Action> messages,
    List<User> usersAdded,
    Group groupAddedIn,
    User addedBy,
  ) => calls.add(
    _Call('ccGroupMemberAdded', [messages, usersAdded, groupAddedIn, addedBy]),
  );

  @override
  void ccOwnershipChanged(Group group, GroupMember newOwner) =>
      calls.add(_Call('ccOwnershipChanged', [group, newOwner]));
}

class _SilentGroupListener with CometChatGroupEventListener {}

class _ConversationRecorder with CometChatConversationEventListener {
  final List<_Call> calls = [];

  @override
  void ccConversationDeleted(Conversation conversation) =>
      calls.add(_Call('ccConversationDeleted', [conversation]));

  @override
  void ccUpdateConversation(Conversation conversation) =>
      calls.add(_Call('ccUpdateConversation', [conversation]));
}

class _SilentConversationListener with CometChatConversationEventListener {}

class _AiRecorder with CometChatAIAssistantEventsListener {
  final List<_Call> calls = [];

  @override
  void onAIAssistantEventReceived(AIAssistantBaseEvent event) =>
      calls.add(_Call('onAIAssistantEventReceived', [event]));
}

class _SilentAiListener with CometChatAIAssistantEventsListener {}

void main() {
  // ===========================================================================
  group('CometChatMessageEvents', () {
    late _MessageRecorder rec;
    late _MessageRecorder second;

    setUp(() {
      CometChatMessageEvents.messagesListener.clear();
      rec = _MessageRecorder();
      second = _MessageRecorder();
      CometChatMessageEvents.addMessagesListener('rec', rec);
      // Overrides nothing: proves the mixin's no-op defaults absorb every
      // event on this bus.
      CometChatMessageEvents.addMessagesListener(
        'silent',
        _SilentMessageListener(),
      );
    });

    tearDown(() => CometChatMessageEvents.messagesListener.clear());

    // --- registration bookkeeping -----------------------------------------
    test('addMessagesListener stores under the id it was given', () {
      expect(CometChatMessageEvents.messagesListener['rec'], same(rec));
    });

    test(
      're-adding the same id replaces the listener rather than duplicating',
      () {
        CometChatMessageEvents.addMessagesListener('rec', second);
        CometChatMessageEvents.ccMessageRead(_text());
        expect(rec.calls, isEmpty);
        expect(second.calls, hasLength(1));
        expect(CometChatMessageEvents.messagesListener, hasLength(2));
      },
    );

    test('every registered listener is reached, not only the first', () {
      CometChatMessageEvents.addMessagesListener('second', second);
      CometChatMessageEvents.ccMessageRead(_text());
      expect(rec.names, ['ccMessageRead']);
      expect(second.names, ['ccMessageRead']);
    });

    test('a removed listener stops receiving', () {
      CometChatMessageEvents.removeMessagesListener('rec');
      CometChatMessageEvents.ccMessageRead(_text());
      expect(rec.calls, isEmpty);
      expect(CometChatMessageEvents.messagesListener.containsKey('rec'), false);
    });

    test('removing an id that was never added is a no-op', () {
      CometChatMessageEvents.removeMessagesListener('nobody');
      CometChatMessageEvents.ccMessageRead(_text());
      expect(rec.names, ['ccMessageRead']);
    });

    // --- composer / message-list events, payload identity ------------------
    test('ccMessageSent carries the message and the status', () {
      final m = _text();
      CometChatMessageEvents.ccMessageSent(m, MessageSendStatus.inProgress);
      expect(rec.only.name, 'ccMessageSent');
      expect(rec.only.args, [same(m), MessageSendStatus.inProgress]);
    });

    test('ccMessageEdited carries the message and the edit status', () {
      final m = _text();
      CometChatMessageEvents.ccMessageEdited(m, MessageEditStatus.success);
      expect(rec.only.name, 'ccMessageEdited');
      expect(rec.only.args, [same(m), MessageEditStatus.success]);
    });

    test('ccMessageDeleted carries the message and the event status', () {
      final m = _text();
      CometChatMessageEvents.ccMessageDeleted(m, EventStatus.inProgress);
      expect(rec.only.name, 'ccMessageDeleted');
      expect(rec.only.args, [same(m), EventStatus.inProgress]);
    });

    test('ccMessageRead carries the message', () {
      final m = _text();
      CometChatMessageEvents.ccMessageRead(m);
      expect(rec.only.args, [same(m)]);
    });

    test('ccThreadSubscriptionChanged carries the parent id and the flag', () {
      CometChatMessageEvents.ccThreadSubscriptionChanged(99, false);
      expect(rec.only.name, 'ccThreadSubscriptionChanged');
      expect(rec.only.args, [99, false]);
    });

    test('pin / unpin / save / unsave each fire their own event', () {
      final m = _text();
      CometChatMessageEvents.ccMessagePinned(m);
      CometChatMessageEvents.ccMessageUnpinned(m);
      CometChatMessageEvents.ccMessageSaved(m);
      CometChatMessageEvents.ccMessageUnsaved(m);
      expect(rec.names, [
        'ccMessagePinned',
        'ccMessageUnpinned',
        'ccMessageSaved',
        'ccMessageUnsaved',
      ]);
      for (final c in rec.calls) {
        expect(c.args, [same(m)]);
      }
    });

    test('ccLiveReaction forwards only the reaction, dropping receiverId', () {
      // The bus takes (reaction, receiverId) but the listener signature is
      // (reaction) alone — a listener cannot tell which chat it came from.
      CometChatMessageEvents.ccLiveReaction('❤️', 'u2');
      expect(rec.only.name, 'ccLiveReaction');
      expect(rec.only.args, ['❤️']);
    });

    test('ccMessageForwarded carries recipients and status', () {
      final m = _text();
      CometChatMessageEvents.ccMessageForwarded(
        m,
        [_bob],
        [_team],
        MessageSendStatus.sent,
      );
      expect(rec.only.name, 'ccMessageForwarded');
      expect(rec.only.args, [
        same(m),
        [_bob],
        [_team],
        MessageSendStatus.sent,
      ]);
    });

    test('ccReplyToMessage carries the message', () {
      final m = _text();
      CometChatMessageEvents.ccReplyToMessage(m);
      expect(rec.only.name, 'ccReplyToMessage');
      expect(rec.only.args, [same(m)]);
    });

    // --- SDK-shaped events -------------------------------------------------
    test('onTextMessageReceived carries the text message', () {
      final m = _text('ping');
      CometChatMessageEvents.onTextMessageReceived(m);
      expect(rec.only.name, 'onTextMessageReceived');
      expect(rec.only.args, [same(m)]);
    });

    test('onMediaMessageReceived carries the media message', () {
      final m = _media();
      CometChatMessageEvents.onMediaMessageReceived(m);
      expect(rec.only.name, 'onMediaMessageReceived');
      expect(rec.only.args, [same(m)]);
    });

    test('onCustomMessageReceived carries the custom message', () {
      final m = _custom();
      CometChatMessageEvents.onCustomMessageReceived(m);
      expect(rec.only.name, 'onCustomMessageReceived');
      expect(rec.only.args, [same(m)]);
    });

    test('typing started and ended are distinct events', () {
      final t = _typing();
      CometChatMessageEvents.onTypingStarted(t);
      CometChatMessageEvents.onTypingEnded(t);
      expect(rec.names, ['onTypingStarted', 'onTypingEnded']);
      expect(rec.calls.first.args, [same(t)]);
      expect(rec.calls.last.args, [same(t)]);
    });

    test('the four receipt events stay distinct', () {
      final r = _receipt();
      CometChatMessageEvents.onMessagesDelivered(r);
      CometChatMessageEvents.onMessagesRead(r);
      CometChatMessageEvents.onMessagesDeliveredToAll(r);
      CometChatMessageEvents.onMessagesReadByAll(r);
      expect(rec.names, [
        'onMessagesDelivered',
        'onMessagesRead',
        'onMessagesDeliveredToAll',
        'onMessagesReadByAll',
      ]);
      for (final c in rec.calls) {
        expect(c.args, [same(r)]);
      }
    });

    test('onMessageEdited / onMessageDeleted / onMessageModerated', () {
      final m = _text();
      CometChatMessageEvents.onMessageEdited(m);
      CometChatMessageEvents.onMessageDeleted(m);
      CometChatMessageEvents.onMessageModerated(m);
      expect(rec.names, [
        'onMessageEdited',
        'onMessageDeleted',
        'onMessageModerated',
      ]);
    });

    test('onTransientMessageReceived carries the transient message', () {
      final m = _transient();
      CometChatMessageEvents.onTransientMessageReceived(m);
      expect(rec.only.name, 'onTransientMessageReceived');
      expect(rec.only.args, [same(m)]);
    });

    test('the interactive-message events stay distinct', () {
      final form = FormMessage.fromInteractiveMessage(
        _interactive(type: MessageTypeConstants.form),
      );
      final card = CometChatInteractiveCardMessage.fromInteractiveMessage(
        _interactive(type: MessageTypeConstants.card, data: {'text': 'hi'}),
      );
      final custom = CustomInteractiveMessage.fromInteractiveMessage(
        _interactive(
          type: 'weird',
          data: {
            'customData': {'a': 1},
            'subType': 'widget_v2',
          },
        ),
      );
      final scheduler = SchedulerMessage.fromInteractiveMessage(
        _interactive(type: MessageTypeConstants.scheduler),
      );

      CometChatMessageEvents.onFormMessageReceived(form);
      CometChatMessageEvents.onCardMessageReceived(card);
      CometChatMessageEvents.onCustomInteractiveMessageReceived(custom);
      CometChatMessageEvents.onSchedulerMessageReceived(scheduler);

      expect(rec.names, [
        'onFormMessageReceived',
        'onCardMessageReceived',
        'onCustomInteractiveMessageReceived',
        'onSchedulerMessageReceived',
      ]);
      expect(rec.calls[0].args, [same(form)]);
      expect(rec.calls[1].args, [same(card)]);
      expect(rec.calls[2].args, [same(custom)]);
      expect(rec.calls[3].args, [same(scheduler)]);
    });

    test('onInteractionGoalCompleted carries the receipt', () {
      final r = _interactionReceipt();
      CometChatMessageEvents.onInteractionGoalCompleted(r);
      expect(rec.only.name, 'onInteractionGoalCompleted');
      expect(rec.only.args, [same(r)]);
    });

    test('reaction added and removed are distinct events', () {
      final e = _reactionEvent();
      CometChatMessageEvents.onMessageReactionAdded(e);
      CometChatMessageEvents.onMessageReactionRemoved(e);
      expect(rec.names, ['onMessageReactionAdded', 'onMessageReactionRemoved']);
      expect(rec.calls.first.args, [same(e)]);
      expect(rec.calls.last.args, [same(e)]);
    });

    test('emitting with no listeners registered is harmless', () {
      CometChatMessageEvents.messagesListener.clear();
      expect(
        () => CometChatMessageEvents.ccMessageRead(_text()),
        returnsNormally,
      );
    });
  });

  // ===========================================================================
  group('CometChatUIEvents', () {
    late _UiRecorder rec;

    setUp(() {
      CometChatUIEvents.uiListener.clear();
      rec = _UiRecorder();
      CometChatUIEvents.addUiListener('rec', rec);
      CometChatUIEvents.addUiListener('silent', _SilentUiListener());
    });

    tearDown(() => CometChatUIEvents.uiListener.clear());

    test('addUiListener stores under the id it was given', () {
      expect(CometChatUIEvents.uiListener['rec'], same(rec));
    });

    test('a removed listener stops receiving', () {
      CometChatUIEvents.removeUiListener('rec');
      CometChatUIEvents.openChat(_bob, null);
      expect(rec.calls, isEmpty);
    });

    test('showPanel carries id, position and the builder itself', () {
      Widget builder(BuildContext _) => const SizedBox.shrink();
      CometChatUIEvents.showPanel(
        {'uid': 'u2'},
        CustomUIPosition.messageListBottom,
        builder,
      );
      expect(rec.only.name, 'showPanel');
      expect(rec.only.args, [
        {'uid': 'u2'},
        CustomUIPosition.messageListBottom,
        same(builder),
      ]);
    });

    test('hidePanel carries id and position', () {
      CometChatUIEvents.hidePanel(null, CustomUIPosition.messageListTop);
      expect(rec.only.name, 'hidePanel');
      expect(rec.only.args, [null, CustomUIPosition.messageListTop]);
    });

    test('ccActiveChatChanged carries all five arguments in order', () {
      final m = _text();
      CometChatUIEvents.ccActiveChatChanged({'uid': 'u2'}, m, _bob, _team, 4);
      expect(rec.only.name, 'ccActiveChatChanged');
      expect(rec.only.args, [
        {'uid': 'u2'},
        same(m),
        same(_bob),
        same(_team),
        4,
      ]);
    });

    test('openChat carries whichever of user / group was given', () {
      CometChatUIEvents.openChat(_bob, null);
      expect(rec.only.args, [same(_bob), null]);
    });

    test('ccComposeMessage carries the text and the edit status', () {
      CometChatUIEvents.ccComposeMessage('draft', MessageEditStatus.inProgress);
      expect(rec.only.name, 'ccComposeMessage');
      expect(rec.only.args, ['draft', MessageEditStatus.inProgress]);
    });

    test('lock / unlock bottom padding are distinct and carry the height', () {
      CometChatUIEvents.lockBottomPadding({'uid': 'u2'}, 280);
      CometChatUIEvents.unlockBottomPadding({'uid': 'u2'});
      expect(rec.calls.map((c) => c.name), [
        'lockBottomPadding',
        'unlockBottomPadding',
      ]);
      expect(rec.calls.first.args, [
        {'uid': 'u2'},
        280.0,
      ]);
      expect(rec.calls.last.args, [
        {'uid': 'u2'},
      ]);
    });

    test('requestComposerFocus carries the target id', () {
      CometChatUIEvents.requestComposerFocus({'uid': 'u2'});
      expect(rec.only.name, 'requestComposerFocus');
      expect(rec.only.args, [
        {'uid': 'u2'},
      ]);
    });

    test('ccAgentChatThreadResolved carries receiver and parent id', () {
      CometChatUIEvents.ccAgentChatThreadResolved(
        receiverId: 'agent-1',
        parentMessageId: 77,
      );
      expect(rec.only.name, 'ccAgentChatThreadResolved');
      expect(rec.only.args, ['agent-1', 77]);
    });

    test('ccCardActionClicked carries the owning message and the action', () {
      final m = _text();
      const action = 'tapped';
      CometChatUIEvents.ccCardActionClicked(m, action);
      expect(rec.only.name, 'ccCardActionClicked');
      expect(rec.only.args, [same(m), action]);
    });
  });

  // ===========================================================================
  group('CometChatCallEvents', () {
    late _CallRecorder rec;
    late Call call;

    setUp(() {
      CometChatCallEvents.callEventsListener.clear();
      rec = _CallRecorder();
      CometChatCallEvents.addCallEventsListener('rec', rec);
      CometChatCallEvents.addCallEventsListener(
        'silent',
        _SilentCallListener(),
      );
      call = Call(
        sessionId: 's1',
        receiverUid: 'u2',
        type: 'audio',
        receiverType: ReceiverTypeConstants.user,
        sender: _alice,
        receiver: _bob,
      );
    });

    tearDown(() => CometChatCallEvents.callEventsListener.clear());

    test('addCallEventsListener stores under the id it was given', () {
      expect(CometChatCallEvents.callEventsListener['rec'], same(rec));
    });

    test('a removed listener stops receiving', () {
      CometChatCallEvents.removeCallEventsListener('rec');
      CometChatCallEvents.ccOutgoingCall(call);
      expect(rec.calls, isEmpty);
    });

    test('the four call events stay distinct and carry the call', () {
      CometChatCallEvents.ccOutgoingCall(call);
      CometChatCallEvents.ccCallAccepted(call);
      CometChatCallEvents.ccCallRejected(call);
      CometChatCallEvents.ccCallEnded(call);
      expect(rec.calls.map((c) => c.name), [
        'ccOutgoingCall',
        'ccCallAccepted',
        'ccCallRejected',
        'ccCallEnded',
      ]);
      for (final c in rec.calls) {
        expect(c.args, [same(call)]);
      }
    });
  });

  // ===========================================================================
  group('CometChatUserEvents', () {
    late _UserRecorder rec;

    setUp(() {
      CometChatUserEvents.usersListener.clear();
      rec = _UserRecorder();
      CometChatUserEvents.addUsersListener('rec', rec);
      CometChatUserEvents.addUsersListener('silent', _SilentUserListener());
    });

    tearDown(() => CometChatUserEvents.usersListener.clear());

    test('addUsersListener stores under the id it was given', () {
      expect(CometChatUserEvents.usersListener['rec'], same(rec));
    });

    test('a removed listener stops receiving', () {
      CometChatUserEvents.removeUsersListener('rec');
      CometChatUserEvents.ccUserBlocked(_bob);
      expect(rec.calls, isEmpty);
    });

    test('block and unblock stay distinct and carry the user', () {
      CometChatUserEvents.ccUserBlocked(_bob);
      CometChatUserEvents.ccUserUnblocked(_bob);
      expect(rec.calls.map((c) => c.name), [
        'ccUserBlocked',
        'ccUserUnblocked',
      ]);
      expect(rec.calls.first.args, [same(_bob)]);
      expect(rec.calls.last.args, [same(_bob)]);
    });
  });

  // ===========================================================================
  // The SDK bridge. Constructing it registers a MessageListener on the SDK's
  // static listener map — a plain map write, no transport — so the translation
  // layer can be driven directly from a test.
  group('ChatSDKEventInitializer', () {
    late _MessageRecorder rec;
    late ChatSDKEventInitializer bridge;

    setUp(() {
      CometChatMessageEvents.messagesListener.clear();
      rec = _MessageRecorder();
      CometChatMessageEvents.addMessagesListener('rec', rec);
      bridge = ChatSDKEventInitializer();
    });

    tearDown(() {
      CometChatMessageEvents.messagesListener.clear();
      CometChat.removeMessageListener('__CometChatConstantListenerID__');
    });

    test('plain SDK callbacks forward straight through to the bus', () {
      final text = _text();
      final media = _media();
      final custom = _custom();
      final typing = _typing();
      final receipt = _receipt();
      final transient = _transient();
      final goal = _interactionReceipt();
      final reaction = _reactionEvent();

      bridge.onTextMessageReceived(text);
      bridge.onMediaMessageReceived(media);
      bridge.onCustomMessageReceived(custom);
      bridge.onTypingStarted(typing);
      bridge.onTypingEnded(typing);
      bridge.onMessagesDelivered(receipt);
      bridge.onMessagesRead(receipt);
      bridge.onTransientMessageReceived(transient);
      bridge.onInteractionGoalCompleted(goal);
      bridge.onMessageReactionAdded(reaction);
      bridge.onMessageReactionRemoved(reaction);
      bridge.onMessagesDeliveredToAll(receipt);
      bridge.onMessagesReadByAll(receipt);
      bridge.onMessageModerated(text);

      expect(rec.names, [
        'onTextMessageReceived',
        'onMediaMessageReceived',
        'onCustomMessageReceived',
        'onTypingStarted',
        'onTypingEnded',
        'onMessagesDelivered',
        'onMessagesRead',
        'onTransientMessageReceived',
        'onInteractionGoalCompleted',
        'onMessageReactionAdded',
        'onMessageReactionRemoved',
        'onMessagesDeliveredToAll',
        'onMessagesReadByAll',
        'onMessageModerated',
      ]);
      // Payloads are passed by reference, not rebuilt.
      expect(rec.calls.first.args, [same(text)]);
      expect(rec.calls[1].args, [same(media)]);
      expect(rec.calls[2].args, [same(custom)]);
      expect(rec.calls[7].args, [same(transient)]);
    });

    test('a non-interactive edit is forwarded unchanged', () {
      final m = _text();
      bridge.onMessageEdited(m);
      expect(rec.only.name, 'onMessageEdited');
      expect(rec.only.args, [same(m)]);
    });

    test('a non-interactive delete is forwarded unchanged', () {
      final m = _text();
      bridge.onMessageDeleted(m);
      expect(rec.only.name, 'onMessageDeleted');
      expect(rec.only.args, [same(m)]);
    });

    test('an interactive edit is narrowed before it reaches the bus', () {
      final packed = _interactive(
        type: MessageTypeConstants.card,
        data: {'text': 'hi'},
      );
      expect(packed.category, MessageCategoryConstants.interactive);

      bridge.onMessageEdited(packed);

      expect(rec.only.name, 'onMessageEdited');
      final forwarded = rec.only.args.single;
      expect(forwarded, isA<CometChatInteractiveCardMessage>());
      expect(forwarded, isNot(same(packed)));
      expect((forwarded! as BaseMessage).id, packed.id);
    });

    test('an interactive delete is narrowed before it reaches the bus', () {
      final packed = _interactive(
        type: MessageTypeConstants.form,
        data: {
          'title': 'Survey',
          'formFields': <dynamic>[],
          'submitElement': {
            'elementType': UIElementTypeConstants.button,
            'elementId': 'submit',
            'buttonText': 'Send',
          },
        },
      );

      bridge.onMessageDeleted(packed);

      expect(rec.only.name, 'onMessageDeleted');
      final forwarded = rec.only.args.single;
      expect(forwarded, isA<FormMessage>());
      expect((forwarded! as FormMessage).title, 'Survey');
    });

    test('onInteractiveMessageReceived routes a form to the form event', () {
      bridge.onInteractiveMessageReceived(
        _interactive(
          type: MessageTypeConstants.form,
          data: {'title': 'Survey', 'formFields': <dynamic>[]},
        ),
      );
      expect(rec.only.name, 'onFormMessageReceived');
      expect((rec.only.args.single! as FormMessage).title, 'Survey');
    });

    test('onInteractiveMessageReceived routes a card to the card event', () {
      bridge.onInteractiveMessageReceived(
        _interactive(
          type: MessageTypeConstants.card,
          data: {'text': 'Pick one'},
        ),
      );
      expect(rec.only.name, 'onCardMessageReceived');
      expect(
        (rec.only.args.single! as CometChatInteractiveCardMessage).text,
        'Pick one',
      );
    });

    test(
      'onInteractiveMessageReceived routes a scheduler to the scheduler event',
      () {
        bridge.onInteractiveMessageReceived(
          _interactive(
            type: MessageTypeConstants.scheduler,
            data: {'title': 'Book a slot'},
          ),
        );
        expect(rec.only.name, 'onSchedulerMessageReceived');
        expect(
          (rec.only.args.single! as SchedulerMessage).title,
          'Book a slot',
        );
      },
    );

    test(
      'onInteractiveMessageReceived sends anything else to the custom event',
      () {
        bridge.onInteractiveMessageReceived(
          _interactive(
            type: 'vendor_widget',
            data: {
              'customData': {'a': 1},
              'subType': 'widget_v2',
            },
          ),
        );
        expect(rec.only.name, 'onCustomInteractiveMessageReceived');
        final m = rec.only.args.single! as CustomInteractiveMessage;
        expect(m.type, 'vendor_widget');
        expect(m.customData, {'a': 1});
        expect(m.subType, 'widget_v2');
      },
    );

    // FINDING: an interactive message of an unrecognised type whose payload
    // has no `customData` key crashes the SDK message listener.
    // `ChatSDKEventInitializer.onInteractiveMessageReceived` routes every
    // unknown type to `CustomInteractiveMessage.fromInteractiveMessage`, which
    // reads `interactiveData['customData']` straight into a non-nullable
    // `Map<String, dynamic>` field — so a null there is a TypeError raised
    // inside the SDK's message callback, not a degraded bubble. This is the
    // same shape as the scheduler crash fixed under ENG-39022 (see
    // interaction_message_utils_test.dart), which that fix did not cover.
    // Pinned as-is; the kit should degrade to an empty payload instead.
    test('an unknown interactive type with no customData throws', () {
      expect(
        () => bridge.onInteractiveMessageReceived(
          _interactive(type: 'vendor_widget', data: {'a': 1}),
        ),
        throwsA(isA<TypeError>()),
      );
      expect(rec.calls, isEmpty);
    });
  });

  // ===========================================================================
  group('CometChatGroupEvents', () {
    late _GroupRecorder rec;
    late cc.Action action;
    late GroupMember owner;

    setUp(() {
      CometChatGroupEvents.groupsListener.clear();
      rec = _GroupRecorder();
      CometChatGroupEvents.addGroupsListener('rec', rec);
      CometChatGroupEvents.addGroupsListener('silent', _SilentGroupListener());
      action = cc.Action(
        receiverUid: 'g1',
        receiverType: ReceiverTypeConstants.group,
        type: MessageTypeConstants.groupActions,
        category: MessageCategoryConstants.action,
        sender: _alice,
      );
      owner = GroupMember(
        scope: GroupMemberScope.owner,
        uid: 'u2',
        name: 'Bob',
      );
    });

    tearDown(() => CometChatGroupEvents.groupsListener.clear());

    test('addGroupsListener stores under the id it was given', () {
      expect(CometChatGroupEvents.groupsListener['rec'], same(rec));
    });

    test('a removed listener stops receiving', () {
      CometChatGroupEvents.removeGroupsListener('rec');
      CometChatGroupEvents.ccGroupCreated(_team);
      expect(rec.calls, isEmpty);
    });

    test('created and deleted stay distinct and carry the group', () {
      CometChatGroupEvents.ccGroupCreated(_team);
      CometChatGroupEvents.ccGroupDeleted(_team);
      expect(rec.names, ['ccGroupCreated', 'ccGroupDeleted']);
      expect(rec.calls.first.args, [same(_team)]);
      expect(rec.calls.last.args, [same(_team)]);
    });

    test('ccGroupLeft carries the action, the member and the group', () {
      CometChatGroupEvents.ccGroupLeft(action, _bob, _team);
      expect(rec.only.name, 'ccGroupLeft');
      expect(rec.only.args, [same(action), same(_bob), same(_team)]);
    });

    test('ccGroupMemberScopeChanged carries both scopes in order', () {
      CometChatGroupEvents.ccGroupMemberScopeChanged(
        action,
        _bob,
        GroupMemberScope.admin,
        GroupMemberScope.participant,
        _team,
      );
      expect(rec.only.name, 'ccGroupMemberScopeChanged');
      expect(rec.only.args, [
        same(action),
        same(_bob),
        GroupMemberScope.admin,
        GroupMemberScope.participant,
        same(_team),
      ]);
    });

    test('banned / kicked / unbanned stay distinct and keep actor order', () {
      CometChatGroupEvents.ccGroupMemberBanned(action, _bob, _alice, _team);
      CometChatGroupEvents.ccGroupMemberKicked(action, _bob, _alice, _team);
      CometChatGroupEvents.ccGroupMemberUnbanned(action, _bob, _alice, _team);
      expect(rec.names, [
        'ccGroupMemberBanned',
        'ccGroupMemberKicked',
        'ccGroupMemberUnbanned',
      ]);
      for (final c in rec.calls) {
        // subject first, actor second — swapping them would blame the wrong
        // person in the UI.
        expect(c.args, [same(action), same(_bob), same(_alice), same(_team)]);
      }
    });

    test('ccGroupMemberJoined carries the member and the group', () {
      CometChatGroupEvents.ccGroupMemberJoined(_bob, _team);
      expect(rec.only.name, 'ccGroupMemberJoined');
      expect(rec.only.args, [same(_bob), same(_team)]);
    });

    test('ccGroupMemberAdded carries the batch of actions and users', () {
      CometChatGroupEvents.ccGroupMemberAdded([action], [_bob], _team, _alice);
      expect(rec.only.name, 'ccGroupMemberAdded');
      expect(rec.only.args, [
        [same(action)],
        [same(_bob)],
        same(_team),
        same(_alice),
      ]);
    });

    test('ccOwnershipChanged carries the group and the new owner', () {
      CometChatGroupEvents.ccOwnershipChanged(_team, owner);
      expect(rec.only.name, 'ccOwnershipChanged');
      expect(rec.only.args, [same(_team), same(owner)]);
    });
  });

  // ===========================================================================
  group('CometChatConversationEvents', () {
    late _ConversationRecorder rec;
    late Conversation conversation;

    setUp(() {
      CometChatConversationEvents.conversationListListener.clear();
      rec = _ConversationRecorder();
      CometChatConversationEvents.addConversationListListener('rec', rec);
      CometChatConversationEvents.addConversationListListener(
        'silent',
        _SilentConversationListener(),
      );
      conversation = Conversation(
        conversationId: 'c1',
        conversationType: ReceiverTypeConstants.user,
        conversationWith: _bob,
        lastMessage: _text(),
      );
    });

    tearDown(
      () => CometChatConversationEvents.conversationListListener.clear(),
    );

    test('addConversationListListener stores under the id it was given', () {
      expect(
        CometChatConversationEvents.conversationListListener['rec'],
        same(rec),
      );
    });

    test('a removed listener stops receiving', () {
      CometChatConversationEvents.removeConversationListListener('rec');
      CometChatConversationEvents.ccConversationDeleted(conversation);
      expect(rec.calls, isEmpty);
    });

    test('deleted and updated stay distinct and carry the conversation', () {
      CometChatConversationEvents.ccConversationDeleted(conversation);
      CometChatConversationEvents.ccUpdateConversation(conversation);
      expect(rec.calls.map((c) => c.name), [
        'ccConversationDeleted',
        'ccUpdateConversation',
      ]);
      expect(rec.calls.first.args, [same(conversation)]);
      expect(rec.calls.last.args, [same(conversation)]);
    });
  });

  // ===========================================================================
  group('CometChatAIAssistantEvents', () {
    late _AiRecorder rec;

    setUp(() {
      rec = _AiRecorder();
      CometChatAIAssistantEvents.addAIAssistantListener('rec', rec);
      CometChatAIAssistantEvents.addAIAssistantListener(
        'silent',
        _SilentAiListener(),
      );
    });

    tearDown(() {
      CometChatAIAssistantEvents.removeAIAssistantListener('rec');
      CometChatAIAssistantEvents.removeAIAssistantListener('silent');
    });

    test('an added listener receives the event object itself', () {
      final event = AIAssistantBaseEvent(
        id: 5,
        type: 'message.delta',
        conversationId: 'c1',
      );
      CometChatAIAssistantEvents.onAIAssistantEventReceived(event);
      expect(rec.calls, hasLength(1));
      expect(rec.calls.single.name, 'onAIAssistantEventReceived');
      expect(rec.calls.single.args, [same(event)]);
    });

    test('a removed listener stops receiving', () {
      CometChatAIAssistantEvents.removeAIAssistantListener('rec');
      CometChatAIAssistantEvents.onAIAssistantEventReceived(
        AIAssistantBaseEvent(id: 6),
      );
      expect(rec.calls, isEmpty);
    });
  });
}
