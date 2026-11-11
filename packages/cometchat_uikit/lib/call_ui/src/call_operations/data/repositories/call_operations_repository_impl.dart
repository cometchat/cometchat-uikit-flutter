import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import 'package:flutter/widgets.dart';

import '../../../../../shared_ui/src/clean_architecture/core/result.dart';
import '../../domain/repositories/call_operations_repository.dart';
import '../datasources/call_operations_datasource.dart';

/// Implementation of [CallOperationsRepository].
/// Wraps datasource calls in [Result] for consistent error handling.
class CallOperationsRepositoryImpl implements CallOperationsRepository {
  final CallOperationsDataSource dataSource;

  const CallOperationsRepositoryImpl({required this.dataSource});

  @override
  Future<Result<Call>> initiateCall(Call call) async {
    try {
      final result = await dataSource.initiateCall(call);
      return Success(result);
    } on CallOperationsException catch (e) {
      return Failure(
        message: e.message,
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(message: 'Unexpected error initiating call: $e');
    }
  }

  @override
  Future<Result<Call>> acceptCall(String sessionId) async {
    try {
      final result = await dataSource.acceptCall(sessionId);
      return Success(result);
    } on CallOperationsException catch (e) {
      return Failure(
        message: e.message,
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(message: 'Unexpected error accepting call: $e');
    }
  }

  @override
  Future<Result<Call>> rejectCall(String sessionId, String status) async {
    try {
      final result = await dataSource.rejectCall(sessionId, status);
      return Success(result);
    } on CallOperationsException catch (e) {
      return Failure(
        message: e.message,
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(message: 'Unexpected error rejecting call: $e');
    }
  }

  @override
  Future<Result<Call>> endCall(String sessionId) async {
    try {
      // ignore: deprecated_member_use_from_same_package
      final result = await dataSource.endCall(sessionId);
      return Success(result);
    } on CallOperationsException catch (e) {
      return Failure(
        message: e.message,
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(message: 'Unexpected error ending call: $e');
    }
  }

  @override
  Future<Result<String>> generateCallToken(String sessionId) async {
    try {
      final token = await dataSource.generateCallToken(sessionId);
      return Success(token);
    } on CallOperationsException catch (e) {
      return Failure(
        message: e.message,
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(message: 'Unexpected error generating call token: $e');
    }
  }

  @override
  Future<Result<Widget>> startSession(
    String sessionId,
    SessionSettings settings,
  ) async {
    try {
      final widget = await dataSource.startSession(sessionId, settings);
      return Success(widget);
    } on CallOperationsException catch (e) {
      return Failure(
        message: e.message,
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(message: 'Unexpected error starting session: $e');
    }
  }

  @override
  Future<Result<void>> endSession() async {
    try {
      await dataSource.endSession();
      return const Success(null);
    } on CallOperationsException catch (e) {
      return Failure(
        message: e.message,
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(message: 'Unexpected error ending session: $e');
    }
  }

  @override
  Future<Result<CustomMessage>> sendCustomMessage(CustomMessage message) async {
    try {
      final result = await dataSource.sendCustomMessage(message);
      return Success(result);
    } on CallOperationsException catch (e) {
      return Failure(
        message: e.message,
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(message: 'Unexpected error sending custom message: $e');
    }
  }

  @override
  Future<Result<User?>> getLoggedInUser() async {
    try {
      final user = await dataSource.getLoggedInUser();
      return Success(user);
    } catch (e) {
      return Failure(message: 'Failed to get logged-in user: $e');
    }
  }

  @override
  Future<Result<String?>> getUserAuthToken() async {
    try {
      final token = await dataSource.getUserAuthToken();
      return Success(token);
    } catch (e) {
      return Failure(message: 'Failed to get user auth token: $e');
    }
  }

  @override
  Future<void> waitForCallsSdk() async {
    await dataSource.waitForCallsSdk();
  }
}
