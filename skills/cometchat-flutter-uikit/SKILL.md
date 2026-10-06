---
name: cometchat-flutter-uikit
description: >
  Use when building chat with CometChat Flutter UIKit v6 (cometchat_chat_uikit).
  Triggers on CometChatUIKit, CometChatConversations, CometChatMessageList,
  CometChatMessageComposer, CometChatMessageHeader, CometChatUsers, CometChatGroups,
  UIKitSettings, CometChatThemeHelper, CometChatColorPalette, ConversationsBloc,
  MessageListBloc, CometChatTextBubble, CometChatImageBubble, CometChatMessageBubble,
  CometChatMentionsFormatter, SliverSpacing, ERR_ALREADY_LOGGED_IN, ERR_INVALID_REGION,
  authentication null. Also for adding chat to Flutter, customizing bubbles, theming,
  real-time messages. Use whenever user mentions CometChat or says "chat UI".
license: "MIT"
compatibility: "flutter >=2.5.0; dart >=2.17.0; cometchat_chat_uikit 6.0.0-beta2"
allowed-tools: "executeBash, readFile, readCode, fileSearch, listDirectory, grepSearch"
metadata:
  author: "CometChat"
  version: "1.0.0"
  tags: "cometchat flutter chat uikit messaging conversations bloc clean-architecture"
---

# CometChat Flutter UIKit v6 — Orchestrator

Entry point skill for the `cometchat_chat_uikit` package. Routes to feature skills based on context.

## Project Detection

Confirm the project uses CometChat UIKit by checking `pubspec.yaml` for:
```yaml
dependencies:
  cometchat_chat_uikit:
    hosted: https://dart.cloudsmith.io/cometchat/cometchat/
    version: 6.0.0-beta2
```

If missing, install via:
```bash
dart pub add cometchat_chat_uikit:6.0.0-beta2 --hosted-url https://dart.cloudsmith.io/cometchat/cometchat/
```

Call functionality is built into `cometchat_chat_uikit` — no separate package needed. To use call-specific types, import the calls barrel:
```dart
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart'; // For call types
```

## Skill Routing

| User mentions | Route to skill |
|---------------|---------------|
| init, login, logout, UIKitSettings, setup, credentials, appId, region | `cometchat-flutter-core` |
| theme, colors, dark mode, styling, CometChatColorPalette, CometChatSpacing, typography, Style class | `cometchat-flutter-theming` |
| conversations, conversation list, recent chats, ConversationsBloc | `cometchat-flutter-conversations` |
| messages, message list, composer, header, keyboard, rich text, bubbles, send message | `cometchat-flutter-messages` |
| users, groups, group members, contacts, user list | `cometchat-flutter-users-groups` |
| events, listeners, real-time, typing indicator, online status, receipts, SDK listener | `cometchat-flutter-events` |

## Architecture Overview

The UIKit follows Clean Architecture + BLoC:
```
{component}/
├── bloc/           # BLoC, Events, State (Equatable)
├── domain/         # Use Cases, Repository interfaces
├── data/           # Repository impl, DataSources
├── di/             # ServiceLocator (singleton)
├── widgets/        # UI components
└── {component}.dart # Barrel export
```

All components: conversations, message_list, message_composer, message_header, users, groups, group_members, search, threaded_header, message_information.

## Package Structure

```
chat_uikit/lib/
├── cometchat_chat_uikit.dart    # Main barrel export (chat components)
├── cometchat_calls_uikit.dart   # Calls barrel export
├── chat_ui/src/                 # Chat components (conversations, messages, users, groups, etc.)
├── call_ui/src/                 # Call components (incoming, outgoing, ongoing, call_logs)
└── shared_ui/                   # Shared utilities (theme, events, formatters, models, views)
```

## Rule: AUTH_CHECK_AFTER_INIT

After `CometChatUIKit.init()` completes (in its `onSuccess`), the static field `CometChatUIKit.loggedInUser` is already populated if a cached session exists. Use this synchronous check — do NOT call `CometChat.getLoggedInUser()` separately.

```dart
// ✅ CORRECT — synchronous check after init completes
CometChatUIKit.init(
  uiKitSettings: settings,
  onSuccess: (_) {
    final hasUser = CometChatUIKit.loggedInUser != null;
    // Route to home or login based on hasUser
  },
);

// ❌ WRONG — separate async getLoggedInUser call after init
CometChatUIKit.init(
  uiKitSettings: settings,
  onSuccess: (_) {
    CometChat.getLoggedInUser(
      onSuccess: (user) { ... },  // Unreliable when no session exists
      onError: (e) { ... },
    );
  },
);
```

