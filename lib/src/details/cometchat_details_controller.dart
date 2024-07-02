import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as cc;
import 'package:flutter/material.dart';

///[CometChatDetailsController] is the view model for [CometChatDetails]
///it contains all the business logic involved in changing the state of the UI of [CometChatDetails]
class CometChatDetailsController extends GetxController
    with UserListener, GroupListener, CometChatGroupEventListener
    implements CometChatDetailsControllerProtocol {
  CometChatDetailsController(this.user, this.group,
      {this.addMemberConfiguration,
      this.transferOwnershipConfiguration,
      this.bannedMemberConfiguration,
      this.stateCallBack,
      this.data,
      this.onError,
      this.groupMembersConfiguration,
      this.leaveGroupDialogStyle});

  ///to pass [user] , one of parameter [user] or [group] should be always populated
  final User? user;

  ///to pass [group] , one of parameter [user] or [group] should be always populated
  Group? group;

  ///configurations for opening add members
  final AddMemberConfiguration? addMemberConfiguration;

  ///configurations for opening transfer ownership
  final TransferOwnershipConfiguration? transferOwnershipConfiguration;

  ///configurations for opening transfer ownership
  final BannedMemberConfiguration? bannedMemberConfiguration;

  ///configurations for viewing group members
  final GroupMembersConfiguration? groupMembersConfiguration;

  ///[stateCallBack] a call back to give state to its parent
  final void Function(CometChatDetailsController)? stateCallBack;

  ///used to override list of templates is passed which is used for displaying relevant options
  final List<CometChatDetailsTemplate>? Function(Group? group, User? user)?
      data;

  ///[onError] callback triggered in case any error happens when fetching users
  final OnError? onError;

  ///[leaveGroupDialogStyle] used to customize the dialog box that pops up when trying to leave group
  final ConfirmDialogStyle? leaveGroupDialogStyle;

  late CometChatTheme theme;
  late String _dateString;
  late String _userListener;
  late String _groupListener;
  late String _uiGroupListener;
  late BuildContext context;

  int membersCount = 1;

  User? loggedInUser;

  List<CometChatDetailsTemplate> templateList = [];
  Map<String, List<CometChatDetailsOption>> optionsMap = {};

  Conversation? _conversation;

  String? _conversationId;

  //initialization methods--------------

  @override
  void onInit() {
    if (stateCallBack != null) {
      stateCallBack!(this);
    }
    _dateString = DateTime.now().millisecondsSinceEpoch.toString();
    _userListener = "${_dateString}UsersListener";
    _groupListener = "${_dateString}GroupsListener";
    _uiGroupListener = "${_dateString}UIGroupListener";
    _addListeners();
    initializeLoggedInUser();
    if (group != null && group?.membersCount != null) {
      membersCount = group?.membersCount ?? 1;
    }
    super.onInit();
  }

  initializeLoggedInUser() async {
    if (loggedInUser == null) {
      loggedInUser = await CometChat.getLoggedInUser();
      String id;
      String conversationType;
      if (user != null) {
        id = user!.uid;
        conversationType = ConversationType.user;
      } else {
        id = group!.guid;
        conversationType = ConversationType.group;
      }
      _conversation ??= (await CometChat.getConversation(id, conversationType,
          onSuccess: (conversation) {
        if (conversation.lastMessage != null) {}
      }, onError: (_) {}));
      _conversationId ??= _conversation?.conversationId;
      update();
    }
  }

  initializeSectionUtilities() {
    if (data != null) {
      templateList = data!(group, user) ?? [];
    } else {
      templateList = DetailUtils.getDefaultDetailsTemplates(
          context, loggedInUser,
          user: user, group: group);
    }

    _setOptions();
  }

  @override
  void onClose() {
    _removeListeners();
    super.onClose();
  }

  _addListeners() {
    CometChat.addUserListener(_userListener, this);
    CometChat.addGroupListener(_groupListener, this);
    CometChatGroupEvents.addGroupsListener(_uiGroupListener, this);
  }

  _removeListeners() {
    CometChat.removeUserListener(_userListener);
    CometChat.removeGroupListener(_groupListener);
    CometChatGroupEvents.removeGroupsListener(_uiGroupListener);
  }

  //initialization methods end--------------

  //--------SDK User Listeners

  @override
  void onUserOnline(User user) {
    if (this.user != null && user.uid == this.user?.uid) {
      this.user?.status = CometChatUserStatus.online;
    }
    update();
  }

  @override
  void onUserOffline(User user) {
    if (this.user != null && user.uid == this.user?.uid) {
      this.user?.status = CometChatUserStatus.offline;
    }
    update();
  }

  //------------------SDK user listeners end---------

  //-----------Group SDK listeners---------------------------------
  @override
  void onGroupMemberScopeChanged(
      cc.Action action,
      User updatedBy,
      User updatedUser,
      String scopeChangedTo,
      String scopeChangedFrom,
      Group group) {
    if (group.guid == this.group?.guid &&
        updatedUser.uid == loggedInUser?.uid) {
      this.group?.scope = scopeChangedTo;
      update();
    }
  }

  @override
  void onGroupMemberKicked(
      cc.Action action, User kickedUser, User kickedBy, Group kickedFrom) {
    if (kickedFrom.guid == group?.guid) {
      membersCount = kickedFrom.membersCount;
      update();
    }
  }

  @override
  void onGroupMemberBanned(
      cc.Action action, User bannedUser, User bannedBy, Group bannedFrom) {
    if (bannedFrom.guid == group?.guid) {
      membersCount = bannedFrom.membersCount;
      update();
    }
  }

  @override
  void onGroupMemberLeft(cc.Action action, User leftUser, Group leftGroup) {
    if (leftGroup.guid == group?.guid) {
      membersCount = leftGroup.membersCount;
      update();
    }
  }

  @override
  void onMemberAddedToGroup(
      cc.Action action, User addedby, User userAdded, Group addedTo) {
    if (addedTo.guid == group?.guid) {
      membersCount = addedTo.membersCount;
      update();
    }
  }

  @override
  void onGroupMemberJoined(
      cc.Action action, User joinedUser, Group joinedGroup) {
    if (joinedGroup.guid == group?.guid) {
      membersCount = joinedGroup.membersCount;
      update();
    }
  }

  @override
  void ccOwnershipChanged(Group group, GroupMember newOwner) {
    if (group.guid == this.group?.guid) {
      group.owner = newOwner.uid;
      update();
    }
  }

  //-------------Group SDK listeners end---------------

  //From UI listeners

  @override
  void ccGroupMemberBanned(
      cc.Action message, User bannedUser, User bannedBy, Group bannedFrom) {
    if (group?.guid == bannedFrom.guid) {
      membersCount = bannedFrom.membersCount;
      update();
    }
  }

  @override
  void ccGroupMemberKicked(
      cc.Action message, User kickedUser, User kickedBy, Group kickedFrom) {
    if (group?.guid == kickedFrom.guid) {
      membersCount = kickedFrom.membersCount;
      update();
    }
  }

  @override
  onViewMemberClicked(Group group) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CometChatGroupMembers(
                  group: group,
                  activateSelection:
                      groupMembersConfiguration?.activateSelection,
                  appBarOptions: groupMembersConfiguration?.appBarOptions,
                  avatarStyle: groupMembersConfiguration?.avatarStyle,
                  backButton: groupMembersConfiguration?.backButton,
                  controller: groupMembersConfiguration?.controller,
                  disableUsersPresence:
                      groupMembersConfiguration?.disableUsersPresence ?? false,
                  emptyStateText: groupMembersConfiguration?.emptyStateText,
                  emptyStateView: groupMembersConfiguration?.emptyStateView,
                  errorStateText: groupMembersConfiguration?.errorStateText,
                  errorStateView: groupMembersConfiguration?.errorStateView,
                  groupMemberStyle:
                      groupMembersConfiguration?.groupMemberStyle ??
                          const GroupMembersStyle(),
                  groupMembersProtocol:
                      groupMembersConfiguration?.groupMembersProtocol,
                  groupMembersRequestBuilder:
                      groupMembersConfiguration?.groupMembersRequestBuilder,
                  groupScopeStyle: groupMembersConfiguration?.groupScopeStyle,
                  hideError: groupMembersConfiguration?.hideError,
                  hideSearch: groupMembersConfiguration?.hideSearch ?? false,
                  hideSeparator: groupMembersConfiguration?.hideSeparator,
                  listItemStyle: groupMembersConfiguration?.listItemStyle,
                  listItemView: groupMembersConfiguration?.listItemView,
                  loadingStateView: groupMembersConfiguration?.loadingStateView,
                  onBack: groupMembersConfiguration?.onBack,
                  onError: groupMembersConfiguration?.onError,
                  onItemLongPress: groupMembersConfiguration?.onItemLongPress,
                  onItemTap: groupMembersConfiguration?.onItemTap,
                  onSelection: groupMembersConfiguration?.onSelection,
                  options: groupMembersConfiguration?.options,
                  searchBoxIcon: groupMembersConfiguration?.searchBoxIcon,
                  searchPlaceholder:
                      groupMembersConfiguration?.searchPlaceholder,
                  selectIcon: groupMembersConfiguration?.selectIcon,
                  selectionMode: groupMembersConfiguration?.selectionMode,
                  showBackButton:
                      groupMembersConfiguration?.showBackButton ?? true,
                  stateCallBack: groupMembersConfiguration?.stateCallBack,
                  statusIndicatorStyle:
                      groupMembersConfiguration?.statusIndicatorStyle,
                  submitIcon: groupMembersConfiguration?.submitIcon,
                  subtitleView: groupMembersConfiguration?.subtitleView,
                  tailView: groupMembersConfiguration?.tailView,
                  theme: groupMembersConfiguration?.theme ?? theme,
                  title: groupMembersConfiguration?.title,
                )));
  }

  @override
  void ccGroupMemberAdded(List<cc.Action> messages, List<User> usersAdded,
      Group groupAddedIn, User addedBy) {
    if (groupAddedIn.guid == group?.guid) {
      membersCount = groupAddedIn.membersCount;
      update();
    }
  }

  @override
  onAddMemberClicked(Group group) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CometChatAddMembers(
                  group: group,
                  title: addMemberConfiguration?.title,
                  hideSearch: addMemberConfiguration?.hideSearch,
                  theme: addMemberConfiguration?.theme ?? theme,
                  backButton: addMemberConfiguration?.backButton,
                  showBackButton:
                      addMemberConfiguration?.showBackButton ?? true,
                  searchIcon: addMemberConfiguration?.searchIcon,
                  searchPlaceholder: addMemberConfiguration?.searchPlaceholder,
                  addMembersStyle: addMemberConfiguration?.addMembersStyle,
                  appBarOptions: addMemberConfiguration?.appBarOptions,
                  disableUsersPresence:
                      addMemberConfiguration?.disableUsersPresence,
                  emptyStateText: addMemberConfiguration?.emptyStateText,
                  emptyStateView: addMemberConfiguration?.emptyStateView,
                  errorStateText: addMemberConfiguration?.errorStateText,
                  errorStateView: addMemberConfiguration?.errorStateView,
                  hideError: addMemberConfiguration?.hideError,
                  hideSeparator: addMemberConfiguration?.hideSeparator,
                  listItemView: addMemberConfiguration?.listItemView,
                  loadingStateView: addMemberConfiguration?.loadingStateView,
                  onBack: addMemberConfiguration?.onBack,
                  onSelection: addMemberConfiguration?.onSelection,
                  options: addMemberConfiguration?.options,
                  selectionMode: addMemberConfiguration?.selectionMode ??
                      SelectionMode.multiple,
                  subtitleView: addMemberConfiguration?.subtitleView,
                  usersProtocol: addMemberConfiguration?.usersProtocol,
                  usersRequestBuilder:
                      addMemberConfiguration?.usersRequestBuilder,
                  selectionIcon: addMemberConfiguration?.selectionIcon,
                  onError: addMemberConfiguration?.onError,
                  avatarStyle: addMemberConfiguration?.avatarStyle,
                  listItemStyle: addMemberConfiguration?.listItemStyle,
                  statusIndicatorStyle:
                      addMemberConfiguration?.statusIndicatorStyle,
                  submitIcon: addMemberConfiguration?.submitIcon,
                )));
  }

  @override
  onTransferOwnershipClicked(Group group) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CometChatTransferOwnership(
                  group: group,
                  title: transferOwnershipConfiguration?.title,
                  transferOwnershipStyle:
                      transferOwnershipConfiguration?.transferOwnershipStyle,
                  hideSearch: transferOwnershipConfiguration?.hideSearch,
                  showBackButton:
                      transferOwnershipConfiguration?.showBackButton,
                  backButton: transferOwnershipConfiguration?.backButton,
                  searchBoxIcon: transferOwnershipConfiguration?.searchBoxIcon,
                  searchPlaceholder:
                      transferOwnershipConfiguration?.searchPlaceholder,
                  disableUsersPresence:
                      transferOwnershipConfiguration?.disableUsersPresence ??
                          false,
                  emptyStateText:
                      transferOwnershipConfiguration?.emptyStateText,
                  errorStateText:
                      transferOwnershipConfiguration?.errorStateText,
                  avatarStyle: transferOwnershipConfiguration?.avatarStyle,
                  emptyStateView:
                      transferOwnershipConfiguration?.emptyStateView,
                  errorStateView:
                      transferOwnershipConfiguration?.emptyStateView,
                  groupMemberStyle:
                      transferOwnershipConfiguration?.groupMemberStyle,
                  groupMembersRequestBuilder: transferOwnershipConfiguration
                      ?.groupMembersRequestBuilder,
                  groupMembersProtocol:
                      transferOwnershipConfiguration?.groupMembersProtocol,
                  hideSeparator: transferOwnershipConfiguration?.hideSeparator,
                  listItemStyle: transferOwnershipConfiguration?.listItemStyle,
                  loadingStateView:
                      transferOwnershipConfiguration?.loadingStateView,
                  statusIndicatorStyle:
                      transferOwnershipConfiguration?.statusIndicatorStyle,
                  subtitleView: transferOwnershipConfiguration?.subtitleView,
                  onTransferOwnership:
                      transferOwnershipConfiguration?.onTransferOwnership,
                  selectIcon: transferOwnershipConfiguration?.selectIcon,
                  submitIcon: transferOwnershipConfiguration?.submitIcon,
                  theme: transferOwnershipConfiguration?.theme ?? theme,
                  onBack: transferOwnershipConfiguration?.onBack,
                  onError: transferOwnershipConfiguration?.onError ?? onError,
                )));
  }

  @override
  onBanMemberClicked(Group group) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CometChatBannedMembers(
            group: group,
            theme: bannedMemberConfiguration?.theme ?? theme,
            backButton: bannedMemberConfiguration?.backButton,
            controller: bannedMemberConfiguration?.controller,
            listItemView: bannedMemberConfiguration?.childView,
            emptyStateText: bannedMemberConfiguration?.emptyStateText,
            errorStateText: bannedMemberConfiguration?.errorStateText,
            hideSearch: bannedMemberConfiguration?.hideSearch ?? true,
            hideSeparator: bannedMemberConfiguration?.hideSeparator,
            onSelection: bannedMemberConfiguration?.onSelection,
            searchBoxIcon: bannedMemberConfiguration?.searchBoxIcon,
            searchPlaceholder: bannedMemberConfiguration?.searchPlaceholder,
            selectionMode: bannedMemberConfiguration?.selectionMode,
            showBackButton: bannedMemberConfiguration?.showBackButton ?? true,
            bannedMembersStyle: bannedMemberConfiguration?.bannedMembersStyle ??
                const BannedMembersStyle(),
            title: bannedMemberConfiguration?.title,
            subtitleView: bannedMemberConfiguration?.subtitleView,
            avatarStyle: bannedMemberConfiguration?.avatarStyle,
            emptyStateView: bannedMemberConfiguration?.emptyStateView,
            errorStateView: bannedMemberConfiguration?.errorStateView,
            loadingStateView: bannedMemberConfiguration?.loadingStateView,
            hideError: bannedMemberConfiguration?.hideError,
            disableUsersPresence:
                bannedMemberConfiguration?.disableUsersPresence ?? false,
            statusIndicatorStyle:
                bannedMemberConfiguration?.statusIndicatorStyle,
            options: bannedMemberConfiguration?.options,
            activateSelection: bannedMemberConfiguration?.activateSelection,
            appBarOptions: bannedMemberConfiguration?.appBarOptions,
            bannedMemberProtocol:
                bannedMemberConfiguration?.bannedMemberProtocol,
            bannedMemberRequestBuilder:
                bannedMemberConfiguration?.bannedMemberRequestBuilder,
            listItemStyle: bannedMemberConfiguration?.listItemStyle,
            onBack: bannedMemberConfiguration?.onBack,
            onError: bannedMemberConfiguration?.onError ?? onError,
            onItemTap: bannedMemberConfiguration?.onItemTap,
            onItemLongPress: bannedMemberConfiguration?.onItemLongPress,
            unbanIconUrl: bannedMemberConfiguration?.unbanIconUrl,
            unbanIconUrlPackageName:
                bannedMemberConfiguration?.unbanIconUrlPackageName,
            stateCallBack: bannedMemberConfiguration?.stateCallBack,
          ),
        ));
  }

  //UI Group Listeners--------

  //------------View Methods-------------------

