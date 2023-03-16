import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class PlaceholderBubbleStyle extends BaseStyles {
  const PlaceholderBubbleStyle({
    this.textStyle,
    this.headerTextStyle,
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

  ///[textStyle] provides style to text
  final TextStyle? textStyle;

  ///[textStyle] provides style to text in header
  final TextStyle? headerTextStyle;
}
