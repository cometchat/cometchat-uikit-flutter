---
name: cometchat-flutter-placement
description: >
  Use when deciding WHERE to put CometChat in a Flutter app. Covers placement patterns:
  tab-based home (IndexedStack), Navigator.push messages screen, modal/bottom sheet chat,
  thread overlay, embedded panel, and floating widget. Includes Scaffold configuration,
  SafeArea, and keyboard-aware spacing patterns.
  Triggers on "add chat to my app", "where to put chat", "messages screen layout",
  "tab bar with chat", "chat in modal", "chat in drawer", "embedded chat",
  "Scaffold layout", or "keyboard handling".
license: "MIT"
compatibility: "cometchat_chat_uikit ^6.0.0; flutter >=2.5.0"
allowed-tools: "executeBash, readFile, readCode, fileSearch, listDirectory, grepSearch"
metadata:
  author: "CometChat"
  version: "1.0.0"
  tags: "cometchat flutter placement route modal drawer tabs scaffold keyboard layout"
---

# CometChat Flutter UIKit — Placement

WHERE to put CometChat in your Flutter app. Five patterns, each with complete code.

**Before using this skill:**
- Read `cometchat-flutter-core` for init, login, and rules
- Read `cometchat-flutter-components` for component names and props (when available)

---

## Placement Recommendation

| User intent | Recommended pattern | Components |
|-------------|-------------------|------------|
| Messaging app | Tab-based home (full screen) | IndexedStack + CometChatConversations + Messages screen |
| Marketplace / platform | Navigator.push from product page | Single-thread messages screen |
| SaaS / dashboard | Modal or bottom sheet | CometChatConversations in BottomSheet |
| Social / community | Tab-based home with calls | IndexedStack + Conversations + CallLogs + Users + Groups |
| Support / helpdesk | Floating action button → modal | FAB + showModalBottomSheet |
| Just exploring | Replace home page | CometChatConversations as Scaffold body |

---

## Pattern 1: Tab-Based Home (Most Common)

BottomNavigationBar with IndexedStack to preserve tab state. This is what master_app uses.

```dart
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: Conversations
          CometChatConversations(
            hideAppbar: true,
            onItemTap: (conversation) => _openChat(context, conversation),
          ),
          // Tab 1: Call Logs
          CometChatCallLogs(hideAppbar: true),
          // Tab 2: Users
          CometChatUsers(
            hideAppbar: true,
            onItemTap: (_, user) => _pushMessages(context, user: user),
          ),
          // Tab 3: Groups
          CometChatGroups(
            hideAppbar: true,
            onItemTap: (_, group) => _pushMessages(context, group: group),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_outlined), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.call_outlined), label: 'Calls'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Groups'),
        ],
      ),
    );
  }

  void _openChat(BuildContext context, Conversation conversation) {
    final user = conversation.conversationWith is User
        ? conversation.conversationWith as User : null;
    final group = conversation.conversationWith is Group
        ? conversation.conversationWith as Group : null;
    _pushMessages(context, user: user, group: group);
  }

  void _pushMessages(BuildContext context, {User? user, Group? group}) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MessagesScreen(user: user, group: group),
    ));
  }
}
```

**Key details:**
- `IndexedStack` keeps all tabs alive — no re-fetch when switching tabs
- `hideAppbar: true` on all components — the parent Scaffold provides the AppBar
- `onItemTap` extracts `User`/`Group` from `conversation.conversationWith`
- Protected groups need a join/password screen before navigating to messages

---

## Pattern 2: Messages Screen (Navigator.push)

The standard messages screen pushed from any conversation/user/group tap.

```dart
class MessagesScreen extends StatefulWidget {
  final User? user;
  final Group? group;
  const MessagesScreen({super.key, this.user, this.group})
      : assert(user != null || group != null);
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late User? _user;
  late Group? _group;

  @override
  void initState() {
    super.initState();
    _user = widget.user;   // Mutable copy — updated by SDK listeners
    _group = widget.group;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CometChatMessageHeader(
        user: _user,
        group: _group,
        onBack: () => Navigator.pop(context),
      ),
      body: SafeArea(
        bottom: false, // Scaffold handles keyboard inset
        child: Column(
          children: [
            Expanded(child: CometChatMessageList(user: _user, group: _group)),
            CometChatMessageComposer(user: _user, group: _group),
          ],
        ),
      ),
    );
  }
}
```

### Critical Scaffold Rules

1. `SafeArea(bottom: false)` — The Scaffold's `resizeToAvoidBottomInset` (default `true`) handles the bottom keyboard inset for you, so don't re-apply bottom safe area.
2. Mutable `_user`/`_group` — Keep mutable copies in State, not `widget.user`/`widget.group`. Update from SDK listeners for block/kick/scope changes.

