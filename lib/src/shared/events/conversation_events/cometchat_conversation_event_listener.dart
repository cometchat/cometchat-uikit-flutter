import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_chat_ui_kit/src/utils/ui_event_handler.dart';

///Listener class for [CometChatConversations]
abstract class CometChatConversationEventListener implements UIEventHandler {
  ///[ccConversationDeleted] is used to inform the listeners 
  ///when the logged-in user deletes a conversation
  void ccConversationDeleted(Conversation conversation) {}
}