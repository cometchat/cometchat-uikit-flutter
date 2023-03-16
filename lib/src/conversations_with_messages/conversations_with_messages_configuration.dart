import '../../flutter_chat_ui_kit.dart';

class ConversationsWithMessagesConfiguration {
  const ConversationsWithMessagesConfiguration(
      {this.theme, this.conversationConfigurations, this.messageConfiguration});

  final CometChatTheme? theme;

  final ConversationsConfiguration? conversationConfigurations;

  final MessageConfiguration? messageConfiguration;
}
