import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CollaborativeWhiteBoardConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [CollaborativeWhiteBoardExtension]
/// ```dart
///  CollaborativeWhiteboardConfiguration(
///    title: "Collaborative Editing",
///    subtitle: "Open a document to edit together",
///    buttonText: "Open",
///    optionTitle: "Collaborative Whiteboard",
///    optionIconUrl: "assets/images/collaborative_whiteboard.png",
///    optionIconUrlPackageName: "my_package",
///    optionStyle: CollaborativeWhiteboardOptionStyle(
///    background: Colors.green,
///    iconTint: Colors.red,
///    titleStyle: TextStyle(color: Colors.white)
///    )
///   );
/// ```
///
class CollaborativeWhiteBoardConfiguration {
  CollaborativeWhiteBoardConfiguration(
      {this.title,
      this.subtitle,
      this.icon,
      this.buttonText,
      this.style,
      this.theme,
      this.optionTitle,
      this.optionIconUrl,
      this.optionIconUrlPackageName,
      this.optionStyle});

  ///[title] title to be displayed default is 'Collaborative Whiteboard'
  final String? title;

  ///[subtitle] subtitle to be displayed default is 'Open whiteboard to draw together'
  final String? subtitle;

  ///[icon] document icon to be shown on bubble
  final Widget? icon;

  ///[buttonText] button text to be shown default is 'Open Whiteboard'
  final String? buttonText;

  ///[style] whiteboard bubble styling properties
  final WhiteBoardBubbleStyle? style;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[optionTitle] is the name for the option for this extension
  final String? optionTitle;

  ///[optionIconUrl] is the path to the icon image for the option for this extension
  final String? optionIconUrl;

  ///[optionIconUrlPackageName] is the name of the package where the icon for the option for this extension is located
  final String? optionIconUrlPackageName;

  ///[optionStyle] provides style to the option that generates a collaborative whiteboard
  final CollaborativeWhiteboardOptionStyle? optionStyle;
}
