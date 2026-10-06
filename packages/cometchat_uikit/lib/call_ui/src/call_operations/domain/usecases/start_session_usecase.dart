import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:flutter/widgets.dart';
import '../../../../../shared_ui/src/clean_architecture/core/result.dart';
import '../repositories/call_operations_repository.dart';

/// Use case for starting a call session with a session ID and settings.
/// The SDK generates the call token internally.
///
/// Since 6.2.0 this does not start the Android ongoing-call service: see
/// `CallOperationsDataSource.startSession`.
class StartSessionUseCase {
  final CallOperationsRepository repository;
  const StartSessionUseCase(this.repository);

  Future<Result<Widget>> call(
    String sessionId,
    SessionSettings settings,
  ) async {
    if (sessionId.isEmpty) {
      return const Failure(
        message: 'Session ID is required',
        code: 'MISSING_SESSION_ID',
      );
    }
    return repository.startSession(sessionId, settings);
  }
}
