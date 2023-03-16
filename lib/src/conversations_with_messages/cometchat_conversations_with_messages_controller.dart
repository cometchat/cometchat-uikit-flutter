import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class CometChatConversationsWithMessagesController extends GetxController
    with CometChatMessageEventListener, CometChatConversationEventListener {
  CometChatConversationsWithMessagesController(
      {this.messageConfiguration, this.theme});

  ///[messageConfiguration] CometChatMessage configurations
  final MessageConfiguration? messageConfiguration;

  ///[theme] custom theme
  final CometChatTheme? theme;

  late String _dateString;

  late BuildContext context;
  //Class Variables------
  final String messageEventListenerId = "CWMMessageListener";
  final String conversationEventListenerId = "CWMConversationListener";

  //Class variables end-----

  @override
  void onInit() {
    super.onInit();
    _dateString = DateTime.now().millisecondsSinceEpoch.toString();
    CometChatMessageEvents.addMessagesListener(
        _dateString + messageEventListenerId, this);
    CometChatConversationEvents.addConversationListListener(
        _dateString + conversationEventListenerId, this);
  }

  @override
  void onClose() {
    CometChatMessageEvents.removeMessagesListener(
        _dateString + messageEventListenerId);
    CometChatConversationEvents.removeConversationListListener(
        _dateString + conversationEventListenerId);
    super.onClose();
  }

  void onItemTap(Conversation conversation) {
    User? user;
    Group? group;
    if (conversation.conversationType == ReceiverTypeConstants.user) {
      user = (conversation.conversationWith as User);
    } else if (conversation.conversationType == ReceiverTypeConstants.group) {
      group = (conversation.conversationWith as Group);
    }

    navigateToMessagesScreen(user: user, group: group);
  }

  void navigateToMessagesScreen(
      {User? user, Group? group, BuildContext? context}) {
    Navigator.push(
        context ?? this.context,
        MaterialPageRoute(
          builder: (context) => CometChatMessages(
            user: user,
            group: group,
            theme: messageConfiguration?.theme ?? theme,
            messageComposerConfiguration:
                messageConfiguration?.messageComposerConfiguration ??
                    const MessageComposerConfiguration(),
            messageListConfiguration:
                messageConfiguration?.messageListConfiguration ??
                    const MessageListConfiguration(),
            messageHeaderConfiguration:
                messageConfiguration?.messageHeaderConfiguration ??
                    const MessageHeaderConfiguration(),
            customSoundForIncomingMessagePackage:
                messageConfiguration?.customSoundForIncomingMessagePackage,
            customSoundForIncomingMessages:
                messageConfiguration?.customSoundForIncomingMessages,
            customSoundForOutgoingMessagePackage:
                messageConfiguration?.customSoundForOutgoingMessagePackage,
            customSoundForOutgoingMessages:
                messageConfiguration?.customSoundForOutgoingMessages,
            detailsConfiguration: messageConfiguration?.detailsConfiguration,
            disableSoundForMessages:
                messageConfiguration?.disableSoundForMessages,
            disableTyping: messageConfiguration?.disableTyping ?? false,
            hideMessageComposer:
                messageConfiguration?.hideMessageComposer ?? false,
            hideMessageHeader: messageConfiguration?.hideMessageHeader,
            messageComposerView: messageConfiguration?.messageComposerView,
            messageHeaderView: messageConfiguration?.messageHeaderView,
            messageListView: messageConfiguration?.messageListView,
            messagesStyle: messageConfiguration?.messagesStyle,
            threadedMessagesConfiguration:
                messageConfiguration?.threadedMessagesConfiguration,
            hideDetails: messageConfiguration?.hideDetails,
          ),
        )).then((value) {
      if (value != null && value > 0) {
        Navigator.of(context ?? this.context).pop(value - 1);
      }
    });
  }
}
