import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class JoinProtectedGroupConfiguration {
  const JoinProtectedGroupConfiguration(
      {this.closeIcon,
      this.joinIcon,
      this.style,
      this.theme,
      this.onJoinTap,
      this.passwordPlaceholderText,
      this.title,
      this.description,
      this.onBack,
    this.onError});

  ///[closeIcon] replace back button
  final Widget? closeIcon;

  ///[joinIcon] replace create icon
  final Widget? joinIcon;

  ///[style] set styling properties
  final JoinProtectedGroupStyle? style;

  ///[theme] set custom theme
  final CometChatTheme? theme;

  ///[passwordPlaceholderText] placeholder for password input field
  final String? passwordPlaceholderText;

  ///[onJoinTap] triggered on join group icon tap
  final Function({Group group, String password})? onJoinTap;

  ///[title] sets title of the component
  final String? title;

  ///[description] sets title of the component
  final String? description;

  ///[onError] callback triggered in case any error happens when fetching users
  final OnError? onError;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;
}
