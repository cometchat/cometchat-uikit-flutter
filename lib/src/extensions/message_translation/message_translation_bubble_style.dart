import 'package:flutter/material.dart';

///[MessageTranslationBubbleStyle] is a data class that has styling-related properties
///to customize the appearance of [MessageTranslationBubble]
class MessageTranslationBubbleStyle {
  MessageTranslationBubbleStyle({this.infoTextStyle, this.translatedTextStyle});

  ///[infoTextStyle] provides styling for the text "Translated message"
  final TextStyle? infoTextStyle;

  ///[translatedTextStyle] provides styling for the translated text
  final TextStyle? translatedTextStyle;
}
