---
name: cometchat-flutter-troubleshooting
description: >
  Diagnose and fix CometChat Flutter UIKit v6 integration problems. Covers init
  failures, login errors, UI rendering issues, keyboard problems, call failures,
  listener leaks, theme jank, and platform-specific build errors. Use when seeing
  errors, crashes, or unexpected behavior with CometChat components.
license: "MIT"
compatibility: "cometchat_chat_uikit ^6.0.0"
allowed-tools: "executeBash, readFile, readCode, fileSearch, listDirectory, grepSearch"
metadata:
  author: "CometChat"
  version: "1.0.0"
  tags: "cometchat flutter troubleshooting errors debugging crashes fixes"
---

# CometChat Flutter UIKit v6 — Troubleshooting Guide

Comprehensive guide for diagnosing and fixing CometChat Flutter UIKit v6 integration problems.

---

## 1. Quick Diagnosis Flow

Use this decision tree to jump to the right section:

```
What's happening?
│
├─ App crashes or errors on startup
│  └─ Go to → Section 2: Init & Login Errors
│
├─ UI looks wrong, layout broken, keyboard issues
│  └─ Go to → Section 3: UI Rendering Issues
│
├─ Calls not working, call screen blank or stuck
│  └─ Go to → Section 4: Call Issues
│
├─ Events not firing, duplicate events, memory leaks
│  └─ Go to → Section 5: Listener Issues
│
├─ Build fails on Android or iOS
│  └─ Go to → Section 6: Build Errors
│
├─ App is slow, janky scrolling, laggy keyboard
│  └─ Go to → Section 7: Performance Issues
│
└─ Platform-specific weirdness (Android/iOS/Web)
   └─ Go to → Section 8: Platform-Specific Issues
```

---

## 2. Init & Login Errors

### 2.1 "Authentication null"

- **Symptom**: Error message `Authentication null` or `Please log in to CometChat before calling this method` when using any CometChat component or SDK call.
- **Cause**: `CometChatUIKit.init()` was not called, or was called but not awaited before using components or calling login.
- **Fix**: Ensure `init()` completes before any other CometChat usage:

```dart
// ✅ CORRECT — await init before anything else
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

// ❌ WRONG — login before init completes (race condition)
CometChatUIKit.init(uiKitSettings: settings);
CometChatUIKit.login('uid');
```

### 2.2 "APP ID null"

- **Symptom**: Error `APP ID null` or `appId is required` during init.
- **Cause**: `appId` not set in `UIKitSettingsBuilder`.
- **Fix**: Set `appId` before calling `.build()`:

```dart
final settings = (UIKitSettingsBuilder()
      ..appId = 'YOUR_APP_ID'  // ← Must be set
      ..region = 'us'
      ..authKey = 'YOUR_AUTH_KEY')
    .build();
```

### 2.3 ERR_ALREADY_LOGGED_IN

- **Symptom**: Error `ERR_ALREADY_LOGGED_IN` when calling `CometChatUIKit.login()`.
- **Cause**: Calling login when a session already exists. After `init()`, the SDK restores cached sessions automatically.
- **Fix**: Check `CometChatUIKit.loggedInUser` after init before calling login:

```dart
CometChatUIKit.init(
  uiKitSettings: settings,
  onSuccess: (_) {
    if (CometChatUIKit.loggedInUser != null) {
      // Already logged in — skip login, go to home
      navigateToHome();
    } else {
      // No session — show login screen
      navigateToLogin();
    }
  },
);
```

`CometChatUIKit.loginWithAuthToken` does not use this code. With a user already logged in it calls `onSuccess` only for the auth token the SDK already holds; any other token gets `onError` with `ERR_USER_ALREADY_LOGGED_IN` (and a null return). Same fix: check `CometChatUIKit.loggedInUser` first, and `CometChatUIKit.logout()` before logging in as another user.

### 2.4 "Android internal error" on login

