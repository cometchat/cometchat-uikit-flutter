import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show CometChatCallsException;

import '../shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';
import '../shared_ui/src/logging/cometchat_log.dart';
import 'calls_sdk_gateway.dart';

/// What the Calls SDK was initialised with. When it changes, the init runs
/// again.
///
/// The hosts are part of it so that a later `CometChatUIKit.init` against
/// another environment re-initialises the Calls SDK. They are not passed to
/// the Calls SDK itself (out of scope for now, by the owner's decision).
@immutable
final class CallsSdkSettings {
  /// Creates a settings snapshot.
  const CallsSdkSettings({
    required this.appId,
    required this.region,
    this.clientHost,
    this.adminHost,
    this.fromSettings = false,
  });

  /// The CometChat app id.
  final String appId;

  /// The CometChat region.
  final String region;

  /// `UIKitSettings.clientHost`.
  final String? clientHost;

  /// `UIKitSettings.adminHost`.
  final String? adminHost;

  /// Whether the UI Kit was initialised from `cometchat-settings.json`
  /// (`CometChatUIKit.initFromSettings`). The Calls SDK is then initialised
  /// the same way, so it records the "ai-agent" integration source.
  final bool fromSettings;

  /// The snapshot of what `CometChatUIKit` was last initialised with, or null
  /// when it has no app id or region yet.
  static CallsSdkSettings? fromUIKit() {
    final settings = CometChatUIKit.authenticationSettings;
    final appId = settings?.appId;
    final region = settings?.region;
    if (settings == null || appId == null || region == null) return null;
    return CallsSdkSettings(
      appId: appId,
      region: region,
      clientHost: settings.clientHost,
      adminHost: settings.adminHost,
      fromSettings: CometChatUIKit.initializedFromSettings,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CallsSdkSettings &&
      other.appId == appId &&
      other.region == region &&
      other.clientHost == clientHost &&
      other.adminHost == adminHost &&
      other.fromSettings == fromSettings;

  @override
  int get hashCode =>
      Object.hash(appId, region, clientHost, adminHost, fromSettings);

  @override
  String toString() =>
      'CallsSdkSettings(appId: $appId, region: $region, '
      'clientHost: $clientHost, adminHost: $adminHost, '
      'fromSettings: $fromSettings)';
}

/// The time limits [CallsSdkSession] puts on the Calls SDK.
@immutable
final class CallsSdkTimeouts {
  /// Creates the limits. The defaults are the product decision (P1-D01):
  /// init 10 s, login 10 s x 2, and 22 s for a whole [CallsSdkSession.ensureReady].
  const CallsSdkTimeouts({
    this.init = const Duration(seconds: 10),
    this.login = const Duration(seconds: 10),
    this.loginAttempts = 2,
    this.loginRetryGap = const Duration(seconds: 1),
    this.chatTokenPolls = 5,
    this.chatTokenPollInterval = const Duration(milliseconds: 200),
    this.logout = const Duration(seconds: 5),
    this.overall = const Duration(seconds: 22),
  });

  /// How long one Calls SDK init may take.
  final Duration init;

  /// How long one Calls SDK login attempt may take.
  final Duration login;

  /// Login attempts per login phase.
  final int loginAttempts;

  /// Pause between two login attempts.
  final Duration loginRetryGap;

  /// How many times the chat SDK is asked for its auth token before the
  /// login gives up. Right after a chat login or a cold start with a restored
  /// session, the token can take a moment to appear.
  final int chatTokenPolls;

  /// Pause between two chat token reads.
  final Duration chatTokenPollInterval;

  /// How long a Calls SDK logout may take.
  final Duration logout;

  /// How long one [CallsSdkSession.ensureReady] may take in total.
  final Duration overall;
}

/// Progress of one Calls SDK phase (init or login).
enum CallsSdkPhase {
  /// Not run, or reset by [CallsSdkSession.stop].
  idle,

  /// In flight.
  running,

  /// Done and still valid.
  ready,

  /// The last attempt failed or timed out. The next
  /// [CallsSdkSession.ensureReady] runs it once more.
  failed,
}

/// Initialises the Calls SDK and logs the chat user into it: once, within a
/// time limit, and again only when something says it is needed.
///
/// Package-private (see `lib/src/`), like `ActiveCallTracker`.
///
/// Every caller that needs the Calls SDK — the lifecycle at login, the call
/// screen before joining, the call logs before loading — calls
/// [ensureReady]. Concurrent callers share one run per phase; a finished
/// phase is re-checked (is the plugin still initialised, is it logged in with
/// the chat user's token) rather than re-run; a failed phase is run once more
/// by the next call. There are no background retries or timers.
///
/// [stop] (logout, user switch) bumps a generation counter. Anything that
/// was in flight before it lands without touching the state.
final class CallsSdkSession {
  /// Creates a session. Production code uses [instance]; tests build their
  /// own over a fake [gateway] and a fixed [settings] snapshot.
  CallsSdkSession({
    CallsSdkGateway gateway = const DefaultCallsSdkGateway(),
    CallsSdkSettings? Function()? settings,
    this.timeouts = const CallsSdkTimeouts(),
  }) : _gateway = gateway,
       _settings = settings ?? CallsSdkSettings.fromUIKit;

  static final CallsSdkSession _default = CallsSdkSession();
  static CallsSdkSession? _override;

  /// The session the UI Kit uses.
  static CallsSdkSession get instance => _override ?? _default;

  /// Replaces [instance] (null restores the real one).
  @visibleForTesting
  static set debugInstance(CallsSdkSession? session) => _override = session;

  final CallsSdkGateway _gateway;
  final CallsSdkSettings? Function() _settings;

  /// The limits this session applies.
  final CallsSdkTimeouts timeouts;

  /// The Calls SDK / chat SDK calls this session goes through.
  CallsSdkGateway get gateway => _gateway;

  int _generation = 0;

  CallsSdkPhase _initPhase = CallsSdkPhase.idle;
  CallsSdkSettings? _initSettings;
  Future<bool>? _initFuture;

  CallsSdkPhase _loginPhase = CallsSdkPhase.idle;
  Future<bool>? _loginFuture;

  Future<bool>? _readyFuture;
  Future<void>? _logoutFuture;
  bool _loggedOut = false;

  /// The login last sent to the Calls SDK, until it settles. It cannot be
  /// cancelled, so a logout waits for it (bounded) instead of letting it land
  /// afterwards.
  Future<void>? _gatewayLogin;

  /// The chat token the web fallback logged the JS Calls SDK in with. The
  /// Dart Calls SDK still holds no token after it, so without this every
  /// [ensureReady] would run the failing Dart login again.
  String? _nativeFallbackToken;
  bool _loggedMissingSettings = false;

  /// Where the init phase is.
  CallsSdkPhase get initPhase => _initPhase;

  /// Where the login phase is.
  CallsSdkPhase get loginPhase => _loginPhase;

  /// Whether the Calls SDK init succeeded and the plugin still says so.
  bool get isInitialized =>
      _initPhase == CallsSdkPhase.ready && _gateway.isInitialized;

  /// Whether the Calls SDK is initialised and the chat user is logged into
  /// it, as of the last check.
  bool get isReady => isInitialized && _loginPhase == CallsSdkPhase.ready;

  /// Makes sure the Calls SDK is initialised, without logging anyone in.
  /// Resolves to whether it is, within [CallsSdkTimeouts.init].
  Future<bool> ensureInitialized() => _ensureInitialized(_generation);

  /// Makes sure the Calls SDK is initialised and logged in with the chat
  /// user's token. Resolves to [isReady] within [CallsSdkTimeouts.overall].
  /// Never throws.
  Future<bool> ensureReady() {
    final inFlight = _readyFuture;
    if (inFlight != null) return inFlight;
    final gen = _generation;
    late final Future<bool> run;
    run = _runReady(gen)
        .timeout(
          timeouts.overall,
          onTimeout: () {
            _log(
              'ensureReady gave up after ${timeouts.overall.inSeconds} s '
              '(init=$_initPhase, login=$_loginPhase)',
            );
            return false;
          },
        )
        .whenComplete(() {
          if (identical(_readyFuture, run)) _readyFuture = null;
        });
    _readyFuture = run;
    return run;
  }

  /// Forgets the current user's Calls state: the login phase goes back to
  /// idle, and whatever is in flight will land without effect.
  ///
  /// A successful init is kept (the Calls plugin stays initialised across
  /// logout from 5.0.8; [ensureReady] re-checks it on 5.0.4). Does not log
  /// the Calls SDK out; see [logout].
  void stop() {
    _generation++;
    _readyFuture = null;
    _initFuture = null;
    _loginFuture = null;
    _nativeFallbackToken = null;
    if (_initPhase != CallsSdkPhase.ready) _initPhase = CallsSdkPhase.idle;
    _loginPhase = CallsSdkPhase.idle;
  }

  /// Logs the Calls SDK out, within [CallsSdkTimeouts.logout]. Concurrent
  /// callers share one logout, and a second one after it is a no-op until
  /// the next login. Never throws.
  ///
  /// The plugin's own callback cannot be cancelled: one that lands after the
  /// next user's login wipes that login. [ensureReady] catches it at the next
  /// join by comparing tokens. A login already sent to the plugin is waited
  /// for first (within [CallsSdkTimeouts.logout]), so it cannot land after
  /// the logout; one that lands later still counts as logged in, and the
  /// next logout logs it out.
  Future<void> logout() {
    final inFlight = _logoutFuture;
    if (inFlight != null) return inFlight;
    _loginPhase = CallsSdkPhase.idle;
    if (_loggedOut || !_gateway.isInitialized) return Future<void>.value();
    return _sharedLogout();
  }

  // ---------------------------------------------------------------------------

  bool _isCurrent(int gen) => gen == _generation;

  Future<bool> _runReady(int gen) async {
    try {
      if (!await _ensureInitialized(gen)) return false;
      if (!_isCurrent(gen)) return false;
      return await _ensureLoggedIn(gen);
    } catch (e) {
      _log('ensureReady failed: $e');
      return false;
    }
  }

  Future<bool> _ensureInitialized(int gen) {
    final settings = _settings();
    if (settings == null) {
      if (!_loggedMissingSettings) {
        _loggedMissingSettings = true;
        _log('no app id / region yet (CometChatUIKit.init not run); skipping');
      }
      return Future<bool>.value(false);
    }
    _loggedMissingSettings = false;
    if (_initPhase == CallsSdkPhase.ready &&
        _initSettings == settings &&
        _gateway.isInitialized) {
      return Future<bool>.value(true);
    }
    final inFlight = _initFuture;
    if (inFlight != null && _initSettings == settings) return inFlight;

    late final Future<bool> run;
    run = _runInit(settings, gen).whenComplete(() {
      if (identical(_initFuture, run)) _initFuture = null;
    });
    _initFuture = run;
    return run;
  }

  Future<bool> _runInit(CallsSdkSettings settings, int gen) async {
    final previous = _initSettings;
    if (previous != null && previous != settings) {
      _log('settings changed ($previous -> $settings); initialising again');
      // Another app or environment: the login has to be redone as well.
      _loginPhase = CallsSdkPhase.idle;
      _nativeFallbackToken = null;
    } else if (_initPhase == CallsSdkPhase.ready) {
      _log(
        'the Calls plugin reports it is not initialised; initialising again',
      );
    }
    _initPhase = CallsSdkPhase.running;
    _initSettings = settings;

    var ok = false;
    try {
      final init = settings.fromSettings
          ? _gateway.initFromSettings()
          : _gateway.init(settings.appId, settings.region);
      await init.timeout(timeouts.init);
      ok = true;
    } on TimeoutException {
      _log('init timed out after ${timeouts.init.inSeconds} s');
    } catch (e) {
      _log('init failed: ${_describe(e)}');
    }

    if (!_isCurrent(gen) || _initSettings != settings) return false;
    _initPhase = ok ? CallsSdkPhase.ready : CallsSdkPhase.failed;
    if (ok) _log('initialised');
    return ok;
  }

  Future<bool> _ensureLoggedIn(int gen) {
    final inFlight = _loginFuture;
    if (inFlight != null) return inFlight;
    late final Future<bool> run;
    run = _runLogin(gen).whenComplete(() {
      if (identical(_loginFuture, run)) _loginFuture = null;
    });
    _loginFuture = run;
    return run;
  }

  Future<bool> _runLogin(int gen) async {
    // A logout still on its way would wipe this login when it lands.
    final pendingLogout = _logoutFuture;
    if (pendingLogout != null) await pendingLogout;
    if (!_isCurrent(gen)) return false;

    var chatToken = await _pollChatToken(gen);
    if (!_isCurrent(gen)) return false;
    if (chatToken == null) {
      _log('no chat auth token (no user logged in?); not logging in');
      _loginPhase = CallsSdkPhase.failed;
      return false;
    }

    final callsToken = await _readCallsToken();
    if (!_isCurrent(gen)) return false;
    if (callsToken == chatToken) {
      // Already logged in with this user's token: nothing to do. The plugin's
      // own same-token login is local too.
      _loggedOut = false;
      _loginPhase = CallsSdkPhase.ready;
      return true;
    }
    if (callsToken == null && chatToken == _nativeFallbackToken) {
      // Web: the fallback already logged the JS Calls SDK in with this token.
      _loginPhase = CallsSdkPhase.ready;
      return true;
    }

    _loginPhase = CallsSdkPhase.running;
    if (callsToken != null && callsToken.isNotEmpty) {
      // Logged in as someone else (a user switch, or a logout that timed
      // out). Log out explicitly and wait for it: the plugin's own
      // "different token -> logout -> login" path fails on 5.0.4, whose
      // logout tears the API connection down before the login request.
      _log('Calls SDK holds another login; logging out first');
      await _sharedLogout();
      if (!_isCurrent(gen)) return false;
    }

    if (!_gateway.isInitialized) {
      // Calls plugin 5.0.4 de-initialises itself on logout.
      if (!await _ensureInitialized(gen)) {
        if (_isCurrent(gen)) _loginPhase = CallsSdkPhase.failed;
        return false;
      }
      if (!_isCurrent(gen)) return false;
    }

    _loggedOut = false;
    final attempts = timeouts.loginAttempts < 1 ? 1 : timeouts.loginAttempts;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        await _sendLogin(chatToken!).timeout(timeouts.login);
        if (!_isCurrent(gen)) return false;
        _log('logged in (attempt $attempt)');
        _loginPhase = CallsSdkPhase.ready;
        return true;
      } on TimeoutException {
        _log(
          'login timed out after ${timeouts.login.inSeconds} s '
          '(attempt $attempt)',
        );
      } catch (e) {
        _log('login failed (attempt $attempt): ${_describe(e)}');
      }
      if (!_isCurrent(gen)) return false;
      if (attempt < attempts) {
        await Future<void>.delayed(timeouts.loginRetryGap);
        if (!_isCurrent(gen)) return false;
        // The token can rotate between attempts.
        final refreshed = await _readChatToken();
        if (!_isCurrent(gen)) return false;
        if (refreshed != null && refreshed.isNotEmpty) chatToken = refreshed;
      }
    }

    // Web: the Dart login can fail (CORS, API differences) while the JS
    // Calls SDK can still be logged in directly, which is all joinSession
    // needs there.
    if (_gateway.supportsNativeAuthTokenFallback) {
      _log('web fallback: setting the native auth token directly');
      try {
        unawaited(
          _gateway.setNativeAuthToken(chatToken!).catchError((Object e) {
            _log('web fallback setNativeAuthToken failed: $e');
          }),
        );
        _nativeFallbackToken = chatToken;
        _loginPhase = CallsSdkPhase.ready;
        return true;
      } catch (e) {
        _log('web fallback setNativeAuthToken failed: $e');
      }
    }

    _loginPhase = CallsSdkPhase.failed;
    return false;
  }

