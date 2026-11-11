import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import '../../../../../shared_ui/src/clean_architecture/core/result.dart';
import '../repositories/call_operations_repository.dart';

/// Use case for ending an active call via CometChat SDK.
@Deprecated(
  'Use EndSessionUseCase instead: a joined call is left, not ended with the '
  'Chat SDK. The Chat SDK\'s calling APIs are deprecated (ringing v2).',
)
class EndCallUseCase {
  final CallOperationsRepository repository;
  const EndCallUseCase(this.repository);

  Future<Result<Call>> call(String sessionId) async {
    if (sessionId.isEmpty) {
      return const Failure(
        message: 'Session ID is required',
        code: 'MISSING_SESSION_ID',
      );
    }
    // ignore: deprecated_member_use_from_same_package
    return repository.endCall(sessionId);
  }
}
