import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class ListItemStyle extends BaseStyles {
  const ListItemStyle({
    this.titleStyle,
    this.separatorColor,
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

  ///[titleStyle] TextStyle for List item title
  final TextStyle? titleStyle;

  ///[separatorColor] customize the color of the horizontal line separating the list items
  final Color? separatorColor;
}
