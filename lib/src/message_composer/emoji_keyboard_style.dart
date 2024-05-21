import 'package:flutter/material.dart';

///[EmojiKeyboardStyle] is
/// a data class that has styling-related properties
///to customize the appearance of [CometChatEmojiKeyboard]
class EmojiKeyboardStyle {
  EmojiKeyboardStyle(
      {this.backgroundColor,
      this.titleStyle,
      this.dividerColor,
      this.categoryLabelStyle,
      this.selectedCategoryIconColor,
      this.unselectedCategoryIconColor});

  ///[backgroundColor] provides color to the emoji keyboard
  final Color? backgroundColor;

  ///[titleStyle] provides style to the title of the emoji keyboard
  final TextStyle? titleStyle;

  ///[dividerColor] provides to the divider in the emoji keyboard
  final Color? dividerColor;

  ///[categoryLabelStyle] provides style to the label text in the emoji keyboard
  final TextStyle? categoryLabelStyle;

  ///[selectedCategoryIconColor] provides background color to a selected emoji on the emoji keyboard
  final Color? selectedCategoryIconColor;

  ///[unselectedCategoryIconColor] provides the default background of all emojis in the emoji keyboard
  final Color? unselectedCategoryIconColor;
}
