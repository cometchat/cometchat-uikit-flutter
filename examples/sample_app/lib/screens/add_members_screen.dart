import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as cc;

/// Add Members screen — select users and add them to a group.
class AddMembersScreen extends StatefulWidget {
  final Group group;

  const AddMembersScreen({super.key, required this.group});

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  late CometChatColorPalette _colorPalette;
  late CometChatTypography _typography;
  late CometChatSpacing _spacing;

  late UsersBloc _usersBloc;
  User? _loggedInUser;
  Conversation? _conversation;
  String? _conversationId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (!UsersServiceLocator.instance.isInitialized) {
      UsersServiceLocator.instance.setup();
    }
    // Include AI agents (`@agentic`) alongside regular users so an agent can be
    // added to a group for testing — the default user query excludes them.
    _usersBloc = UsersBloc(
      usersRequestBuilder: UsersRequestBuilder()
        ..roles = ['default', AIConstants.aiRole],
    );
    _usersBloc.add(const LoadUsers());
    _initLoggedInUser();
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
    _usersBloc.close();
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
    // Notify UI that initialization is complete
    if (mounted) setState(() {});
  }

  void _addMembers() {
    final state = _usersBloc.state;
    if (state is! UsersLoaded) return;

    final selectedUsers =
        state.users.where((u) => state.selectedUsers.contains(u.uid)).toList();
    if (selectedUsers.isEmpty) return;

    // Guard: _loggedInUser must be initialized before adding members
    if (_loggedInUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _colorPalette.error,
        content: const Text('Please wait, initializing...'),
      ));
      return;
    }

    setState(() => _isLoading = true);

    final members = selectedUsers
        .map((user) => GroupMember(
              scope: GroupMemberScope.participant,
              name: user.name,
              role: user.role ?? '',
              status: user.status ?? '',
              uid: user.uid,
              avatar: user.avatar,
              blockedByMe: user.blockedByMe,
              joinedAt: DateTime.now(),
              hasBlockedMe: user.hasBlockedMe,
              lastActiveAt: user.lastActiveAt,
              link: user.link,
              metadata: user.metadata,
              statusMessage: user.statusMessage,
              tags: user.tags,
            ))
        .toList();

    CometChat.addMembersToGroup(
      guid: widget.group.guid,
      groupMembers: members,
      onSuccess: (Map<String?, String?> result) async {
        final addedMembers = <User>[];
        final messages = <cc.Action>[];
        for (final member in members) {
          if (result[member.uid] == 'success') {
            addedMembers.add(member);
            messages.add(cc.Action(
              conversationId: _conversationId ?? '',
              message: '${_loggedInUser?.name} added ${member.name}',
              oldScope: '',
              newScope: GroupMemberScope.participant,
              muid: DateTime.now().microsecondsSinceEpoch.toString(),
              sender: _loggedInUser!,
              receiverUid: widget.group.guid,
              type: MessageTypeConstants.groupActions,
              receiverType: ReceiverTypeConstants.group,
              parentMessageId: 0,
              receiver: widget.group,
            ));
          }
        }

        if (!mounted) return;

        if (messages.isEmpty || addedMembers.isEmpty) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: _colorPalette.error,
            content: const Text(
                'Unable to add members. They may already be in the group.'),
          ));
        } else {
          // Refresh group from SDK to get accurate membersCount BEFORE firing
          // ccGroupMemberAdded. The SDK returns 'success' even for duplicate
          // members, so we can't safely just increment locally.
          // Awaiting here ensures listeners get the correct membersCount.
          final refreshedGroup = await CometChat.getGroup(
            widget.group.guid,
            onSuccess: (g) => g,
            onError: (_) {},
          );
          if (refreshedGroup != null) {
            widget.group.membersCount = refreshedGroup.membersCount;
          } else {
            // Fallback: increment locally (may be inaccurate for duplicates)
            widget.group.membersCount += addedMembers.length;
          }
          if (!mounted) return;
          CometChatGroupEvents.ccGroupMemberAdded(
              messages, addedMembers, widget.group, _loggedInUser!);
          setState(() => _isLoading = false);
          _usersBloc.add(const ClearUserSelection());
          Navigator.pop(context);
        }
      },
      onError: (CometChatException e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        debugPrint('Add members failed: ${e.message}');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _colorPalette.error,
          content: const Text('Error adding members.'),
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _colorPalette.background1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _colorPalette.iconPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Text(
          cc.Translations.of(context).addMembers,
          style: TextStyle(
            color: _colorPalette.textPrimary,
            fontSize: _typography.heading1?.bold?.fontSize,
            fontWeight: _typography.heading1?.bold?.fontWeight,
            fontFamily: _typography.heading1?.bold?.fontFamily,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: CometChatUsers(
              usersBloc: _usersBloc,
              stickyHeaderVisibility: true,
              hideAppbar: true,
              selectionMode: SelectionMode.multiple,
              onSelection: (_, __) {},
              submitIcon: const SizedBox(),
              activateSelection: ActivateSelection.onClick,
            ),
          ),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: _colorPalette.background1,
              border: Border(
                top: BorderSide(
                  color: _colorPalette.borderLight ?? Colors.transparent,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _spacing.margin3 ?? 0,
                vertical: _spacing.margin4 ?? 0,
              ),
              child: SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addMembers,
                  style: ButtonStyle(
                    backgroundColor:
                        WidgetStateProperty.all(_colorPalette.primary),
                    shape: WidgetStateProperty.all(RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(_spacing.radius2 ?? 8),
                    )),
                    padding: WidgetStateProperty.all(EdgeInsets.symmetric(
                      vertical: _spacing.padding2 ?? 8,
                      horizontal: _spacing.padding5 ?? 20,
                    )),
                  ),
                  child: Center(
                    child: _isLoading
                        ? CircularProgressIndicator(color: _colorPalette.white)
                        : Text(
                            cc.Translations.of(context).addMembers,
                            style: TextStyle(
                              color: _colorPalette.buttonIconColor,
                              fontSize: _typography.button?.medium?.fontSize,
                              fontFamily:
                                  _typography.button?.medium?.fontFamily,
                              fontWeight:
                                  _typography.button?.medium?.fontWeight,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
