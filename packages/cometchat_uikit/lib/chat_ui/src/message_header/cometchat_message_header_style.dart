import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CometChatMessageHeaderStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatMessageHeader]
class CometChatMessageHeaderStyle
    extends ThemeExtension<CometChatMessageHeaderStyle> {
  ///message header style components
  const CometChatMessageHeaderStyle({
    this.onlineStatusColor,
    this.subtitleTextStyle,
    this.typingIndicatorTextStyle,
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.titleTextStyle,
    this.titleTextColor,
    this.subtitleTextColor,
    this.backIconColor,
    this.backIcon,
    this.privateGroupBadgeIcon,
    this.passwordProtectedGroupBadgeIcon,
    this.privateGroupBadgeIconColor,
    this.passwordProtectedGroupBadgeIconColor,
    this.groupIconBackgroundColor,
    this.avatarStyle,
    this.callButtonsStyle,
    this.statusIndicatorStyle,
    this.newChatIconColor,
    this.chatHistoryIconColor,
    this.menuIconColor,
  });

  ///[typingIndicatorTextStyle] is text style for setting typing indicator text
  final TextStyle? typingIndicatorTextStyle;

  ///[subtitleTextStyle] is textStyle for setting subtitle text style
  final TextStyle? subtitleTextStyle;

  ///[onlineStatusColor] sets online status color
  final Color? onlineStatusColor;
  //
  ///[backgroundColor] provides background color to the message header
  final Color? backgroundColor;

  ///[border] provides border to the message header
  final BoxBorder? border;

  ///[borderRadius] provides border radius to the message header
  final BorderRadiusGeometry? borderRadius;

  ///[titleTextColor] provides color to the title text
  final Color? titleTextColor;

  ///[titleTextStyle] provides text style to the title text
  final TextStyle? titleTextStyle;

  ///[subtitleTextColor] provides color to the subtitle text
  final Color? subtitleTextColor;

  ///[backIconColor] provides color to the back icon
  final Color? backIconColor;

  ///[backIcon] provides back icon
  final Widget? backIcon;

  ///[privateGroupBadgeIcon] provides group icon
  final Widget? privateGroupBadgeIcon;

  ///[passwordProtectedGroupBadgeIcon] provides password protected group icon
  final Widget? passwordProtectedGroupBadgeIcon;

  ///[privateGroupBadgeIconColor] provides color to the private group badge icon
  final Color? privateGroupBadgeIconColor;

  ///[passwordProtectedGroupBadgeIconColor] provides color to the password protected group badge icon
  final Color? passwordProtectedGroupBadgeIconColor;

  ///[groupIconBackgroundColor] provides background color to the group icon
  final Color? groupIconBackgroundColor;

  ///[avatarStyle] set style for avatar
  final CometChatAvatarStyle? avatarStyle;

  ///[callButtonsStyle] set style for call buttons
  final CometChatCallButtonsStyle? callButtonsStyle;

  ///[statusIndicatorStyle] set style for status indicator
  final CometChatStatusIndicatorStyle? statusIndicatorStyle;

  ///[newChatIconColor] provides color to the new chat icon
  final Color? newChatIconColor;

  ///[chatHistoryIconColor] provides color to the chat history icon
  final Color? chatHistoryIconColor;

  ///[menuIconColor] provides color to the overflow (⋯) menu icon. Falls back
  ///to [backIconColor], then to the palette's primary icon colour.
  final Color? menuIconColor;

  static CometChatMessageHeaderStyle of(BuildContext context) =>
      const CometChatMessageHeaderStyle();

  @override
  CometChatMessageHeaderStyle copyWith({
    Color? backButtonIconTint,
    TextStyle? typingIndicatorTextStyle,
    TextStyle? subtitleTextStyle,
    Color? onlineStatusColor,
    Color? backgroundColor,
    BoxBorder? border,
    BorderRadiusGeometry? borderRadius,
    Color? titleTextColor,
    TextStyle? titleTextStyle,
    Color? subtitleTextColor,
    Color? backIconColor,
    Widget? backIcon,
    Widget? privateGroupBadgeIcon,
    Widget? passwordProtectedGroupBadgeIcon,
    Color? privateGroupBadgeIconColor,
    Color? passwordProtectedGroupBadgeIconColor,
    Color? groupIconBackgroundColor,
    CometChatAvatarStyle? avatarStyle,
    CometChatCallButtonsStyle? callButtonsStyle,
    CometChatStatusIndicatorStyle? statusIndicatorStyle,
    Color? newChatIconColor,
    Color? chatHistoryIconColor,
    Color? menuIconColor,
  }) {
    return CometChatMessageHeaderStyle(
      typingIndicatorTextStyle:
          typingIndicatorTextStyle ?? this.typingIndicatorTextStyle,
      subtitleTextStyle: subtitleTextStyle ?? this.subtitleTextStyle,
      onlineStatusColor: onlineStatusColor ?? this.onlineStatusColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      titleTextColor: titleTextColor ?? this.titleTextColor,
      titleTextStyle: titleTextStyle ?? this.titleTextStyle,
      subtitleTextColor: subtitleTextColor ?? this.subtitleTextColor,
      backIcon: backIcon ?? this.backIcon,
      backIconColor: backIconColor ?? this.backIconColor,
      privateGroupBadgeIcon:
          privateGroupBadgeIcon ?? this.privateGroupBadgeIcon,
      passwordProtectedGroupBadgeIcon:
          passwordProtectedGroupBadgeIcon ??
          this.passwordProtectedGroupBadgeIcon,
      privateGroupBadgeIconColor:
          privateGroupBadgeIconColor ?? this.privateGroupBadgeIconColor,
      passwordProtectedGroupBadgeIconColor:
          passwordProtectedGroupBadgeIconColor ??
          this.passwordProtectedGroupBadgeIconColor,
      groupIconBackgroundColor:
          groupIconBackgroundColor ?? this.groupIconBackgroundColor,
      avatarStyle: avatarStyle ?? this.avatarStyle,
      callButtonsStyle: callButtonsStyle ?? this.callButtonsStyle,
      statusIndicatorStyle: statusIndicatorStyle ?? this.statusIndicatorStyle,
      newChatIconColor: newChatIconColor ?? this.newChatIconColor,
      chatHistoryIconColor: chatHistoryIconColor ?? this.chatHistoryIconColor,
      menuIconColor: menuIconColor ?? this.menuIconColor,
    );
  }

  CometChatMessageHeaderStyle merge(CometChatMessageHeaderStyle? style) {
    if (style == null) return this;
    return copyWith(
      typingIndicatorTextStyle: style.typingIndicatorTextStyle,
      subtitleTextStyle: style.subtitleTextStyle,
      onlineStatusColor: style.onlineStatusColor,
      backgroundColor: style.backgroundColor,
      border: style.border,
      borderRadius: style.borderRadius,
      titleTextColor: style.titleTextColor,
      titleTextStyle: style.titleTextStyle,
      subtitleTextColor: style.subtitleTextColor,
      backIcon: style.backIcon,
      backIconColor: style.backIconColor,
      privateGroupBadgeIcon: style.privateGroupBadgeIcon,
      passwordProtectedGroupBadgeIcon: style.passwordProtectedGroupBadgeIcon,
      privateGroupBadgeIconColor: style.privateGroupBadgeIconColor,
      passwordProtectedGroupBadgeIconColor:
          style.passwordProtectedGroupBadgeIconColor,
      groupIconBackgroundColor: style.groupIconBackgroundColor,
      avatarStyle: style.avatarStyle,
      callButtonsStyle: style.callButtonsStyle,
      statusIndicatorStyle: style.statusIndicatorStyle,
      newChatIconColor: style.newChatIconColor,
      chatHistoryIconColor: style.chatHistoryIconColor,
      menuIconColor: style.menuIconColor,
    );
  }

  @override
  CometChatMessageHeaderStyle lerp(
    CometChatMessageHeaderStyle? other,
    double t,
  ) {
    return CometChatMessageHeaderStyle(
      typingIndicatorTextStyle: TextStyle.lerp(
        typingIndicatorTextStyle,
        other?.typingIndicatorTextStyle,
        t,
      ),
      subtitleTextStyle: TextStyle.lerp(
        subtitleTextStyle,
        other?.subtitleTextStyle,
        t,
      ),
      onlineStatusColor: Color.lerp(
        onlineStatusColor,
        other?.onlineStatusColor,
        t,
      ),
      backgroundColor: Color.lerp(backgroundColor, other?.backgroundColor, t),
      border: BoxBorder.lerp(border, other?.border, t),
      borderRadius: BorderRadiusGeometry.lerp(
        borderRadius,
        other?.borderRadius,
        t,
      ),
      titleTextColor: Color.lerp(titleTextColor, other?.titleTextColor, t),
      titleTextStyle: TextStyle.lerp(titleTextStyle, other?.titleTextStyle, t),
      subtitleTextColor: Color.lerp(
        subtitleTextColor,
        other?.subtitleTextColor,
        t,
      ),
      backIconColor: Color.lerp(backIconColor, other?.backIconColor, t),
      backIcon: other?.backIcon ?? backIcon,
      privateGroupBadgeIcon:
          other?.privateGroupBadgeIcon ?? privateGroupBadgeIcon,
      passwordProtectedGroupBadgeIcon:
          other?.passwordProtectedGroupBadgeIcon ??
          passwordProtectedGroupBadgeIcon,
      groupIconBackgroundColor: Color.lerp(
        groupIconBackgroundColor,
        other?.groupIconBackgroundColor,
        t,
      ),
      passwordProtectedGroupBadgeIconColor: Color.lerp(
        passwordProtectedGroupBadgeIconColor,
        other?.passwordProtectedGroupBadgeIconColor,
        t,
      ),
      privateGroupBadgeIconColor: Color.lerp(
        privateGroupBadgeIconColor,
        other?.privateGroupBadgeIconColor,
        t,
      ),
      avatarStyle: avatarStyle?.lerp(other?.avatarStyle, t),
      callButtonsStyle: callButtonsStyle?.lerp(other?.callButtonsStyle, t),
      statusIndicatorStyle: statusIndicatorStyle?.lerp(
        other?.statusIndicatorStyle,
        t,
      ),
      newChatIconColor: Color.lerp(
        newChatIconColor,
        other?.newChatIconColor,
        t,
      ),
      chatHistoryIconColor: Color.lerp(
        chatHistoryIconColor,
        other?.chatHistoryIconColor,
        t,
      ),
      menuIconColor: Color.lerp(menuIconColor, other?.menuIconColor, t),
    );
  }
}
