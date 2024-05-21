import 'package:flutter/material.dart';

import '../../../cometchat_chat_uikit.dart';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as kit;

///[CometChatGroupsController] is the view model for [CometChatGroups]
///it contains all the business logic involved in changing the state of the UI of [CometChatGroups]
class CometChatGroupsController
    extends CometChatSearchListController<Group, String>
    with
        CometChatSelectable,
        CometChatGroupEventListener,
        GroupListener,
        ConnectionListener {
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
      super.onError})
      : super(builderProtocol: groupsBuilderProtocol) {
    selectionMode = mode ?? SelectionMode.none;
    dateStamp = DateTime.now().microsecondsSinceEpoch.toString();

    groupSDKListenerID = "${dateStamp}group_sdk_listener";
    groupUIListenerID = "${dateStamp}_ui_FromGroup_listener";
  }

//initialization functions
  @override
  void onInit() {
    CometChatGroupEvents.addGroupsListener(groupUIListenerID, this);
    CometChat.addGroupListener(groupSDKListenerID, this);
    CometChat.addConnectionListener(groupSDKListenerID, this);
    super.onInit();
  }

  @override
  void onClose() {
    CometChat.removeGroupListener(groupSDKListenerID);
    CometChatGroupEvents.removeGroupsListener(groupUIListenerID);
    CometChat.removeConnectionListener(groupSDKListenerID);
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
    int matchedIndex;
    matchedIndex = getMatchingIndex(addedTo);
    if (matchedIndex == -1) {
      //TODO: once hasJoined has been fixed in sdk the following override will be removed
      addedTo.hasJoined = true;
      addElement(addedTo);
    } else {
      updateElement(addedTo);
    }
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

  //TODO: once hasJoined has been fixed in sdk the following override will be removed
  @override
  updateElement(Group element, {int? index}) {
    int matchedIndex;
    if (index == null) {
      matchedIndex = getMatchingIndex(element);
    } else {
      matchedIndex = index;
    }
    if (index != -1) {
      element.hasJoined = list[matchedIndex].hasJoined;
    }
    super.updateElement(element, index: matchedIndex);
  }

  @override
  void onConnected() {
    if (!isLoading) {
      request = groupsBuilderProtocol.getRequest();
      list = [];
      loadMoreElements();
    }
  }
}
