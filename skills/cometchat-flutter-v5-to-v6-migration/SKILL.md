---
name: cometchat-flutter-v5-to-v6-migration
description: >
  Use when migrating a CometChat Flutter app from UIKit v5 (cometchat_calls_uikit + GetX)
  to UIKit v6 (cometchat_chat_uikit unified package, no GetX). Covers import changes,
  dependency cleanup, GetX removal, init/login pattern changes, navigation rewrites,
  screen structure flattening, notification service updates, and BuilderSettings removal.
  Also use when seeing imports from cometchat_calls_uikit, get/get.dart, or v5-era patterns
  like GetBuilder, Get.put, Get.find, PageManager, BuilderSettings, or CometChatCallingExtension.
license: "MIT"
compatibility: "cometchat_chat_uikit 6.0.0-beta2"
allowed-tools: "executeBash, readFile, readCode, fileSearch, listDirectory, grepSearch"
metadata:
  author: "CometChat"
  version: "1.0.0"
  tags: "cometchat flutter migration v5 v6 getx removal upgrade consumer"
---

# CometChat Flutter — v5 to v6 Migration

Complete guide for migrating a consumer app from UIKit v5 to v6.

## What Changed

| Area | v5 | v6 |
|------|-----|-----|
| Packages | `cometchat_chat_uikit` + `cometchat_calls_uikit` (separate) | `cometchat_chat_uikit` only (calls bundled) |
| State | GetX (`Get.put`, `GetBuilder`, `Obx`, `.obs`, `RxBool`) | Plain `StatefulWidget` + `setState()` |
| Navigation | `PageManager` (GetxController singleton) | Direct `Navigator.push` |
| Init | `InitializeCometChat.init()` + `CometChatCallingExtension()` + `extensions` + `aiFeature` | Inline `CometChatUIKit.init()` + `enableCalls: true` + `CallingConfiguration()` |
| Calls SDK init | `CometChatCallingExtension()` in extensions list | Automatic with `enableCalls: true`: the UI Kit sets the Calls SDK up in `init`/`login` |
| Screens | Separate controller + widget files per screen | Single file, state in StatefulWidget |
| Dashboard | `MyHomePage`/`MyPageView` with GetX `PageManager` | `HomeScreen` with `IndexedStack` |
| Messages | `MessagesSample` + `CometChatMessagesController` | `MessagesScreen` with listener mixins |
| Builder system | `BuilderSettings`, `BuilderColor`, `BuilderTypography` | Removed — use `ComponentToggles` |
| Notifications | `VoipNotificationHandler`, `APNSService` | `VoipCallHandler`, `ApnsService` |
| Extra deps | `get`, `google_sign_in`, `firebase_auth`, `bugsee_flutter`, `shared_preferences`, `toast`, `mobile_scanner`, `app_badge_plus` | None of these |
| Localization | `cc.Translations.delegate` + `GlobalMaterialLocalizations` in MaterialApp | Handled by UIKit internally |
| Call screen | `callMain()` entry point + `CallApp` + `CallScreen` widget | `CallScreenOverlay.show()` (overlay, no separate entry point) |
| Android minSdk | 24 | 26 (required by `cometchat_calls_sdk`) |

## Step 1: pubspec.yaml

```yaml
# ❌ v5
dependencies:
  cometchat_chat_uikit:
    path: ../chat_uikit
  cometchat_calls_uikit:
    path: ../calls_uikit
  get: ^4.6.5
  google_sign_in: ^6.2.2
  firebase_auth: ^5.3.4
  bugsee_flutter: ^8.0.0
  permission_handler: ^11.3.1
  shared_preferences: ^2.2.1
  toast: ^0.3.0
  mobile_scanner: ^7.1.2
  app_badge_plus: ^1.2.6

# ✅ v6
dependencies:
  cometchat_chat_uikit:
    hosted: https://dart.cloudsmith.io/cometchat/cometchat/
    version: 6.0.0-beta2
  firebase_core: ^3.9.0
  firebase_crashlytics: ^4.1.3
  firebase_messaging: ^15.1.6
  flutter_local_notifications: ^18.0.0
  flutter_callkit_incoming: ^2.5.0
  http: ^1.2.0
  intl: ^0.20.2
```

## Step 2: Fix All Imports

