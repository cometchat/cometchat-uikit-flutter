import 'dart:async';

import 'package:flutter/foundation.dart';

// The web login fallback needs the plugin's platform interface, which the
// Calls SDK does not export.
// ignore: implementation_imports
import 'package:cometchat_calls_sdk/src/plugin/platform/cometchatcalls_plugin_platform_interface.dart';

import '../cometchat_calls_uikit.dart';

/// The calls the UI Kit makes to set up the Calls SDK, as futures.
///
/// Package-private (see `lib/src/`). [CallsSdkSession] drives the Calls SDK
/// only through this, so tests can hand it a fake that answers, fails or
/// never answers, instead of a plugin that needs a device.
///
/// The futures complete when the SDK answers and fail when it reports an
/// error. They are not bounded: the session puts its own time limits on them.
abstract interface class CallsSdkGateway {
  /// Whether the Calls SDK reports itself initialised.
  ///
  /// Calls plugin 5.0.4 turns this back to false on logout; 5.0.8 keeps it.
  bool get isInitialized;

  /// `CometChatCalls.init` with [appId] and [region].
  Future<void> init(String appId, String region);

  /// `CometChatCalls.initFromSettings`: the Calls SDK reads
  /// `cometchat-settings.json` itself and records the "ai-agent" source.
  Future<void> initFromSettings();

  /// `CometChatCalls.loginWithAuthToken`.
  Future<void> loginWithAuthToken(String authToken);

  /// `CometChatCalls.logout`.
  Future<void> logout();

  /// The auth token the Calls SDK is logged in with, or null.
  Future<String?> callsAuthToken();

  /// The chat SDK's auth token for the logged-in user, or null.
  Future<String?> chatAuthToken();

  /// Whether [setNativeAuthToken] is a usable fallback when the Calls login
  /// fails. True on web only.
  bool get supportsNativeAuthTokenFallback;

  /// Logs the web JS Calls SDK in directly, bypassing the Dart login.
  Future<void> setNativeAuthToken(String authToken);
}

/// The real Calls SDK and chat SDK behind [CallsSdkGateway].
final class DefaultCallsSdkGateway implements CallsSdkGateway {
  /// Creates the gateway over the static `CometChatCalls` / `CometChat` APIs.
  const DefaultCallsSdkGateway();

  @override
  bool get isInitialized => CometChatCalls.isInitialized;

  @override
  Future<void> init(String appId, String region) {
    final completer = Completer<void>();
    final settings =
        (CallAppSettingBuilder()
              ..appId = appId
              ..region = region)
            .build();
    CometChatCalls.init(
      settings,
      onSuccess: (_) => _complete(completer),
      onError: (e) => _fail(completer, e),
    );
    return completer.future;
  }

  @override
  Future<void> initFromSettings() {
    final completer = Completer<void>();
    unawaited(
      CometChatCalls.initFromSettings(
        onSuccess: (_) => _complete(completer),
        onError: (e) => _fail(completer, e),
      ),
    );
    return completer.future;
  }

  @override
  Future<void> loginWithAuthToken(String authToken) {
    final completer = Completer<void>();
    CometChatCalls.loginWithAuthToken(
      authToken: authToken,
      onSuccess: (_) => _complete(completer),
      onError: (e) => _fail(completer, e),
    );
    return completer.future;
  }

  @override
  Future<void> logout() {
    final completer = Completer<void>();
    CometChatCalls.logout(
      onSuccess: (_) => _complete(completer),
      onError: (e) => _fail(completer, e),
    );
    return completer.future;
  }

  @override
  Future<String?> callsAuthToken() => CometChatCalls.getUserAuthToken();

  @override
  Future<String?> chatAuthToken() => CometChat.getUserAuthToken();

  @override
  bool get supportsNativeAuthTokenFallback => kIsWeb;

  @override
  Future<void> setNativeAuthToken(String authToken) =>
      CometChatCallsPluginPlatform.instance.setNativeAuthToken(authToken);

  static void _complete(Completer<void> completer) {
    if (!completer.isCompleted) completer.complete();
  }

  static void _fail(Completer<void> completer, CometChatCallsException e) {
    if (!completer.isCompleted) completer.completeError(e);
  }
}
