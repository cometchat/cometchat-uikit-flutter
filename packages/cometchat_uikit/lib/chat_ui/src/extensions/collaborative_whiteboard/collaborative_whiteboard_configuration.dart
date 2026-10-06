import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CollaborativeWhiteBoardConfiguration] configured the v5 collaborative whiteboard extension. No v6 API accepts it:
/// the extension is enabled from the CometChat Dashboard, and the
/// deprecation message names the components that now configure what it
/// described.
@Deprecated(
  'No API in v6 accepts an extension configuration object; the collaborative whiteboard extension is enabled from the CometChat Dashboard. Style the bubble with collaborativeWhiteboardBubbleStyle on CometChatIncomingMessageBubbleStyle and CometChatOutgoingMessageBubbleStyle, replace or hide the composer\'s option with CometChatMessageComposer.attachmentOptions (id ExtensionType.whiteboard) or hideCollaborativeWhiteboardOption, and style the option sheet with CometChatMessageComposerStyle.attachmentOptionSheetStyle. The bubble\'s title, subtitle, icon and button text have no replacement. Will be removed in 7.0.0.',
)
class CollaborativeWhiteBoardConfiguration {
  /// Creates a [CollaborativeWhiteBoardConfiguration].
  CollaborativeWhiteBoardConfiguration({
    this.title,
    this.subtitle,
    this.icon,
    this.buttonText,
    this.style,
    this.optionTitle,
    this.optionIcon,
    this.optionStyle,
  });

  ///[title] title to be displayed default is 'Collaborative Whiteboard'
  final String? title;

  ///[subtitle] subtitle to be displayed default is 'Open whiteboard to draw together'
  final String? subtitle;

  ///[icon] document icon to be shown on bubble
  final Widget? icon;

  ///[buttonText] button text to be shown default is 'Open Whiteboard'
  final String? buttonText;

  ///[style] whiteboard bubble styling properties
  final CometChatCollaborativeBubbleStyle? style;

  ///[optionTitle] is the name for the option for this extension
  final String? optionTitle;

  ///[optionIcon] is the icon for the option for this extension
  final Widget? optionIcon;

  ///[optionStyle] provides style to the option that generates a collaborative whiteboard
  final CollaborativeWhiteboardOptionStyle? optionStyle;
}
