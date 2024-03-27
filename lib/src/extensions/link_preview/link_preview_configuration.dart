import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[LinkPreviewConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [LinkPreviewExtension]
///
/// ```dart
///   LinkPreviewConfiguration(
///    defaultImage: Image.network('some url for image'),
///    style: LinkPreviewBubbleStyle(),
///    theme: CometChatTheme(palette: Palette(),typography: Typography())
///  );
/// ```
class LinkPreviewConfiguration {
  LinkPreviewConfiguration({this.defaultImage, this.theme, this.style});

  ///[defaultImage] is shown unable to generate image from link
  final Widget? defaultImage;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[style] provides style to the link preview bubble
  final LinkPreviewBubbleStyle? style;
}
