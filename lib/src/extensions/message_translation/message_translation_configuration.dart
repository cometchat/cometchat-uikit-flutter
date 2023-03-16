import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class MessageTranslationConfiguration {
  MessageTranslationConfiguration(
      {this.optionTitle,
      this.optionIconUrl,
      this.optionIconUrlPackageName,
      this.optionStyle,
      this.style,
      this.theme});

  ///[style] provides style
  final MessageTranslationBubbleStyle? style;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[optionTitle] is the name for the option for this extension
  final String? optionTitle;

  ///[optionIconUrl] is the path to the icon image for the option for this extension
  final String? optionIconUrl;

  ///[optionIconUrlPackageName] is the name of the package where the icon for the option for this extension is located
  final String? optionIconUrlPackageName;

  ///[optionStyle] provides style to the option
  final MessageTranslationOptionStyle? optionStyle;
}
