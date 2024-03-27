import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[TextModerationConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [TextModerationExtension]
///
/// ```dart
///  TextModerationConfiguration(
///    style: TextBubbleStyle(),
///    theme: CometChatTheme(palette: Palette(),typography: Typography())
///  );
/// ```
class TextModerationConfiguration {
  const TextModerationConfiguration({this.theme, this.style});

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[style] use this to alter the default video bubble style
  final TextBubbleStyle? style;
}
