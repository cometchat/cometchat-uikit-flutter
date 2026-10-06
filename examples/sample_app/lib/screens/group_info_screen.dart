import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as cc;
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/utils/thread_toast.dart';
import 'add_members_screen.dart';
import 'banned_members_screen.dart';
import 'messages_screen.dart';
import 'responsive_home_screen.dart';
import 'thread_screen.dart';
import 'transfer_ownership_screen.dart';

/// Group Info screen — shows group details, members, and management actions.
class GroupInfoScreen extends StatefulWidget {
  final Group group;

  const GroupInfoScreen({
    super.key,
    required this.group,
    this.hideAppBar = false,
  });

  /// Drops this screen's own header. Set it when the host already
  /// renders a title bar — the desktop side panel does.
  final bool hideAppBar;

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen>
    with GroupListener, CometChatGroupEventListener {
  late CometChatColorPalette _colorPalette;
  late CometChatTypography _typography;
  late CometChatSpacing _spacing;

  late Group _group;
  int _membersCount = 1;
  User? _loggedInUser;
  Conversation? _conversation;
  String? _conversationId;
  bool _isLeaveLoading = false;
  bool _isDeleteLoading = false;

  late final String _groupListenerId;
  late final String _uiGroupListenerId;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _membersCount = _group.membersCount;
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    _groupListenerId = '${ts}_group_info_sdk';
    _uiGroupListenerId = '${ts}_group_info_ui';
    CometChat.addGroupListener(_groupListenerId, this);
    CometChatGroupEvents.addGroupsListener(_uiGroupListenerId, this);
    _initLoggedInUser();
    _refreshGroup();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colorPalette = CometChatThemeHelper.getColorPalette(context);
    _typography = CometChatThemeHelper.getTypography(context);
    _spacing = CometChatThemeHelper.getSpacing(context);
  }

  @override
  void dispose() {
    CometChat.removeGroupListener(_groupListenerId);
    CometChatGroupEvents.removeGroupsListener(_uiGroupListenerId);
    super.dispose();
  }

  Future<void> _initLoggedInUser() async {
    _loggedInUser = await CometChat.getLoggedInUser();
    _conversation = await CometChat.getConversation(
      _group.guid,
      ConversationType.group,
      onSuccess: (c) => c,
      onError: (_) {},
    );
    _conversationId = _conversation?.conversationId;
    if (mounted) setState(() {});
  }

  void _refreshGroup() {
    CometChat.getGroup(
      _group.guid,
      onSuccess: (grp) {
        if (mounted) {
          setState(() {
            _group = grp;
            _membersCount = grp.membersCount;
          });
        }
      },
      onError: (e) => debugPrint('Group Info: fetch failed: ${e.message}'),
    );
  }

  // ── SDK Group Listeners ──────────────────────────────────────────

  @override
  void onGroupMemberJoined(cc.Action action, User joinedUser, Group group) {
    if (group.guid == _group.guid) _updateGroup(group);
  }

  @override
  void onGroupMemberLeft(cc.Action action, User leftUser, Group group) {
    if (group.guid == _group.guid) _updateGroup(group);
  }

  @override
  void onGroupMemberKicked(
      cc.Action action, User kickedUser, User kickedBy, Group group) {
    if (group.guid == _group.guid) _updateGroup(group);
  }

  @override
  void onGroupMemberBanned(
      cc.Action action, User bannedUser, User bannedBy, Group group) {
    if (group.guid == _group.guid) _updateGroup(group);
  }

  @override
  void onGroupMemberScopeChanged(
      cc.Action action,
      User updatedBy,
      User updatedUser,
      String scopeChangedTo,
      String scopeChangedFrom,
      Group group) {
    if (group.guid == _group.guid && updatedUser.uid == _loggedInUser?.uid) {
      _group.scope = scopeChangedTo;
      setState(() {});
    }
  }

  @override
  void onMemberAddedToGroup(
      cc.Action action, User addedby, User userAdded, Group group) {
    if (group.guid == _group.guid) _updateGroup(group);
  }

  // ── UI Group Listeners ───────────────────────────────────────────

  @override
  void ccGroupMemberBanned(
      cc.Action message, User bannedUser, User bannedBy, Group bannedFrom) {
    if (bannedFrom.guid == _group.guid) _updateGroup(bannedFrom);
  }

  @override
  void ccGroupMemberKicked(
      cc.Action message, User kickedUser, User kickedBy, Group kickedFrom) {
    if (kickedFrom.guid == _group.guid) _updateGroup(kickedFrom);
  }