- **Symptom**: Login fails with a vague `Android internal error` message.
- **Cause**: Multiple possible causes — incorrect auth key, UID doesn't exist in CometChat dashboard, beta SDK bug, or network issue.
- **Fix**:
  1. Verify credentials are correct in the CometChat dashboard
  2. Verify the UID exists in the dashboard
  3. Try calling `CometChat.login(uid, authKey)` directly to isolate UIKit vs SDK issue
  4. If using beta SDK, try the stable release
  5. Check network connectivity and firewall rules

### 2.5 Guard screen stuck on spinner

- **Symptom**: App shows a loading spinner forever after init. The auth guard never resolves.
- **Cause**: Using the callback-based `CometChat.getLoggedInUser()` after init instead of the synchronous `CometChatUIKit.loggedInUser`. The callback API silently fails when no session exists — neither `onSuccess` nor `onError` fires.
- **Fix**: Use the synchronous check after init:

```dart
// ✅ CORRECT — synchronous check, always resolves
CometChatUIKit.init(
  uiKitSettings: settings,
  onSuccess: (_) {
    final hasUser = CometChatUIKit.loggedInUser != null;
    setState(() {
      _loggedIn = hasUser;
      _initializing = false;
    });
  },
);

// ❌ WRONG — callback may never fire when no session exists
CometChatUIKit.init(
  uiKitSettings: settings,
  onSuccess: (_) {
    CometChat.getLoggedInUser(
      onSuccess: (user) { /* may never fire */ },
      onError: (e) { /* may never fire */ },
    );
  },
);

// ❌ ALSO WRONG — redundant native bridge round-trip
CometChatUIKit.init(
  uiKitSettings: settings,
  onSuccess: (_) async {
    final user = await CometChatUIKit.getLoggedInUser(); // Unnecessary!
  },
);
```

### 2.6 Region error (ERR_INVALID_REGION)

- **Symptom**: Init fails with `ERR_INVALID_REGION`.
- **Cause**: Region string is uppercase or not one of the valid values.
- **Fix**: Use lowercase region string — valid values are `'us'`, `'eu'`, `'in'`:

```dart
// ✅ CORRECT
..region = 'us'

// ❌ WRONG
..region = 'US'
..region = 'United States'
```

### 2.7 StateError from uninitialized ServiceLocator

- **Symptom**: `StateError: not initialized` when creating a BLoC manually.
- **Cause**: Component's `ServiceLocator.instance.setup()` was not called before creating the BLoC. UIKit widgets do this automatically, but manual BLoC creation requires it.
- **Fix**: Call setup before creating the BLoC:

```dart
// ✅ CORRECT
ConversationsServiceLocator.instance.setup();
final bloc = ConversationsBloc(
  getLoggedInUserUseCase: ConversationsServiceLocator.instance.getLoggedInUserUseCase,
);

// ❌ WRONG — setup not called
final bloc = ConversationsBloc(
  getLoggedInUserUseCase: ConversationsServiceLocator.instance.getLoggedInUserUseCase,
);
```

---

## 3. UI Rendering Issues

### 3.1 Double keyboard compensation (layout jumps)

- **Symptom**: When the keyboard opens, the message list jumps or there's extra white space. Content shifts twice — once from Flutter's Scaffold resize, once from the composer's internal keyboard handling.
- **Cause**: The `Scaffold` containing `CometChatMessageComposer` has `resizeToAvoidBottomInset` set to `true` (the default). The composer handles keyboard spacing internally via `SliverSpacing`. Both systems react to the keyboard, causing double-compensation.
- **Fix**: Set `resizeToAvoidBottomInset: false` on any Scaffold containing the composer:

```dart
// ✅ CORRECT
Scaffold(
  resizeToAvoidBottomInset: false, // REQUIRED
  body: Column(
    children: [
      Expanded(child: CometChatMessageList(user: user)),
      CometChatMessageComposer(user: user),
    ],
  ),
)

// ❌ WRONG — default is true, causes double keyboard compensation
Scaffold(
  body: Column(
    children: [
      Expanded(child: CometChatMessageList(user: user)),
      CometChatMessageComposer(user: user),
    ],
  ),
)
```

