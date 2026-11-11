/// The call logs keep themselves current (round 5, P5-C14; owner's P5-D13
/// A, "Android triggers + merge").
///
/// Before there were no listeners at all: the list was stale until the
/// screen was built again. Now a chat SDK call event, a reconnect, a UI Kit
/// call event or a call screen closing refreshes the first page 1.5 s after
/// the last of them, silently, and merges it in by session id: new rows on
/// top, changed rows in place, older pages kept. The refresh reads the first
/// page through a request of its own, so load-more keeps its place.
///
/// Ringing v2 registers the chat SDK's call listener on web only. These
/// tests run on the Dart VM, so they cover Android and iOS, where a call of
/// this device's being over (`ActiveCallTracker.releasedSessions`) or
/// stopping ringing here (`ringingEndedSessions`) takes its place. The chat
/// SDK triggers are covered when run with `--platform chrome`.
///
/// Time is fake throughout (testWidgets); no test awaits a future that
/// depends on it.
///
///   flutter test test/call_ui/call_logs/call_logs_live_refresh_test.dart
library;

import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/bloc/call_logs_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/bloc/call_logs_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/bloc/call_logs_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/domain/repositories/call_logs_repository.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/domain/usecases/get_call_logs_usecase.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/domain/usecases/initiate_call_usecase.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/domain/usecases/load_more_call_logs_usecase.dart';
import 'package:cometchat_chat_uikit/call_ui/src/utils/call_state_service.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/events/call_events/cometchat_call_events.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/chat_sdk_listeners.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/call_bloc_harness.dart';
import '../helpers/fake_call_logs_remote.dart';

/// The chat SDK listeners the bloc registered, by id.
final _callListeners = <String, CallListener>{};
final _connectionListeners = <String, ConnectionListener>{};

Call _call() => Call(
  sessionId: 'x',
  receiverUid: 'them',
  type: 'audio',
  receiverType: 'user',
);

CallLog _row(String id, {String status = 'ended', int at = 1700000000}) =>
    CallLog(sessionId: id, initiatedAt: at, type: 'audio', status: status);

/// Pumps past the first load (the Calls SDK wait and the fetch).
Future<void> _settle(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 5));

Future<void> _close(WidgetTester tester, CallLogsBloc bloc) =>
    tester.runAsync<void>(bloc.close);

var _sessions = 0;

/// A call of this device's is over here, as ringing v2 reports it on
/// Android and iOS: its record is released. On web, one chat SDK call event.
void _callOver() {
  if (kIsWeb) {
    _callListeners.values.single.onIncomingCallCancelled(_call());
  } else {
    ActiveCallTracker.release('over-${++_sessions}');
  }
}

/// A call stopped ringing on this device without being answered or declined
/// here (Android and iOS).
void _ringingEnded() => ActiveCallTracker.ringingEnded('rang-${++_sessions}');

List<String?> _ids(CallLogsBloc bloc) =>
    bloc.state.callLogs.map((log) => log.sessionId).toList();

/// A repository of the host's own: not the UI Kit's.
class _HostRepository implements CallLogsRepository {
  int fetches = 0;

  @override
  Future<Result<List<CallLog>>> getCallLogs({int limit = 30}) async {
    fetches++;
    return Success(<CallLog>[_row('h')]);
  }

  @override
  Future<Result<User?>> getLoggedInUser() async => const Success(null);

  @override
  Future<Result<Call>> initiateCall(Call call) async => Success(call);

  @override
  Future<Result<String?>> getUserAuthToken() async => const Success('t');
}

