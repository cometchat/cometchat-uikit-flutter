import '../../../../../flutter_chat_ui_kit.dart';

class CometChatGroupEvents {
  static Map<String, CometChatGroupEventListener> groupsListener = {};

  static addGroupsListener(
      String listenerId, CometChatGroupEventListener listenerClass) {
    groupsListener[listenerId] = listenerClass;
  }

  static removeGroupsListener(String listenerId) {
    groupsListener.remove(listenerId);
  }

  static onGroupTap(Group group, int index) {
    groupsListener.forEach((key, value) {
      value.onGroupTap(group, index);
    });
  }

  static onGroupLongPress(Group group, int index) {
    groupsListener.forEach((key, value) {
      value.onGroupLongPress(group, index);
    });
  }

  static onCreateGroupIconClick() {
    groupsListener.forEach((key, value) {
      value.onCreateGroupIconClick();
    });
  }

  static onGroupCreate(Group group) {
    groupsListener.forEach((key, value) {
      value.onGroupCreate(group);
    });
  }

  static onGroupError(CometChatException error) {
    groupsListener.forEach((key, value) {
      value.onGroupError(error);
    });
  }

  static onGroupDelete(Group group) {
    groupsListener.forEach((key, value) {
      value.onGroupDelete(group);
    });
  }

  static onGroupLeave(Group group, GroupMember member) {
    groupsListener.forEach((key, value) {
      value.onGroupLeave(group, member);
    });
  }

  static onGroupMemberLeave(User leftUser, Group leftGroup) {
    groupsListener.forEach((key, value) {
      value.onGroupMemberLeave(leftUser, leftGroup);
    });
  }

  static onGroupMemberChangeScope(User updatedBy, User updatedUser,
      String scopeChangedTo, String scopeChangedFrom, Group group) {
    groupsListener.forEach((key, value) {
      value.onGroupMemberChangeScope(
          updatedBy, updatedUser, scopeChangedTo, scopeChangedFrom, group);
    });
  }

  static onGroupMemberBan(User bannedUser, User bannedBy, Group bannedFrom) {
    groupsListener.forEach((key, value) {
      value.onGroupMemberBan(bannedUser, bannedBy, bannedFrom);
    });
  }

  static onGroupMemberKick(User kickedUser, User kickedBy, Group kickedFrom) {
    groupsListener.forEach((key, value) {
      value.onGroupMemberKick(kickedUser, kickedBy, kickedFrom);
    });
  }

  static onGroupMemberUnban(
      User unbannedUser, User unbannedBy, Group unbannedFrom) {
    groupsListener.forEach((key, value) {
      value.onGroupMemberUnban(unbannedUser, unbannedBy, unbannedFrom);
    });
  }

  static onGroupMemberJoin(User joinedUser, Group joinedGroup) {
    groupsListener.forEach((key, value) {
      value.onGroupMemberJoin(joinedUser, joinedGroup);
    });
  }

  static onGroupMemberAdd(usersAdded, userAddedBy, userAddedIn) {
    groupsListener.forEach((key, value) {
      value.onGroupMemberAdd(usersAdded, userAddedBy, userAddedIn);
    });
  }

  static onOwnershipChange(Group group, GroupMember member) {
    groupsListener.forEach((key, value) {
      value.onOwnershipChange(group, member);
    });
  }
}