This applies everywhere the composer is used: messages screen, thread screen, or any custom screen.

### 3.2 Stale user/group data

- **Symptom**: User name, avatar, or group info doesn't update in real-time. Old data persists even after changes.
- **Cause**: Passing `widget.user` or `widget.group` directly to UIKit components instead of maintaining mutable state that updates from listeners.
- **Fix**: Keep mutable `_user`/`_group` in your State class and update from SDK listeners:

```dart
class _MessagesScreenState extends State<MessagesScreen> {
  late User? _user;
  late Group? _group;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _group = widget.group;
    // Register listeners to update _user/_group on changes
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Expanded(child: CometChatMessageList(user: _user, group: _group)),
          CometChatMessageComposer(user: _user, group: _group),
        ],
      ),
    );
  }
}
```

### 3.3 No typing indicators / presence events

- **Symptom**: Online/offline status never updates. Typing indicators don't appear. No presence events fire. No error is thrown.
- **Cause**: `subscriptionType` was not set in `UIKitSettingsBuilder`. Omitting it silently disables all presence events.
- **Fix**: Always set `subscriptionType`:

```dart
// ✅ CORRECT
UIKitSettingsBuilder()
  ..appId = 'APP_ID'
  ..region = 'us'
  ..authKey = 'AUTH_KEY'
  ..subscriptionType = CometChatSubscriptionType.allUsers

// ❌ WRONG — no error, but presence events never fire
UIKitSettingsBuilder()
  ..appId = 'APP_ID'
  ..region = 'us'
  ..authKey = 'AUTH_KEY'
  // subscriptionType missing!
```

### 3.4 Messages not updating in real-time

- **Symptom**: New messages don't appear until the screen is refreshed or re-opened.
- **Cause**: Multiple possible causes:
  1. SDK message listener not registered (BLoC handles this automatically — check component is mounted)
  2. `subscriptionType` not set (see 3.3)
  3. Component was disposed and listener removed
- **Fix**:
  1. Ensure `subscriptionType` is set in UIKitSettings
  2. Verify the `CometChatMessageList` widget is mounted and not disposed
  3. If using custom BLoC, ensure it registers `CometChat.addMessageListener()` in its constructor and removes it in `close()`

### 3.5 Theme jank during keyboard animation

- **Symptom**: Visible jank (stuttering, dropped frames) when the keyboard opens or closes, especially on message screens.
- **Cause**: Theme values (`CometChatThemeHelper.getColorPalette(context)`, etc.) are being looked up inside `build()`. During keyboard animation, `MediaQuery` changes trigger rebuilds, and each lookup does expensive InheritedWidget traversal (44–95ms instead of <16ms).
- **Fix**: Cache theme values in `didChangeDependencies()` with a `_themeInitialized` flag:

```dart
// ✅ CORRECT — cache once, reuse on every build
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

  @override
  Widget build(BuildContext context) {
    // Use _colorPalette, _spacing, _typography — no lookups here
    return Container(color: _colorPalette.primary);
  }
}

// ❌ WRONG — lookup in build causes jank during keyboard animation
@override
Widget build(BuildContext context) {
  final colors = CometChatThemeHelper.getColorPalette(context); // Expensive!
  return Container(color: colors.primary);
}
```

### 3.6 Extra white space between composer and keyboard

- **Symptom**: Visible gap between the message composer and the keyboard when it opens.
- **Cause**: Safe area bottom padding being applied when the keyboard is open. The keyboard already covers the safe area, so adding safe area padding on top creates extra space.
- **Fix**: Always use `MediaQuery.paddingOf(context).bottom` for safe area (set once in `didChangeDependencies()`). Never overwrite it with native plugin values. The `SliverSpacing` widget handles this automatically — ensure you're not adding extra `SafeArea` wrappers around the composer.

---

