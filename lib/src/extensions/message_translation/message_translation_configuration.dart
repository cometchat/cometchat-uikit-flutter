import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[MessageTranslationConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [MessageTranslationExtension]
///
/// ```dart
/// MessageTranslationConfiguration translationConfig = MessageTranslationConfiguration(
///     optionTitle: 'Translate',
///     optionIconUrl: 'https://example.com/translate-icon.png',
///     style: MessageTranslationBubbleStyle(
///         infoTextStyle: TextStyle(
///             color: Colors.black,
///             fontSize: 14,
///         ),
///     ),
///     optionStyle: MessageTranslationOptionStyle(
///         titleStyle: TextStyle(
///             color: Colors.black,
///             fontSize: 16,
///         ),
///         iconTint: Colors.blue,
///     ),
///     theme: CometChatTheme(palette: Palette(),typography: Typography()),
/// );
///
/// ```
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
