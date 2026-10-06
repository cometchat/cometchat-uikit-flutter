import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

/// Reads CometChat credentials. For device-based integration tests,
/// Platform.environment is not available — credentials are compiled in
/// via --dart-define or hardcoded for internal test apps.
///
/// For CI, pass via --dart-define:
///   flutter test integration_test/ \
///     --dart-define=COMETCHAT_APP_ID=xxx \
///     --dart-define=TEST_USER_UID=yyy
class LoginFixture {
  // Hardcoded for internal test app (26580020f03ff346).
  // For CI, override via --dart-define.
  static const String appId = String.fromEnvironment(
    'COMETCHAT_APP_ID',
    defaultValue: '',
  );
  static const String region = String.fromEnvironment(
    'COMETCHAT_REGION',
    defaultValue: '',
  );

  /// No default: the literal key that used to sit here was a credential in
  /// source, alongside the REST key that was moved out in 0cfc982e0. An auth
  /// key is a client-side credential and a far smaller exposure than a REST
  /// key, but there is no reason for a test helper to carry one — the suites
  /// already take every other value this way.
  ///
  /// Empty unless supplied; [_assertConfigured] turns that into a message
  /// that says what to pass, rather than an opaque login failure.
  static const String authKey = String.fromEnvironment('COMETCHAT_AUTH_KEY');
  static const String testUserUid = String.fromEnvironment(
    'TEST_USER_UID',
    defaultValue: '',
  );

  /// Tracks whether `CometChatUIKit.init` has succeeded for the current
  /// process. Re-initialising the UIKit can throw "already initialised" or
  /// silently leave the SDK in a bad state, so we skip it on subsequent
  /// calls within the same test process (e.g. when `all_e2e_tests.dart`
  /// chains multiple test files together).
  /// Fails with a message that says what to do, instead of letting an empty
  /// key reach the SDK and come back as an opaque auth error. Mirrors
  /// [SeedData._assertConfigured].
  static void _assertConfigured() {
    if (authKey.isEmpty) {
      throw StateError(
        'COMETCHAT_AUTH_KEY is not set. The E2E suites log in with it and '
        'cannot run without it. Pass --dart-define=COMETCHAT_AUTH_KEY=<key>.',
      );
    }
  }

  static bool _initialised = false;

  /// Tracks whether the current process has an authenticated user.
  /// `setUpAll` in chained test files will hit this fast-path instead of
  /// performing a full re-login flow.
  static bool _loggedIn = false;

  /// Initialize CometChat SDK (once per process) and login with the test
  /// user. Returns the logged-in [User].
  ///
  /// Calling this multiple times is safe:
  ///   - The first call performs init + login.
  ///   - Subsequent calls skip init if the SDK is already up, and skip
  ///     login if the user is still authenticated.
  static Future<User> initAndLogin() async {
    _assertConfigured();
    if (!_initialised) {
      final settingsBuilder = UIKitSettingsBuilder()
        ..subscriptionType = CometChatSubscriptionType.allUsers
        ..region = region
        ..autoEstablishSocketConnection = true
        ..appId = appId
        ..authKey = authKey;

      // Build settings (skip enableCalls to avoid Calls SDK init which
      // requires permissions we can't grant in integration_test).
      final uiKitSettings = settingsBuilder.build();

      // CometChatUIKit.init is NOT a true Future; it uses callbacks.
      // Bridge with a Completer.
      final initCompleter = Completer<void>();
      CometChatUIKit.init(
        uiKitSettings: uiKitSettings,
        onSuccess: (_) {
          initCompleter.complete();
        },
        onError: (e) {
          initCompleter.completeError(
            StateError(
              'CometChatUIKit.init failed: '
              '${e.message}',
            ),
          );
        },
      );

      await initCompleter.future;
      _initialised = true;
    }

    // If we're already logged in (e.g. previous test file in a chained run),
    // resolve the existing user instead of re-running login.
    if (_loggedIn) {
      final existing = await _loggedInUser();
      if (existing != null) return existing;
      // Cached state lied — fall through to re-login.
      _loggedIn = false;
    }

    final loginCompleter = Completer<User>();
    CometChatUIKit.login(
      testUserUid,
      onSuccess: (user) {
        loginCompleter.complete(user);
      },
      onError: (e) {
        loginCompleter.completeError(
          StateError(
            'CometChatUIKit.login failed: '
            '${e.message}',
          ),
        );
      },
    );

    final user = await loginCompleter.future;
    _loggedIn = true;
    return user;
  }

  /// Logout the current user. Call in `tearDownAll`.
  ///
  /// In chained test runs, the user that the next test file logs in as is
  /// the same one we just logged out, so we mark the cached login state
  /// as stale here and let the next `initAndLogin` do the work.
  static Future<void> logout() async {
    await CometChatUIKit.logout(onSuccess: (_) {}, onError: (_) {});
    _loggedIn = false;
  }

  /// Returns the currently authenticated user, or null if no one is logged
  /// in. Used to short-circuit re-login in chained test runs.
  static Future<User?> _loggedInUser() async {
    try {
      return await CometChat.getLoggedInUser();
    } catch (_) {
      return null;
    }
  }
}
