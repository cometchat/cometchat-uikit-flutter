import 'package:flutter/material.dart';

class ReactionsStyle {
  ReactionsStyle({
    this.emojiBackground,
    this.emojiBorder,
    this.emojiBorderRadius,
    this.emojiCountStyle,
  });

  ///[emojiBackground] changes background color of emojis
  final Color? emojiBackground;

  ///[emojiBorder] changes border color of emojis
  final BoxBorder? emojiBorder;

  ///[emojiBorderRadius] changes border radius of emojis
  final double? emojiBorderRadius;

  ///[emojiCountStyle] changes text style of emoji count
  final TextStyle? emojiCountStyle;
}
