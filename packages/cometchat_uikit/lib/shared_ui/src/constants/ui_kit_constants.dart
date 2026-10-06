import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared_ui/cometchat_uikit_shared.dart';

///[UIConstants] contains properties essential and limited to setting up the ui kit

class UIConstants {
  static const MethodChannel channel = MethodChannel('cometchat_chat_uikit');
  static const String packageName = "cometchat_chat_uikit";
}

///[MessageCategoryConstants] is a utility class that stores String constants of categories of messages
class MessageCategoryConstants {
  static const String message = CometChatMessageCategory.message;
  static const String action = CometChatMessageCategory.action;
  static const String call = CometChatMessageCategory.call;
  static const String custom = CometChatMessageCategory.custom;
  static const String interactive = CometChatMessageCategory.interactive;
  static const String card = CometChatMessageCategory.categoryCard;
  static const String agentic = CometChatMessageCategory.categoryAgentic;
}

///[MessageTypeConstants] is a utility class that stores String constants of types of messages
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
  static const String form = "form";
  static const String card = "card";
  static const String customInteractive = "customInteractive";
  static const String scheduler = "scheduler";
  static const String meeting = "meeting";
  static const String attachPhoto = "attachPhoto";
  static const String attachVideo = "attachVideo";
}

///[ReceiverTypeConstants] is a utility class that stores String constants of the types of [AppEntity] that can receive a [BaseMessage]
class ReceiverTypeConstants {
  static const String user = "user";
  static const String group = "group";
}

///[MessageOptionConstants] is a utility class that stores String constants of the actions permitted to execute on a particular [BaseMessage]
class MessageOptionConstants {
  static const String editMessage = "editMessage";
  static const String deleteMessage = "deleteMessage";
  static const String shareMessage = "shareMessage";
  static const String copyMessage = "copyMessage";
  static const String forwardMessage = "forwardMessage";
  static const String replyMessage = "replyMessage";
  static const String replyInThreadMessage = "replyInThreadMessage";
  static const String threadSubscription = "threadSubscription";
  static const String pinMessage = "pinMessage";
  static const String unpinMessage = "unpinMessage";
  static const String saveMessage = "saveMessage";
  static const String unsaveMessage = "unsaveMessage";
  // static const String reactToMessage = "reactToMessage";
  /// The Translate option: shows a text message translated into the
  /// app language, via the `message-translation` extension.
  static const String translateMessage = "translateMessage";
  static const String messageInformation = "messageInformation";
  static const String sendMessagePrivately = "sendMessagePrivately";
  // static const String replyMessagePrivately = "replyMessagePrivately";
  static const String markAsUnread = "markAsUnread";
  static const String reportMessage = "reportMessage";
}

///[MetadataConstants] is a utility class that stores String constants to use in the [metadata] property of a [BaseMessage]
class MetadataConstants {
  static const String liveReaction = "live_reaction";
  // static const String replyMessage = "reply-message";
}

///[GroupOptionConstants] is a utility class that stores String constants of the options available in `CometChatDetails` if it is being rendered for a [Group]
class GroupOptionConstants {
  static const String leave = "leave";
  static const String delete = "delete";
  static const String viewMembers = "viewMembers";
  static const String addMembers = "addMembers";
  static const String bannedMembers = "bannedMembers";
  static const String voiceCall = "voiceCall";
  static const String videoCall = "videoCall";
}

///[GroupMemberOptionConstants] is a utility class that stores String constants of the actions permitted to a [GroupMember] to execute on a particular [Group]
class GroupMemberOptionConstants {
  static const String kick = "kick";
  static const String ban = "ban";
  static const String unban = "unban";
  static const String changeScope = "changeScope";
}

///[UserOptionConstants] is a utility class that stores String constants of the options available in `CometChatDetails` if it is being rendered for a [User]
class UserOptionConstants {
  static const String viewProfile = "viewProfile";
  static const String voiceCall = "voiceCall";
  static const String videoCall = "videoCall";
  static const String blockUser = "blockUser";
  static const String unblockUser = "unblockUser";
}

///[GroupTypeConstants] is a utility class that stores String constants of the types of [Group]
class GroupTypeConstants {
  static const String private = CometChatGroupType.private;
  static const String public = CometChatGroupType.public;
  static const String password = CometChatGroupType.password;
}

