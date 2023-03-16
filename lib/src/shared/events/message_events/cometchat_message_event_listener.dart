import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_chat_ui_kit/src/utils/ui_event_handler.dart';

enum LiveReactionType { liveReaction }

///Listener class for [CometChatMessages]
abstract class CometChatMessageEventListener implements UIEventHandler {
  //---composer events---
  //event for message sent by logged-in user
  void ccMessageSent(BaseMessage message, MessageStatus messageStatus) {}

  //---message list events---
  //event for message edited by logged-in user
  void ccMessageEdited(BaseMessage message, MessageEditStatus status) {}

  //event for message deleted by logged-in user
  void ccMessageDeleted(BaseMessage message, EventStatus messageStatus) {}

  //event for message read by logged-in user
  void ccMessageRead(BaseMessage message) {}

  //event for transient message sent by logged-in user
  void ccLiveReaction(String reaction) {}

}
