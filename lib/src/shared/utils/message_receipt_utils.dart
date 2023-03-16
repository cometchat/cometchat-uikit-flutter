import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class MessageReceiptUtils {
  static ReceiptStatus getReceiptStatus(BaseMessage _message) {
    ReceiptStatus _receiptStatus = ReceiptStatus.waiting;

    if (_message.metadata != null &&
        _message.metadata!.containsKey("error") &&
        _message.metadata?["error"] is Exception) {
      _receiptStatus = ReceiptStatus.error;
    } else if (_message.readAt != null) {
      _receiptStatus = ReceiptStatus.read;
    } else if (_message.deliveredAt != null) {
      _receiptStatus = ReceiptStatus.delivered;
    } else if (_message.sentAt != null) {
      _receiptStatus = ReceiptStatus.sent;
    }

    return _receiptStatus;
  }
}
