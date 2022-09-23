import '../../../flutter_chat_ui_kit.dart';

///Configuration class for [CometChatMessages]
///
/// ```dart
///   MessageConfiguration(
///       enableSoundForMessages: true,
///       enableTypingIndicator: true,
///       hideMessageComposer: false,
///       messageListConfiguration: MessageListConfiguration(),
///       messageBubbleConfiguration: MessageBubbleConfiguration(),
///       messageComposerConfiguration: MessageComposerConfiguration(),
///       messageHeaderConfiguration: MessageHeaderConfiguration()
///     )
///
/// ```
///
class MessageConfiguration {
  const MessageConfiguration(
      {this.enableTypingIndicator = true,
      this.enableSoundForMessages = true,
      this.hideMessageComposer = false,
      this.messageHeaderConfiguration = const MessageHeaderConfiguration(),
      this.messageListConfiguration = const MessageListConfiguration(),
      this.messageComposerConfiguration = const MessageComposerConfiguration(),
      this.messageTypes,
      this.excludeMessageTypes});

  ///[hideMessageComposer] is true then hide message composer
  final bool hideMessageComposer;

  ///[enableTypingIndicator] if true then enables is typing indicator
  final bool enableTypingIndicator;

  ///[enableSoundForMessages] if true then enables outgoing message sound
  final bool enableSoundForMessages;

  ///[messageHeaderConfiguration] set configuration properties for [CometChatMessageHeader]
  final MessageHeaderConfiguration messageHeaderConfiguration;

  ///[messageListConfiguration] set configuration properties for [CometChatMessageList]
  final MessageListConfiguration messageListConfiguration;

  ///[messageComposerConfiguration] set configuration properties for [CometChatMessageComposer]
  final MessageComposerConfiguration messageComposerConfiguration;

  ///[messageTypes]  takes list of [CometChatMessageTemplate] to be included
  final List<CometChatMessageTemplate>? messageTypes;

  ///[excludeMessageTypes] excludes list of message types
  final List<String>? excludeMessageTypes;
}
