import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

/// A Configuration object for [CometChatAvatar]
///
/// this Configuration object can be used to configure avatar properties
/// from parents

/// {@tool snippet}
/// ```dart
///AvatarConfiguration(
/// width: 22,
/// height: 20,
/// backgroundColor: Colors.black,
/// cornerRadius: 5.0,
/// nameTextStyle : TextStyle(),
///  outerCornerRadius: 20.0,
/// outerViewBackgroundColor:
/// Colors.black,
/// outerViewSpacing:1.0,
/// outerViewWidth:1.0)
///```
/// {@end-tool}
class AvatarConfiguration extends CometChatConfigurations {
  const AvatarConfiguration({
    this.width,
    this.height,
    this.border,
    this.backgroundColor,
    this.cornerRadius,
    this.outerCornerRadius,
    this.outerViewBorder,
    this.outerViewWidth,
    this.outerViewBackgroundColor,
    this.outerViewSpacing,
    this.nameTextStyle,
  });

  ///[width] Width of Avatar
  final double? width;

  ///[height] height of inner container
  final double? height;

  ///[border] style of inner border
  final BoxBorder? border;

  ///[backgroundColor] background color of widget
  final Color? backgroundColor;

  ///[cornerRadius] of inner container
  final double? cornerRadius;

  ///[outerCornerRadius] of outer container
  final double? outerCornerRadius;

  ///[outerViewBorder] style the outer Container border
  final BoxBorder? outerViewBorder;

  ///[outerViewWidth] outer view With
  final double? outerViewWidth;

  ///[outerViewBackgroundColor] outer Container background Color
  final Color? outerViewBackgroundColor;

  ///[outerViewSpacing] Spacing between the image and the outer border
  final double? outerViewSpacing;

  ///[nameTextStyle] font style if visible
  final TextStyle? nameTextStyle;
}
