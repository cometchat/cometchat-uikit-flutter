import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:sample_app/utils/feature_flags.dart';
import 'package:sample_app/utils/component_toggles.dart';
import 'package:sample_app/screens/messages_screen.dart';
import 'package:sample_app/screens/contacts_screen.dart';
import 'package:sample_app/screens/create_group_screen.dart';
import 'package:sample_app/screens/call_log_details_screen.dart';
import 'package:sample_app/screens/join_protected_group_screen.dart';
import 'package:sample_app/screens/login_screen.dart';
import 'package:sample_app/screens/thread_screen.dart';
import 'package:sample_app/screens/threads_screen.dart';
import 'package:sample_app/widgets/responsive_layout.dart';
import 'package:sample_app/utils/call_error_snackbar.dart';

/// A responsive home screen that shows:
/// - Desktop/Web (>=700px): 3-panel layout with nested navigators
///   - Left panel: conversation list / tabs (own navigator)
///   - Middle panel: messages view (own navigator for threads, info, etc.)
///   - Right panel: contextual panel (search messages, shown on demand)
/// - Mobile (<700px): standard bottom-nav with push navigation
class ResponsiveHomeScreen extends StatefulWidget {
  const ResponsiveHomeScreen({super.key});

  @override
  State<ResponsiveHomeScreen> createState() => _ResponsiveHomeScreenState();
}

class _ResponsiveHomeScreenState extends State<ResponsiveHomeScreen> {
  int _currentIndex = 0;
  final _toggles = ComponentToggles.instance;
  late CometChatColorPalette _colorPalette;
  late CometChatTypography _typography;

  // Currently selected conversation for the middle panel (desktop only)
  User? _selectedUser;
  Group? _selectedGroup;
  int? _selectedMessageId;

  // Key to force rebuild of MessagesScreen when selection changes
  int _messagesKey = 0;

  // Navigator keys for nested navigation
  final GlobalKey<NavigatorState> _leftNavKey = GlobalKey<NavigatorState>();

