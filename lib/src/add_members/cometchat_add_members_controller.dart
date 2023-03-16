import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import '../../flutter_chat_ui_kit.dart' as cc;

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
        group.guid, ConversationType.group, onSuccess: (_conversation) {
      if (_conversation.lastMessage != null) {}
    }, onError: (_) {}));
    _conversationId ??= _conversation?.conversationId;
  }

  addMember(List<User>? users, BuildContext context) {
    List<GroupMember> members = [];
    List<User> _addedMembers = [];

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
              _addedMembers.add(member);
              messages.add(cc.Action(
                action: MessageCategoryConstants.action,
                conversationId: _conversationId!,
                message: '${_loggedInUser?.name} added ${member.name}',
                rawData: '{}',
                oldScope: '',
                newScope: GroupMemberScope.participant,
                id: DateTime.now().microsecondsSinceEpoch,
                muid: null,
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
              ));
            }
          }
          group.membersCount += _addedMembers.length;
          Navigator.of(context).pop();
          CometChatGroupEvents.ccGroupMemberAdded(
              messages, _addedMembers, group, _loggedInUser!);
        },
        onError: onError);
  }
}
