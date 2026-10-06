import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as cc;
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/utils/thread_toast.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:intl/intl.dart';

import 'package:sample_app/utils/call_error_snackbar.dart';

import 'messages_screen.dart';
import 'thread_screen.dart';

/// User Info screen — shows user profile, online status, call buttons,
/// block/unblock, and delete chat actions.
class UserInfoScreen extends StatefulWidget {
  final User user;

  const UserInfoScreen({
    super.key,
    required this.user,
    this.hideAppBar = false,
  });

  /// Drops this screen's own header. Set it when the host already
  /// renders a title bar — the desktop side panel does.
  final bool hideAppBar;

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen>
    with UserListener, CometChatUserEventListener {
  late CometChatColorPalette _colorPalette;
  late CometChatTypography _typography;
  late CometChatSpacing _spacing;

  late User _user;
  Conversation? _conversation;
  bool _isBlockLoading = false;
  bool _isDeleteLoading = false;

  late final String _userListenerId;
  late final String _uiUserListenerId;

  /// Places the Voice and Video calls, through the UI Kit as the chat
  /// header's call buttons do: the same checks, the same outgoing screen
  /// and configuration, and errors as SnackBars.
  late final CallButtonsBloc _callButtonsBloc;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    _userListenerId = '${ts}_user_info_sdk';
    _uiUserListenerId = '${ts}_user_info_ui';
    CometChat.addUserListener(_userListenerId, this);
    CometChatUserEvents.addUsersListener(_uiUserListenerId, this);
    final calling = CometChatUIKit.authenticationSettings?.callingConfiguration;
    _callButtonsBloc = CallButtonsBloc(
      user: _user,
      // The configuration the chat header's call buttons use.
      outgoingCallConfiguration:
          calling?.callButtonsConfiguration?.outgoingCallConfiguration ??
          calling?.outgoingCallConfiguration,
      errorCallback: showCallButtonsError,
    );
    _initLoggedInUser();
  }

  Future<void> _initLoggedInUser() async {
    await CometChat.getConversation(
      _user.uid,
      ConversationType.user,
      onSuccess: (conversation) {
        _conversation = conversation;
      },
      onError: (_) {},
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CometChat.removeUserListener(_userListenerId);
    CometChatUserEvents.removeUsersListener(_uiUserListenerId);
    _callButtonsBloc.close();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colorPalette = CometChatThemeHelper.getColorPalette(context);
    _typography = CometChatThemeHelper.getTypography(context);
    _spacing = CometChatThemeHelper.getSpacing(context);
  }

  // --- SDK Listeners ---

  @override
  void onUserOnline(User user) {
    if (user.uid == _user.uid) {
      _user.status = CometChatUserStatus.online;
      if (mounted) setState(() {});
    }
  }

  @override
  void onUserOffline(User user) {
    if (user.uid == _user.uid) {
      _user.status = CometChatUserStatus.offline;
      _user.lastActiveAt = user.lastActiveAt;
      if (mounted) setState(() {});
    }
  }

  @override
  void ccUserBlocked(User user) {
    if (user.uid == _user.uid) {
      _user.blockedByMe = true;
      if (mounted) setState(() {});
    }
  }

  @override
  void ccUserUnblocked(User user) {
    if (user.uid == _user.uid) {
      _user.blockedByMe = false;
      if (mounted) setState(() {});
    }
  }

  // --- Helpers ---

  bool get _isBlocked =>
      _user.blockedByMe == true || _user.hasBlockedMe == true;

  bool get _blockedByMe => _user.blockedByMe == true;

  String _getPresenceText() {
    if (_isBlocked) return '';
    if (_user.status == CometChatUserStatus.online) return 'Online';
    final lastActive = _user.lastActiveAt;
    if (lastActive == null) return '';
    final diff = DateTime.now().difference(lastActive);
    if (diff.inMinutes <= 1) return 'Last seen 1 minute ago';
    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes} minutes ago';
    final date = DateFormat.MMMd().format(lastActive);
    final time = DateFormat.jm().format(lastActive);
    return 'Last seen $date at $time';
  }

  // --- Actions ---

