import 'dart:async';
import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;

/// Exception thrown when remote data source operations fail
class CallLogsRemoteDataSourceException implements Exception {
  final String message;
  final String? code;
  final Exception? originalException;

  const CallLogsRemoteDataSourceException({
    required this.message,
    this.code,
    this.originalException,
  });

  @override
  String toString() =>
      'CallLogsRemoteDataSourceException(message: $message, code: $code)';
}

/// Abstract interface for call logs remote data source.
/// Handles all interactions with CometChat Calls SDK.
abstract class CallLogsRemoteDataSource {
  /// Fetches call logs with optional pagination.
  ///
  /// [request] - The CallLogRequest for fetching call logs
  Future<List<CallLog>> getCallLogs(CallLogRequest request);

  /// Gets the currently logged-in user.
  Future<User?> getLoggedInUser();

  /// Initiates a call with the specified call object.
  ///
  /// [call] - The call object containing receiver details and call type
  Future<Call> initiateCall(Call call);

  /// Gets the authentication token for the current user.
  Future<String?> getUserAuthToken();
}

/// Implementation of CallLogsRemoteDataSource using CometChat Calls SDK.
///
/// Uses the SDK's CallLogRequest.fetchNext() exclusively.
/// No REST fallback — the Calls REST API requires a server-side apikey
/// which is not available on the client.
class CallLogsRemoteDataSourceImpl implements CallLogsRemoteDataSource {
  @override
  Future<List<CallLog>> getCallLogs(CallLogRequest request) async {
    try {
      final completer = Completer<List<CallLog>>();

      unawaited(
        request.fetchNext(
          onSuccess: (List<CallLog> callLogs) {
            if (!completer.isCompleted) {
              completer.complete(callLogs);
            }
          },
          onError: (CometChatCallsException exception) {
            if (!completer.isCompleted) {
              completer.completeError(
                CallLogsRemoteDataSourceException(
                  message: exception.message ?? 'Failed to fetch call logs',
                  code: exception.code,
                  originalException: exception,
                ),
              );
            }
          },
        ),
      );

      return await completer.future;
    } on CallLogsRemoteDataSourceException {
      rethrow;
    } on CometChatCallsException catch (e) {
      throw CallLogsRemoteDataSourceException(
        message: e.message ?? 'Failed to fetch call logs',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      if (e is CallLogsRemoteDataSourceException) rethrow;
      throw CallLogsRemoteDataSourceException(
        message: 'Unexpected error while fetching call logs: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<User?> getLoggedInUser() async {
    try {
      final completer = Completer<User?>();

      unawaited(
        CometChat.getLoggedInUser(
          onSuccess: (User user) {
            if (!completer.isCompleted) {
              completer.complete(user);
            }
          },
          onError: (CometChatException exception) {
            if (!completer.isCompleted) {
              completer.completeError(
                CallLogsRemoteDataSourceException(
                  message: exception.message ?? 'Failed to get logged-in user',
                  code: exception.code,
                  originalException: exception,
                ),
              );
            }
          },
        ),
      );

      return await completer.future;
    } on CallLogsRemoteDataSourceException {
      rethrow;
    } catch (e) {
      throw CallLogsRemoteDataSourceException(
        message:
            'Unexpected error while getting logged-in user: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Call> initiateCall(Call call) async {
    try {
      final completer = Completer<Call>();

      CometChat.initiateCall(
        call,
        onSuccess: (Call returnedCall) {
          if (!completer.isCompleted) {
            completer.complete(returnedCall);
          }
        },
        onError: (CometChatException exception) {
          if (!completer.isCompleted) {
            completer.completeError(
              CallLogsRemoteDataSourceException(
                message: exception.message ?? 'Failed to initiate call',
                code: exception.code,
                originalException: exception,
              ),
            );
          }
        },
      );

      return await completer.future;
    } on CallLogsRemoteDataSourceException {
      rethrow;
    } catch (e) {
      throw CallLogsRemoteDataSourceException(
        message: 'Unexpected error while initiating call: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<String?> getUserAuthToken() async {
    try {
      return await CometChat.getUserAuthToken();
    } catch (e) {
      throw CallLogsRemoteDataSourceException(
        message: 'Failed to get user auth token: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }
}
