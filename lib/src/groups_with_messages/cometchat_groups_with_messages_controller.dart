import 'package:flutter/foundation.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CometChatGroupsWithMessagesController] is the view model for [CometChatGroupsWithMessages]
///it contains all the business logic involved in changing the state of the UI of [CometChatGroupsWithMessages]
class CometChatGroupsWithMessagesController extends GetxController
    with
        CometChatGroupEventListener,
        CometChatMessageEventListener,
        CometChatUIEventListener {
  CometChatGroupsWithMessagesController(
      {this.messageConfiguration,
      required this.theme,
      this.createGroupConfiguration,
      this.joinProtectedGroupConfiguration});

  ///[messageConfiguration] CometChatMessage configurations
  final MessageConfiguration? messageConfiguration;

  ///[theme] custom theme
  final CometChatTheme theme;

  ///[createGroupConfiguration] sets configuration for [CometChatCreateGroup]
  final CreateGroupConfiguration? createGroupConfiguration;

  ///[joinProtectedGroupConfiguration] sets configuration for [CometChatJoinProtectedGroup]
  final JoinProtectedGroupConfiguration? joinProtectedGroupConfiguration;

  late String _dateString;
  late String _groupsEventListenerId;
  late String _messageEventListenerId;

  late BuildContext context;

  @override
  void onInit() {
    super.onInit();
    _dateString = DateTime.now().millisecondsSinceEpoch.toString();
    _groupsEventListenerId = "${_dateString}GWMGroupListener";
    _messageEventListenerId = "${_dateString}GWMGMessageListener";
    CometChatGroupEvents.addGroupsListener(_groupsEventListenerId, this);
    CometChatMessageEvents.addMessagesListener(_messageEventListenerId, this);
    CometChatUIEvents.addUiListener(_groupsEventListenerId, this);
  }

  @override
  void onClose() {
    super.onClose();
    CometChatGroupEvents.removeGroupsListener(_groupsEventListenerId);
    CometChatMessageEvents.removeMessagesListener(_messageEventListenerId);
    CometChatUIEvents.removeUiListener(_groupsEventListenerId);
  }

  void onItemTap(BuildContext context, Group group) {
    if (group.hasJoined) {
      navigateToMessagesScreen(group: group);
    } else if (group.type == GroupTypeConstants.password) {
      navigateToJoinProtectedGroupScreen(group: group);
    } else if (group.type == GroupTypeConstants.public) {
      _joinGroup(guid: group.guid, groupType: group.type);
    }
  }

  @override
  void ccGroupMemberJoined(User joinedUser, Group joinedGroup) async {
    User? loggedInUser = await CometChat.getLoggedInUser();
    if (joinedUser.uid == loggedInUser?.uid) {
      navigateToMessagesScreen(group: joinedGroup);
    }
  }

  @override
  void ccGroupCreated(Group group) {
    navigateToMessagesScreen(group: group);
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

  @override
  void openChat(User? user, Group? group) {
    navigateToMessagesScreen(user: user, group: group);
  }

  void navigateToMessagesScreen(
      {User? user, Group? group, BuildContext? context}) {
    Navigator.push(
        context ?? this.context,
        MaterialPageRoute(
            builder: (context) => CometChatMessages(
                  group: group,
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
                ))).then((value) {
      if (value != null && value > 0) {
        Navigator.of(context ?? this.context).pop(value - 1);
      }
    });
  }

  void navigateToJoinProtectedGroupScreen(
      {required Group group, BuildContext? context}) {
    Navigator.push(
        context ?? this.context,
        MaterialPageRoute(
            builder: (context) => CometChatJoinProtectedGroup(
                  group: group,
                  onJoinTap: joinProtectedGroupConfiguration?.onJoinTap,
                  closeIcon: joinProtectedGroupConfiguration?.closeIcon,
                  joinIcon: joinProtectedGroupConfiguration?.joinIcon,
                  passwordPlaceholderText:
                      joinProtectedGroupConfiguration?.passwordPlaceholderText,
                  theme: joinProtectedGroupConfiguration?.theme ?? theme,
                  onError: joinProtectedGroupConfiguration?.onError,
                  title: joinProtectedGroupConfiguration?.title,
                  description: joinProtectedGroupConfiguration?.description,
                  joinProtectedGroupStyle:
                      joinProtectedGroupConfiguration?.joinProtectedGroupStyle,
                  onBack: joinProtectedGroupConfiguration?.onBack,
                  errorStateText:
                      joinProtectedGroupConfiguration?.errorStateText,
                )));
  }

  void navigateCreateGroup() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CometChatCreateGroup(
                  createGroupStyle: CreateGroupStyle(
                      titleTextStyle: createGroupConfiguration
                          ?.createGroupStyle?.titleTextStyle,
                      selectedTabColor: createGroupConfiguration
                          ?.createGroupStyle?.selectedTabColor,
                      selectedTabTextStyle: createGroupConfiguration
                          ?.createGroupStyle?.selectedTabTextStyle,
                      tabTextStyle: createGroupConfiguration
                          ?.createGroupStyle?.tabTextStyle,
                      closeIconTint: createGroupConfiguration
                          ?.createGroupStyle?.closeIconTint,
                      createIconTint: createGroupConfiguration
                          ?.createGroupStyle?.createIconTint,
                      tabColor:
                          createGroupConfiguration?.createGroupStyle?.tabColor,
                      background: createGroupConfiguration
                          ?.createGroupStyle?.background,
                      borderColor: createGroupConfiguration
                          ?.createGroupStyle?.borderColor,
                      border:
                          createGroupConfiguration?.createGroupStyle?.border,
                      borderRadius: createGroupConfiguration
                          ?.createGroupStyle?.borderRadius,
                      gradient:
                          createGroupConfiguration?.createGroupStyle?.gradient,
                      height:
                          createGroupConfiguration?.createGroupStyle?.height,
                      namePlaceholderTextStyle: createGroupConfiguration
                          ?.createGroupStyle?.namePlaceholderTextStyle,
                      nameInputTextStyle: createGroupConfiguration
                          ?.createGroupStyle?.nameInputTextStyle,
                      passwordPlaceholderTextStyle: createGroupConfiguration
                          ?.createGroupStyle?.passwordPlaceholderTextStyle,
                      passwordInputTextStyle: createGroupConfiguration
                          ?.createGroupStyle?.passwordInputTextStyle,
                      width: createGroupConfiguration?.createGroupStyle?.width),
                  createIcon: createGroupConfiguration?.createIcon,
                  theme: createGroupConfiguration?.theme ?? theme,
                  title: createGroupConfiguration?.title,
                  namePlaceholderText:
                      createGroupConfiguration?.namePlaceholderText,
                  closeIcon: createGroupConfiguration?.closeIcon,
                  disableCloseButton:
                      createGroupConfiguration?.disableCloseButton,
                  onCreateTap: createGroupConfiguration?.onCreateTap,
                  onBack: createGroupConfiguration?.onBack,
                  onError: createGroupConfiguration?.onError,
                  passwordPlaceholderText:
                      createGroupConfiguration?.passwordPlaceholderText,
                )));
  }

  _joinGroup(
      {required String guid, required String groupType, String password = ""}) {
    showLoadingIndicatorDialog(context,
        background: theme.palette.getBackground(),
        progressIndicatorColor: theme.palette.getPrimary(),
        shadowColor: theme.palette.getAccent300());

    CometChat.joinGroup(guid, groupType, password: password,
        onSuccess: (Group group) async {
      User? user = await CometChat.getLoggedInUser();
      if (kDebugMode) {
        debugPrint("Group Joined Successfully : $group ");
      }

      if (context.mounted) {
        Navigator.pop(context); //pop loading dialog
      }

      //ToDo: remove after sdk issue solve
      if (group.hasJoined == false) {
        group.hasJoined = true;
      }

      CometChatGroupEvents.ccGroupMemberJoined(user!, group);
    },
        onError: joinProtectedGroupConfiguration?.onError ??
            (CometChatException e) {
              Navigator.pop(context); //pop loading dialog

              showCometChatConfirmDialog(
                  context: context,
                  style: ConfirmDialogStyle(
                      backgroundColor:
                          theme.palette.mode == PaletteThemeModes.light
                              ? theme.palette.getBackground()
                              : Color.alphaBlend(theme.palette.getAccent200(),
                                  theme.palette.getBackground()),
                      shadowColor: theme.palette.getAccent300(),
                      confirmButtonTextStyle: TextStyle(
                          fontSize: theme.typography.text2.fontSize,
                          fontWeight: theme.typography.text2.fontWeight,
                          color: theme.palette.getPrimary())),
                  title: Text(
                      Translations.of(context).something_went_wrong_error,
                      style: TextStyle(
                          fontSize: theme.typography.name.fontSize,
                          fontWeight: theme.typography.name.fontWeight,
                          color: theme.palette.getAccent(),
                          fontFamily: theme.typography.name.fontFamily)),
                  confirmButtonText: Translations.of(context).okay,
                  onConfirm: () {
                    Navigator.pop(context); //pop confirm dialog
                  });
            });
  }
}
