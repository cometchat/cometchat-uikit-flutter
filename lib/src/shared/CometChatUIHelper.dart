import '../../flutter_chat_ui_kit.dart';

class CometChatUIHelper {
  static sendMessage(BaseMessage message, MessageStatus messageStatus) {
    CometChatMessageEvents.onMessageSent(message, messageStatus);
  }

  static onMessageError(CometChatException error, BaseMessage? message) {
    CometChatMessageEvents.onMessageError(error, message);
  }

  static onMessageEdit(BaseMessage message, MessageEditStatus status) {
    CometChatMessageEvents.onMessageEdit(message, status);
  }

  static onMessageDelete(BaseMessage message) {
    CometChatMessageEvents.onMessageDelete(message);
  }

  static onMessageReact(
      BaseMessage message, String reaction, MessageStatus messageStatus) {
    CometChatMessageEvents.onMessageReact(message, reaction, messageStatus);
  }
}
