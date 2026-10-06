import 'package:cometchat_sdk/cometchat_sdk.dart'
    show CallListener, CometChat, ConnectionListener;
import 'package:flutter/foundation.dart';

/// Registers chat SDK call and connection listeners for the UI Kit's own
/// components (the call logs, the Chats list).
///
/// A seam: the chat SDK keeps its listener maps private, so a test cannot
/// reach a listener a component registered, nor tell it was removed. The
/// `debug` hooks replace the SDK calls in tests.
///
/// Package-private (see `lib/src/`).
abstract final class ChatSdkListeners {
  /// Registers [listener] for the chat SDK's call events under [id].
  static void addCallListener(String id, CallListener listener) =>
      (debugAddCallListener ?? CometChat.addCallListener)(id, listener);

  /// Removes the call listener registered under [id].
  static void removeCallListener(String id) =>
      (debugRemoveCallListener ?? CometChat.removeCallListener)(id);

  /// Registers [listener] for the chat SDK's connection events under [id].
  static void addConnectionListener(String id, ConnectionListener listener) =>
      (debugAddConnectionListener ?? CometChat.addConnectionListener)(
        id,
        listener,
      );

  /// Removes the connection listener registered under [id].
  static void removeConnectionListener(String id) =>
      (debugRemoveConnectionListener ?? CometChat.removeConnectionListener)(id);

  /// Replaces [addCallListener]'s SDK call in tests.
  @visibleForTesting
  static void Function(String id, CallListener listener)? debugAddCallListener;

  /// Replaces [removeCallListener]'s SDK call in tests.
  @visibleForTesting
  static void Function(String id)? debugRemoveCallListener;

  /// Replaces [addConnectionListener]'s SDK call in tests.
  @visibleForTesting
  static void Function(String id, ConnectionListener listener)?
  debugAddConnectionListener;

  /// Replaces [removeConnectionListener]'s SDK call in tests.
  @visibleForTesting
  static void Function(String id)? debugRemoveConnectionListener;

  /// Puts the SDK calls back.
  @visibleForTesting
  static void debugReset() {
    debugAddCallListener = null;
    debugRemoveCallListener = null;
    debugAddConnectionListener = null;
    debugRemoveConnectionListener = null;
  }
}
