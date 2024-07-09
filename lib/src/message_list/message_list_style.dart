import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[MessageListStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatMessageList]
class MessageListStyle extends BaseStyles {
  const MessageListStyle({
    this.loadingIconTint,
    this.emptyTextStyle,
    this.errorTextStyle,
    this.contentPadding,
    super.width,
    super.height,
    super.background,
    super.border,
    super.borderRadius,
    super.gradient,
  });

  ///[loadingIconTint] provides color to loading icon
  final Color? loadingIconTint;

  ///[emptyTextStyle] provides styling for text to indicate message list is empty
  final TextStyle? emptyTextStyle;

  ///[errorTextStyle] provides styling for text to indicate some error has occured while fetching the message list
  final TextStyle? errorTextStyle;

  final EdgeInsetsGeometry? contentPadding;

  /// Merge with another MessageListStyle
  MessageListStyle mergeWith(MessageListStyle? other) {
    if (other == null) return this;
    return MessageListStyle(
      loadingIconTint: other.loadingIconTint ?? loadingIconTint,
      emptyTextStyle: other.emptyTextStyle ?? emptyTextStyle,
      errorTextStyle: other.errorTextStyle ?? errorTextStyle,
      contentPadding: other.contentPadding ?? contentPadding,
      width: other.width ?? width,
      height: other.height ?? height,
      background: other.background ?? background,
      border: other.border ?? border,
      borderRadius: other.borderRadius ?? borderRadius,
      gradient: other.gradient ?? gradient,
    );
  }

  /// Copy with some properties replaced
  MessageListStyle copyWith({
    Color? loadingIconTint,
    TextStyle? emptyTextStyle,
    TextStyle? errorTextStyle,
    EdgeInsetsGeometry? contentPadding,
    double? width,
    double? height,
    Color? background,
    Border? border,
    double? borderRadius,
    Gradient? gradient,
  }) {
    return MessageListStyle(
      loadingIconTint: loadingIconTint ?? this.loadingIconTint,
      emptyTextStyle: emptyTextStyle ?? this.emptyTextStyle,
      errorTextStyle: errorTextStyle ?? this.errorTextStyle,
      contentPadding: contentPadding ?? this.contentPadding,
      width: width ?? this.width,
      height: height ?? this.height,
      background: background ?? this.background,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      gradient: gradient ?? this.gradient,
    );
  }
}
