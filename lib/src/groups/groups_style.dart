import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[GroupsStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatGroups]
class GroupsStyle extends BaseStyles {
  const GroupsStyle({
    this.titleStyle,
    this.backIconTint,
    this.searchBorderColor,
    this.searchBackground,
    this.searchBorderRadius,
    this.searchBorderWidth,
    this.searchTextStyle,
    this.searchPlaceholderStyle,
    this.searchIconTint,
    this.loadingIconTint,
    this.emptyTextStyle,
    this.errorTextStyle,
    super.width,
    super.height,
    super.background,
    super.border,
    super.borderRadius,
    super.gradient,
    this.subtitleTextStyle,
    this.privateGroupIconBackground,
    this.passwordGroupIconBackground,
    this.selectionIconTint,
    this.submitIconTint,
  });

  ///[titleStyle] provides styling for title text
  final TextStyle? titleStyle;

  ///[backIconTint] provides color for the back icon
  final Color? backIconTint;

  ///[searchBorderColor] provides color for the border around the search box
  final Color? searchBorderColor;

  ///[searchBackground] provides color for the search box
  final Color? searchBackground;

  ///[searchBorderRadius] provides radius for the border around the search box
  final double? searchBorderRadius;

  ///[searchBorderWidth] provides width to the border around the search box
  final double? searchBorderWidth;

  ///[searchTextStyle] provides styling for text inside the search box
  final TextStyle? searchTextStyle;

  ///[searchPlaceholderStyle] provides styling for the hint text inside the search box
  final TextStyle? searchPlaceholderStyle;

  ///[searchIconTint] provides color for the search icon
  final Color? searchIconTint;

  ///[loadingIconTint] provides color to loading icon
  final Color? loadingIconTint;

  ///[emptyTextStyle] provides styling for text to indicate group list is empty
  final TextStyle? emptyTextStyle;

  ///[errorTextStyle] provides styling for text to indicate some error has occurred while fetching the group list
  final TextStyle? errorTextStyle;

  ///[subtitleTextStyle] provides styling to the text in the subtitle
  final TextStyle? subtitleTextStyle;

  ///[privateGroupIconBackground] provides color to the icon for private group
  final Color? privateGroupIconBackground;

  ///[privateGroupIconBackground] provides color to the icon for password protected group
  final Color? passwordGroupIconBackground;

  ///[selectionIconTint] set selection icon color
  final Color? selectionIconTint;

  ///[submitIconTint] set submit icon tint
  final Color? submitIconTint;
}
