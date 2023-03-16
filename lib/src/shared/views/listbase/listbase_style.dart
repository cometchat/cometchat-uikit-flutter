import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class ListBaseStyle extends BaseStyles {
  const ListBaseStyle({
    this.titleStyle,
    this.searchBoxRadius,
    this.searchTextStyle,
    this.searchPlaceholderStyle,
    this.searchBorderWidth,
    this.searchBorderColor,
    this.searchBoxBackground,
    this.backIconTint,
    this.searchIconTint,
    this.padding,
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

  ///[titleStyle] TextStyle for tvTitle
  final TextStyle? titleStyle;

  ///[searchBoxRadius] search box radius
  final double? searchBoxRadius;

  ///[searchTextStyle] TextStyle for search text
  final TextStyle? searchTextStyle;

  ///[searchBorderWidth] border width for search box
  final double? searchBorderWidth;

  ///[searchBorderColor] border color for search box
  final Color? searchBorderColor;

  ///[searchBoxBackground] background color for search box
  final Color? searchBoxBackground;

  ///[searchPlaceholderStyle] TextStyle for search hint/placeholder text
   final TextStyle? searchPlaceholderStyle;

  ///[searchIconTint] color for search icon
   final Color? searchIconTint;

  ///[backIconTint] color for back icon
   final Color? backIconTint;

  ///[padding] surrounds the cometchat listbase
  final EdgeInsetsGeometry? padding;
}