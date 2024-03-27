import 'package:flutter/material.dart';

///[SmartReplyStyle] is a data class that has styling-related properties
///to customize the appearance of [SmartReplyView]
class SmartReplyStyle {
  const SmartReplyStyle(
      {this.replyTextStyle,
      this.replyBackgroundColor,
      this.closeIconColor,
      this.shadowColor});

  ///[replyTextStyle] changes style of suggested reply text
  final TextStyle? replyTextStyle;

  ///[replyBackgroundColor] changes background color of reply text chip/bubbles
  final Color? replyBackgroundColor;

  ///[closeIconColor] changes color of of the close icon that removes the reply text view
  final Color? closeIconColor;

  ///[shadowColor] changes shadow color of reply text chip/bubbles
  final Color? shadowColor;
}
