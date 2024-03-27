import '../../cometchat_chat_uikit.dart';

///[ConversationsWithMessagesConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [CometChatConversationsWithMessages]
///can be used by a component where [CometChatConversationsWithMessages] is a child component
class ConversationsWithMessagesConfiguration {
  const ConversationsWithMessagesConfiguration(
      {this.theme, this.conversationConfigurations, this.messageConfiguration});

  final CometChatTheme? theme;

  final ConversationsConfiguration? conversationConfigurations;

  final MessageConfiguration? messageConfiguration;
}
