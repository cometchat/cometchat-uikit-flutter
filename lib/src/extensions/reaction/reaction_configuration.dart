import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class ReactionConfiguration {
  ReactionConfiguration(
      {this.optionTitle,
      this.optionIconUrl,
      this.optionIconUrlPackageName,
      this.optionStyle,
      this.theme,
      this.addReactionIcon,
      this.reactionsStyle,
      this.emojiKeyboardStyle
      });

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[addReactionIcon] add reaction icon
  final Widget? addReactionIcon;

  ///[reactionsStyle] provides style to the emoji keyboard and the emoji
  final ReactionsStyle? reactionsStyle;

  ///[optionTitle] is the name for the option for this extension
  final String? optionTitle;

  ///[optionIconUrl] is the path to the icon image for the option for this extension
  final String? optionIconUrl;

  ///[optionIconUrlPackageName] is the name of the package where the icon for the option for this extension is located
  final String? optionIconUrlPackageName;

  ///[optionStyle] provides style to the option
  final ReactionOptionStyle? optionStyle;
  
  ///[emojiKeyboardStyle] provides styling to the keyboard that contains the emojis
  final ReactionsEmojiKeyboardStyle? emojiKeyboardStyle;
}
