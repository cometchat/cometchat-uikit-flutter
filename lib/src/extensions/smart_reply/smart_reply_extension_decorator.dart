import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[SmartReplyExtensionDecorator] is a the view model for [SmartReplyExtension] it contains all the relevant business logic
///it is also a sub-class of [DataSourceDecorator] which allows any extension to override the default methods provided by [MessagesDataSource]
class SmartReplyExtensionDecorator extends DataSourceDecorator
    with CometChatMessageEventListener, CometChatUIEventListener {
  late String dateStamp;
  late String _listenerId;
  User? loggedInUser;
  SmartReplyConfiguration? configuration;

  SmartReplyExtensionDecorator(super.dataSource, {this.configuration}) {
    dateStamp = DateTime.now().microsecondsSinceEpoch.toString();
    _listenerId = "ExtensionSmartReplyListener";
    CometChatMessageEvents.removeMessagesListener(_listenerId);
    CometChatUIEvents.removeUiListener(_listenerId);
    CometChatMessageEvents.addMessagesListener(_listenerId, this);
    CometChatUIEvents.addUiListener(_listenerId, this);
    getLoggedInUser();
  }

  getLoggedInUser() async {
    loggedInUser = await CometChat.getLoggedInUser();
  }

  closeCall() {
    CometChat.removeMessageListener(_listenerId);
  }

  List<String> getReplies(BaseMessage message) {
    List<String> replies = [];
    Map<String, dynamic>? map = ExtensionModerator.extensionCheck(message);
    if (map != null && map.containsKey(ExtensionConstants.smartReply)) {
      Map<String, dynamic> smartReplies = map[ExtensionConstants.smartReply];
      if (smartReplies.containsKey("reply_neutral")) {
        replies.add(smartReplies["reply_neutral"]);
      }
      if (smartReplies.containsKey("reply_negative")) {
        replies.add(smartReplies["reply_negative"]);
      }
      if (smartReplies.containsKey("reply_positive")) {
        replies.add(smartReplies["reply_positive"]);
      }
    }
    return replies;
  }

  @override
  void ccActiveChatChanged(Map<String, dynamic>? id, BaseMessage? lastMessage,
      User? user, Group? group, int unreadMessageCount) {
    if (lastMessage != null &&
        lastMessage is TextMessage &&
        lastMessage.sender?.uid != loggedInUser?.uid) {
      checkAndShowReplies(lastMessage);
    }
  }

  @override
  void onTextMessageReceived(TextMessage textMessage) async {
    checkAndShowReplies(textMessage);
  }

  @override
  void onMediaMessageReceived(MediaMessage mediaMessage) {
    String? uid;
    String? guid;
    if (mediaMessage.receiverType == ReceiverTypeConstants.user) {
      uid = (mediaMessage.sender as User).uid;
    } else {
      guid = (mediaMessage.receiver as Group).guid;
    }
    Map<String, dynamic> id =
        UIEventUtils.createMap(uid, guid, mediaMessage.parentMessageId);

    CometChatUIEvents.hidePanel(id, CustomUIPosition.messageListBottom);
  }

  @override
  void onCustomMessageReceived(CustomMessage customMessage) {
    String? uid;
    String? guid;
    if (customMessage.receiverType == ReceiverTypeConstants.user) {
      uid = (customMessage.sender as User).uid;
    } else {
      guid = (customMessage.receiver as Group).guid;
    }
    Map<String, dynamic> id =
        UIEventUtils.createMap(uid, guid, customMessage.parentMessageId);

    CometChatUIEvents.hidePanel(id, CustomUIPosition.messageListBottom);
  }

  @override
  void ccMessageSent(BaseMessage message, MessageStatus messageStatus) {
    String? uid;
    String? guid;
    if (message.receiverType == ReceiverTypeConstants.user) {
      uid = message.receiverUid;
    } else {
      guid = message.receiverUid;
    }
    Map<String, dynamic> id =
        UIEventUtils.createMap(uid, guid, message.parentMessageId);

    CometChatUIEvents.hidePanel(id, CustomUIPosition.messageListBottom);
  }

  @override
  void onSchedulerMessageReceived(SchedulerMessage schedulerMessage) {
    String? uid;
    String? guid;
    if (schedulerMessage.receiverType == ReceiverTypeConstants.user) {
      uid = (schedulerMessage.sender as User).uid;
    } else {
      guid = (schedulerMessage.receiver as Group).guid;
    }
    Map<String, dynamic> id =
        UIEventUtils.createMap(uid, guid, schedulerMessage.parentMessageId);

    CometChatUIEvents.hidePanel(id, CustomUIPosition.messageListBottom);
  }

  @override
  void onFormMessageReceived(FormMessage formMessage) {
    String? uid;
    String? guid;
    if (formMessage.receiverType == ReceiverTypeConstants.user) {
      uid = (formMessage.sender as User).uid;
    } else {
      guid = (formMessage.receiver as Group).guid;
    }
    Map<String, dynamic> id =
        UIEventUtils.createMap(uid, guid, formMessage.parentMessageId);

    CometChatUIEvents.hidePanel(id, CustomUIPosition.messageListBottom);
  }

  @override
  void onCardMessageReceived(CardMessage cardMessage) {
    String? uid;
    String? guid;
    if (cardMessage.receiverType == ReceiverTypeConstants.user) {
      uid = (cardMessage.sender as User).uid;
    } else {
      guid = (cardMessage.receiver as Group).guid;
    }
    Map<String, dynamic> id =
        UIEventUtils.createMap(uid, guid, cardMessage.parentMessageId);

    CometChatUIEvents.hidePanel(id, CustomUIPosition.messageListBottom);
  }

  @override
  void onCustomInteractiveMessageReceived(
      CustomInteractiveMessage customInteractiveMessage) {
    String? uid;
    String? guid;
    if (customInteractiveMessage.receiverType == ReceiverTypeConstants.user) {
      uid = (customInteractiveMessage.sender as User).uid;
    } else {
      guid = (customInteractiveMessage.receiver as Group).guid;
    }
    Map<String, dynamic> id = UIEventUtils.createMap(
        uid, guid, customInteractiveMessage.parentMessageId);

    CometChatUIEvents.hidePanel(id, CustomUIPosition.messageListBottom);
  }

  checkAndShowReplies(TextMessage textMessage) {
    List<String> replies = getReplies(textMessage);

    String? uid;
    String? guid;
    if (textMessage.receiver is User) {
      uid = (textMessage.sender as User).uid;
    } else {
      guid = (textMessage.receiver as Group).guid;
    }

    Map<String, dynamic> id =
        UIEventUtils.createMap(uid, guid, textMessage.parentMessageId);

    if (replies.isEmpty) {
      CometChatUIEvents.hidePanel(id, CustomUIPosition.messageListBottom);
      return;
    }

    onCloseTap() {
      CometChatUIEvents.hidePanel(id, CustomUIPosition.messageListBottom);
    }

    onCLick(String reply) {
      CometChatUIEvents.hidePanel(id, CustomUIPosition.messageListBottom);

      String receiverUid;
      if (textMessage.receiverType == CometChatReceiverType.user) {
        receiverUid = (textMessage.sender!.uid);
      } else {
        receiverUid = (textMessage.receiver as Group).guid;
      }

      TextMessage sendingMessage = TextMessage(
          text: reply,
          receiverUid: receiverUid,
          type: CometChatMessageType.text,
          receiverType: textMessage.receiverType,
          sender: loggedInUser,
          parentMessageId: textMessage.parentMessageId,
          muid: DateTime.now().microsecondsSinceEpoch.toString(),
          category: CometChatMessageCategory.message);

      CometChatUIKit.sendTextMessage(sendingMessage);
    }

    CometChatUIEvents.showPanel(
        id,
        CustomUIPosition.messageListBottom,
        (context) => SmartReplyView(
              onCloseTap: onCloseTap,
              replies: replies,
              onClick: onCLick,
            ));
  }

  @override
  String getId() {
    return "smartreply";
  }
}