  Future<String?> _pollChatToken(int gen) async {
    final polls = timeouts.chatTokenPolls < 1 ? 1 : timeouts.chatTokenPolls;
    for (var i = 0; i < polls; i++) {
      if (i > 0) {
        await Future<void>.delayed(timeouts.chatTokenPollInterval);
        if (!_isCurrent(gen)) return null;
      }
      final token = await _readChatToken();
      if (token != null && token.isNotEmpty) return token;
    }
    return null;
  }

  Future<String?> _readChatToken() async {
    try {
      return await _gateway.chatAuthToken();
    } catch (e) {
      _log('reading the chat auth token failed: $e');
      return null;
    }
  }

  Future<String?> _readCallsToken() async {
    try {
      return await _gateway.callsAuthToken();
    } catch (e) {
      _log('reading the Calls auth token failed: $e');
      return null;
    }
  }

  /// Sends a login to the Calls SDK and tracks it until it settles. However
  /// late it lands, a successful one means the plugin holds a login again.
  Future<void> _sendLogin(String authToken) {
    final login = _gateway.loginWithAuthToken(authToken);
    late final Future<void> settled;
    settled = login
        .then<void>((_) => _loggedOut = false, onError: (Object _) {})
        .whenComplete(() {
          if (identical(_gatewayLogin, settled)) _gatewayLogin = null;
        });
    _gatewayLogin = settled;
    return login;
  }

