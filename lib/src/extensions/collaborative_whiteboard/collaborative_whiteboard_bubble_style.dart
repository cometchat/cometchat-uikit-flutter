import 'package:flutter/material.dart';

///[WhiteBoardBubbleStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatCollaborativeWhiteBoardBubble]
class WhiteBoardBubbleStyle {
  ///Style for WhiteBoard bubble
  const WhiteBoardBubbleStyle(
      {this.titleStyle,
      this.subtitleStyle,
      this.buttonTextStyle,
      this.webViewTitleStyle,
      this.webViewBackIconColor,
      this.webViewAppBarColor,
      this.iconTint,
      this.background,
      this.dividerColor});

  ///[titleStyle] title text style
  final TextStyle? titleStyle;

  ///[subtitleStyle] subtitle text style
  final TextStyle? subtitleStyle;

  ///[buttonTextStyle] buttonText text style
  final TextStyle? buttonTextStyle;

  ///[iconTint] default document bubble icon
  final Color? iconTint;

  ///[webViewTitleStyle] webview title style
  final TextStyle? webViewTitleStyle;

  ///[webViewBackIconColor] webview back icon color
  final Color? webViewBackIconColor;

  ///[webViewAppBarColor] webview app bar color
  final Color? webViewAppBarColor;

  ///[background] sets background color for the bubble
  final Color? background;

  ///[dividerColor] sets background color for the bubble
  final Color? dividerColor;
}
