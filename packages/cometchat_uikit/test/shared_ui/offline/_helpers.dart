import 'package:cometchat_sdk/cometchat_sdk.dart';

/// Builds a [BaseMessage] for the offline unit tests.
BaseMessage msg({
  int id = 0,
  String muid = '',
  String? localMessageId,
  String? senderUid,
  String receiverUid = 'bob',
  String receiverType = 'user',
  String? conversationId,
  int? updatedAtMs,
  CometChatMessageStatus? status,
}) {
  final m = BaseMessage(
    id: id,
    muid: muid,
    receiverUid: receiverUid,
    type: 'text',
    receiverType: receiverType,
    localMessageId: localMessageId,
    conversationId: conversationId,
    sender: senderUid == null ? null : User(uid: senderUid, name: senderUid),
    updatedAt: updatedAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
  );
  if (status != null) m.sendState = _sendStateFor(status);
  return m;
}

String? _sendStateFor(CometChatMessageStatus s) {
  switch (s) {
    case CometChatMessageStatus.pending:
      return 'PENDING';
    case CometChatMessageStatus.sending:
      return 'SENDING';
    case CometChatMessageStatus.failed:
      return 'FAILED';
    case CometChatMessageStatus.sent:
    case CometChatMessageStatus.delivered:
    case CometChatMessageStatus.read:
      return null;
  }
}
