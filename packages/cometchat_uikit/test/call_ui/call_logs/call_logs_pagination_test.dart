/// Call-log paging (round 5, P5-C15; owner's P5-D14 A), over the UI Kit's
/// own repository and a fake Calls SDK endpoint that pages like the real one.
///
/// Before: there was more only while pages had 30 rows, so a host builder
/// asking for 10 stopped after the first page; a page made only of rows
/// already listed ended paging; and a failed page dropped the request,
/// answered from the cache, and so stopped paging for good without a word.
/// Now a page that comes back empty is the end; a failed page keeps the list
/// and the request (same page, same filters), sets
/// `CallLogsState.loadMoreError`, and the next LoadMoreCallLogs retries it.
///
///   flutter test test/call_ui/call_logs/call_logs_pagination_test.dart
library;

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/bloc/call_logs_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/bloc/call_logs_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/bloc/call_logs_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/data/datasources/call_logs_local_datasource.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/data/repositories/call_logs_repository_impl.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_call_logs_remote.dart';

/// Pumps past the Calls-SDK wait in the first load, and any page fetch.
Future<void> _settle(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 30));

Future<void> _close(WidgetTester tester, CallLogsBloc bloc) =>
    tester.runAsync<void>(bloc.close);

List<String?> _ids(CallLogsBloc bloc) =>
    bloc.state.callLogs.map((log) => log.sessionId).toList();

