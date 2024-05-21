import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[BannedMembersStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatBannedMembers]
class BannedMembersStyle extends BaseStyles {
  const BannedMembersStyle({
    this.titleStyle,
    this.backIconTint,
    this.searchBorderColor,
    this.searchBackground,
    this.searchBorderRadius,
    this.searchIconTint,
    this.searchBorderWidth,
    this.searchPlaceholderStyle,
    this.searchStyle,
    this.loadingIconTint,
    this.emptyTextStyle,
    this.errorTextStyle,
    this.sectionHeaderTextStyle,
    this.tailTextStyle,
    this.onlineStatusColor,
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

  ///[searchStyle] provides styling for text inside the search box
  final TextStyle? searchStyle;

  ///[titleStyle] provides styling for text inside the placeholder
  final TextStyle? searchPlaceholderStyle;

  ///[searchIconTint] provides color to search button
  final Color? searchIconTint;

  ///[loadingIconTint] provides color to loading icon
  final Color? loadingIconTint;

  ///[emptyTextStyle] provides styling for text to indicate banned member list is empty
  final TextStyle? emptyTextStyle;

  ///[errorTextStyle] provides styling for text to indicate some error has occurred while fetching the banned member list
  final TextStyle? errorTextStyle;

  ///[sectionHeaderTextStyle] provides styling for text separating banned members alphabetically
  final TextStyle? sectionHeaderTextStyle;

  ///[tailTextStyle] provides styling to the text in the trailing widget
  final TextStyle? tailTextStyle;

  ///[onlineStatusColor] set online status color
  final Color? onlineStatusColor;
}
