import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class CometChatUsersWithMessagesController extends GetxController {
  CometChatUsersWithMessagesController(
      {this.messageConfiguration, this.theme}) {
    tag = "tag$counter";
    counter++;
    debugPrint('uwm constructor of controller called');
  }

  ///[messageConfiguration] CometChatMessage configurations
  final MessageConfiguration? messageConfiguration;

  ///[theme] custom theme
  final CometChatTheme? theme;

  static int counter = 0;
  late String tag;

  late BuildContext context;

  void onItemTap(User user) {
    if (user.hasBlockedMe == false) {
      navigateToMessagesScreen(user: user);
    }
  }

  //----------User Event Listeners--------------

  void navigateToMessagesScreen({User? user, BuildContext? context}) {
    Navigator.push(
        context ?? this.context,
        MaterialPageRoute(
            builder: (context) => CometChatMessages(
                  user: user,
                  messageComposerConfiguration:
                      messageConfiguration?.messageComposerConfiguration ??
                          const MessageComposerConfiguration(),
                  messageListConfiguration:
                      messageConfiguration?.messageListConfiguration ??
                          const MessageListConfiguration(),
                  messageHeaderConfiguration:
                      messageConfiguration?.messageHeaderConfiguration ??
                          const MessageHeaderConfiguration(),
                  customSoundForIncomingMessagePackage: messageConfiguration
                      ?.customSoundForIncomingMessagePackage,
                  customSoundForIncomingMessages:
                      messageConfiguration?.customSoundForIncomingMessages,
                  customSoundForOutgoingMessagePackage: messageConfiguration
                      ?.customSoundForOutgoingMessagePackage,
                  customSoundForOutgoingMessages:
                      messageConfiguration?.customSoundForOutgoingMessages,
                  detailsConfiguration:
                      messageConfiguration?.detailsConfiguration,
                  disableSoundForMessages:
                      messageConfiguration?.disableSoundForMessages,
                  disableTyping: messageConfiguration?.disableTyping ?? false,
                  hideMessageComposer:
                      messageConfiguration?.hideMessageComposer ?? false,
                  hideMessageHeader: messageConfiguration?.hideMessageHeader,
                  messageComposerView:
                      messageConfiguration?.messageComposerView,
                  messageHeaderView: messageConfiguration?.messageHeaderView,
                  messageListView: messageConfiguration?.messageListView,
                  messagesStyle: messageConfiguration?.messagesStyle,
                  theme: messageConfiguration?.theme ?? theme,
                  threadedMessagesConfiguration:
                      messageConfiguration?.threadedMessagesConfiguration,
                  hideDetails: messageConfiguration?.hideDetails,
                )));
  }
}
