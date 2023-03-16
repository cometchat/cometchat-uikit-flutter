import 'package:flutter_chat_ui_kit/src/utils/loading_indicator.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class CometChatGroupsWithMessagesController extends GetxController
    with CometChatGroupEventListener {
  CometChatGroupsWithMessagesController(
      {this.messageConfiguration,
      this.theme,
      this.createGroupConfiguration,
      this.joinProtectedGroupConfiguration});

  ///[messageConfiguration] CometChatMessage configurations
  final MessageConfiguration? messageConfiguration;

  ///[theme] custom theme
  final CometChatTheme? theme;

  ///[createGroupConfiguration] sets configuration for [CometChatCreateGroup]
  final CreateGroupConfiguration? createGroupConfiguration;

  ///[joinProtectedGroupConfiguration] sets configuration for [CometChatJoinProtectedGroup]
  final JoinProtectedGroupConfiguration? joinProtectedGroupConfiguration;

  late String _dateString;
  late String _groupsEventListenerId;

  late BuildContext context;

  @override
  void onInit() {
    super.onInit();
    _dateString = DateTime.now().millisecondsSinceEpoch.toString();
    _groupsEventListenerId = "${_dateString}GWMGroupListener";
    CometChatGroupEvents.addGroupsListener(_groupsEventListenerId, this);
  }

  @override
  void onClose() {
    super.onClose();
    CometChatGroupEvents.removeGroupsListener(_groupsEventListenerId);
  }

  void onItemTap(Group group) {
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

  void navigateToMessagesScreen({required Group group, BuildContext? context}) {
    Navigator.push(
        context ?? this.context,
        MaterialPageRoute(
            builder: (context) => CometChatMessages(
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
                  theme: joinProtectedGroupConfiguration?.theme,
                  onError: joinProtectedGroupConfiguration?.onError,
                  title: joinProtectedGroupConfiguration?.title,
                  description: joinProtectedGroupConfiguration?.description,
                  style: joinProtectedGroupConfiguration?.style,
                  onBack: joinProtectedGroupConfiguration?.onBack,
                )));
  }

  void navigateCreateGroup() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CometChatCreateGroup(
                  style: CreateGroupStyle(
                      titleTextStyle: createGroupConfiguration
                              ?.style?.titleTextStyle ??
                          TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: theme?.palette.getAccent()),
                      selectedTabColor: createGroupConfiguration
                              ?.style?.selectedTabColor ??
                          theme?.palette.getPrimary(),
                      selectedTabTextStyle: createGroupConfiguration
                              ?.style?.selectedTabTextStyle ??
                          TextStyle(
                            color: theme?.palette.getBackground(),
                            fontSize: theme?.typography.text1.fontSize,
                            fontFamily: theme?.typography.text1.fontFamily,
                            fontWeight: theme?.typography.text1.fontWeight,
                          ),
                      tabTextStyle: createGroupConfiguration
                              ?.style?.tabTextStyle ??
                          TextStyle(
                            color: theme?.palette.getAccent600(),
                            fontSize: theme?.typography.text1.fontSize,
                            fontFamily: theme?.typography.text1.fontFamily,
                            fontWeight: theme?.typography.text1.fontWeight,
                          ),
                      closeIconTint: createGroupConfiguration
                              ?.style?.closeIconTint ??
                          theme?.palette.getPrimary(),
                      createIconTint: createGroupConfiguration
                              ?.style?.createIconTint ??
                          theme?.palette.getPrimary(),
                      tabColor: createGroupConfiguration?.style?.tabColor ??
                          theme?.palette.getAccent100(),
                      background: createGroupConfiguration?.style?.background ??
                          theme?.palette.getBackground(),
                      borderColor:
                          createGroupConfiguration?.style?.borderColor ??
                              theme?.palette.getAccent100(),
                      border: createGroupConfiguration?.style?.border,
                      borderRadius:
                          createGroupConfiguration?.style?.borderRadius,
                      gradient: createGroupConfiguration?.style?.gradient,
                      height: createGroupConfiguration?.style?.height,
                      namePlaceholderTextStyle: createGroupConfiguration
                          ?.style?.namePlaceholderTextStyle,
                      nameInputTextStyle:
                          createGroupConfiguration?.style?.nameInputTextStyle,
                      passwordPlaceholderTextStyle: createGroupConfiguration
                          ?.style?.passwordPlaceholderTextStyle,
                      passwordInputTextStyle: createGroupConfiguration
                          ?.style?.passwordInputTextStyle,
                      width: createGroupConfiguration?.style?.width),
                  createIcon: createGroupConfiguration?.createIcon,
                  theme: createGroupConfiguration?.theme,
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
        background: theme?.palette.getBackground(),
        progressIndicatorColor: theme?.palette.getPrimary(),
        shadowColor: theme?.palette.getAccent300());

    CometChat.joinGroup(guid, groupType, password: password,
        onSuccess: (Group group) async {
      User? user = await CometChat.getLoggedInUser();
      debugPrint("Group Joined Successfully : $group ");
      Navigator.pop(context); //pop loading dialog

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
                          theme?.palette.mode == PaletteThemeModes.light
                              ? theme?.palette.getBackground()
                              : Color.alphaBlend(theme!.palette.getAccent200(),
                                  theme!.palette.getBackground()),
                      shadowColor: theme?.palette.getAccent300(),
                      confirmButtonTextStyle: TextStyle(
                          fontSize: theme?.typography.text2.fontSize,
                          fontWeight: theme?.typography.text2.fontWeight,
                          color: theme?.palette.getPrimary())),
                  title: Text(
                      Translations.of(context).something_went_wrong_error,
                      style: TextStyle(
                          fontSize: theme?.typography.name.fontSize,
                          fontWeight: theme?.typography.name.fontWeight,
                          color: theme?.palette.getAccent(),
                          fontFamily: theme?.typography.name.fontFamily)),
                  confirmButtonText: Translations.of(context).okay,
                  onConfirm: () {
                    Navigator.pop(context); //pop confirm dialog
                  });
            });
  }
}
