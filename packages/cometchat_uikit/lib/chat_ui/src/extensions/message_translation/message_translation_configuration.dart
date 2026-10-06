import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

///[MessageTranslationConfiguration] configured the v5 message translation extension. No v6 API accepts it:
/// the extension is enabled from the CometChat Dashboard, and the
/// deprecation message names the components that now configure what it
/// described.
@Deprecated(
  'Has no effect: no v6 API accepts it. The Translate option shows while the message-translation extension is enabled; hide it with CometChatMessageList.hideTranslateMessageOption, style it with CometChatMessageListStyle.messageOptionSheetStyle, and style the translation with CometChatIncomingMessageBubbleStyle.messageTranslationBubbleStyle and CometChatOutgoingMessageBubbleStyle.messageTranslationBubbleStyle. Will be removed in 7.0.0.',
)
class MessageTranslationConfiguration {
  /// Creates a [MessageTranslationConfiguration].
  MessageTranslationConfiguration({
    this.optionTitle,
    this.optionIcon,
    this.optionStyle,
    this.style,
  });

  ///[style] provides style
  final CometChatMessageTranslationBubbleStyle? style;

  ///[optionTitle] is the name for the option for this extension
  final String? optionTitle;

  ///[optionIcon] is the path to the icon image for the option for this extension
  final Widget? optionIcon;

  ///[optionStyle] provides style to the option
  final MessageTranslationOptionStyle? optionStyle;
}
