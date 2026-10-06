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
  Future<Call> initiateCall(Call call);
  Future<Call> acceptCall(String sessionId);
  Future<Call> rejectCall(String sessionId, String status);
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
