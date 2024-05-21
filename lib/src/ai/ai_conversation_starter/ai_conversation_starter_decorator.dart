import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[AIConversationStarterDecorator] is a the view model for [AIConversationStarterExtension] it contains all the relevant business logic
///it is also a sub-class of [DataSourceDecorator] which allows any extension to override the default methods provided by [MessagesDataSource]
class AIConversationStarterDecorator extends DataSourceDecorator
    with CometChatUIEventListener, CometChatMessageEventListener {
  late String dateStamp;
  late String _listenerId;
  User? loggedInUser;
  AIConversationStarterConfiguration? configuration;

  Map<String, dynamic> getMapForSentMessage(BaseMessage message) {
    String? uid;
    String? guid;
    if (message.receiverType == ReceiverTypeConstants.user) {
      uid = message.receiverUid;
    } else {
      guid = message.receiverUid;
    }
    Map<String, dynamic> idMap = UIEventUtils.createMap(uid, guid, 0);
    return idMap;
  }

  Map<String, dynamic> getMapForReceivedMessage(BaseMessage message) {
    String? uid;
    String? guid;
    if (message.receiverType == ReceiverTypeConstants.user) {
      uid = message.sender!.uid;
    } else {
      guid = message.receiverUid;
    }
    Map<String, dynamic> idMap = UIEventUtils.createMap(uid, guid, 0);
    return idMap;
  }

  @override
  void ccMessageSent(BaseMessage message, MessageStatus messageStatus) {
    Map<String, dynamic> idMap = getMapForSentMessage(message);
    hideSummaryPanel(idMap);
  }

  @override
  void onTextMessageReceived(TextMessage textMessage) {
    Map<String, dynamic> idMap = getMapForReceivedMessage(textMessage);
    hideSummaryPanel(idMap);
  }

  @override
  void onMediaMessageReceived(MediaMessage mediaMessage) {
    Map<String, dynamic> idMap = getMapForReceivedMessage(mediaMessage);
    hideSummaryPanel(idMap);
  }

  @override
  void onCustomMessageReceived(CustomMessage customMessage) {
    Map<String, dynamic> idMap = getMapForReceivedMessage(customMessage);
    hideSummaryPanel(idMap);
  }

  @override
  void onFormMessageReceived(FormMessage formMessage) {
    Map<String, dynamic> idMap = getMapForReceivedMessage(formMessage);
    hideSummaryPanel(idMap);
  }

  @override
  void onCardMessageReceived(CardMessage cardMessage) {
    Map<String, dynamic> idMap = getMapForReceivedMessage(cardMessage);
    hideSummaryPanel(idMap);
  }

  @override
  onSchedulerMessageReceived(SchedulerMessage schedulerMessage) {
    Map<String, dynamic> idMap = getMapForReceivedMessage(schedulerMessage);
    hideSummaryPanel(idMap);
  }

  AIConversationStarterDecorator(super.dataSource, {this.configuration}) {
    dateStamp = DateTime.now().microsecondsSinceEpoch.toString();
    _listenerId = "AiConversationStarter$dateStamp";
    CometChatUIEvents.removeUiListener(_listenerId);
    CometChatUIEvents.addUiListener(_listenerId, this);
    CometChatMessageEvents.removeMessagesListener(_listenerId);
    CometChatMessageEvents.addMessagesListener(_listenerId, this);
    getLoggedInUser();
  }

  getLoggedInUser() async {
    loggedInUser = await CometChat.getLoggedInUser();
  }

  closeCall() {
    CometChat.removeMessageListener(_listenerId);
    CometChatMessageEvents.removeMessagesListener(_listenerId);
  }

  hideSummaryPanel(Map<String, dynamic>? id) {
    CometChatUIEvents.hidePanel(id, CustomUIPosition.composerTop);
  }

  @override
  void ccActiveChatChanged(Map<String, dynamic>? id, BaseMessage? lastMessage,
      User? user, Group? group, int unreadMessageCount) {
    CometChatTheme theme = configuration?.theme ?? cometChatTheme;
    if (lastMessage == null && id?["parentMessageId"] == null) {
      onRepliesListBottom(user, group, theme);
      return;
    }
  }

  onRepliesListBottom(User? user, Group? group, CometChatTheme? theme) async {
    Map<String, dynamic>? apiMap;

    if (configuration != null && configuration?.apiConfiguration != null) {
      apiMap = await configuration?.apiConfiguration!(user, group);
    }

    Map<String, dynamic> id = {};
    String receiverId = "";
    if (user != null) {
      receiverId = user.uid;
      id['uid'] = receiverId;
    } else if (group != null) {
      receiverId = group.guid;
      id['guid'] = receiverId;
    }

    CometChatUIEvents.showPanel(
      id,
      CustomUIPosition.composerTop,
      (context) => AIConversationStarterView(
        aiConversationStarterStyle: configuration?.conversationStarterStyle,
        theme: configuration?.theme ?? theme ?? cometChatTheme,
        user: user,
        group: group,
        emptyStateText: configuration?.emptyStateText,
        errorStateText: configuration?.errorStateText,
        customView: configuration?.customView,
        loadingStateText: configuration?.loadingStateText,
        emptyIconUrl: configuration?.emptyIconUrl,
        loadingStateView: configuration?.loadingStateView,
        loadingIconUrl: configuration?.loadingIconUrl,
        errorStateView: configuration?.errorStateView,
        emptyStateView: configuration?.errorStateView,
        errorIconUrl: configuration?.errorIconUrl,
        apiConfiguration: apiMap,
      ),
    );
  }

  @override
  String getId() {
    return "conversationStarter";
  }
}
