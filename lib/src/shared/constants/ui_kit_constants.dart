import 'package:flutter/services.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class UIConstants {
  static const MethodChannel channel = MethodChannel('flutter_chat_ui_kit');
  static const String packageName = "flutter_chat_ui_kit";
}

class MessageCategoryConstants {
  static const String message = CometChatMessageCategory.message;
  static const String action = CometChatMessageCategory.action;
  static const String call = CometChatMessageCategory.call;
  static const String custom = CometChatMessageCategory.custom;
}

class MessageTypeConstants {
  static const String image = CometChatMessageType.image;
  static const String video = CometChatMessageType.video;
  static const String audio = CometChatMessageType.audio;
  static const String file = CometChatMessageType.file;
  static const String text = CometChatMessageType.text;
  static const String custom = CometChatMessageType.custom;
  static const String groupActions = "groupMember";
  static const String message = "message";
  static const String takePhoto = "takePhoto";
  static const String photoAndVideo = "photoAndVideo";
}

class ReceiverTypeConstants {
  static const String user = "user";
  static const String group = "group";
}

class MessageOptionConstants {
  static const String editMessage = "editMessage";
  static const String deleteMessage = "deleteMessage";
  static const String shareMessage = "shareMessage";
  static const String copyMessage = "copyMessage";
  static const String forwardMessage = "forwardMessage";
  static const String replyMessage = "replyMessage";
  static const String replyInThreadMessage = "replyInThreadMessage";
  static const String reactToMessage = "reactToMessage";
  static const String translateMessage = "translateMessage";
  static const String messageInformation = "messageInformation";
  static const String sendMessagePrivately = "sendMessagePrivately";
  static const String replyMessagePrivately = "replyMessagePrivately";
}

class MetadataConstants {
  static const String liveReaction = "live_reaction";
  static const String replyMessage = "reply-message";
  static const String stickerUrl = "sticker_url";
  static const String stickerName = "sticker_name";
}

class GroupOptionConstants {
  static const String leave = "leave";
  static const String delete = "delete";
  static const String viewMembers = "viewMembers";
  static const String addMembers = "addMembers";
  static const String bannedMembers = "bannedMembers";
  static const String voiceCall = "voiceCall";
  static const String videoCall = "videoCall";
  static const String viewInformation = "viewInformation";
}

class GroupMemberOptionConstants {
  static const String kick = "kick";
  static const String ban = "ban";
  static const String unban = "unban";
  static const String changeScope = "changeScope";
}

class UserOptionConstants {
  static const String blockUnblock = "blockUnblock";
  static const String viewProfile = "viewProfile";
  static const String voiceCall = "voiceCall";
  static const String videoCall = "videoCall";
  static const String viewInformation = "viewInformation";
  static const String blockUser = "blockUser";
  static const String unblockUser = "unblockUser";
}

class GroupTypeConstants {
  static const String private = CometChatGroupType.private;
  static const String public = CometChatGroupType.public;
  static const String password = CometChatGroupType.password;
}

class GroupMemberScope {
  static const String admin = CometChatMemberScope.admin;
  static const String moderator = CometChatMemberScope.moderator;
  static const String participant = CometChatMemberScope.participant;
  static const String owner = "owner";
}

class UserStatusConstants {
  static const String online = CometChatUserStatus.online;
  static const String offline = CometChatUserStatus.offline;
}

class ReceiptTypeConstants {
  static const String delivered = CometChatReceiptType.delivered;
  static const String read = CometChatReceiptType.read;
}

class DetailsTemplateConstants {
  static const String primaryActions = "primaryActions";
  static const String destructiveActions = "destructiveActions";
  static const String moreActions = "moreActions";
}

class UITabNameConstants {
  static const userWithMessages = "userWithMessages";
  static const groupWithMessages = "groupWithMessages";
  static const conversationWithMessages = "conversationWithMessages";
}

class ConversationOptionConstants {
  static const delete = "delete";
}

class CallStatusConstants {
  static const initiated = "initiated";
  static const ongoing = "ongoing";
  static const rejected = "rejected";
  static const cancelled = "cancelled";
  static const busy = "busy";
  static const unanswered = "unanswered";
  static const ended = "ended";
}

typedef OnError = Function(Exception e);

class LiveReactionConstants {
  static const timeout = 1500;
}
