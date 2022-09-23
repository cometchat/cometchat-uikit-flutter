import 'package:flutter/material.dart';
import '../../../../flutter_chat_ui_kit.dart';
import 'package:cometchat/models/action.dart' as action;

import '../../utils/right_swipe_menu.dart';

/// Creates a widget that that gives CometChat Conversation List Item
class CometChatConversationListItem extends StatelessWidget {
  const CometChatConversationListItem(
      {Key? key,
      this.inputData = const ConversationInputData(),
      this.style,
      required this.showTypingIndicator,
      this.typingIndicatorText,
      this.hideThreadIndicator = true,
      this.threadIndicatorText,
      this.hideReceipt,
      this.isActive,
      this.conversationOptions,
      required this.onTap,
      this.toggleIndicator,
      this.avatarConfiguration = const AvatarConfiguration(),
      this.badgeCountConfiguration = const BadgeCountConfiguration(),
      this.statusIndicatorConfiguration = const StatusIndicatorConfiguration(),
      this.dateConfiguration = const DateConfiguration(),
      this.messageReceiptConfiguration = const MessageReceiptConfiguration(),
      required this.conversation,
      this.theme,
      this.onLongPress})
      : super(key: key);

  ///[inputData]
  final ConversationInputData inputData;

  ///[style] style object for ListItem
  final ConversationListItemStyle? style;

  ///[showTypingIndicator] set true to show typing indicator
  final bool showTypingIndicator;

  ///[typingIndicatorText] typing indicator text
  final String? typingIndicatorText;

  ///[hideThreadIndicator] set true to hide thread indicator for group conversation
  final bool? hideThreadIndicator;

  ///[threadIndicatorText] thread indicator text
  final String? threadIndicatorText;

  ///[hideReceipt]
  final bool? hideReceipt;

  ///[isActive] set user isActive or not
  final bool? isActive;

  final CometChatMenuList? conversationOptions;

  ///[onTap] ListItem onTap function
  final Function() onTap;

  ///[onLongPress] ListItem onLongPress function
  final Function()? onLongPress;

  ///[toggleIndicator]
  final VoidCallback? toggleIndicator;

  ///[avatarConfigurations]
  final AvatarConfiguration avatarConfiguration;

  ///[statusIndicatorConfiguration]
  final StatusIndicatorConfiguration statusIndicatorConfiguration;

  ///[badgeCountConfiguration]
  final BadgeCountConfiguration badgeCountConfiguration;

  ///[dateConfiguration]
  final DateConfiguration dateConfiguration;

  ///[messageReceiptConfiguration]
  final MessageReceiptConfiguration messageReceiptConfiguration;

  ///[Conversation]
  final Conversation conversation;

  ///[theme] can pass custom theme class or dark theme defaultDarkTheme object from CometChatTheme class, by default light theme
  final CometChatTheme? theme;

  Widget getAvatar(CometChatTheme _theme) {
    if (inputData.thumbnail == true) {
      String _name;
      String? _image;

      if (conversation.conversationWith is User) {
        final _user = conversation.conversationWith as User;
        _image = _user.avatar;
        _name = _user.name;
      }
      //----------- group conversation -----------
      else {
        final _group = conversation.conversationWith as Group;
        _image = _group.icon;
        _name = _group.name;
      }

      return CometChatAvatar(
        image: inputData.thumbnail == true ? _image : '',
        name: _name,
        width: avatarConfiguration.width,
        height: avatarConfiguration.height,
        backgroundColor: avatarConfiguration.backgroundColor ??
            _theme.palette.getAccent700(),
        cornerRadius: avatarConfiguration.cornerRadius,
        outerCornerRadius: avatarConfiguration.outerCornerRadius,
        border: avatarConfiguration.border,
        outerViewBackgroundColor: avatarConfiguration.outerViewBackgroundColor,
        nameTextStyle: avatarConfiguration.nameTextStyle ??
            TextStyle(
                color: _theme.palette.getBackground(),
                fontSize: _theme.typography.name.fontSize,
                fontWeight: _theme.typography.name.fontWeight,
                fontFamily: _theme.typography.name.fontFamily),
        outerViewBorder: avatarConfiguration.outerViewBorder,
        outerViewSpacing: avatarConfiguration.outerViewSpacing,
        outerViewWidth: avatarConfiguration.outerViewWidth,
      );
    } else {
      return const SizedBox();
    }
  }

