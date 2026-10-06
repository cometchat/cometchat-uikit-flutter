---
name: cometchat-flutter-production
description: >
  Production readiness for CometChat Flutter UIKit v6 — server-side auth tokens,
  user management, Android ProGuard/R8, iOS Info.plist, minSdk, release build
  checklist, environment configuration, and security hardening. Use when preparing
  a CometChat Flutter app for production deployment.
license: "MIT"
compatibility: "cometchat_chat_uikit ^6.0.0"
allowed-tools: "executeBash, readFile, readCode, fileSearch, listDirectory, grepSearch"
metadata:
  author: "CometChat"
  version: "1.0.0"
  tags: "cometchat flutter production release auth-token proguard security"
---

# CometChat Flutter UIKit v6 — Production Readiness

Everything you need to move a CometChat Flutter app from development to production. Covers authentication, platform configuration, environment management, and security hardening.

---

## 1. Dev Mode vs Production

CometChat supports two authentication modes. Understanding the difference is critical before shipping.

### Dev Mode (authKey — development only)

The `authKey` is embedded in client code and lets any user log in by UID alone. Convenient for prototyping, but **anyone who decompiles your app can impersonate any user**.

```dart
// ✅ Dev mode — fine for prototyping, NEVER ship this
final settings = (UIKitSettingsBuilder()
      ..appId = 'APP_ID'
      ..region = 'us'
      ..authKey = 'AUTH_KEY'  // Client-side secret — dev only
      ..subscriptionType = CometChatSubscriptionType.allUsers)
    .build();

await CometChatUIKit.init(uiKitSettings: settings);

// Login with authKey (SDK uses the key from UIKitSettings internally)
await CometChatUIKit.login('user_uid',
  onSuccess: (user) => debugPrint('Logged in: ${user.name}'),
  onError: (e) => debugPrint('Login failed: ${e.message}'),
);
```

### Production Mode (authToken — server-minted)

Your backend generates a short-lived `authToken` for each authenticated user. The client never sees the `authKey`.

```dart
// ✅ Production — authKey is NOT in client code
final settings = (UIKitSettingsBuilder()
      ..appId = 'APP_ID'
      ..region = 'us'
      // No authKey here — tokens come from your server
      ..subscriptionType = CometChatSubscriptionType.allUsers)
    .build();

await CometChatUIKit.init(uiKitSettings: settings);

// Login with server-provided token
final authToken = await yourBackend.getCometChatToken(currentUserId);
await CometChatUIKit.loginWithAuthToken(authToken,
  onSuccess: (user) => debugPrint('Logged in: ${user.name}'),
  onError: (e) => debugPrint('Login failed: ${e.message}'),
);
```

**Rule**: If `authKey` appears anywhere in your production build, you have a security vulnerability.

---

## 2. Server-Side Auth Token Flow

### How It Works

```
┌──────────┐     1. Authenticate      ┌──────────────┐
│  Flutter  │ ──────────────────────>  │  Your Server │
│   App     │                          │  (Backend)   │
│           │  4. Return authToken     │              │
│           │ <──────────────────────  │              │
└──────────┘                          └──────────────┘
     │                                       │
     │ 5. loginWithAuthToken(token)          │ 2. Verify user identity
     │                                       │ 3. POST /auth-tokens
     v                                       v
┌──────────┐                          ┌──────────────┐
│ CometChat│                          │  CometChat   │
│   SDK    │                          │  REST API    │
└──────────┘                          └──────────────┘
```

### Step 1: Your Backend Generates the Token

Your server calls the CometChat REST API with the `authKey` (which stays server-side):

```bash
curl -X POST "https://API_REGION.cometchat.io/v3/users/USER_UID/auth_tokens" \
  -H "appId: YOUR_APP_ID" \
  -H "apiKey: YOUR_AUTH_KEY" \
  -H "Content-Type: application/json"
```

Response:
```json
{
  "data": {
    "uid": "user_uid",
    "authToken": "user_uid_1a2b3c4d5e6f7a8b9c0d1e2f",
    "createdAt": 1700000000
  }
}
```

Replace `API_REGION` with your region endpoint:
- US: `api-us.cometchat.io`
- EU: `api-eu.cometchat.io`
- IN: `api-in.cometchat.io`

### Step 2: Your Backend Returns the Token to the Client

Your Flutter app calls your own backend (after the user authenticates with your auth system), and your backend returns the CometChat `authToken`.

### Step 3: Flutter Client Logs In with the Token