///[GroupMemberScope] is a utility class that stores String constants of scope of [GroupMember] with respect to a particular [Group]
class GroupMemberScope {
  static const String admin = CometChatMemberScope.admin;
  static const String moderator = CometChatMemberScope.moderator;
  static const String participant = CometChatMemberScope.participant;
  static const String owner = "owner";
}

///[UserStatusConstants] is a utility class that stores String constants of the online/offline status of an [User]
class UserStatusConstants {
  static const String online = CometChatUserStatus.online;
  static const String offline = CometChatUserStatus.offline;
}

///[ReceiptTypeConstants] is a utility class that stores String constants of the various stages of message delivery
class ReceiptTypeConstants {
  static const String delivered = CometChatReceiptType.delivered;
  static const String read = CometChatReceiptType.read;
  static const String deliveredToAll = CometChatReceiptType.deliveredToAll;
  static const String readByAll = CometChatReceiptType.readByAll;
}

///[DetailsTemplateConstants] is a utility class that stores String constants of the types of [CometChatDetailsTemplate]
class DetailsTemplateConstants {
  static const String primaryActions = "primaryActions";
  static const String secondaryActions = "secondaryActions";
  // static const String moreActions = "moreActions";
}

///[UITabNameConstants] is a utility class that stores String constants of the names of the tabs available for [CometChatUI]
class UITabNameConstants {
  static const userWithMessages = "userWithMessages";
  static const groupWithMessages = "groupWithMessages";
  static const conversationWithMessages = "conversationWithMessages";
}

///[ConversationOptionConstants] is a utility class that stores String constants of options available for [Conversation] items
class ConversationOptionConstants {
  static const delete = "delete";
}

///[CallStatusConstants] is a utility class that stores String constants of various stages of [Call]
class CallStatusConstants {
  static const initiated = "initiated";
  static const ongoing = "ongoing";
  static const rejected = "rejected";
  static const cancelled = "cancelled";
  static const busy = "busy";
  static const unanswered = "unanswered";
  static const ended = "ended";
}

///[OnError] defines the structure of error handler used by the components in the ui kit
typedef OnError = Function(Exception e);

///[OnLoad] defines the structure of loading handler used by the components in the ui kit
typedef OnLoad<T> = Function(List<T> list);

///[OnEmpty] defines the structure of empty handler used by the components in the ui kit
typedef OnEmpty = void Function();

typedef ComposerWidgetBuilder =
    Widget Function(
      BuildContext context,
      User? user,
      Group? group,
      Map<String, dynamic>? id,
    );

typedef ComposerActionsBuilder =
    List<CometChatMessageComposerAction> Function(
      BuildContext context,
      User? user,
      Group? group,
      Map<String, dynamic>? id,
    );

typedef UserGroupBuilder =
    Function(BuildContext context, User? user, Group? group);

///[LiveReactionConstants] is a utility class that stores constant values related to functioning of [TransientMessage]
class LiveReactionConstants {
  static const timeout = 1500;
}

///[CometChatStartConversationType] is a utility class that stores String constants of the types of [CometChatContacts]
class CometChatStartConversationType {
  static const String user = CometChatConversationType.user;
  static const String group = CometChatConversationType.group;
}

class CallTypeConstants {
  static const audioCall = "audio";
  static const videoCall = "video";
}

class ActionMessageTypeConstants {
  static const edited = "edited";
  static const deleted = "deleted";
}

class UIElementTypeConstants {
  static const String label = "label";
  static const String textInput = "textInput";
  static const String button = "button";
  static const String checkbox = "checkbox";
  static const String dropdown = "dropdown";
  static const String radio = "radio";
  static const String singleSelect = "singleSelect";
  static const String dateTime = "dateTime";
}

class ActionTypeConstants {
  static const String apiAction = "apiAction";
  static const String urlNavigation = "urlNavigation";
  static const String customAction = "customAction";
}

class APIRequestTypeConstants {
  static const String post = "POST";
  static const String put = "PUT";
  static const String patch = "PATCH";
  static const String delete = "DELETE";
}

class InteractionGoalTypeConstants {
  static const String none = InteractionGoalType.none;
  static const String allOf = InteractionGoalType.allOf;
  static const String anyOf = InteractionGoalType.anyOf;
  static const String anyAction = InteractionGoalType.anyAction;
}

