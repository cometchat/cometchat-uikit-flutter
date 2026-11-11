import '../domain/repositories/call_operations_repository.dart';
import '../domain/usecases/initiate_call_usecase.dart';
import '../domain/usecases/accept_call_usecase.dart';
import '../domain/usecases/reject_call_usecase.dart';
import '../domain/usecases/end_call_usecase.dart';
import '../domain/usecases/generate_call_token_usecase.dart';
import '../domain/usecases/start_session_usecase.dart';
import '../domain/usecases/end_session_usecase.dart';
import '../domain/usecases/send_meeting_message_usecase.dart';
import '../domain/usecases/get_logged_in_user_usecase.dart';
import '../domain/usecases/get_user_auth_token_usecase.dart';
import '../data/datasources/call_operations_datasource.dart';
import '../data/datasources/call_operations_datasource_impl.dart';
import '../data/repositories/call_operations_repository_impl.dart';

/// Shared service locator for call operations used by
/// call_buttons, incoming_call, outgoing_call, and ongoing_call.
///
/// Singleton — call [setup] once during app startup.
class CallOperationsServiceLocator {
  static final CallOperationsServiceLocator _instance =
      CallOperationsServiceLocator._internal();
  CallOperationsServiceLocator._internal();
  static CallOperationsServiceLocator get instance => _instance;

  late CallOperationsDataSource _dataSource;
  late CallOperationsRepository _repository;

  late InitiateDirectCallUseCase _initiateCallUseCase;
  late AcceptCallUseCase _acceptCallUseCase;
  late RejectCallUseCase _rejectCallUseCase;
  // ignore: deprecated_member_use_from_same_package
  late EndCallUseCase _endCallUseCase;
  late GenerateCallTokenUseCase _generateCallTokenUseCase;
  late StartSessionUseCase _startSessionUseCase;
  late EndSessionUseCase _endSessionUseCase;
  late SendMeetingMessageUseCase _sendMeetingMessageUseCase;
  late GetCallLoggedInUserUseCase _getLoggedInUserUseCase;
  late GetUserAuthTokenUseCase _getUserAuthTokenUseCase;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  void setup({CallOperationsDataSource? dataSource}) {
    if (_isInitialized) return;

    _dataSource = dataSource ?? CallOperationsDataSourceImpl();
    _repository = CallOperationsRepositoryImpl(dataSource: _dataSource);

    _initiateCallUseCase = InitiateDirectCallUseCase(_repository);
    _acceptCallUseCase = AcceptCallUseCase(_repository);
    _rejectCallUseCase = RejectCallUseCase(_repository);
    // ignore: deprecated_member_use_from_same_package
    _endCallUseCase = EndCallUseCase(_repository);
    _generateCallTokenUseCase = GenerateCallTokenUseCase(_repository);
    _startSessionUseCase = StartSessionUseCase(_repository);
    _endSessionUseCase = EndSessionUseCase(_repository);
    _sendMeetingMessageUseCase = SendMeetingMessageUseCase(_repository);
    _getLoggedInUserUseCase = GetCallLoggedInUserUseCase(_repository);
    _getUserAuthTokenUseCase = GetUserAuthTokenUseCase(_repository);

    _isInitialized = true;
  }

  // Use case getters
  InitiateDirectCallUseCase get initiateCallUseCase {
    _ensureInitialized();
    return _initiateCallUseCase;
  }

  AcceptCallUseCase get acceptCallUseCase {
    _ensureInitialized();
    return _acceptCallUseCase;
  }

  RejectCallUseCase get rejectCallUseCase {
    _ensureInitialized();
    return _rejectCallUseCase;
  }

  @Deprecated(
    'Use endSessionUseCase instead: a joined call is left, not ended with '
    'the Chat SDK. The Chat SDK\'s calling APIs are deprecated (ringing v2).',
  )
  // ignore: deprecated_member_use_from_same_package
  EndCallUseCase get endCallUseCase {
    _ensureInitialized();
    return _endCallUseCase;
  }

  GenerateCallTokenUseCase get generateCallTokenUseCase {
    _ensureInitialized();
    return _generateCallTokenUseCase;
  }

  StartSessionUseCase get startSessionUseCase {
    _ensureInitialized();
    return _startSessionUseCase;
  }

  EndSessionUseCase get endSessionUseCase {
    _ensureInitialized();
    return _endSessionUseCase;
  }

  SendMeetingMessageUseCase get sendMeetingMessageUseCase {
    _ensureInitialized();
    return _sendMeetingMessageUseCase;
  }

  GetCallLoggedInUserUseCase get getLoggedInUserUseCase {
    _ensureInitialized();
    return _getLoggedInUserUseCase;
  }

  GetUserAuthTokenUseCase get getUserAuthTokenUseCase {
    _ensureInitialized();
    return _getUserAuthTokenUseCase;
  }

  CallOperationsRepository get repository {
    _ensureInitialized();
    return _repository;
  }

  /// Ensures the service locator is initialized.
  /// Auto-initializes with default datasource on first access.
  void _ensureInitialized() {
    if (!_isInitialized) {
      setup();
    }
  }

  Future<void> reset() async {
    _isInitialized = false;
  }
}