The `init()` method internally calls `getLoggedInUser()` and sets `CometChatUIKit.loggedInUser` before firing `onSuccess`. Calling it again is redundant and the callback-based version can silently fail when no session exists (the SDK logs "Please log in to CometChat before calling this method" and neither callback fires consistently).

This also applies to `login()` and `loginWithAuthToken()` — all three populate `CometChatUIKit.loggedInUser` before calling `onSuccess`.

```dart
// ❌ ALSO WRONG — async UIKit getLoggedInUser after init (redundant native bridge round-trip)
CometChatUIKit.init(
  uiKitSettings: settings,
  onSuccess: (_) async {
    final user = await CometChatUIKit.getLoggedInUser(); // Unnecessary!
    if (user != null) { ... }
  },
);

// ❌ ALSO WRONG — raw SDK getLoggedInUser (bypasses UIKit, unreliable)
User? existingUser = await CometChat.getLoggedInUser();
```

## Golden Path — Minimal Chat App

```dart
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

// 1. Init (once, at app startup)
final settings = (UIKitSettingsBuilder()
      ..appId = 'YOUR_APP_ID'
      ..region = 'us'
      ..authKey = 'YOUR_AUTH_KEY'
      ..subscriptionType = CometChatSubscriptionType.allUsers)
    .build();
await CometChatUIKit.init(uiKitSettings: settings);

// 2. Login (init may already have restored a session)
if (CometChatUIKit.loggedInUser == null) {
  await CometChatUIKit.loginWithAuthToken('AUTH_TOKEN');
}

// 3. Show conversations
CometChatConversations(
  onItemTap: (conversation) {
    final user = conversation.conversationWith is User
        ? conversation.conversationWith as User : null;
    final group = conversation.conversationWith is Group
        ? conversation.conversationWith as Group : null;
    // Navigate to messages screen
  },
)

// 4. Messages screen
Scaffold(
  appBar: CometChatMessageHeader(
    user: user,
    group: group,
    onBack: () => Navigator.pop(context),
  ),
  body: Column(
    children: [
      Expanded(child: CometChatMessageList(user: user, group: group)),
      CometChatMessageComposer(user: user, group: group),
    ],
  ),
)
```

## Complete App Scaffold (main.dart)

Full working app with init → auth guard → login → home → logout. Copy-paste ready.

```dart
import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

const String appId = 'YOUR_APP_ID';
const String region = 'us';
const String authKey = 'YOUR_AUTH_KEY';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initializing = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _initCometChat();
  }

  void _initCometChat() {
    final settings = (UIKitSettingsBuilder()
          ..appId = appId
          ..region = region
          ..authKey = authKey
          ..subscriptionType = CometChatSubscriptionType.allUsers)
        .build();

    CometChatUIKit.init(
      uiKitSettings: settings,
      onSuccess: (_) {
        // CometChatUIKit.loggedInUser is already set if a cached session exists
        setState(() {
          _loggedIn = CometChatUIKit.loggedInUser != null;
          _initializing = false;
        });
      },
      onError: (e) {
        debugPrint('Init failed: ${e.message}');
        setState(() => _initializing = false);
      },
    );
  }

  void _onLoginSuccess() => setState(() => _loggedIn = true);

  void _onLogout() => setState(() => _loggedIn = false);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: _initializing
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _loggedIn
              ? HomeScreen(onLogout: _onLogout)
              : LoginScreen(onLoginSuccess: _onLoginSuccess),
    );
  }
}

// --- Login Screen ---
class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _uidController = TextEditingController();
  bool _loggingIn = false;
  String? _error;

  void _login() {
    final uid = _uidController.text.trim();
    if (uid.isEmpty) return;
    setState(() { _loggingIn = true; _error = null; });

    CometChatUIKit.login(uid,
      onSuccess: (_) {
        if (mounted) widget.onLoginSuccess();
      },
      onError: (e) {
        if (mounted) setState(() { _loggingIn = false; _error = e.message; });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _uidController,
              decoration: const InputDecoration(labelText: 'User ID'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loggingIn ? null : _login,
              child: _loggingIn
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Home Screen (Conversations → Messages) ---
class HomeScreen extends StatelessWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});

  void _logout(BuildContext context) {
    CometChatUIKit.logout(
      onSuccess: (_) => onLogout(),
      onError: (e) => debugPrint('Logout failed: ${e.message}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context)),
        ],
      ),
      body: CometChatConversations(
        onItemTap: (conversation) {
          final user = conversation.conversationWith is User
              ? conversation.conversationWith as User : null;
          final group = conversation.conversationWith is Group
              ? conversation.conversationWith as Group : null;
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => MessagesScreen(user: user, group: group),
          ));
        },
      ),
    );
  }
}

// --- Messages Screen ---
class MessagesScreen extends StatelessWidget {
  final User? user;
  final Group? group;
  const MessagesScreen({super.key, this.user, this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CometChatMessageHeader(
        user: user,
        group: group,
        onBack: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          Expanded(child: CometChatMessageList(user: user, group: group)),
          CometChatMessageComposer(user: user, group: group),
        ],
      ),
    );
  }
}
```

