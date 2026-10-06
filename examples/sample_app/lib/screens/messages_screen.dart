import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as cc;
import '../utils/component_toggles.dart';
import 'thread_screen.dart';
import 'group_info_screen.dart';
import 'user_info_screen.dart';

class MessagesScreen extends StatefulWidget {
  final User? user;
  final Group? group;
  final int? goToMessageId;
  final BaseMessage? parentMessage;
  final bool isHistory;
  final bool isNewChat;

  /// When true, the back button in the message header is hidden.
  /// Used in desktop split-pane layout where the screen is embedded.
  final bool hideBackButton;

  /// When set (desktop 3-panel layout), threads, pinned messages and search
  /// open as the third column via this opener instead of being pushed over
  /// the chat.
  final void Function(Widget content, {String title})? onOpenSidePanel;

  /// Closes the third column. Needed by panel content whose own dismiss
  /// affordance isn't the panel's ✕ — search puts a back arrow inside its
  /// field, and popping the navigator there would take the chat with it.
  final VoidCallback? onCloseSidePanel;

  const MessagesScreen({
    super.key,
    this.user,
    this.group,
    this.goToMessageId,
    this.parentMessage,
    this.isHistory = false,
    this.isNewChat = false,
    this.hideBackButton = false,
    this.onOpenSidePanel,
    this.onCloseSidePanel,
  }) : assert(user != null || group != null);

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with
        UserListener,
        CometChatUserEventListener,
        GroupListener,
        CometChatGroupEventListener {
  // Mutable copies for tracking blocked / kicked state
  late User? _user;
  late Group? _group;
  bool _isUserBlocked = false;
  bool _kickedOrBanned = false;

  late final String _listenerId;

  // Pin & Save: imperative handle for the mounted list, used to jump to a
  // tapped pinned/saved message without tearing the list down.
  final CometChatMessageListController _messageListController =
      CometChatMessageListController();

  final _toggles = ComponentToggles.instance;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _group = widget.group;
    _listenerId = DateTime.now().millisecondsSinceEpoch.toString();

    // Add listeners for blocked/kicked state
    if (_user != null) {
      CometChat.addUserListener('${_listenerId}_msg_user', this);
      CometChatUserEvents.addUsersListener('${_listenerId}_msg_user_ui', this);
      _isUserBlocked =
          _user!.blockedByMe == true || _user!.hasBlockedMe == true;
    }
    if (_group != null) {
      CometChat.addGroupListener('${_listenerId}_msg_group', this);
      CometChatGroupEvents.addGroupsListener(
          '${_listenerId}_msg_group_ui', this);
    }
  }

  @override
  void dispose() {
    if (_user != null) {
      CometChat.removeUserListener('${_listenerId}_msg_user');
      CometChatUserEvents.removeUsersListener('${_listenerId}_msg_user_ui');
    }
    if (_group != null) {
      CometChat.removeGroupListener('${_listenerId}_msg_group');
      CometChatGroupEvents.removeGroupsListener('${_listenerId}_msg_group_ui');
    }
    super.dispose();
  }

  // Multi-attachment staging + batch send are owned by the UIKit composer
  // (enableMultipleAttachments, on by default) — no app wiring needed.

  // --- User Listeners (blocked state) ---

  @override
  void ccUserBlocked(User user) {
    if (_user != null && user.uid == _user!.uid) {
      _user!.blockedByMe = true;
      setState(() => _isUserBlocked = true);
    }
  }

  @override
  void ccUserUnblocked(User user) {
    if (_user != null && user.uid == _user!.uid) {
      _user!.blockedByMe = false;
      setState(() {
        _isUserBlocked =
            _user!.blockedByMe == true || _user!.hasBlockedMe == true;
      });
    }
  }

  @override
  void onUserOnline(User user) {
    if (_user != null && user.uid == _user!.uid) {
      _user =
          user; // Keep reference fresh; header BLoC handles its own UI update
    }
  }

  @override
  void onUserOffline(User user) {
    if (_user != null && user.uid == _user!.uid) {
      _user = user;
    }
  }

  // --- Group Listeners (kicked/banned state) ---

  @override
  void onGroupMemberKicked(
      cc.Action action, User kickedUser, User kickedBy, Group kickedFrom) {
    if (_group != null && kickedFrom.guid == _group!.guid) {
      final loggedInUid = CometChatUIKit.loggedInUser?.uid;
      if (kickedUser.uid == loggedInUid) {
        setState(() => _kickedOrBanned = true);
      } else {
        _group = kickedFrom;
        setState(() {});
      }
    }
  }

