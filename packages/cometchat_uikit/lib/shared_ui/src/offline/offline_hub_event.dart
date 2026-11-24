import 'package:cometchat_sdk/cometchat_sdk.dart';

import 'message_send_state.dart';

/// The events the [OfflineHub] fans out to the blocs on its private broadcast
/// channel (W1 §2.6, PR #23 §3.5). Each carries the session [gen]; a bloc drops
/// an event whose [gen] is older than its own.
sealed class OfflineHubEvent {
  const OfflineHubEvent(this.gen);

  /// The session generation the event belongs to.
  final int gen;
}

/// One transition of an own queued send (from the outbox listener). The hub
/// emits at most one of these per transition per non-empty [localMessageId]
/// (the dedupe, ON path only).
class SendStateEvent extends OfflineHubEvent {
  /// Creates a send-state transition event.
  const SendStateEvent(
    super.gen,
    this.localMessageId,
    this.message,
    this.state,
    this.reason,
  );

  /// The local id of the message (empty when it has none).
  final String localMessageId;

  /// The message as the SDK reported it.
  final BaseMessage message;

  /// The new send state.
  final CometChatMessageSendState state;

  /// Why the send failed, when [state] is failed.
  final MessageFailureReason? reason;
}

/// A reconnect conversation-sync completed with this page (BEH-SYNC-08).
class ConversationSyncCompleted extends OfflineHubEvent {
  /// Creates a conversation-sync completion event.
  const ConversationSyncCompleted(super.gen, this.conversations);

  /// The conversations the sync returned (one page).
  final List<Conversation> conversations;
}

/// A reconnect conversation-sync failed.
class ConversationSyncFailed extends OfflineHubEvent {
  /// Creates a conversation-sync failure event.
  const ConversationSyncFailed(super.gen, this.error);

  /// The sync error.
  final CometChatException error;
}

/// A reconnect message-sync completed with this page and [outcome]
/// (BEH-SYNC-25/31). Carries `action`/`call` rows the message callbacks don't.
class MessageSyncCompleted extends OfflineHubEvent {
  /// Creates a message-sync completion event.
  const MessageSyncCompleted(super.gen, this.messages, this.outcome);

  /// The messages the sync returned.
  final List<BaseMessage> messages;

  /// Whether the sync caught up or was partial.
  final SyncOutcome outcome;
}

/// A reconnect message-sync failed.
class MessageSyncFailed extends OfflineHubEvent {
  /// Creates a message-sync failure event.
  const MessageSyncFailed(super.gen, this.error);

  /// The sync error.
  final CometChatException error;
}

/// `onMessagesSynced`: update rows already shown, never insert (BEH-INV-11).
class MessagesUpdated extends OfflineHubEvent {
  /// Creates a synced-updates event.
  const MessagesUpdated(super.gen, this.messages);

  /// The updated messages (edits, deletes, reactions, receipts).
  final List<BaseMessage> messages;
}

/// The SDK wiped and rebuilt the offline cache (BEH-ENC-15/16).
/// [pendingMessagesLost] is null when unknown, never 0.
class CacheReset extends OfflineHubEvent {
  /// Creates a cache-reset event.
  const CacheReset(super.gen, this.reason, this.pendingMessagesLost);

  /// Why the cache was reset.
  final OfflineCacheResetReason reason;

  /// How many unsent messages were lost, or null when unknown.
  final int? pendingMessagesLost;
}

/// A media attachment finished downloading and its local path is ready.
///
/// A bubble is found by [attachmentId] (every attachment carries it) or, for an
/// own un-acked message, by [localMessageId]. [messageId] is the server id when
/// the SDK supplies one; SDK 5.1.0's `onMediaDownloaded` passes only the local
/// id and the attachment id, so it is null until the SDK adds it.
class MediaReady extends OfflineHubEvent {
  /// Creates a media-ready event.
  const MediaReady(
    super.gen,
    this.localMessageId,
    this.messageId,
    this.localPath, {
    required this.attachmentId,
  });

  /// The local id of an own un-acked message, else null.
  final String? localMessageId;

  /// The server message id, when the SDK supplies it.
  final int? messageId;

  /// Where the downloaded media is stored.
  final String localPath;

  /// The id of the attachment that finished downloading.
  final String attachmentId;
}

/// The session ended (logout, or a login as a different uid). Blocs clear
/// everything before the next frame and bump their own list `gen`.
class SessionEnded extends OfflineHubEvent {
  /// Creates a session-end event.
  const SessionEnded(super.gen);
}
