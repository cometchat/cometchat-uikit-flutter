import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

///[MessagesStyle] is the component to provide styles for message module
class ThreadedMessageStyle extends BaseStyles {
  final Color? closeIconTint;

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