void main() {
  setUp(() async {
    _callListeners.clear();
    _connectionListeners.clear();
    ChatSdkListeners.debugAddCallListener = (id, listener) =>
        _callListeners[id] = listener;
    ChatSdkListeners.debugRemoveCallListener = _callListeners.remove;
    ChatSdkListeners.debugAddConnectionListener = (id, listener) =>
        _connectionListeners[id] = listener;
    ChatSdkListeners.debugRemoveConnectionListener =
        _connectionListeners.remove;
    // waitForCallsSdk answers at once.
    await installReadyCallsSdk();
  });

  tearDown(() {
    ChatSdkListeners.debugReset();
    CallStateService.instance.setActiveCallValue(false);
    uninstallCallsSdk();
  });

  testWidgets('P5-E30: a burst of triggers refreshes once, 1.5 s after the '
      'last of them, with no loading state', (tester) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [
          [_row('a')],
          [_row('b', at: 1700000100), _row('a')],
        ],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(remote);
    bloc.add(const LoadCallLogs());
    await _settle(tester);
    expect(remote.requests, hasLength(1));
    final statuses = <CallLogsStatus>[];
    final sub = bloc.stream.listen((s) => statuses.add(s.status));

    _callOver();
    await tester.pump(const Duration(milliseconds: 500));
    CometChatCallEvents.ccCallRejected(_call());
    await tester.pump(const Duration(milliseconds: 500));
    _connectionListeners.values.single.onConnected();
    // 1.5 s after the first trigger, but only 0.5 s after the last.
    await tester.pump(const Duration(milliseconds: 500));
    expect(remote.requests, hasLength(1));
    // Just under 1.5 s after the last: still nothing.
    await tester.pump(const Duration(milliseconds: 999));
    expect(remote.requests, hasLength(1));
    // Just past 1.5 s after the last: one refresh.
    await tester.pump(const Duration(milliseconds: 2));
    expect(remote.requests, hasLength(2));
    expect(_ids(bloc), ['b', 'a']);
    expect(statuses, isNot(contains(CallLogsStatus.loading)));

    await tester.pump(const Duration(seconds: 5));
    expect(remote.requests, hasLength(2));
    await tester.runAsync<void>(sub.cancel);
    await _close(tester, bloc);
  });

  testWidgets('P5-N15: the refresh puts a new row on top, updates a changed '
      'one in place, and keeps the older pages and hasMore', (tester) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [
          [_row('s1', status: 'initiated'), _row('s2')],
          [
            _row('s0', at: 1700000100),
            _row('s1', status: 'rejected'),
            _row('s2'),
          ],
        ],
        2: [
          [_row('s3', at: 1600000000)],
        ],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(
      remote,
      builder: CallLogRequestBuilder()..limit = 2,
    );
    bloc.add(const LoadCallLogs());
    await _settle(tester);
    bloc.add(const LoadMoreCallLogs());
    await _settle(tester);
    expect(_ids(bloc), ['s1', 's2', 's3']);
    expect(bloc.state.hasMore, isTrue);

    _callOver();
    await tester.pump(const Duration(seconds: 2));

    expect(_ids(bloc), ['s0', 's1', 's2', 's3']);
    expect(bloc.state.callLogs[1].status, 'rejected');
    expect(bloc.state.hasMore, isTrue);
    expect(bloc.state.status, CallLogsStatus.loaded);
    // The session index follows the merged list.
    expect(bloc.findCallLogIndex('s3'), 3);
    await _close(tester, bloc);
  });

  testWidgets('P5-C14: the refresh reads the first page through a request '
      'of its own, with the same filters, and load-more keeps its place', (
    tester,
  ) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [
          [_row('a1'), _row('a2')],
        ],
        2: [
          [_row('b1', at: 1600000000), _row('b2', at: 1600000000)],
        ],
        3: [
          [_row('c1', at: 1500000000)],
        ],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(
      remote,
      builder: CallLogRequestBuilder()
        ..limit = 2
        ..uid = 'bob',
    );
    bloc.add(const LoadCallLogs());
    await _settle(tester);
    bloc.add(const LoadMoreCallLogs());
    await _settle(tester);

    _callOver();
    await tester.pump(const Duration(seconds: 2));
    bloc.add(const LoadMoreCallLogs());
    await _settle(tester);

    expect(remote.pagesAsked, [1, 2, 1, 3]);
    final shared = remote.requests[0];
    final refresh = remote.requests[2];
    expect(refresh, isNot(same(shared)));
    expect(remote.requests[3], same(shared));
    expect(refresh.uid, 'bob');
    expect(refresh.limit, 2);
    expect(_ids(bloc), ['a1', 'a2', 'b1', 'b2', 'c1']);
    await _close(tester, bloc);
  });

  testWidgets('P5-C14: a refresh that fails twice keeps the list; one that '
      'fails once is retried', (tester) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [
          [_row('a')],
          // The first refresh: both attempts fail.
          remoteFailure(),
          remoteFailure(),
          // The second: the first attempt fails, the retry succeeds.
          remoteFailure(),
          [_row('n', at: 1700000100), _row('a')],
        ],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(remote);
    bloc.add(const LoadCallLogs());
    await _settle(tester);

    // Two attempts, both failing: the list stays, nothing is reported.
    _callOver();
    await tester.pump(const Duration(seconds: 5));
    expect(remote.requests, hasLength(3));
    expect(_ids(bloc), ['a']);
    expect(bloc.state.status, CallLogsStatus.loaded);
    expect(bloc.state.loadMoreError, isNull);

    // The next refresh's second attempt succeeds.
    _callOver();
    await tester.pump(const Duration(seconds: 5));
    expect(remote.requests, hasLength(5));
    expect(_ids(bloc), ['n', 'a']);
    await _close(tester, bloc);
  });

  testWidgets('P5-C14: every trigger kind schedules a refresh', (tester) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [
          [_row('a')],
        ],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(remote);
    bloc.add(const LoadCallLogs());
    await _settle(tester);

    final triggers = <String, void Function()>{
      // The chat SDK's call listener exists on web only (ringing v2); on
      // Android and iOS the call tracker's sessions take its place.
      if (kIsWeb) ...{
        'onIncomingCallReceived': () =>
            _callListeners.values.single.onIncomingCallReceived(_call()),
        'onOutgoingCallAccepted': () =>
            _callListeners.values.single.onOutgoingCallAccepted(_call()),
        'onOutgoingCallRejected': () =>
            _callListeners.values.single.onOutgoingCallRejected(_call()),
        'onIncomingCallCancelled': () =>
            _callListeners.values.single.onIncomingCallCancelled(_call()),
        'onCallEndedMessageReceived': () =>
            _callListeners.values.single.onCallEndedMessageReceived(_call()),
      } else ...{
        'a call released here (releasedSessions)': _callOver,
        'a call that stopped ringing here (ringingEndedSessions)':
            _ringingEnded,
      },
      'P5-E29 onConnected': () =>
          _connectionListeners.values.single.onConnected(),
      'ccOutgoingCall': () => CometChatCallEvents.ccOutgoingCall(_call()),
      'ccCallAccepted': () => CometChatCallEvents.ccCallAccepted(_call()),
      'ccCallRejected': () => CometChatCallEvents.ccCallRejected(_call()),
      'ccCallEnded': () => CometChatCallEvents.ccCallEnded(_call()),
      'a call screen closing': () {
        CallStateService.instance.setActiveCallValue(true);
        CallStateService.instance.setActiveCallValue(false);
      },
    };
    for (final MapEntry(key: name, value: trigger) in triggers.entries) {
      final before = remote.requests.length;
      trigger();
      await tester.pump(const Duration(seconds: 2));
      expect(remote.requests.length, before + 1, reason: name);
    }

    // A call screen opening is no reason to refresh.
    final before = remote.requests.length;
    CallStateService.instance.setActiveCallValue(true);
    await tester.pump(const Duration(seconds: 2));
    expect(remote.requests.length, before);
    CallStateService.instance.setActiveCallValue(false);
    await tester.pump(const Duration(seconds: 2));
    expect(remote.requests.length, before + 1);
    await _close(tester, bloc);
  });

  testWidgets('P5-C14: close() removes the call triggers (the chat SDK call '
      'listener on web, the call tracker on Android and iOS), the connection '
      'listener and the UI Kit call listener, and cancels the timer', (
    tester,
  ) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [
          [_row('a')],
        ],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(remote);
    bloc.add(const LoadCallLogs());
    await _settle(tester);
    final id = _connectionListeners.keys.single;
    expect(_callListeners.keys, kIsWeb ? [id] : isEmpty);
    expect(CometChatCallEvents.callEventsListener.keys, contains(id));

    // A refresh is pending when the bloc closes. The test ends right after:
    // a timer close() left would fail it as pending.
    _callOver();
    await tester.pump(const Duration(milliseconds: 500));
    await _close(tester, bloc);

    expect(_callListeners, isEmpty);
    expect(_connectionListeners, isEmpty);
    expect(CometChatCallEvents.callEventsListener.keys, isNot(contains(id)));
    expect(remote.requests, hasLength(1));

    // The call tracker no longer reaches the closed bloc.
    if (!kIsWeb) {
      _callOver();
      _ringingEnded();
      await tester.pump(const Duration(seconds: 2));
      expect(remote.requests, hasLength(1));
    }
  });

  testWidgets('P5-C14: a call screen closing after close() refreshes nothing', (
    tester,
  ) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [
          [_row('a')],
        ],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(remote);
    bloc.add(const LoadCallLogs());
    await _settle(tester);
    await _close(tester, bloc);

    CallStateService.instance.setActiveCallValue(true);
    CallStateService.instance.setActiveCallValue(false);
    await tester.pump(const Duration(seconds: 3));
    expect(remote.requests, hasLength(1));
  });

  testWidgets('P5-C14: a trigger during a load-more waits for it', (
    tester,
  ) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [
          [_row('a')],
        ],
        2: [
          [_row('b', at: 1600000000)],
        ],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(remote);
    bloc.add(const LoadCallLogs());
    await _settle(tester);

    remote.gate = Completer<void>();
    bloc.add(const LoadMoreCallLogs());
    await tester.pump();
    _callOver();
    await tester.pump(const Duration(seconds: 3));
    // Only the load-more has asked.
    expect(remote.pagesAsked, [1, 2]);

    remote.gate!.complete();
    remote.gate = null;
    await tester.pump(const Duration(seconds: 3));
    expect(remote.pagesAsked, [1, 2, 1]);
    expect(_ids(bloc), ['a', 'b']);
    await _close(tester, bloc);
  });

  testWidgets('P5-C14: a refresh that a reload overtakes emits nothing', (
    tester,
  ) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [
          [_row('a')],
          [_row('stale', at: 1700000100), _row('a')],
          [_row('fresh', at: 1700000200)],
        ],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(remote);
    bloc.add(const LoadCallLogs());
    await _settle(tester);
    final seen = <List<String?>>[];
    final sub = bloc.stream.listen(
      (s) => seen.add(s.callLogs.map((l) => l.sessionId).toList()),
    );

    remote.gate = Completer<void>();
    _callOver();
    await tester.pump(const Duration(seconds: 2));
    expect(remote.requests, hasLength(2));
    bloc.add(const RefreshCallLogs());
    await tester.pump(const Duration(seconds: 1));
    remote.gate!.complete();
    remote.gate = null;
    await tester.pump(const Duration(seconds: 3));

    expect(_ids(bloc), ['fresh']);
    expect(seen.where((ids) => ids.contains('stale')), isEmpty);
    await tester.runAsync<void>(sub.cancel);
    await _close(tester, bloc);
  });

  testWidgets('P5-C14: a trigger before the first load refreshes nothing, '
      'then or later', (tester) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [
          [_row('a')],
        ],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(remote);

    _callOver();
    CometChatCallEvents.ccCallEnded(_call());
    await tester.pump(const Duration(milliseconds: 200));
    expect(remote.requests, isEmpty);
    expect(bloc.state.status, CallLogsStatus.initial);

    // The first load lands before a refresh scheduled then would run.
    bloc.add(const LoadCallLogs());
    await tester.pump(const Duration(seconds: 3));
    expect(remote.requests, hasLength(1));
    await _close(tester, bloc);
  });

  testWidgets('P5-C14: a repository of the host\'s own is left alone', (
    tester,
  ) async {
    final repository = _HostRepository();
    final bloc = CallLogsBloc(
      getCallLogsUseCase: GetCallLogsUseCase(repository),
      loadMoreCallLogsUseCase: LoadMoreCallLogsUseCase(repository),
      initiateCallUseCase: InitiateCallUseCase(repository),
      getLoggedInUserUseCase: GetLoggedInUserUseCase(repository),
    );
    bloc.add(const LoadCallLogs());
    await _settle(tester);
    expect(repository.fetches, 1);

    _callOver();
    await tester.pump(const Duration(seconds: 3));
    expect(repository.fetches, 1);
    await _close(tester, bloc);
  });

  testWidgets('P5-C14: an empty list becomes the list when a call comes in, '
      'without the loading state', (tester) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [
          <CallLog>[],
          [_row('n')],
        ],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(remote);
    bloc.add(const LoadCallLogs());
    await _settle(tester);
    expect(bloc.state.status, CallLogsStatus.empty);
    final statuses = <CallLogsStatus>[];
    final sub = bloc.stream.listen((s) => statuses.add(s.status));

    CometChatCallEvents.ccCallRejected(_call());
    await tester.pump(const Duration(seconds: 2));

    expect(bloc.state.status, CallLogsStatus.loaded);
    expect(_ids(bloc), ['n']);
    expect(bloc.state.hasMore, isTrue);
    expect(statuses, [CallLogsStatus.loaded]);
    await tester.runAsync<void>(sub.cancel);
    await _close(tester, bloc);
  });

  testWidgets('P5-E29: after a failed first load, a reconnect loads the list '
      'quietly', (tester) async {
    final remote = FakeCallLogsRemote(
      pages: {
        1: [
          remoteFailure(),
          remoteFailure(),
          remoteFailure(),
          remoteFailure(),
          [_row('a')],
        ],
      },
    );
    final (:bloc, repository: _) = callLogsBlocOver(remote);
    bloc.add(const LoadCallLogs());
    await _settle(tester);
    expect(bloc.state.status, CallLogsStatus.error);
    final statuses = <CallLogsStatus>[];
    final sub = bloc.stream.listen((s) => statuses.add(s.status));

    _connectionListeners.values.single.onConnected();
    await tester.pump(const Duration(seconds: 2));

    expect(bloc.state.status, CallLogsStatus.loaded);
    expect(_ids(bloc), ['a']);
    expect(statuses, isNot(contains(CallLogsStatus.loading)));
    await tester.runAsync<void>(sub.cancel);
    await _close(tester, bloc);
  });
}
