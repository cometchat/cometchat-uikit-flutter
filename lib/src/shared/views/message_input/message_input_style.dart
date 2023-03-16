import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class MessageInputStyle extends BaseStyles {
  const MessageInputStyle(
    {
    this.textStyle,
    this.placeholderTextStyle,
    this.dividerTint,
    // this.dividerColor, 
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


  ///[textStyle]
  final TextStyle? textStyle;

  ///[placeholderTextStyle] hint text style
  final TextStyle? placeholderTextStyle;

  ///[dividerTint] provides color to the divider sepeating input field and bottom bar
  final Color? dividerTint;

  ///[dividerColor] provides color to the divider
  // final Color? dividerColor;
}
