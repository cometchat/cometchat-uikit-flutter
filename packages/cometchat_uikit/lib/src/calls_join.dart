import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show CometChatCalls, CometChatCallsException, SessionSettings;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/widgets.dart' show Widget;

/// How `CometChatUIKitCalls.startSession` asks the Calls SDK to join a
/// session: `CometChatCalls.joinSession` by session id.
///
/// Package-private (see `lib/src/`). A seam: the real join needs the network
/// and a device, and the tests of what the UI Kit does around it (the
/// Android ongoing-call service it starts, the "maybe in a session" mark)
/// replace it with one that answers when they say.
abstract final class CallsJoin {
  /// Joins `sessionId` with `sessionSettings`; `onSuccess` gets the call
  /// view, `onError` the Calls SDK's refusal.
  static JoinSession get joinSession => _join;

  /// Replaces the join (tests).
  @visibleForTesting
  static set joinSession(JoinSession join) => _join = join;

  static JoinSession _join = _joinSession;

  static void _joinSession({
    required String sessionId,
    required SessionSettings sessionSettings,
    required void Function(Widget?) onSuccess,
    required void Function(CometChatCallsException) onError,
  }) {
    unawaited(
      CometChatCalls.joinSession(
        sessionId: sessionId,
        sessionSettings: sessionSettings,
        onSuccess: onSuccess,
        onError: onError,
      ),
    );
  }

  /// Puts the Calls SDK's own join back, after a test replaced it.
  @visibleForTesting
  static void debugReset() => _join = _joinSession;
}

/// What [CallsJoin.joinSession] is.
typedef JoinSession =
    void Function({
      required String sessionId,
      required SessionSettings sessionSettings,
      required void Function(Widget?) onSuccess,
      required void Function(CometChatCallsException) onError,
    });
