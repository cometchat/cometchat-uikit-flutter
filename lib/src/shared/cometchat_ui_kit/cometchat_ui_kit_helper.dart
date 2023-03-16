import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart' as ui_kit;

///[CometChatUIKitHelper] contains static methods for triggering local events
class CometChatUIKitHelper {
  //---------- Message Events ----------
  ///[onMessageSent] is used to inform the listeners
  ///when the logged-in user is sending a message
  static onMessageSent(BaseMessage message, MessageStatus messageStatus) {
    CometChatMessageEvents.ccMessageSent(message, messageStatus);
  }

  ///[onMessageEdited] is used to inform the listeners
  ///when the logged-in user is editing a message
  static onMessageEdited(BaseMessage message, MessageEditStatus status) {
    CometChatMessageEvents.ccMessageEdited(message, status);
  }

  ///[onMessageDeleted] is used to inform the listeners
  ///when the logged-in user has deleted a message
  static onMessageDeleted(BaseMessage message, EventStatus status) {
    CometChatMessageEvents.ccMessageDeleted(message, status);
  }

  ///[onMessageRead] is used to inform the listeners
  ///when the logged-in user has read a message
  static onMessageRead(BaseMessage message) {
    CometChatMessageEvents.ccMessageRead(message);
  }

  ///[onLiveReaction] is used to inform the listeners
  ///when the logged-in user sends a transient message (live reaction)
  static onLiveReaction(String reaction, String receiverId) {
    CometChatMessageEvents.ccLiveReaction(reaction, receiverId);
  }

  //---------- User Events ----------
  ///[onUserBlocked] is used to inform the listeners
  ///when the logged-in user blocks another user
  static onUserBlocked(User user) {
    CometChatUserEvents.ccUserBlocked(user);
  }

  ///[onUserUnblocked] is used to inform the listeners
  ///when the logged-in user unblocks a blocked user
  static onUserUnblocked(User user) {
    CometChatUserEvents.ccUserUnblocked(user);
  }

  //---------- Group Events ----------
  ///[onGroupCreated] is used to inform the listeners
  ///when the logged-in user creates a Group
  static onGroupCreated(Group group) {
    CometChatGroupEvents.ccGroupCreated(group);
  }

  ///[onGroupDeleted] is used to inform the listeners
  ///when the logged-in user deletes a Group
  static onGroupDeleted(Group group) {
    CometChatGroupEvents.ccGroupDeleted(group);
  }

  ///[onGroupLeft] is used to inform the listeners
  ///when the logged-in user leaves a Group
  static onGroupLeft(ui_kit.Action message, User leftUser, Group leftGroup) {
    CometChatGroupEvents.ccGroupLeft(message, leftUser, leftGroup);
  }

  ///[onGroupMemberScopeChanged] is used to inform the listeners
  ///when the logged-in user changes the scope of a group member
  ///in a group
  static onGroupMemberScopeChanged(ui_kit.Action message, User updatedUser,
      String scopeChangedTo, String scopeChangedFrom, Group group) {
    CometChatGroupEvents.ccGroupMemberScopeChanged(
        message, updatedUser, scopeChangedTo, scopeChangedFrom, group);
  }

  ///[onGroupMemberBanned] is used to inform the listeners
  ///when the logged-in user bans a group member
  static onGroupMemberBanned(
      ui_kit.Action message, User bannedUser, User bannedBy, Group bannedFrom) {
    CometChatGroupEvents.ccGroupMemberBanned(
        message, bannedUser, bannedBy, bannedFrom);
  }

  ///[onGroupMemberKicked] is used to inform the listeners
  ///when the logged-in user kicks a group member from a group
  static onGroupMemberKicked(
      ui_kit.Action message, User kickedUser, User kickedBy, Group kickedFrom) {
    CometChatGroupEvents.ccGroupMemberKicked(
        message, kickedUser, kickedBy, kickedFrom);
  }

  ///[onGroupMemberUnbanned] is used to inform the listeners
  ///when the logged-in user unbans a banned user of a group
  static onGroupMemberUnbanned(ui_kit.Action message, User unbannedUser,
      User unbannedBy, Group unbannedFrom) {
    CometChatGroupEvents.ccGroupMemberUnbanned(
        message, unbannedUser, unbannedBy, unbannedFrom);
  }

  ///[onGroupMemberJoined] is used to inform the listeners
  ///when the logged-in user joins a group
  static onGroupMemberJoined(User joinedUser, Group joinedGroup) {
    CometChatGroupEvents.ccGroupMemberJoined(joinedUser, joinedGroup);
  }

  ///[onGroupMemberAdded] is used to inform the listeners
  ///when the logged-in user adds users to a group
  static onGroupMemberAdded(
    List<ui_kit.Action> messages,
    List<User> usersAdded,
    Group groupAddedIn,
    User addedBy,
  ) {
    CometChatGroupEvents.ccGroupMemberAdded(
        messages, usersAdded, groupAddedIn, addedBy);
  }

  ///[onOwnershipChanged] is used to inform the listeners
  ///when the logged-in user transfers their ownership to some other group member
  static onOwnershipChanged(Group group, GroupMember newOwner) {
    CometChatGroupEvents.ccOwnershipChanged(group, newOwner);
  }

  //---------- Conversation Events ----------
  ///[onConversationDeleted] is used to inform the listeners
  ///when the logged-in user deletes a conversation
  static onConversationDeleted(Conversation conversation) {
    CometChatConversationEvents.ccConversationDeleted(conversation);
  }

  //---------- CometChat UI Events ----------
  ///[showPanel] used to reveal a panel above message composer
  static showPanel(
      Map<String, dynamic>? id, alignment align, WidgetBuilder child) {
    CometChatUIEvents.showPanel(id, align, child);
  }

  ///[hidePanel] used to hide the panel above message composer
  static hidePanel(Map<String, dynamic>? id, alignment align) {
    CometChatUIEvents.hidePanel(id, align);
  }

  ///[onConversationChanged] used to notify if the logged-in user
  ///has moved on to a different conversation
  static onConversationChanged(Map<String, dynamic>? id,
      BaseMessage? lastMessage, User? user, Group? group) {
    CometChatUIEvents.onConversationChanged(id, lastMessage, user, group);
  }
}
