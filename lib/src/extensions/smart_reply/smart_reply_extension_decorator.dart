import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class SmartReplyExtensionDecorator extends DataSourceDecorator
    with MessageListener, CometChatUIEventListener {
  late String dateStamp;
  late String _listenerId;
  User? loggedInUser;
  SmartReplyConfiguration? configuration;

  SmartReplyExtensionDecorator(DataSource dataSource, {this.configuration})
      : super(dataSource) {
    dateStamp = DateTime.now().microsecondsSinceEpoch.toString();
    _listenerId = "ExtensionSmartReplyListener";
    CometChat.removeMessageListener(_listenerId);
    CometChatUIEvents.removeUiListener(_listenerId);
    CometChat.addMessageListener(_listenerId, this);
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
    List<String> _replies = [];
    Map<String, dynamic>? map = ExtensionModerator.extensionCheck(message);
    if (map != null && map.containsKey(ExtensionConstants.smartReply)) {
      Map<String, dynamic> smartReplies = map[ExtensionConstants.smartReply];
      if (smartReplies.containsKey("reply_neutral")) {
        _replies.add(smartReplies["reply_neutral"]);
      }
      if (smartReplies.containsKey("reply_negative")) {
        _replies.add(smartReplies["reply_negative"]);
      }
      if (smartReplies.containsKey("reply_positive")) {
        _replies.add(smartReplies["reply_positive"]);
      }
    }
    return _replies;
  }

  @override
  void onConversationChanged(Map<String, dynamic>? id, BaseMessage? lastMessage,
      User? user, Group? group) {
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

  checkAndShowReplies(TextMessage textMessage) {
    List<String> _replies = getReplies(textMessage);

    if (_replies.isEmpty) return;

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
      CometChatUIEvents.hidePanel(id, alignment.composerTop);
    }

    onCLick(String reply) {
      CometChatUIEvents.hidePanel(id, alignment.composerTop);

      String _receiverUid;
      if (textMessage.receiverType == CometChatReceiverType.user) {
        _receiverUid = (textMessage.sender!.uid);
      } else {
        _receiverUid = (textMessage.receiver as Group).guid;
      }

      TextMessage sendingMessage = TextMessage(
          text: reply,
          receiverUid: _receiverUid,
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
        alignment.composerTop,
        (context) => SmartReplyView(
              onCloseTap: onCloseTap,
              replies: _replies,
              onClick: onCLick,
            ));
  }

  @override
  String getId() {
    return "smartreply";
  }
}