Key points in this scaffold:
- `CometChatUIKit.loggedInUser` is checked synchronously after `init()` — no separate `getLoggedInUser()` call
- State is managed at the `MyApp` level so login/logout transitions are clean
- `LoginScreen` uses `CometChatUIKit.login(uid)` with auth key (set in UIKitSettings)
- Logout calls `CometChatUIKit.logout()` and resets state

## Top 10 Error Debugging

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Authentication null" | `CometChatUIKit.init()` not called | Call init before login/components |
| "APP ID null" | appId not set in UIKitSettingsBuilder | Set `..appId = 'YOUR_APP_ID'` |
| No typing indicators / presence | `subscriptionType` not set | Set `..subscriptionType = CometChatSubscriptionType.allUsers` |
| Theme jank during keyboard | Theme looked up in `build()` | Cache in `didChangeDependencies()` with `_themeInitialized` flag |
| Listener leak / duplicate events | Listener not removed in `dispose()` | Always remove with same ID used to register |
| "ERR_ALREADY_LOGGED_IN" | Calling login when session exists | Check `CometChatUIKit.getLoggedInUser()` first |
| "ERR_USER_ALREADY_LOGGED_IN" | `loginWithAuthToken` with another token while a user is logged in | Check `CometChatUIKit.loggedInUser` first; `logout()` before switching users |
| Messages not updating in real-time | SDK listener not registered | BLoC registers automatically; check component is mounted |
| Stale user/group data | Passing widget params instead of mutable state | Keep mutable `_user`/`_group` in State, update from listeners |
| Region error | Uppercase region string | Use lowercase: 'us', 'eu', 'in' |
| `Android internal error` on login | SDK internal failure — often auth key issue, beta SDK bug, or network | Verify credentials are correct. Try `CometChat.login(uid, authKey)` directly instead of `CometChatUIKit.login(uid)`. Check CometChat dashboard for UID existence. If using beta SDK, try stable release. |
| Guard screen stuck on spinner | Using `CometChat.getLoggedInUser()` callback API after init | Use `CometChatUIKit.loggedInUser` synchronously after `init()` completes — see AUTH_CHECK_AFTER_INIT rule |
| Release build crash (ClassNotFoundException) | Missing ProGuard keep rules | Add `-keep class com.cometchat.** { *; }` to `proguard-rules.pro` |
| Android build fails (minSdk) | minSdk too low | Set `minSdk = 26` in `android/app/build.gradle` |
| Android build fails (support library) | Missing Jetifier | Add `android.enableJetifier=true` to `gradle.properties` |

## Autonomous Mode

- If `pubspec.yaml` has `cometchat_chat_uikit` → proceed without asking
- If credentials exist in code → reuse them, don't ask
- If user says "messages screen" → generate Scaffold + Header + List + Composer
- Always add `subscriptionType` to UIKitSettingsBuilder
- Always use `CometChatThemeHelper` for colors, never hardcode

## Android Build Requirements

These are required in your Android project or the build/release will fail:

### gradle.properties
```properties
android.useAndroidX=true
android.enableJetifier=true
```
`enableJetifier` resolves old Android Support Library conflicts from transitive dependencies.

### minSdk 26
In `android/app/build.gradle` (or `.kts`):
```kotlin
defaultConfig {
    minSdk = 26  // Required by cometchat_calls_sdk
}
```

### ProGuard / R8 Keep Rules
Create `android/app/proguard-rules.pro`:
```
# CometChat — prevent R8 from stripping SDK classes
-keep class com.cometchat.** { *; }
-keep interface com.cometchat.** { *; }

# Suppress warnings for Calls SDK classes referenced cross-module
-dontwarn com.cometchat.calls.CometChatRTCView$CometChatRTCViewBuilder
-dontwarn com.cometchat.calls.CometChatRTCView
-dontwarn com.cometchat.calls.CometChatRTCViewListener
-dontwarn com.cometchat.calls.model.AnalyticsSettings
-dontwarn com.cometchat.calls.model.RTCCallback
-dontwarn com.cometchat.calls.model.RTCReceiver
```

Reference it in `build.gradle`:
```kotlin
buildTypes {
    release {
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

Without these rules, release builds crash with `ClassNotFoundException` for CometChat classes.
