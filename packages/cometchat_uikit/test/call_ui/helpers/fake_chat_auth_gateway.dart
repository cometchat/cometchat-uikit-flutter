/// A scriptable chat SDK behind `ChatAuthGateway`, for the tests of
/// `CometChatUIKit` init, login and logout.
library;

import 'package:cometchat_chat_uikit/src/calls_lifecycle.dart';
import 'package:cometchat_chat_uikit/src/chat_auth_gateway.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';

/// The chat SDK, as `CometChatUIKit` sees it. Like the real one, a login
/// notifies the login listeners, then calls onSuccess without awaiting it,
/// then returns.
class FakeChatAuthGateway implements ChatAuthGateway {
  FakeChatAuthGateway(this.log);

  /// Shared with the test, so host callbacks can be ordered against it.
  final List<String> log;

  /// The user the chat SDK has a session for.
  User? loggedInUser;

  /// The chat SDK's auth token for [loggedInUser].
  String? authToken;

  /// Makes `init` fail.
  CometChatException? initError;

  /// Makes `login` / `loginWithAuthToken` fail.
  CometChatException? loginError;

  /// Whether a login notifies the UI Kit's out-of-band login listener before
  /// onSuccess, as `CometChat.login` does once `CometChatUIKit.init` ran.
  bool notifyLoginListener = true;

  /// Who each auth token belongs to.
  final Map<String, User> usersByToken = <String, User>{};

  @override
  Future<void> init(
    String appId,
    AppSettings appSettings, {
    required Function(String successMessage)? onSuccess,
    required Function(CometChatException e)? onError,
  }) async {
    log.add('chat init');
    final error = initError;
    if (error != null) {
      onError?.call(error);
      return;
    }
    onSuccess?.call('initialized');
    log.add('chat init returned');
  }

  @override
  Future<User?> login(
    String uid,
    String authKey, {
    required Function(User user)? onSuccess,
    required Function(CometChatException excep)? onError,
  }) async {
    log.add('chat login:$uid');
    return _complete(
      User(uid: uid, name: uid),
      'chat-token-$uid',
      onSuccess,
      onError,
    );
  }

  @override
  Future<User?> loginWithAuthToken(
    String authToken, {
    required Function(User user)? onSuccess,
    required Function(CometChatException excep)? onError,
  }) async {
    log.add('chat loginWithAuthToken:$authToken');
    final user = usersByToken[authToken] ?? User(uid: 'uid-x', name: 'X');
    return _complete(user, authToken, onSuccess, onError);
  }

  User? _complete(
    User user,
    String token,
    Function(User user)? onSuccess,
    Function(CometChatException excep)? onError,
  ) {
    final error = loginError;
    if (error != null) {
      onError?.call(error);
      return null;
    }
    loggedInUser = user;
    authToken = token;
    if (notifyLoginListener) {
      CallsLifecycle.debugLoginListener.loginSuccess(user);
    }
    onSuccess?.call(user);
    log.add('chat login returned');
    return user;
  }

  @override
  Future<User?> getLoggedInUser({
    Function(User user)? onSuccess,
    Function(CometChatException excep)? onError,
  }) async {
    final user = loggedInUser;
    if (user != null) onSuccess?.call(user);
    return user;
  }

  @override
  Future<String?> getUserAuthToken() async => authToken;

  /// Makes `logout` fail.
  CometChatException? logoutError;

  /// Like the real one: the login listeners hear of a successful logout
  /// before onSuccess, which is not awaited.
  @override
  Future<void> logout({
    required Function(String message)? onSuccess,
    required Function(CometChatException excep)? onError,
  }) async {
    log.add('chat logout');
    final error = logoutError;
    if (error != null) {
      onError?.call(error);
      return;
    }
    loggedInUser = null;
    authToken = null;
    if (notifyLoginListener) {
      CallsLifecycle.debugLoginListener.logoutSuccess();
    }
    onSuccess?.call('logged out');
  }
}
