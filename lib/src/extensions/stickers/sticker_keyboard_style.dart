import 'package:flutter/material.dart';

///[StickerKeyboardStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatStickerKeyboard]
class StickerKeyboardStyle {
  StickerKeyboardStyle(
      {this.loadingIconTint,
      this.emptyTextStyle,
      this.errorTextStyle,
      this.errorIconTint,
      this.errorIconBackground});

  ///[loadingIconTint] provides color to loading icon
  final Color? loadingIconTint;

  ///[emptyTextStyle] provides styling for text to indicate user list is empty
  final TextStyle? emptyTextStyle;

  ///[errorTextStyle] provides styling for text to indicate some error has occurred while fetching the user list
  final TextStyle? errorTextStyle;

  ///[loadingIconTint] provides color to loading icon
  final Color? errorIconTint;

  ///[loadingIconTint] provides color to loading icon
  final Color? errorIconBackground;
}
