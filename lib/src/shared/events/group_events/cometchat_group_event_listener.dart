import 'package:flutter_chat_ui_kit/src/utils/ui_event_handler.dart';

import '../../../../../flutter_chat_ui_kit.dart';

///Events can be triggered by Group Module
///e.g. Clicking on a particular group. All public-facing components in each module will trigger events.
abstract class CometChatGroupEventListener implements UIEventHandler {

  ///This will get triggered when a group is created successfully
  void ccGroupCreated(Group group) {}

  ///This will get triggered when a group is deleted successfully
  void ccGroupDeleted(Group group) {}

  ///This will get triggered when logged in user leaves the group
  void ccGroupLeft(Action message, User leftUser, Group leftGroup) {}

  ///This will get triggered when group member's scope is changed by logged in user
  void ccGroupMemberScopeChanged(Action message,User updatedUser, String scopeChangedTo,
      String scopeChangedFrom, Group group) {}

  ///This will get triggered when group member is banned from the group by logged in user
  void ccGroupMemberBanned(Action message, User bannedUser, User bannedBy, Group bannedFrom) {}

  ///This will get triggered when group member is kicked from the group by logged in user
  void ccGroupMemberKicked(Action message, User kickedUser, User kickedBy, Group kickedFrom) {}

  ///This will get triggered when a banned group member is unbanned from group by logged in user
  void ccGroupMemberUnbanned(Action message, User unbannedUser, User unbannedBy, Group unbannedFrom) {}

  ///This will get triggered when logged in user is joined successfully
  void ccGroupMemberJoined(User joinedUser, Group joinedGroup) {}

  ///This will get triggered when a member is added by logged in user
  void ccGroupMemberAdded(List<Action> messages,List<User> usersAdded, Group groupAddedIn,User addedBy) {}

  ///This will get triggered when ownership is changed by logged in user
  void ccOwnershipChanged(Group group, GroupMember newOwner) {}

}
