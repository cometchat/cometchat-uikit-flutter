import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

///[CometChatUsersWithMessages] is a container component that wraps and formats the [CometChatUsers] and [CometChatMessages] component
///
/// it list down users according to different parameter set in order of recent activity and opens message by default on click
///
/// ```dart
/// CometChatUsersWithMessages(
///              usersConfiguration: UsersConfiguration(
///                userListConfiguration:
///                    UserListConfiguration(
///                        dataItemConfiguration:
///       DataItemConfiguration<User>(
///           inputData: InputData(
///               subtitle: (User user) {
///                             return user.uid;
///                 }))),
///              ),
///            )
///
/// ```

class CometChatUsersWithMessages extends StatefulWidget {
  const CometChatUsersWithMessages(
      {Key? key,
      this.theme,
      this.usersConfiguration = const UsersConfiguration(),
      this.messageConfiguration = const MessageConfiguration()})
      : super(key: key);

  ///[theme] can pass custom theme
  final CometChatTheme? theme;

  ///[usersConfiguration] CometChatUsers configurations
  final UsersConfiguration usersConfiguration;

  ///[messageConfiguration] CometChatMessage configurations
  final MessageConfiguration messageConfiguration;

  @override
  State<CometChatUsersWithMessages> createState() =>
      _CometChatUsersWithMessagesState();
}

class _CometChatUsersWithMessagesState extends State<CometChatUsersWithMessages>
    with CometChatUserListener {
  @override
  void initState() {
    super.initState();
    CometChatUserEvents.addUsersListener(
        "cometchat_users_with_messages_user_listener", this);
  }

  @override
  void dispose() {
    super.dispose();
    CometChatUserEvents.removeUsersListener(
        "cometchat_users_with_messages_user_listener");
  }

  @override
  void onUserTap(User user) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CometChatMessages(
                  user: user.uid,
                  theme: widget.theme,
                  enableTypingIndicator:
                      widget.messageConfiguration.enableTypingIndicator,
                  enableSoundForMessages:
                      widget.messageConfiguration.enableSoundForMessages,
                  hideMessageComposer:
                      widget.messageConfiguration.hideMessageComposer,
                  messageHeaderConfiguration:
                      widget.messageConfiguration.messageHeaderConfiguration,
                  messageListConfiguration:
                      widget.messageConfiguration.messageListConfiguration,
                  messageComposerConfiguration:
                      widget.messageConfiguration.messageComposerConfiguration,
                )));
  }

  @override
  Widget build(BuildContext context) {
    return CometChatUsers(
      theme: widget.theme,
      title: widget.usersConfiguration.title,
      showBackButton: widget.usersConfiguration.showBackButton,
      activeUser: widget.usersConfiguration.activeUser,
      hideSearch: widget.usersConfiguration.hideSearch,
      searchPlaceholder: widget.usersConfiguration.searchPlaceholder,
      userListConfiguration: widget.usersConfiguration.userListConfiguration,
    );
  }
}