## 4. Call Issues

### 4.1 "auth token null" on call init

- **Symptom**: Calls SDK fails with `auth token null` or similar authentication error when trying to start a call.
- **Cause**: The Calls SDK was initialized before the Chat SDK completed init and login. The Calls SDK needs the auth token from a successful chat login.
- **Fix**: Ensure `CometChatUIKit.init()` and login complete before any calls-related initialization. The UIKit handles this order internally — if you're initializing calls manually, ensure the chat session is established first.

### 4.2 "session already started"

- **Symptom**: Error `session already started` when trying to join or start a call.
- **Cause**: A previous call session was not properly ended. This can happen if the user navigated away from the call screen without ending the call, or if the app was killed during a call.
- **Fix**: Ensure call sessions are properly ended when leaving call screens. If the error persists, call `CometChat.endCall()` or `CometChat.rejectCall()` to clean up the stale session before starting a new one.

### 4.3 "CallManager not found" / "Calling module not found"

- **Symptom**: Android native error `CallManager not found` or `CometChat Calling module not found`.
- **Cause**: The CometChat Calling native module is not properly linked on Android. This can happen with ProGuard stripping, missing dependencies, or build configuration issues.
- **Fix**:
  1. Ensure ProGuard keep rules are in place (see Section 6.1)
  2. Verify `cometchat_chat_uikit` is properly added to `pubspec.yaml`
  3. Run `flutter clean` and rebuild
  4. Check that `android.enableJetifier=true` is in `gradle.properties`

### 4.4 "startSession null" on Android

- **Symptom**: `startSession` returns null on Android with no error feedback. The call screen may appear blank or stuck.
- **Cause**: Known Android SDK issue where `startSession` silently fails. A 5-second timeout workaround exists but provides no error feedback.
- **Fix**: This is a known SDK-level issue. Workarounds:
  1. Implement a timeout wrapper around `startSession` calls
  2. Show a retry option to the user if the call screen doesn't load within 5 seconds
  3. Check for updates to `cometchat_calls_sdk` that may fix this

### 4.5 Incoming call not received

- **Symptom**: Incoming calls are not shown to the receiver. The caller sees the outgoing call screen but the receiver gets nothing.
- **Cause**: Multiple possible causes:
  1. `subscriptionType` not set (presence/events disabled)
  2. Push notification / VoIP setup incomplete
  3. Call listeners not registered (`UIKitSettings.enableCalls` off, and no `CallEventService.instance.init()` of your own)
  4. `CallNavigationContext.navigatorKey` is not the root `MaterialApp`'s `navigatorKey`: the banner has nowhere to show (`onError` gets `NO_NAVIGATOR`)
  5. App is in background without proper background handling. On iOS the in-app banner is not shown at all while the app is not in the foreground: background calls are VoIP push / CallKit's
- **Fix**:
  1. Ensure `subscriptionType` is set to `CometChatSubscriptionType.allUsers`
  2. Verify FCM/APNs push notification setup for background calls
  3. Turn on `UIKitSettings.enableCalls` (the UI Kit registers the call listeners at login)
  4. `MaterialApp(navigatorKey: CallNavigationContext.navigatorKey, ...)`
  5. For cross-platform issues (Android↔iOS↔React), verify all platforms are on compatible SDK versions

### 4.6 Calls don't work after logout and re-login

- **Symptom**: After logout and re-login, calls don't work. Call screens may be blank or throw errors.
- **Cause**: Usually a second Calls SDK init or login of the app's own racing the UI Kit's, or a logout that bypassed the UI Kit (`CometChat.logout()` directly).
- **Fix**: Do not re-initialise the Calls SDK yourself. With `UIKitSettings.enableCalls`, `CometChatUIKit.logout()` logs the Calls SDK out and the next `login` logs it in again; nothing else is needed (`CallEventService.reinitializeAfterSession()` is deprecated). To wait for it (a push handler, say), `await CallEventService.instance.waitForCallsSdk()`.

