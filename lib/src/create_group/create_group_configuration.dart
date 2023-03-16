import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class CreateGroupConfiguration {
  const CreateGroupConfiguration(
      {this.title,
      this.createIcon,
      this.namePlaceholderText,
      this.closeIcon,
      this.disableCloseButton,
      this.onCreateTap,
      this.onError,
      this.onBack,
      this.style,
      this.theme,
      this.passwordPlaceholderText});

  ///[title] Title of the component
  final String? title;

  ///[createIcon] create icon
  final Widget? createIcon;

  ///[createIcon] create icon
  final Widget? closeIcon;

  ///[namePlaceholderText] group name input placeholder
  final String? namePlaceholderText;

  ///[disableCloseButton] toggle visibility for close button
  final bool? disableCloseButton;

  ///[passwordPlaceholderText] group password input placeholder
  final String? passwordPlaceholderText;

  ///[theme] instance of cometchat theme
  final CometChatTheme? theme;

  ///[onCreateTap] triggered on create group icon click
  final Function(Group group)? onCreateTap;

  ///[style] styling properties
  final CreateGroupStyle? style;

  ///[onError] triggered in case of any error
  final OnError? onError;

  ///[onError] triggered in case of any error
  final VoidCallback? onBack;
}
