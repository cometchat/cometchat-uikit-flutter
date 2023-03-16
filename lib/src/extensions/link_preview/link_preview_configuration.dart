import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class LinkPreviewConfiguration {
  LinkPreviewConfiguration({this.defaultImage, this.theme, this.style});

  ///[defaultImage] is shown unable to generate image from link
  final Widget? defaultImage;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[style] provides style to the link preview bubble
  final LinkPreviewBubbleStyle? style;
}
