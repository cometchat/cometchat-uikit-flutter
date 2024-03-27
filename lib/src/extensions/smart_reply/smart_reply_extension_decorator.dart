import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[SmartReplyExtensionDecorator] is a the view model for [SmartReplyExtension] it contains all the relevant business logic
///it is also a sub-class of [DataSourceDecorator] which allows any extension to override the default methods provided by [MessagesDataSource]
class SmartReplyExtensionDecorator extends DataSourceDecorator
    with CometChatMessageEventListener, CometChatUIEventListener {
  late String dateStamp;
  late String _listenerId;
  User? loggedInUser;
  SmartReplyConfiguration? configuration;

  SmartReplyExtensionDecorator(DataSource dataSource, {this.configuration})
      : super(dataSource) {
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
      User? user, Group? group, int unreadMessageCount ) {
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
  void onSchedulerMessageReceived(SchedulerMessage schedulerMessage) {
    Map<String, dynamic> id = {};

    if (schedulerMessage.receiver is User) {
      id['uid'] = (schedulerMessage.sender as User).uid;
    } else if (schedulerMessage.receiver is Group) {
      id['guid'] = (schedulerMessage.receiver as Group).guid;
    }

    if (schedulerMessage.parentMessageId != 0) {
      id['parentMessageId'] = schedulerMessage.parentMessageId;
    }
    CometChatUIEvents.hidePanel(id, CustomUIPosition.messageListBottom);
  }

  checkAndShowReplies(TextMessage textMessage) {
    List<String> replies = getReplies(textMessage);

    if (replies.isEmpty) return;

    Map<String, dynamic> id = {};

    if (textMessage.receiver is User) {
      id['uid'] = (textMessage.sender as User).uid;
    } else if (textMessage.receiver is Group) {
      id['guid'] = (textMessage.receiver as Group).guid;
    }

    if (textMessage.parentMessageId != 0) {
      id['parentMessageId'] = textMessage.parentMessageId;
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