class ModelFieldConstants {
  static const formFields = "formFields";
  static const submitElement = "submitElement";
  static const title = "title";
  static const text = "text";

  static const type = "type";
  static const url = "url";
  static const payload = "payload";
  static const headers = "headers";
  static const actionType = "actionType";

  static const elementType = "elementType";
  static const elementId = "elementId";
  static const enabled = "enabled";
  static const optional = "optional";
  static const label = "label";
  static const defaultValue = "defaultValue";
  static const options = "options";
  static const id = "id";
  static const buttonText = "buttonText";
  static const disableAfterInteracted = "disableAfterInteracted";
  static const checked = "checked";
  static const value = "value";
  static const placeholder = "placeholder";
  static const maxLines = "maxLines";
  static const style = "style";
  static const answer = "answer";
  static const goalCompletionText = "goalCompletionText";
  static const response = "response";
  static const action = "action";
  static const customData = "customData";
  static const subType = "subType";
  static const imageUrl = "imageUrl";
  static const actions = "actions";

  static const scheduleElement = "scheduleElement";
  static const avatarUrl = "avatarUrl";
  static const timezoneCode = "timezoneCode";
  static const bufferTime = "bufferTime";
  static const duration = "duration";
  static const dateRangeStart = "dateRangeStart";
  static const dateRangeEnd = "dateRangeEnd";
  static const icsFileUrl = "icsFileUrl";
  static const availability = "availability";
  static const from = "from";
  static const to = "to";
  static const dateTimeFormat = "dateTimeFormat";
  static const mode = "mode";
}

class ActionElementFields {
  static const url = "url";
  static const method = "method";
  static const headers = "headers";
  static const dataKey = "dataKey";
  static const payload = "payload";
}

class CardMessageKeys {
  static const title = "title";
  static const text = "text";
  static const imageUrl = "imageUrl";
  static const cardActions = "cardActions";
}

class IDMapConstants {
  static const user = "user";
  static const group = "group";
  static const parentMessageId = "parentMessageId";
}

class SchedulerConstants {
  static const from = "from";
  static const to = "to";
  static const schedulerData = "schedulerData";
  static const meetStartAt = "meetStartAt";
  static const duration = "duration";
}

class InteractiveMessageConstants {
  static const appID = "appID";
  static const region = "region";
  static const trigger = "trigger";
  static const uiMessageInteracted = "ui_message_interacted";
  static const data = "data";
  static const conversationId = "conversationId";
  static const sender = "sender";
  static const receiver = "receiver";
  static const receiverType = "receiverType";
  static const messageCategory = "messageCategory";
  static const messageType = "messageType";
  static const messageId = "messageId";
  static const interactionTimezoneCode = "interactionTimezoneCode";
  static const interactedBy = "interactedBy";
  static const interactedElementId = "interactedElementId";
}

class ReactionConstants {
  static const reaction = "reaction";
  static const allReactions = "All";
}

class UpdateSettingsConstant {
  static const incrementUnreadCount = "incrementUnreadCount";
}

class ExtensionType {
  static const String extensionPoll = "extension_poll";
  static const String location = "location";
  static const String sticker = "extension_sticker";
  static const String document = "extension_document";
  static const String whiteboard = "extension_whiteboard";
}

class AudioBubbleConstants {
  static const String localPath = "localPath";
  static const String usedByMediaRecorder = 'usedByMediaRecorder';
}

class SetSourceConstant {
  static const String uiKitVersion = "uikit-v6";
  static const String platform = "flutter";

  /// Semantic version of the UIKit package.
  /// Must be kept in sync with pubspec.yaml version field.
  static const String version = "6.0.5";
}

class ErrorConstants {
  static const String fileErrorCodeAndroid = "ERR_BAD_REQUEST";
  static const String fileErrorCodeIOS = "ERROR_INVALID_FILE_SIZE";
}

class FileConstants {
  static const String fileExtensionHeic = "heic";
  static const String fileExtensionHeif = "heif";
  static const String fileExtensionMif1 = "mif1";
  static const String fileExtensionHeix = "heix";
  static const String fileExtensionHeim = "heim";
  static const String fileExtensionHeis = "heis";
  static const String fileExtensionHevm = "hevm";
  static const String fileExtensionHevs = "hevs";
}
