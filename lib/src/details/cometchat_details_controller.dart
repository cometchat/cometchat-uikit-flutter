import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart' as cc;
import 'package:flutter/material.dart';

class CometChatDetailsController extends GetxController
    with UserListener, GroupListener, CometChatGroupEventListener {
  CometChatDetailsController(this.user, this.group,
      {this.addMemberConfiguration,
      this.transferOwnershipConfiguration,
      this.bannedMemberConfiguration,
      this.stateCallBack,
      this.data,
      this.onError,
      this.viewMembersConfiguration});

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

  ///configurations for opening view members
  final GroupMembersConfiguration? viewMembersConfiguration;

  ///[stateCallBack] a call back to give state to its parent
  final void Function(CometChatDetailsController)? stateCallBack;

  ///used to override list of templates is passed which is used for displaying relevant options
  final List<CometChatDetailsTemplate>? Function(Group? group, User? user)?
      data;

  ///[onError] callback triggered in case any error happens when fetching users
  final OnError? onError;

  // class variables-----------------
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
          onSuccess: (_conversation) {
        if (_conversation.lastMessage != null) {}
      }, onError: (_) {}));
      _conversationId ??= _conversation?.conversationId;
      update();
    }
  }

  initializeSectionUtilities() {
    if (data != null && templateList.isEmpty) {
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
    if (group.guid == this.group?.guid) {
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

  onViewMemberClicked(Group group) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CometChatGroupMembers(
                  group: group,
                  activateSelection:
                      viewMembersConfiguration?.activateSelection,
                  appBarOptions: viewMembersConfiguration?.appBarOptions,
                  avatarStyle: viewMembersConfiguration?.avatarStyle,
                  backButton: viewMembersConfiguration?.backButton,
                  controller: viewMembersConfiguration?.controller,
                  disableUsersPresence:
                      viewMembersConfiguration?.disableUsersPresence ?? false,
                  emptyStateText: viewMembersConfiguration?.emptyStateText,
                  emptyStateView: viewMembersConfiguration?.emptyStateView,
                  errorStateText: viewMembersConfiguration?.errorStateText,
                  errorStateView: viewMembersConfiguration?.errorStateView,
                  groupMemberStyle:
                      viewMembersConfiguration?.groupMemberStyle ??
                          const GroupMembersStyle(),
                  groupMembersProtocol:
                      viewMembersConfiguration?.groupMembersProtocol,
                  groupMembersRequestBuilder:
                      viewMembersConfiguration?.groupMembersRequestBuilder,
                  groupScopeStyle: viewMembersConfiguration?.groupScopeStyle,
                  hideError: viewMembersConfiguration?.hideError,
                  hideSearch: viewMembersConfiguration?.hideSearch ?? false,
                  hideSeparator: viewMembersConfiguration?.hideSeparator,
                  listItemStyle: viewMembersConfiguration?.listItemStyle,
                  listItemView: viewMembersConfiguration?.listItemView,
                  loadingStateView: viewMembersConfiguration?.loadingStateView,
                  onBack: viewMembersConfiguration?.onBack,
                  onError: viewMembersConfiguration?.onError,
                  onItemLongPress: viewMembersConfiguration?.onItemLongPress,
                  onItemTap: viewMembersConfiguration?.onItemTap,
                  onSelection: viewMembersConfiguration?.onSelection,
                  options: viewMembersConfiguration?.options,
                  searchBoxIcon: viewMembersConfiguration?.searchBoxIcon,
                  searchPlaceholder:
                      viewMembersConfiguration?.searchPlaceholder,
                  selectIcon: viewMembersConfiguration?.selectIcon,
                  selectionMode: viewMembersConfiguration?.selectionMode,
                  showBackButton:
                      viewMembersConfiguration?.showBackButton ?? true,
                  stateCallBack: viewMembersConfiguration?.stateCallBack,
                  statusIndicatorStyle:
                      viewMembersConfiguration?.statusIndicatorStyle,
                  submitIcon: viewMembersConfiguration?.submitIcon,
                  subtitleView: viewMembersConfiguration?.subtitleView,
                  tailView: viewMembersConfiguration?.tailView,
                  theme: viewMembersConfiguration?.theme ?? theme,
                  title: viewMembersConfiguration?.title,
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

  onAddMemberClicked(Group group) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CometChatAddMembers(
                  group: group,
                  title: addMemberConfiguration?.title,
                  hideSearch: addMemberConfiguration?.hideSearch,
                  theme: theme,
                  backButton: addMemberConfiguration?.backButton,
                  showBackButton:
                      addMemberConfiguration?.showBackButton ?? true,
                  searchIcon: addMemberConfiguration?.searchIcon,
                  searchPlaceholder: addMemberConfiguration?.searchPlaceholder,
                  style: addMemberConfiguration?.style,
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
                )));
  }

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
                  theme: transferOwnershipConfiguration?.theme,
                  onBack: transferOwnershipConfiguration?.onBack,
                  onError: transferOwnershipConfiguration?.onError ?? onError,
                )));
  }

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
            emptyText: bannedMemberConfiguration?.emptyText,
            errorText: bannedMemberConfiguration?.errorText,
            hideSearch: bannedMemberConfiguration?.hideSearch ?? true,
            hideSeparator: bannedMemberConfiguration?.hideSeparator,
            onSelection: bannedMemberConfiguration?.onSelection,
            searchBoxIcon: bannedMemberConfiguration?.searchBoxIcon,
            searchPlaceholder: bannedMemberConfiguration?.searchPlaceholder,
            selectionMode: bannedMemberConfiguration?.selectionMode,
            showBackButton: bannedMemberConfiguration?.showBackButton ?? true,
            style:
                bannedMemberConfiguration?.style ?? const BannedMembersStyle(),
            title: bannedMemberConfiguration?.title,
            subtitle: bannedMemberConfiguration?.subtitle,
            tail: bannedMemberConfiguration?.tail,
            avatarStyle: bannedMemberConfiguration?.avatarStyle,
            emptyView: bannedMemberConfiguration?.emptyView,
            errorView: bannedMemberConfiguration?.errorView,
            loadingView: bannedMemberConfiguration?.loadingView,
            hideError: bannedMemberConfiguration?.hideError,
            disableUsersPresence:
                bannedMemberConfiguration?.hideUserPresence ?? true,
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
          ),
        ));
  }

  //UI Group Listeners--------

  //------------View Methods-------------------

