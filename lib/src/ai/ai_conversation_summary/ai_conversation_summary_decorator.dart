import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

///[AIConversationSummaryDecorator] is a the view model for [AIConversationSummaryExtension] it contains all the relevant business logic
///it is also a sub-class of [DataSourceDecorator] which allows any extension to override the default methods provided by [MessagesDataSource]
class AIConversationSummaryDecorator extends DataSourceDecorator
    with CometChatUIEventListener, CometChatMessageEventListener {
  late String dateStamp;
  late String _listenerId;
  User? loggedInUser;
  AIConversationSummaryConfiguration? configuration;
  final defaultUnreadMessageCount = 30;

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
  void onCustomInteractiveMessageReceived(
      CustomInteractiveMessage customInteractiveMessage) {
    Map<String, dynamic> idMap =
        getMapForReceivedMessage(customInteractiveMessage);
    hideSummaryPanel(idMap);
  }

  @override
  onSchedulerMessageReceived(SchedulerMessage schedulerMessage) {
    Map<String, dynamic> idMap = getMapForReceivedMessage(schedulerMessage);
    hideSummaryPanel(idMap);
  }

  AIConversationSummaryDecorator(super.dataSource, {this.configuration}) {
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
  List<CometChatMessageComposerAction> getAIOptions(
      User? user,
      Group? group,
      CometChatTheme theme,
      BuildContext context,
      Map<String, dynamic>? id,
      AIOptionsStyle? aiOptionStyle) {
    List<CometChatMessageComposerAction> actionList =
        super.getAIOptions(user, group, theme, context, id, aiOptionStyle);

    if (id?["parentMessageId"] == null || id?["parentMessageId"] == 0) {
      CometChatMessageComposerAction summaryAction =
          CometChatMessageComposerAction(
              title: "Summary",
              id: getId(),
              iconUrl: AssetConstants.repliesError,
              onItemClick: (BuildContext context, User? user, Group? group) {
                if (id?["parentMessageId"] == null ||
                    id?["parentMessageId"] == 0) {
                  showSummary(id, user, group, theme);
                }
              });

      actionList.add(summaryAction);
    }

    return actionList;
  }

  @override
  void ccActiveChatChanged(Map<String, dynamic>? id, BaseMessage? lastMessage,
      User? user, Group? group, int unreadMessageCount) {
    CometChatTheme theme = configuration?.theme ?? cometChatTheme;
    int unreadMessageCountThreshold =
        configuration?.unreadMessageThreshold ?? defaultUnreadMessageCount;

    if (id?["parentMessageId"] == null &&
        unreadMessageCount >= unreadMessageCountThreshold) {
      showSummary(id, user, group, theme);
    }
  }

  showSummary(Map<String, dynamic>? id, User? user, Group? group,
      CometChatTheme? theme) async {
    Map<String, dynamic>? config;

    if (configuration?.apiConfiguration != null) {
      config = await configuration!.apiConfiguration!(user, group);
    }

    CometChatUIEvents.showPanel(
        id,
        CustomUIPosition.composerTop,
        (context) => AIConversationSummaryView(
              group: group,
              user: user,
              loadingStateText: configuration?.loadingStateText,
              emptyIconUrl: configuration?.emptyIconUrl,
              loadingStateView: configuration?.loadingStateView,
              loadingIconUrl: configuration?.loadingIconUrl,
              errorStateView: configuration?.errorStateView,
              emptyStateView: configuration?.errorStateView,
              errorIconUrl: configuration?.errorIconUrl,
              customView: configuration?.customView,
              aiConversationSummaryStyle:
                  configuration?.conversationSummaryStyle,
              title: configuration?.title,
              onCloseIconTap: configuration?.onCloseIconTap,
              theme: configuration?.theme ?? theme ?? cometChatTheme,
              apiConfiguration: config,
              emptyIconPackageName: configuration?.emptyIconPackageName,
              errorIconPackageName: configuration?.errorIconPackageName,
              loadingIconPackageName: configuration?.loadingIconPackageName,
              emptyStateText: configuration?.emptyStateText,
              errorStateText: configuration?.errorStateText,
            ));
  }

  @override
  String getId() {
    return "conversationSummary";
  }
}
