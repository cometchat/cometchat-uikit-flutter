import 'package:flutter/material.dart';

///[MessageTranslationOptionStyle] is a data class that has styling-related properties
///to customize the appearance of the option that appears in the bottom modal sheet on long-pressing a message bubble
@Deprecated(
  'Has no effect: only MessageTranslationConfiguration accepted it. Style the Translate option with CometChatMessageListStyle.messageOptionSheetStyle, and hide it with CometChatMessageList.hideTranslateMessageOption. Will be removed in 7.0.0.',
)
class MessageTranslationOptionStyle {
  /// Creates a [MessageTranslationOptionStyle].
  MessageTranslationOptionStyle({this.iconTint, this.titleStyle});

  ///[iconTint] provides color to option icon
  final Color? iconTint;

  ///[titleStyle] provides style to option text
  final TextStyle? titleStyle;
}
