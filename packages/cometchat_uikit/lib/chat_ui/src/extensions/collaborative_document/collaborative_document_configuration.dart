import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CollaborativeDocumentConfiguration] configured the v5 collaborative document extension. No v6 API accepts it:
/// the extension is enabled from the CometChat Dashboard, and the
/// deprecation message names the components that now configure what it
/// described.
@Deprecated(
  'No API in v6 accepts an extension configuration object; the collaborative document extension is enabled from the CometChat Dashboard. Style the bubble with collaborativeDocumentBubbleStyle on CometChatIncomingMessageBubbleStyle and CometChatOutgoingMessageBubbleStyle, replace or hide the composer\'s option with CometChatMessageComposer.attachmentOptions (id ExtensionType.document) or hideCollaborativeDocumentOption, and style the option sheet with CometChatMessageComposerStyle.attachmentOptionSheetStyle. The bubble\'s title, subtitle, icon and button text have no replacement. Will be removed in 7.0.0.',
)
class CollaborativeDocumentConfiguration {
  /// Creates a [CollaborativeDocumentConfiguration].
  CollaborativeDocumentConfiguration({
    this.title,
    this.subtitle,
    this.icon,
    this.buttonText,
    this.style,
    this.optionTitle,
    this.collaborativeDocumentOptionStyle,
    this.optionIcon,
  });

  ///[title] title to be displayed , default is 'Collaborative Document'
  final String? title;

  ///[subtitle] subtitle to be displayed , default is 'Open document to edit content together'
  final String? subtitle;

  ///[icon] document icon to be shown on bubble
  final Widget? icon;

  ///[buttonText] button text to be shown , default is 'Open Document'
  final String? buttonText;

  ///[style] document bubble styling properties
  final CometChatCollaborativeBubbleStyle? style;

  ///[optionTitle] is the name for the option for this extension
  final String? optionTitle;

  ///[optionIcon] is the icon for the option for this extension
  final Widget? optionIcon;

  ///[collaborativeDocumentOptionStyle] provides style to the option that generates a collaborative document
  final CollaborativeDocumentOptionStyle? collaborativeDocumentOptionStyle;
}
