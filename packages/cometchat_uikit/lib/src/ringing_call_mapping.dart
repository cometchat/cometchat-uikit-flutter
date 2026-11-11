import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show InitiatedCall;
import 'package:cometchat_sdk/cometchat_sdk.dart' show AppEntity, Call, User;

import '../shared_ui/src/constants/ui_kit_constants.dart'
    show CallStatusConstants, MessageCategoryConstants;

/// Builds the chat SDK [Call] the UI Kit's calling API, call components and
/// call events take, from what the Calls SDK's ringing calls return.
///
/// Package-private (see `lib/src/`). `CometChatCalls.initiateCall` returns an
/// [InitiatedCall] (and `endCall` nothing), not the chat SDK's call
/// message. The UI Kit keeps the [Call] as its public type (ringing v2, as
/// Android does): `CometChatUIKitCalls.initiateCall` and `rejectCall`, the
/// outgoing call screen and the events (`ccOutgoingCall`, `ccCallRejected`,
/// ...) still take and return one. The message ID it carries is the
/// server's, so the message list matches it to the call message itself.
abstract final class RingingCallMapping {
  /// The [Call] for [placed], a call this device has just placed.
  ///
  /// [caller] is the logged-in user, and [receiver] the user or group called,
  /// when known: the call carries them as initiator and receiver. Otherwise
  /// they are built from the UIDs the Calls SDK returned.
  static Call fromInitiated(
    InitiatedCall placed, {
    User? caller,
    AppEntity? receiver,
  }) {
    final callerUid = placed.sender;
    final initiator =
        caller ??
        (callerUid == null || callerUid.isEmpty
            ? null
            : User(
                uid: callerUid,
                name: placed.callerName ?? callerUid,
                avatar: placed.callerAvatarUrl,
              ));
    final initiatedAt = placed.initiatedAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(placed.initiatedAt)
        : DateTime.now();
    return Call(
      id: int.tryParse(placed.messageId ?? '') ?? 0,
      sessionId: placed.sessionId,
      callStatus: placed.status.isEmpty
          ? CallStatusConstants.initiated
          : placed.status,
      type: placed.type ?? '',
      receiverType: placed.receiverType ?? '',
      receiverUid: placed.receiver ?? '',
      callInitiator: initiator,
      callReceiver: receiver,
      sender: initiator,
      receiver: receiver,
      initiatedAt: initiatedAt,
      sentAt: initiatedAt,
      conversationId: placed.conversationId,
      category: MessageCategoryConstants.call,
    );
  }

  /// The UI Kit's status for an `onIncomingCallEnded` [reason], or null for
  /// one that is not an end of the call (an answer, a filtered push). The
  /// reasons differ per platform: Android's are call statuses, iOS's
  /// CallKit's.
  static String? endStatusForReason(String reason) {
    switch (reason.toLowerCase()) {
      case 'rejected':
      case 'declined':
        return CallStatusConstants.rejected;
      case 'busy':
        return CallStatusConstants.busy;
      case 'cancelled':
        return CallStatusConstants.cancelled;
      case 'unanswered':
      case 'timedout':
        return CallStatusConstants.unanswered;
      case 'ended':
      case 'remoteended':
      case 'failed':
        return CallStatusConstants.ended;
      default:
        return null;
    }
  }

  /// The [Call] for [sessionId], ended before it was joined with [status]
  /// (`CometChatCalls.endCall`, which reports no data since Calls SDK
  /// 5.1.0-team): [known], the call as this device knows it (its ringing or
  /// active call record), in that status, or the session alone. No call
  /// message ID: the Calls SDK does not return the message the status made.
  static Call ended(String sessionId, String status, {Call? known}) {
    final base =
        known ??
        Call(sessionId: sessionId, receiverUid: '', type: '', receiverType: '');
    return withStatus(base, status);
  }

  /// A copy of [call] in [status]: the call as it stands once that status
  /// came. It claims no call message (ID 0), so it is never taken for the
  /// message of an earlier status.
  static Call withStatus(Call call, String status) {
    final at = DateTime.now();
    return Call(
      id: 0,
      sessionId: call.sessionId,
      callStatus: status,
      type: call.type,
      receiverType: call.receiverType,
      receiverUid: call.receiverUid,
      callInitiator: call.callInitiator,
      callReceiver: call.callReceiver,
      sender: call.sender,
      receiver: call.receiver,
      initiatedAt: call.initiatedAt,
      joinedAt: call.joinedAt,
      sentAt: at,
      updatedAt: at,
      conversationId: call.conversationId,
      category: MessageCategoryConstants.call,
    );
  }
}
