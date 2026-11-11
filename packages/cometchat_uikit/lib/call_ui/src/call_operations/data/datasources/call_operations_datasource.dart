import 'dart:async';
import 'package:flutter/widgets.dart';

import '../../../../../cometchat_calls_uikit.dart';

/// Exception thrown when call operations fail.
class CallOperationsException implements Exception {
  final String message;
  final String? code;
  final Exception? originalException;

  const CallOperationsException({
    required this.message,
    this.code,
    this.originalException,
  });

  @override
  String toString() =>
      'CallOperationsException(message: $message, code: $code)';
}

/// Abstract interface for call operations data source.
abstract class CallOperationsDataSource {
  /// Places [call] and returns it as the server has it.
  ///
  /// Since ringing v2 the UI Kit's own implementation places it with the
  /// Calls SDK (`CometChatUIKitCalls.initiateCall`), on web with the chat SDK.
  Future<Call> initiateCall(Call call);

  /// Answers the incoming call [sessionId] and returns it, now ongoing.
  ///
  /// Since ringing v2 the UI Kit's own implementation answers through the
  /// app's push ringer (`CometChatUIKitCalls.acceptCall`), or with the chat
  /// SDK when there is none.
  Future<Call> acceptCall(String sessionId);

  /// Ends [sessionId] before it is joined with [status] (`rejected`, `busy`,
  /// `cancelled`, `unanswered`) and returns the call message of that status.
  ///
  /// Since ringing v2 the UI Kit's own implementation ends it with the Calls
  /// SDK (`CometChatUIKitCalls.rejectCall`), on web with the chat SDK.
  Future<Call> rejectCall(String sessionId, String status);
  @Deprecated(
    'Use endSession instead: a joined call is left, not ended with the Chat '
    'SDK. The Chat SDK\'s calling APIs are deprecated (ringing v2).',
  )
  Future<Call> endCall(String sessionId);
  Future<String> generateCallToken(String sessionId);

  /// Joins [sessionId] with [settings] and returns the call view.
  ///
  /// Since 6.2.0 the UI Kit's own implementation
  /// (`CallOperationsDataSourceImpl`) no longer starts the Android
  /// ongoing-call service ("Call in progress"): the UI Kit's call screen
  /// starts it once the call view is back and the screen is still up, and
  /// stops it when it leaves. A call screen of your own that joins through
  /// this (or through `CallOperationsRepository.startSession` or
  /// `StartSessionUseCase`) starts it with
  /// `CometChatOngoingCallService.launch(isVideo: ...)`.
  Future<Widget> startSession(String sessionId, SessionSettings settings);

  /// Leaves the media session.
  ///
  /// The UI Kit's own implementation also stops the Android ongoing-call
  /// service, through `CometChatUIKitCalls.endSession`. The UI Kit's call
  /// screen stops the service it started itself, so an implementation of
  /// your own may only leave.
  Future<void> endSession();
  Future<CustomMessage> sendCustomMessage(CustomMessage message);
  Future<User?> getLoggedInUser();
  Future<String?> getUserAuthToken();
  Future<void> waitForCallsSdk();
}
