---
name: cometchat-flutter-core
description: >
  Use when writing any code that uses cometchat_chat_uikit. Contains hard rules that prevent
  silent failures, crashes, and subtle bugs. Covers CometChatUIKit.init, login, logout,
  UIKitSettings, UIKitSettingsBuilder, listener lifecycle, theme caching,
  subscriptionType, region, muid preservation, and the
  Clean Architecture + BLoC component pattern. Also use when seeing errors like
  "Authentication null", "APP ID null", ERR_ALREADY_LOGGED_IN, or StateError from
  uninitialized ServiceLocator. Make sure to use this skill for any CometChat Flutter
  UIKit code, even simple widget usage.
license: "MIT"
compatibility: "cometchat_chat_uikit ^6.0.0; flutter_bloc ^8.1.0"
allowed-tools: "executeBash, readFile, readCode, fileSearch, listDirectory, grepSearch"
metadata:
  author: "CometChat"
  version: "1.0.0"
  tags: "cometchat flutter core rules init login logout lifecycle"
---

# CometChat Flutter UIKit — Core Rules

Non-negotiable constraints for all CometChat UIKit code. Violating these causes silent failures or crashes.

## Rule: INIT_FIRST

`CometChatUIKit.init()` must complete before any login, component usage, or SDK call.

```dart
// ✅ CORRECT
final settings = (UIKitSettingsBuilder()
      ..appId = 'APP_ID'
      ..region = 'us'
      ..authKey = 'AUTH_KEY'
      ..subscriptionType = CometChatSubscriptionType.allUsers)
    .build();

await CometChatUIKit.init(
  uiKitSettings: settings,
  onSuccess: (_) => debugPrint('Init done'),
  onError: (e) => debugPrint('Init failed: ${e.message}'),
);

// ❌ WRONG — login before init completes
CometChatUIKit.init(uiKitSettings: settings);
CometChatUIKit.login('uid'); // Race condition
```

With `..enableCalls = true`, `init` (and `login`/`loginWithAuthToken`) call `onSuccess`, and complete their futures, only once the Calls SDK is set up too: within about 22 s, and a Calls failure never becomes `onError`. Await init behind a splash screen, not before `runApp`.

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
// ❌ ALSO WRONG — async getLoggedInUser after init (redundant native bridge round-trip)
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

## Rule: LISTENER_LIFECYCLE

SDK listeners MUST be registered with a unique ID in `initState()` and removed with the same ID in `dispose()`. Forgetting removal causes duplicate events and memory leaks.

```dart
// ✅ CORRECT
class _MyScreenState extends State<MyScreen> with MessageListener {
  late final String _listenerId;

  @override
  void initState() {
    super.initState();
    _listenerId = 'my_screen_${DateTime.now().millisecondsSinceEpoch}';
    CometChat.addMessageListener(_listenerId, this);
  }

  @override
  void dispose() {
    CometChat.removeMessageListener(_listenerId);
    super.dispose();
  }
}

// ❌ WRONG — hardcoded ID causes collisions; missing dispose removal
class _MyScreenState extends State<MyScreen> with MessageListener {
  @override
  void initState() {
    super.initState();
    CometChat.addMessageListener('messages', this); // Collision!
  }
  // Missing dispose → listener leaks
}
```

## Rule: THEME_CACHE

Cache theme values in `didChangeDependencies()` with a `_themeInitialized` flag. Never call `CometChatThemeHelper.getColorPalette(context)` in `build()` — during keyboard animation, `MediaQuery` changes trigger rebuilds, and each lookup does expensive InheritedWidget traversal (44-95ms instead of <16ms).

```dart
// ✅ CORRECT — Hybrid pattern
class _MyWidgetState extends State<MyWidget> {
  late CometChatColorPalette _colorPalette;
  late CometChatSpacing _spacing;
  late CometChatTypography _typography;
  bool _themeInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_themeInitialized) {
      _colorPalette = CometChatThemeHelper.getColorPalette(context);
      _spacing = CometChatThemeHelper.getSpacing(context);
      _typography = CometChatThemeHelper.getTypography(context);
      _themeInitialized = true;
    }
  }
}

// ❌ WRONG — lookup in build causes jank
@override
Widget build(BuildContext context) {
  final colors = CometChatThemeHelper.getColorPalette(context); // Expensive!
  return Container(color: colors.primary);
}
```

