import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[JoinProtectedGroupConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [CometChatJoinProtectedGroup]
///can be used by a component where [CometChatJoinProtectedGroup] is a child component
/// ```dart
/// JoinProtectedGroupConfiguration(
///          joinProtectedGroupStyle: JoinProtectedGroupStyle(),
///          passwordPlaceholderText: "some password",
///          description: "some description"
///         );
/// ```
class JoinProtectedGroupConfiguration {
  const JoinProtectedGroupConfiguration(
      {this.closeIcon,
      this.joinIcon,
      this.joinProtectedGroupStyle,
      this.theme,
      this.onJoinTap,
      this.passwordPlaceholderText,
      this.title,
      this.description,
      this.errorStateText,
      this.onBack,
      this.onError});

  ///[closeIcon] replace back button
  final Widget? closeIcon;

  ///[joinIcon] replace create icon
  final Widget? joinIcon;

  ///[joinProtectedGroupStyle] set styling properties
  final JoinProtectedGroupStyle? joinProtectedGroupStyle;

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

  ///[errorStateText] text to show if any error occurs when joining the group
  final String? errorStateText;

  JoinProtectedGroupConfiguration merge(
      JoinProtectedGroupConfiguration mergeWith) {
    return JoinProtectedGroupConfiguration(
      closeIcon: closeIcon ?? mergeWith.closeIcon,
      joinIcon: joinIcon ?? mergeWith.joinIcon,
      joinProtectedGroupStyle:
          joinProtectedGroupStyle ?? mergeWith.joinProtectedGroupStyle,
      theme: theme ?? mergeWith.theme,
      onJoinTap: onJoinTap ?? mergeWith.onJoinTap,
      passwordPlaceholderText:
          passwordPlaceholderText ?? mergeWith.passwordPlaceholderText,
      title: title ?? mergeWith.title,
      description: description ?? mergeWith.description,
      errorStateText: errorStateText ?? mergeWith.errorStateText,
      onBack: onBack ?? mergeWith.onBack,
      onError: onError ?? mergeWith.onError,
    );
  }
}
