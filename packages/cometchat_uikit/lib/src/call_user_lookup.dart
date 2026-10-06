import 'package:cometchat_sdk/cometchat_sdk.dart'
    show CometChat, CometChatException, User;
import 'package:flutter/foundation.dart';

/// Fetches the user a call from a call log goes to: their real name and
/// avatar for the outgoing call screen, and whether either side has blocked
/// the other.
///
/// Package-private (see `lib/src/`). A seam rather than a method on the
/// call logs repository: `CallLogsRepository` and its datasource are
/// exported interfaces, and a new member would break every implementation a
/// host has written.
abstract final class CallUserLookup {
  /// Fetches the user with [uid], or throws the SDK's [CometChatException].
  static Future<User> fetchUser(String uid) =>
      (debugFetchUser ?? _fromSdk)(uid);

  /// Replaces [fetchUser] in tests.
  @visibleForTesting
  static Future<User> Function(String uid)? debugFetchUser;

  static Future<User> _fromSdk(String uid) async {
    CometChatException? error;
    final user = await CometChat.getUser(
      uid,
      onSuccess: (_) {},
      onError: (CometChatException e) => error = e,
    );
    if (user != null) return user;
    throw error ??
        CometChatException(
          'ERR_UID_NOT_FOUND',
          'No user with uid $uid.',
          'The user could not be fetched.',
        );
  }
}
