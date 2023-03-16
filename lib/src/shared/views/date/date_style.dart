import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class DateStyle extends BaseStyles {
  const DateStyle({
    this.textStyle,
    this.contentPadding,
    this.isTransparentBackground,
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

  ///[textStyle] gives style to the date to be displayed
  final TextStyle? textStyle;

  ///[contentPadding] set the content padding.
  final EdgeInsetsGeometry? contentPadding;

  ///set the container to be transparent.
  final bool? isTransparentBackground;
}