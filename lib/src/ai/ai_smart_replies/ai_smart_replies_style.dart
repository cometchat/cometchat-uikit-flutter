import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

///[AISmartRepliesStyle] is a data class that has styling-related properties
///to customize the appearance of [AISmartRepliesView]
class AISmartRepliesStyle {
  const AISmartRepliesStyle({
    this.replyTextStyle,
    this.backgroundColor,
    this.emptyTextStyle,
    this.errorIconTint,
    this.errorTextStyle,
    this.loadingIconTint,
    this.emptyIconTint,
    this.dividerTint,
    this.loadingTextStyle,
  });

  ///[replyTextStyle] changes style of suggested reply text
  final TextStyle? replyTextStyle;

  ///[backgroundColor] changes background color of reply list
  final Color? backgroundColor;

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

  ///[dividerTint] sets color for divider
  final Color? dividerTint;

  ///[loadingTextStyle] provides styling for text to indicate loading state has occurred while fetching the replies list
  final TextStyle? loadingTextStyle;

  AISmartRepliesStyle fromJson(Map<String, dynamic> json) {
    return AISmartRepliesStyle(
      backgroundColor: backgroundColor ?? json['backgroundColor'],
      replyTextStyle: replyTextStyle ?? json['replyTextStyle'],
      dividerTint: dividerTint ?? json['dividerTint'],
      loadingIconTint: loadingIconTint ?? json['loadingIconTint'],
      emptyTextStyle: emptyTextStyle ?? json['emptyTextStyle'],
      errorTextStyle: errorTextStyle ?? json['errorTextStyle'],
      errorIconTint: errorIconTint ?? json['errorIconTint'],
      emptyIconTint: emptyIconTint ?? json['emptyIconTint'],
      loadingTextStyle: loadingTextStyle ?? json['loadingTextStyle'],
    );
  }

  /// Copies current [AISmartRepliesStyle] with some changes
  AISmartRepliesStyle copyWith({
    TextStyle? replyTextStyle,
    Color? backgroundColor,
    Color? loadingIconTint,
    TextStyle? emptyTextStyle,
    TextStyle? errorTextStyle,
    Color? errorIconTint,
    Color? emptyIconTint,
    Color? dividerTint,
    TextStyle? loadingTextStyle,
  }) {
    return AISmartRepliesStyle(
      replyTextStyle: replyTextStyle ?? this.replyTextStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      loadingIconTint: loadingIconTint ?? this.loadingIconTint,
      emptyTextStyle: emptyTextStyle ?? this.emptyTextStyle,
      errorTextStyle: errorTextStyle ?? this.errorTextStyle,
      errorIconTint: errorIconTint ?? this.errorIconTint,
      emptyIconTint: emptyIconTint ?? this.emptyIconTint,
      dividerTint: dividerTint ?? this.dividerTint,
      loadingTextStyle: loadingTextStyle ?? this.loadingTextStyle,
    );
  }

  /// Merges current [AISmartRepliesStyle] with [other]
  AISmartRepliesStyle merge(AISmartRepliesStyle? other) {
    if (other == null) return this;
    return copyWith(
      replyTextStyle: other.replyTextStyle,
      backgroundColor: other.backgroundColor,
      loadingIconTint: other.loadingIconTint,
      emptyTextStyle: other.emptyTextStyle,
      errorTextStyle: other.errorTextStyle,
      errorIconTint: other.errorIconTint,
      emptyIconTint: other.emptyIconTint,
      dividerTint: other.dividerTint,
      loadingTextStyle: other.loadingTextStyle,
    );
  }
}