  /// One gateway logout at a time, shared by [logout] and the login's
  /// explicit logout of another user's session.
  Future<void> _sharedLogout() {
    final inFlight = _logoutFuture;
    if (inFlight != null) return inFlight;
    late final Future<void> run;
    run = _logoutGateway().whenComplete(() {
      if (identical(_logoutFuture, run)) _logoutFuture = null;
    });
    _logoutFuture = run;
    return run;
  }

  Future<void> _logoutGateway() async {
    final pendingLogin = _gatewayLogin;
    if (pendingLogin != null) {
      try {
        await pendingLogin.timeout(timeouts.logout);
      } on TimeoutException {
        _log(
          'a login still in flight after ${timeouts.logout.inSeconds} s; '
          'logging out anyway',
        );
      }
    }
    _loggedOut = true;
    _nativeFallbackToken = null;
    try {
      await _gateway.logout().timeout(timeouts.logout);
      _log('logged out');
    } on TimeoutException {
      _log('logout timed out after ${timeouts.logout.inSeconds} s');
    } catch (e) {
      _log('logout failed: ${_describe(e)}');
    }
  }

  static String _describe(Object e) =>
      e is CometChatCallsException ? '${e.code} ${e.message}' : e.toString();

  static void _log(String message) => ccLog('CallsSdkSession: $message');
}