  Widget getStatus(CometChatTheme _theme) {
    if (inputData.status == false) {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    } else if (conversation.conversationType == ReceiverTypeConstants.user) {
      return CometChatStatusIndicator(
        backgroundColor: (conversation.conversationWith as User).status ==
                UserStatusConstants.online
            ? _theme.palette.getSuccess()
            : null,
        border: statusIndicatorConfiguration.border,
        cornerRadius: statusIndicatorConfiguration.cornerRadius,
        height: statusIndicatorConfiguration.height,
        width: statusIndicatorConfiguration.width,
      );
    } else {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }
  }

  Widget getTime(CometChatTheme _theme) {
    if (inputData.timestamp == false) {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    } else {
      DateTime? lastMessageTime = conversation.lastMessage?.updatedAt ??
          conversation.lastMessage?.sentAt;
      if (lastMessageTime == null) return const SizedBox();
      DateTime now = DateTime.now();

      return CometChatDate(
        date: lastMessageTime,
        contentPadding: dateConfiguration.contentPadding,
        isTransparentBackground: dateConfiguration.isTransparentBackground,
        cornerRadius: dateConfiguration.cornerRadius,
        borderColor:
            dateConfiguration.borderColor ?? _theme.palette.getBackground(),
        backgroundColor:
            dateConfiguration.backgroundColor ?? _theme.palette.getBackground(),
        textStyle: dateConfiguration.textStyle ??
            TextStyle(
                color: _theme.palette.getAccent500(),
                fontSize: _theme.typography.subtitle1.fontSize,
                fontWeight: _theme.typography.subtitle1.fontWeight,
                fontFamily: _theme.typography.subtitle1.fontFamily),
        borderWidth: dateConfiguration.borderWidth ?? 0,
        pattern: dateConfiguration.pattern ?? DateTimePattern.dayDateTimeFormat,
        dateFormat: dateConfiguration.dateFormat,
        timeFormat: dateConfiguration.timeFormat,
      );
    }
  }

  Widget getTitle(ConversationListItemStyle _style, CometChatTheme _theme) {
    if (inputData.title == false) {
      return Container();
    } else {
      String _name;
      if (conversation.conversationWith is User) {
        final _user = conversation.conversationWith as User;
        _name = _user.name;
      } else {
        final _group = conversation.conversationWith as Group;
        _name = _group.name;
      }

      return Text(
        _name,
        style: _style.titleStyle ??
            TextStyle(
                color: _theme.palette.getAccent(),
                fontWeight: _theme.typography.name.fontWeight,
                fontSize: _theme.typography.name.fontSize,
                fontFamily: _theme.typography.name.fontFamily),
      );
    }
  }

  Widget getUnreadCount(CometChatTheme _theme) {
    if (inputData.unreadCount == false) {
      return const SizedBox();
    } else {
      return CometChatBadgeCount(
        count: conversation.unreadMessageCount ?? 0,
        width: badgeCountConfiguration.width ?? 25,
        height: badgeCountConfiguration.height ?? 25,
        cornerRadius: badgeCountConfiguration.cornerRadius ?? 100,
        textStyle: badgeCountConfiguration.textStyle ??
            TextStyle(
                fontSize: _theme.typography.subtitle1.fontSize,
                color: _theme.palette.getAccent()),
        background:
            badgeCountConfiguration.background ?? _theme.palette.getPrimary(),
        borderColor: badgeCountConfiguration.borderColor,
        borderWidth: badgeCountConfiguration.borderWidth,
      );
    }
  }

  //----------- get last message text-----------
  String getLastMessage(BaseMessage? message, BuildContext context) {
    if (message == null) return '';
    if (message.deletedBy != null && message.deletedBy!.trim() != '') {
      return Translations.of(context).this_message_deleted;
    }
    if (message.type == MessageTypeConstants.text) {
      return (message as TextMessage).text;
    } else if (message.type == "groupMember") {
      action.Action actionMessage = message as action.Action;
      return actionMessage.message;
    } else {
      return TemplateUtils.getMessageTypeToSubtitle(message.type, context);
    }
  }

  Widget getSubtitle(ConversationListItemStyle _style, CometChatTheme _theme,
      BuildContext context) {
    TextStyle _subtitleStyle = _style.subtitleStyle ??
        TextStyle(
            color: _theme.palette.getAccent600(),
            fontSize: _theme.typography.subtitle1.fontSize,
            fontWeight: _theme.typography.subtitle1.fontWeight,
            fontFamily: _theme.typography.subtitle1.fontFamily);

    String? _text;
    if (inputData.subtitle != null) {
      if (conversation.lastMessage != null) {
        _text = inputData.subtitle!(conversation);
      } else {
        //print("Returning from else");
        _text = '';
      }
    } else {
      _text = getLastMessage(conversation.lastMessage, context);
    }

    if (_text != null) {
      return Text(
        _text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _subtitleStyle,
      );
    } else {
      return Container();
    }
  }