//predefined template option functions--------------------
  _blockUser(User? user, Group? group, String section,
      CometChatDetailsControllerProtocol state) async {
    if (user != null) {
      await CometChat.blockUser([user.uid],
          onSuccess: (Map<String, dynamic> map) {
        if (this.user != null) {
          this.user!.blockedByMe = true;
        }
        updateOption(section, UserOptionConstants.blockUser,
            DetailUtils.getUnBlockUserOption(context));
        CometChatUserEvents.ccUserBlocked(user);
      }, onError: onError);
    }
  }

  _unBlockUser(User? user, Group? group, String section,
      CometChatDetailsControllerProtocol state) async {
    if (user != null) {
      await CometChat.unblockUser([user.uid],
          onSuccess: (Map<String, dynamic> map) {
        if (this.user != null) {
          this.user!.blockedByMe = false;
        }

        updateOption(section, UserOptionConstants.unblockUser,
            DetailUtils.getBlockUserOption(context));
        CometChatUserEvents.ccUserUnblocked(user);
      }, onError: onError);
    }
  }

  _viewMember(User? user, Group? group, String section,
      CometChatDetailsControllerProtocol state) {
    if (group != null) {
      onViewMemberClicked(group);
    }
  }

  _addMember(User? user, Group? group, String section,
      CometChatDetailsControllerProtocol state) {
    if (group != null) {
      onAddMemberClicked(group);
    }
  }

  _banMember(User? user, Group? group, String section,
      CometChatDetailsControllerProtocol state) {
    if (group != null) {
      onBanMemberClicked(group);
    }
  }

  _deleteGroup(User? user, Group? group, String section,
      CometChatDetailsControllerProtocol state) {
    if (group != null && (group.owner == loggedInUser?.uid)) {
      _showConfirmationDialog(
          messageText: Translations.of(context).deleteConfirm,
          confirmButtonText: Translations.of(context).delete.toUpperCase(),
          confirmButtonTextStyle: TextStyle(
              fontSize: theme.typography.text2.fontSize,
              color: theme.palette.error.light),
          onConfirm: _onDeleteGroupConfirmed);
    }
  }

  _leaveGroup(User? user, Group? group, String section,
      CometChatDetailsControllerProtocol state) async {
    if (group != null) {
      if (loggedInUser == null) return;

      if (group.owner == loggedInUser?.uid) {
        _showConfirmationDialog(
            messageText: Translations.of(context).transferOwnership,
            confirmButtonText: "TRANSFER OWNERSHIP",
            confirmButtonTextStyle:
                TextStyle(fontSize: theme.typography.text2.fontSize),
            onConfirm: _onTransferOwnershipConfirmed);
      } else {
        _showConfirmationDialog(
          messageText: Translations.of(context).leaveConfirm,
          confirmButtonText: Translations.of(context).leaveGroup.toUpperCase(),
          confirmButtonTextStyle: TextStyle(
              fontSize: theme.typography.text2.fontSize,
              color: theme.palette.error.light),
          onConfirm: _onLeaveGroupConfirmed,
        );
      }
    }
  }

  //predefined template option functions end --------------------

  //Utility functions-------------

  //set options in option map after populating onClick
  _setOptions() {
    for (CometChatDetailsTemplate template in templateList) {
      optionsMap[template.id] = _getPopulatedOptions(template) ?? [];
    }
  }

  //returns list of detail options after populating default options if function is null
  List<CometChatDetailsOption>? _getPopulatedOptions(
      CometChatDetailsTemplate template) {
    List<CometChatDetailsOption>? options;
    if (template.options != null) {
      options = template.options!(user, group, context, theme);
    }

    //Getting initial option List
    //checking individual option if null then passing the new option
    if (options!.isEmpty) return options;

    for (CometChatDetailsOption option in options) {
      option.onClick ??= _getOptionOnClick(option.id);
    }
    return options;
  }

  //returns default options according to option id
  Function(User? user, Group? group, String section,
          CometChatDetailsControllerProtocol state)?
      _getOptionOnClick(String optionId) {
    switch (optionId) {
      case UserOptionConstants.blockUser:
        {
          return _blockUser;
        }
      case UserOptionConstants.unblockUser:
        {
          return _unBlockUser;
        }
      case GroupOptionConstants.viewMembers:
        {
          return _viewMember;
        }
      case GroupOptionConstants.addMembers:
        {
          return _addMember;
        }
      case GroupOptionConstants.bannedMembers:
        {
          return _banMember;
        }
      case GroupOptionConstants.delete:
        {
          return _deleteGroup;
        }
      case GroupOptionConstants.leave:
        {
          return _leaveGroup;
        }
      default:
        {
          return null;
        }
    }
  }

  //Utility functions end------------

  //public methods----------------------

  @override
  int updateOption(String templateId, String oldOptionID,
      CometChatDetailsOption updatedOption) {
    int actionIndex = -1;
    if (optionsMap[templateId] != null) {
      int? optionIndex = optionsMap[templateId]
          ?.indexWhere((element) => (element.id == oldOptionID));
      if (optionIndex != null && optionIndex != -1) {
        updatedOption.onClick ??= _getOptionOnClick(updatedOption.id);
        optionsMap[templateId]![optionIndex] = updatedOption;
        update();
        actionIndex = optionIndex;
      }
    }
    return actionIndex;
  }

  @override
  int removeOption(String templateId, String optionId) {
    int actionIndex = -1;
    if (optionsMap[templateId] != null) {
      int? optionIndex = optionsMap[templateId]
          ?.indexWhere((element) => (element.id == optionId));
      if (optionIndex != null && optionIndex != -1) {
        optionsMap[templateId]!.removeAt(optionIndex);
        actionIndex = optionIndex;
        update();
      }
    }
    return actionIndex;
  }

  @override
  int addOption(String templateId, CometChatDetailsOption newOption,
      {int? position}) {
    int actionIndex = -1;
    if (optionsMap[templateId] != null) {
      if (position != null && position < optionsMap[templateId]!.length) {
        optionsMap[templateId]!.insert(position, newOption);
        actionIndex = position;
      } else {
        optionsMap[templateId]!.add(newOption);
        actionIndex = optionsMap[templateId]!.length;
      }

      update();
    }
    return actionIndex;
  }

  @override
  useOption(CometChatDetailsOption option, String sectionId) {
    if (option.onClick != null) {
      debugPrint(
          "option clicked on ID is ${option.id} and title is ${option.title}");
      option.onClick!(user, group, sectionId, this);
    }
  }

  //public methods end---------------

  _showConfirmationDialog(
      {required String messageText,
      dynamic Function()? onConfirm,
      String? confirmButtonText,
      TextStyle? confirmButtonTextStyle}) {
    showCometChatConfirmDialog(
        context: context,
        messageText: Text(messageText,
            style: TextStyle(
              color: theme.palette.getAccent700(),
              fontSize: theme.typography.title2.fontSize,
              fontFamily: theme.typography.title2.fontFamily,
              fontWeight: theme.typography.title2.fontWeight,
            )),
        onConfirm: onConfirm,
        cancelButtonText: Translations.of(context).cancel.toUpperCase(),
        confirmButtonText: confirmButtonText,
        style: ConfirmDialogStyle(
            backgroundColor: leaveGroupDialogStyle?.backgroundColor ??
                (theme.palette.mode == PaletteThemeModes.light
                    ? theme.palette.getBackground()
                    : Color.alphaBlend(theme.palette.getAccent200(),
                        theme.palette.getBackground())),
            shadowColor: leaveGroupDialogStyle?.shadowColor ??
                theme.palette.getAccent100(),
            confirmButtonTextStyle: confirmButtonTextStyle
                ?.merge(leaveGroupDialogStyle?.confirmButtonTextStyle),
            cancelButtonTextStyle:
                TextStyle(fontSize: theme.typography.text2.fontSize)
                    .merge(leaveGroupDialogStyle?.cancelButtonTextStyle)));
  }

  _onLeaveGroupConfirmed() {
    if (group == null) return;
    Navigator.of(context).pop();
    CometChat.leaveGroup(group!.guid, onSuccess: (String response) {
      group?.membersCount--;
      CometChatGroupEvents.ccGroupLeft(
          cc.Action(
            conversationId: _conversationId!,
            message: '${loggedInUser?.name} left',
            oldScope: group!.scope ?? GroupMemberScope.participant,
            newScope: '',
            muid: DateTime.now().microsecondsSinceEpoch.toString(),
            sender: loggedInUser!,
            receiverUid: group!.guid,
            type: MessageTypeConstants.groupActions,
            receiverType: ReceiverTypeConstants.group,
          ),
          loggedInUser!,
          group!);
      membersCount = group!.membersCount;
      Navigator.of(context).pop(1);
    }, onError: onError);
  }

  _onTransferOwnershipConfirmed() {
    if (group == null) return;
    Navigator.of(context).pop();
    onTransferOwnershipClicked(group!);
  }

  _onDeleteGroupConfirmed() {
    if (group == null) return;
    Navigator.of(context).pop();
    CometChat.deleteGroup(group!.guid, onSuccess: (String message) {
      CometChatGroupEvents.ccGroupDeleted(group!);
      Navigator.of(context).pop(1);
    }, onError: onError);
  }

  @override
  Map<String, List<CometChatDetailsOption>> getDetailsOptionMap() {
    return optionsMap;
  }

  @override
  List<CometChatDetailsTemplate> getDetailsTemplateList() {
    return templateList;
  }
}
