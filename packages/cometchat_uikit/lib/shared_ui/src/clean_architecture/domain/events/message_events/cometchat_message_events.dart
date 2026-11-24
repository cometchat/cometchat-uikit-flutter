import "package:cometchat_sdk/cometchat_sdk.dart" hide CardMessage;
import '../../../core/constants/enums.dart';
import '../../../../offline/message_send_state.dart';
import '../../../data/models/interactive_message/form_message.dart';
import '../../../data/models/interactive_message/card_message.dart';
import '../../../data/models/interactive_message/scheduler_message.dart';
import '../../../data/models/interactive_message/custom_interactive_message.dart';
import 'cometchat_message_event_listener.dart';

///Event emitting class for [CometChatMessageList]
class CometChatMessageEvents {
  static Map<String, CometChatMessageEventListener> messagesListener = {};

  static void addMessagesListener(
    String listenerId,
    CometChatMessageEventListener listenerClass,
  ) {
    messagesListener[listenerId] = listenerClass;
  }

  static void removeMessagesListener(String listenerId) {
    messagesListener.remove(listenerId);
  }

  static void ccMessageSent(BaseMessage message, MessageStatus messageStatus) {
    messagesListener.forEach((key, value) {
      value.ccMessageSent(message, messageStatus);
    });
  }

  /// Offline (additive, G14): emits one send-state transition of an own
  /// message to every registered listener. Never called with offline off.
  static void ccMessageSendStateChanged(
    BaseMessage message,
    CometChatMessageSendState state,
    MessageFailureReason? reason,
  ) {
    messagesListener.forEach((key, value) {
      value.ccMessageSendStateChanged(message, state, reason);
    });
  }

  /// Offline (additive, G14): emits an offline cache-reset to every registered
  /// listener. Never called with offline off.
  static void ccOfflineCacheReset(
    OfflineCacheResetReason reason,
    int? pendingMessagesLost,
  ) {
    messagesListener.forEach((key, value) {
      value.ccOfflineCacheReset(reason, pendingMessagesLost);
    });
  }

  static void ccMessageEdited(BaseMessage message, MessageEditStatus status) {
    messagesListener.forEach((key, value) {
      value.ccMessageEdited(message, status);
    });
  }

  static void ccMessageDeleted(BaseMessage message, EventStatus messageStatus) {
    messagesListener.forEach((key, value) {
      value.ccMessageDeleted(message, messageStatus);
    });
  }

  static void ccMessageRead(BaseMessage message) {
    messagesListener.forEach((key, value) {
      value.ccMessageRead(message);
    });
  }

  ///Event for the logged-in user following/unfollowing a thread from either
  ///kit surface (the message action sheet or the threaded-header control).
  ///Keeps the two entry points in agreement without a refetch, and gives an
  ///integrator's own thread list a channel to react to (an unfollow also
  ///hard-deletes the thread's row server-side, so remove it locally).
  static void ccThreadSubscriptionChanged(
    int parentMessageId,
    bool subscribed,
  ) {
    messagesListener.forEach((key, value) {
      value.ccThreadSubscriptionChanged(parentMessageId, subscribed);
    });
  }

  ///Events for the logged-in user pinning/unpinning/saving/unsaving a
  ///message from a kit surface. [message] is the full updated object (pin/
  ///save fields stamped or cleared) so panels like Pinned/Saved Messages can
  ///insert or drop rows without a refetch.
  static void ccMessagePinned(BaseMessage message) {
    messagesListener.forEach((key, value) {
      value.ccMessagePinned(message);
    });
  }

  static void ccMessageUnpinned(BaseMessage message) {
    messagesListener.forEach((key, value) {
      value.ccMessageUnpinned(message);
    });
  }

  static void ccMessageSaved(BaseMessage message) {
    messagesListener.forEach((key, value) {
      value.ccMessageSaved(message);
    });
  }

  static void ccMessageUnsaved(BaseMessage message) {
    messagesListener.forEach((key, value) {
      value.ccMessageUnsaved(message);
    });
  }

  static void ccLiveReaction(String reaction, String receiverId) {
    messagesListener.forEach((key, value) {
      value.ccLiveReaction(reaction);
    });
  }

  static void ccMessageForwarded(
    BaseMessage message,
    List<User>? usersSent,
    List<Group>? groupsSent,
    MessageStatus status,
  ) {
    messagesListener.forEach((key, value) {
      value.ccMessageForwarded(message, usersSent, groupsSent, status);
    });
  }

