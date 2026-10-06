import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as cc;
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:http/http.dart' show Client, Request;
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

// Mobile-only imports — guarded by kIsWeb at call sites
import 'package:sample_app/utils/call_error_snackbar.dart';
import 'package:sample_app/utils/call_placement.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  /// A new key gives the Calls tab a new CometChatCallLogs, which loads its
  /// logs again: the custom error view's Retry. A plain setState kept the
  /// same CometChatCallLogs, and so its error, so Retry did nothing.
  Key _callLogsKey = UniqueKey();

  final _toggles = ComponentToggles.instance;
  late CometChatColorPalette _colorPalette;

  // Notification services — platform-specific (mobile only)
  // UI event listener for mention tap → open chat navigation
  final String _uiListenerId =
      'home_screen_ui_${DateTime.now().millisecondsSinceEpoch}';

  static const _tabTitlesMobile = [
    'Chats',
    'Calls',
    'Users',
    'Groups',
    'Notifications'
  ];
  static const _tabTitlesWeb = ['Chats', 'Users', 'Groups', 'Notifications'];
  static List<String> get _tabTitles =>
      kIsWeb ? _tabTitlesWeb : _tabTitlesMobile;

  @override
  void initState() {
    super.initState();

    // Listen for openChat UI events (e.g., mention tap → navigate to user's chat)
    CometChatUIEvents.addUiListener(
        _uiListenerId,
        _HomeScreenUIEventListener(
          onOpenChat: (user, group) {
            if (mounted) {
              _pushMessages(context, user: user, group: group);
            }
          },
          onCardActionClicked: (message, action) {
            if (mounted) {
              _handleCardAction(context, message, action);
            }
          },
        ));

  }

  @override
  Widget build(BuildContext context) {
    _colorPalette = CometChatThemeHelper.getColorPalette(context);
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
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: _colorPalette.background1,
        selectedItemColor: _colorPalette.primary,
        unselectedItemColor: _colorPalette.textSecondary,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined),
            activeIcon: Icon(Icons.chat_rounded),
            label: 'Chats',
          ),
          if (!kIsWeb)
            const BottomNavigationBarItem(
              icon: Icon(Icons.call_outlined),
              activeIcon: Icon(Icons.call_rounded),
              label: 'Calls',
            ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Users',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            activeIcon: Icon(Icons.people_alt_rounded),
            label: 'Groups',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications_rounded),
            label: 'Notifications',
          ),
        ],
      ),
    );
  }

  /// Pin & Save: a saved-messages row tap resolves the message's
  /// conversation and jumps to it (thread replies open their thread screen).
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessagesScreen(
          user: user,
          group: group,
          goToMessageId: message.id,
        ),
      ),
    );
  }

  Widget _buildProfileMenu() {
    final loggedInUser = CometChatUIKit.loggedInUser;
    final typography = CometChatThemeHelper.getTypography(context);
    final spacing = CometChatThemeHelper.getSpacing(context);

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
      icon: Padding(
        padding: EdgeInsets.only(
          left: spacing.padding3 ?? 0,
          right: spacing.padding4 ?? 0,
        ),
        child: CometChatAvatar(
          width: 40,
          height: 40,
          image: loggedInUser?.avatar ?? '',
          name: loggedInUser?.name ?? '',
        ),
      ),
      onSelected: (value) async {
        switch (value) {
          case '/create':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactsScreen()),
            );
            break;
          case '/saved':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    CometChatSavedMessages(onItemTap: _openSavedMessage),
              ),
            );
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.add_box_outlined,
                  color: _colorPalette.iconSecondary,
                  size: 22,
                ),
              ),
              Text(
                'Create conversation',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _colorPalette.textPrimary,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          value: '/saved',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.bookmark_border,
                  color: _colorPalette.iconSecondary,
                  size: 22,
                ),
              ),
              Text(
                'Saved Messages',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _colorPalette.textPrimary,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          enabled: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.account_circle_outlined,
                  color: _colorPalette.iconSecondary,
                  size: 22,
                ),
              ),
              Text(
                loggedInUser?.name ?? '',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _colorPalette.textPrimary,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          value: '/logout',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.logout,
                  color: _colorPalette.error,
                  size: 22,
                ),
              ),
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _colorPalette.error,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          enabled: false,
          child: Text(
            'v6.0.0-beta3',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: _colorPalette.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    // On web: no Calls tab. Indices: 0=Chats, 1=Users, 2=Groups, 3=Notifications
    // On mobile: 0=Chats, 1=Calls, 2=Users, 3=Groups, 4=Notifications
    if (!kIsWeb && _currentIndex == 1) {
      return CometChatCallLogs(
        key: _callLogsKey,
        hideAppbar: true,
        onItemClick: (callLog) => _openCallLogDetails(context, callLog),
        onError: (Exception error) {
          // A call placed from a log row that failed; see
          // call_error_snackbar.dart.
          if (isCallLogsPlacementError(error)) {
            showCallPlacementError(error);
            return;
          }
          final errorMessage =
              error is CometChatException ? error.message : error.toString();
          debugPrint('CallLogs error: $errorMessage');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Call logs error: $errorMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        },
        errorStateView: (context) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: _colorPalette.iconSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load call logs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _colorPalette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please check your connection and try again',
                style: TextStyle(
                  fontSize: 14,
                  color: _colorPalette.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _callLogsKey = UniqueKey());
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colorPalette.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        emptyStateView: (context) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.call_outlined,
                size: 64,
                color: _colorPalette.iconSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'No call logs yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _colorPalette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Make or receive calls to see them here',
                style: TextStyle(
                  fontSize: 14,
                  color: _colorPalette.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Wrap in ValueListenableBuilder so toggle changes rebuild tabs instantly
    // On web: 0=Chats, 1=Users, 2=Groups, 3=Notifications (no Calls offset)
    // On mobile: 0=Chats, 2=Users, 3=Groups, 4=Notifications → subtract 1 for Calls gap
    final int stackIndex;
    if (kIsWeb) {
      stackIndex = _currentIndex; // 0=Chats, 1=Users, 2=Groups, 3=Notifications
    } else {
      stackIndex = _currentIndex == 0 ? 0 : _currentIndex - 1;
    }
    return ValueListenableBuilder<int>(
      valueListenable: _toggles.revision,
      builder: (context, _, __) {
        return IndexedStack(
          index: stackIndex,
          children: [
            _buildConversationsTab(),
            _buildUsersTab(),
            _buildGroupsTab(),
            _buildNotificationsTab(),
          ],
        );
      },
    );
  }

  Widget _buildConversationsTab() {
    return Column(
      children: [
        // Search above the conversation list; the list's own built-in
        // search bar is hidden in favour of this one.
        InboxSearchBar(onTap: () => _openSearch(context)),
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
        _pushMessages(context, user: user, group: group);
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
      onItemTap: (_, user) => _openUserChat(context, user),
      hideSearch: _toggles.usersHideSearch.value,
      stickyHeaderVisibility: _toggles.usersStickyHeader.value,
    );
  }

  Widget _buildGroupsTab() {
    return Stack(
      children: [
        CometChatGroups(
          hideAppbar: true,
          onItemTap: (_, group) => _openGroupChat(context, group),
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

  Widget _buildNotificationsTab() {
    return CometChatNotificationFeed(
      showHeader: false,
      onItemClick: (feedItem) {
        debugPrint('Notification tapped: ${feedItem.id}');
      },
      onActionClick: (feedItem, action) {
        debugPrint(
            'Notification action: ${feedItem.id} → ${action.action.type}');
      },
      onError: (error) {
        debugPrint('NotificationFeed error: $error');
      },
    );
  }

  void _openSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CometChatSearch(
          onConversationClicked: (conversation) {
            Navigator.pop(context);
            _openChat(context, conversation);
          },
          onMessageClicked: (message) {
            // Push messages screen on top of search (don't pop search)
            final sender = message.sender;
            final receiverUid = message.receiverUid;
            final receiverType = message.receiverType;
            final messageId = message.id;

            // Thread reply → fetch parent and open ThreadScreen so the reply
            // isn't injected into the main conversation's message list.
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
                },
                onError: (_) {},
              );
              return;
            }

            if (receiverType == ReceiverTypeConstants.user) {
              final loggedInUid = CometChatUIKit.loggedInUser?.uid;
              final otherUid =
                  (sender?.uid == loggedInUid) ? receiverUid : sender?.uid;
              if (otherUid != null) {
                CometChat.getUser(otherUid,
                    onSuccess: (user) => _pushMessages(context,
                        user: user, scrollToMessageId: messageId),
                    onError: (_) {});
              }
            } else if (receiverType == ReceiverTypeConstants.group) {
              final guid = receiverUid;
              CometChat.getGroup(guid,
                  onSuccess: (group) => _pushMessages(context,
                      group: group, scrollToMessageId: messageId),
                  onError: (_) {});
            }
          },
        ),
      ),
    );
  }

  void _openChat(BuildContext context, Conversation conversation) {
    final user = conversation.conversationType == 'user'
        ? conversation.conversationWith as User
        : null;
    final group = conversation.conversationType != 'user'
        ? conversation.conversationWith as Group
        : null;

    // Protected group that user hasn't joined → show password screen
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

    _pushMessages(context, user: user, group: group);
  }

  void _openCallLogDetails(BuildContext context, CallLog callLog) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallLogDetailsScreen(callLog: callLog),
      ),
    );
  }

  void _openUserChat(BuildContext context, User user) =>
      _pushMessages(context, user: user);

  void _openGroupChat(BuildContext context, Group group) {
    // Already a member → open chat
    if (group.hasJoined) {
      _pushMessages(context, group: group);
      return;
    }

    // Password-protected group → show password prompt
    if (group.type == GroupTypeConstants.password) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JoinProtectedGroupScreen(group: group),
        ),
      );
      return;
    }

    // Public group the user isn't in (e.g., previously kicked) → auto-rejoin
    if (group.type == GroupTypeConstants.public) {
      _joinPublicGroupAndOpen(context, group);
      return;
    }

    // Private group the user isn't in → cannot self-rejoin, needs admin invite
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text(
        'You are no longer a member of this group. Ask an admin to add you back.',
      ),
      backgroundColor: _colorPalette.error,
    ));
  }

  /// Attempts to (re)join a public group on tap and opens the chat on success.
  /// Used when a user taps a public group they're not a member of — for example,
  /// after being kicked (ENG-34445).
  void _joinPublicGroupAndOpen(BuildContext context, Group group) {
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
        _pushMessages(context, group: joinedGroup);
      },
      onError: (CometChatException e) {
        if (!mounted) return;
        debugPrint('Auto-join public group failed: ${e.message}');
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(
          content: Text(
            e.message ?? 'Unable to join group. Please try again.',
          ),
          backgroundColor: _colorPalette.error,
        ));
      },
    );
  }

  void _openAiAssistantScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CometChatUsers(
          title: cc.Translations.of(context).agents,
          usersRequestBuilder: UsersRequestBuilder()
            ..roles = [AIConstants.aiRole],
          onItemTap: (ctx, user) => _pushMessages(ctx, user: user),
        ),
      ),
    );
  }

  void _openNotificationsScreen() {
    // Switch to the Notifications tab
    // Mobile: index 4, Web: index 3
    final notificationsIndex = kIsWeb ? 3 : 4;
    if (mounted) {
      setState(() => _currentIndex = notificationsIndex);
    }
  }

  void _pushMessages(BuildContext context,
      {User? user, Group? group, int? scrollToMessageId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'messages'),
        builder: (_) => MessagesScreen(
            user: user, group: group, goToMessageId: scrollToMessageId),
      ),
    );
  }

  /// Handles card action events from developer cards and agent card blocks.
  /// Dispatches the 9 action types per §2.6 of the design doc.
  void _handleCardAction(
      BuildContext context, BaseMessage message, dynamic action) {
    if (action is! CometChatCardActionEvent) return;

    final cardAction = action.action;

    // Show snackbar for every card action tap
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Card action: ${cardAction.type} (${action.elementId})'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    switch (cardAction) {
      case CometChatCardOpenUrlAction(:final url):
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Open URL: $url'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

      case CometChatCardCopyToClipboardAction(:final value):
        Clipboard.setData(ClipboardData(text: value));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copied to clipboard'),
              duration: Duration(seconds: 2),
            ),
          );
        }

      case CometChatCardDownloadFileAction(:final url):
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download: $url'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

      case CometChatCardSendMessageAction(
          :final text,
          :final receiverUid,
          :final receiverGuid
        ):
        _sendCardMessage(text, receiverUid, receiverGuid);

      case CometChatCardApiCallAction(:final url, :final method):
        _makeApiCall(url, method);

      case CometChatCardChatWithUserAction(:final uid):
        _navigateToChatWithUser(uid);

      case CometChatCardChatWithGroupAction(:final guid):
        _navigateToChatWithGroup(guid);

      case CometChatCardInitiateCallAction(
          :final callType,
          :final uid,
          :final guid
        ):
        _initiateCall(callType, uid, guid);

      case CometChatCardCustomCallbackAction(:final callbackId, :final payload):
        debugPrint('[HomeScreen] customCallback: callbackId=$callbackId, '
            'payload=$payload, messageId=${message.id}');

      case CometChatCardUnknownAction():
        debugPrint('[HomeScreen] Unknown card action: ${cardAction.type}');
    }
  }

  void _sendCardMessage(
      String text, String? receiverUid, String? receiverGuid) {
    if (receiverUid != null && receiverUid.isNotEmpty) {
      final textMessage = TextMessage(
        text: text,
        receiverUid: receiverUid,
        receiverType: ReceiverTypeConstants.user,
        type: MessageTypeConstants.text,
      );
      CometChat.sendMessage(textMessage, onSuccess: (_) {
        debugPrint(
            '[HomeScreen] Card sendMessage success to user: $receiverUid');
      }, onError: (e) {
        debugPrint('[HomeScreen] Card sendMessage error: ${e.message}');
      });
    } else if (receiverGuid != null && receiverGuid.isNotEmpty) {
      final textMessage = TextMessage(
        text: text,
        receiverUid: receiverGuid,
        receiverType: ReceiverTypeConstants.group,
        type: MessageTypeConstants.text,
      );
      CometChat.sendMessage(textMessage, onSuccess: (_) {
        debugPrint(
            '[HomeScreen] Card sendMessage success to group: $receiverGuid');
      }, onError: (e) {
        debugPrint('[HomeScreen] Card sendMessage error: ${e.message}');
      });
    }
  }

  Future<void> _makeApiCall(String url, String? method) async {
    try {
      final uri = Uri.parse(url);
      final httpMethod = (method ?? 'GET').toUpperCase();
      debugPrint('[HomeScreen] Card apiCall: $httpMethod $url');
      // Basic implementation — apps can extend with headers/body as needed
      final request = Request(httpMethod, uri);
      final client = Client();
      await client.send(request);
      client.close();
    } catch (e) {
      debugPrint('[HomeScreen] Card apiCall error: $e');
    }
  }

  void _navigateToChatWithUser(String uid) {
    CometChat.getUser(uid, onSuccess: (user) {
      if (mounted) {
        _pushMessages(context, user: user);
      }
    }, onError: (e) {
      debugPrint('[HomeScreen] Card chatWithUser error: ${e.message}');
    });
  }

  void _navigateToChatWithGroup(String guid) {
    CometChat.getGroup(guid, onSuccess: (group) {
      if (mounted) {
        _pushMessages(context, group: group);
      }
    }, onError: (e) {
      debugPrint('[HomeScreen] Card chatWithGroup error: ${e.message}');
    });
  }

  /// A card's "initiate call" action. A call to a user goes through the UI
  /// Kit, as the chat header's call buttons do: the same checks, outgoing
  /// screen and configuration, and errors as SnackBars. It used to call
  /// CometChat.initiateCall directly, so the callee rang while the caller
  /// had nothing on screen to end the call with.
  void _initiateCall(String callType, String? uid, String? guid) {
    if (uid == null || uid.isEmpty) {
      // A group call is a meeting, which a card does not start here.
      if (guid != null && guid.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Group calls from cards aren't supported here."),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    CometChat.getUser(
      uid,
      onSuccess: (user) {
        if (!mounted) return;
        _placeCardCall(user, isVideo: callType == 'video');
      },
      onError: showCallPlacementError,
    );
  }

  /// Places a call to [user] with a CallButtonsBloc of its own, kept until
  /// the placement is done (the outgoing screen is up, or the call was
  /// refused) and closed then: closed at once, it would stop before the
  /// call was placed. See [closeWhenPlaced].
  void _placeCardCall(User user, {required bool isVideo}) {
    final calling = CometChatUIKit.authenticationSettings?.callingConfiguration;
    final bloc = CallButtonsBloc(
      user: user,
      outgoingCallConfiguration:
          calling?.callButtonsConfiguration?.outgoingCallConfiguration ??
              calling?.outgoingCallConfiguration,
      errorCallback: showCallButtonsError,
    );
    unawaited(closeWhenPlaced(bloc.stream, bloc.close));
    bloc.add(isVideo ? const InitiateVideoCall() : const InitiateVoiceCall());
  }

  @override
  void dispose() {
    CometChatUIEvents.removeUiListener(_uiListenerId);
    super.dispose();
  }
}

/// Listener for CometChat UI events in HomeScreen
class _HomeScreenUIEventListener with CometChatUIEventListener {
  final void Function(User? user, Group? group) onOpenChat;
  final void Function(BaseMessage message, dynamic action)? onCardActionClicked;

  _HomeScreenUIEventListener({
    required this.onOpenChat,
    this.onCardActionClicked,
  });

  @override
  void openChat(User? user, Group? group) {
    onOpenChat(user, group);
  }

  @override
  void ccCardActionClicked(BaseMessage message, dynamic action) {
    onCardActionClicked?.call(message, action);
  }
}
