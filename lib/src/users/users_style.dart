import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[UsersStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatUsers]
class UsersStyle extends BaseStyles {
  const UsersStyle({
    this.titleStyle,
    this.backIconTint,
    this.searchBorderColor,
    this.searchBackground,
    this.searchBorderRadius,
    this.searchIconTint,
    this.searchBorderWidth,
    this.searchPlaceholderStyle,
    this.searchTextStyle,
    this.loadingIconTint,
    this.emptyTextStyle,
    this.errorTextStyle,
    this.sectionHeaderTextStyle,
    this.onlineStatusColor,
    this.separatorColor,
    this.selectionIconTint,
    this.submitIconTint,
    super.width,
    super.height,
    super.background,
    super.border,
    super.borderRadius,
    super.gradient,
  });

  ///[titleStyle] provides styling for title text
  final TextStyle? titleStyle;

  ///[backIconTint] provides color to close button
  final Color? backIconTint;

  ///[searchBorderColor] provides color to border of search box
  final Color? searchBorderColor;

  ///[searchBackground] provides color to background of search box
  final Color? searchBackground;

  ///[searchBorderRadius] provides radius to border of search box
  final double? searchBorderRadius;

  ///[searchBorderWidth] provides width to border of search box
  final double? searchBorderWidth;

  ///[searchTextStyle] provides styling for text inside the search box
  final TextStyle? searchTextStyle;

  ///[titleStyle] provides styling for text inside the placeholder
  final TextStyle? searchPlaceholderStyle;

  ///[searchIconTint] provides color to search button
  final Color? searchIconTint;

  ///[loadingIconTint] provides color to loading icon
  final Color? loadingIconTint;

  ///[emptyTextStyle] provides styling for text to indicate user list is empty
  final TextStyle? emptyTextStyle;

  ///[errorTextStyle] provides styling for text to indicate some error has occurred while fetching the user list
  final TextStyle? errorTextStyle;

  ///[sectionHeaderTextStyle] provides styling for text separating users alphabetically
  final TextStyle? sectionHeaderTextStyle;

  ///[onlineStatusColor] set online status color
  final Color? onlineStatusColor;

  ///[separatorColor] set separator color
  final Color? separatorColor;

  ///[selectionIconTint] set selection icon color
  final Color? selectionIconTint;

  ///[submitIconTint] set submit icon tint
  final Color? submitIconTint;
}
