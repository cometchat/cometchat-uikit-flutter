import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../cometchat_chat_uikit.dart';
import '../../../cometchat_chat_uikit.dart' as cc;
import '../../../shared_ui/src/logging/cometchat_log.dart';

///[CometChatGroupMembersController] is the view model for [CometChatGroupMembers]
///it contains all the business logic involved in changing the state of the UI of [CometChatGroupMembers]
class CometChatGroupMembersController
    extends CometChatSearchListController<GroupMember, String>
    with
        CometChatSelectable,
        GroupListener,
        UserListener,
        CometChatGroupEventListener
    implements CometChatGroupMembersControllerProtocol {
  //Class members
  late GroupMembersBuilderProtocol groupMembersBuilderProtocol;
  late String dateStamp;
  late String groupSDKListenerID;
  late String userSDKListenerID;
  late String groupUIListenerID;
  final Group group;
  bool usersStatusVisibility = true;
  User? loggedInUser;
  bool? isOwner;
  Conversation? _conversation;

  ///[hideKickMemberOption] This prop defines whether a member can be kicked or not.
  final bool? hideKickMemberOption;

  ///[hideBanMemberOption] This prop defines whether a member can be banned or not.
  final bool? hideBanMemberOption;

  ///[hideScopeChangeOption] This prop defines whether a member's scope can be changed or not.
  final bool? hideScopeChangeOption;

  String? _conversationId;
  CometChatConfirmDialogStyle? confirmDialogStyle;
  CometChatChangeScopeStyle? changeScopeStyle;

  //Constructor
  CometChatGroupMembersController({
    required this.groupMembersBuilderProtocol,
    required this.group,
    SelectionMode? mode,
    bool? userStatusVisibility,
    this.confirmDialogStyle,
    this.changeScopeStyle,
    super.onError,
    super.onEmpty,
    super.onLoad,
    this.hideBanMemberOption,
    this.hideKickMemberOption,
    this.hideScopeChangeOption,
  }) : super(builderProtocol: groupMembersBuilderProtocol) {
    usersStatusVisibility = userStatusVisibility ?? true;
    selectionMode = mode ?? SelectionMode.none;
    dateStamp = DateTime.now().microsecondsSinceEpoch.toString();
    groupSDKListenerID = "${dateStamp}groupMembers_listener";
    userSDKListenerID = "${dateStamp}user_listener";
    groupUIListenerID = "${dateStamp}_ui_group_listener";
  }

  //initialization functions
  @override
  void onInit() {
    CometChat.addGroupListener(groupSDKListenerID, this);
    CometChatGroupEvents.addGroupsListener(groupUIListenerID, this);

    if (usersStatusVisibility == true) {
      //Adding listener when presence is needed
      CometChat.addUserListener(userSDKListenerID, this);
    }
    initializeInternalDependencies();
    super.onInit();
  }

  void initializeInternalDependencies() async {
    _conversation ??= (await CometChat.getConversation(
      group.guid,
      ConversationType.group,
      onSuccess: (conversation) {
        if (conversation.lastMessage != null) {}
      },
      onError: (_) {},
    ));
    _conversationId ??= _conversation?.conversationId;
  }

  @override
  void onClose() {
    CometChat.removeGroupListener(groupSDKListenerID);
    CometChatGroupEvents.removeGroupsListener(groupUIListenerID);
    if (usersStatusVisibility == true) {
      CometChat.removeUserListener(userSDKListenerID);
    }

    super.onClose();
  }

  //------------------User SDK Listeners------------------
  @override
  void onUserOffline(User user) {
    int matchingIndex = getMatchingIndexFromKey(user.uid);
    if (matchingIndex != -1) {
      list[matchingIndex].status = user.status;
      update();
    }
  }

  @override
  void onUserOnline(User user) {
    int matchingIndex = getMatchingIndexFromKey(user.uid);
    if (matchingIndex != -1) {
      list[matchingIndex].status = user.status;
      update();
    }
  }

  //------------------Group SDK Listeners------------------
  @override
  void onGroupMemberScopeChanged(
    cc.Action action,
    User updatedBy,
    User updatedUser,
    String scopeChangedTo,
    String scopeChangedFrom,
    Group group,
  ) {
    if (group.guid == this.group.guid) {
      int matchingIndex = getMatchingIndexFromKey(updatedUser.uid);
      if (matchingIndex != -1) {
        list[matchingIndex].scope = scopeChangedTo;
        update();
      }
    }
  }

  GroupMember? getGroupMemberFromUser(User user) {
    try {
      return list.cast<GroupMember?>().firstWhere(
        (element) => element!.uid == user.uid,
        orElse: () => null,
      );
    } catch (e) {
      if (kDebugMode) {
        ccLog('Error in getGroupMemberFromUser: $e');
      }
      return null;
    }
  }

  @override
  void onGroupMemberKicked(
    cc.Action action,
    User kickedUser,
    User kickedBy,
    Group kickedFrom,
  ) {
    if (kickedFrom.guid == group.guid) {
      GroupMember? member = getGroupMemberFromUser(kickedUser);
      if (member != null) {
        removeElement(member);
      }
    }
  }

  @override
  void onGroupMemberLeft(cc.Action action, User leftUser, Group leftGroup) {
    if (leftGroup.guid == group.guid) {
      GroupMember? member = getGroupMemberFromUser(leftUser);
      if (member != null) {
        removeElement(member);
      }
    }
  }

  @override
  void onGroupMemberBanned(
    cc.Action action,
    User bannedUser,
    User bannedBy,
    Group bannedFrom,
  ) {
    if (bannedFrom.guid == group.guid) {
      GroupMember? member = getGroupMemberFromUser(bannedUser);
      if (member != null) {
        removeElement(member);
      }
    }
  }

  @override
  void onGroupMemberJoined(
    cc.Action action,
    User joinedUser,
    Group joinedGroup,
  ) {
    if (joinedGroup.guid == group.guid) {
      addElement(joinedUser as GroupMember);
    }
  }

  @override
  void onMemberAddedToGroup(
    cc.Action action,
    User addedby,
    User userAdded,
    Group addedTo,
  ) {
    if (addedTo.guid == group.guid) {
      addElement(addedTo as GroupMember);
    }
  }

  Future<void> changeScope(
    Group group,
    GroupMember member,
    String newScope,
    String oldScope,
  ) async {
    await CometChat.updateGroupMemberScope(
      guid: group.guid,
      uid: member.uid,
      scope: newScope,
      onSuccess: (String res) {
        member.scope = newScope;
        CometChatGroupEvents.ccGroupMemberScopeChanged(
          cc.Action(
            conversationId: _conversationId!,
            message: "${loggedInUser?.name} made ${member.name} $newScope",
            oldScope: oldScope,
            newScope: newScope,
            muid: DateTime.now().microsecondsSinceEpoch.toString(),
            sender: loggedInUser!,
            receiverUid: group.guid,
            type: MessageTypeConstants.groupActions,
            receiverType: ReceiverTypeConstants.group,
            parentMessageId: 0,
          ),
          member,
          newScope,
          oldScope,
          group,
        );
        updateElement(member);
      },
      onError: onError,
    );
  }

  @override
  ccGroupMemberAdded(
    List<cc.Action> messages,
    List<User> usersAdded,
    Group groupAddedIn,
    User addedBy,
  ) {
    if (groupAddedIn.guid == group.guid) {
      for (User user in usersAdded) {
        addElement(user as GroupMember);
      }
    }
  }

  @override
  ccOwnershipChanged(Group group, GroupMember newOwner) {
    if (group.guid == group.guid) {
      updateElement(newOwner);
    }
  }

  //CometChatListController override  functions
  @override
  bool match(GroupMember elementA, GroupMember elementB) {
    return elementA.uid == elementB.uid;
  }

  @override
  String getKey(GroupMember element) {
    return element.uid;
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

  //default functions
  @override
  List<CometChatOption> defaultFunction(
    Group group,
    GroupMember member,
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    List<CometChatOption> optionList = [];
    List<CometChatGroupMemberOption> groupMemberOptions = [];

    groupMemberOptions = DetailUtils.getDefaultGroupMemberOptions(
      loggedInUser: loggedInUser,
      group: group,
      member: member,
      context: context,
      hideBanMemberOption: hideBanMemberOption,
      hideKickMemberOption: hideKickMemberOption,
      hideScopeChangeOption: hideScopeChangeOption,
    );

    for (CometChatGroupMemberOption option in groupMemberOptions) {
      optionList.add(
        CometChatOption(
          id: option.id,
          title: option.title,
          packageName: option.packageName,
          backgroundColor: option.backgroundColor,
          icon: option.icon,
          iconTint: colorPalette.iconSecondary,
          onClick: () {
            final operations = _getOptionFunctionality(
              option.id,
              group,
              member,
              context,
              colorPalette,
              typography,
              spacing,
            );
            if (operations != null) {
              operations();
            }
          },
          iconWidget: option.iconWidget,
        ),
      );
    }

    return optionList;
  }

  final ValueNotifier<bool> isActionRunning = ValueNotifier<bool>(false);
  dynamic Function()? _getOptionFunctionality(
    String optionId,
    Group group,
    GroupMember member,
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    switch (optionId) {
      case GroupMemberOptionConstants.ban:
        return () async {
          showConfirmDialog(
            context,
            colorPalette,
            typography,
            spacing,
            title: "Ban ${member.name}?",
            icon: Icon(
              Icons.not_interested,
              size: 48,
              color: confirmDialogStyle?.iconColor ?? colorPalette.error,
            ),
            messageText:
                "${cc.Translations.of(context).areYouSureBan} ${member.name} ${cc.Translations.of(context).from} ${group.name}?",
            onConfirm: (dialogContext) {
              isActionRunning.value = true;
              CometChat.banGroupMember(
                guid: group.guid,
                uid: member.uid,
                onSuccess: (String result) async {
                  group.membersCount--;
                  CometChatGroupEvents.ccGroupMemberBanned(
                    cc.Action(
                      conversationId: _conversationId!,
                      message: "${loggedInUser?.name} banned ${member.name}",
                      oldScope: GroupMemberScope.participant,
                      newScope: '',
                      muid: DateTime.now().microsecondsSinceEpoch.toString(),
                      sender: loggedInUser!,
                      receiver: group,
                      receiverUid: group.guid,
                      type: MessageTypeConstants.groupActions,
                      receiverType: ReceiverTypeConstants.group,
                      parentMessageId: 0,
                    ),
                    member,
                    loggedInUser!,
                    group,
                  );
                  removeElement(member);
                  isActionRunning.value = false;
                  Navigator.of(dialogContext).pop();
                },
                onError: (exception) {
                  if (onError != null) {
                    onError!(exception);
                  }
                  isActionRunning.value = false;
                  Navigator.of(dialogContext).pop();
                },
              );
            },
            confirmButtonText: cc.Translations.of(context).ban.toUpperCase(),
          );
        };
      case GroupMemberOptionConstants.kick:
        return () async {
          showConfirmDialog(
            context,
            colorPalette,
            typography,
            spacing,
            title: "${cc.Translations.of(context).kick} ${member.name}?",
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 48,
              color: confirmDialogStyle?.iconColor ?? colorPalette.error,
            ),
            messageText:
                "${cc.Translations.of(context).areYouSureRemove} ${member.name} ${cc.Translations.of(context).from} ${group.name}?",
            onConfirm: (dialogContext) {
              isActionRunning.value = true;
              CometChat.kickGroupMember(
                guid: group.guid,
                uid: member.uid,
                onSuccess: (String result) async {
                  group.membersCount--;
                  CometChatGroupEvents.ccGroupMemberKicked(
                    cc.Action(
                      conversationId: _conversationId!,
                      message: '${loggedInUser?.name} kicked ${member.name}',
                      oldScope: GroupMemberScope.participant,
                      newScope: '',
                      muid: DateTime.now().microsecondsSinceEpoch.toString(),
                      sender: loggedInUser!,
                      receiver: group,
                      receiverUid: group.guid,
                      type: MessageTypeConstants.groupActions,
                      receiverType: ReceiverTypeConstants.group,
                      parentMessageId: 0,
                    ),
                    member,
                    loggedInUser!,
                    group,
                  );
                  removeElement(member);
                  isActionRunning.value = false;
                  Navigator.of(dialogContext).pop();
                },
                onError: (excep) {
                  if (onError != null) {
                    onError!(excep);
                  }
                  isActionRunning.value = false;
                  Navigator.of(dialogContext).pop();
                },
              );
            },
            confirmButtonText: cc.Translations.of(context).kick.toUpperCase(),
          );
        };
      case GroupMemberOptionConstants.changeScope:
        showModalBottomSheet(
          context: context,
          barrierColor: (colorPalette.textPrimary ?? const Color(0xFF141414))
              .withValues(alpha: 0.8),
          builder: (context) => SingleChildScrollView(
            child: CometChatChangeScope(
              group: group,
              member: member,
              onSave: changeScope,
              style: changeScopeStyle,
            ),
          ),
        );
        break;
      default:
        return null;
    }
    return null;
  }

  void clearSelection() {
    selectionMap.clear();
    update();
  }

  void showConfirmDialog(
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing, {
    Function(BuildContext)? onConfirm,
    Widget? icon,
    String? title,
    String? messageText,
    String? confirmButtonText,
  }) {
    CometChatConfirmDialog(
      context: context,
      confirmButtonText: cc.Translations.of(context).deleteCapital,
      cancelButtonText: cc.Translations.of(context).cancelCapital,
      icon: icon,
      title: Text(title ?? "", textAlign: TextAlign.center),
      messageText: Text(messageText ?? "", textAlign: TextAlign.center),
      onCancel: (dialogContext) {
        isActionRunning.value = false;
        Navigator.of(dialogContext).pop();
      },
      style: CometChatConfirmDialogStyle(
        iconColor: confirmDialogStyle?.iconColor ?? colorPalette.error,
        backgroundColor: confirmDialogStyle?.backgroundColor,
        shadow: confirmDialogStyle?.shadow,
        iconBackgroundColor: confirmDialogStyle?.iconBackgroundColor,
        borderRadius: confirmDialogStyle?.borderRadius,
        border: confirmDialogStyle?.border,
        cancelButtonBackground:
            confirmDialogStyle?.cancelButtonBackground ??
            colorPalette.borderLight,
        confirmButtonBackground:
            confirmDialogStyle?.confirmButtonBackground ?? colorPalette.error,
        cancelButtonTextColor: confirmDialogStyle?.cancelButtonTextColor,
        confirmButtonTextColor: confirmDialogStyle?.confirmButtonTextColor,
        messageTextColor: confirmDialogStyle?.messageTextColor,
        titleTextColor: confirmDialogStyle?.titleTextColor,
        titleTextStyle:
            TextStyle(
                  color:
                      confirmDialogStyle?.titleTextColor ??
                      colorPalette.textPrimary,
                  fontSize: typography.heading2?.medium?.fontSize,
                  fontWeight: typography.heading2?.medium?.fontWeight,
                  fontFamily: typography.heading2?.medium?.fontFamily,
                )
                .merge(confirmDialogStyle?.titleTextStyle)
                .copyWith(color: confirmDialogStyle?.titleTextColor),
        messageTextStyle:
            TextStyle(
                  color:
                      confirmDialogStyle?.messageTextColor ??
                      colorPalette.textSecondary,
                  fontSize: typography.body?.regular?.fontSize,
                  fontWeight: typography.body?.regular?.fontWeight,
                  fontFamily: typography.body?.regular?.fontFamily,
                )
                .merge(confirmDialogStyle?.messageTextStyle)
                .copyWith(color: confirmDialogStyle?.messageTextColor),
        confirmButtonTextStyle:
            TextStyle(
                  color:
                      confirmDialogStyle?.confirmButtonTextColor ??
                      colorPalette.white,
                  fontSize: typography.button?.medium?.fontSize,
                  fontWeight: typography.button?.medium?.fontWeight,
                  fontFamily: typography.button?.medium?.fontFamily,
                )
                .merge(confirmDialogStyle?.confirmButtonTextStyle)
                .copyWith(color: confirmDialogStyle?.confirmButtonTextColor),
        cancelButtonTextStyle:
            TextStyle(
                  color:
                      confirmDialogStyle?.cancelButtonTextColor ??
                      colorPalette.textPrimary,
                  fontSize: typography.button?.medium?.fontSize,
                  fontWeight: typography.button?.medium?.fontWeight,
                  fontFamily: typography.button?.medium?.fontFamily,
                )
                .merge(confirmDialogStyle?.cancelButtonTextStyle)
                .copyWith(color: confirmDialogStyle?.cancelButtonTextColor),
      ),
      onConfirm: onConfirm,
      confirmButtonTextWidget: ValueListenableBuilder<bool>(
        valueListenable: isActionRunning,
        builder: (context, running, _) => running
            ? SizedBox(
                height: 25,
                width: 25,
                child: CircularProgressIndicator(color: colorPalette.white),
              )
            : Text(
                confirmButtonText ?? "",
                style:
                    TextStyle(
                          color:
                              confirmDialogStyle?.confirmButtonTextColor ??
                              colorPalette.white,
                          fontSize: typography.button?.medium?.fontSize,
                          fontWeight: typography.button?.medium?.fontWeight,
                          fontFamily: typography.button?.medium?.fontFamily,
                        )
                        .merge(confirmDialogStyle?.confirmButtonTextStyle)
                        .copyWith(
                          color: confirmDialogStyle?.confirmButtonTextColor,
                        ),
              ),
      ),
    ).show();
  }
}
