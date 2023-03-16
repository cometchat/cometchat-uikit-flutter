import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class ThumbnailGenerationConfiguration {
  const ThumbnailGenerationConfiguration({this.theme, this.style});

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[style] use this to alter the default video bubble style
  final VideoBubbleStyle? style;
}
