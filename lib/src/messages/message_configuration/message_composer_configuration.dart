import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

///Configuration class for [CometChatMessageComposer]
///
/// ```dart
///   MessageComposerConfiguration(
///                   customOutgoingMessageSound: 'asset url',
///                   excludeMessageTypes: [CometChatUIMessageTypes.image],
///                   messageTypes: [
///                     TemplateUtils.getDefaultAudioTemplate(),
///                     TemplateUtils.getDefaultTextTemplate(),
///                     CometChatMessageTemplate(type: 'custom', name: 'custom')
///                   ],
///                   hideEmoji: false,
///                   hideAttachment: false,
///                   hideLiveReaction: false,
///                   showSendButton: true,
///                   placeholderText: 'Message',
///
///         )
///
/// ```
class MessageComposerConfiguration {
  const MessageComposerConfiguration(
      {this.placeholderText,
      this.hideAttachment = false,
      this.hideMicrophone = false,
      this.hideLiveReaction = false,
      this.hideEmoji = false,
      this.showSendButton = true,
      this.customOutgoingMessageSound,
      this.messageTypes,
      this.excludeMessageTypes,
      this.onSendButtonClick});

  ///[placeholderText] hint text
  final String? placeholderText;

  ///[hideAttachment] if true hides attachments options
  final bool hideAttachment;

  ///[hideMicrophone] if true hides microphone option
  final bool hideMicrophone;

  ///[hideLiveReaction] if true hides live reaction option
  final bool hideLiveReaction;

  ///[hideEmoji] if true hides emoji option
  final bool hideEmoji;

  ///[showSendButton] show back button
  final bool showSendButton;

  ///[customOutgoingMessageSound] custom outgoing message sound assets url
  final String? customOutgoingMessageSound;

  ///[messageTypes] takes list of [CometChatMessageTemplate] to be included
  final List<CometChatMessageTemplate>? messageTypes;

  ///[excludeMessageTypes] excludes list of message types
  final List<String>? excludeMessageTypes;

  ///[onSendButtonClick] callback on send button click
  final Function()? onSendButtonClick;
}
