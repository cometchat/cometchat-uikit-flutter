import 'package:flutter/material.dart';

///[CreatePollsStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatCreatePolls]
class CreatePollsStyle {
  ///create poll style
  const CreatePollsStyle(
      {this.background,
      this.borderColor,
      this.titleStyle,
      this.closeIconColor,
      this.deleteIconColor,
      this.createPollIconColor,
      this.inputTextStyle,
      this.hintTextStyle,
      this.answerHelpText,
      this.addAnswerTextStyle});

  ///[background] background color
  final Color? background;

  ///[titleStyle] title style
  final TextStyle? titleStyle;

  ///[closeIconColor] back icon color
  final Color? closeIconColor;

  ///[createPollIconColor] check mark color
  final Color? createPollIconColor;

  ///[deleteIconColor]
  final Color? deleteIconColor;

  ///[borderColor] border color of text field
  final Color? borderColor;

  ///[inputTextStyle] input text style in text filed
  final TextStyle? inputTextStyle;

  ///[hintTextStyle] hint text style in text field
  final TextStyle? hintTextStyle;

  ///[answerHelpText] set the answers text style
  final TextStyle? answerHelpText;

  ///[addAnswerTextStyle] add new answers text style
  final TextStyle? addAnswerTextStyle;
}