| v5 Import | v6 Import |
|-----------|-----------|
| `package:cometchat_calls_uikit/cometchat_calls_uikit.dart` | `package:cometchat_chat_uikit/cometchat_calls_uikit.dart` |
| `package:get/get.dart` | Remove entirely |
| `builder/builder_settings.dart` | Remove — use `ComponentToggles` |
| `builder/builder_settings_helper.dart` | Remove |
| `utils/page_manager.dart` | Remove — use `Navigator.push` |
| `utils/initialize_cometchat.dart` | Remove — inline init |
| `utils/bool_singleton.dart` | Remove |
| `utils/text_constants.dart` | Remove |
| `prefs/shared_preferences.dart` | Remove |

## Step 3: Rewrite Init

```dart
// ❌ v5 — helper class with CometChatCallingExtension + extensions + aiFeature
class InitializeCometChat {
  static Future<bool> init() async {
    final builder = UIKitSettingsBuilder()
      ..callingExtension = CometChatCallingExtension()  // REMOVED in v6
      ..extensions = CometChatUIKitChatExtensions.getDefaultExtensions()  // REMOVED
      ..aiFeature = CometChatUIKitChatAIFeatures.getDefaultAiFeatures();  // REMOVED
    // ...
  }
}

// ✅ v6 — inline, enableCalls + CallingConfiguration replace all three
final settings = (UIKitSettingsBuilder()
      ..subscriptionType = CometChatSubscriptionType.allUsers
      ..region = AppCredentials.region
      ..appId = AppCredentials.appId
      ..authKey = AppCredentials.authKey
      ..enableCalls = true
      ..callingConfiguration = CallingConfiguration())
    .build();

CometChatUIKit.init(uiKitSettings: settings, onSuccess: (_) { ... });
```

### Removed v5 UIKitSettingsBuilder properties
- `callingExtension` → replaced by `enableCalls: true`
- `extensions` → removed (extensions auto-registered in v6)
- `aiFeature` → removed (AI features auto-registered in v6)

### Calls SDK Init for Cached Sessions

```dart
// ❌ v5 — CometChatCallingExtension handled it automatically

// ✅ v6 — with enableCalls, nothing to add. CometChatUIKit.init restores the
// cached session and, before its onSuccess, starts call handling (incoming
// call listener) and initialises and logs the user into the Calls SDK.
// login / loginWithAuthToken do the same for a fresh login, and logout stops
// it and logs the Calls SDK out.
CometChatUIKit.init(
  uiKitSettings: settings, // ..enableCalls = true ..callingConfiguration = ...
  onSuccess: (_) {
    final hasUser = CometChatUIKit.loggedInUser != null;
    // Route to home or login.
  },
);
```

- The Calls set-up is bounded: `onSuccess` (and the returned future) comes within about 22 s even when the Calls SDK is slow or fails, and a Calls failure never becomes `onError` (it is retried when a call needs it). Show a splash rather than holding `runApp` on `await CometChatUIKit.init(...)`.
- Configure the call UI with `UIKitSettings.callingConfiguration`. `CallEventService.instance.init(configuration:)` is deprecated (removal in 7.0.0): its `configuration` is only used when `UIKitSettings.callingConfiguration` is not set. Do not call it with an empty `CallingConfiguration()`.
- Only apps that keep `enableCalls` off and want the incoming call UI call `await CallEventService.instance.init();` themselves, after login.
- `CallEventService.instance.waitForCallsSdk()` returns within 22 s. `CallEventService.instance.reinitializeAfterSession()` is deprecated and no longer needed after a call.

## Step 4: Remove GetX

### PageManager → Navigator.push
```dart
// ❌ v5
Get.put(PageManager());
Get.find<PageManager>().navigateToMessages(context: context, user: user);

// ✅ v6
Navigator.push(context, MaterialPageRoute(
  builder: (_) => MessagesScreen(user: user),
));
```

### GetBuilder → StatefulWidget with listener mixins
```dart
// ❌ v5
GetBuilder<CometChatMessagesController>(
  init: messagesController,
  tag: messagesController.tag,
  builder: (controller) => Scaffold(/* ... */),
)

// ✅ v6
class _MessagesScreenState extends State<MessagesScreen>
    with UserListener, CometChatUserEventListener,
         GroupListener, CometChatGroupEventListener {
  late User? _user;
  late Group? _group;
  // setState() instead of controller.update()
}
```

