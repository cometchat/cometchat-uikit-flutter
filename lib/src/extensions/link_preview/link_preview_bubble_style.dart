import 'package:flutter/material.dart';

///[LinkPreviewBubbleStyle] is a data class that has styling-related properties
///to customize the appearance of [LinkPreviewBubble]
class LinkPreviewBubbleStyle {
  const LinkPreviewBubbleStyle(
      {this.titleStyle, this.urlStyle, this.tileColor, this.backgroundColor});

  ///[titleStyle] styles the name of the website
  final TextStyle? titleStyle;

  ///[urlStyle] styles the url link
  final TextStyle? urlStyle;

  ///[tileColor] changes the color of the tile containing website name, link and favicon
  final Color? tileColor;

  ///[backgroundColor] changes the color of the bubble
  final Color? backgroundColor;
}