```dart
Future<void> loginWithToken(String uid) async {
  // 0. A session restored by CometChatUIKit.init is already logged in.
  //    loginWithAuthToken with a newly minted token would fail with
  //    ERR_USER_ALREADY_LOGGED_IN (log out first to switch users).
  if (CometChatUIKit.loggedInUser?.uid == uid) return;

  // 1. Call YOUR backend to get a CometChat auth token
  final response = await http.post(
    Uri.parse('https://your-api.com/cometchat/token'),
    headers: {'Authorization': 'Bearer ${yourJwt}'},
    body: jsonEncode({'uid': uid}),
  );
  final authToken = jsonDecode(response.body)['authToken'];

  // 2. Login to CometChat with the token
  CometChatUIKit.loginWithAuthToken(authToken,
    onSuccess: (user) {
      // CometChatUIKit.loggedInUser is now set
      debugPrint('Logged in as ${user.name}');
    },
    onError: (e) {
      debugPrint('CometChat login failed: ${e.message}');
    },
  );
}
```

**Note**: `loginWithAuthToken` populates `CometChatUIKit.loggedInUser` before calling `onSuccess` — same as `login()` and `init()`. No need to call `getLoggedInUser()` afterward.

**Note**: When a user is already logged in, `loginWithAuthToken` calls `onSuccess` only for the auth token the SDK already holds. Any other token gets `onError` with `ERR_USER_ALREADY_LOGGED_IN` and returns null: check `CometChatUIKit.loggedInUser` first, and call `CometChatUIKit.logout()` before logging in as someone else.

---

## 3. User Management

### Creating Users

```dart
final user = User(
  uid: 'user_123',
  name: 'Jane Doe',
  avatar: 'https://example.com/avatar.png',
);

await CometChatUIKit.createUser(user,
  onSuccess: (created) => debugPrint('Created: ${created.uid}'),
  onError: (e) => debugPrint('Create failed: ${e.message}'),
);
```

### Updating Users

```dart
final user = User(
  uid: 'user_123',
  name: 'Jane Smith',  // Updated name
);

await CometChatUIKit.updateUser(user,
  onSuccess: (updated) => debugPrint('Updated: ${updated.name}'),
  onError: (e) => debugPrint('Update failed: ${e.message}'),
);
```

### Production Warning

`createUser()` and `updateUser()` require the `authKey` (set in UIKitSettings). In production:

- **Move user creation to your backend** — call the CometChat REST API server-side
- **Move user updates to your backend** — same approach
- The Flutter client should only call `loginWithAuthToken()` — never create or update users directly

Server-side user creation:
```bash
curl -X POST "https://API_REGION.cometchat.io/v3/users" \
  -H "appId: YOUR_APP_ID" \
  -H "apiKey: YOUR_AUTH_KEY" \
  -H "Content-Type: application/json" \
  -d '{"uid": "user_123", "name": "Jane Doe"}'
```

---

## 4. Android Build Requirements

These are required for CometChat UIKit v6 on Android. Without them, debug builds may work but release builds will crash.

### gradle.properties

Ensure these are in `android/gradle.properties`:

```properties
android.useAndroidX=true
android.enableJetifier=true
```

`enableJetifier` resolves old Android Support Library conflicts from transitive dependencies in the CometChat SDK.

### minSdk 26

In `android/app/build.gradle` (Groovy) or `build.gradle.kts` (Kotlin DSL):

```kotlin
// build.gradle.kts
android {
    defaultConfig {
        minSdk = 26  // Required by cometchat_calls_sdk
    }
}
```

```groovy
// build.gradle (Groovy)
android {
    defaultConfig {
        minSdkVersion 26
    }
}
```

If your `minSdk` is lower than 26, the build will fail with a manifest merger error referencing `cometchat_calls_sdk`.

### ProGuard / R8 Keep Rules

Create `android/app/proguard-rules.pro` with these exact contents:

