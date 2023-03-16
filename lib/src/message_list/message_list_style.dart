import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class MessageListStyle extends BaseStyles {
  const MessageListStyle({
    this.loadingIconTint,
    this.emptyTextStyle,
    this.errorTextStyle,
    this.contentPadding,
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

  ///[loadingIconTint] provides color to loading icon
  final Color? loadingIconTint;

  ///[emptyTextStyle] provides styling for text to indicate message list is empty
  final TextStyle? emptyTextStyle;

  ///[errorTextStyle] provides styling for text to indicate some error has occured while fetching the message list
  final TextStyle? errorTextStyle;

  final EdgeInsetsGeometry? contentPadding;
}