## Rule: SUBSCRIPTION_TYPE_REQUIRED

Omitting `subscriptionType` in `UIKitSettingsBuilder` silently disables all presence events (online/offline, typing indicators). No error is thrown.

```dart
// ✅ CORRECT
UIKitSettingsBuilder()
  ..subscriptionType = CometChatSubscriptionType.allUsers

// ❌ WRONG — no error, but presence events never fire
UIKitSettingsBuilder()
  ..appId = 'APP_ID'
  ..region = 'us'
```

## Rule: REGION_LOWERCASE

Region must be a lowercase string. The SDK validates against `['us', 'eu', 'in']`.

```dart
// ✅ CORRECT
..region = 'us'

// ❌ WRONG — throws ERR_INVALID_REGION
..region = 'US'
```

## Rule: SERVICE_LOCATOR_INIT

Each component's `ServiceLocator.instance.setup()` must be called before creating its BLoC. The UIKit widgets do this automatically, but if you create BLoCs manually:

```dart
// ✅ CORRECT
ConversationsServiceLocator.instance.setup();
final bloc = ConversationsBloc(
  getLoggedInUserUseCase: ConversationsServiceLocator.instance.getLoggedInUserUseCase,
  // ...
);

// ❌ WRONG — StateError: not initialized
final bloc = ConversationsBloc(
  getLoggedInUserUseCase: ConversationsServiceLocator.instance.getLoggedInUserUseCase,
);
```

## Rule: MUID_PRESERVATION

When sending messages, the SDK may return an empty `muid` in the success callback. The UIKit preserves the original `muid` for pending→sent deduplication. If you handle `ccMessageSent` events, compare by `muid` first, then `id`.

## Pattern: Callback → Async Bridge

The CometChat SDK uses callback-based APIs (`onSuccess`/`onError`). Wrap them with `Completer` for async/await:

```dart
import 'dart:async';

Future<User> loginAsync(String uid) {
  final completer = Completer<User>();
  CometChatUIKit.login(uid,
    onSuccess: (user) => completer.complete(user),
    onError: (e) => completer.completeError(e),
  );
  return completer.future;
}

// Usage
try {
  final user = await loginAsync('user123');
} on CometChatException catch (e) {
  debugPrint('Login failed: ${e.message}');
}
```

This pattern is used internally by the UIKit's repository layer. Use it when calling SDK methods directly outside UIKit components.

## Component Architecture Pattern

Every component follows this structure:

```
{component}/
├── bloc/
│   ├── {component}_bloc.dart      # Extends Bloc<Event, State>, registers SDK listeners
│   ├── {component}_event.dart     # Equatable events
│   └── {component}_state.dart     # Equatable state with copyWith
├── domain/
│   ├── usecases/                  # One class per operation
│   └── repositories/              # Abstract interface
├── data/
│   ├── repositories/              # Impl delegates to datasource
│   └── datasources/               # SDK calls
├── di/
│   └── {component}_service_locator.dart  # Singleton, setup() method
└── widgets/                       # UI, uses BlocConsumer/BlocBuilder
```

## Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Widget | `CometChat{Name}` | `CometChatConversations` |
| BLoC | `{Name}Bloc` | `ConversationsBloc` |
| Event | `{Verb}{Name}` | `LoadConversations`, `MessageReceived` |
| State | `{Name}State` | `ConversationsLoaded`, `MessageListState` |
| Repository | `{Name}Repository` / `{Name}RepositoryImpl` | `ConversationsRepository` |
| Use Case | `{Verb}{Name}UseCase` | `GetConversationsUseCase` |
| Service Locator | `{Name}ServiceLocator` | `ConversationsServiceLocator` |
| Style | `CometChat{Name}Style` | `CometChatConversationsStyle` |

## Checklist — Every CometChat Screen

- [ ] `CometChatUIKit.init()` called before any usage
- [ ] Auth check uses `CometChatUIKit.loggedInUser` after init, not `CometChat.getLoggedInUser()`
- [ ] `subscriptionType` set in UIKitSettingsBuilder
- [ ] `region` is lowercase
- [ ] Theme cached in `didChangeDependencies()`, not `build()`
- [ ] SDK listeners registered with unique ID, removed in `dispose()`
- [ ] Colors from `CometChatThemeHelper`, never hardcoded
- [ ] Strings from `Translations.of(context)`, never hardcoded
