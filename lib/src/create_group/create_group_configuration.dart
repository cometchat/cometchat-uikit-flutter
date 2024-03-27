import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CreateGroupConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [CometChatCreateGroup]
///can be used by a component where [CometChatCreateGroup] is a child component
/// ```dart
///  CreateGroupConfiguration(
///          createGroupStyle: CreateGroupStyle(),
///          namePlaceholderText: "some name",
///          passwordPlaceholderText: "some password"
///          );
/// ```
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
      this.createGroupStyle,
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

  ///[createGroupStyle] styling properties
  final CreateGroupStyle? createGroupStyle;

  ///[onError] triggered in case of any error
  final OnError? onError;

  ///[onError] triggered in case of any error
  final VoidCallback? onBack;
}
