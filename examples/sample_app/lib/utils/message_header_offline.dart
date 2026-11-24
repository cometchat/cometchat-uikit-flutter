import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// The kit's single offline switch (UIK-GATE-01: the only `isOfflineEnabled`
// read in chat_uikit/lib and master_app/lib). Not exported by the barrel.
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_gate.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// The app's helper for a chat opened by id (push, deep link): resolves the
/// `User` or `Group` the message header and list need, without blocking
/// offline. App-local (ENG-41131), not kit API.
///
/// With offline off it makes today's `CometChat.getUser` / `getGroup` call
/// exactly. With offline on it reads the conversation in two rounds
/// (`CometChat.getConversation` with a `ConversationDetailsListener`) and opens
/// the chat on the **first** conversation it gets, cached or server, so a
/// cached chat opens with no network. When neither round delivers one (no
/// cached conversation, and the server read failed or found none), it falls
/// back to today's call, so an online open of a chat that has no conversation
/// yet still works.
///
/// It never hangs: the read also settles when the SDK call ends without any
/// listener callback (the SDK reports some failures only through `onError`,
/// which this read does not pass), and after [MessageHeaderOfflineSeams.settleTimeout]
/// at the latest. The caller's `onUser` / `onGroup` runs after the read has
/// settled, outside the SDK call, so a callback that throws cannot stall it.
abstract final class MessageHeaderOffline {
  /// Resolves the chat [id] of [receiverType] (`'user'` / `'group'`) and calls
  /// [onUser] or [onGroup] at most once; [onError] gets today's error when
  /// nothing resolves.
  static Future<void> fetchChatById(
    String id,
    String receiverType, {
    required void Function(User user) onUser,
    required void Function(Group group) onGroup,
    required void Function(CometChatException e) onError,
  }) async {
    final isUser = receiverType == 'user';
    Future<void> today() => isUser
        ? MessageHeaderOfflineSeams.getUser(id, onUser, onError)
        : MessageHeaderOfflineSeams.getGroup(id, onGroup, onError);

    if (!OfflineGate.isOn()) return today();

    Object? chatOf(Conversation c) {
      final w = c.conversationWith;
      if (isUser && w is User) return w;
      if (!isUser && w is Group) return w;
      return null;
    }

    // Completes on the first conversation that opens the chat (the cached
    // round needs no network), or with null when the read ends without one.
    final found = Completer<Object?>();
    void settle(Object? chat) {
      if (!found.isCompleted) found.complete(chat);
    }

    final read = Future<void>.sync(
      () => MessageHeaderOfflineSeams.getConversation(
        id,
        receiverType,
        _DetailsListener(
          cached: (c) {
            final chat = chatOf(c);
            if (chat != null) settle(chat);
          },
          server: (c) => settle(chatOf(c)),
          failed: (_) => settle(null),
        ),
      ),
    );
    // The SDK call can end with no callback at all; its end settles the read.
    unawaited(read.then((_) => settle(null), onError: (_) => settle(null)));

    final chat = await found.future.timeout(
      MessageHeaderOfflineSeams.settleTimeout,
      onTimeout: () => null,
    );
    if (chat is User) return onUser(chat);
    if (chat is Group) return onGroup(chat);
    return today();
  }
}

/// Test seams for [MessageHeaderOffline]; default to the SDK.
@visibleForTesting
abstract final class MessageHeaderOfflineSeams {
  /// The longest an offline-on open waits for the conversation read before
  /// falling back to today's call.
  static Duration settleTimeout = _defaultSettleTimeout;
  static const Duration _defaultSettleTimeout = Duration(seconds: 15);

  /// The two-phase conversation read; completes when the SDK call ends.
  static Future<void> Function(
    String id,
    String type,
    ConversationDetailsListener listener,
  )
  getConversation = _sdkGetConversation;

  /// Today's user read.
  static Future<void> Function(
    String uid,
    void Function(User) onSuccess,
    void Function(CometChatException) onError,
  )
  getUser = _sdkGetUser;

  /// Today's group read.
  static Future<void> Function(
    String guid,
    void Function(Group) onSuccess,
    void Function(CometChatException) onError,
  )
  getGroup = _sdkGetGroup;

  /// Restores the SDK defaults (tests).
  static void reset() {
    settleTimeout = _defaultSettleTimeout;
    getConversation = _sdkGetConversation;
    getUser = _sdkGetUser;
    getGroup = _sdkGetGroup;
  }

  static Future<void> _sdkGetConversation(
    String id,
    String type,
    ConversationDetailsListener listener,
  ) => CometChat.getConversation(
    id,
    type,
    onSuccess: null,
    onError: null,
    listener: listener,
  );

  static Future<void> _sdkGetUser(
    String uid,
    void Function(User) onSuccess,
    void Function(CometChatException) onError,
  ) => CometChat.getUser(uid, onSuccess: onSuccess, onError: onError);

  static Future<void> _sdkGetGroup(
    String guid,
    void Function(Group) onSuccess,
    void Function(CometChatException) onError,
  ) => CometChat.getGroup(guid, onSuccess: onSuccess, onError: onError);
}

class _DetailsListener implements ConversationDetailsListener {
  _DetailsListener({
    required this.cached,
    required this.server,
    required this.failed,
  });

  final void Function(Conversation) cached;
  final void Function(Conversation) server;
  final void Function(CometChatException) failed;

  @override
  void onCachedConversation(Conversation conversation) => cached(conversation);

  @override
  void onServerConversation(Conversation conversation) => server(conversation);

  @override
  void onError(CometChatException e) => failed(e);
}
