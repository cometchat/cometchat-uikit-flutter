import 'package:flutter/material.dart';

import '../../../flutter_chat_ui_kit.dart';

import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart' as kit;

class CometChatGroupsController
    extends CometChatSearchListController<Group, String>
    with CometChatSelectable, CometChatGroupEventListener, GroupListener {
  //Class members
  late GroupsBuilderProtocol groupsBuilderProtocol;
  late String dateStamp;
  CometChatTheme theme;
  late BuildContext context;
  late String groupSDKListenerID;
  late String groupUIListenerID;

  //Constructor
  CometChatGroupsController(
      {required this.groupsBuilderProtocol,
      SelectionMode? mode,
      required this.theme,
      OnError? onError})
      : super(builderProtocol: groupsBuilderProtocol, onError: onError) {
    selectionMode = mode ?? SelectionMode.none;
    dateStamp = DateTime.now().microsecondsSinceEpoch.toString();

    groupSDKListenerID = "${dateStamp}group_sdk_listener";
    groupUIListenerID = "${dateStamp}_ui_group_listener";
  }

//initialization functions
  @override
  void onInit() {
    CometChatGroupEvents.addGroupsListener(groupUIListenerID, this);
    CometChat.addGroupListener(groupSDKListenerID, this);
    super.onInit();
  }

  @override
  void onClose() {
    CometChat.removeGroupListener(groupSDKListenerID);
    CometChatGroupEvents.removeGroupsListener(groupUIListenerID);
    super.onClose();
  }

  @override
  bool match(Group elementA, Group elementB) {
    return elementA.guid == elementB.guid;
  }

  @override
  String getKey(Group element) {
    return element.guid;
  }

  @override
  void ccGroupCreated(Group group) {
    addElement(group);
  }

  @override
  void ccGroupMemberJoined(User joinedUser, Group joinedGroup) {
    updateElement(joinedGroup);
  }

  @override
  ccOwnershipChanged(Group group, GroupMember newOwner) {
    updateElement(group);
  }

  @override
  void ccGroupMemberAdded(List<kit.Action> messages, List<User> usersAdded,
      Group groupAddedIn, User addedBy) {
    updateElement(groupAddedIn);
  }

  @override
  ccGroupLeft(kit.Action message, User leftUser, Group leftGroup) {
    if (leftGroup.type == GroupTypeConstants.private) {
      removeElement(leftGroup);
    } else {
      leftGroup.hasJoined = false;
      leftGroup.scope = null;
      updateElement(leftGroup);
    }
  }

  @override
  void ccGroupMemberBanned(
      kit.Action message, User bannedUser, User bannedBy, Group bannedFrom) {
    updateElement(bannedFrom);
  }

  @override
  onGroupMemberKicked(
      kit.Action action, User kickedUser, User kickedBy, Group kickedFrom) {
    updateElement(kickedFrom);
  }

  @override
  onGroupMemberJoined(kit.Action action, User joinedUser, Group joinedGroup) {
    updateElement(joinedGroup);
  }

  @override
  onGroupMemberLeft(kit.Action action, User leftUser, Group leftGroup) {
    updateElement(leftGroup);
  }

  @override
  onGroupMemberBanned(
      kit.Action action, User bannedUser, User bannedBy, Group bannedFrom) {
    updateElement(bannedFrom);
  }

  @override
  onGroupMemberScopeChanged(kit.Action action, User updatedBy, User updatedUser,
      String scopeChangedTo, String scopeChangedFrom, Group group) {
    updateElement(group);
  }

  @override
  onMemberAddedToGroup(
      kit.Action action, User addedby, User userAdded, Group addedTo) {
    updateElement(addedTo);
  }

  @override
  void ccGroupDeleted(Group group) {
    removeElement(group);
  }

  @override
  void ccGroupMemberKicked(
      kit.Action message, User kickedUser, User kickedBy, Group kickedFrom) {
    updateElement(kickedFrom);
  }
}