  void _showBlockDialog() {
    CometChatConfirmDialog(
      context: context,
      icon: Icon(Icons.block, color: _colorPalette.error, size: 48),
      title: Text(
        cc.Translations.of(context).blockContact,
        style: TextStyle(
          fontSize: _typography.heading2?.medium?.fontSize,
          fontFamily: _typography.heading2?.medium?.fontFamily,
          fontWeight: _typography.heading2?.medium?.fontWeight,
          color: _colorPalette.textPrimary,
        ),
      ),
      messageText: Text(
        cc.Translations.of(context).confirmBlockContact,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _typography.body?.regular?.fontSize,
          fontFamily: _typography.body?.regular?.fontFamily,
          fontWeight: _typography.body?.regular?.fontWeight,
          color: _colorPalette.textSecondary,
        ),
      ),
      confirmButtonText: cc.Translations.of(context).blockUser,
      cancelButtonText: cc.Translations.of(context).cancel,
      onConfirm: _blockUser,
      style: CometChatConfirmDialogStyle(
        confirmButtonBackground: _colorPalette.error,
        confirmButtonTextColor: _colorPalette.white,
      ),
    ).show();
  }

  void _showUnblockDialog() {
    CometChatConfirmDialog(
      context: context,
      icon: Icon(Icons.block, color: _colorPalette.error, size: 48),
      title: Text(
        cc.Translations.of(context).unblockContact,
        style: TextStyle(
          fontSize: _typography.heading2?.medium?.fontSize,
          fontFamily: _typography.heading2?.medium?.fontFamily,
          fontWeight: _typography.heading2?.medium?.fontWeight,
          color: _colorPalette.textPrimary,
        ),
      ),
      messageText: Text(
        cc.Translations.of(context).confirmUnblockContact,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _typography.body?.regular?.fontSize,
          fontFamily: _typography.body?.regular?.fontFamily,
          fontWeight: _typography.body?.regular?.fontWeight,
          color: _colorPalette.textSecondary,
        ),
      ),
      confirmButtonText: cc.Translations.of(context).unblockUser,
      cancelButtonText: cc.Translations.of(context).cancel,
      onConfirm: _unblockUser,
      style: CometChatConfirmDialogStyle(
        confirmButtonBackground: _colorPalette.error,
        confirmButtonTextColor: _colorPalette.white,
      ),
    ).show();
  }

  void _blockUser(BuildContext dialogContext) {
    Navigator.of(dialogContext).pop();
    setState(() => _isBlockLoading = true);
    CometChat.blockUser(
      [_user.uid],
      onSuccess: (_) {
        _user.blockedByMe = true;
        CometChatUserEvents.ccUserBlocked(_user);
        if (mounted) {
          setState(() => _isBlockLoading = false);
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isBlockLoading = false);
          _showError(cc.Translations.of(context).errorBlockUser);
        }
      },
    );
  }

  void _unblockUser(BuildContext dialogContext) {
    Navigator.of(dialogContext).pop();
    setState(() => _isBlockLoading = true);
    CometChat.unblockUser(
      [_user.uid],
      onSuccess: (_) {
        _user.blockedByMe = false;
        CometChatUserEvents.ccUserUnblocked(_user);
        if (mounted) {
          setState(() => _isBlockLoading = false);
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isBlockLoading = false);
          _showError(cc.Translations.of(context).errorBlockUser);
        }
      },
    );
  }

  void _showDeleteChatDialog() {
    CometChatConfirmDialog(
      context: context,
      icon: Image.asset(
        AssetConstants.delete,
        color: _colorPalette.error,
        package: UIConstants.packageName,
        width: 48,
        height: 48,
      ),
      title: Text(
        cc.Translations.of(context).deleteChat,
        style: TextStyle(
          fontSize: _typography.heading2?.medium?.fontSize,
          fontFamily: _typography.heading2?.medium?.fontFamily,
          fontWeight: _typography.heading2?.medium?.fontWeight,
          color: _colorPalette.textPrimary,
        ),
      ),
      messageText: Text(
        cc.Translations.of(context).confirmDeleteChat,
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
      onConfirm: _deleteChat,
      style: CometChatConfirmDialogStyle(
        confirmButtonBackground: _colorPalette.error,
        confirmButtonTextColor: _colorPalette.white,
      ),
    ).show();
  }

  void _deleteChat(BuildContext dialogContext) {
    if (_conversation == null) {
      Navigator.of(dialogContext).pop(); // dismiss dialog
      _showError('No conversation found to delete.');
      return;
    }
    setState(() => _isDeleteLoading = true);
    CometChat.deleteConversation(
      _user.uid,
      _conversation!.conversationType,
      onSuccess: (_) {
        CometChatConversationEvents.ccConversationDeleted(_conversation!);
        if (mounted) {
          // Dismiss dialog then pop back to home
          Navigator.of(dialogContext).pop();
          Navigator.of(dialogContext).pop();
          Navigator.of(context).maybePop();
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isDeleteLoading = false);
          Navigator.of(dialogContext).pop(); // dismiss dialog
          _showError(cc.Translations.of(context).errorDeleteUser);
        }
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _colorPalette.error,
        content: Text(
          message,
          style: TextStyle(
            color: _colorPalette.white,
            fontSize: _typography.button?.medium?.fontSize,
            fontWeight: _typography.button?.medium?.fontWeight,
            fontFamily: _typography.button?.medium?.fontFamily,
          ),
        ),
      ),
    );
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final presence = _getPresenceText();
    return Scaffold(
      backgroundColor: _colorPalette.background1,
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              backgroundColor: _colorPalette.background1,
              centerTitle: false,
              titleSpacing: 0,
              leading: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: _colorPalette.iconPrimary),
              ),
              title: Text(
                cc.Translations.of(context).userInfo,
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
            Divider(color: _colorPalette.borderLight, height: 1),
            // Blocked banner
            if (_blockedByMe)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _spacing.padding3 ?? 0,
                  vertical: _spacing.padding2 ?? 0,
                ),
                color: _colorPalette.warning?.withValues(alpha: 0.2),
                child: Row(
                  children: [
                    Icon(Icons.info, color: _colorPalette.warning),
                    SizedBox(width: _spacing.padding2),
                    Expanded(
                      child: Text(
                        '${cc.Translations.of(context).youHaveBlocked} ${_user.name}.',
                        style: TextStyle(
                          fontSize: _typography.body?.regular?.fontSize,
                          fontFamily: _typography.body?.regular?.fontFamily,
                          fontWeight: _typography.body?.regular?.fontWeight,
                          color: _colorPalette.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: _spacing.padding5),
            // Avatar
            Padding(
              padding: EdgeInsets.only(bottom: _spacing.padding3 ?? 0),
              child: CometChatAvatar(
                height: 120,
                width: 120,
                image: _user.avatar ?? '',
                name: _user.name,
                style: CometChatAvatarStyle(
                  placeHolderTextStyle: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: _colorPalette.white,
                  ),
                ),
              ),
            ),
            // Name
            Text(
              _user.name,
              style: TextStyle(
                fontSize: _typography.heading2?.medium?.fontSize,
                fontFamily: _typography.heading2?.medium?.fontFamily,
                fontWeight: _typography.heading2?.medium?.fontWeight,
                color: _colorPalette.textPrimary,
              ),
            ),
            // Presence
            if (!_isBlocked && presence.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: _spacing.padding1 ?? 4),
                child: Text(
                  presence,
                  style: TextStyle(
                    fontSize: _typography.caption1?.regular?.fontSize,
                    fontFamily: _typography.caption1?.regular?.fontFamily,
                    fontWeight: _typography.caption1?.regular?.fontWeight,
                    color: _colorPalette.textSecondary,
                  ),
                ),
              ),
            // Call buttons (only when not blocked)
            if (!_isBlocked) _buildCallButtons(),
            SizedBox(height: _spacing.padding3),
            Divider(color: _colorPalette.borderLight, height: 1),
            // Search
            _buildSearchTile(),
            // Pin & Save: pinned messages only — pinning the conversation
            // itself lives on the chat list row's long-press menu.
            _buildNeutralTile(
              cc.Translations.of(context).pinnedMessagesTitle,
              Icon(Icons.push_pin_outlined, color: _colorPalette.iconPrimary),
              _viewPinnedMessages,
            ),
            // Block / Unblock
            _buildActionTile(
              _blockedByMe
                  ? cc.Translations.of(context).unBlock
                  : cc.Translations.of(context).block,
              Icon(Icons.block, color: _colorPalette.error),
              _isBlockLoading
                  ? null
                  : () {
                      if (_blockedByMe) {
                        _showUnblockDialog();
                      } else {
                        _showBlockDialog();
                      }
                    },
            ),
            // Delete chat
            _buildActionTile(
              cc.Translations.of(context).deleteTheChat,
              Image.asset(
                AssetConstants.delete,
                color: _colorPalette.error,
                package: UIConstants.packageName,
              ),
              _isDeleteLoading ? null : _showDeleteChatDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTile() {
    return Semantics(
      button: true,
      label: cc.Translations.of(context).search,
      child: ListTile(
        enableFeedback: false,
        minLeadingWidth: 0,
        minTileHeight: 0,
        minVerticalPadding: 0,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (searchCtx) => CometChatSearch(
                user: _user,
                searchIn: const [SearchScope.messages],
                onBack: () => Navigator.of(searchCtx).pop(),
                onMessageClicked: (message) {
                  // Capture NavigatorState while Search route context is alive.
                  // Pop Search + UserInfo, then replace Messages with a new
                  // instance scrolled to the tapped message.
                  final navigator = Navigator.of(searchCtx);
                  final user = _user;

                  // Thread reply → fetch parent and open ThreadScreen so the
                  // reply isn't injected into the main conversation's list.
                  if (message.parentMessageId > 0) {
                    CometChatHelper.getMessageDetails(
                      message.parentMessageId,
                      onSuccess: (parent) {
                        if (parent == null) return;
                        navigator.pop(); // pop Search
                        navigator.pop(); // pop UserInfo
                        navigator.push(
                          MaterialPageRoute(
                            builder: (_) => ThreadScreen(
                              user: user,
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
                  navigator.pop(); // pop UserInfo
                  navigator.pushReplacement(
                    MaterialPageRoute(
                      settings: const RouteSettings(name: 'messages'),
                      builder: (_) => MessagesScreen(
                        user: user,
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
        contentPadding: EdgeInsets.symmetric(
          horizontal: _spacing.padding5 ?? 0,
          vertical: _spacing.padding3 ?? 0,
        ),
        title: Text(
          cc.Translations.of(context).search,
          style: TextStyle(
            fontSize: _typography.heading4?.regular?.fontSize,
            fontFamily: _typography.heading4?.regular?.fontFamily,
            fontWeight: _typography.heading4?.regular?.fontWeight,
            color: _colorPalette.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildCallButtons() {
    return StreamBuilder<CallButtonsState>(
      stream: _callButtonsBloc.stream,
      initialData: _callButtonsBloc.state,
      builder: (context, snapshot) {
        // Off while a call is being placed, as the header's buttons are.
        final enabled = snapshot.data?.isDisabled != true;
        return Padding(
          padding: EdgeInsets.only(
            top: _spacing.padding5 ?? 0,
            left: _spacing.padding5 ?? 0,
            right: _spacing.padding5 ?? 0,
          ),
          child: Row(
            children: [
              _buildCallTile(
                Icons.call_outlined,
                cc.Translations.of(context).voice,
                enabled
                    ? () => _callButtonsBloc.add(const InitiateVoiceCall())
                    : null,
              ),
              SizedBox(width: _spacing.padding2),
              _buildCallTile(
                Icons.videocam_outlined,
                cc.Translations.of(context).video,
                enabled
                    ? () => _callButtonsBloc.add(const InitiateVideoCall())
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCallTile(IconData icon, String label, VoidCallback? onTap) {
    return Expanded(
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.5 : 1,
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: _spacing.padding2 ?? 0,
                horizontal: _spacing.padding3 ?? 0,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _colorPalette.borderDefault ?? Colors.transparent,
                ),
                borderRadius: BorderRadius.circular(_spacing.radius2 ?? 0),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: _spacing.padding2 ?? 0),
                    child: Icon(
                      icon,
                      color: _colorPalette.iconHighlight,
                      size: 24,
                    ),
                  ),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  /// Like [_buildActionTile] but with neutral (non-destructive) styling.
  Widget _buildNeutralTile(String title, Widget icon, VoidCallback? onTap) {
    return Semantics(
      button: true,
      label: title,
      child: ListTile(
        enableFeedback: false,
        minLeadingWidth: 0,
        minTileHeight: 0,
        minVerticalPadding: 0,
        onTap: onTap,
        leading: icon,
        contentPadding: EdgeInsets.symmetric(
          horizontal: _spacing.padding5 ?? 0,
          vertical: _spacing.padding3 ?? 0,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: _typography.heading4?.regular?.fontSize,
            fontFamily: _typography.heading4?.regular?.fontFamily,
            fontWeight: _typography.heading4?.regular?.fontWeight,
            color: _colorPalette.textPrimary,
          ),
        ),
      ),
    );
  }

  void _viewPinnedMessages() {
    CometChatPinnedMessages.show(
      context,
      user: widget.user,
      onItemTap: (message) {
        // Pop UserInfo, then open the conversation jumped to the message
        // (thread replies open their thread screen).
        final navigator = Navigator.of(context);
        final user = widget.user;
        if (message.parentMessageId > 0) {
          CometChatHelper.getMessageDetails(
            message.parentMessageId,
            onSuccess: (parent) {
              if (parent == null) return;
              navigator.pop(); // pop UserInfo
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => ThreadScreen(
                    user: user,
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
        navigator.pop(); // pop UserInfo
        navigator.pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'messages'),
            builder: (_) => MessagesScreen(
              user: user,
              goToMessageId: message.id,
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile(String title, Widget icon, VoidCallback? onTap) {
    return Semantics(
      button: true,
      label: title,
      child: ListTile(
        enableFeedback: false,
        minLeadingWidth: 0,
        minTileHeight: 0,
        minVerticalPadding: 0,
        onTap: onTap,
        leading: icon,
        contentPadding: EdgeInsets.symmetric(
          horizontal: _spacing.padding5 ?? 0,
          vertical: _spacing.padding3 ?? 0,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: _typography.heading4?.regular?.fontSize,
            fontFamily: _typography.heading4?.regular?.fontFamily,
            fontWeight: _typography.heading4?.regular?.fontWeight,
            color: _colorPalette.error,
          ),
        ),
      ),
    );
  }
}