---

## 5. Listener Issues

### 5.1 Duplicate events (hardcoded listener IDs)

- **Symptom**: Event handlers fire multiple times for a single event. Messages appear twice, typing indicators flicker.
- **Cause**: Listener registered with a hardcoded ID. When the widget is recreated (e.g., navigation), the new listener overwrites the old one but the old widget's handler may still be referenced, or multiple instances collide.
- **Fix**: Use a unique listener ID per widget instance:

```dart
// ✅ CORRECT — unique ID per instance
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

// ❌ WRONG — hardcoded ID causes collisions across instances
CometChat.addMessageListener('messages', this); // Collision!
```

### 5.2 Listener leaks (missing dispose)

- **Symptom**: Memory usage grows over time. Events fire on screens that are no longer visible. App becomes sluggish.
- **Cause**: SDK listeners registered in `initState()` but not removed in `dispose()`.
- **Fix**: Always remove listeners with the same ID used to register:

```dart
@override
void dispose() {
  CometChat.removeMessageListener(_listenerId);
  CometChat.removeUserListener(_listenerId);
  CometChat.removeGroupListener(_listenerId);
  CometChat.removeCallListener(_listenerId);
  super.dispose();
}
```

### 5.3 No events firing (subscriptionType not set)

- **Symptom**: All listeners are properly registered and removed, but no events ever fire. No errors in console.
- **Cause**: `subscriptionType` not set in `UIKitSettingsBuilder`. This silently disables all real-time events.
- **Fix**: Set `subscriptionType` during init:

```dart
UIKitSettingsBuilder()
  ..subscriptionType = CometChatSubscriptionType.allUsers
```

---

## 6. Build Errors

### 6.1 Android: ClassNotFoundException (missing ProGuard rules)

- **Symptom**: Release build crashes with `ClassNotFoundException` for CometChat classes. Debug builds work fine.
- **Cause**: R8/ProGuard strips CometChat SDK classes during release minification.
- **Fix**: Create `android/app/proguard-rules.pro` with:

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

Reference it in `android/app/build.gradle`:

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

### 6.2 Android: minSdk too low

- **Symptom**: Build fails with error about minimum SDK version. Error mentions `minSdkVersion` incompatibility.
- **Cause**: `minSdk` is set below 26. The `cometchat_calls_sdk` requires minSdk 26.
- **Fix**: In `android/app/build.gradle` (or `.kts`):

```kotlin
defaultConfig {
    minSdk = 26  // Required by cometchat_calls_sdk
}
```

### 6.3 Android: Jetifier missing

- **Symptom**: Build fails with errors about Android Support Library classes not found, or `androidx` conflicts.
- **Cause**: `android.enableJetifier=true` not set. Transitive dependencies from the CometChat SDK use old Android Support Library references.
- **Fix**: In `android/gradle.properties`:

```properties
android.useAndroidX=true
android.enableJetifier=true
```

### 6.4 iOS: pod install failures

- **Symptom**: `pod install` fails with dependency resolution errors, version conflicts, or missing pods.
- **Cause**: Cocoapods cache is stale, or the Podfile needs updating.
- **Fix**:

```bash
cd ios
rm -rf Pods Podfile.lock
pod repo update
pod install --repo-update
cd ..
flutter clean
flutter pub get
```

If still failing, check that the iOS deployment target in `ios/Podfile` is high enough:

```ruby
platform :ios, '13.0'  # Minimum for CometChat
```

### 6.5 iOS: missing permissions

- **Symptom**: App crashes or shows blank screen when trying to access camera, microphone, or photo library on iOS.
- **Cause**: Required permission descriptions missing from `Info.plist`.
- **Fix**: Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is needed for video calls and sending photos</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is needed for voice and video calls</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is needed for sending images</string>
```

For VoIP calls, also add:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>voip</string>
    <string>remote-notification</string>
</array>
```

---

## 7. Performance Issues

### 7.1 Theme lookup in build() causing jank

