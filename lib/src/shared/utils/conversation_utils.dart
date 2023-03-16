import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import '../../../flutter_chat_ui_kit.dart' as cc;

class ConversationUtils {

  static List<CometChatOption>? getDefaultOptions(
      Conversation conversation,
      CometChatConversationsController controller,
      BuildContext context,
      CometChatTheme? theme) {
    return [CometChatOption(
        id: ConversationOptionConstants.delete,
        icon: AssetConstants.delete,
        packageName: UIConstants.packageName,
        backgroundColor: Colors.red,
        onClick: () {
          controller.deleteConversation(conversation);
        })];
  }

  static String getLastCustomMessage(
      Conversation conversation, BuildContext context) {
    CustomMessage customMessage = conversation.lastMessage as CustomMessage;
    String messageType = customMessage.type;
    String subtitle = '';

    switch (messageType) {
      default:
        subtitle = messageType;
        break;
    }
    return subtitle;
  }

  static String getLastMessage(
      Conversation conversation, BuildContext context) {
    BaseMessage message = conversation.lastMessage!;
    String messageType = message.type;
    String subtitle;
    switch (messageType) {
      case MessageTypeConstants.text:
        subtitle = (message as TextMessage).text;
        break;
      case MessageTypeConstants.image:
        subtitle = Translations.of(context).message_image;
        break;
      case MessageTypeConstants.video:
        subtitle = Translations.of(context).message_video;
        break;
      case MessageTypeConstants.file:
        subtitle = Translations.of(context).message_file;
        break;
      case MessageTypeConstants.audio:
        subtitle = Translations.of(context).message_audio;
        break;
      default:
        subtitle = messageType;
    }
    return subtitle;
  }

  static String getLastActionMessage(
      Conversation conversation, BuildContext context) {
    BaseMessage message = conversation.lastMessage!;
    String subtitle;

    if (message.type == MessageTypeConstants.groupActions) {
      cc.Action actionMessage = message as cc.Action;
      subtitle = actionMessage.message;
    } else {
      subtitle = message.type;
    }

    return subtitle;
  }

  static String getLastCallMessage(
      Conversation conversation, BuildContext context) {
    Call call = conversation.lastMessage as Call;
    User? conversationWithUser;
    Group? conversationWithGroup;

    if (conversation.conversationWith is User) {
      conversationWithUser = conversation.conversationWith as User;
    }
    if (conversation.conversationWith is Group) {
      conversationWithGroup = conversation.conversationWith as Group;
    }

    String subtitle = call.type;
    Group? callInitiatorGroup;
    User? callInitiatorUser;
    if (call.callInitiator is User) {
      callInitiatorUser = call.callInitiator as User;
    } else {
      callInitiatorGroup = call.callInitiator as Group;
    }

    if (call.callStatus == CallStatusConstants.ongoing) {
      subtitle = Translations.of(context).ongoing_call;
    } else if (call.callStatus == CallStatusConstants.ended ||
        call.callStatus == CallStatusConstants.initiated) {
      if ((callInitiatorUser != null &&
              conversationWithUser != null &&
              callInitiatorUser.uid == conversationWithUser.uid) ||
          (callInitiatorGroup != null &&
              conversationWithGroup != null &&
              callInitiatorGroup.guid == conversationWithGroup.guid)) {
        if (call.type == MessageTypeConstants.audio) {
          subtitle = Translations.of(context).incoming_audio_call;
        } else {
          subtitle = Translations.of(context).incoming_video_call;
        }
      } else {
        if (call.type == MessageTypeConstants.audio) {
          subtitle = Translations.of(context).outgoing_audio_call;
        } else {
          subtitle = Translations.of(context).outgoing_video_call;
        }
      }
    } else if (call.callStatus == CallStatusConstants.cancelled ||
        call.callStatus == CallStatusConstants.unanswered ||
        call.callStatus == CallStatusConstants.rejected ||
        call.callStatus == CallStatusConstants.busy) {
      if ((callInitiatorUser != null &&
              conversationWithUser != null &&
              callInitiatorUser.uid == conversationWithUser.uid) ||
          (callInitiatorGroup != null &&
              conversationWithGroup != null &&
              callInitiatorGroup.guid == conversationWithGroup.guid)) {
        if (call.type == MessageTypeConstants.audio) {
          subtitle = Translations.of(context).missed_voice_call;
        } else {
          subtitle = Translations.of(context).missed_video_call;
        }
      } else {
        if (call.type == MessageTypeConstants.audio) {
          subtitle = Translations.of(context).unanswered_audio_call;
        } else {
          subtitle = Translations.of(context).unanswered_video_call;
        }
      }
    }
    return subtitle;
  }

  static String getLastConversationMessage(
      Conversation conversation, BuildContext context) {
    String? messageCategory = conversation.lastMessage?.category;
    String subtitle;
    switch (messageCategory) {
      case MessageCategoryConstants.message:
        subtitle = getLastMessage(conversation, context);
        break;
      case MessageCategoryConstants.custom:
        subtitle = getLastCustomMessage(conversation, context);
        break;
      case MessageCategoryConstants.action:
        subtitle = getLastActionMessage(conversation, context);
        break;
      case MessageCategoryConstants.call:
        subtitle = getLastCallMessage(conversation, context
        );
        break;
      default:
        subtitle = conversation.lastMessage!.type;
        break;
    }

    return subtitle;
  }
}