  static void ccReplyToMessage(BaseMessage message) {
    messagesListener.forEach((key, value) {
      value.ccReplyToMessage(message);
    });
  }

  /// Called when an outgoing call is initiated by the logged-in user.
  static void onTextMessageReceived(TextMessage textMessage) {
    messagesListener.forEach((key, value) {
      value.onTextMessageReceived(textMessage);
    });
  }

  /// Called when a media message is received.
  static void onMediaMessageReceived(MediaMessage mediaMessage) {
    messagesListener.forEach((key, value) {
      value.onMediaMessageReceived(mediaMessage);
    });
  }

  /// Called when a custom message is received.
  static void onCustomMessageReceived(CustomMessage customMessage) {
    messagesListener.forEach((key, value) {
      value.onCustomMessageReceived(customMessage);
    });
  }

  /// Called when typing is started.
  static void onTypingStarted(TypingIndicator typingIndicator) {
    messagesListener.forEach((key, value) {
      value.onTypingStarted(typingIndicator);
    });
  }

  /// Called when typing is ended.
  static void onTypingEnded(TypingIndicator typingIndicator) {
    messagesListener.forEach((key, value) {
      value.onTypingEnded(typingIndicator);
    });
  }

  /// Called when messages are delivered.
  static void onMessagesDelivered(MessageReceipt messageReceipt) {
    messagesListener.forEach((key, value) {
      value.onMessagesDelivered(messageReceipt);
    });
  }

  /// Called when messages are read.
  static void onMessagesRead(MessageReceipt messageReceipt) {
    messagesListener.forEach((key, value) {
      value.onMessagesRead(messageReceipt);
    });
  }

  /// Called when a message is edited.
  static void onMessageEdited(BaseMessage message) {
    messagesListener.forEach((key, value) {
      value.onMessageEdited(message);
    });
  }

  /// Called when a message is deleted.
  static void onMessageDeleted(BaseMessage message) {
    messagesListener.forEach((key, value) {
      value.onMessageDeleted(message);
    });
  }

  /// Called when a transient message is received.
  static void onTransientMessageReceived(TransientMessage message) {
    messagesListener.forEach((key, value) {
      value.onTransientMessageReceived(message);
    });
  }

  /// Called when a form message is received.
  static void onFormMessageReceived(FormMessage message) {
    messagesListener.forEach((key, value) {
      value.onFormMessageReceived(message);
    });
  }

  /// Called when a card message is received.
  static void onCardMessageReceived(CardMessage message) {
    messagesListener.forEach((key, value) {
      value.onCardMessageReceived(message);
    });
  }

  /// Called when a custom interactive message is received.
  static void onCustomInteractiveMessageReceived(
    CustomInteractiveMessage message,
  ) {
    messagesListener.forEach((key, value) {
      value.onCustomInteractiveMessageReceived(message);
    });
  }

  /// Called when an interaction goal is completed.
  static void onInteractionGoalCompleted(InteractionReceipt receipt) {
    messagesListener.forEach((key, value) {
      value.onInteractionGoalCompleted(receipt);
    });
  }

  ///[onSchedulerMessageReceived] Called when a meeting message is received.
  static void onSchedulerMessageReceived(SchedulerMessage schedulerMessage) {
    messagesListener.forEach((key, value) {
      value.onSchedulerMessageReceived(schedulerMessage);
    });
  }

  static void onMessageReactionAdded(ReactionEvent reactionEvent) {
    messagesListener.forEach((key, value) {
      value.onMessageReactionAdded(reactionEvent);
    });
  }

  static void onMessageReactionRemoved(ReactionEvent reactionEvent) {
    messagesListener.forEach((key, value) {
      value.onMessageReactionRemoved(reactionEvent);
    });
  }

  /// Called when messages are delivered to all.
  static void onMessagesDeliveredToAll(MessageReceipt messageReceipt) {
    messagesListener.forEach((key, value) {
      value.onMessagesDeliveredToAll(messageReceipt);
    });
  }

  /// Called when messages are read by all.
  static void onMessagesReadByAll(MessageReceipt messageReceipt) {
    messagesListener.forEach((key, value) {
      value.onMessagesReadByAll(messageReceipt);
    });
  }

  /// Called when a message is moderated.
  static void onMessageModerated(BaseMessage message) {
    messagesListener.forEach((key, value) {
      value.onMessageModerated(message);
    });
  }
}