- **Symptom**: Dropped frames during scrolling or keyboard animation. Flutter DevTools shows long build times (44–95ms).
- **Cause**: `CometChatThemeHelper.getColorPalette(context)` and similar calls in `build()` do expensive InheritedWidget traversal on every rebuild.
- **Fix**: Cache theme values in `didChangeDependencies()` — see Section 3.5 for the full pattern. For child widgets, pass pre-cached theme values from the parent:

```dart
// Parent passes cached values to children
CometChatImageBubble(
  imageUrl: message.attachment?.fileUrl,
  colorPalette: _colorPalette,  // Pre-cached from parent
  spacing: _spacing,            // Pre-cached from parent
);
```

### 7.2 Missing buildWhen optimization

- **Symptom**: Entire widget tree rebuilds on every BLoC state change, even when only a small part of the state changed.
- **Cause**: `BlocConsumer` or `BlocBuilder` without `buildWhen` — rebuilds on every state emission.
- **Fix**: Add `buildWhen` to limit rebuilds to relevant state changes:

```dart
BlocConsumer<MessageComposerBloc, MessageComposerState>(
  buildWhen: (previous, current) =>
      previous.isEditMode != current.isEditMode ||
      previous.isReplyMode != current.isReplyMode ||
      previous.isRecordingMode != current.isRecordingMode ||
      previous.editMessage != current.editMessage ||
      previous.replyMessage != current.replyMessage,
  listener: (context, state) { /* still receives ALL state changes */ },
  builder: (context, state) { /* only rebuilds when buildWhen is true */ },
)
```

### 7.3 O(n) lookups instead of O(1)

- **Symptom**: Slow scrolling in long message lists. `findChildIndexCallback` takes too long.
- **Cause**: Using `list.indexWhere()` (O(n)) to find messages instead of a Map-based O(1) lookup.
- **Fix**: Maintain a `Map<int, int>` alongside the message list for O(1) index lookups:

```dart
// In BLoC — maintain O(1) lookup map
final Map<int, int> _messageIndexMap = {};

int? findMessageIndex(int messageId) => _messageIndexMap[messageId];

// In SliverAnimatedList
SliverAnimatedList(
  findChildIndexCallback: (Key key) {
    if (key is ValueKey<int>) {
      final index = widget.findMessageIndex?.call(key.value) ??
          _messages.indexWhere((m) => m.id == key.value);
      if (index != -1) return visualPosition(index);
    }
    return null;
  },
)
```

---

## 8. Platform-Specific Issues

### 8.1 Android-specific

| Symptom | Cause | Fix |
|---------|-------|-----|
| Release crash `ClassNotFoundException` | Missing ProGuard rules | Add `-keep class com.cometchat.** { *; }` — see Section 6.1 |
| Build fail `minSdk` | minSdk < 26 | Set `minSdk = 26` in `build.gradle` |
| Build fail support library | Missing Jetifier | Add `android.enableJetifier=true` to `gradle.properties` |
| `startSession` returns null | Known Calls SDK issue | Implement timeout + retry — see Section 4.4 |
| `CallManager not found` | Native module not linked | Clean build + verify ProGuard + Jetifier — see Section 4.3 |
| Audio recording stuck after permission | Permission callback race | Ensure permission is granted before starting recording; handle the permission result callback properly |

### 8.2 iOS-specific

| Symptom | Cause | Fix |
|---------|-------|-----|
| Pod install fails | Stale cache or version conflict | `rm -rf Pods Podfile.lock && pod install --repo-update` |
| Camera/mic crash | Missing `Info.plist` permissions | Add `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` — see Section 6.5 |
| Media not sending | File access or permission issue | Verify `NSPhotoLibraryUsageDescription` in Info.plist; check file picker permissions |
| App crash on iPhone 11 | Device-specific compatibility | Check iOS deployment target ≥ 13.0; verify no 32-bit dependencies |
| VoIP calls not received in background | Missing background modes | Add `voip` and `remote-notification` to `UIBackgroundModes` in Info.plist |

