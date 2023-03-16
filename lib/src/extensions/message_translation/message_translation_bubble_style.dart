import 'package:flutter/material.dart';

class MessageTranslationBubbleStyle {
  MessageTranslationBubbleStyle({this.infoTextStyle, this.translatedTextStyle});

  ///[infoTextStyle] provides styling for the text "Translated message"
  final TextStyle? infoTextStyle;

  ///[translatedTextStyle] provides styling for the translated text
  final TextStyle? translatedTextStyle;
}
