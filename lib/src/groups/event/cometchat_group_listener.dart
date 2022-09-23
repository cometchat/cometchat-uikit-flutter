import 'package:flutter_chat_ui_kit/src/utils/ui_event_handler.dart';

import '../../../../../flutter_chat_ui_kit.dart';

///Events can be triggered by Group Module
///e.g. Clicking on a particular group. All public-facing components in each module will trigger events.
abstract class CometChatGroupEventListener implements UIEventHandler {
  ///This will get triggered when a user clicks/presses on single Group i.e at CometChatDataItem
  void onGroupTap(Group group, int index) {}

  ///This will get triggered when a user Long presses on single Group i.e at CometChatDataItem
  void onGroupLongPress(Group group, int index) {}

  ///This will get triggered when a user clicks/presses on create group icon
  void onCreateGroupIconClick() {}

  ///This will get triggered when a group is created successfully
  void onGroupCreate(Group group) {}

  ///This will get triggered when a error occur at any point while working in groups module
  void onGroupError(CometChatException error) {}

  ///This will get triggered when a group is deleted successfully
  void onGroupDelete(Group group) {}

  ///This will get triggered when logged in user leaves the group
  void onGroupLeave(Group group, GroupMember member) {}

  ///This will get triggered when group member leave
  void onGroupMemberLeave(User leftUser, Group leftGroup) {}

  ///This will get triggered when group member's scope is changed by logged in user
  void onGroupMemberChangeScope(User updatedBy, User updatedUser,
      String scopeChangedTo, String scopeChangedFrom, Group group) {}

  ///This will get triggered when group member is banned from the group by logged in user
  void onGroupMemberBan(User bannedUser, User bannedBy, Group bannedFrom) {}

  ///This will get triggered when group member is kicked from the group by logged in user
  void onGroupMemberKick(User kickedUser, User kickedBy, Group kickedFrom) {}

  ///This will get triggered when a banned group member is unbanned from group by logged in user
  void onGroupMemberUnban(
      User unbannedUser, User unbannedBy, Group unbannedFrom) {}

  ///This will get triggered when logged in user is joined successfully
  void onGroupMemberJoin(User joinedUser, Group joinedGroup) {}

  ///This will get triggered when a member is added by logged in user
  void onGroupMemberAdd(usersAdded, userAddedBy, userAddedIn) {}

  ///This will get triggered when ownership is changed by logged in user
  void onOwnershipChange(Group group, GroupMember member) {}

  ///This will get triggered when a user clicks/presses on single Group i.e CometChatDataItem
  void onGroupBack(Group group) {}
}
