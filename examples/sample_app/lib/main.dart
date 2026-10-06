import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sample_app/app_credentials.dart';
import 'package:sample_app/screens/app_credentials_screen.dart';
import 'package:sample_app/screens/guard_screen.dart';
import 'package:sample_app/screens/home_screen.dart';
import 'package:sample_app/screens/responsive_home_screen.dart';
import 'package:sample_app/utils/app_uikit_settings.dart';
import 'package:sample_app/utils/call_error_snackbar.dart';

/// Entry point for the public sample app.
///
/// WHY THIS FILE IS TRACKED RATHER THAN GENERATED
///
/// The mirror used to derive this file from master_app/lib/main.dart by
/// deleting every line that mentioned a push/Firebase/VoIP identifier. That
/// cannot work: those identifiers appear inside a ternary's false branch, in a
/// variable whose later uses remain, and on lines that open a block. Deleting
/// the line leaves a dangling `?` with no `:`, an undefined variable, and an
/// orphaned closing brace — 33 analyzer errors, none of which a cleverer regex
/// would avoid, because the fix is to remove the surrounding statement.
///
/// So this is a hand-maintained public counterpart instead. It is reviewable,
/// it compiles, and release-to-public.yml's build gate checks it on every run.
/// When master_app's main.dart changes in a way that matters to the sample,
/// change this one too.
///
/// WHAT IT DELIBERATELY OMITS versus master_app
///
///   * Firebase init and Crashlytics — the sample ships no Firebase config.
///   * PlatformServices — mobile push, VoIP/CallKit and the cold-start
///     "accept a call answered from the lock screen" path. That whole feature
///     needs native set-up a sample cannot assume.
///   * The staging host switch.
///
/// WHAT IT KEEPS
///
///   * Credentials entered at runtime, gated by [AppCredentialsScreen].
///   * Cached-session validation, which is the subtle part worth showing.
///   * Responsive routing: split-pane on web/desktop, bottom-nav on mobile.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Before the first frame, so it is already known whether the credentials
  // screen is needed.
  await AppCredentials.loadSavedCredentials();

  runApp(const BlocSampleApp());
}

class BlocSampleApp extends StatefulWidget {
  const BlocSampleApp({super.key});

  @override
  State<BlocSampleApp> createState() => _BlocSampleAppState();
}

class _BlocSampleAppState extends State<BlocSampleApp> {
  bool _isInitialized = false;
  bool _isLoggedIn = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCometChat();
  }

  Future<void> _initCometChat() async {
    // Nothing to initialise until the user has supplied credentials. Mark the
    // app initialised so [_buildHome] renders the credentials screen rather
    // than spinning forever on the splash.
    if (!AppCredentials.hasValidCredentials) {
      if (mounted) setState(() => _isInitialized = true);
      return;
    }

    try {
      // Shared with AppCredentialsScreen, so entering credentials there and
      // starting cold both configure the same UI Kit.
      final uiKitSettings = buildAppUIKitSettings();

      CometChatUIKit.init(
        uiKitSettings: uiKitSettings,
        onSuccess: (message) async {
          debugPrint('CometChat initialized: $message');
          final isValid = await _resolveCachedSession();
          if (mounted) {
            setState(() {
              _isLoggedIn = isValid;
              _isInitialized = true;
            });
          }
        },
        onError: (error) {
          debugPrint('CometChat init error: ${error.code} - ${error.message}');
          if (mounted) setState(() => _error = error.toString());
        },
      );
    } catch (e, stackTrace) {
      debugPrint('Exception during CometChat init: $e');
      debugPrint('  $stackTrace');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  /// Resolve whether there is a valid, live session.
  ///
  /// `getLoggedInUser()` can return a user when all that exists is a cached
  /// blob in the token store (Keychain on iOS, EncryptedSharedPreferences on
  /// Android). On iOS that cache survives app uninstall, so a stale session
  /// from a previous install would route straight to the home screen with a
  /// dead auth token, after which every authenticated call fails with
  /// `AUTH_ERR_AUTH_TOKEN_NOT_FOUND`.
  ///
  /// So prove the token with one lightweight authenticated call. Returns true
  /// when a cached user exists AND that call either succeeds or fails for a
  /// non-auth reason — being offline must not discard a good session.
  Future<bool> _resolveCachedSession() async {
    final cachedUser = await CometChatUIKit.getLoggedInUser();
    if (cachedUser == null) return false;

    final completer = Completer<_SessionCheckResult>();
    await CometChat.getUser(
      cachedUser.uid,
      onSuccess: (_) {
        if (!completer.isCompleted) {
          completer.complete(_SessionCheckResult.valid);
        }
      },
      onError: (error) {
        if (completer.isCompleted) return;
        completer.complete(_isAuthInvalidatedCode(error.code)
            ? _SessionCheckResult.authInvalidated
            : _SessionCheckResult.unknown);
      },
    );

    switch (await completer.future) {
      case _SessionCheckResult.valid:
        return true;
      case _SessionCheckResult.unknown:
        debugPrint('Session check inconclusive (likely offline). '
            'Trusting the cached session.');
        return true;
      case _SessionCheckResult.authInvalidated:
        debugPrint('Cached auth token is no longer valid server-side. '
            'Clearing the local session.');
        await _forceLogout();
        return false;
    }
  }

  /// Log out so the token store and cached user are cleared. Succeeds even
  /// when the server has already revoked the token: the SDK treats an
  /// auth-invalidated error from the logout API as "already logged out" and
  /// clears local state anyway.
  Future<void> _forceLogout() async {
    final completer = Completer<void>();
    await CometChatUIKit.logout(
      onSuccess: (_) {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (e) {
        debugPrint('logout error (ignored): ${e.code} ${e.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future;
  }

  /// Server codes meaning the auth token is gone. Declared locally because the
  /// app depends on the UI Kit and does not import SDK internals.
  bool _isAuthInvalidatedCode(String? code) {
    if (code == null) return false;
    const invalidated = <String>{'AUTH_ERR_AUTH_TOKEN_NOT_FOUND'};
    return invalidated.contains(code);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CometChat Sample App',
      debugShowCheckedModeBanner: false,
      // master_app swaps in its own key on mobile to drive the native
      // call-notification flow. With no PlatformServices here, the UI Kit's
      // own key is used on every platform, which is what its call overlay
      // expects.
      navigatorKey: CallNavigationContext.navigatorKey,
      // Call errors raised by the UI Kit's call components surface here.
      scaffoldMessengerKey: appScaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initCometChat,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing CometChat...'),
            ],
          ),
        ),
      );
    }

    // First launch, or credentials cleared: collect them before anything else.
    if (!AppCredentials.hasValidCredentials) {
      return const AppCredentialsScreen(buildSettings: buildAppUIKitSettings);
    }

    if (!_isLoggedIn) return const GuardScreen();

    // Web and desktop get the split-pane layout; mobile gets bottom-nav.
    return kIsWeb ? const ResponsiveHomeScreen() : const HomeScreen();
  }
}

enum _SessionCheckResult {
  /// The server accepted the cached auth token.
  valid,

  /// The server said the token is gone or revoked.
  authInvalidated,

  /// The server could not be reached, or returned a non-auth error. Do not
  /// discard the session for this — it is probably transient.
  unknown,
}
