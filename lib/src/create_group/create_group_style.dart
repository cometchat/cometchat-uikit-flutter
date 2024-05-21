import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CreateGroupStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatCreateGroup]
class CreateGroupStyle extends BaseStyles {
  const CreateGroupStyle({
    this.titleTextStyle,
    this.borderColor,
    this.closeIconTint,
    this.createIconTint,
    this.selectedTabColor,
    this.tabColor,
    this.selectedTabTextStyle,
    this.tabTextStyle,
    this.namePlaceholderTextStyle,
    this.passwordPlaceholderTextStyle,
    this.nameInputTextStyle,
    this.passwordInputTextStyle,
    super.width,
    super.height,
    super.background,
    super.border,
    super.borderRadius,
    super.gradient,
  });

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

  ///[namePlaceholderTextStyle] provides styling for the hint text in the name text input field
  final TextStyle? namePlaceholderTextStyle;

  ///[passwordPlaceholderTextStyle] provides styling for the hint text in the password text input field
  final TextStyle? passwordPlaceholderTextStyle;

  ///[nameInputTextStyle] provides styling for the text in the name input field
  final TextStyle? nameInputTextStyle;

  ///[passwordInputTextStyle] provides styling for the text in the password input field
  final TextStyle? passwordInputTextStyle;
}
