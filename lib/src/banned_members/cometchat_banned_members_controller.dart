import 'package:flutter/material.dart' as material;
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import '../../cometchat_chat_uikit.dart' as cc;

///[CometChatBannedMembersController] is the view model for [CometChatBannedMembers]
///it contains all the business logic involved in changing the state of the UI of [CometChatBannedMembers]
class CometChatBannedMembersController
    extends CometChatSearchListController<GroupMember, String>
    with
        CometChatSelectable,
        GroupListener,
        UserListener,
        CometChatGroupEventListener {
  late BannedMemberBuilderProtocol bannedMemberBuilderProtocol;
  late String dateStamp;
  late String groupSDKListenerID;
  late String userSDKListenerID;
  late String groupUIListenerID;
  CometChatTheme? theme;
  bool disableUsersPresence;
  bool? isOwner;
  late Group group;
  User? loggedInUser;
  Conversation? _conversation;

  String? _conversationId;

  ///[unbanIconUrl] is a custom icon for the default option
  final String? unbanIconUrl;

  ///[unbanIconUrlPackageName] is the package for the asset image to show as custom icon for the default option
  final String? unbanIconUrlPackageName;

  CometChatBannedMembersController(
      {required this.bannedMemberBuilderProtocol,
      SelectionMode? mode,
      required this.group,
      required this.disableUsersPresence,
      required CometChatTheme theme,
      OnError? onError,
      this.unbanIconUrl,
      this.unbanIconUrlPackageName})
      : super(builderProtocol: bannedMemberBuilderProtocol, onError: onError) {
    selectionMode = mode ?? SelectionMode.none;
    dateStamp = DateTime.now().microsecondsSinceEpoch.toString();
    // assigning values for listeners
    groupSDKListenerID = "${dateStamp}group_sdk_listener";
    userSDKListenerID = "${dateStamp}user_sdk_listener";
    groupUIListenerID = "${dateStamp}_ui_group_listener";
  }

  @override
  void onInit() {
    CometChat.addGroupListener(groupSDKListenerID, this);
    CometChatGroupEvents.addGroupsListener(groupUIListenerID, this);
    if (disableUsersPresence != true) {
      //Adding listener when presence is needed
      CometChat.addUserListener(userSDKListenerID, this);
    }
    initializeInternalDependencies();
    super.onInit();
  }

  void initializeInternalDependencies() async {
    _conversation ??= (await CometChat.getConversation(
        group.guid, ConversationType.group, onSuccess: (conversation) {
      if (conversation.lastMessage != null) {}
    }, onError: (_) {}));
    _conversationId ??= _conversation?.conversationId;
  }

  @override
  void onClose() {
    CometChat.removeGroupListener(groupSDKListenerID);

    CometChatGroupEvents.removeGroupsListener(groupUIListenerID);
    if (disableUsersPresence == false) {
      CometChat.removeUserListener(userSDKListenerID);
    }
    super.onClose();
  }

  @override
  bool match(GroupMember elementA, GroupMember elementB) {
    return elementA.uid == elementB.uid;
  }

  @override
  String getKey(GroupMember element) {
    return element.uid;
  }

  ///[onGroupMemberBanned] will get triggered when a group member is banned from group by someone other than the logged in user
  @override
  void onGroupMemberBanned(
      Action action, User bannedUser, User bannedBy, Group bannedFrom) {
    if (bannedFrom.guid == group.guid) {
      addElement(GroupMember.fromUid(
          scope: bannedFrom.scope, uid: bannedUser.uid, name: bannedUser.name));
      material.debugPrint('onGroupMemberBanned got triggered');
    }
  }

  /// [onGroupMemberUnbanned] will get triggered when a group member is unbanned from group by someone other than the logged in user
  @override
  void onGroupMemberUnbanned(
      Action action, User unbannedUser, User unbannedBy, Group unbannedFrom) {
    if (unbannedFrom.guid == group.guid) {
      removeElement(GroupMember.fromUid(
          scope: unbannedFrom.scope,
          uid: unbannedUser.uid,
          name: unbannedUser.name));
    }
  }

  /// [ccGroupMemberBanned] will get triggered when a group member is banned from group by logged in user
  @override
  void ccGroupMemberBanned(
      Action message, User bannedUser, User bannedBy, Group bannedFrom) {
    if (bannedFrom.guid == group.guid) {
      addElement(GroupMember.fromUid(
          scope: bannedFrom.scope, uid: bannedUser.uid, name: bannedUser.name));
    }
  }

  /// [ccGroupMemberUnbanned] will get triggered when a banned group member is unbanned from group by logged in user
  @override
  void ccGroupMemberUnbanned(
      Action action, User unbannedUser, User unbannedBy, Group unbannedFrom) {
    if (unbannedFrom.guid == group.guid) {
      removeElement(GroupMember.fromUid(
          scope: unbannedFrom.scope,
          uid: unbannedUser.uid,
          name: unbannedUser.name));
    }
  }

  @override
  loadMoreElements({bool Function(GroupMember element)? isIncluded}) async {
    if (loggedInUser == null) {
      loggedInUser = await CometChat.getLoggedInUser();
      if (loggedInUser?.uid == group.owner) {
        isOwner = true;
      }
    }
    await super.loadMoreElements(isIncluded: isIncluded);
  }

  @override
  void onUserOffline(User user) {
    int index = getMatchingIndexFromKey(user.uid);
    if (index != -1) {
      list[index].status = user.status;
      update();
      material.debugPrint('user down ${user.status}');
    }
  }

  @override
  void onUserOnline(User user) {
    int index = getMatchingIndexFromKey(user.uid);
    if (index != -1) {
      list[index].status = UserStatusConstants.online;
      update();
      material.debugPrint('user up ${user.status}');
    }
  }

  List<CometChatOption> defaultFunction(Group group, GroupMember member) {
    List<CometChatOption> optionList = [];
    optionList = getDefaultGroupMemberOptions(group, member, theme: theme);

    optionList.removeWhere((option) =>
        DetailUtils.validateGroupMemberOptions(
            loggedInUserScope: isOwner == true
                ? GroupMemberScope.owner
                : group.scope ?? GroupMemberScope.participant,
            memberScope: member.scope ?? GroupMemberScope.participant,
            optionId: option.id) ==
        false);

    return optionList;
  }

  List<CometChatOption> getDefaultGroupMemberOptions(
    Group group,
    GroupMember member, {
    CometChatTheme? theme,
  }) {
    return [
      getUnBanOption(group, member, theme: theme),
    ];
  }

  CometChatOption getUnBanOption(Group group, GroupMember member,
      {CometChatTheme? theme}) {
    return CometChatOption(
        id: GroupMemberOptionConstants.unban,
        icon: unbanIconUrl ?? AssetConstants.close,
        packageName: unbanIconUrlPackageName ?? UIConstants.packageName,
        backgroundColor: theme?.palette.getOption() ?? material.Colors.red,
        onClick: () async {
          CometChat.unbanGroupMember(
              guid: group.guid,
              uid: member.uid,
              onSuccess: (String result) async {
                CometChatGroupEvents.ccGroupMemberUnbanned(
                    cc.Action(
                      action: MessageCategoryConstants.action,
                      conversationId: _conversationId!,
                      message: '${loggedInUser?.name} unbanned ${member.name}',
                      rawData: '{}',
                      oldScope: '',
                      newScope: '',
                      id: 0,
                      muid: DateTime.now().microsecondsSinceEpoch.toString(),
                      sender: loggedInUser!,
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
                      deliveredToMeAt: DateTime.now(),
                      deletedAt: DateTime.now(),
                      editedAt: DateTime.now(),
                      deletedBy: null,
                      editedBy: null,
                      updatedAt: DateTime.now(),
                      parentMessageId: 0,
                      replyCount: 0,
                      unreadRepliesCount: 0,
                    ),
                    member,
                    loggedInUser!,
                    group);
              },
              onError: onError);
        });
  }
}
