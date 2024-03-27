import '../../cometchat_chat_uikit.dart';

///[UsersWithMessagesConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [CometChatUsersWithMessages]
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