### 8.3 Web-specific

| Symptom | Cause | Fix |
|---------|-------|-----|
| Runtime error on web | Platform-specific code without `kIsWeb` guard | Wrap platform-specific code with `if (!kIsWeb)` checks |
| Native plugins crash on web | Plugin not available on web | Use conditional imports or `kIsWeb` guards before calling native APIs |
| CORS errors | API calls blocked by browser | Ensure CometChat API endpoints are accessible; check proxy configuration |

```dart
// ✅ CORRECT — guard platform-specific code
import 'package:flutter/foundation.dart' show kIsWeb;

if (!kIsWeb) {
  // Native-only code (e.g., push notifications, file system access)
  setupPushNotifications();
}

// For conditional imports:
// lib/platform/native_service.dart — native implementation
// lib/platform/web_service.dart — web implementation
```

---

## Quick Reference: Error → Fix Table

| Error / Symptom | Section | One-Line Fix |
|----------------|---------|-------------|
| "Authentication null" | 2.1 | Call `CometChatUIKit.init()` before any usage |
| "APP ID null" | 2.2 | Set `..appId = 'YOUR_APP_ID'` in UIKitSettingsBuilder |
| ERR_ALREADY_LOGGED_IN | 2.3 | Check `CometChatUIKit.loggedInUser` before calling login |
| ERR_USER_ALREADY_LOGGED_IN | 2.3 | `loginWithAuthToken` with another token: check `loggedInUser`, `logout()` first |
| "Android internal error" | 2.4 | Verify credentials, UID existence, try stable SDK |
| Guard screen stuck on spinner | 2.5 | Use `CometChatUIKit.loggedInUser` synchronously after init |
| ERR_INVALID_REGION | 2.6 | Use lowercase: `'us'`, `'eu'`, `'in'` |
| StateError: not initialized | 2.7 | Call `ServiceLocator.instance.setup()` before creating BLoC |
| Double keyboard compensation | 3.1 | Set `resizeToAvoidBottomInset: false` on Scaffold |
| No typing indicators / presence | 3.3 | Set `..subscriptionType = CometChatSubscriptionType.allUsers` |
| Theme jank during keyboard | 3.5 | Cache theme in `didChangeDependencies()`, not `build()` |
| Duplicate events | 5.1 | Use unique listener ID per widget instance |
| Listener leak | 5.2 | Remove listener in `dispose()` with same ID |
| ClassNotFoundException (release) | 6.1 | Add ProGuard keep rules for `com.cometchat.**` |
| minSdk too low | 6.2 | Set `minSdk = 26` |
| Jetifier missing | 6.3 | Add `android.enableJetifier=true` |
| Pod install failure | 6.4 | Delete Pods + Podfile.lock, `pod install --repo-update` |
| Missing iOS permissions | 6.5 | Add camera/mic/photo descriptions to Info.plist |

---

## Checklist — Every CometChat Integration

Use this checklist to verify your integration is correct:

- [ ] `CometChatUIKit.init()` called and awaited before any usage
- [ ] Auth check uses `CometChatUIKit.loggedInUser` after init (not `CometChat.getLoggedInUser()`)
- [ ] `subscriptionType` set in UIKitSettingsBuilder
- [ ] `region` is lowercase (`'us'`, `'eu'`, `'in'`)
- [ ] Scaffold has `resizeToAvoidBottomInset: false` if composer is present
- [ ] Theme cached in `didChangeDependencies()`, not `build()`
- [ ] SDK listeners registered with unique ID, removed in `dispose()`
- [ ] Colors from `CometChatThemeHelper`, never hardcoded
- [ ] Strings from `Translations.of(context)`, never hardcoded
- [ ] Android: minSdk ≥ 26, Jetifier enabled, ProGuard rules added
- [ ] iOS: permissions in Info.plist, deployment target ≥ 13.0
- [ ] Web: `kIsWeb` guards on platform-specific code
