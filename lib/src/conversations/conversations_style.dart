import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[ConversationsStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatConversations]
class ConversationsStyle extends BaseStyles {
  const ConversationsStyle(
      {this.backIconTint,
      this.titleStyle,
      super.width,
      super.height,
      super.background,
      super.border,
      super.borderRadius,
      super.gradient,
      this.emptyTextStyle,
      this.errorTextStyle,
      this.onlineStatusColor,
      this.separatorColor,
      this.loadingIconTint,
      this.lastMessageStyle,
      this.threadIndicatorStyle,
      this.typingIndicatorStyle,
      this.privateGroupIconBackground,
      this.protectedGroupIconBackground});

  ///[backIconTint] provides color for the back icon
  final Color? backIconTint;

  ///[titleStyle] TextStyle for title
  final TextStyle? titleStyle;

  ///[emptyTextStyle] provides styling for text to indicate user list is empty
  final TextStyle? emptyTextStyle;

  ///[errorTextStyle] provides styling for text to indicate some error has occurred while fetching the user list
  final TextStyle? errorTextStyle;

  ///[onlineStatusColor] set online status color
  final Color? onlineStatusColor;

  ///[separatorColor] set separator color
  final Color? separatorColor;

  ///[loadingIconTint] provides color to loading icon
  final Color? loadingIconTint;

  ///[lastMessageStyle] provides styling for last message
  final TextStyle? lastMessageStyle;

  ///[typingIndicatorStyle] typing indicator widget shown on user is typing
  final TextStyle? typingIndicatorStyle;

  ///[threadIndicatorStyle] thread indicator shown if message is in thread in group
  final TextStyle? threadIndicatorStyle;

  ///[privateGroupIconBackground] provides background color for status indicator if group is private
  final Color? privateGroupIconBackground;

  ///[protectedGroupIconBackground] provides background color for status indicator if group is private
  final Color? protectedGroupIconBackground;
}
