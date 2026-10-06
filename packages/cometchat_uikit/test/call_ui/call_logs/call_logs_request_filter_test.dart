/// What the call logs ask the server for (round 5, P5-C12; owner's P5-D12
/// A): 1:1 calls only by default (callCategory "call"), and a host's own
/// request builder exactly as given.
///
/// Meetings used to be listed by default, with an inert call icon, a
/// person's name as the title of a group call and a details screen that
/// never loaded. Android also forces "call" over a host's builder, which
/// leaves a host no way to show meetings; that part is not copied.
///
///   flutter test test/call_ui/call_logs/call_logs_request_filter_test.dart
library;

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/bloc/call_logs_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/bloc/call_logs_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/data/datasources/call_logs_local_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/data/repositories/call_logs_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_call_logs_remote.dart';

/// Pumps past the Calls-SDK wait in the first load (fake time).
Future<void> _settle(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 30));

Future<void> _close(WidgetTester tester, CallLogsBloc bloc) =>
    tester.runAsync<void>(bloc.close);

void main() {
  testWidgets('P5-C12 / P5-N14: by default the list asks for 1:1 calls only, '
      '30 a page', (tester) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [callLogPage('a', 2)],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(remote);

    bloc.add(const LoadCallLogs());
    await _settle(tester);

    final request = remote.requests.single;
    expect(request.callCategory, CometChatCallsConstants.callCategoryCall);
    expect(request.limit, 30);
    await _close(tester, bloc);
  });

  testWidgets('P5-C12: a host builder with no category reaches the server as '
      'given, meetings and all', (tester) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [callLogPage('a', 2)],
      },
    );
    final builder = CallLogRequestBuilder()
      ..limit = 10
      ..uid = 'bob'
      ..callType = 'video';
    final (:bloc, repository: _) = callLogsBlocOver(remote, builder: builder);

    bloc.add(const LoadCallLogs());
    await _settle(tester);

    final request = remote.requests.single;
    expect(request.callCategory, isNull);
    expect(request.limit, 10);
    expect(request.uid, 'bob');
    expect(request.callType, 'video');
    await _close(tester, bloc);
  });

  testWidgets('P5-C12: a host builder that asks for meetings only keeps its '
      'category', (tester) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [callLogPage('a', 2)],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(
      remote,
      builder: CallLogRequestBuilder()..callCategory = 'meet',
    );

    bloc.add(const LoadCallLogs());
    await _settle(tester);

    expect(remote.requests.single.callCategory, 'meet');
    await _close(tester, bloc);
  });

  test('P5-C12: the repository on its own also asks for 1:1 calls only', () {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [callLogPage('a', 1)],
      },
    );
    final repository = CallLogsRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: CallLogsLocalDataSourceImpl(),
    );

    return repository.getCallLogs(limit: 20).then((_) {
      expect(
        remote.requests.single.callCategory,
        CometChatCallsConstants.callCategoryCall,
      );
      expect(remote.requests.single.limit, 20);
    });
  });
}
