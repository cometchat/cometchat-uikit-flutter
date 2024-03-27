import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[ThreadedMessageStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatThreadedMessages]
class ThreadedMessageStyle extends BaseStyles {
  ///[closeIconTint] sets color for close icon
  final Color? closeIconTint;

  ///[titleStyle] sets TextStyle for title
  final TextStyle? titleStyle;

  const ThreadedMessageStyle(
      {double? width,
      double? height,
      Color? background,
      BoxBorder? border,
      double? borderRadius,
      Gradient? gradient,
      this.titleStyle,
      this.closeIconTint})
      : super(
            width: width,
            height: height,
            background: background,
            border: border,
            borderRadius: borderRadius,
            gradient: gradient);
}