```proguard
# CometChat — prevent R8 from stripping SDK classes used via reflection
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

Reference the ProGuard file in your release build type. In `android/app/build.gradle.kts`:

```kotlin
android {
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
}
```

Or in `android/app/build.gradle` (Groovy):

```groovy
android {
    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

**Without these rules, release builds crash with `ClassNotFoundException` for CometChat classes.** Debug builds work fine because R8/ProGuard only runs on release.

### Multidex (if targeting API < 21 elsewhere)

CometChat requires minSdk 26, so multidex is not needed (it's automatic above API 21). If you have a multi-module setup where another module targets lower, ensure the app module still sets `minSdk = 26`.

---

## 5. iOS Build Requirements

### Info.plist Permissions

Add these to `ios/Runner/Info.plist` inside the top-level `<dict>`:

```xml
<!-- Camera access (video calls, sending photos) -->
<key>NSCameraUsageDescription</key>
<string>$(PRODUCT_NAME) needs camera access for video calls and sending photos</string>

<!-- Microphone access (voice/video calls, audio messages) -->
<key>NSMicrophoneUsageDescription</key>
<string>$(PRODUCT_NAME) needs microphone access for voice and video calls</string>

<!-- Photo library access (sending images from gallery) -->
<key>NSPhotoLibraryUsageDescription</key>
<string>$(PRODUCT_NAME) needs photo library access to send images</string>
```

Without these, the app crashes when the user taps the camera/gallery/mic button — iOS terminates apps that access protected APIs without a usage description.

### VoIP Background Mode (for CallKit)

If using CometChat calling with CallKit (incoming call notifications when app is backgrounded), add to `Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>voip</string>
    <string>remote-notification</string>
</array>
```

Or enable via Xcode: Target → Signing & Capabilities → + Background Modes → check "Voice over IP" and "Remote notifications".

### App Transport Security

CometChat uses HTTPS by default, so no ATS exceptions are needed. If you're loading user avatars or media from HTTP URLs (not recommended), add:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

**Avoid this in production** — it disables all transport security. Instead, ensure all media URLs use HTTPS.

### Minimum iOS Deployment Target

In `ios/Podfile`, ensure:

```ruby
platform :ios, '13.0'
```

CometChat UIKit v6 requires iOS 13.0+. If your Podfile has a lower target, `pod install` will fail.

---

## 6. Environment Configuration

Never hardcode credentials in source code. The `AppCredentials` pattern used in development:

```dart
// ❌ DON'T ship this — credentials visible in decompiled binary
class AppCredentials {
  static const String appId = 'YOUR_APP_ID';
  static const String region = 'in';
  static const String authKey = 'YOUR_AUTH_KEY';
}
```

### Option A: Dart Defines (recommended for simple setups)

Pass credentials at build time:

```bash
flutter run \
  --dart-define=COMETCHAT_APP_ID=your_app_id \
  --dart-define=COMETCHAT_REGION=us
```

Read them in code:

```dart
class CometChatConfig {
  static const appId = String.fromEnvironment('COMETCHAT_APP_ID');
  static const region = String.fromEnvironment('COMETCHAT_REGION');
  // No authKey in production builds — use authToken flow
}
```

For release builds:

```bash
flutter build apk \
  --dart-define=COMETCHAT_APP_ID=your_app_id \
  --dart-define=COMETCHAT_REGION=us

flutter build ipa \
  --dart-define=COMETCHAT_APP_ID=your_app_id \
  --dart-define=COMETCHAT_REGION=us
```

### Option B: .env File with flutter_dotenv

```bash
dart pub add flutter_dotenv
```

Create `.env` (add to `.gitignore`):

```
COMETCHAT_APP_ID=your_app_id
COMETCHAT_REGION=us
```

Load in code:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

class CometChatConfig {
  static String get appId => dotenv.env['COMETCHAT_APP_ID'] ?? '';
  static String get region => dotenv.env['COMETCHAT_REGION'] ?? 'us';
}
```

**Note**: `.env` files bundled in the app asset can still be extracted. For true secret protection, fetch config from your backend at runtime.

### Option C: Flavor-Based Configuration

For apps with dev/staging/prod environments:

```dart
enum Environment { dev, staging, prod }

class CometChatConfig {
  final String appId;
  final String region;
  final bool useAuthToken; // true for staging/prod

  const CometChatConfig._({
    required this.appId,
    required this.region,
    required this.useAuthToken,
  });

  static CometChatConfig of(Environment env) {
    switch (env) {
      case Environment.dev:
        return const CometChatConfig._(
          appId: 'dev_app_id',
          region: 'us',
          useAuthToken: false,
        );
      case Environment.staging:
        return const CometChatConfig._(
          appId: 'staging_app_id',
          region: 'us',
          useAuthToken: true,
        );
      case Environment.prod:
        return const CometChatConfig._(
          appId: 'prod_app_id',
          region: 'us',
          useAuthToken: true,
        );
    }
  }
}
```

---

## 7. Release Build Checklist

### Authentication
- [ ] `authKey` is NOT in any client-side code for production builds
- [ ] Server-side auth token generation is implemented and tested
- [ ] `CometChatUIKit.loginWithAuthToken()` is used instead of `CometChatUIKit.login()`
- [ ] User creation/update calls are server-side, not client-side

### Android
- [ ] `minSdk = 26` in `android/app/build.gradle`
- [ ] `android.enableJetifier=true` in `gradle.properties`
- [ ] `proguard-rules.pro` created with CometChat keep rules
- [ ] Release build type references `proguard-rules.pro`
- [ ] `isMinifyEnabled = true` and `isShrinkResources = true` for release
- [ ] Release APK/AAB tested on a real device (not just debug)
- [ ] Push notification provider ID configured (FCM)

### iOS
- [ ] `NSCameraUsageDescription` in Info.plist
- [ ] `NSMicrophoneUsageDescription` in Info.plist
- [ ] `NSPhotoLibraryUsageDescription` in Info.plist
- [ ] VoIP background mode enabled (if using CallKit)
- [ ] Minimum deployment target is iOS 13.0+
- [ ] Release build tested on a real device
- [ ] Push notification entitlements configured (APNs)

### Environment
- [ ] No hardcoded credentials in source code
- [ ] Credentials passed via dart-define, .env, or flavor config
- [ ] `.env` files are in `.gitignore`
- [ ] Production app ID and region are correct (not dev/staging)

### CometChat Configuration
- [ ] `CometChatUIKit.init()` called before any login or component usage
- [ ] `subscriptionType` set in UIKitSettingsBuilder (or presence events won't fire)
- [ ] `region` is lowercase (`'us'`, `'eu'`, `'in'`)
- [ ] Logout properly calls `CometChatUIKit.logout()` and clears local state

### Testing
- [ ] Release build tested end-to-end: init → login → send message → receive message → logout
- [ ] Tested on both Android and iOS physical devices
- [ ] Tested with ProGuard/R8 enabled (Android release)
- [ ] Tested push notifications in production environment
- [ ] Tested calling features if enabled (audio + video)
- [ ] Tested app kill → reopen → session restore (cached login via `CometChatUIKit.loggedInUser`)

---

## 8. Security Hardening

### Never Ship authKey in Production

The `authKey` allows anyone to:
- Log in as any user
- Create users
- Update user profiles

If it's in your APK/IPA, it can be extracted in minutes with standard decompilation tools.

```dart
// ❌ SECURITY VULNERABILITY — authKey in client code
final settings = (UIKitSettingsBuilder()
      ..appId = 'APP_ID'
      ..region = 'us'
      ..authKey = 'AUTH_KEY_VISIBLE_TO_ATTACKERS')
    .build();

// ✅ SECURE — no authKey, use server-minted tokens
final settings = (UIKitSettingsBuilder()
      ..appId = appId   // App ID is not secret (it's in network requests anyway)
      ..region = region
      ..subscriptionType = CometChatSubscriptionType.allUsers)
    .build();
```

### Don't Log Sensitive Data

```dart
// ❌ WRONG — auth tokens in logs
debugPrint('Token: $authToken');
debugPrint('User: ${user.toJson()}'); // May contain tokens

// ✅ CORRECT — log only non-sensitive identifiers
debugPrint('Logged in as uid: ${user.uid}');
```

In release builds, consider disabling debug prints entirely:

```dart
// In main.dart for release
if (kReleaseMode) {
  debugPrint = (String? message, {int? wrapWidth}) {};
}
```

### ProGuard Obfuscation

The ProGuard rules in Section 4 keep CometChat classes intact (required for the SDK to work), but R8 will still obfuscate your own application code. This makes reverse engineering harder.

Ensure `isMinifyEnabled = true` is set for release builds — it enables both code shrinking and obfuscation.

### Token Expiry and Refresh

CometChat auth tokens don't expire by default, but you can configure token expiry in the CometChat dashboard. If you enable expiry:

```dart
CometChatUIKit.loginWithAuthToken(authToken,
  onSuccess: (user) {
    // Token accepted, proceed
  },
  onError: (e) {
    if (e.code == 'ERR_AUTH_TOKEN_NOT_FOUND' || e.code == 'AUTH_ERR_AUTH_TOKEN_NOT_FOUND') {
      // Token expired or invalid — fetch a new one from your backend
      refreshAndRetryLogin();
    }
  },
);
```

### Network Security

- CometChat SDK uses HTTPS/WSS by default — no additional configuration needed
- Don't add `NSAllowsArbitraryLoads` to Info.plist unless absolutely necessary
- If using a proxy or custom certificate pinning, ensure CometChat domains are whitelisted:
  - `*.cometchat.io`
  - `*.cometchat.com`

### Session Management

```dart
// Always logout when user signs out of your app
Future<void> signOut() async {
  // Awaited: it first ends this device's calls on the server (within ~3 s),
  // then logs out. Leave the app's screens only once it has succeeded.
  await CometChatUIKit.logout(
    onSuccess: (_) async {
      // Clear your own auth state, then go to the login screen.
      await yourAuthService.signOut();
      navigator.pushReplacementNamed('/login');
    },
    onError: (e) {
      // Still logged in (calls still arrive): stay, and say so.
      debugPrint('CometChat logout failed: ${e.message}');
    },
  );
}
```

Don't just navigate away — always call `CometChatUIKit.logout()` to clear the SDK session, disconnect WebSocket, and remove cached credentials.
