import 'package:cometchat_sdk/cometchat_sdk.dart'
    show AppSettings, CometChat, CometChatException, User;
import 'package:flutter/foundation.dart';

/// The chat SDK calls `CometChatUIKit` makes to initialise, restore a session,
/// log in and log out.
///
/// Package-private (see `lib/src/`), like `CallsSdkGateway`. The methods have
/// the chat SDK's own shape, callbacks included, so a fake can behave the way
/// the SDK does: call `onSuccess` without awaiting it, then return. Tests put
/// a fake in with [debugInstance].
abstract interface class ChatAuthGateway {
  static ChatAuthGateway? _override;

  /// The gateway `CometChatUIKit` uses: the chat SDK, unless a test put a
  /// fake in.
  static ChatAuthGateway get instance =>
      _override ?? const DefaultChatAuthGateway();

  /// Replaces [instance] (null restores the chat SDK).
  @visibleForTesting
  static set debugInstance(ChatAuthGateway? gateway) => _override = gateway;

  /// `CometChat.init`.
  Future<void> init(
    String appId,
    AppSettings appSettings, {
    required Function(String successMessage)? onSuccess,
    required Function(CometChatException e)? onError,
  });

  /// `CometChat.login` with an auth key.
  Future<User?> login(
    String uid,
    String authKey, {
    required Function(User user)? onSuccess,
    required Function(CometChatException excep)? onError,
  });

  /// `CometChat.loginWithAuthToken`.
  Future<User?> loginWithAuthToken(
    String authToken, {
    required Function(User user)? onSuccess,
    required Function(CometChatException excep)? onError,
  });

  /// `CometChat.getLoggedInUser`.
  Future<User?> getLoggedInUser({
    Function(User user)? onSuccess,
    Function(CometChatException excep)? onError,
  });

  /// `CometChat.getUserAuthToken`: the logged-in user's auth token, or null.
  Future<String?> getUserAuthToken();

  /// `CometChat.logout`.
  Future<void> logout({
    required Function(String message)? onSuccess,
    required Function(CometChatException excep)? onError,
  });
}

/// [ChatAuthGateway] over the chat SDK's static `CometChat` API.
final class DefaultChatAuthGateway implements ChatAuthGateway {
  /// Creates the gateway.
  const DefaultChatAuthGateway();

  @override
  Future<void> init(
    String appId,
    AppSettings appSettings, {
    required Function(String successMessage)? onSuccess,
    required Function(CometChatException e)? onError,
  }) => CometChat.init(
    appId,
    appSettings,
    onSuccess: onSuccess,
    onError: onError,
  );

  @override
  Future<User?> login(
    String uid,
    String authKey, {
    required Function(User user)? onSuccess,
    required Function(CometChatException excep)? onError,
  }) =>
      // ignore: deprecated_member_use — authKey login is the intended UIKit flow
      CometChat.login(uid, authKey, onSuccess: onSuccess, onError: onError);

  @override
  Future<User?> loginWithAuthToken(
    String authToken, {
    required Function(User user)? onSuccess,
    required Function(CometChatException excep)? onError,
  }) => CometChat.loginWithAuthToken(
    authToken,
    onSuccess: onSuccess,
    onError: onError,
  );

  @override
  Future<User?> getLoggedInUser({
    Function(User user)? onSuccess,
    Function(CometChatException excep)? onError,
  }) => CometChat.getLoggedInUser(onSuccess: onSuccess, onError: onError);

  @override
  Future<String?> getUserAuthToken() => CometChat.getUserAuthToken();

  @override
  Future<void> logout({
    required Function(String message)? onSuccess,
    required Function(CometChatException excep)? onError,
  }) => CometChat.logout(onSuccess: onSuccess, onError: onError);
}
