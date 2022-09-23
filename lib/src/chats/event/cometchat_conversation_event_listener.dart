import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_chat_ui_kit/src/utils/ui_event_handler.dart';

///Listener class for [CometchatConversation]
abstract class CometChatConversationEventListener implements UIEventHandler {
  void onConversationTap(Conversation conversation) {}

  void onConversationLongPress(Conversation conversation) {}

  void onConversationError(CometChatException exception) {}
}
