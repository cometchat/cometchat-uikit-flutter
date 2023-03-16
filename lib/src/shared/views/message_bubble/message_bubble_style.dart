import 'package:flutter/material.dart';
import '../../../../flutter_chat_ui_kit.dart';

class MessageBubbleStyle extends BaseStyles {
  const MessageBubbleStyle(
      {double? width,
      double? height,
      Color? background,
      BoxBorder? border,
      double? borderRadius,
      Gradient? gradient,
      this.contentPadding})
      : super(
            width: width,
            height: height,
            background: background,
            border: border,
            borderRadius: borderRadius,
            gradient: gradient);

  final EdgeInsets? contentPadding;
}
