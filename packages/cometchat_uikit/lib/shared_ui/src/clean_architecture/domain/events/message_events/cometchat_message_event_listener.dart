import "package:cometchat_sdk/cometchat_sdk.dart" hide CardMessage;
import '../../../core/utils/ui_event_handler.dart';
import '../../../core/constants/enums.dart';
import '../../../../offline/message_send_state.dart';
import '../../../data/models/interactive_message/form_message.dart';
import '../../../data/models/interactive_message/card_message.dart';
import '../../../data/models/interactive_message/scheduler_message.dart';
import '../../../data/models/interactive_message/custom_interactive_message.dart';

///Listener class for [CometChatMessageList]

enum LiveReactionType { liveReaction }

mixin CometChatMessageEventListener implements UIEventHandler {
  //---composer events---
  //event for message sent by logged-in user
  void ccMessageSent(BaseMessage message, MessageStatus messageStatus) {}

  //Offline (additive, G14): one event per transition of an own message's send
  //state (sending/sent/failed). [reason] is non-null only on a failure. Default
  //no-op so existing listeners are unaffected; never emitted with offline off.
  /// Called once per send-state transition of an own message (offline only).
  void ccMessageSendStateChanged(
    BaseMessage message,
    CometChatMessageSendState state,
    MessageFailureReason? reason,
  ) {}

  //Offline (additive, G14): the SDK wiped and rebuilt the offline cache,
  //losing unsent messages. [pendingMessagesLost] is null when unknown, never 0.
  //Default no-op; never emitted with offline off.
  /// Called when the SDK wiped and rebuilt the offline cache (offline only).
  void ccOfflineCacheReset(
    OfflineCacheResetReason reason,
    int? pendingMessagesLost,
  ) {}

  //---message list events---
  //event for message edited by logged-in user
  void ccMessageEdited(BaseMessage message, MessageEditStatus status) {}

  //event for message deleted by logged-in user
  void ccMessageDeleted(BaseMessage message, EventStatus messageStatus) {}

  //event for message read by logged-in user
  void ccMessageRead(BaseMessage message) {}

  //event for the logged-in user following/unfollowing a thread from a kit
  //surface; default no-op so existing listeners are unaffected
  void ccThreadSubscriptionChanged(int parentMessageId, bool subscribed) {}

  //Pin & Save events for actions taken by the logged-in user from a kit
  //surface; [message] carries the full updated object. Default no-ops so
  //existing listeners are unaffected.
  void ccMessagePinned(BaseMessage message) {}

  void ccMessageUnpinned(BaseMessage message) {}

  void ccMessageSaved(BaseMessage message) {}

  void ccMessageUnsaved(BaseMessage message) {}

  //event for transient message sent by logged-in user
  void ccLiveReaction(String reaction) {}

  //event for forwarding message by logged-in user
  void ccMessageForwarded(
    BaseMessage message,
    List<User>? usersSent,
    List<Group>? groupsSent,
    MessageStatus status,
  ) {}

  //event for replying to a message by logged-in user
  void ccReplyToMessage(BaseMessage message) {}

  //event for forwarding message by logged-in user
  void onTextMessageReceived(TextMessage textMessage) {}

  //event for forwarding message by logged-in user
  void onMediaMessageReceived(MediaMessage mediaMessage) {}

  //event for forwarding message by logged-in user
  void onCustomMessageReceived(CustomMessage customMessage) {}

  //event for on transient message received
  void onTypingStarted(TypingIndicator typingIndicator) {}

  //event for on transient message received
  void onTypingEnded(TypingIndicator typingIndicator) {}

  //event for on transient message received
  void onMessagesDelivered(MessageReceipt messageReceipt) {}

  //event for on transient message received
  void onMessagesRead(MessageReceipt messageReceipt) {}

  //event for on transient message received
  void onMessageEdited(BaseMessage message) {}

  //event for on transient message received
  void onMessageDeleted(BaseMessage message) {}

  //event for on transient message received
  void onTransientMessageReceived(TransientMessage message) {}

  //event for forwarding message by logged-in user
  void onFormMessageReceived(FormMessage formMessage) {}

  //event for forwarding message by logged-in user
  void onCardMessageReceived(CardMessage cardMessage) {}

  //event for forwarding message by logged-in user
  void onCustomInteractiveMessageReceived(
    CustomInteractiveMessage customInteractiveMessage,
  ) {}

  //event for completion of interaction goals
  void onInteractionGoalCompleted(InteractionReceipt receipt) {}

  //event for listening to meeting message events
  void onSchedulerMessageReceived(SchedulerMessage schedulerMessage) {}

  ///[onMessageReactionAdded] is called when a reaction is added to a message
  void onMessageReactionAdded(ReactionEvent reactionEvent) {}

  ///[onMessageReactionRemoved] is called when a reaction is removed from a message
  void onMessageReactionRemoved(ReactionEvent reactionEvent) {}

  //event for all messages delivered to all
  void onMessagesDeliveredToAll(MessageReceipt messageReceipt) {}

  //event for all messages read by all
  void onMessagesReadByAll(MessageReceipt messageReceipt) {}

  //event for on transient message received
  void onMessageModerated(BaseMessage message) {}
}
