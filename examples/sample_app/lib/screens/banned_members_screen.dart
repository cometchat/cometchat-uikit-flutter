import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as cc;
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_gate.dart';

import 'banned_members_offline.dart';

/// Banned Members screen — lists banned group members with unban option.
class BannedMembersScreen extends StatefulWidget {
  final Group group;

  const BannedMembersScreen({super.key, required this.group});

  @override
  State<BannedMembersScreen> createState() => _BannedMembersScreenState();
}

class _BannedMembersScreenState extends State<BannedMembersScreen>
    with GroupListener, CometChatGroupEventListener {
  late CometChatColorPalette _colorPalette;
  late CometChatTypography _typography;
  late CometChatSpacing _spacing;

  User? _loggedInUser;
  Conversation? _conversation;
  String? _conversationId;

  final List<GroupMember> _bannedMembers = [];
  bool _isLoading = true;
  bool _hasMore = true;
  bool _hasError = false;
  bool _isUnbanning = false;

  late BannedGroupMembersRequest _request;
  late final String _groupListenerId;
  late final String _uiGroupListenerId;
  late final String _connectionListenerId;

  /// Whether offline support was on when the screen opened; only then is the
  /// reconnect reload registered.
  bool _offlineReconnect = false;

  /// Offline-on page reads: one in flight at a time, and a reconnect during
  /// one queues a reload for when it finishes.
  final BannedPageQueue _pageQueue = BannedPageQueue();

  @override
  void initState() {
    super.initState();
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    _groupListenerId = '${ts}_banned_sdk';
    _uiGroupListenerId = '${ts}_banned_ui';
    _connectionListenerId = '${ts}_banned_connection';
    if (OfflineGate.isOn()) {
      _offlineReconnect = true;
      CometChat.addConnectionListener(
        _connectionListenerId,
        _BannedConnectionListener(onConnectedCallback: _onReconnected),
      );
    }
    CometChat.addGroupListener(_groupListenerId, this);
    CometChatGroupEvents.addGroupsListener(_uiGroupListenerId, this);
    _request =
        BannedGroupMembersRequestBuilder(guid: widget.group.guid).build();
    _initLoggedInUser();
    _loadBannedMembers();
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
    if (_offlineReconnect) {
      CometChat.removeConnectionListener(_connectionListenerId);
    }
    super.dispose();
  }

  Future<void> _initLoggedInUser() async {
    _loggedInUser = await CometChat.getLoggedInUser();
    _conversation = await CometChat.getConversation(
      widget.group.guid,
      ConversationType.group,
      onSuccess: (c) => c,
      onError: (_) {},
    );
    _conversationId = _conversation?.conversationId;
  }

  void _loadBannedMembers() {
    if (OfflineGate.isOn()) {
      _loadPageTwoPhase(BannedMembersPage());
      return;
    }
    _request.fetchNext(
      onSuccess: (List<GroupMember> members) {
        if (!mounted) return;
        setState(() {
          _bannedMembers.addAll(members);
          _hasMore = members.isNotEmpty;
          _isLoading = false;
        });
      },
      onError: (e) {
        if (!mounted) return;
        debugPrint('Banned members fetch failed: ${e.message}');
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      },
    );
  }

  // ── Offline on (W6) ──────────────────────────────────────────────

  /// Reads one page with the two-phase listener: the cached page paints at
  /// once and the server page replaces it by uid (see [BannedMembersPage]).
  void _loadPageTwoPhase(BannedMembersPage page) {
    if (!_pageQueue.tryStart()) return;
    bannedMembersFetchStream(_request).listen((phase) {
      if (!mounted) return;
      setState(() {
        final next = page.apply(phase, (
          rows: List<GroupMember>.of(_bannedMembers),
          hasMore: _hasMore,
          hasError: _hasError,
          isLoading: _isLoading,
        ));
        _bannedMembers
          ..clear()
          ..addAll(next.rows);
        _hasMore = next.hasMore;
        _hasError = next.hasError;
        _isLoading = next.isLoading;
      });
    }, onDone: () {
      if (_pageQueue.finish()) _onReconnected();
    });
  }

  /// The connection is back: re-read the first page once, two-phase, keeping
  /// the rows on screen until the server page replaces them. While a page is
  /// in flight the reload is queued and runs when that page finishes.
  void _onReconnected() {
    if (!mounted || !OfflineGate.isOn() || !_pageQueue.reconnect()) return;
    _request =
        BannedGroupMembersRequestBuilder(guid: widget.group.guid).build();
    _loadPageTwoPhase(BannedMembersPage(reload: true));
  }

  // ── SDK Listeners ────────────────────────────────────────────────

  @override
  void onGroupMemberBanned(
      cc.Action action, User bannedUser, User bannedBy, Group group) {
    if (group.guid == widget.group.guid) {
      setState(() {
        _bannedMembers.add(GroupMember.fromUid(
          scope: group.scope,
          uid: bannedUser.uid,
          name: bannedUser.name,
        ));
      });
    }
  }

  @override
  void onGroupMemberUnbanned(
      cc.Action action, User unbannedUser, User unbannedBy, Group group) {
    if (group.guid == widget.group.guid) {
      setState(() {
        _bannedMembers.removeWhere((m) => m.uid == unbannedUser.uid);
      });
    }
  }

  @override
  void ccGroupMemberBanned(
      cc.Action message, User bannedUser, User bannedBy, Group bannedFrom) {
    if (bannedFrom.guid == widget.group.guid) {
      setState(() {
        _bannedMembers.add(GroupMember.fromUid(
          scope: bannedFrom.scope,
          uid: bannedUser.uid,
          name: bannedUser.name,
        ));
      });
    }
  }

  @override
  void ccGroupMemberUnbanned(cc.Action action, User unbannedUser,
      User unbannedBy, Group unbannedFrom) {
    if (unbannedFrom.guid == widget.group.guid) {
      setState(() {
        _bannedMembers.removeWhere((m) => m.uid == unbannedUser.uid);
      });
    }
  }

  // ── Unban ────────────────────────────────────────────────────────

  void _unbanMember(GroupMember member) {
    CometChatConfirmDialog(
      context: context,
      icon: Icon(Icons.not_interested, size: 48, color: _colorPalette.error),
      title: Text(
        'Unban ${member.name}?',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _colorPalette.textPrimary,
          fontSize: _typography.heading2?.medium?.fontSize,
          fontWeight: _typography.heading2?.medium?.fontWeight,
          fontFamily: _typography.heading2?.medium?.fontFamily,
        ),
      ),
      messageText: Text(
        'Are you sure you want to unban ${member.name} from ${widget.group.name}?',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _colorPalette.textSecondary,
          fontSize: _typography.body?.regular?.fontSize,
          fontWeight: _typography.body?.regular?.fontWeight,
          fontFamily: _typography.body?.regular?.fontFamily,
        ),
      ),
      confirmButtonText: cc.Translations.of(context).unban.toUpperCase(),
      cancelButtonText: cc.Translations.of(context).cancel,
      style: CometChatConfirmDialogStyle(
        confirmButtonBackground: _colorPalette.error,
        confirmButtonTextColor: _colorPalette.white,
      ),
      onCancel: (dialogContext) => Navigator.of(dialogContext).pop(),
      onConfirm: (dialogContext) => _performUnban(member, dialogContext),
    ).show();
  }

  void _performUnban(GroupMember member, BuildContext dialogContext) {
    setState(() => _isUnbanning = true);
    CometChat.unbanGroupMember(
      guid: widget.group.guid,
      uid: member.uid,
      onSuccess: (_) {
        if (!mounted) return;
        CometChatGroupEvents.ccGroupMemberUnbanned(
          cc.Action(
            conversationId: _conversationId ?? '',
            message: '${_loggedInUser?.name} unbanned ${member.name}',
            oldScope: '',
            newScope: '',
            muid: DateTime.now().microsecondsSinceEpoch.toString(),
            sender: _loggedInUser!,
            receiverUid: widget.group.guid,
            type: MessageTypeConstants.groupActions,
            receiverType: ReceiverTypeConstants.group,
            parentMessageId: 0,
            receiver: widget.group,
          ),
          member,
          _loggedInUser!,
          widget.group,
        );
        setState(() {
          _bannedMembers.removeWhere((m) => m.uid == member.uid);
          _isUnbanning = false;
        });
        Navigator.of(dialogContext).pop(); // close dialog
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _isUnbanning = false);
        Navigator.of(dialogContext).pop();
        debugPrint('Unban failed: ${e.message}');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colorPalette.background1,
      appBar: AppBar(
        backgroundColor: _colorPalette.background1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _colorPalette.iconPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Text(
          cc.Translations.of(context).bannedMembers,
          style: TextStyle(
            color: _colorPalette.textPrimary,
            fontSize: _typography.heading1?.bold?.fontSize,
            fontWeight: _typography.heading1?.bold?.fontWeight,
            fontFamily: _typography.heading1?.bold?.fontFamily,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: _colorPalette.iconSecondary),
            const SizedBox(height: 16),
            Text('Unable to load banned members',
                style: TextStyle(color: _colorPalette.textPrimary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isLoading = true;
                  _bannedMembers.clear();
                });
                _request =
                    BannedGroupMembersRequestBuilder(guid: widget.group.guid)
                        .build();
                _loadBannedMembers();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_isLoading && _bannedMembers.isEmpty) {
      return _buildShimmer();
    }

    if (_bannedMembers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              AssetConstants(CometChatThemeHelper.getBrightness(context))
                  .emptyUserList,
              package: UIConstants.packageName,
              width: 120,
              height: 120,
            ),
            Text(
              cc.Translations.of(context).noBannedMembersFound,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _colorPalette.textPrimary,
                fontSize: _typography.heading3?.bold?.fontSize,
                fontWeight: _typography.heading3?.bold?.fontWeight,
                fontFamily: _typography.heading3?.bold?.fontFamily,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _hasMore ? _bannedMembers.length + 1 : _bannedMembers.length,
      itemBuilder: (context, index) {
        if (index >= _bannedMembers.length) {
          _loadBannedMembers();
          return _buildShimmer();
        }
        final member = _bannedMembers[index];
        return CometChatListItem(
          key: ValueKey(member.uid),
          id: member.uid,
          avatarName: member.name,
          avatarURL: member.avatar,
          title: member.name,
          tailView: IconButton(
            onPressed: () => _unbanMember(member),
            icon: Icon(Icons.close, color: _colorPalette.iconSecondary),
          ),
          style: ListItemStyle(
            background: _colorPalette.background1,
            titleStyle: TextStyle(
              overflow: TextOverflow.ellipsis,
              fontSize: _typography.heading4?.medium?.fontSize,
              fontWeight: _typography.heading4?.medium?.fontWeight,
              fontFamily: _typography.heading4?.medium?.fontFamily,
              color: _colorPalette.textPrimary,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: _spacing.padding4 ?? 0,
              vertical: _spacing.padding3 ?? 0,
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmer() {
    return CometChatShimmerEffect(
      colorPalette: _colorPalette,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 10,
        itemBuilder: (_, __) => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _spacing.padding4 ?? 0,
            vertical: _spacing.padding3 ?? 0,
          ),
          child: Row(
            children: [
              Padding(
                padding: EdgeInsets.only(right: _spacing.padding3 ?? 0),
                child: const CircleAvatar(
                    radius: 24, backgroundColor: Colors.grey),
              ),
              Container(
                height: 22,
                width: MediaQuery.of(context).size.width * 0.4,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(_spacing.radius2 ?? 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannedConnectionListener with ConnectionListener {
  _BannedConnectionListener({required this.onConnectedCallback});

  final void Function() onConnectedCallback;

  @override
  void onConnected() => onConnectedCallback();
}
