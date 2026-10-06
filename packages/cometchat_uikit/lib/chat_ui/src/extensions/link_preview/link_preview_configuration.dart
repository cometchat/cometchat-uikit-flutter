import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[LinkPreviewConfiguration] configured the v5 link preview extension. No v6 API accepts it:
/// the extension is enabled from the CometChat Dashboard, and the
/// deprecation message names the components that now configure what it
/// described.
@Deprecated(
  'No API in v6 accepts an extension configuration object; link previews come from the Dashboard-enabled extension. Style them with linkPreviewBubbleStyle on CometChatIncomingMessageBubbleStyle and CometChatOutgoingMessageBubbleStyle. defaultImage has no replacement: a preview without an image shows none. Will be removed in 7.0.0.',
)
class LinkPreviewConfiguration {
  /// Creates a [LinkPreviewConfiguration].
  LinkPreviewConfiguration({this.defaultImage, this.style});

  ///[defaultImage] is shown unable to generate image from link
  final Widget? defaultImage;

  ///[style] provides style to the link preview bubble
  final CometChatLinkPreviewBubbleStyle? style;
}
