import 'package:flutter/material.dart';

class PollsBubbleStyle {
  ///poll bubble style
  const PollsBubbleStyle(
      {this.questionTextStyle,
      this.pollResultTextStyle,
      this.voteCountTextStyle,
      this.pollOptionsTextStyle,
      this.radioButtonColor,
      this.pollOptionsBackgroundColor,
      this.selectedOptionColor,
      this.unSelectedOptionColor});

  ///[questionTextStyle] question text style
  final TextStyle? questionTextStyle;

  ///[pollResultTextStyle] poll result text style
  final TextStyle? pollResultTextStyle;

  ///[voteCountTextStyle] vote count text style
  final TextStyle? voteCountTextStyle;

  ///[pollOptionsTextStyle] poll options text style
  final TextStyle? pollOptionsTextStyle;

  ///[radioButtonColor] radio  button color
  final Color? radioButtonColor;

  ///[pollOptionsBackgroundColor] poll option bar background color
  final Color? pollOptionsBackgroundColor;

  ///[selectedOptionColor] selected option poll bar color
  final Color? selectedOptionColor;

  ///[unSelectedOptionColor] unselected option poll bar color
  final Color? unSelectedOptionColor;
}