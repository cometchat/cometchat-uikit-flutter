import 'package:flutter/material.dart';

import '../../../flutter_chat_ui_kit.dart';

class CometChatConversations extends StatefulWidget {
  const CometChatConversations(
      {Key? key,
      this.title,
      this.activeConversation,
      this.conversationType = ConversationTypes.both,
      this.style = const ConversationStyle(),
      this.showBackButton = false,
      this.backButton,
      this.hideStartConversation = false,
      this.startConversationIcon,
      this.hideSearch = false,
      this.search,
      this.theme,
      this.avatarConfiguration,
      this.statusIndicatorConfiguration,
      this.conversationListConfiguration =
          const ConversationListConfigurations(),
      this.badgeCountConfiguration,
      this.conversationListItemConfiguration,
      this.dateConfiguration,
      this.messageReceiptConfiguration,
      this.stateCallBack})
      : super(key: key);

  ///[title] title text
  final String? title;

  ///[activeConversation] active conversation
  final String? activeConversation;

  ///[conversationType] conversation type user/group/both
  final ConversationTypes conversationType;

  final ConversationStyle style;

  ///[showBackButton] show back button on true
  final bool? showBackButton;

  ///[backButton] icon for back button
  final Widget? backButton;

  ///[hideStartConversation] if true then hides start conversation icon
  final bool? hideStartConversation;

  ///[startConversationIcon] start conversation icon
  final Icon? startConversationIcon;

  ///[hideSearch] if true then hides search box
  final bool? hideSearch;

  ///[search] search box
  final Widget? search;

  ///[theme] can pass custom theme class or dark theme defaultDarkTheme object from CometChatTheme class, by default light theme
  final CometChatTheme? theme;

  ///[avatarConfigurations]
  final AvatarConfiguration? avatarConfiguration;

  ///[statusIndicatorConfiguration]
  final StatusIndicatorConfiguration? statusIndicatorConfiguration;

  ///[badgeCountConfiguration]
  final BadgeCountConfiguration? badgeCountConfiguration;

  ///[conversationListItemConfigurations]
  final ConversationListItemConfigurations? conversationListItemConfiguration;

  ///[dateConfiguration]
  final DateConfiguration? dateConfiguration;

  ///[messageReceiptConfiguration]
  final MessageReceiptConfiguration? messageReceiptConfiguration;

  ///[conversationListConfigurations]
  final ConversationListConfigurations conversationListConfiguration;

  ///[stateCallBack]
  final Function(CometChatConversationsState)? stateCallBack;

  @override
  State<CometChatConversations> createState() => CometChatConversationsState();
}

class CometChatConversationsState extends State<CometChatConversations>
    with CometChatMessageEventListener {
  CometChatConversationListState? conversationListState;

  conversationListStateCallBack(
      CometChatConversationListState _conversationListState) {
    conversationListState = _conversationListState;
  }

  @override
  void onMessageRead(BaseMessage message) {
    conversationListState?.resetUnreadCount(message);
  }

  @override
  void onMessageSent(BaseMessage message, MessageStatus messageStatus) {
    if (messageStatus == MessageStatus.sent) {
      conversationListState?.updateLastMessage(message);
    }
  }

  @override
  void onMessageEdit(BaseMessage message, MessageEditStatus status) {
    if (status == MessageEditStatus.success) {
      conversationListState?.updateLastMessageOnEdited(message);
    }
  }

  @override
  void onMessageDeleted(BaseMessage message) {
    conversationListState?.updateLastMessageOnEdited(message);
  }

  @override
  void initState() {
    super.initState();
    if (widget.stateCallBack != null) {
      widget.stateCallBack!(this);
    }

    CometChatMessageEvents.addMessagesListener(
        "cometchat_message_listener_conversation", this);
  }

  @override
  void dispose() {
    CometChatMessageEvents.removeMessagesListener(
        "cometchat_message_listener_conversation");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    CometChatTheme _theme = widget.theme ?? cometChatTheme;
    return CometChatListBase(
      title: widget.title ?? Translations.of(context).chats,
      style: ListBaseStyle(
        titleStyle: widget.style.titleStyle,
        background: widget.style.gradient == null
            ? widget.style.background
            : Colors.transparent,
        gradient: widget.style.gradient,
      ),
      hideSearch: true,
      showBackButton: widget.showBackButton,
      backIcon: widget.backButton,
      theme: widget.theme,
      menuOptions: [
        if (widget.hideStartConversation == false)
          IconButton(
            onPressed: () {},
            icon: widget.startConversationIcon ??
                Image.asset(
                  "assets/icons/write.png",
                  package: UIConstants.packageName,
                  color: _theme.palette.getPrimary(),
                ),
          )
      ],
      container: CometChatConversationList(
        //-----conversation list configurations-----
        limit: widget.conversationListConfiguration.limit,
        userAndGroupTags: widget.conversationListConfiguration.userAndGroupTags,
        customView: widget.conversationListConfiguration.customView ??
            const CustomView(),
        hideError: widget.conversationListConfiguration.hideError ?? false,
        tags: widget.conversationListConfiguration.tags,
        // onErrorCallBack: widget.conversationListConfiguration.onErrorCallBack,
        conversationType: widget.conversationType,
        theme: _theme,
        avatarConfiguration: widget.avatarConfiguration,
        statusIndicatorConfiguration: widget.statusIndicatorConfiguration,
        badgeCountConfiguration: widget.badgeCountConfiguration,
        dateConfiguration: widget.dateConfiguration,
        messageReceiptConfiguration: widget.messageReceiptConfiguration,
        conversationListItemConfiguration:
            widget.conversationListItemConfiguration,
        stateCallBack: conversationListStateCallBack,
        style: ListStyle(
            background: widget.style.gradient != null
                ? Colors.transparent
                : widget.style.background),
      ),
    );
  }
}

class ConversationStyle {
  const ConversationStyle(
      {this.width,
      this.height,
      this.background,
      this.border,
      this.cornerRadius,
      this.titleStyle,
      this.gradient});

  ///[width] width
  final double? width;

  ///[height] height
  final double? height;

  ///[background] background color
  final Color? background;

  ///[border] border
  final BoxBorder? border;

  ///[cornerRadius] corner radius for list
  final double? cornerRadius;

  ///[titleStyle] TextStyle for title
  final TextStyle? titleStyle;

  ///[gradient]
  final Gradient? gradient;
}
