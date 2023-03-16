import '../../flutter_chat_ui_kit.dart';

class UsersWithMessagesConfiguration {
  const UsersWithMessagesConfiguration(
      {this.usersConfiguration, this.messageConfiguration, this.theme});

  ///[usersConfiguration] CometChatUsers configurations
  final UsersConfiguration? usersConfiguration;

  ///[messageConfiguration] CometChatMessage configurations
  final MessageConfiguration? messageConfiguration;

  ///[theme] can pass custom theme
  final CometChatTheme? theme;

}
