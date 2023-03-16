import 'package:flutter/cupertino.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_chat_ui_kit/src/utils/ui_event_handler.dart';

enum alignment {
  composerTop,
  composerBottom,
  messageListTop,
  messageListBottom
}

///Listener class for [CometChatConversations]
abstract class CometChatUIEventListener implements UIEventHandler {
  void showPanel(
      Map<String, dynamic>? id, alignment align, WidgetBuilder child) {}
  void hidePanel(Map<String, dynamic>? id, alignment align) {}

  void onConversationChanged(Map<String, dynamic>? id, BaseMessage? lastMessage,
      User? user, Group? group) {}
}
