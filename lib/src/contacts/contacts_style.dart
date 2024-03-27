import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[ContactsStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatContacts]
class ContactsStyle extends BaseStyles {
  const ContactsStyle({
    this.titleTextStyle,
    this.borderColor,
    this.closeIconTint,
    this.createIconTint,
    this.selectedTabColor,
    this.tabColor,
    this.selectedTabTextStyle,
    this.tabTextStyle,
    this.theme,
    this.tabBorderRadius,
    this.activeIconTint,
    this.activeTabColor,
    this.activeTabTitleTextStyle,
    this.iconTint,
    this.tabBorder,
    this.tabHeight,
    this.tabWidth,
    double? width,
    double? height,
    Color? background,
    BoxBorder? border,
    double? borderRadius,
    Gradient? gradient,
  }) : super(
            width: width,
            height: height,
            background: background,
            border: border,
            borderRadius: borderRadius,
            gradient: gradient);

  ///[closeIconTint] provides color to back icon
  final Color? closeIconTint;

  ///[createIconTint] provides color to create icon
  final Color? createIconTint;

  ///[titleTextStyle] provides styling for title text
  final TextStyle? titleTextStyle;

  ///[selectedTabColor] provides color to the active/selected tab
  final Color? selectedTabColor;

  ///[tabColor] provides color to the inactive/unselected tabs
  final Color? tabColor;

  ///[selectedTabTextStyle] provides styling for the text in the active/selected tab
  final TextStyle? selectedTabTextStyle;

  ///[tabTextStyle] provides styling for the text in the inactive/unselected tab
  final TextStyle? tabTextStyle;

  ///[borderColor] provides color to border
  final Color? borderColor;

  ///[activeTabColor] provides color to the active/selected tabs
  final Color? activeTabColor;

  ///[iconTint] provides color to icon
  final Color? iconTint;

  ///[activeIconTint] provides color to active/selected icon
  final Color? activeIconTint;

  ///[theme] provides theme
  final Theme? theme;

  ///[activeTabTitleTextStyle] provides styling for active title text
  final TextStyle? activeTabTitleTextStyle;

  ///[tabBorder] provides border to tab box
  final double? tabBorder;

  ///[tabHeight] provides height to tab box
  final double? tabHeight;

  ///[tabWidth] provides width to tab box
  final double? tabWidth;

  ///[tabBorderRadius] provides borderRadius to tab box
  final double? tabBorderRadius;
}