//predefined template option functions--------------------
  _blockUser(User? user, Group? group, String section,
      CometChatDetailsController state) async {
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
      CometChatDetailsController state) async {
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

  _viewProfile(User? user, Group? group, String section,
      CometChatDetailsController state) async {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Scaffold(
                  body: Center(
                      child: Text(Translations.of(context).view_profile)),
                )));
  }

  _viewMember(User? user, Group? group, String section,
      CometChatDetailsController state) {
    if (group != null) {
      onViewMemberClicked(group);
    }
  }

  _addMember(User? user, Group? group, String section,
      CometChatDetailsController state) {
    if (group != null) {
      onAddMemberClicked(group);
    }
  }

  _banMember(User? user, Group? group, String section,
      CometChatDetailsController state) {
    if (group != null) {
      onBanMemberClicked(group);
    }
  }

  _deleteGroup(User? user, Group? group, String section,
      CometChatDetailsController state) {
    if (group != null && (group.owner == loggedInUser?.uid)) {
      _showConfirmationDialog(
          messageText: Translations.of(context).delete_confirm,
          confirmButtonText: Translations.of(context).delete.toUpperCase(),
          confirmButtonTextStyle: TextStyle(
              fontSize: theme.typography.text2.fontSize,
              color: theme.palette.error.light),
          onConfirm: _onDeleteGroupConfirmed);
    }
  }

  _leaveGroup(User? user, Group? group, String section,
      CometChatDetailsController state) async {
    if (group != null) {
      if (loggedInUser == null) return;

      if (group.owner == loggedInUser?.uid) {
        _showConfirmationDialog(
            messageText: Translations.of(context).transfer_confirm,
            confirmButtonText: "TRANSFER OWNERSHIP",
            confirmButtonTextStyle:
                TextStyle(fontSize: theme.typography.text2.fontSize),
            onConfirm: _onTransferOwnershipConfirmed);
      } else {
        _showConfirmationDialog(
            messageText: Translations.of(context).leave_confirm,
            confirmButtonText:
                Translations.of(context).leave_group.toUpperCase(),
            confirmButtonTextStyle: TextStyle(
                fontSize: theme.typography.text2.fontSize,
                color: theme.palette.error.light),
            onConfirm: _onLeaveGroupConfirmed);
      }
    }
  }

  //predefined template option functions end --------------------

  //Utility functions-------------

  //set options in option map after populating onClick
  _setOptions() {
    for (CometChatDetailsTemplate _template in templateList) {
      optionsMap[_template.id] = _getPopulatedOptions(_template) ?? [];
    }
  }

  //returns list of detail options after populating default options if function is null
  List<CometChatDetailsOption>? _getPopulatedOptions(
      CometChatDetailsTemplate _template) {
    List<CometChatDetailsOption>? _options;
    if (_template.options != null) {
      _options = _template.options!(user, group, context, theme);
    }

    //Getting initial option List
    //checking individual option if null then passing the new option
    if (_options!.isEmpty) return _options;

    for (CometChatDetailsOption _option in _options) {
      _option.onClick ??= _getOptionOnClick(_option.id);
    }
    return _options;
  }

  //returns default options according to option id
  Function(User? user, Group? group, String section,
      CometChatDetailsController state)? _getOptionOnClick(String optionId) {
    switch (optionId) {
      case UserOptionConstants.blockUser:
        {
          return _blockUser;
        }
      case UserOptionConstants.unblockUser:
        {
          return _unBlockUser;
        }
      case UserOptionConstants.viewProfile:
        {
          return _viewProfile;
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

  int updateOption(String templateId, String oldOptionID,
      CometChatDetailsOption updatedOption) {
    int _actionIndex = -1;
    if (optionsMap[templateId] != null) {
      int? optionIndex = optionsMap[templateId]
          ?.indexWhere((element) => (element.id == oldOptionID));
      if (optionIndex != null && optionIndex != -1) {
        updatedOption.onClick ??= _getOptionOnClick(updatedOption.id);
        optionsMap[templateId]![optionIndex] = updatedOption;
        update();
        _actionIndex = optionIndex;
      }
    }
    return _actionIndex;
  }

  int removeOption(String templateId, String optionId) {
    int _actionIndex = -1;
    if (optionsMap[templateId] != null) {
      int? optionIndex = optionsMap[templateId]
          ?.indexWhere((element) => (element.id == optionId));
      if (optionIndex != null && optionIndex != -1) {
        optionsMap[templateId]!.removeAt(optionIndex);
        _actionIndex = optionIndex;
        update();
      }
    }
    return _actionIndex;
  }

  int addOption(String templateId, CometChatDetailsOption newOption,
      {int? position}) {
    int _actionIndex = -1;
    if (optionsMap[templateId] != null) {
      if (position != null && position < optionsMap[templateId]!.length) {
        optionsMap[templateId]!.insert(position, newOption);
        _actionIndex = position;
      } else {
        optionsMap[templateId]!.add(newOption);
        _actionIndex = optionsMap[templateId]!.length;
      }

      update();
    }
    return _actionIndex;
  }

  useOption(CometChatDetailsOption _option, String sectionId) {
    if (_option.onClick != null) {
      _option.onClick!(user, group, sectionId, this);
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
            backgroundColor: theme.palette.mode == PaletteThemeModes.light
                ? theme.palette.getBackground()
                : Color.alphaBlend(theme.palette.getAccent200(),
                    theme.palette.getBackground()),
            shadowColor: theme.palette.getAccent100(),
            confirmButtonTextStyle: confirmButtonTextStyle,
            cancelButtonTextStyle:
                TextStyle(fontSize: theme.typography.text2.fontSize)));
  }

  _onLeaveGroupConfirmed() {
    if (group == null) return;
    Navigator.of(context).pop();
    CometChat.leaveGroup(group!.guid, onSuccess: (String response) {
      group?.membersCount--;
      CometChatGroupEvents.ccGroupLeft(
          cc.Action(
            action: MessageCategoryConstants.action,
            conversationId: _conversationId!,
            message: '${loggedInUser?.name} left',
            rawData: '{}',
            oldScope: group!.scope ?? GroupMemberScope.participant,
            newScope: '',
            id: DateTime.now().microsecondsSinceEpoch,
            muid: null,
            sender: loggedInUser!,
            receiver: group!,
            receiverUid: group!.guid,
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
}
