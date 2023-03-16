import 'package:flutter/material.dart';
import '../../flutter_chat_ui_kit.dart';

///[AddMembersStyle] is a styling class to alter styling properties for [CometChatAddMember]
///it list down users according to different parameter set in order of recent activity and select users on click

class AddMembersStyle extends BaseStyles {
  AddMembersStyle({
    this.titleStyle,
    this.backIconTint,
    this.closeIconTint,
    this.searchBackground,
    this.searchStyle,
    this.placeholderStyle,
    this.searchIconTint,
    this.searchBorderWidth,
    this.searchBorderColor,
    this.searchBorderRadius,
    double? width,
    double? height,
    Color? background,
    BoxBorder? border,
    double? borderRadius,
    Gradient? gradient,
    this.emptyStateTextStyle,
    this.errorStateTextStyle
  }) : super(
            width: width,
            height: height,
            background: background,
            border: border,
            borderRadius: borderRadius,
            gradient: gradient);

  ///[titleStyle] provide title style to add members
  final TextStyle? titleStyle;

  ///[backIconTint] set icon tint for back button if not present already
  final Color? backIconTint;

  ///[closeIconTint] set close icon tint
  final Color? closeIconTint;

  ///[searchBackground] set search field background color
  final Color? searchBackground;

  ///[searchStyle] set search field text style
  final TextStyle? searchStyle;

  ///[placeholderStyle] set search text placeholder
  final TextStyle? placeholderStyle;

  ///[searchIconTint] set search icon tint
  final Color? searchIconTint;

  ///[searchBorderWidth] provides width to the search border
  final double? searchBorderWidth;

  ///[searchBorderColor] provides color to the search border
  final Color? searchBorderColor;

  ///[searchBorderRadius] provides radius to the search box
  final double? searchBorderRadius;

  ///[emptyStateTextStyle] provides styling for text to indicate user list is empty
  final TextStyle? emptyStateTextStyle;

  ///[errorStateTextStyle] provides styling for text to indicate some error has occurred while fetching the user list
  final TextStyle? errorStateTextStyle;
}
