import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class CometChatGroupEvents {
  static Map<String, CometChatGroupEventListener> groupsListener = {};

  static addGroupsListener(
      String listenerId, CometChatGroupEventListener listenerClass) {
    groupsListener[listenerId] = listenerClass;
  }

  static removeGroupsListener(String listenerId) {
    groupsListener.remove(listenerId);
  }

  static ccGroupCreated(Group group) {
    groupsListener.forEach((key, value) {
      value.ccGroupCreated(group);
    });
  }

  static ccGroupDeleted(Group group) {
    groupsListener.forEach((key, value) {
      value.ccGroupDeleted(group);
    });
  }

  static ccGroupLeft(Action message, User leftUser, Group leftGroup) {
    groupsListener.forEach((key, value) {
      value.ccGroupLeft(message,leftUser,leftGroup);
    });
  }


  static ccGroupMemberScopeChanged(Action message,User updatedUser, String scopeChangedTo,
      String scopeChangedFrom, Group group) {
    groupsListener.forEach((key, value) {
      value.ccGroupMemberScopeChanged(
          message,updatedUser, scopeChangedTo, scopeChangedFrom, group);
    });
  }

  static ccGroupMemberBanned(Action message, User bannedUser, User bannedBy, Group bannedFrom) {
    groupsListener.forEach((key, value) {
      value.ccGroupMemberBanned(message,bannedUser,bannedBy, bannedFrom);
    });
  }

  static ccGroupMemberKicked(Action message, User kickedUser, User kickedBy, Group kickedFrom) {
    groupsListener.forEach((key, value) {
      value.ccGroupMemberKicked(message,kickedUser,kickedBy, kickedFrom);
    });
  }

  static ccGroupMemberUnbanned(Action message, User unbannedUser, User unbannedBy, Group unbannedFrom) {
    groupsListener.forEach((key, value) {
      value.ccGroupMemberUnbanned(message, unbannedUser, unbannedBy, unbannedFrom);
    });
  }

  static ccGroupMemberJoined(User joinedUser, Group joinedGroup) {
    groupsListener.forEach((key, value) {
      value.ccGroupMemberJoined(joinedUser, joinedGroup);
    });
  }

  static ccGroupMemberAdded(List<Action> messages,List<User> usersAdded, Group groupAddedIn,User addedBy) {
    groupsListener.forEach((key, value) {
      value.ccGroupMemberAdded(messages,usersAdded, groupAddedIn,addedBy);
    });
  }

  static ccOwnershipChanged(Group group, GroupMember newOwner) {
    groupsListener.forEach((key, value) {
      value.ccOwnershipChanged(group, newOwner);
    });
  }
}
