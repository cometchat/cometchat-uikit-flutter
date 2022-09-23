import '../../../flutter_chat_ui_kit.dart';

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

  static onMessageSent(BaseMessage message, MessageStatus messageStatus) {
    messagesListener.forEach((key, value) {
      value.onMessageSent(message, messageStatus);
    });
  }

  static onCreatePoll(MessageStatus messageStatus) {
    messagesListener.forEach((key, value) {
      value.onCreatePoll(messageStatus);
    });
  }

  // static onMessageEdited(BaseMessage message) {
  //   messagesListener.forEach((key, value) {
  //     value.onMessageEdited(message);
  //   });
  // }

  static onMessageError(CometChatException error, BaseMessage? message) {
    messagesListener.forEach((key, value) {
      value.onMessageError(error, message);
    });
  }

  static onMessageReact(
      BaseMessage message, String reaction, MessageStatus messageStatus) {
    messagesListener.forEach((key, value) {
      value.onMessageReact(message, reaction, messageStatus);
    });
  }

//---message list events---
  static onMessageEdit(BaseMessage message, MessageEditStatus status) {
    messagesListener.forEach((key, value) {
      value.onMessageEdit(message, status);
    });
  }

  static onMessageReply(BaseMessage message) {
    messagesListener.forEach((key, value) {
      value.onMessageReply(message);
    });
  }

  static onMessageDelete(BaseMessage message) {
    messagesListener.forEach((key, value) {
      value.onMessageDelete(message);
    });
  }

  static onMessageDeleted(BaseMessage message) {
    messagesListener.forEach((key, value) {
      value.onMessageDeleted(message);
    });
  }

  static onMessageRead(BaseMessage message) {
    messagesListener.forEach((key, value) {
      value.onMessageRead(message);
    });
  }

  static onMessageTap(BaseMessage message) {
    messagesListener.forEach((key, value) {
      value.onMessageTap(message);
    });
  }

  static onMessageLongPress(BaseMessage message) {
    messagesListener.forEach((key, value) {
      value.onMessageLongPress(message);
    });
  }

  static onEventClicked(CometChatMessageOptions messageOptions,
      BaseMessage message, CometChatMessageListState state) {
    messagesListener.forEach((key, value) {
      value.onEventClicked(messageOptions, message, state);
    });
  }

  static onLiveReaction(String reaction) {
    messagesListener.forEach((key, value) {
      value.onLiveReaction(reaction);
    });
  }
}
