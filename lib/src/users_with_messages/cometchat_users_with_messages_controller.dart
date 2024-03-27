import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CometChatUsersWithMessagesController] is the view model for [CometChatUsersWithMessages]
///it contains all the business logic involved in changing the state of the UI of [CometChatUsersWithMessages]
class CometChatUsersWithMessagesController extends GetxController
    with CometChatMessageEventListener {
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
  late String _dateString;
  late String _messageEventListenerId;

  late BuildContext context;

  void onItemTap(BuildContext context, User user) {
    if (user.hasBlockedMe == false) {
      navigateToMessagesScreen(user: user);
    }
  }

  @override
  void onInit() {
    super.onInit();
    _dateString = DateTime.now().millisecondsSinceEpoch.toString();
    _messageEventListenerId = "${_dateString}UWMGMessageListener";
    CometChatMessageEvents.addMessagesListener(_messageEventListenerId, this);
  }

  @override
  void onClose() {
    super.onClose();
    CometChatMessageEvents.removeMessagesListener(_messageEventListenerId);
  }

  @override
  void ccMessageForwarded(BaseMessage message, List<User>? usersSent,
      List<Group>? groupsSent, MessageStatus status) {
    if (status == MessageStatus.inProgress) return;

    if (((usersSent?.length ?? 0) + (groupsSent?.length ?? 0)) == 1) {
      if (usersSent != null && usersSent.isNotEmpty) {
        navigateToMessagesScreen(user: usersSent[0]);
      } else {
        navigateToMessagesScreen(group: groupsSent![0]);
      }
    }
  }

  //----------User Event Listeners--------------

  void navigateToMessagesScreen(
      {User? user, Group? group, BuildContext? context}) {
    Navigator.push(
        context ?? this.context,
        MaterialPageRoute(
            builder: (context) => CometChatMessages(
                  user: user,
                  group: group,
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
