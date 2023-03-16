import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

///Event emitting class for [CometchatConversation]
class CometChatConversationEvents {
  static Map<String, CometChatConversationEventListener>
      conversationListListener = {};

  static addConversationListListener(
      String listenerId, CometChatConversationEventListener listenerClass) {
    conversationListListener[listenerId] = listenerClass;
  }

  static removeConversationListListener(String listenerId) {
    conversationListListener.remove(listenerId);
  }

  static ccConversationDeleted(Conversation conversation) {
    conversationListListener.forEach((key, value) {
      value.ccConversationDeleted(conversation);
    });
  }
}
