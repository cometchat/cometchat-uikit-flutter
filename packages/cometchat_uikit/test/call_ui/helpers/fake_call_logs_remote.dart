import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/bloc/call_logs_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/data/datasources/call_logs_local_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/data/datasources/call_logs_remote_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/data/repositories/call_logs_repository_impl.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/domain/usecases/get_call_logs_usecase.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/domain/usecases/initiate_call_usecase.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/domain/usecases/load_more_call_logs_usecase.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;

/// A Calls SDK call-log endpoint behind the UI Kit's own
/// [CallLogsRepositoryImpl], for the call-log tests that need the real
/// repository: its request handling, its paging, and the bloc's silent
/// refresh, which reads the first page through the remote data source.
///
/// Every request is recorded with the page it asked for. Answers are
/// scripted per page number (see [pages]); like the SDK's
/// `CallLogRequest.fetchNext`, a successful answer moves the request's
/// cursor to that page, a failure leaves it where it was.
class FakeCallLogsRemote implements CallLogsRemoteDataSource {
  FakeCallLogsRemote({Map<int, List<Object>>? pages})
    : pages = pages ?? <int, List<Object>>{};

  /// Answers per page number, used in order: a `List<CallLog>`, or an
  /// [Exception] to throw. The last answer for a page repeats. A page with
  /// no answers is empty, the last page.
  final Map<int, List<Object>> pages;

  /// Every request asked, in order.
  final List<CallLogRequest> requests = <CallLogRequest>[];

  /// The page each request asked for, in order.
  final List<int> pagesAsked = <int>[];

  /// When set, every fetch waits for it before answering.
  Completer<void>? gate;

  final Map<int, int> _answered = <int, int>{};

  /// The logged-in user [getLoggedInUser] answers with.
  User? loggedInUser;

  @override
  Future<List<CallLog>> getCallLogs(CallLogRequest request) async {
    requests.add(request);
    final page = request.currentPage + 1;
    pagesAsked.add(page);
    await gate?.future;
    final answers = pages[page];
    if (answers == null || answers.isEmpty) {
      request.totalPages = request.currentPage;
      return <CallLog>[];
    }
    final index = _answered[page] ?? 0;
    _answered[page] = index + 1;
    final answer = answers[index < answers.length ? index : answers.length - 1];
    if (answer is Exception) throw answer;
    request.currentPage = page;
    return answer as List<CallLog>;
  }

  @override
  Future<User?> getLoggedInUser() async => loggedInUser;

  @override
  Future<Call> initiateCall(Call call) async => call;

  @override
  Future<String?> getUserAuthToken() async => 'token';
}

/// A remote failure, as the data source reports one.
CallLogsRemoteDataSourceException remoteFailure([String message = 'offline']) =>
    CallLogsRemoteDataSourceException(message: message, code: 'ERR_NETWORK');

/// A [CallLogsBloc] over the UI Kit's own repository, fetching through
/// [remote].
({CallLogsBloc bloc, CallLogsRepositoryImpl repository}) callLogsBlocOver(
  FakeCallLogsRemote remote, {
  CallLogRequestBuilder? builder,
  void Function(Exception error)? onError,
}) {
  final repository = CallLogsRepositoryImpl(
    remoteDataSource: remote,
    localDataSource: CallLogsLocalDataSourceImpl(),
  );
  final bloc = CallLogsBloc(
    getCallLogsUseCase: GetCallLogsUseCase(repository),
    loadMoreCallLogsUseCase: LoadMoreCallLogsUseCase(repository),
    initiateCallUseCase: InitiateCallUseCase(repository),
    getLoggedInUserUseCase: GetLoggedInUserUseCase(repository),
    callLogsRequestBuilder: builder,
    errorCallback: onError,
  );
  return (bloc: bloc, repository: repository);
}

/// [count] call logs, newest first, with session ids `<prefix>0`...
List<CallLog> callLogPage(
  String prefix,
  int count, {
  int newest = 1700000000,
}) => List<CallLog>.generate(
  count,
  (i) => CallLog(
    sessionId: '$prefix$i',
    initiatedAt: newest - i,
    type: 'audio',
    status: 'ended',
  ),
);
