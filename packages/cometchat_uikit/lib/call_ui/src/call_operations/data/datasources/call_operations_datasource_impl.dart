import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../../../../cometchat_calls_uikit.dart';
import '../../../../../cometchat_chat_uikit.dart';
import 'start_session_deadline.dart';

/// Implementation of [CallOperationsDataSource] using CometChat SDK.
///
/// Uses [Completer] to bridge callback-based SDK APIs to async/await.
class CallOperationsDataSourceImpl implements CallOperationsDataSource {
  @override
  Future<Call> initiateCall(Call call) async {
    final completer = Completer<Call>();
    CometChatUIKitCalls.initiateCall(
      call,
      onSuccess: (Call returnedCall) => completer.complete(returnedCall),
      onError: (CometChatException e) => completer.completeError(
        CallOperationsException(
          message: e.message ?? 'Failed to initiate call',
          code: e.code,
          originalException: e,
        ),
      ),
    );
    return completer.future;
  }

  @override
  Future<Call> acceptCall(String sessionId) async {
    final completer = Completer<Call>();
    CometChat.acceptCall(
      sessionId,
      onSuccess: (Call acceptedCall) => completer.complete(acceptedCall),
      onError: (CometChatException e) => completer.completeError(
        CallOperationsException(
          message: e.message ?? 'Failed to accept call',
          code: e.code,
          originalException: e,
        ),
      ),
    );
    return completer.future;
  }

  @override
  Future<Call> rejectCall(String sessionId, String status) async {
    final completer = Completer<Call>();
    CometChatUIKitCalls.rejectCall(
      sessionId,
      status,
      onSuccess: (Call rejectedCall) => completer.complete(rejectedCall),
      onError: (CometChatException e) => completer.completeError(
        CallOperationsException(
          message: e.message ?? 'Failed to reject call',
          code: e.code,
          originalException: e,
        ),
      ),
    );
    return completer.future;
  }

  @override
  Future<Call> endCall(String sessionId) async {
    final completer = Completer<Call>();
    CometChat.endCall(
      sessionId,
      onSuccess: (Call call) => completer.complete(call),
      onError: (CometChatException e) => completer.completeError(
        CallOperationsException(
          message: e.message ?? 'Failed to end call',
          code: e.code,
          originalException: e,
        ),
      ),
    );
    return completer.future;
  }

  @override
  Future<String> generateCallToken(String sessionId) async {
    final completer = Completer<String>();
    CometChatUIKitCalls.generateToken(
      sessionId,
      onSuccess: (callToken) {
        final token = callToken.callToken;
        if (token == null) {
          completer.completeError(
            const CallOperationsException(
              message: 'Call token is null',
              code: 'NULL_TOKEN',
            ),
          );
        } else {
          completer.complete(token);
        }
      },
      onError: (CometChatCallsException e) => completer.completeError(
        CallOperationsException(
          message: e.message ?? 'Failed to generate call token',
          code: e.code,
          originalException: e,
        ),
      ),
    );
    return completer.future;
  }

  /// Joins [sessionId] and hands back the call view, within the 30 s limit
  /// of [joinWithDeadline].
  ///
  /// Since 6.2.0 the Android ongoing-call service is not started here (a
  /// change of behaviour): the UI Kit's call screen starts it once the join
  /// has landed and it is still the screen on show, and stops it when it
  /// leaves. It used to start on every successful join, a late one
  /// included, and the late one was undone by stopping the service
  /// app-wide, a newer call's too. A call screen of your own that joins
  /// through this starts it with `CometChatOngoingCallService.launch`.
  @override
  Future<Widget> startSession(String sessionId, SessionSettings settings) {
    return joinWithDeadline(
      (onSuccess, onError) => CometChatUIKitCalls.startSession(
        sessionId,
        settings,
        onSuccess: onSuccess,
        onError: onError,
        launchOngoingCallService: false,
      ),
    );
  }

  @override
  Future<void> endSession() async {
    final completer = Completer<void>();
    unawaited(
      CometChatUIKitCalls.endSession(
        onSuccess: (_) => completer.complete(),
        onError: (CometChatCallsException e) => completer.completeError(
          CallOperationsException(
            message: e.message ?? 'Failed to end session',
            code: e.code,
            originalException: e,
          ),
        ),
      ),
    );
    return completer.future;
  }

  @override
  Future<CustomMessage> sendCustomMessage(CustomMessage message) async {
    final completer = Completer<CustomMessage>();
    unawaited(
      CometChatUIKit.sendCustomMessage(
        message,
        onSuccess: (CustomMessage sent) => completer.complete(sent),
        onError: (CometChatException e) => completer.completeError(
          CallOperationsException(
            message: e.message ?? 'Failed to send custom message',
            code: e.code,
            originalException: e,
          ),
        ),
      ),
    );
    return completer.future;
  }

  @override
  Future<User?> getLoggedInUser() async {
    return await CometChatUIKit.getLoggedInUser();
  }

  @override
  Future<String?> getUserAuthToken() async {
    return await CometChat.getUserAuthToken();
  }

  @override
  Future<void> waitForCallsSdk() async {
    await CallEventService.instance.waitForCallsSdk();
  }
}
