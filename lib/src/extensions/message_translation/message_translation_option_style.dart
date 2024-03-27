import 'package:flutter/material.dart';

///[MessageTranslationOptionStyle] is a data class that has styling-related properties
///to customize the appearance of the option that appears in the bottom modal sheet on long-pressing a message bubble
class MessageTranslationOptionStyle {
  MessageTranslationOptionStyle({this.iconTint, this.titleStyle});

  ///[iconTint] provides color to option icon
  final Color? iconTint;

  ///[titleStyle] provides style to option text
  final TextStyle? titleStyle;
}