  Widget getReceiptIcon(CometChatTheme _theme) {
    if (hideReceipt ?? false) {
      return const SizedBox();
    } else if (conversation.lastMessage != null &&
        conversation.lastMessage?.sender != null &&
        conversation.lastMessage!.deletedBy == null &&
        conversation.lastMessage!.type != "groupMember") {
      return Padding(
        padding: const EdgeInsets.only(right: 5.0),
        child: CometChatMessageReceipt(
          message: conversation.lastMessage!,
          deliveredIcon: messageReceiptConfiguration.deliveredIcon ??
              Image.asset(
                "assets/icons/message_received.png",
                package: UIConstants.packageName,
                color: _theme.palette.getAccent(),
              ),
          errorIcon: messageReceiptConfiguration.errorIcon,
          readIcon: messageReceiptConfiguration.readIcon,
          sentIcon: messageReceiptConfiguration.sentIcon ??
              Image.asset(
                "assets/icons/message_sent.png",
                package: UIConstants.packageName,
                color: _theme.palette.getAccent(),
              ),
          waitIcon: messageReceiptConfiguration.waitIcon,
        ),
      );
    } else {
      return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    ConversationListItemStyle _style =
        style ?? const ConversationListItemStyle();
    CometChatTheme _theme = theme ?? cometChatTheme;

    //-------------------------------

    return SwipeMenu(
      key: UniqueKey(),
      //-----------right swipe menu options-----------
      menuItems: conversationOptions,

      child: Container(
        height: _style.height ?? 72,
        width: _style.width ?? MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
            color: _style.background ?? _theme.palette.getBackground(),
            border: _style.border,
            borderRadius: BorderRadius.circular(_style.cornerRadius ?? 0),
            gradient: _style.gradient),
        child: ListTile(
          contentPadding: const EdgeInsets.all(0),

          //-----------on tap list item callback function-----------
          onTap: onTap,

          onLongPress: onLongPress,

          //----------- avatar with status -----------
          leading: inputData.thumbnail != false
              ? Stack(
                  children: [
                    getAvatar(_theme),
                    Positioned(
                      height: 12,
                      width: 12,
                      right: 1,
                      bottom: 1,
                      child: getStatus(_theme),
                    )
                  ],
                )
              : null,

          //-----------name of user/group -----------
          title: getTitle(_style, _theme),

          //-----------subtitle is typing/ last message -----------
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hideThreadIndicator != null && hideThreadIndicator == false)
                Text(
                  Translations.of(context).in_a_thread,
                  style: _style.threadIndicator ??
                      TextStyle(
                          color: _theme.palette.getPrimary(),
                          fontWeight: _theme.typography.subtitle1.fontWeight,
                          fontSize: _theme.typography.subtitle1.fontSize,
                          fontFamily: _theme.typography.subtitle1.fontFamily),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  getReceiptIcon(_theme),
                  if (showTypingIndicator)
                    Text(
                      typingIndicatorText ?? Translations.of(context).is_typing,
                      style: _style.typingIndicator ??
                          TextStyle(
                              color: _theme.palette.getPrimary(),
                              fontWeight:
                                  _theme.typography.subtitle1.fontWeight,
                              fontSize: _theme.typography.subtitle1.fontSize,
                              fontFamily:
                                  _theme.typography.subtitle1.fontFamily),
                    )
                  else
                    Expanded(child: getSubtitle(_style, _theme, context))
                ],
              ),
            ],
          ),

          //----------- last message update time and unread message count -----------
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              getTime(_theme),
              getUnreadCount(_theme),
            ],
          ),
        ),
      ),
    );
  }
}

class ConversationListItemStyle {
  ///class for the List Item style
  const ConversationListItemStyle(
      {this.height,
      this.width,
      this.background,
      this.border,
      this.cornerRadius,
      this.titleStyle,
      this.subtitleStyle,
      this.typingIndicator,
      this.threadIndicator,
      this.gradient});

  ///[height] height of list item
  final double? height;

  ///[width] width of list item
  final double? width;

  ///[background] background color of list item
  final Color? background;

  ///[border] border of list item
  final BoxBorder? border;

  ///[cornerRadius] radius
  final double? cornerRadius;

  ///[titleStyle] TextStyle for List item title
  final TextStyle? titleStyle;

  ///[subtitleStyle] subtitle TextStyle
  final TextStyle? subtitleStyle;

  ///[typingIndicator] typing indicator widget shown on user is typing
  final TextStyle? typingIndicator;

  ///[threadIndicator] thread indicator shown if message is in thread in group
  final TextStyle? threadIndicator;

  final Gradient? gradient;
}
