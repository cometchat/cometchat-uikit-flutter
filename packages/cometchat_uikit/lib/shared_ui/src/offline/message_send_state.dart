import 'package:cometchat_sdk/cometchat_sdk.dart';

/// The lifecycle state of an own message, as reported to integrators through
/// the new public send-state event (W1 §2.2, PR #23 §3.4).
///
/// This is the payload of [CometChatMessageEvents.ccMessageSendStateChanged]
/// and is the only send-state type the kit exposes publicly. It never replaces
/// or extends the SDK's [CometChatMessageStatus]; it is a coarser three-state
/// view (sending / sent / failed) that the offline UI renders from.
enum CometChatMessageSendState {
  /// The message is queued or in flight and has not been acknowledged by the
  /// server yet (SDK PENDING or SENDING). Shown as "Not sent yet".
  sending,

  /// The message reached the server (SDK SENT / DELIVERED / READ).
  sent,

  /// The message failed to send (SDK FAILED).
  failed,
}

/// How a failed own message can be retried (W1 §2.2). Internal to the kit.
enum OfflineFailureKind {
  /// The failure has a durable outbox row: Retry is
  /// `CometChat.retryMessage(localMessageId, listener:)` and the failed state
  /// survives a relaunch (derived from `message.status`).
  outbox,

  /// The failure has no outbox row (a direct/refused send, e.g. queue full or
  /// byte overflow): Retry is a fresh send and the failed mark is kept in
  /// memory only, keyed by [rowKey].
  direct,
}

/// Maps the SDK's derived [CometChatMessageStatus] to the public
/// [CometChatMessageSendState] (W1 §2.2, PR #23 §3.4):
///
/// * pending / sending  → [CometChatMessageSendState.sending]
/// * sent / delivered / read → [CometChatMessageSendState.sent]
/// * failed → [CometChatMessageSendState.failed]
/// * null status → [CometChatMessageSendState.sent]
///
/// Failed is derived from `message.status` on every build (BEH-SEND-30); the
/// only exception is a `direct` failure, which has no outbox row and is tracked
/// in memory by the sending seam (W4).
CometChatMessageSendState sendStateOf(BaseMessage m) {
  switch (m.status) {
    case CometChatMessageStatus.pending:
    case CometChatMessageStatus.sending:
      return CometChatMessageSendState.sending;
    case CometChatMessageStatus.failed:
      return CometChatMessageSendState.failed;
    case CometChatMessageStatus.sent:
    case CometChatMessageStatus.delivered:
    case CometChatMessageStatus.read:
      return CometChatMessageSendState.sent;
  }
}
