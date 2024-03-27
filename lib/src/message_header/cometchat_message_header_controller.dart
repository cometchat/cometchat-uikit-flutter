import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:get/get.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as cc;

///[CometChatMessageHeaderController] is the view model for [CometChatMessageHeader]
///it contains all the business logic involved in changing the state of the UI of [CometChatMessageHeader]
class CometChatMessageHeaderController extends GetxController
    with
        CometChatMessageEventListener,
        UserListener,
        GroupListener,
        CometChatGroupEventListener {
  User? userObject;
  Group? groupObject;
  bool? isTyping;
  User? typingUser;
  late String dateStamp;
  late String messageListenerId;
  late String groupListenerId;
  late String userListenerId;
  bool? disableTyping;
  bool? disableUserPresence;
  static int counter = 0;
  late String tag;
  late String _uiGroupListener;
  late String _dateString;

  int? membersCount;

  CometChatMessageHeaderController(
      {this.userObject,
      this.groupObject,
      bool? disableTyping,
      bool? disableUserPresence}) {
    dateStamp = DateTime.now().microsecondsSinceEpoch.toString();
    messageListenerId = "${dateStamp}_message_listener";
    groupListenerId = "${dateStamp}_group_listener";
    userListenerId = "${dateStamp}_user_listener";
    this.disableTyping = disableTyping ?? false;
    this.disableUserPresence = disableUserPresence ?? false;
    if (groupObject != null) {
      membersCount = groupObject?.membersCount;
      // print("GroupMember count in header ${groupObject?.membersCount}");
    }

    tag = "tag$counter";
    counter++;
  }

  @override
  void onInit() {
    _dateString = DateTime.now().millisecondsSinceEpoch.toString();
    _uiGroupListener = "${_dateString}UIGroupListener";
    if (disableTyping != true) {
      CometChatMessageEvents.addMessagesListener(messageListenerId, this);
    }
    if (userObject != null && disableUserPresence != true) {
      CometChat.addUserListener(groupListenerId, this);
    } else if (groupObject != null) {
      CometChat.addGroupListener(userListenerId, this);
      CometChatGroupEvents.addGroupsListener(_uiGroupListener, this);
    }
    super.onInit();
  }

  @override
  void onClose() {
    CometChatMessageEvents.removeMessagesListener(messageListenerId);
    CometChat.removeUserListener(userListenerId);
    CometChat.removeGroupListener(groupListenerId);
    CometChatGroupEvents.removeGroupsListener(_uiGroupListener);
    super.onClose();
  }

  @override
  void onUserOnline(User user) {
    if (userObject != null && userObject!.uid == user.uid) {
      userObject!.status = UserStatusConstants.online;
      update();
    }
  }

  @override
  void onUserOffline(User user) {
    if (userObject != null && userObject!.uid == user.uid) {
      userObject!.status = UserStatusConstants.offline;
      update();
    }
  }

  @override
  void onTypingStarted(TypingIndicator typingIndicator) {
    if (userObject != null &&
        typingIndicator.receiverType == ReceiverTypeConstants.user &&
        typingIndicator.sender.uid == userObject!.uid) {
      isTyping = true;
      typingUser = typingIndicator.sender;
      update();
    } else if (groupObject != null &&
        typingIndicator.receiverType == ReceiverTypeConstants.group &&
        typingIndicator.receiverId == groupObject!.guid) {
      isTyping = true;
      typingUser = typingIndicator.sender;
      update();
    }
  }

  @override
  void onTypingEnded(TypingIndicator typingIndicator) {
    if (userObject != null &&
        typingIndicator.receiverType == ReceiverTypeConstants.user &&
        typingIndicator.sender.uid == userObject!.uid) {
      isTyping = false;
      typingUser = null;
      update();
    } else if (groupObject != null &&
        typingIndicator.receiverType == ReceiverTypeConstants.group &&
        typingIndicator.receiverId == groupObject!.guid) {
      isTyping = false;
      typingUser = typingIndicator.sender;
      update();
    }
  }
/*
  incrementMemberCount(Group _group) {
    if (groupObject != null && groupObject!.guid == _group.guid) {
      // groupObject!.membersCount++;
      membersCount = membersCount! + 1;
      update();
    }
  }

  decrementMemberCount(Group _group) {
    if (groupObject != null && groupObject!.guid == _group.guid) {
      // groupObject!.membersCount--;
      membersCount = membersCount! - 1;
      update();
    }
  }
  */

  updateMemberCount(Group group) {
    if (groupObject != null && groupObject!.guid == group.guid) {
      membersCount = group.membersCount;
      groupObject?.membersCount = membersCount ?? 1;
      update();
    }
  }

  @override
  void onGroupMemberJoined(
      cc.Action action, User joinedUser, Group joinedGroup) {
    updateMemberCount(joinedGroup);
  }

  @override
  void onGroupMemberLeft(cc.Action action, User leftUser, Group leftGroup) {
    updateMemberCount(leftGroup);
  }

  @override
  void onGroupMemberKicked(
      cc.Action action, User kickedUser, User kickedBy, Group kickedFrom) {
    updateMemberCount(kickedFrom);
  }

  @override
  void onGroupMemberBanned(
      cc.Action action, User bannedUser, User bannedBy, Group bannedFrom) {
    updateMemberCount(bannedFrom);
  }

  @override
  void onGroupMemberUnbanned(cc.Action action, User unbannedUser,
      User unbannedBy, Group unbannedFrom) {}

  @override
  void onMemberAddedToGroup(
      cc.Action action, User addedby, User userAdded, Group addedTo) {
    updateMemberCount(addedTo);
  }

  @override
  void ccGroupMemberBanned(
      cc.Action message, User bannedUser, User bannedBy, Group bannedFrom) {
    updateMemberCount(bannedFrom);
  }

  @override
  void ccOwnershipChanged(Group group, GroupMember newOwner) {
    if (groupObject?.guid == group.guid) {
      groupObject?.owner = group.owner;
      update();
    }
  }

  @override
  void ccGroupMemberKicked(
      cc.Action message, User kickedUser, User kickedBy, Group kickedFrom) {
    updateMemberCount(kickedFrom);
  }

  @override
  void ccGroupMemberAdded(List<cc.Action> messages, List<User> usersAdded,
      Group groupAddedIn, User addedBy) {
    if (groupObject != null && groupAddedIn.guid == groupObject?.guid) {
      updateMemberCount(groupAddedIn);
    }
  }
}
