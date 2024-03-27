import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import '../../cometchat_chat_uikit.dart' as cc;

///[CometChatAddMembersController] is the view model for [CometChatAddMembers]
///it contains all the business logic involved in changing the state of the UI of [CometChatAddMembers]
class CometChatAddMembersController extends GetxController {
  CometChatAddMembersController({required this.group, this.onError});

  ///[group] provide group to add members to
  final Group group;

  ///[onError] callback triggered in case any error happens when adding users to group
  final OnError? onError;

  User? _loggedInUser;

  Conversation? _conversation;

  String? _conversationId;

  @override
  void onInit() {
    initializeLoggedInUser();
    super.onInit();
  }

  initializeLoggedInUser() async {
    _loggedInUser = await CometChat.getLoggedInUser();
    _conversation ??= (await CometChat.getConversation(
        group.guid, ConversationType.group, onSuccess: (conversation) {
      if (conversation.lastMessage != null) {}
    }, onError: (_) {}));
    _conversationId ??= _conversation?.conversationId;
  }

  addMember(List<User>? users, BuildContext context) {
    List<GroupMember> members = [];
    List<User> addedMembers = [];

    if (users == null) return;

    for (User user in users) {
      members.add(GroupMember(
          scope: GroupMemberScope.participant,
          name: user.name,
          role: user.role ?? "",
          status: user.status ?? "",
          uid: user.uid,
          avatar: user.avatar,
          blockedByMe: user.blockedByMe,
          joinedAt: DateTime.now(),
          hasBlockedMe: user.hasBlockedMe,
          lastActiveAt: user.lastActiveAt,
          link: user.link,
          metadata: user.metadata,
          statusMessage: user.statusMessage,
          tags: user.tags));
    }

    CometChat.addMembersToGroup(
        guid: group.guid,
        groupMembers: members,
        onSuccess: (Map<String?, String?> result) {
          List<cc.Action> messages = [];
          for (GroupMember member in members) {
            if (result[member.uid] == "success") {
              addedMembers.add(member);
              messages.add(cc.Action(
                action: MessageCategoryConstants.action,
                conversationId: _conversationId!,
                message: '${_loggedInUser?.name} added ${member.name}',
                rawData: '{}',
                oldScope: '',
                newScope: GroupMemberScope.participant,
                id: 0,
                muid: DateTime.now().microsecondsSinceEpoch.toString(),
                sender: _loggedInUser!,
                receiver: group,
                receiverUid: group.guid,
                type: MessageTypeConstants.groupActions,
                receiverType: ReceiverTypeConstants.group,
                category: MessageCategoryConstants.action,
                sentAt: DateTime.now(),
                deliveredAt: DateTime.now(),
                readAt: DateTime.now(),
                metadata: {},
                readByMeAt: DateTime.now(),
                deliveredToMeAt: DateTime.fromMillisecondsSinceEpoch(
                    DateTime.now().millisecondsSinceEpoch * 1000),
                deletedAt: DateTime.now(),
                editedAt: DateTime.now(),
                deletedBy: null,
                editedBy: null,
                updatedAt: DateTime.now(),
                parentMessageId: 0,
                replyCount: 0,
                unreadRepliesCount: 0,
              ));
            }
          }
          group.membersCount += addedMembers.length;
          Navigator.of(context).pop();
          CometChatGroupEvents.ccGroupMemberAdded(
              messages, addedMembers, group, _loggedInUser!);
        },
        onError: onError);
  }
}
