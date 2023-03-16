import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class ImageModerationConfiguration {
  ImageModerationConfiguration({this.theme, this.warningText, this.style});

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[warningText] text shown if image has sensitive/graphic content
  final String? warningText;

  ///[style] provides styling to this ImageModerationFilter
  final ImageModerationFilterStyle? style;
}
