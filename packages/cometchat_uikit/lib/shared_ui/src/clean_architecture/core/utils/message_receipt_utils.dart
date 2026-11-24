import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

import '../../../offline/offline_send.dart';

///[MessageReceiptUtils] is a utility class to determine receipt status
class MessageReceiptUtils {
  static ReceiptStatus getReceiptStatus(BaseMessage message) {
    ReceiptStatus receiptStatus = ReceiptStatus.waiting;

    // Moderation-based receipt override for Text and Media messages
    if (message is TextMessage) {
      if (message.moderationStatus?.value ==
          ModerationStatusEnum.DISAPPROVED.value) {
        return ReceiptStatus.error;
      }
    } else if (message is MediaMessage) {
      if (message.moderationStatus?.value ==
          ModerationStatusEnum.DISAPPROVED.value) {
        return ReceiptStatus.error;
      }
    }

    // Offline (W4, BEH-SEND-32): an unsent row shows the clock or the failed
    // icon, never a server receipt.
    if (OfflineSend.instance.appliesTo(message)) {
      final unsent = OfflineSend.instance.unsentReceiptOf(message);
      if (unsent != null) {
        return unsent == MessageReceiptStatus.error
            ? ReceiptStatus.error
            : ReceiptStatus.waiting;
      }
    }

    if (message.metadata != null &&
        message.metadata!.containsKey("error") &&
        (message.metadata?["error"] is Exception ||
            message.metadata?["error"] is String)) {
      receiptStatus = ReceiptStatus.error;
    } else if (message.readAt != null) {
      receiptStatus = ReceiptStatus.read;
    } else if (message.deliveredAt != null) {
      receiptStatus = ReceiptStatus.delivered;
    } else if (message.sentAt != null && message.id != 0) {
      receiptStatus = ReceiptStatus.sent;
    } else {
      receiptStatus = ReceiptStatus.waiting;
    }

    return receiptStatus;
  }
}
