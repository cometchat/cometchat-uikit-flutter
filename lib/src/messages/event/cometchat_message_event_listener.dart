import 'package:flutter_chat_ui_kit/src/utils/ui_event_handler.dart';
import '../../../flutter_chat_ui_kit.dart';

enum LiveReactionType { liveReaction }

///Listener class for [CometChatMessages]
abstract class CometChatMessageEventListener implements UIEventHandler {
  //---composer events---
  void onMessageSent(BaseMessage message, MessageStatus messageStatus) {}

  //void onMessageEdited(BaseMessage message) {}

  void onMessageError(CometChatException error, BaseMessage? message) {}

  void onCreatePoll(MessageStatus messageStatus) {}

  void onMessageReact(
      BaseMessage message, String reaction, MessageStatus messageStatus) {}

//---message list events---
  void onMessageEdit(BaseMessage message, MessageEditStatus status) {}

  void onMessageReply(BaseMessage message) {}

  void onMessageDelete(BaseMessage message) {}

  void onMessageDeleted(BaseMessage message) {}

  void onMessageRead(BaseMessage message) {}

  void onMessageTap(BaseMessage message) {}

  void onMessageLongPress(BaseMessage message) {}

  void onLiveReaction(String reaction) {}

  void onEventClicked(CometChatMessageOptions messageOptions,
      BaseMessage message, CometChatMessageListState state) {}
}
