import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[MessageHeaderStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatMessageHeader]
class MessageHeaderStyle extends BaseStyles {
  ///message header style components
  const MessageHeaderStyle({
    this.backButtonIconTint,
    this.onlineStatusColor,
    this.subtitleTextStyle,
    this.typingIndicatorTextStyle,
    double? width,
    double? height,
    Color? background,
    BoxBorder? border,
    double? borderRadius,
    Gradient? gradient,
  }) : super(
            width: width,
            height: height,
            background: background,
            border: border,
            borderRadius: borderRadius,
            gradient: gradient);

  ///[backButtonIconTint] provides color to back button
  final Color? backButtonIconTint;

  ///[typingIndicatorTextStyle] is text style for setting typing indicator text
  final TextStyle? typingIndicatorTextStyle;

  ///[subtitleTextStyle] is textStyle for setting subtitle text style
  final TextStyle? subtitleTextStyle;

  ///[onlineStatusColor] sets online status color
  final Color? onlineStatusColor;
}
