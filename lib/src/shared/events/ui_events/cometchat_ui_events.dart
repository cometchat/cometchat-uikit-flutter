import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';


class CometChatUIEvents {
  static Map<String, CometChatUIEventListener> uiListener = {};

  static addUiListener(
      String listenerId, CometChatUIEventListener listenerClass) {
    uiListener[listenerId] = listenerClass;
  }

  static removeUiListener(String listenerId) {
    uiListener.remove(listenerId);
  }

  static showPanel(
      Map<String, dynamic>? id, alignment align, WidgetBuilder child) {
    uiListener.forEach((key, value) {
      value.showPanel(id, align, child);
    });
  }

  static hidePanel(Map<String, dynamic>? id, alignment align) {
    uiListener.forEach((key, value) {
      value.hidePanel(id, align);
    });
  }

  static onConversationChanged(Map<String, dynamic>? id,
      BaseMessage? lastMessage, User? user, Group? group) {
    uiListener.forEach((key, value) {
      value.onConversationChanged(id, lastMessage, user, group);
    });
  }
}