  // How many routes the left column has pushed above its tab content.
  // The panel's own header belongs to the tab, not to the column, so it is
  // hidden while a pushed screen (Saved, Contacts, Search, Call log details,
  // Join protected group) is showing its own — otherwise the two stack.
  int _leftPanelRouteDepth = 0;
  late final _LeftPanelRouteObserver _leftNavObserver =
      _LeftPanelRouteObserver(onDepthChanged: (depth) {
    // Deferred a frame: navigator callbacks can land mid-build, and setState
    // during build throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && depth != _leftPanelRouteDepth) {
        setState(() => _leftPanelRouteDepth = depth);
      }
    });
  });

  // Panel widths, dragged by the handles between the columns. The middle
  // column has no width of its own — it takes whatever these two leave.
  double _leftPanelWidth = ResponsiveBreakpoints.kLeftPanelWidth;
  double _rightPanelWidth = ResponsiveBreakpoints.kRightPanelWidth;

  // Right panel state — the third column: threads / pinned / search / info.
  // _rightPanelKey re-keys the panel's Navigator so swapping content builds
  // the new route instead of keeping the first one it generated.
  int _rightPanelKey = 0;
  bool _showRightPanel = false;
  Widget? _rightPanelContent;
  String _rightPanelTitle = '';

  // UI event listener
  final String _uiListenerId =
      'responsive_home_ui_${DateTime.now().millisecondsSinceEpoch}';

  static const _tabTitles = ['Chats', 'Calls', 'Users', 'Groups'];

  @override
  void initState() {
    super.initState();
    CometChatUIEvents.addUiListener(
      _uiListenerId,
      _ResponsiveHomeUIEventListener(
        onOpenChat: (user, group) {
          if (mounted) _openConversation(user: user, group: group);
        },
      ),
    );
  }

  @override
  void dispose() {
    CometChatUIEvents.removeUiListener(_uiListenerId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _colorPalette = CometChatThemeHelper.getColorPalette(context);
    _typography = CometChatThemeHelper.getTypography(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveBreakpoints.kDesktopBreakpoint) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DESKTOP LAYOUT (3-panel with nested navigators)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: _colorPalette.background1,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showRight = _showRightPanel && _rightPanelContent != null;
          return Row(
            children: [
              // LEFT PANEL — conversation list with its own navigator
              SizedBox(
                width: _leftPanelWidth,
                child: _buildLeftPanel(),
              ),
              // Draggable divider: right drag widens the left panel.
              PanelResizeHandle(
                color: _colorPalette.borderLight ?? Colors.grey.shade800,
                onDelta: (delta) => _resizeLeftPanel(
                  delta,
                  constraints.maxWidth,
                  showRight,
                ),
              ),
              // MIDDLE PANEL — messages with its own navigator
              Expanded(
                child: _buildMiddlePanel(),
              ),
              // RIGHT PANEL — contextual (threads / pinned) shown on demand
              if (showRight) ...[
                // Right drag NARROWS the right panel — the handle is on its
                // leading edge, so the sign is inverted.
                PanelResizeHandle(
                  color: _colorPalette.borderLight ?? Colors.grey.shade800,
                  onDelta: (delta) =>
                      _resizeRightPanel(delta, constraints.maxWidth),
                ),
                SizedBox(
                  width: _rightPanelWidth,
                  child: _buildRightPanel(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Left panel with its own Navigator so that search, contacts, etc.
  /// push/pop within this panel only.
  Widget _buildLeftPanel() {
    return Column(
      children: [
        // AppBar — only over the tab content; a pushed screen supplies its own.
        if (_leftPanelRouteDepth == 0) _buildLeftPanelAppBar(),
        // Tab content with nested navigator
        Expanded(
          child: Navigator(
            key: _leftNavKey,
            observers: [_leftNavObserver],
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => _buildLeftContent(),
            ),
          ),
        ),
        // Bottom navigation bar
        _buildBottomNav(),
      ],
    );
  }

  Widget _buildLeftPanelAppBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _colorPalette.background1,
        border: Border(
          bottom: BorderSide(
            color: _colorPalette.borderLight ?? Colors.transparent,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            _tabTitles[_currentIndex],
            style: TextStyle(
              color: _colorPalette.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (FeatureFlags.showProfileMenu) _buildProfileMenu(),
        ],
      ),
    );
  }

  /// Pin & Save: a saved-messages row tap opens the message's conversation
  /// in the middle panel and jumps to it (thread replies open their thread
  /// screen).
  Future<void> _openSavedMessage(BaseMessage message) async {
    User? user;
    Group? group;
    if (message.receiverType == ReceiverTypeConstants.group) {
      final receiver = message.receiver;
      if (receiver is Group) group = receiver;
    } else {
      final loggedInUid = CometChatUIKit.loggedInUser?.uid;
      final sender = message.sender;
      final receiver = message.receiver;
      if (sender != null && sender.uid != loggedInUid) {
        user = sender;
      } else if (receiver is User) {
        user = receiver;
      }
    }
    if (user == null && group == null) return;

    if (message.parentMessageId != 0) {
      final parent = await CometChat.getMessageDetails(message.parentMessageId);
      if (parent == null || !mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ThreadScreen(
            user: user,
            group: group,
            message: parent,
            goToMessageId: message.id,
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    _openConversation(
      user: user,
      group: group,
      scrollToMessageId: message.id,
    );
  }

  /// The tab content (conversations, calls, users, groups)
  Widget _buildLeftContent() {
    if (_currentIndex == 1) {
      return CometChatCallLogs(
        hideAppbar: true,
        onItemClick: (callLog) {
          // Push call log details within left panel navigator
          _leftNavKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => CallLogDetailsScreen(callLog: callLog),
            ),
          );
        },
        onError: (Exception error) {
          // A call placed from a log row that failed; the list's own load
          // errors show in its error view.
          if (isCallLogsPlacementError(error)) {
            showCallPlacementError(error);
            return;
          }
          final errorMessage =
              error is CometChatException ? error.message : error.toString();
          debugPrint('CallLogs error: $errorMessage');
        },
      );
    }

    final int stackIndex = _currentIndex == 0 ? 0 : _currentIndex - 1;
    return ValueListenableBuilder<int>(
      valueListenable: _toggles.revision,
      builder: (context, _, __) {
        return IndexedStack(
          index: stackIndex,
          children: [
            _buildConversationsTab(),
            _buildUsersTab(),
            _buildGroupsTab(),
          ],
        );
      },
    );
  }

  /// Middle panel — messages view or empty state.
  /// The messages screen is rendered directly (not pushed into a navigator).
  /// Thread, group info, user info push on top via the middle navigator.
  Widget _buildMiddlePanel() {
    if (_selectedUser == null && _selectedGroup == null) {
      return _buildEmptyState();
    }

    return ClipRect(
      child: Navigator(
        key: ValueKey('middle_nav_$_messagesKey'),
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => MessagesScreen(
            key: ValueKey('messages_$_messagesKey'),
            user: _selectedUser,
            group: _selectedGroup,
            goToMessageId: _selectedMessageId,
            hideBackButton: true,
            // Without this the screen has no opener and falls back to
            // pushing threads/pinned onto its own navigator — which is the
            // middle column, not the third panel.
            onOpenSidePanel: showRightPanel,
            onCloseSidePanel: hideRightPanel,
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    return Column(
      children: [
        // Right panel header with close button
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _colorPalette.background1,
            border: Border(
              bottom: BorderSide(
                color: _colorPalette.borderLight ?? Colors.transparent,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                _rightPanelTitle,
                // Kit heading2/bold, not a hardcoded 16/w600 — the panel
                // header sits beside kit screens that use this token, and a
                // hand-rolled size and missing font family read as a
                // different header.
                style: TextStyle(
                  color: _colorPalette.textPrimary,
                  fontSize: _typography.heading2?.bold?.fontSize,
                  fontFamily: _typography.heading2?.bold?.fontFamily,
                  fontWeight: _typography.heading2?.bold?.fontWeight,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: _colorPalette.iconPrimary),
                onPressed: () {
                  setState(() {
                    _showRightPanel = false;
                    _rightPanelContent = null;
                  });
                },
              ),
            ],
          ),
        ),
        // Right panel content, under its own Navigator like the other two
        // columns. Panel content calls Navigator.pop for its own flows (an
        // info screen's back, leave-group, delete-chat); without a navigator
        // of its own those resolve to the ROOT one and would tear down the
        // whole home screen. Popping the panel's only route is a harmless
        // no-op instead.
        Expanded(
          child: _rightPanelContent == null
              ? const SizedBox.shrink()
              : Navigator(
                  key: ValueKey('right_nav_$_rightPanelKey'),
                  onGenerateRoute: (_) => MaterialPageRoute(
                    builder: (_) => _rightPanelContent!,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 72,
            color: _colorPalette.iconSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome to your Conversations',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _colorPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a chat from the list to start exploring\nyour messages or begin a new conversation',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _colorPalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOBILE LAYOUT (standard bottom nav + push navigation)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: _colorPalette.background1,
      appBar: AppBar(
        backgroundColor: _colorPalette.background1,
        title: Text(
          _tabTitles[_currentIndex],
          style: TextStyle(
            color: _colorPalette.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (FeatureFlags.showProfileMenu) _buildProfileMenu(),
        ],
      ),
      body: _buildMobileBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildMobileBody() {
    if (_currentIndex == 1) {
      return CometChatCallLogs(
        hideAppbar: true,
        onItemClick: (callLog) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallLogDetailsScreen(callLog: callLog),
            ),
          );
        },
        onError: (Exception error) {
          // A call placed from a log row that failed; the list's own load
          // errors show in its error view.
          if (isCallLogsPlacementError(error)) {
            showCallPlacementError(error);
            return;
          }
          final errorMessage =
              error is CometChatException ? error.message : error.toString();
          debugPrint('CallLogs error: $errorMessage');
        },
      );
    }

    final int stackIndex = _currentIndex == 0 ? 0 : _currentIndex - 1;
    return ValueListenableBuilder<int>(
      valueListenable: _toggles.revision,
      builder: (context, _, __) {
        return IndexedStack(
          index: stackIndex,
          children: [
            _buildConversationsTab(),
            _buildUsersTab(),
            _buildGroupsTab(),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED TAB BUILDERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildConversationsTab() {
    return Column(
      children: [
        // Search above the conversation list; the list's own built-in
        // search bar is hidden in favour of this one.
        InboxSearchBar(onTap: _openSearch),
        Expanded(child: _buildConversationsList()),
      ],
    );
  }

  Widget _buildConversationsList() {
    return CometChatConversations(
      hideAppbar: true,
      textFormatters: [
        CometChatMentionsFormatter(),
        MarkdownTextFormatter(),
        CometChatUrlFormatter(),
        CometChatPhoneNumberFormatter(),
        CometChatEmailFormatter(),
      ],
      hideSearch: true,
      onItemTap: (conversation) {
        final user = conversation.conversationWith is User
            ? conversation.conversationWith as User
            : null;
        final group = conversation.conversationWith is Group
            ? conversation.conversationWith as Group
            : null;
        _openConversation(user: user, group: group);
      },
      receiptsVisibility: _toggles.receiptsVisibility.value,
      usersStatusVisibility: _toggles.usersStatusVisibility.value,
      deleteConversationOptionVisibility:
          _toggles.deleteConversationOption.value,
      groupTypeVisibility: _toggles.groupTypeVisibility.value,
      disableSoundForMessages: _toggles.disableSoundForMessages.value,
    );
  }

  Widget _buildUsersTab() {
    return CometChatUsers(
      hideAppbar: true,
      onItemTap: (_, user) => _openConversation(user: user),
      hideSearch: _toggles.usersHideSearch.value,
      stickyHeaderVisibility: _toggles.usersStickyHeader.value,
    );
  }

  Widget _buildGroupsTab() {
    return Stack(
      children: [
        CometChatGroups(
          hideAppbar: true,
          onItemTap: (_, group) => _openGroupChat(group),
          hideSearch: _toggles.groupsHideSearch.value,
          groupTypeVisibility: _toggles.groupsGroupTypeVisibility.value,
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'create_group',
            backgroundColor: _colorPalette.primary,
            onPressed: () {
              showCreateGroup(
                context: context,
                colorPalette: _colorPalette,
              );
            },
            child: Icon(Icons.group_add, color: _colorPalette.white),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        // Pop left navigator back to root when switching tabs
        if (isDesktopLayout(context)) {
          _leftNavKey.currentState?.popUntil((route) => route.isFirst);
        }
        setState(() => _currentIndex = index);
      },
      backgroundColor: _colorPalette.background1,
      selectedItemColor: _colorPalette.primary,
      unselectedItemColor: _colorPalette.textSecondary,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_outlined),
          activeIcon: Icon(Icons.chat_rounded),
          label: 'Chats',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.call_outlined),
          activeIcon: Icon(Icons.call_rounded),
          label: 'Calls',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_rounded),
          activeIcon: Icon(Icons.person_rounded),
          label: 'Users',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_alt_outlined),
          activeIcon: Icon(Icons.people_alt_rounded),
          label: 'Groups',
        ),
      ],
    );
  }

  Widget _buildProfileMenu() {
    final loggedInUser = CometChatUIKit.loggedInUser;

    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _colorPalette.borderLight ?? Colors.transparent,
          width: 1,
        ),
      ),
      color: _colorPalette.background1,
      elevation: 2,
      menuPadding: const EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.zero,
      icon: CometChatAvatar(
        width: 36,
        height: 36,
        image: loggedInUser?.avatar ?? '',
        name: loggedInUser?.name ?? '',
      ),
      onSelected: (value) async {
        switch (value) {
          case '/create':
            if (isDesktopLayout(context)) {
              _leftNavKey.currentState?.push(
                MaterialPageRoute(builder: (_) => const ContactsScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactsScreen()),
              );
            }
            break;
          case '/saved':
            // Saved lives in the LEFT panel on desktop, beside conversations.
            // Desktop keeps the list in the left panel while the tapped
            // message opens in the centre; mobile pops it like any other
            // pushed route.
            final saved = CometChatSavedMessages(
              onItemTap: _openSavedMessage,
              popOnItemTap: !isDesktopLayout(context),
              // Desktop: panel chrome — ✕ on the right, title left.
              useCloseButton: isDesktopLayout(context),
            );
            if (isDesktopLayout(context)) {
              _leftNavKey.currentState?.push(
                MaterialPageRoute(builder: (_) => saved),
              );
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => saved));
            }
            break;
          case '/logout':
            await CometChatUIKit.logout(
              onSuccess: (_) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              onError: (e) {
                debugPrint('Logout error: ${e.message}');
              },
            );
            break;
        }
      },
      position: PopupMenuPosition.under,
      enableFeedback: false,
      itemBuilder: (BuildContext bc) => [
        PopupMenuItem(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          value: '/create',
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.add_box_outlined,
                    color: _colorPalette.iconSecondary, size: 22),
              ),
              Text('Create conversation',
                  style: TextStyle(
                      fontSize: 14, color: _colorPalette.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          value: '/saved',
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.bookmark_border,
                    color: _colorPalette.iconSecondary, size: 22),
              ),
              Text('Saved Messages',
                  style: TextStyle(
                      fontSize: 14, color: _colorPalette.textPrimary)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          enabled: false,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.account_circle_outlined,
                    color: _colorPalette.iconSecondary, size: 22),
              ),
              Text(loggedInUser?.name ?? '',
                  style: TextStyle(
                      fontSize: 14, color: _colorPalette.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          value: '/logout',
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.logout, color: _colorPalette.error, size: 22),
              ),
              Text('Logout',
                  style: TextStyle(fontSize: 14, color: _colorPalette.error)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          enabled: false,
          child: Text('v6.0.0-beta3',
              style:
                  TextStyle(fontSize: 12, color: _colorPalette.textTertiary)),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Opens a conversation. On desktop → middle panel. On mobile → push.
  void _openConversation({User? user, Group? group, int? scrollToMessageId}) {
    if (isDesktopLayout(context)) {
      setState(() {
        _selectedUser = user;
        _selectedGroup = group;
        _selectedMessageId = scrollToMessageId;
        _messagesKey++;
        // Close right panel when switching conversations
        _showRightPanel = false;
        _rightPanelContent = null;
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'messages'),
          builder: (_) => MessagesScreen(
            user: user,
            group: group,
            goToMessageId: scrollToMessageId,
          ),
        ),
      );
    }
  }

  /// Applies a drag on the left handle.
  ///
  /// Clamped twice: against the panel's own min/max, and again so the middle
  /// column keeps [kMiddlePanelMinWidth] — otherwise dragging out on a narrow
  /// window would collapse the message list to nothing.
  void _resizeLeftPanel(double delta, double available, bool rightVisible) {
    final rightTaken = rightVisible ? _rightPanelWidth : 0.0;
    final maxForMiddle = available -
        rightTaken -
        ResponsiveBreakpoints.kMiddlePanelMinWidth -
        _kHandleAllowance;
    final upper = maxForMiddle < ResponsiveBreakpoints.kLeftPanelMinWidth
        ? ResponsiveBreakpoints.kLeftPanelMinWidth
        : (maxForMiddle < ResponsiveBreakpoints.kLeftPanelMaxWidth
            ? maxForMiddle
            : ResponsiveBreakpoints.kLeftPanelMaxWidth);
    final next = (_leftPanelWidth + delta)
        .clamp(ResponsiveBreakpoints.kLeftPanelMinWidth, upper);
    if (next == _leftPanelWidth) return;
    setState(() => _leftPanelWidth = next);
  }

  /// Applies a drag on the right handle. The handle sits on the panel's
  /// LEADING edge, so a rightward drag shrinks it.
  void _resizeRightPanel(double delta, double available) {
    final maxForMiddle = available -
        _leftPanelWidth -
        ResponsiveBreakpoints.kMiddlePanelMinWidth -
        _kHandleAllowance;
    final upper = maxForMiddle < ResponsiveBreakpoints.kRightPanelMinWidth
        ? ResponsiveBreakpoints.kRightPanelMinWidth
        : (maxForMiddle < ResponsiveBreakpoints.kRightPanelMaxWidth
            ? maxForMiddle
            : ResponsiveBreakpoints.kRightPanelMaxWidth);
    final next = (_rightPanelWidth - delta)
        .clamp(ResponsiveBreakpoints.kRightPanelMinWidth, upper);
    if (next == _rightPanelWidth) return;
    setState(() => _rightPanelWidth = next);
  }

  /// Width the two drag handles occupy, excluded from the space the panels
  /// may claim.
  static const double _kHandleAllowance = 16;

  /// Shows the right panel with given content (e.g. a thread, pinned list).
  ///
  /// [title] fills the panel's own header bar — without it the bar renders
  /// blank, since the panel content itself hides its back/title chrome.
  void showRightPanel(Widget content, {String title = ''}) {
    setState(() {
      _showRightPanel = true;
      _rightPanelContent = content;
      _rightPanelTitle = title;
      _rightPanelKey++;
    });
  }

  /// Hides the right panel
  void hideRightPanel() {
    setState(() {
      _showRightPanel = false;
      _rightPanelContent = null;
      _rightPanelTitle = '';
    });
  }

  void _openGroupChat(Group group) {
    if (group.hasJoined) {
      _openConversation(group: group);
      return;
    }

    if (group.type == GroupTypeConstants.password) {
      if (isDesktopLayout(context)) {
        _leftNavKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => JoinProtectedGroupScreen(group: group),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => JoinProtectedGroupScreen(group: group),
          ),
        );
      }
      return;
    }

    if (group.type == GroupTypeConstants.public) {
      _joinPublicGroupAndOpen(group);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text(
        'You are no longer a member of this group. Ask an admin to add you back.',
      ),
      backgroundColor: _colorPalette.error,
    ));
  }

  void _joinPublicGroupAndOpen(Group group) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _colorPalette.white ?? Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('Joining ${group.name}…'),
          ],
        ),
        duration: const Duration(seconds: 10),
      ),
    );

    CometChat.joinGroup(
      group.guid,
      GroupTypeConstants.public,
      onSuccess: (joinedGroup) async {
        if (!mounted) return;
        if (!joinedGroup.hasJoined) joinedGroup.hasJoined = true;
        final user = await CometChat.getLoggedInUser();
        if (user != null) {
          CometChatGroupEvents.ccGroupMemberJoined(user, joinedGroup);
        }
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        _openConversation(group: joinedGroup);
      },
      onError: (CometChatException e) {
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(
          content: Text(e.message ?? 'Unable to join group. Please try again.'),
          backgroundColor: _colorPalette.error,
        ));
      },
    );
  }

  void _openSearch() {
    if (isDesktopLayout(context)) {
      // On desktop, push search within the left panel navigator
      _leftNavKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => CometChatSearch(
            onConversationClicked: (conversation) {
              _leftNavKey.currentState?.pop();
              final user = conversation.conversationType == 'user'
                  ? conversation.conversationWith as User
                  : null;
              final group = conversation.conversationType != 'user'
                  ? conversation.conversationWith as Group
                  : null;

              if (group != null &&
                  !group.hasJoined &&
                  group.type == GroupTypeConstants.password) {
                _leftNavKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (_) => JoinProtectedGroupScreen(group: group),
                  ),
                );
                return;
              }
              _openConversation(user: user, group: group);
            },
            onMessageClicked: (message) {
              _handleSearchMessageClick(message);
            },
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CometChatSearch(
            onConversationClicked: (conversation) {
              Navigator.pop(context);
              final user = conversation.conversationType == 'user'
                  ? conversation.conversationWith as User
                  : null;
              final group = conversation.conversationType != 'user'
                  ? conversation.conversationWith as Group
                  : null;

              if (group != null &&
                  !group.hasJoined &&
                  group.type == GroupTypeConstants.password) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JoinProtectedGroupScreen(group: group),
                  ),
                );
                return;
              }
              _openConversation(user: user, group: group);
            },
            onMessageClicked: (message) {
              _handleSearchMessageClick(message);
            },
          ),
        ),
      );
    }
  }

  void _handleSearchMessageClick(BaseMessage message) {
    // Pop search from left panel on desktop
    if (isDesktopLayout(context)) {
      _leftNavKey.currentState?.pop();
    }

    final sender = message.sender;
    final receiverUid = message.receiverUid;
    final receiverType = message.receiverType;
    final messageId = message.id;

    // Thread reply → open thread
    if (message.parentMessageId > 0) {
      CometChatHelper.getMessageDetails(
        message.parentMessageId,
        onSuccess: (parent) {
          if (parent == null) return;
          User? threadUser;
          Group? threadGroup;
          if (parent.receiverType == ReceiverTypeConstants.user) {
            final loggedInUid = CometChatUIKit.loggedInUser?.uid;
            threadUser = (parent.sender?.uid == loggedInUid)
                ? parent.receiver as User?
                : parent.sender;
          } else {
            threadGroup = parent.receiver as Group?;
          }
          if (isDesktopLayout(context)) {
            // On desktop, open the conversation that contains the thread,
            // then the thread will be accessible from within the messages screen
            if (threadUser != null) {
              _openConversation(user: threadUser, scrollToMessageId: messageId);
            } else if (threadGroup != null) {
              _openConversation(
                  group: threadGroup, scrollToMessageId: messageId);
            }
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ThreadScreen(
                  user: threadUser,
                  group: threadGroup,
                  message: parent,
                  goToMessageId: messageId,
                ),
              ),
            );
          }
        },
        onError: (_) {},
      );
      return;
    }

    if (receiverType == ReceiverTypeConstants.user) {
      final loggedInUid = CometChatUIKit.loggedInUser?.uid;
      final otherUid = (sender?.uid == loggedInUid) ? receiverUid : sender?.uid;
      if (otherUid != null) {
        CometChat.getUser(
          otherUid,
          onSuccess: (user) =>
              _openConversation(user: user, scrollToMessageId: messageId),
          onError: (_) {},
        );
      }
    } else if (receiverType == ReceiverTypeConstants.group) {
      CometChat.getGroup(
        receiverUid,
        onSuccess: (group) =>
            _openConversation(group: group, scrollToMessageId: messageId),
        onError: (_) {},
      );
    }
  }
}

/// Listener for CometChat UI events in ResponsiveHomeScreen
class _ResponsiveHomeUIEventListener with CometChatUIEventListener {
  final void Function(User? user, Group? group) onOpenChat;

  _ResponsiveHomeUIEventListener({required this.onOpenChat});

  @override
  void openChat(User? user, Group? group) {
    onOpenChat(user, group);
  }
}

/// Reports how many routes the left column has pushed above its base tab
/// content, so the panel can hide its own header while a pushed screen is
/// showing one.
///
/// Counts by depth rather than a bool because these screens can stack —
/// Search pushes Join-protected-group on the same navigator.
class _LeftPanelRouteObserver extends NavigatorObserver {
  _LeftPanelRouteObserver({required this.onDepthChanged});

  final void Function(int depth) onDepthChanged;

  int _depth = 0;

  void _emit(int next) {
    if (next == _depth) return;
    _depth = next;
    onDepthChanged(next);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // The base route is the tab content itself and must not count.
    if (previousRoute == null) return;
    _emit(_depth + 1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) return;
    _emit(_depth - 1 < 0 ? 0 : _depth - 1);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) return;
    _emit(_depth - 1 < 0 ? 0 : _depth - 1);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    // Depth is unchanged by a replacement.
  }
}
