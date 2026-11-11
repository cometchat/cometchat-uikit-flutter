import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show CometChatCalls, IncomingCallListener, InitiatedCall;
import 'package:cometchat_sdk/cometchat_sdk.dart'
    show BaseMessage, Call, CometChat;
import 'package:flutter/foundation.dart';

import '../shared_ui/src/constants/ui_kit_constants.dart'
    show CallStatusConstants;
import '../shared_ui/src/logging/cometchat_log.dart';
import 'ringing_call_mapping.dart';

/// Tells the UI Kit's components that show call messages (the Chats list,
/// the message list) that a call started or stopped ringing, on either side,
/// through the Calls SDK's incoming call listener (ringing v2, Android and
/// iOS).
///
/// It replaces the chat SDK's call listener there, deprecated with the rest
/// of its calling APIs and kept on web only, as Android's UI Kit does
/// (`CometChatConversationsViewModel`, `CometChatMessageListViewModel`). The
/// app's push ringer hands every ringing call to the Calls SDK, which
/// reports `onIncomingCallReceived` when it rings on the callee, and
/// `onIncomingCallEnded` once when it stops ringing, on the callee and on
/// the caller ([OutgoingCallWatch]). Nothing is reported without a push
/// ringer (`UIKitSettings.callPushBridge`).
///
/// Package-private (see `lib/src/`).
abstract final class CallActivityListener {
  /// Calls [onCall] with the [Call] each time a call starts or stops
  /// ringing, until [remove]d. Nothing on web.
  static void add(String id, void Function(Call call) onCall) {
    if (kIsWeb) return;
    addIncomingCallListener(id, _CallActivityObserver(onCall));
  }

  /// Removes the listener added under [id]. Nothing on web.
  static void remove(String id) {
    if (kIsWeb) return;
    removeIncomingCallListener(id);
  }

  /// [call] as it started ringing: initiated, with its call message's ID.
  static Call started(InitiatedCall call) =>
      RingingCallMapping.fromInitiated(call);

  /// [call] as it stopped ringing for [reason]: answered (`ongoing`) or
  /// ended, with no call message ID. Null for a reason that says nothing of
  /// the call (iOS's `filtered`).
  static Call? stopped(InitiatedCall call, String reason) {
    final status = switch (reason.toLowerCase()) {
      // Android reports an answer as the call's status; iOS as CallKit's.
      'ongoing' ||
      'answered' ||
      'answeredelsewhere' => CallStatusConstants.ongoing,
      _ => RingingCallMapping.endStatusForReason(reason),
    };
    if (status == null) return null;
    return RingingCallMapping.withStatus(
      RingingCallMapping.fromInitiated(call),
      status,
    );
  }

  /// Reads the call message [messageId] from the server, or null when it
  /// could not. A call message keeps its ID while its status moves on, so a
  /// call's bubble already on screen is re-read for its new status.
  static Future<BaseMessage?> fetchMessage(int messageId) =>
      debugFetchMessage?.call(messageId) ?? _fetchMessage(messageId);

  static Future<BaseMessage?> _fetchMessage(int messageId) async {
    try {
      return await CometChat.getMessageDetails(messageId);
    } catch (e) {
      ccLog('CallActivityListener: reading message $messageId failed: $e');
      return null;
    }
  }

  /// Replaces [fetchMessage]'s SDK call in tests.
  @visibleForTesting
  static Future<BaseMessage?> Function(int messageId)? debugFetchMessage;

  /// Registers the Calls SDK's incoming call listener (tests).
  @visibleForTesting
  static void Function(String id, IncomingCallListener listener)
  addIncomingCallListener = CometChatCalls.addIncomingCallListener;

  /// Removes it (tests).
  @visibleForTesting
  static void Function(String id) removeIncomingCallListener =
      CometChatCalls.removeIncomingCallListener;

  /// Puts the Calls SDK back, after a test replaced it.
  @visibleForTesting
  static void debugReset() {
    addIncomingCallListener = CometChatCalls.addIncomingCallListener;
    removeIncomingCallListener = CometChatCalls.removeIncomingCallListener;
    debugFetchMessage = null;
  }
}

final class _CallActivityObserver extends IncomingCallListener {
  _CallActivityObserver(this._onCall);

  final void Function(Call call) _onCall;

  @override
  void onIncomingCallReceived(InitiatedCall call) {
    try {
      _onCall(CallActivityListener.started(call));
    } catch (e, stackTrace) {
      ccLog('CallActivityListener: ${call.sessionId} started: $e\n$stackTrace');
    }
  }

  @override
  void onIncomingCallEnded(InitiatedCall call, String reason) {
    try {
      final stopped = CallActivityListener.stopped(call, reason);
      if (stopped != null) _onCall(stopped);
    } catch (e, stackTrace) {
      ccLog('CallActivityListener: ${call.sessionId} ended: $e\n$stackTrace');
    }
  }
}