  @override
  void ccGroupMemberAdded(List<cc.Action> messages, List<User> usersAdded,
      Group groupAddedIn, User addedBy) {
    if (groupAddedIn.guid == _group.guid) _updateGroup(groupAddedIn);
  }

  @override
  void ccOwnershipChanged(Group group, GroupMember newOwner) {
    if (group.guid == _group.guid) {
      _group.owner = newOwner.uid;
      setState(() {});
    }
  }

  void _updateGroup(Group group) {
    if (!mounted) return;
    setState(() {
      _group = group;
      _membersCount = group.membersCount;
    });
  }

  // ── Permission helpers ───────────────────────────────────────────

  bool _canAccess(String optionId) {
    final scope = _loggedInUser?.uid == _group.owner
        ? GroupMemberScope.owner
        : _group.scope ?? GroupMemberScope.participant;
    return DetailUtils.validateDetailOptions(
        loggedInUserScope: scope, optionId: optionId);
  }

  // ── Actions ──────────────────────────────────────────────────────

  void _onViewMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CometChatGroupMembers(group: _group),
      ),
    );
  }

  void _onAddMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMembersScreen(group: _group),
      ),
    );
  }

  void _onBannedMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BannedMembersScreen(group: _group),
      ),
    );
  }

  void _onLeave() {
    if (_loggedInUser == null) return;
    // Owner with >1 members must transfer ownership first
    if (_membersCount > 1 && _group.owner == _loggedInUser!.uid) {
      _showTransferOwnershipConfirm();
    } else {
      _showLeaveConfirm();
    }
  }

  void _showLeaveConfirm() {
    CometChatConfirmDialog(
      context: context,
      icon: Icon(Icons.logout, color: _colorPalette.error, size: 48),
      title: Text(
        cc.Translations.of(context).leaveThisGroup,
        style: TextStyle(
          fontSize: _typography.heading2?.medium?.fontSize,
          fontFamily: _typography.heading2?.medium?.fontFamily,
          fontWeight: _typography.heading2?.medium?.fontWeight,
          color: _colorPalette.textPrimary,
        ),
      ),
      messageText: Text(
        cc.Translations.of(context).confirmLeaveGroup,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _typography.body?.regular?.fontSize,
          fontFamily: _typography.body?.regular?.fontFamily,
          fontWeight: _typography.body?.regular?.fontWeight,
          color: _colorPalette.textSecondary,
        ),
      ),
      confirmButtonText: cc.Translations.of(context).leave,
      cancelButtonText: cc.Translations.of(context).cancel,
      style: CometChatConfirmDialogStyle(
        confirmButtonBackground: _colorPalette.error,
        confirmButtonTextColor: _colorPalette.white,
      ),
      onConfirm: _leaveGroup,
    ).show();
  }

  void _leaveGroup(BuildContext dialogContext) {
    setState(() => _isLeaveLoading = true);
    CometChat.leaveGroup(
      _group.guid,
      onSuccess: (_) {
        if (!mounted) return;
        _group.membersCount--;
        CometChatGroupEvents.ccGroupLeft(
          cc.Action(
            conversationId: _conversationId ?? '',
            message:
                '${_loggedInUser?.name} ${cc.Translations.of(context).left}',
            oldScope: _group.scope ?? GroupMemberScope.participant,
            newScope: '',
            muid: DateTime.now().microsecondsSinceEpoch.toString(),
            sender: _loggedInUser!,
            receiverUid: _group.guid,
            type: MessageTypeConstants.groupActions,
            receiverType: ReceiverTypeConstants.group,
            parentMessageId: 0,
          ),
          _loggedInUser!,
          _group,
        );
        // Dismiss dialog, then pop group info screen
        Navigator.of(dialogContext).pop();
        if (kIsWeb) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const ResponsiveHomeScreen(),
            ),
            (route) => false,
          );
        } else {
          // Pop GroupInfo → Messages → back to Home
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        }
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _isLeaveLoading = false);
        Navigator.of(dialogContext).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _colorPalette.error,
            content: Text(cc.Translations.of(context).errorLeaveGroup),
          ),
        );
      },
    );
  }

  /// Leave group without a dialog to dismiss (called after transfer ownership)
  void _leaveGroupAfterTransfer() {
    if (!mounted) return;
    _group.membersCount--;
    CometChatGroupEvents.ccGroupLeft(
      cc.Action(
        conversationId: _conversationId ?? '',
        message: '${_loggedInUser?.name} ${cc.Translations.of(context).left}',
        oldScope: _group.scope ?? GroupMemberScope.participant,
        newScope: '',
        muid: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: _loggedInUser!,
        receiverUid: _group.guid,
        type: MessageTypeConstants.groupActions,
        receiverType: ReceiverTypeConstants.group,
        parentMessageId: 0,
      ),
      _loggedInUser!,
      _group,
    );
    // Pop group info screen (transfer screen already popped itself)
    Navigator.of(context).pop();
  }

  void _showTransferOwnershipConfirm() {
    CometChatConfirmDialog(
      context: context,
      showIcon: false,
      title: Text(
        cc.Translations.of(context).ownerShipTransfer,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _typography.heading2?.medium?.fontSize,
          fontWeight: _typography.heading2?.medium?.fontWeight,
          fontFamily: _typography.heading2?.medium?.fontFamily,
          color: _colorPalette.textPrimary,
        ),
      ),
      messageText: Text(
        cc.Translations.of(context).confirmTransferOwnership,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _typography.body?.regular?.fontSize,
          fontWeight: _typography.body?.regular?.fontWeight,
          fontFamily: _typography.body?.regular?.fontFamily,
          color: _colorPalette.textSecondary,
        ),
      ),
      confirmButtonText: cc.Translations.of(context).continueText,
      cancelButtonText: cc.Translations.of(context).cancel,
      style: CometChatConfirmDialogStyle(
        confirmButtonBackground: _colorPalette.primary,
        confirmButtonTextColor: _colorPalette.white,
      ),
      onCancel: (dialogContext) => Navigator.of(dialogContext).pop(),
      onConfirm: (dialogContext) {
        Navigator.of(dialogContext).pop(); // close dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransferOwnershipScreen(group: _group),
          ),
        ).then((value) {
          if (value == 'LeaveGroup') _leaveGroupAfterTransfer();
        });
      },
    ).show();
  }

  void _onDeleteAndExit() {
    CometChatConfirmDialog(
      context: context,
      useRootNavigator: true,
      icon: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Image.asset(
          AssetConstants.deleteIcon,
          color: _colorPalette.error,
          package: UIConstants.packageName,
          width: 48,
          height: 48,
        ),
      ),
      title: Text(
        '${cc.Translations.of(context).deleteAndExit}?',
        style: TextStyle(
          fontSize: _typography.heading2?.medium?.fontSize,
          fontFamily: _typography.heading2?.medium?.fontFamily,
          fontWeight: _typography.heading2?.medium?.fontWeight,
          color: _colorPalette.textPrimary,
        ),
      ),
      messageText: Text(
        'Are you sure you want to delete this chat and exit the group? This action cannot be undone.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _typography.body?.regular?.fontSize,
          fontFamily: _typography.body?.regular?.fontFamily,
          fontWeight: _typography.body?.regular?.fontWeight,
          color: _colorPalette.textSecondary,
        ),
      ),
      confirmButtonText: cc.Translations.of(context).deleteAndExit,
      cancelButtonText: cc.Translations.of(context).cancel,
      style: CometChatConfirmDialogStyle(
        confirmButtonBackground: _colorPalette.error,
        confirmButtonTextColor: _colorPalette.white,
      ),
      onConfirm: _deleteGroup,
    ).show();
  }

  void _deleteGroup(BuildContext dialogContext) {
    setState(() => _isDeleteLoading = true);
    CometChat.deleteGroup(
      _group.guid,
      onSuccess: (_) {
        if (!mounted) return;
        CometChatGroupEvents.ccGroupDeleted(_group);

        if (kIsWeb) {
          // Dismiss dialog, then pop group info + messages.
          // This preserves the current tab (Groups/Chats/Users).
          Navigator.of(dialogContext).pop();
          Navigator.of(context)
            ..pop() // pop GroupInfo
            ..pop(); // pop Messages
        } else {
          // Dismiss dialog, then pop group info screen
          Navigator.of(dialogContext).pop();
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        }
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _isDeleteLoading = false);
        Navigator.of(dialogContext).pop(); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _colorPalette.error,
            content: Text(cc.Translations.of(context).errorDeleteGroup),
          ),
        );
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colorPalette.background1,
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              backgroundColor: _colorPalette.background1,
              titleSpacing: 0,
              centerTitle: false,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: _colorPalette.iconPrimary),
              ),
              title: Text(
                cc.Translations.of(context).groupInfo,
                style: TextStyle(
                  fontSize: _typography.heading2?.bold?.fontSize,
                  fontFamily: _typography.heading2?.bold?.fontFamily,
                  fontWeight: _typography.heading2?.bold?.fontWeight,
                  color: _colorPalette.textPrimary,
                ),
              ),
            ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Banner for kicked/banned users
            if (_group.hasJoined == false || _group.isBannedFromGroup == true)
              Container(
                width: double.infinity,
                color: _colorPalette.warning,
                padding: EdgeInsets.symmetric(
                  vertical: _spacing.padding2 ?? 0,
                  horizontal: _spacing.padding5 ?? 0,
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: _spacing.padding1 ?? 0),
                      child: Icon(Icons.info_outline,
                          color: _colorPalette.iconPrimary, size: 16),
                    ),
                    Text(
                      cc.Translations.of(context).youAreNoLongerPartOfThisGroup,
                      style: TextStyle(
                        fontSize: _typography.caption1?.regular?.fontSize,
                        fontFamily: _typography.caption1?.regular?.fontFamily,
                        fontWeight: _typography.caption1?.regular?.fontWeight,
                        color: _colorPalette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            Divider(color: _colorPalette.borderLight, height: 1),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _spacing.padding5 ?? 0),
              child: Column(
                children: [
                  _buildProfile(),
                  Text(
                    _group.name,
                    style: TextStyle(
                      fontSize: _typography.heading2?.medium?.fontSize,
                      fontFamily: _typography.heading2?.medium?.fontFamily,
                      fontWeight: _typography.heading2?.medium?.fontWeight,
                      color: _colorPalette.textPrimary,
                    ),
                  ),
                  Text(
                    '$_membersCount ${_membersCount == 1 ? cc.Translations.of(context).member : cc.Translations.of(context).members}',
                    style: TextStyle(
                      fontSize: _typography.caption1?.regular?.fontSize,
                      fontFamily: _typography.caption1?.regular?.fontFamily,
                      fontWeight: _typography.caption1?.regular?.fontWeight,
                      color: _colorPalette.textSecondary,
                    ),
                  ),
                  _buildOptionTiles(),
                ],
              ),
            ),
            Divider(color: _colorPalette.borderLight, height: 1),
            // Search
            _buildSearchTile(),
            Divider(color: _colorPalette.borderLight, height: 1),
            // Pin & Save entries
            _buildPinTiles(),
            Divider(color: _colorPalette.borderLight, height: 1),
            _buildSecondaryActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfile() {
    return Padding(
      padding: EdgeInsets.only(
        top: _spacing.padding10 ?? 0,
        bottom: _spacing.padding3 ?? 0,
      ),
      child: CometChatAvatar(
        height: 120,
        width: 120,
        image: _group.icon ?? '',
        name: _group.name,
        style: CometChatAvatarStyle(
          placeHolderTextStyle: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: _colorPalette.white,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTiles() {
    return Padding(
      padding: EdgeInsets.only(
        top: _spacing.padding3 ?? 0,
        bottom: _spacing.padding5 ?? 0,
        right: _spacing.padding2 ?? 0,
        left: _spacing.padding2 ?? 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (_canAccess(GroupOptionConstants.viewMembers))
            _tile(
              Icon(Icons.group_outlined,
                  color: _colorPalette.iconHighlight, size: 24),
              cc.Translations.of(context).viewMembers,
              _onViewMembers,
            ),
          if (_canAccess(GroupOptionConstants.viewMembers))
            SizedBox(width: _spacing.padding2),
          if (_canAccess(GroupOptionConstants.addMembers))
            _tile(
              Icon(Icons.person_add_alt,
                  color: _colorPalette.iconHighlight, size: 24),
              cc.Translations.of(context).addMembers,
              _onAddMembers,
            ),
          if (_canAccess(GroupOptionConstants.addMembers))
            SizedBox(width: _spacing.padding2),
          if (_canAccess(GroupOptionConstants.bannedMembers))
            _tile(
              Icon(Icons.person_outline_outlined,
                  color: _colorPalette.iconHighlight, size: 24),
              cc.Translations.of(context).bannedMembers,
              _onBannedMembers,
            ),
        ],
      ),
    );
  }

  Widget _tile(Widget icon, String title, VoidCallback onTap) {
    return Expanded(
      child: Semantics(
        button: true,
        label: title,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 70,
            padding: EdgeInsets.symmetric(
              vertical: _spacing.padding2 ?? 0,
              horizontal: _spacing.padding2 ?? 0,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: _colorPalette.borderDefault ?? Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(_spacing.radius2 ?? 0),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: _spacing.padding1 ?? 0),
                  child: icon,
                ),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _typography.caption1?.regular?.fontSize,
                    fontFamily: _typography.caption1?.regular?.fontFamily,
                    fontWeight: _typography.caption1?.regular?.fontWeight,
                    color: _colorPalette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTile() {
    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (searchCtx) => CometChatSearch(
              group: _group,
              searchIn: const [SearchScope.messages],
              onBack: () => Navigator.of(searchCtx).pop(),
              onMessageClicked: (message) {
                // Capture NavigatorState while Search route context is alive.
                // Then pop Search + GroupInfo and replace Messages with a new
                // instance scrolled to the tapped message.
                final navigator = Navigator.of(searchCtx);
                final group = _group;

                // Thread reply → fetch parent and open ThreadScreen so the
                // reply isn't injected into the main conversation's list.
                if (message.parentMessageId > 0) {
                  CometChatHelper.getMessageDetails(
                    message.parentMessageId,
                    onSuccess: (parent) {
                      if (parent == null) return;
                      navigator.pop(); // pop Search
                      navigator.pop(); // pop GroupInfo
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => ThreadScreen(
                            group: group,
                            message: parent,
                            goToMessageId: message.id,
                          ),
                        ),
                      );
                    },
                    onError: (_) {},
                  );
                  return;
                }

                navigator.pop(); // pop Search
                navigator.pop(); // pop GroupInfo
                navigator.pushReplacement(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: 'messages'),
                    builder: (_) => MessagesScreen(
                      group: group,
                      goToMessageId: message.id,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
      leading: Icon(Icons.search, color: _colorPalette.iconPrimary),
      contentPadding: EdgeInsets.symmetric(horizontal: _spacing.padding5 ?? 0),
      title: Text(
        cc.Translations.of(context).search,
        style: TextStyle(
          fontSize: _typography.heading4?.regular?.fontSize,
          fontFamily: _typography.heading4?.regular?.fontFamily,
          fontWeight: _typography.heading4?.regular?.fontWeight,
          color: _colorPalette.textPrimary,
        ),
      ),
    );
  }

  /// Pin & Save: pinned messages only — pinning the conversation itself
  /// lives on the chat list row's long-press menu.
  Widget _buildPinTiles() {
    return _neutralTile(
      cc.Translations.of(context).pinnedMessagesTitle,
      Icon(Icons.push_pin_outlined, color: _colorPalette.iconPrimary),
      _viewPinnedMessages,
    );
  }

  Widget _neutralTile(String title, Widget icon, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: icon,
      contentPadding: EdgeInsets.symmetric(horizontal: _spacing.padding5 ?? 0),
      title: Text(
        title,
        style: TextStyle(
          fontSize: _typography.heading4?.regular?.fontSize,
          fontFamily: _typography.heading4?.regular?.fontFamily,
          fontWeight: _typography.heading4?.regular?.fontWeight,
          color: _colorPalette.textPrimary,
        ),
      ),
    );
  }

  void _viewPinnedMessages() {
    CometChatPinnedMessages.show(
      context,
      group: _group,
      onItemTap: (message) {
        // Pop GroupInfo, then open the conversation jumped to the message
        // (thread replies open their thread screen).
        final navigator = Navigator.of(context);
        final group = _group;
        if (message.parentMessageId > 0) {
          CometChatHelper.getMessageDetails(
            message.parentMessageId,
            onSuccess: (parent) {
              if (parent == null) return;
              navigator.pop(); // pop GroupInfo
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => ThreadScreen(
                    group: group,
                    message: parent,
                    goToMessageId: message.id,
                  ),
                ),
              );
            },
            onError: (_) {},
          );
          return;
        }
        navigator.pop(); // pop GroupInfo
        navigator.pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'messages'),
            builder: (_) => MessagesScreen(
              group: group,
              goToMessageId: message.id,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSecondaryActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Leave option
        if (_membersCount > 1 &&
            _canAccess(GroupOptionConstants.leave) &&
            !(_membersCount <= 1 && _group.owner == _loggedInUser?.uid))
          _listTileOption(
            cc.Translations.of(context).leave,
            Icon(Icons.exit_to_app, color: _colorPalette.error),
            _onLeave,
          ),
        // Delete option
        if (_canAccess(GroupOptionConstants.delete))
          _listTileOption(
            cc.Translations.of(context).deleteAndExit,
            Icon(Icons.delete, color: _colorPalette.error),
            _onDeleteAndExit,
          ),
      ],
    );
  }

  Widget _listTileOption(String title, Widget icon, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: icon,
      contentPadding: EdgeInsets.symmetric(horizontal: _spacing.padding5 ?? 0),
      title: Text(
        title,
        style: TextStyle(
          fontSize: _typography.heading4?.regular?.fontSize,
          fontFamily: _typography.heading4?.regular?.fontFamily,
          fontWeight: _typography.heading4?.regular?.fontWeight,
          color: _colorPalette.error,
        ),
      ),
    );
  }
}