  @override
  void onGroupMemberBanned(
      cc.Action action, User bannedUser, User bannedBy, Group bannedFrom) {
    if (_group != null && bannedFrom.guid == _group!.guid) {
      final loggedInUid = CometChatUIKit.loggedInUser?.uid;
      if (bannedUser.uid == loggedInUid) {
        setState(() => _kickedOrBanned = true);
      } else {
        _group = bannedFrom;
        setState(() {});
      }
    }
  }

  @override
  void ccGroupMemberKicked(
      cc.Action message, User kickedUser, User kickedBy, Group kickedFrom) {
    if (_group != null && kickedFrom.guid == _group!.guid) {
      _group = kickedFrom;
      setState(() {});
    }
  }

  @override
  void ccGroupMemberBanned(
      cc.Action message, User bannedUser, User bannedBy, Group bannedFrom) {
    if (_group != null && bannedFrom.guid == _group!.guid) {
      _group = bannedFrom;
      setState(() {});
    }
  }

  @override
  void onGroupMemberLeft(cc.Action action, User leftUser, Group leftGroup) {
    if (_group != null && leftGroup.guid == _group!.guid) {
      _group = leftGroup;
      setState(() {});
    }
  }

  @override
  void onGroupMemberJoined(
      cc.Action action, User joinedUser, Group joinedGroup) {
    if (_group != null && joinedGroup.guid == _group!.guid) {
      _group = joinedGroup;
      setState(() {});
    }
  }

  @override
  void onMemberAddedToGroup(
      cc.Action action, User addedby, User userAdded, Group addedTo) {
    if (_group != null && addedTo.guid == _group!.guid) {
      _group = addedTo;
      setState(() {});
    }
  }

  @override
  void ccGroupMemberAdded(List<cc.Action> messages, List<User> usersAdded,
      Group groupAddedIn, User addedBy) {
    // UI event fires when the logged-in user adds members.
    // SDK onMemberAddedToGroup fires only for OTHER users in the group.
    if (_group != null && groupAddedIn.guid == _group!.guid) {
      _group = groupAddedIn;
      setState(() {});
    }
  }

  @override
  void onGroupMemberScopeChanged(
      cc.Action action,
      User updatedBy,
      User updatedUser,
      String scopeChangedTo,
      String scopeChangedFrom,
      Group group) {
    if (_group != null && group.guid == _group!.guid) {
      final loggedInUid = CometChatUIKit.loggedInUser?.uid;
      if (updatedUser.uid == loggedInUid) {
        _group!.scope = scopeChangedTo;
        setState(() {});
      }
    }
  }

  // --- Build ---