### Rx variables → plain state
```dart
// ❌ v5
var isBlockLoading = false.obs;
// Usage: isBlockLoading.value = true;

// ✅ v6
bool _isUserBlocked = false;
// Usage: setState(() => _isUserBlocked = true);
```

### Obx dialogs → StatefulBuilder
```dart
// ❌ v5 — Obx in dialog for loading indicator
Obx(() => isLoading.value ? CircularProgressIndicator() : Icon(Icons.check))

// ✅ v6 — StatefulBuilder in dialog
StatefulBuilder(builder: (context, setDialogState) {
  return isLoading ? CircularProgressIndicator() : Icon(Icons.check);
})
```

## Step 5: Removed v5 APIs

These v5 widget parameters/classes don't exist in v6:

| v5 API | Status in v6 |
|--------|-------------|
| `CometChatCompactMessageComposer` | Removed — use `CometChatMessageComposer` |
| `CometChatAIAssistantChatHistory` | Removed |
| `CometChatMessageHeader` `options` param | Removed — use `trailingView` |
| `CometChatMessageList` `messageId` param | Removed — use `goToMessageId` |
| `CometChatMessageList` `hideFlagOption` | Removed |
| `CometChatMessageList` `generateConversationSummary` | Removed |
| `getDataSource()` on message list | Removed |
| `AssetConstants.conversationSummaryOutlined` | Removed |
| `CometChatBannedMembers` (standalone widget) | Not exported in v6 |
| `CometChatCallLogParticipants` (standalone) | Not exported in v6 |
| `CometChatCallLogRecordings` (standalone) | Not exported in v6 |
| `CometChatCallLogHistory` (standalone) | Not exported in v6 |
| `CometChatCallingExtension()` | Replaced by `enableCalls: true` + `CallingConfiguration()` |
| `CometChatUIKitChatExtensions.getDefaultExtensions()` | Removed — auto-registered |
| `CometChatUIKitChatAIFeatures.getDefaultAiFeatures()` | Removed — auto-registered |
| `CallSettingsBuilder` | Replaced by `SessionSettingsBuilder` |
| `FormatPatterns.stripFormatting()` | Removed |
| `CallStateController.instance` | Replaced by `CallStateService.instance` |

### CallSettingsBuilder → SessionSettingsBuilder
```dart
// ❌ v5
CallSettingsBuilder()
  ..enableDefaultLayout = true

// ✅ v6
SessionSettingsBuilder()
  ..setLayout(LayoutType.tile)
  ..startVideoPaused(true)  // for audio calls
  ..hideSwitchCameraButton(true)
  ..hideToggleVideoButton(true)
```

## Step 6: Flatten Screen Structure

```
# ❌ v5 — controller + widget per screen
messages/
├── messages.dart                    # MessagesSample widget
└── messages_controller.dart         # GetxController
group_info/
├── cometchat_group_info.dart
└── cometchat_group_info_controller.dart

# ✅ v6 — single file per screen
screens/
├── messages_screen.dart             # Widget + state + listeners
├── group_info_screen.dart
├── home_screen.dart
└── ...
```

### Class Rename Map

| v5 Class | v6 Class |
|----------|----------|
| `MyHomePage` / `MyPageView` | `HomeScreen` |
| `MessagesSample` | `MessagesScreen` |
| `GuardScreen` | `GuardScreen` (same name, rewritten) |
| `LoginSampleUsers` | `LoginScreen` |

## Step 7: Update MaterialApp

```dart
// ❌ v5 — localization delegates, BuilderTypography, callMain entry point
MaterialApp(
  supportedLocales: const [Locale('en'), Locale('ar'), ...],
  localizationsDelegates: const [
    cc.Translations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: ThemeData(
    fontFamily: BuilderTypography.font,
    extensions: [CometChatColorPalette(primary: BuilderColor.brandColor)],
  ),
  navigatorKey: CallNavigationContext.navigatorKey,
)

// ✅ v6 — Material 3, no builder system, no localization delegates
MaterialApp(
  debugShowCheckedModeBanner: false,
  navigatorKey: LocalNotificationService.navigatorKey,
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
    useMaterial3: true,
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
    useMaterial3: true,
    brightness: Brightness.dark,
  ),
  themeMode: ThemeMode.system,
)
```

Remove the `callMain()` entry point and `CallApp`/`CallScreen` widget entirely — v6 uses `CallScreenOverlay.show()`.