---

## Pattern 3: Thread Screen

Thread replies pushed from `onThreadRepliesClick`. Same Scaffold rules apply.

```dart
class ThreadScreen extends StatelessWidget {
  final User? user;
  final Group? group;
  final BaseMessage message;
  final CometChatMessageTemplate? template;

  const ThreadScreen({
    super.key, this.user, this.group,
    required this.message, this.template,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CometChatMessageHeader(
        user: user, group: group,
        onBack: () => Navigator.pop(context),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CometChatThreadedHeader(
              parentMessage: message,
              loggedInUser: CometChatUIKit.loggedInUser!,
              template: template,
            ),
            Expanded(
              child: CometChatMessageList(
                user: user, group: group,
                parentMessageId: message.id,
                hideReplyInThreadOption: true,
              ),
            ),
            CometChatMessageComposer(
              user: user, group: group,
              parentMessageId: message.id,
            ),
          ],
        ),
      ),
    );
  }
}
```

Wire it from the messages screen:
```dart
CometChatMessageList(
  onThreadRepliesClick: (message, ctx, {template}) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ThreadScreen(
        user: _user, group: _group,
        message: message, template: template,
      ),
    ));
  },
)
```

---

## Pattern 4: Modal / Bottom Sheet Chat

Quick chat access from any screen without full navigation.

```dart
void _openChatModal(BuildContext context, User user) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Scaffold(
        appBar: CometChatMessageHeader(
          user: user,
          onBack: () => Navigator.pop(context),
        ),
        body: Column(
          children: [
            Expanded(child: CometChatMessageList(user: user)),
            CometChatMessageComposer(user: user),
          ],
        ),
      ),
    ),
  );
}
```

**Key details:**
- `isScrollControlled: true` — allows the sheet to be taller than half screen
- `useSafeArea: true` — respects notch/status bar
- Use `MediaQuery.sizeOf(context)` not `MediaQuery.of(context).size`

---

## Pattern 5: Embedded Panel

Chat embedded alongside other content (e.g., split view on tablets).

```dart
class SplitView extends StatelessWidget {
  final User user;
  const SplitView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left: your app content
          Expanded(flex: 3, child: YourProductPage()),
          // Right: embedded chat
          Expanded(
            flex: 2,
            child: Column(
              children: [
                CometChatMessageHeader(user: user),
                Expanded(child: CometChatMessageList(user: user)),
                CometChatMessageComposer(user: user),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Pattern 6: Floating Action Button → Chat

```dart
Scaffold(
  body: YourMainContent(),
  floatingActionButton: FloatingActionButton(
    onPressed: () => _openChatModal(context, supportUser),
    child: const Icon(Icons.chat),
  ),
)
```

---

## Incoming Calls — Global Placement

Incoming call handling MUST be at the app root level, not per-screen. With `UIKitSettings.enableCalls` the UI Kit listens for calls itself and shows its banner over the navigator of `CallNavigationContext.navigatorKey`: give that key to the root `MaterialApp`, and every screen rings.

```dart
// UIKitSettings: ..enableCalls = true (and a callingConfiguration)
MaterialApp(
  navigatorKey: CallNavigationContext.navigatorKey,
  home: const HomeScreen(),
)
```

Calls that arrive while the app is in the background or killed come by push (FCM, or VoIP push and CallKit on iOS): that is your app's code, as in the sample app, not a UI Kit class.

---

## Anti-Patterns

```dart
// ❌ WRONG — passing widget.user directly (stale after block/kick)
CometChatMessageList(user: widget.user)

// ❌ WRONG — incoming call handler only on messages screen
// Calls ring on ALL screens, not just the one with call buttons

// ❌ WRONG — navigating to messages without extracting user/group
onItemTap: (conv) => Navigator.push(context, MaterialPageRoute(
  builder: (_) => MessagesScreen(conversation: conv), // Wrong!
))

// ✅ CORRECT — extract user/group from conversation
onItemTap: (conv) {
  final user = conv.conversationWith is User ? conv.conversationWith as User : null;
  final group = conv.conversationWith is Group ? conv.conversationWith as Group : null;
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => MessagesScreen(user: user, group: group),
  ));
}
```

---

## Checklist

- [ ] `SafeArea(bottom: false)` when using composer (Scaffold handles bottom inset)
- [ ] Mutable `_user`/`_group` state copies, not `widget.user`/`widget.group`
- [ ] `onItemTap` extracts `User`/`Group` from `conversation.conversationWith`
- [ ] Protected groups handled (check `group.hasJoined` and `group.type`)
- [ ] Incoming call handler mounted at app root level
- [ ] `hideAppbar: true` when parent provides its own AppBar
- [ ] `IndexedStack` used for tab-based home (preserves tab state)
