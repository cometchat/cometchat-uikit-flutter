import 'package:flutter/material.dart';
import '../../../../../../cometchat_uikit_shared.dart';

///[ListItemStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatListItem]

class ListItemStyle extends BaseStyles {
  const ListItemStyle({
    this.titleStyle,
    this.separatorColor,
    this.padding,
    this.margin,
    super.width,
    super.height,
    super.background,
    super.border,
    super.borderRadius,
    super.gradient,
  });

  ///[titleStyle] TextStyle for List item title
  final TextStyle? titleStyle;

  ///[separatorColor] customize the color of the horizontal line separating the list items
  final Color? separatorColor;

  /// Empty space to inscribe inside the `decoration`. The `child`, if any, is
  /// placed inside this padding
  final EdgeInsetsGeometry? padding;

  /// Empty space to surround the [CometChatListItem].
  final EdgeInsetsGeometry? margin;

  ListItemStyle copyWith({
    TextStyle? titleStyle,
    Color? separatorColor,
    double? width,
    double? height,
    Color? background,
    Gradient? gradient,
    BoxBorder? border,
    BorderRadiusGeometry? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    return ListItemStyle(
      titleStyle: titleStyle ?? this.titleStyle,
      separatorColor: separatorColor ?? this.separatorColor,
      width: width ?? this.width,
      height: height ?? this.height,
      background: background ?? this.background,
      gradient: gradient ?? this.gradient,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      // Declared fields copyWith never carried, so every copy reset both to
      // null. ENG-39124.
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
    );
  }

  dynamic merge(ListItemStyle? style) {
    if (style == null) return this;
    return copyWith(
      titleStyle: style.titleStyle,
      separatorColor: style.separatorColor,
      width: style.width,
      height: style.height,
      background: style.background,
      gradient: style.gradient,
      border: style.border,
      borderRadius: style.borderRadius,
    );
  }
}
