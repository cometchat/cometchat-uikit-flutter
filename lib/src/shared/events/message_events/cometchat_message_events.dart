import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

///Event emitting class for [CometChatMessages]
class CometChatMessageEvents {
  static Map<String, CometChatMessageEventListener> messagesListener = {};

  static addMessagesListener(
      String listenerId, CometChatMessageEventListener listenerClass) {
    messagesListener[listenerId] = listenerClass;
  }

  static removeMessagesListener(String listenerId) {
    messagesListener.remove(listenerId);
  }

  static ccMessageSent(BaseMessage message, MessageStatus messageStatus) {
    messagesListener.forEach((key, value) {
      value.ccMessageSent(message, messageStatus);
    });
  }

  static ccMessageEdited(BaseMessage message, MessageEditStatus status) {
    messagesListener.forEach((key, value) {
      value.ccMessageEdited(message, status);
    });
  }

  static ccMessageDeleted(BaseMessage message, EventStatus messageStatus) {
    messagesListener.forEach((key, value) {
      value.ccMessageDeleted(message, messageStatus);
    });
  }

  static ccMessageRead(BaseMessage message) {
    messagesListener.forEach((key, value) {
      value.ccMessageRead(message);
    });
  }

  static ccLiveReaction(String reaction, String receiverId) {
    messagesListener.forEach((key, value) {
      value.ccLiveReaction(reaction);
    });
  }
}