void main() {
  testWidgets('P5-N19 / P5-C15: a host builder asking for 10 a page keeps '
      'paging until a page comes back empty', (tester) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [callLogPage('a', 10)],
        2: [callLogPage('b', 10, newest: 1600000000)],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(
      remote,
      builder: CallLogRequestBuilder()..limit = 10,
    );

    bloc.add(const LoadCallLogs());
    await _settle(tester);
    // Ten rows is a full page for this host: there may be more.
    expect(bloc.state.callLogs, hasLength(10));
    expect(bloc.state.hasMore, isTrue);

    bloc.add(const LoadMoreCallLogs());
    await _settle(tester);
    expect(bloc.state.callLogs, hasLength(20));
    expect(bloc.state.hasMore, isTrue);

    bloc.add(const LoadMoreCallLogs());
    await _settle(tester);
    expect(remote.pagesAsked, [1, 2, 3]);
    expect(bloc.state.callLogs, hasLength(20));
    expect(bloc.state.hasMore, isFalse);

    // Nothing more is asked once the end is reached.
    bloc.add(const LoadMoreCallLogs());
    await _settle(tester);
    expect(remote.pagesAsked, [1, 2, 3]);
    await _close(tester, bloc);
  });

  testWidgets('P5-E27: a failed page keeps the list and sets loadMoreError; '
      'the next load-more asks for the same page, with the same filters, '
      'appends it and clears the error', (tester) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [callLogPage('a', 30)],
        2: [remoteFailure(), callLogPage('b', 5, newest: 1600000000)],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(
      remote,
      builder: CallLogRequestBuilder()..uid = 'bob',
    );
    bloc.add(const LoadCallLogs());
    await _settle(tester);

    bloc.add(const LoadMoreCallLogs());
    await _settle(tester);
    expect(bloc.state.status, CallLogsStatus.loaded);
    expect(bloc.state.callLogs, hasLength(30));
    expect(bloc.state.loadMoreError, contains('offline'));
    expect(bloc.state.hasMore, isTrue);
    expect(bloc.state.isLoadingMore, isFalse);

    bloc.add(const LoadMoreCallLogs());
    await _settle(tester);
    expect(remote.pagesAsked, [1, 2, 2]);
    // The very request the failure left, so the host's filters still hold.
    expect(remote.requests[2], same(remote.requests[1]));
    expect(remote.requests[2].uid, 'bob');
    expect(bloc.state.callLogs, hasLength(35));
    expect(bloc.state.loadMoreError, isNull);
    await _close(tester, bloc);
  });

  testWidgets('P5-E27: an unexpected failure on a later page keeps the '
      'request too', (tester) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [callLogPage('a', 30)],
        2: [Exception('socket closed'), callLogPage('b', 2)],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(remote);
    bloc.add(const LoadCallLogs());
    await _settle(tester);

    bloc.add(const LoadMoreCallLogs());
    await _settle(tester);
    expect(bloc.state.loadMoreError, isNotNull);

    bloc.add(const LoadMoreCallLogs());
    await _settle(tester);
    expect(remote.pagesAsked, [1, 2, 2]);
    expect(remote.requests[2], same(remote.requests[1]));
    expect(bloc.state.callLogs, hasLength(32));
    await _close(tester, bloc);
  });

  testWidgets('P5-C15: a page of rows already listed does not end paging', (
    tester,
  ) async {
    // Newer calls push rows already listed into later pages; a page made
    // only of those used to be "nothing more".
    final remote = FakeCallLogsRemote(
      pages: {
        1: [callLogPage('a', 10)],
        2: [callLogPage('a', 10)],
        3: [callLogPage('c', 4, newest: 1600000000)],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(
      remote,
      builder: CallLogRequestBuilder()..limit = 10,
    );
    bloc.add(const LoadCallLogs());
    await _settle(tester);

    bloc.add(const LoadMoreCallLogs());
    await _settle(tester);
    expect(bloc.state.callLogs, hasLength(10));
    expect(bloc.state.hasMore, isTrue);

    bloc.add(const LoadMoreCallLogs());
    await _settle(tester);
    expect(remote.pagesAsked, [1, 2, 3]);
    expect(_ids(bloc), [
      for (var i = 0; i < 10; i++) 'a$i',
      for (var i = 0; i < 4; i++) 'c$i',
    ]);
    await _close(tester, bloc);
  });

  testWidgets('a fresh load clears a load-more error', (tester) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [callLogPage('a', 30)],
        2: [remoteFailure()],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(remote);
    bloc.add(const LoadCallLogs());
    await _settle(tester);
    bloc.add(const LoadMoreCallLogs());
    await _settle(tester);
    expect(bloc.state.loadMoreError, isNotNull);

    bloc.add(const RefreshCallLogs());
    await _settle(tester);
    expect(bloc.state.loadMoreError, isNull);
    expect(bloc.state.status, CallLogsStatus.loaded);
    await _close(tester, bloc);
  });

  group('CallLogsState.loadMoreError (P5-C15)', () {
    test('it tells two states apart, so a failure is never dropped as a '
        'repeat', () {
      const ok = CallLogsState(status: CallLogsStatus.loaded);
      expect(ok.copyWith(loadMoreError: 'offline'), isNot(ok));
      expect(
        ok.copyWith(loadMoreError: 'offline'),
        ok.copyWith(loadMoreError: 'offline'),
      );
    });

    test('copyWith keeps it unless cleared', () {
      final failed = const CallLogsState().copyWith(loadMoreError: 'offline');
      expect(failed.copyWith(hasMore: true).loadMoreError, 'offline');
      expect(failed.copyWith(clearLoadMoreError: true).loadMoreError, isNull);
      expect(const CallLogsState().loadMoreError, isNull);
    });
  });

  group('CallLogsRepositoryImpl paging (P5-C15)', () {
    CallLogsRepositoryImpl repositoryOver(FakeCallLogsRemote remote) =>
        CallLogsRepositoryImpl(
          remoteDataSource: remote,
          localDataSource: CallLogsLocalDataSourceImpl(),
        );

    test('a later page that fails is reported, not answered from the cache '
        '(which holds the first page)', () async {
      final remote = FakeCallLogsRemote(
        pages: {
          1: [callLogPage('a', 3)],
          2: [remoteFailure()],
        },
      );
      final repository = repositoryOver(remote);

      expect(await repository.getCallLogs(), isA<Success<List<CallLog>>>());
      final second = await repository.getCallLogs();
      expect(second, isA<Failure>());
      expect((second as Failure).message, contains('offline'));
    });

    test(
      'a first page that fails still falls back to the cached one',
      () async {
        final remote = FakeCallLogsRemote(
          pages: {
            1: [callLogPage('a', 3), remoteFailure()],
          },
        );
        final repository = repositoryOver(remote);
        await repository.getCallLogs();

        // The bloc's retry resets the request; the first page fails again.
        repository.resetRequest();
        final again = await repository.getCallLogs();
        expect(again, isA<Success<List<CallLog>>>());
        expect((again as Success<List<CallLog>>).data, hasLength(3));
      },
    );

    test('a later page does not replace the cached first page', () async {
      final remote = FakeCallLogsRemote(
        pages: {
          1: [callLogPage('a', 3), remoteFailure()],
          2: [callLogPage('b', 2)],
        },
      );
      final repository = repositoryOver(remote);
      await repository.getCallLogs();
      await repository.getCallLogs();

      repository.resetRequest();
      final fallback = await repository.getCallLogs();
      expect(
        (fallback as Success<List<CallLog>>).data.map((l) => l.sessionId),
        containsAll(<String>['a0', 'a1', 'a2']),
      );
    });
  });
}