## Step 8: Update Notification Services

| v5 Class | v6 Class |
|----------|----------|
| `VoipNotificationHandler` | `VoipCallHandler` |
| `APNSService` | `ApnsService` |
| `FirebaseService` | `FirebaseService` (same) |

### VoIP Cold Start
```dart
// ❌ v5 — handled in dashboard initState
VoipNotificationHandler.handleNativeCallIntent(context);

// ✅ v6 — init early in main(), markSdkReady after login
VoipCallHandler.instance.init();  // in main()
await VoipCallHandler.instance.markSdkReady();  // after login
```

## Step 9: resizeToAvoidBottomInset

```dart
// ❌ v5 — default true, SafeArea wrapping
Scaffold(body: SafeArea(child: Column(children: [messageList, composer])))

// ✅ v6 — must be false, composer handles keyboard internally
Scaffold(
  resizeToAvoidBottomInset: false,
  body: Column(children: [Expanded(child: messageList), composer]),
)
```

## Step 10: Android Build

In `android/app/build.gradle(.kts)`:
```kotlin
defaultConfig {
    minSdk = 26  // Was 24 in v5, required by cometchat_calls_sdk in v6
}
```

In `android/gradle.properties`:
```properties
android.enableJetifier=true  // Required for support library conflicts
```

## Step 11: Delete v5 Files

- `builder/` folder entirely
- `utils/page_manager.dart`, `initialize_cometchat.dart`, `bool_singleton.dart`, `text_constants.dart`
- `prefs/shared_preferences.dart`
- `services/bugsee_services.dart`
- `qr_scanner/` folder
- `ai_agents/` folder
- `call_screen.dart`
- `demo_meta_info_constants.dart` (recreate minimal if needed)
- All `*_controller.dart` files
- `auth/login_screen.dart` (if it depended on google_sign_in/firebase_auth)

## Gotchas

- `CometChatCallingExtension()`, `extensions`, and `aiFeature` on UIKitSettingsBuilder don't exist in v6. Extensions and AI features are auto-registered. Only `enableCalls: true` + `CallingConfiguration()` is needed.
- `CallSettingsBuilder` is renamed to `SessionSettingsBuilder` with different API: `.setLayout(LayoutType.tile)` instead of `..enableDefaultLayout = true`.
- v6 `CometChatMessageList` doesn't have `messageId` param — use `goToMessageId` instead.
- `CometChatBannedMembers`, `CometChatCallLogParticipants`, `CometChatCallLogRecordings`, `CometChatCallLogHistory` are not exported as standalone widgets in v6.
- The `callMain()` entry point pattern (separate Dart entry point for Android CallActivity) is gone. v6 uses `CallScreenOverlay` which is an overlay on the existing app.
- `FormatPatterns.stripFormatting()` doesn't exist in v6. Use `MarkdownTextFormatter` instead.

## Checklist

- [ ] `pubspec.yaml` — remove `cometchat_calls_uikit`, `get`, and all unused deps
- [ ] All imports — `cometchat_calls_uikit` → `cometchat_chat_uikit/cometchat_calls_uikit.dart`
- [ ] All imports — remove `get/get.dart`
- [ ] Init — remove `CometChatCallingExtension`, `extensions`, `aiFeature`; add `enableCalls` + `CallingConfiguration`
- [ ] Calls — `enableCalls: true` + `callingConfiguration` in UIKitSettings; remove any `CallEventService.instance.init(configuration: ...)` / `CometChatUIKitCalls.init()` calls after login or session restore
- [ ] Remove `PageManager` — replace with `Navigator.push`
- [ ] Remove all `GetBuilder`/`Obx`/`Get.put`/`Get.find`
- [ ] Remove all `*_controller.dart` files
- [ ] Flatten screens into `screens/` folder
- [ ] Remove `BuilderSettings` — replace with `ComponentToggles`
- [ ] Update `MaterialApp` — remove localization delegates, remove `BuilderTypography`
- [ ] Remove `callMain()` entry point and `CallScreen` widget
- [ ] `CallSettingsBuilder` → `SessionSettingsBuilder`
- [ ] `resizeToAvoidBottomInset: false` on all Scaffolds with composer
- [ ] Android `minSdk` = 26
- [ ] Android `enableJetifier = true`
- [ ] Delete all unused v5 files
- [ ] Test: init → login → conversations → messages → calls → logout → re-login