  Widget _buildMessageList() {
    final t = _toggles;
    final isAIUser = _user?.role == 'ai' || _user?.role == '@agentic';

    // When coming from AI chat history, scope messages to the parent message
    MessagesRequestBuilder? requestBuilder;
    int? parentMessageId;
    if (widget.parentMessage != null && widget.isHistory) {
      parentMessageId = widget.parentMessage!.id;
      requestBuilder = MessagesRequestBuilder()
        ..parentMessageId = widget.parentMessage!.id
        ..withParent = true
        ..hideReplies = false; // Show all messages in the thread (user + AI)
    }

    return CometChatMessageList(
      controller: _messageListController,
      user: _user,
      group: _group,
      goToMessageId: widget.goToMessageId,
      parentMessageId: parentMessageId,
      messagesRequestBuilder: requestBuilder,
      hideReplies: (widget.isHistory) ? false : true,
      showMarkAsUnreadOption: true,
      startFromUnreadMessages: true,
      hideDeletedMessages: t.hideDeletedMessages.value,
      disableReceipts: t.disableReceipts.value,
      avatarVisibility: t.avatarVisibility.value,
      hideDateSeparator: t.hideDateSeparator.value,
      hideStickyDate: t.hideStickyDate.value,
      disableReactions: isAIUser || t.disableReactions.value,
      enableSwipeToReply: isAIUser ? false : t.enableSwipeToReply.value,
      hideGroupActionMessages: t.hideGroupActionMessages.value,
      enableSmartReplies: isAIUser || t.enableSmartReplies.value,
      enableConversationStarters:
          isAIUser || t.enableConversationStarters.value,
      hideCopyMessageOption: t.hideCopyMessageOption.value,
      hideDeleteMessageOption: t.hideDeleteMessageOption.value,
      hideEditMessageOption: t.hideEditMessageOption.value,
      hideMessageInfoOption: t.hideMessageInfoOption.value,
      hideReplyInThreadOption: t.hideReplyInThreadOption.value,
      hideReactionOption: t.hideReactionOption.value,
      hideTranslateMessageOption: t.hideTranslateMessageOption.value,
      hideShareMessageOption: t.hideShareMessageOption.value,
      textFormatters: [
        CometChatMentionsFormatter(user: _user, group: _group),
        MarkdownTextFormatter(),
        CometChatUrlFormatter(),
        CometChatPhoneNumberFormatter(),
        CometChatEmailFormatter(),
      ],
      onThreadRepliesClick: (message, ctx, {template}) {
        if (!mounted) return;
        final openPanel = widget.onOpenSidePanel;
        if (openPanel != null) {
          openPanel(
            ThreadScreen(
              user: _user,
              group: _group,
              message: message,
              template: template,
              hideAppBar: true,
            ),
            title: cc.Translations.of(context).thread,
          );
          return;
        }
        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 280),
            reverseTransitionDuration: const Duration(milliseconds: 220),
            pageBuilder: (_, animation, __) => ThreadScreen(
              user: _user,
              group: _group,
              message: message,
              template: template,
            ),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity:
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Pin & Save: jump target for a tapped pinned row. Top-level messages
  /// scroll THIS list to the message — the pinned screen has already popped,
  /// so pushing another MessagesScreen would just stack a duplicate chat.
  /// Thread replies still open their thread screen (parent fetched on demand).
  Future<void> _openPinnedMessage(BaseMessage message) async {
    if (message.parentMessageId != 0) {
      final parent = await CometChat.getMessageDetails(message.parentMessageId);
      if (parent == null || !mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ThreadScreen(
            user: _user,
            group: _group,
            message: parent,
            goToMessageId: message.id,
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    _jumpTo(message.id);
  }

  /// Re-targets the message list at [messageId].
  ///
  /// Goes through the list's controller, so the mounted list scrolls (loading
  /// the page around the target when it isn't in memory) and keeps its state
  /// — no remount, no extra route.
  void _jumpTo(int messageId) {
    _messageListController.jumpToMessage(messageId);
  }

  /// Header ⋯ menu → delete this conversation, then leave the screen.
  ///
  /// Confirmed first: unlike pin/save this is destructive and not undoable
  /// from the same menu.

  /// Header ⋯ menu / name-tap → info screen.
  ///
  /// Desktop opens it as the third column beside the chat; mobile pushes it
  /// full-screen as before.
  void _openInfoScreen() {
    final openPanel = widget.onOpenSidePanel;
    final translations = cc.Translations.of(context);

    if (_group != null) {
      if (openPanel != null) {
        openPanel(
          GroupInfoScreen(group: _group!, hideAppBar: true),
          title: translations.groupInfo,
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupInfoScreen(group: _group!)),
      );
    } else if (_user != null) {
      if (openPanel != null) {
        openPanel(
          UserInfoScreen(user: _user!, hideAppBar: true),
          title: translations.userInfo,
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserInfoScreen(user: _user!)),
      );
    }
  }

  /// Header ⋯ menu → message search scoped to this conversation; a result
  /// tap reuses the pinned-row jump flow.
  void _openSearchScreen() {
    final openPanel = widget.onOpenSidePanel;
    if (openPanel != null) {
      // Desktop: search is the third column, so results jump the chat that
      // stays visible beside it.
      openPanel(
        CometChatSearch(
          user: _user,
          group: _group,
          searchIn: const [SearchScope.messages],
          onBack: () => widget.onCloseSidePanel?.call(),
          onMessageClicked: (message) {
            widget.onCloseSidePanel?.call();
            _openPinnedMessage(message);
          },
        ),
        title: cc.Translations.of(context).search,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (searchCtx) => CometChatSearch(
          user: _user,
          group: _group,
          searchIn: const [SearchScope.messages],
          onBack: () => Navigator.of(searchCtx).pop(),
          onMessageClicked: (message) {
            Navigator.of(searchCtx).pop();
            _openPinnedMessage(message);
          },
        ),
      ),
    );
  }

  /// Colour-picker trailing action (Trailing Toolbar Buttons DD §8.2).
  ///
  /// Exercises all four acceptance scenarios from consumer code alone:
  /// S1 apply to the live selection, S2 remove, S3 compose with bold (the
  /// kit merges formats → inline style), S4 skip mentions via
  /// getMentionRanges.
  Future<void> _onTextColorTap(
    BuildContext context,
    TextEditingController controller,
  ) async {
    if (controller is! RichTextEditingController) return;
    // On web the tap that opened us may have blurred the field and collapsed
    // the live selection — fall back to the controller's remembered one.
    var selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) {
      final last = controller.lastNonCollapsedSelection;
      if (last != null &&
          last.start >= 0 &&
          last.end <= controller.text.length) {
        selection = last;
      }
    }
    if (!selection.isValid || selection.isCollapsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select some text first'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final start = selection.start;
    final end = selection.end;

    const swatches = <Color>[
      Color(0xFFE53935),
      Color(0xFFFB8C00),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
      Color(0xFF8E24AA),
    ];

    final picked = await showDialog<Object>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Text colour'),
        contentPadding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            children: [
              for (final color in swatches)
                InkWell(
                  onTap: () => Navigator.of(dialogContext).pop(color),
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(backgroundColor: color, radius: 16),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop('remove'),
            icon: const Icon(Icons.format_color_reset_outlined),
            label: const Text('Remove colour'),
          ),
        ],
      ),
    );
    if (picked == null) return;

    const styleId = 'demo-text-color';
    if (picked == 'remove') {
      controller.removeInlineStyle(start, end, id: styleId);
      return;
    }

    // S4: colour only the non-mention stretches of the selection — a
    // mention keeps its own styling.
    final color = picked as Color;
    var cursor = start;
    final mentions = controller.getMentionRanges()
      ..sort((a, b) => a.start.compareTo(b.start));
    for (final mention in mentions) {
      if (mention.end <= cursor || mention.start >= end) continue;
      if (mention.start > cursor) {
        controller.applyInlineStyle(
          cursor,
          mention.start,
          TextStyle(color: color),
          id: styleId,
        );
      }
      cursor = mention.end;
    }
    if (cursor < end) {
      controller.applyInlineStyle(
        cursor,
        end,
        TextStyle(color: color),
        id: styleId,
      );
    }
  }

  Widget _buildComposer() {
    final t = _toggles;
    final isAI = _user?.role == 'ai' || _user?.role == '@agentic';
    return CometChatMessageComposer(
      user: _user,
      group: _group,
      parentMessageId: widget.parentMessage?.id ?? 0,
      placeholderText: isAI ? 'Ask anything...' : null,
      disableTypingEvents: isAI || t.disableTypingEvents.value,
      hideVoiceRecordingButton: isAI || t.hideVoiceRecordingButton.value,
      hideSendButton: t.hideSendButton.value,
      hideAttachmentButton: isAI || t.hideAttachmentButton.value,
      hideStickersButton: isAI || t.hideStickersButton.value,
      disableMentions: isAI || t.disableMentions.value,
      hideBottomSafeArea: t.hideBottomSafeArea.value,
      layout: cc.CometChatComposerLayout.singleLine,
      // Trailing Toolbar Buttons DD — the canonical colour-picker exemplar.
      // All colour logic is consumer code (§1.1.1): the kit only exposes the
      // slot, the controller, and getMentionRanges.
      richTextToolbarActions: isAI
          ? null
          : (context, user, group, id) => [
                CometChatMessageComposerAction(
                  id: 'text_color',
                  title: 'Text colour',
                  icon: const Icon(Icons.palette_outlined),
                  onToolbarTap: _onTextColorTap,
                ),
              ],
      textFormatters: isAI
          ? [] // No formatters for AI chat
          : [
              CometChatMentionsFormatter(user: _user, group: _group),
              MarkdownTextFormatter(),
              CometChatUrlFormatter(),
              CometChatPhoneNumberFormatter(),
              CometChatEmailFormatter(),
            ],
      enableRichTextFormatting: !isAI,
      showRichTextFormattingOptions: !isAI,
    );
  }

  @override
  Widget build(BuildContext context) {
    final _colorPalette = CometChatThemeHelper.getColorPalette(context);
    final _typography = CometChatThemeHelper.getTypography(context);
    final _isAI = _user?.role == 'ai' || _user?.role == '@agentic';
    return Scaffold(
      backgroundColor: _colorPalette.background1,
      appBar: CometChatMessageHeader(
        user: _user,
        group: _group,
        showBackButton: !widget.hideBackButton,
        onBack: widget.hideBackButton ? null : () => Navigator.pop(context),
        // A user either side has blocked cannot be called: no buttons, as
        // in Android's MessagesActivity.
        hideVideoCallButton:
            _isAI || _isUserBlocked || _toggles.hideVideoCallButton.value,
        hideVoiceCallButton:
            _isAI || _isUserBlocked || _toggles.hideVoiceCallButton.value,
        usersStatusVisibility: _toggles.headerUsersStatusVisibility.value,
        // Pin & Save: the header ⋯ menu opens the conversation's pinned
        // list; tapping a row jumps to that message (replies open their
        // thread screen).
        onPinnedMessageItemTap: _openPinnedMessage,
        onPinnedMessagesTap: widget.onOpenSidePanel == null
            ? null
            : () => widget.onOpenSidePanel!(
                  CometChatPinnedMessages(
                    user: _user,
                    group: _group,
                    onItemTap: _openPinnedMessage,
                    showBackButton: false,
                    // The panel renders its own title bar and close button,
                    // so the screen's own header would be a second one.
                    hideAppBar: true,
                  ),
                  title: cc.Translations.of(context).pinnedMessagesTitle,
                ),
        // ⋯ overflow menu entries + tap-on-name → info screen.
        onInfoTap: _isAI ? null : _openInfoScreen,
        onSearchTap: _isAI ? null : _openSearchScreen,
        onHeaderTap: _isAI ? null : _openInfoScreen,
        chatHistoryButtonClick: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CometChatAIAssistantChatHistory(
                user: _user,
                group: _group,
                onNewChatButtonClicked: () {
                  if (widget.isHistory) {
                    Navigator.of(context).pop();
                  }
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MessagesScreen(
                        user: _user,
                        group: _group,
                        isNewChat: true,
                      ),
                    ),
                  );
                },
                onMessageClicked: (message) {
                  if (message != null) {
                    Navigator.of(context)
                      ..pop()
                      ..pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MessagesScreen(
                          user: _user,
                          group: _group,
                          parentMessage: message,
                          isHistory: true,
                        ),
                      ),
                    );
                  }
                },
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
          );
        },
        messageHeaderStyle: CometChatMessageHeaderStyle(
          backgroundColor: _colorPalette.background1,
          border: Border(
            bottom: BorderSide(
              color: _colorPalette.borderLight ?? Colors.transparent,
              width: 1.0,
            ),
          ),
        ),
        trailingView: (user, group, ctx) => [
          if (user?.role == 'ai' || user?.role == '@agentic') ...[
            IconButton(
              icon: Icon(Icons.add, color: _colorPalette.iconPrimary),
              tooltip: 'New Chat',
              onPressed: () {
                Navigator.pushReplacement(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => MessagesScreen(
                      user: _user,
                      group: _group,
                      isNewChat: true,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.history, color: _colorPalette.iconPrimary),
              tooltip: 'AI Chat History',
              onPressed: () {
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => CometChatAIAssistantChatHistory(
                      user: _user,
                      group: _group,
                      onNewChatButtonClicked: () {
                        // Pop history, then replace current messages with fresh one
                        if (widget.isHistory) {
                          Navigator.of(ctx).pop();
                        }
                        Navigator.pushReplacement(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => MessagesScreen(
                              user: _user,
                              group: _group,
                              isNewChat: true,
                            ),
                          ),
                        );
                      },
                      onMessageClicked: (message) {
                        if (message != null) {
                          Navigator.of(ctx)
                            ..pop()
                            ..pop();
                          Navigator.push(
                            ctx,
                            MaterialPageRoute(
                              builder: (_) => MessagesScreen(
                                user: _user,
                                group: _group,
                                parentMessage: message,
                                isHistory: true,
                              ),
                            ),
                          );
                        }
                      },
                      onClose: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                );
              },
            ),
          ], // end AI buttons spread
        ],
      ),
      body: SafeArea(
        top: false,
        child: Container(
          color: _colorPalette.background3,
          child: Column(
            children: [
              // Blocked user banner
              if (_isUserBlocked && _user != null)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: _colorPalette.warning?.withValues(alpha: 0.15),
                  child: Row(
                    children: [
                      Icon(Icons.block, color: _colorPalette.warning, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _user!.blockedByMe == true
                              ? 'You have blocked this user.'
                              : 'This user has blocked you.',
                          style: TextStyle(
                            fontSize: _typography.body?.regular?.fontSize,
                            color: _colorPalette.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Kicked/banned banner
              if (_kickedOrBanned && _group != null)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: _colorPalette.error?.withValues(alpha: 0.15),
                  child: Row(
                    children: [
                      Icon(Icons.remove_circle_outline,
                          color: _colorPalette.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You have been removed from this group.',
                          style: TextStyle(
                            fontSize: _typography.body?.regular?.fontSize,
                            color: _colorPalette.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _buildMessageList(),
              ),
              if (!_kickedOrBanned) _buildComposer(),
            ],
          ),
        ),
      ),
    );
  }
}
