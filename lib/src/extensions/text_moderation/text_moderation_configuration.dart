import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class TextModerationConfiguration {
  const TextModerationConfiguration({this.theme, this.style});

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[style] use this to alter the default video bubble style
  final TextBubbleStyle? style;
}
