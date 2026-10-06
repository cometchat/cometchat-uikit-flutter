import 'package:flutter/material.dart';

/// Styling properties for [CometChatAISmartRepliesView].
class CometChatAISmartRepliesStyle
    extends ThemeExtension<CometChatAISmartRepliesStyle> {
  const CometChatAISmartRepliesStyle({
    this.itemTextStyle,
    this.backgroundColor,
    this.emptyTextStyle,
    this.errorTextStyle,
    this.emptyIconTint,
    this.itemBackgroundColor,
    this.border,
    this.borderRadius,
    this.itemBorder,
    this.itemBorderRadius,
    this.closeIconColor,
    this.titleStyle,
  });

  final TextStyle? itemTextStyle;
  final Color? backgroundColor;
  final TextStyle? emptyTextStyle;
  final TextStyle? errorTextStyle;
  final Color? emptyIconTint;
  final Color? itemBackgroundColor;
  final BoxBorder? border;
  final BorderRadiusGeometry? borderRadius;
  final BoxBorder? itemBorder;
  final BorderRadiusGeometry? itemBorderRadius;
  final Color? closeIconColor;
  final TextStyle? titleStyle;

  static CometChatAISmartRepliesStyle of(BuildContext context) =>
      const CometChatAISmartRepliesStyle();

  @override
  CometChatAISmartRepliesStyle copyWith({
    TextStyle? itemTextStyle,
    Color? backgroundColor,
    TextStyle? emptyTextStyle,
    TextStyle? errorTextStyle,
    Color? emptyIconTint,
    Color? itemBackgroundColor,
    BoxBorder? border,
    BorderRadiusGeometry? borderRadius,
    BoxBorder? itemBorder,
    BorderRadiusGeometry? itemBorderRadius,
    Color? closeIconColor,
    TextStyle? titleStyle,
  }) {
    return CometChatAISmartRepliesStyle(
      itemTextStyle: itemTextStyle ?? this.itemTextStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      emptyTextStyle: emptyTextStyle ?? this.emptyTextStyle,
      errorTextStyle: errorTextStyle ?? this.errorTextStyle,
      emptyIconTint: emptyIconTint ?? this.emptyIconTint,
      itemBackgroundColor: itemBackgroundColor ?? this.itemBackgroundColor,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      itemBorder: itemBorder ?? this.itemBorder,
      itemBorderRadius: itemBorderRadius ?? this.itemBorderRadius,
      closeIconColor: closeIconColor ?? this.closeIconColor,
      titleStyle: titleStyle ?? this.titleStyle,
    );
  }

  CometChatAISmartRepliesStyle merge(CometChatAISmartRepliesStyle? other) {
    if (other == null) return this;
    return copyWith(
      itemTextStyle: other.itemTextStyle,
      backgroundColor: other.backgroundColor,
      emptyTextStyle: other.emptyTextStyle,
      errorTextStyle: other.errorTextStyle,
      emptyIconTint: other.emptyIconTint,
      itemBackgroundColor: other.itemBackgroundColor,
      border: other.border,
      borderRadius: other.borderRadius,
      itemBorder: other.itemBorder,
      itemBorderRadius: other.itemBorderRadius,
      closeIconColor: other.closeIconColor,
      titleStyle: other.titleStyle,
    );
  }

  @override
  CometChatAISmartRepliesStyle lerp(
    covariant CometChatAISmartRepliesStyle? other,
    double t,
  ) {
    if (other is! CometChatAISmartRepliesStyle) return this;
    return CometChatAISmartRepliesStyle(
      itemTextStyle: TextStyle.lerp(itemTextStyle, other.itemTextStyle, t),
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      emptyTextStyle: TextStyle.lerp(emptyTextStyle, other.emptyTextStyle, t),
      errorTextStyle: TextStyle.lerp(errorTextStyle, other.errorTextStyle, t),
      emptyIconTint: Color.lerp(emptyIconTint, other.emptyIconTint, t),
      itemBackgroundColor: Color.lerp(
        itemBackgroundColor,
        other.itemBackgroundColor,
        t,
      ),
      closeIconColor: Color.lerp(closeIconColor, other.closeIconColor, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      // All four geometry props were absent from the constructor call, so an
      // animated theme transition dropped every border and radius on this
      // view mid-flight. ENG-39124.
      border: BoxBorder.lerp(border, other.border, t),
      borderRadius: BorderRadiusGeometry.lerp(
        borderRadius,
        other.borderRadius,
        t,
      ),
      itemBorder: BoxBorder.lerp(itemBorder, other.itemBorder, t),
      itemBorderRadius: BorderRadiusGeometry.lerp(
        itemBorderRadius,
        other.itemBorderRadius,
        t,
      ),
    );
  }
}
