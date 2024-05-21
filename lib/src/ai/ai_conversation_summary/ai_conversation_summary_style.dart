import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[AIConversationSummaryStyle] is a data class that has styling-related properties
///to customize the appearance of [AIConversationSummaryStyle]
class AIConversationSummaryStyle extends BaseStyles {
  const AIConversationSummaryStyle({
    this.backgroundColor,
    this.emptyTextStyle,
    this.emptyIconTint,
    this.errorIconTint,
    this.errorTextStyle,
    this.loadingTextStyle,
    this.loadingIconTint,
    this.shadowColor,
    this.decoratedContainerSummaryStyle,
    super.background,
    super.border,
    super.borderRadius,
    super.gradient,
  });

  ///[loadingTextStyle] changes style of suggested loading text
  final TextStyle? loadingTextStyle;

  ///[backgroundColor] changes background color of reply list
  final Color? backgroundColor;

  ///[loadingIconTint] provides color to loading icon
  final Color? loadingIconTint;

  ///[emptyTextStyle] provides styling for text tin empty state
  final TextStyle? emptyTextStyle;

  ///[errorTextStyle] provides styling for text to indicate error state
  final TextStyle? errorTextStyle;

  ///[errorIconTint] provides color to error icon
  final Color? errorIconTint;

  ///[emptyIconTint] provides color to empty icon
  final Color? emptyIconTint;

  ///[shadowColor] changes shadow color of reply text chip/bubbles
  final Color? shadowColor;

  ///[decoratedContainerSummaryStyle] set style for summary's decorated style
  final DecoratedContainerStyle? decoratedContainerSummaryStyle;

  /// Copies current [AIConversationSummaryStyle] with some changes
  AIConversationSummaryStyle copyWith({
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
    return AIConversationSummaryStyle(
      loadingTextStyle: loadingTextStyle ?? this.loadingTextStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
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

  /// Merges current [AIConversationSummaryStyle] with [other]
  AIConversationSummaryStyle merge(AIConversationSummaryStyle? other) {
    if (other == null) return this;
    return AIConversationSummaryStyle(
      loadingTextStyle: other.loadingTextStyle,
      backgroundColor: other.backgroundColor,
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
