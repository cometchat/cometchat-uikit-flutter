import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[AIAssistBotStyle] is a data class that has styling-related properties
///to customize the appearance of [AIAssistBotExtension]
class AIAssistBotStyle extends BaseStyles {
  const AIAssistBotStyle({
    this.emptyTextStyle,
    this.emptyIconTint,
    this.errorIconTint,
    this.errorTextStyle,
    this.loadingTextStyle,
    this.loadingIconTint,
    this.shadowColor,
    this.titleStyle,
    this.closeIconTint,
    super.background,
    super.border,
    super.borderRadius,
    super.gradient,
  });

  ///[loadingTextStyle] changes style of suggested loading text
  final TextStyle? loadingTextStyle;

  ///[loadingIconTint] provides color to loading icon
  final Color? loadingIconTint;

  ///[emptyTextStyle] provides styling for text to indicate replies list is empty
  final TextStyle? emptyTextStyle;

  ///[errorTextStyle] provides styling for text to indicate some error has occurred while fetching the replies list
  final TextStyle? errorTextStyle;

  ///[errorIconTint] provides color to error icon
  final Color? errorIconTint;

  ///[emptyIconTint] provides color to empty icon
  final Color? emptyIconTint;

  ///[shadowColor] changes shadow color of reply text chip/bubbles
  final Color? shadowColor;

  ///[titleStyle] set style for title
  final TextStyle? titleStyle;

  ///[closeIconTint] sets the color for close icon
  final Color? closeIconTint;

  /// Copies current [AIAssistBotStyle] with some changes
  AIAssistBotStyle copyWith({
    TextStyle? replyTextStyle,
    TextStyle? loadingTextStyle,
    Color? backgroundColor,
    Color? loadingIconTint,
    TextStyle? emptyTextStyle,
    TextStyle? errorTextStyle,
    Color? errorIconTint,
    Color? emptyIconTint,
    Color? shadowColor,
    Color? background,
    BoxBorder? border,
    double? borderRadius,
    Gradient? gradient,
  }) {
    return AIAssistBotStyle(
      loadingTextStyle: loadingTextStyle ?? this.loadingTextStyle,
      loadingIconTint: loadingIconTint ?? this.loadingIconTint,
      emptyTextStyle: emptyTextStyle ?? this.emptyTextStyle,
      errorTextStyle: errorTextStyle ?? this.errorTextStyle,
      errorIconTint: errorIconTint ?? this.errorIconTint,
      emptyIconTint: emptyIconTint ?? this.emptyIconTint,
      shadowColor: shadowColor ?? this.shadowColor,
      background: background ?? this.background,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      gradient: gradient ?? this.gradient,
    );
  }

  /// Merges current [AIAssistBotStyle] with [other]
  AIAssistBotStyle merge(AIAssistBotStyle? other) {
    if (other == null) return this;
    return AIAssistBotStyle(
      loadingTextStyle: other.loadingTextStyle,
      loadingIconTint: other.loadingIconTint,
      emptyTextStyle: other.emptyTextStyle,
      errorTextStyle: other.errorTextStyle,
      errorIconTint: other.errorIconTint,
      emptyIconTint: other.emptyIconTint,
      shadowColor: other.shadowColor,
      background: other.background,
      border: other.border,
      borderRadius: other.borderRadius,
      gradient: other.gradient,
    );
  }
}
