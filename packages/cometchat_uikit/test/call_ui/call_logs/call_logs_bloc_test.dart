/// Drives [CallLogsBloc] end to end against a stub repository.
///
/// Two things make this bloc awkward to drive headless, and the harness below
/// is shaped around them:
///
///  * `_onLoadCallLogs` awaits `CallEventService.waitForCallsSdk()`, which in a
///    VM test finds no Calls SDK and polls for ~11 seconds before giving up.
///    Every test therefore runs inside `testWidgets` so that the poll's
///    `Future.delayed` chain is fake time, and [_settle] pumps past it.
///  * `bloc.close()` never completes under that fake clock, so [_close] runs it
///    through `tester.runAsync`.
///
///   flutter test test/call_ui/call_logs/call_logs_bloc_test.dart
library;

import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_chat_uikit/call_ui/src/call_event_service.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/bloc/call_logs_bloc.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/bloc/call_logs_event.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/bloc/call_logs_state.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/domain/repositories/call_logs_repository.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/domain/usecases/get_call_logs_usecase.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/domain/usecases/initiate_call_usecase.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_logs/domain/usecases/load_more_call_logs_usecase.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_operations/di/call_operations_service_locator.dart';
import 'package:cometchat_chat_uikit/call_ui/src/call_settings/call_navigation_context.dart';
import 'package:cometchat_chat_uikit/call_ui/src/outgoing_call/cometchat_outgoing_call.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart' as calls;
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as public;
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_chat_uikit/src/active_call_tracker.dart';
import 'package:cometchat_chat_uikit/src/call_user_lookup.dart';
import 'package:cometchat_chat_uikit/src/calls_lifecycle.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/call_bloc_harness.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

/// Programmable [CallLogsRepository]. `getCallLogs` answers [pages] in order
/// and repeats the last entry once the queue is exhausted, which is what the
/// retry loop and pagination need.
class _StubRepo implements CallLogsRepository {
  _StubRepo({this.loggedInUser, List<Result<List<CallLog>>>? pages})
    : pages = pages ?? <Result<List<CallLog>>>[const Success(<CallLog>[])];

  final User? loggedInUser;
  final List<Result<List<CallLog>>> pages;

  int getCallLogsCalls = 0;
  int getLoggedInUserCalls = 0;
  final List<Call> initiatedCalls = [];
  Result<Call>? initiateResult;

  @override
  Future<Result<List<CallLog>>> getCallLogs({int limit = 30}) async {
    final index = getCallLogsCalls < pages.length
        ? getCallLogsCalls
        : pages.length - 1;
    getCallLogsCalls++;
    return pages[index];
  }

  @override
  Future<Result<User?>> getLoggedInUser() async {
    getLoggedInUserCalls++;
    return Success(loggedInUser);
  }

  /// When set, `initiateCall` waits for it before answering.
  Completer<void>? initiateGate;

  @override
  Future<Result<Call>> initiateCall(Call call) async {
    initiatedCalls.add(call);
    await initiateGate?.future;
    return initiateResult ?? Success(call);
  }

  @override
  Future<Result<String?>> getUserAuthToken() async => const Success('token');
}

/// Listens on the call-event bus the package exports.
class _PublicCallEventSpy with public.CometChatCallEventListener {
  final List<Call> outgoing = [];

  @override
  void ccOutgoingCall(Call call) => outgoing.add(call);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CallLog _log({
  String sessionId = 's1',
  int? initiatedAt = 1700000000,
  String type = 'audio',
  CallEntity? initiator,
  CallEntity? receiver,
}) => CallLog(
  sessionId: sessionId,
  initiatedAt: initiatedAt,
  type: type,
  initiator: initiator,
  receiver: receiver,
);

List<CallLog> _logs(int count) => List.generate(
  count,
  (i) => _log(sessionId: 's$i', initiatedAt: 1700000000 + i),
);

CallLogsBloc _blocFor(
  _StubRepo repo, {
  CallLogRequestBuilder? builder,
  public.OnError? onError,
}) => CallLogsBloc(
  getCallLogsUseCase: GetCallLogsUseCase(repo),
  loadMoreCallLogsUseCase: LoadMoreCallLogsUseCase(repo),
  initiateCallUseCase: InitiateCallUseCase(repo),
  getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
  callLogsRequestBuilder: builder,
  errorCallback: onError,
);

/// Pumps past the Calls-SDK wait inside `_onLoadCallLogs` (~11s of fake time)
/// plus the three 1s retry delays, with headroom.
Future<void> _settle(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 30));

/// `Bloc.close()` — and a stream cancel — do not complete under the fake
/// clock, because nothing flushes their microtasks once the pumping stops.
/// Run them in real async instead.
Future<void> _close(
  WidgetTester tester,
  CallLogsBloc bloc, {
  StreamSubscription<CallLogsState>? subscription,
}) async {
  await tester.runAsync<void>(() async {
    await subscription?.cancel();
    await bloc.close();
  });
}

/// A context whose element has been disposed — `context.mounted` is false.
/// Used to exercise the "screen went away while the call was being placed"
/// branch without pushing the real outgoing-call screen.
Future<BuildContext> _defunctContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pumpWidget(const SizedBox());
  return captured;
}

/// A call log old enough that the bloc gives it a formatted date rather than
/// "Today"/"Yesterday". Relative to now, so it stays old in every timezone.
final DateTime _old = DateTime.now().subtract(const Duration(days: 30));

/// The key `CallLogsBloc._getDateKey` builds for [when] — its local calendar
/// day, formatted as the bloc formats it (`MMM d, yyyy`, English month
/// abbreviations). Mirrored here rather than hardcoded so the expectation
/// travels with the runner's timezone.
String _expectedDateKey(DateTime when) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[when.month - 1]} ${when.day}, ${when.year}';
}

void main() {
  // Round 2: a call-back asks for the microphone (and camera) and fetches
  // the callee first. By default both go through: the permissions are
  // granted, and the callee is a user nobody has blocked.
  setUp(() {
    PermissionChannelStub.install(granted: true);
    CallUserLookup.debugFetchUser = (String uid) async =>
        User(uid: uid, name: 'Name of $uid', avatar: 'https://a/$uid.png');
  });

  tearDown(() {
    PermissionChannelStub.remove();
    CallUserLookup.debugFetchUser = null;
    ActiveCallTracker.debugResetPlacingCall();
  });

  // =========================================================================
  group('CallLogsBloc — initial load', () {
    testWidgets('emits loading then loaded, groups by date and fills the '
        'session index', (tester) async {
      final repo = _StubRepo(
        loggedInUser: User(uid: 'me', name: 'Me'),
        pages: [
          Success([
            _log(sessionId: 'a', initiatedAt: 1700000000),
            _log(sessionId: 'b', initiatedAt: 1700000060),
          ]),
        ],
      );
      final bloc = _blocFor(repo);
      final seen = <CallLogsStatus>[];
      final sub = bloc.stream.listen((s) => seen.add(s.status));

      bloc.add(const LoadCallLogs());
      await _settle(tester);

      expect(seen, [CallLogsStatus.loading, CallLogsStatus.loaded]);
      expect(bloc.state.callLogs.length, 2);
      expect(bloc.state.loggedInUser?.uid, 'me');
      // Both logs fall on the same day, so they group under one key.
      expect(bloc.state.groupedEntries.length, 1);
      expect(bloc.state.groupedEntries.values.single.length, 2);
      // Round 5 (P5-C15): there is more until a page comes back empty, as on
      // Android; a page shorter than 30 is not the last when a host asked
      // for fewer.
      expect(bloc.state.hasMore, isTrue);
      // The O(1) lookup map is rebuilt from the replaced list.
      expect(bloc.findCallLogIndex('b'), 1);
      expect(bloc.findCallLog('a')?.sessionId, 'a');
      expect(bloc.findCallLog('missing'), isNull);

      await _close(tester, bloc, subscription: sub);
    });

    testWidgets('a full page leaves hasMore true', (tester) async {
      final repo = _StubRepo(pages: [Success(_logs(30))]);
      final bloc = _blocFor(repo);

      bloc.add(const LoadCallLogs());
      await _settle(tester);

      expect(bloc.state.status, CallLogsStatus.loaded);
      expect(bloc.state.hasMore, isTrue);

      await _close(tester, bloc);
    });

    testWidgets('an empty result is the empty state, not loaded', (
      tester,
    ) async {
      final repo = _StubRepo(
        loggedInUser: User(uid: 'me', name: 'Me'),
        pages: [const Success(<CallLog>[])],
      );
      final bloc = _blocFor(repo);

      bloc.add(const LoadCallLogs());
      await _settle(tester);

      expect(bloc.state.status, CallLogsStatus.empty);
      expect(bloc.state.callLogs, isEmpty);
      expect(bloc.state.loggedInUser?.uid, 'me');

      await _close(tester, bloc);
    });

    testWidgets('a log with no initiatedAt is dropped from the grouping but '
        'kept in the list', (tester) async {
      final repo = _StubRepo(
        pages: [
          Success([
            _log(sessionId: 'a', initiatedAt: 1700000000),
            _log(sessionId: 'b', initiatedAt: null),
          ]),
        ],
      );
      final bloc = _blocFor(repo);

      bloc.add(const LoadCallLogs());
      await _settle(tester);

      expect(bloc.state.callLogs.length, 2);
      expect(bloc.state.groupedEntries.values.single.length, 1);

      await _close(tester, bloc);
    });

    testWidgets('today and yesterday get named date keys', (tester) async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final repo = _StubRepo(
        pages: [
          Success([
            _log(
              sessionId: 'today',
              initiatedAt: now.millisecondsSinceEpoch ~/ 1000,
            ),
            _log(
              sessionId: 'yesterday',
              initiatedAt: yesterday.millisecondsSinceEpoch ~/ 1000,
            ),
            _log(
              sessionId: 'old',
              initiatedAt: _old.millisecondsSinceEpoch ~/ 1000,
            ),
          ]),
        ],
      );
      final bloc = _blocFor(repo);

      bloc.add(const LoadCallLogs());
      await _settle(tester);

      expect(bloc.state.groupedEntries.keys, contains('Today'));
      expect(bloc.state.groupedEntries.keys, contains('Yesterday'));
      // Derived from the same instant the log carries, not hardcoded: the
      // bloc keys off the LOCAL calendar day, so a fixed label only holds in
      // the timezone it was written in. "Nov 15, 2023" was right in IST and
      // failed on CI's UTC runner, which saw Nov 14.
      expect(bloc.state.groupedEntries.keys, contains(_expectedDateKey(_old)));

      await _close(tester, bloc);
    });

    testWidgets('a custom request builder is accepted and used', (
      tester,
    ) async {
      final builder = CallLogRequestBuilder()..limit = 10;
      final repo = _StubRepo(pages: [Success(_logs(2))]);
      final bloc = _blocFor(repo, builder: builder);

      expect(bloc.callLogsRequestBuilder, same(builder));

      bloc.add(const LoadCallLogs());
      await _settle(tester);

      expect(bloc.state.status, CallLogsStatus.loaded);

      await _close(tester, bloc);
    });
  });

  // =========================================================================
  group('CallLogsBloc — failure and retry', () {
    testWidgets('a failing fetch is retried three times before the error '
        'state', (tester) async {
      final repo = _StubRepo(
        pages: [const Failure(message: 'boom', code: 'ERR')],
      );
      final bloc = _blocFor(repo);

      bloc.add(const LoadCallLogs());
      await _settle(tester);

      expect(bloc.state.status, CallLogsStatus.error);
      expect(bloc.state.errorMessage, 'boom');
      // One initial attempt plus _maxRetries.
      expect(repo.getCallLogsCalls, 4);

      await _close(tester, bloc);
    });

    testWidgets('a retry that succeeds loads normally', (tester) async {
      final repo = _StubRepo(
        pages: [
          const Failure(message: 'transient'),
          Success(_logs(3)),
        ],
      );
      final bloc = _blocFor(repo);

      bloc.add(const LoadCallLogs());
      await _settle(tester);

      expect(bloc.state.status, CallLogsStatus.loaded);
      expect(bloc.state.callLogs.length, 3);
      expect(bloc.state.errorMessage, isNull);
      expect(repo.getCallLogsCalls, 2);

      await _close(tester, bloc);
    });
  });

  // =========================================================================
  group('CallLogsBloc — pagination', () {
    testWidgets('load more is ignored before the first load', (tester) async {
      final repo = _StubRepo(pages: [Success(_logs(30))]);
      final bloc = _blocFor(repo);

      bloc.add(const LoadMoreCallLogs());
      await _settle(tester);

      expect(bloc.state.status, CallLogsStatus.initial);
      expect(repo.getCallLogsCalls, 0);

      await _close(tester, bloc);
    });

    testWidgets('load more is ignored when the list is exhausted', (
      tester,
    ) async {
      // An empty page sets hasMore false.
      final repo = _StubRepo(
        pages: [Success(_logs(2)), const Success(<CallLog>[])],
      );
      final bloc = _blocFor(repo);
      bloc.add(const LoadCallLogs());
      await _settle(tester);
      bloc.add(const LoadMoreCallLogs());
      await _settle(tester);
      expect(bloc.state.hasMore, isFalse);
      final callsAfterLoad = repo.getCallLogsCalls;

      bloc.add(const LoadMoreCallLogs());
      await _settle(tester);

      expect(repo.getCallLogsCalls, callsAfterLoad);
      expect(bloc.state.isLoadingMore, isFalse);

      await _close(tester, bloc);
    });

    testWidgets('a second page is appended, de-duplicated and re-grouped', (
      tester,
    ) async {
      final page1 = _logs(30);
      final page2 = [
        // First entry duplicates a session id already held; the use case
        // filters it out, so only the new one lands.
        _log(sessionId: 's0', initiatedAt: 1700000000),
        _log(sessionId: 'new', initiatedAt: 1600000000),
      ];
      final repo = _StubRepo(pages: [Success(page1), Success(page2)]);
      final bloc = _blocFor(repo);
      bloc.add(const LoadCallLogs());
      await _settle(tester);

      bloc.add(const LoadMoreCallLogs());
      await _settle(tester);

      expect(bloc.state.callLogs.length, 31);
      expect(bloc.state.callLogs.last.sessionId, 'new');
      // The appended entry is from a different day, so a second group appears.
      expect(bloc.state.groupedEntries.length, 2);
      // Only an empty page ends pagination (round 5, P5-C15).
      expect(bloc.state.hasMore, isTrue);
      expect(bloc.state.isLoadingMore, isFalse);
      expect(bloc.findCallLogIndex('new'), 30);

      await _close(tester, bloc);
    });

    testWidgets('an empty second page only clears hasMore', (tester) async {
      final repo = _StubRepo(
        pages: [Success(_logs(30)), const Success(<CallLog>[])],
      );
      final bloc = _blocFor(repo);
      bloc.add(const LoadCallLogs());
      await _settle(tester);

      bloc.add(const LoadMoreCallLogs());
      await _settle(tester);

      expect(bloc.state.callLogs.length, 30);
      expect(bloc.state.hasMore, isFalse);
      expect(bloc.state.isLoadingMore, isFalse);
      expect(bloc.state.status, CallLogsStatus.loaded);

      await _close(tester, bloc);
    });

    testWidgets('a full second page keeps hasMore true', (tester) async {
      final page2 = List.generate(
        30,
        (i) => _log(sessionId: 'p2_$i', initiatedAt: 1700000000 + i),
      );
      final repo = _StubRepo(pages: [Success(_logs(30)), Success(page2)]);
      final bloc = _blocFor(repo);
      bloc.add(const LoadCallLogs());
      await _settle(tester);

      bloc.add(const LoadMoreCallLogs());
      await _settle(tester);

      expect(bloc.state.callLogs.length, 60);
      expect(bloc.state.hasMore, isTrue);

      await _close(tester, bloc);
    });

    testWidgets('P5-E27: a failing second page keeps the list, with '
        'loadMoreError set', (tester) async {
      final repo = _StubRepo(
        pages: [
          Success(_logs(30)),
          const Failure(message: 'no more'),
        ],
      );
      final bloc = _blocFor(repo);
      bloc.add(const LoadCallLogs());
      await _settle(tester);

      bloc.add(const LoadMoreCallLogs());
      await _settle(tester);

      // Round 5 (P5-C15): it replaced the whole list with the error view.
      expect(bloc.state.status, CallLogsStatus.loaded);
      expect(bloc.state.loadMoreError, 'no more');
      expect(bloc.state.errorMessage, isNull);
      expect(bloc.state.isLoadingMore, isFalse);
      expect(bloc.state.hasMore, isTrue);
      expect(bloc.state.callLogs.length, 30);

      await _close(tester, bloc);
    });

    testWidgets('a repeated page is de-duplicated away rather than appended', (
      tester,
    ) async {
      final page2 = List.generate(
        30,
        (i) => _log(sessionId: 'p2_$i', initiatedAt: 1700000000 + i),
      );
      final repo = _StubRepo(pages: [Success(_logs(30)), Success(page2)]);
      final bloc = _blocFor(repo);
      bloc.add(const LoadCallLogs());
      await _settle(tester);
      final callsAfterLoad = repo.getCallLogsCalls;

      bloc.add(const LoadMoreCallLogs());
      bloc.add(const LoadMoreCallLogs());
      await _settle(tester);

      // The two events are handled one after the other rather than being
      // collapsed, so a second page is requested — but every already-held
      // session id is filtered out of it rather than duplicated. A page of
      // nothing but known rows does not end pagination (round 5, P5-C15):
      // newer calls push rows already listed down into later pages.
      expect(repo.getCallLogsCalls, callsAfterLoad + 2);
      expect(bloc.state.callLogs.length, 60);
      expect(bloc.state.callLogs.map((c) => c.sessionId).toSet().length, 60);
      expect(bloc.state.hasMore, isTrue);

      await _close(tester, bloc);
    });
  });

  // =========================================================================
  group('CallLogsBloc — refresh', () {
    testWidgets('refresh re-runs the initial load', (tester) async {
      final repo = _StubRepo(pages: [Success(_logs(2))]);
      final bloc = _blocFor(repo);
      bloc.add(const LoadCallLogs());
      await _settle(tester);
      final callsAfterLoad = repo.getCallLogsCalls;

      final seen = <CallLogsStatus>[];
      final sub = bloc.stream.listen((s) => seen.add(s.status));
      bloc.add(const RefreshCallLogs());
      await _settle(tester);

      expect(seen, [CallLogsStatus.loading, CallLogsStatus.loaded]);
      expect(repo.getCallLogsCalls, callsAfterLoad + 1);
      expect(bloc.state.callLogs.length, 2);

      await _close(tester, bloc, subscription: sub);
    });
  });

  // =========================================================================
  group('CallLogsBloc — initiating a call from a log', () {
    late _PublicCallEventSpy publicSpy;

    setUp(() {
      publicSpy = _PublicCallEventSpy();
      public.CometChatCallEvents.addCallEventsListener(
        'call_logs_bloc_test',
        publicSpy,
      );
    });

    tearDown(() {
      public.CometChatCallEvents.removeCallEventsListener(
        'call_logs_bloc_test',
      );
    });

    testWidgets('when the logged-in user placed the original call, the '
        'receiver is called back', (tester) async {
      final repo = _StubRepo(
        loggedInUser: User(uid: 'me', name: 'Me'),
      );
      final bloc = _blocFor(repo);
      final context = await _defunctContext(tester);
      // The app has a navigator for the outgoing call screen (round 1b:
      // with none, nothing is placed).
      await mountCallNavigator(tester);
      await _settle(tester);

      bloc.add(
        InitiateCallFromLog(
          callLog: _log(
            initiator: CallUser(uid: 'me'),
            receiver: CallUser(uid: 'them'),
            type: 'video',
          ),
          context: context,
        ),
      );
      await _settle(tester);

      expect(repo.initiatedCalls.single.receiverUid, 'them');
      expect(repo.initiatedCalls.single.receiverType, 'user');
      expect(repo.initiatedCalls.single.type, 'video');
      // The placed call is announced even though the screen that asked for it
      // is gone — on the bus the package exports, which CallEventService and
      // app listeners use. It used to go to a second, private copy of the bus
      // that nothing listened on.
      expect(publicSpy.outgoing.single.receiverUid, 'them');
      expect(publicSpy.outgoing.single.category, 'call');

      await _close(tester, bloc);
    });

    testWidgets('when someone else placed the original call, the initiator is '
        'called back', (tester) async {
      final repo = _StubRepo(
        loggedInUser: User(uid: 'me', name: 'Me'),
      );
      final bloc = _blocFor(repo);
      final context = await _defunctContext(tester);
      // The app has a navigator for the outgoing call screen (round 1b:
      // with none, nothing is placed).
      await mountCallNavigator(tester);
      await _settle(tester);

      bloc.add(
        InitiateCallFromLog(
          callLog: _log(
            initiator: CallUser(uid: 'them'),
            receiver: CallUser(uid: 'me'),
          ),
          context: context,
        ),
      );
      await _settle(tester);

      expect(repo.initiatedCalls.single.receiverUid, 'them');
      expect(repo.initiatedCalls.single.type, 'audio');

      await _close(tester, bloc);
    });

    testWidgets('a group log calls the group back', (tester) async {
      final repo = _StubRepo(
        loggedInUser: User(uid: 'me', name: 'Me'),
      );
      final bloc = _blocFor(repo);
      final context = await _defunctContext(tester);
      // The app has a navigator for the outgoing call screen (round 1b:
      // with none, nothing is placed).
      await mountCallNavigator(tester);
      await _settle(tester);

      bloc.add(
        InitiateCallFromLog(
          callLog: _log(
            initiator: CallUser(uid: 'me'),
            receiver: CallGroup(guid: 'g1'),
          ),
          context: context,
        ),
      );
      await _settle(tester);

      expect(repo.initiatedCalls.single.receiverUid, 'g1');
      expect(repo.initiatedCalls.single.receiverType, 'group');
      // No user is attached for a group call-back.
      expect(publicSpy.outgoing.single.receiverType, 'group');

      await _close(tester, bloc);
    });

    testWidgets('a group initiator is called back when the log was incoming', (
      tester,
    ) async {
      final repo = _StubRepo(
        loggedInUser: User(uid: 'me', name: 'Me'),
      );
      final bloc = _blocFor(repo);
      final context = await _defunctContext(tester);
      // The app has a navigator for the outgoing call screen (round 1b:
      // with none, nothing is placed).
      await mountCallNavigator(tester);
      await _settle(tester);

      bloc.add(
        InitiateCallFromLog(
          callLog: _log(initiator: CallGroup(guid: 'g2')),
          context: context,
        ),
      );
      await _settle(tester);

      expect(repo.initiatedCalls.single.receiverUid, 'g2');
      expect(repo.initiatedCalls.single.receiverType, 'group');

      await _close(tester, bloc);
    });

    testWidgets('a log with no usable party places no call', (tester) async {
      final repo = _StubRepo(
        loggedInUser: User(uid: 'me', name: 'Me'),
      );
      final bloc = _blocFor(repo);
      final context = await _defunctContext(tester);
      await _settle(tester);

      // Neither initiator nor receiver is a CallUser/CallGroup.
      bloc.add(InitiateCallFromLog(callLog: _log(), context: context));
      await _settle(tester);

      expect(repo.initiatedCalls, isEmpty);
      expect(publicSpy.outgoing, isEmpty);

      await _close(tester, bloc);
    });

    testWidgets('a party with an empty id places no call', (tester) async {
      final repo = _StubRepo(
        loggedInUser: User(uid: 'me', name: 'Me'),
      );
      final bloc = _blocFor(repo);
      final context = await _defunctContext(tester);
      await _settle(tester);

      bloc.add(
        InitiateCallFromLog(
          callLog: _log(
            initiator: CallUser(uid: 'me'),
            receiver: CallUser(uid: null),
          ),
          context: context,
        ),
      );
      await _settle(tester);

      expect(repo.initiatedCalls, isEmpty);

      await _close(tester, bloc);
    });

    testWidgets('with no logged-in user the log is treated as incoming', (
      tester,
    ) async {
      // _isLoggedInUserInitiator returns false when there is no user, so the
      // initiator — not the receiver — is called back.
      final repo = _StubRepo();
      final bloc = _blocFor(repo);
      final context = await _defunctContext(tester);
      // The app has a navigator for the outgoing call screen (round 1b:
      // with none, nothing is placed).
      await mountCallNavigator(tester);
      await _settle(tester);

      bloc.add(
        InitiateCallFromLog(
          callLog: _log(
            initiator: CallUser(uid: 'them'),
            receiver: CallUser(uid: 'me'),
          ),
          context: context,
        ),
      );
      await _settle(tester);

      expect(repo.initiatedCalls.single.receiverUid, 'them');

      await _close(tester, bloc);
    });

    testWidgets('a failed initiate surfaces the message without changing '
        'status', (tester) async {
      final repo = _StubRepo(
        loggedInUser: User(uid: 'me', name: 'Me'),
      )..initiateResult = const Failure(message: 'busy');
      final bloc = _blocFor(repo);
      final context = await _defunctContext(tester);
      // The app has a navigator for the outgoing call screen (round 1b:
      // with none, nothing is placed).
      await mountCallNavigator(tester);
      await _settle(tester);

      bloc.add(
        InitiateCallFromLog(
          callLog: _log(
            initiator: CallUser(uid: 'me'),
            receiver: CallUser(uid: 'them'),
          ),
          context: context,
        ),
      );
      await _settle(tester);

      expect(bloc.state.errorMessage, 'busy');
      expect(bloc.state.status, CallLogsStatus.initial);
      expect(publicSpy.outgoing, isEmpty);

      await _close(tester, bloc);
    });
  });

  // =========================================================================
  // Round 1b: a call from a log is only placed when its screen can be shown.
  group('CallLogsBloc — no navigator (round 1b)', () {
    late FakeCallOperationsDataSource operations;
    late _PublicCallEventSpy publicSpy;

    setUp(() async {
      await CallOperationsServiceLocator.instance.reset();
      operations = FakeCallOperationsDataSource();
      CallOperationsServiceLocator.instance.setup(dataSource: operations);
      CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
      publicSpy = _PublicCallEventSpy();
      public.CometChatCallEvents.addCallEventsListener(
        'call_logs_bloc_test_nav',
        publicSpy,
      );
    });

    tearDown(() async {
      public.CometChatCallEvents.removeCallEventsListener(
        'call_logs_bloc_test_nav',
      );
      await CallOperationsServiceLocator.instance.reset();
    });

    InitiateCallFromLog outgoingLog(BuildContext context) =>
        InitiateCallFromLog(
          callLog: _log(
            initiator: CallUser(uid: 'me'),
            receiver: CallUser(uid: 'them'),
          ),
          context: context,
        );

    testWidgets('no app navigator and the call-log screen gone: '
        'NO_NAVIGATOR, and nothing is placed', (tester) async {
      final repo = _StubRepo(
        loggedInUser: User(uid: 'me', name: 'Me'),
      );
      final errors = <Exception>[];
      final bloc = _blocFor(repo, onError: errors.add);
      final context = await _defunctContext(tester);
      await _settle(tester);

      bloc.add(outgoingLog(context));
      await _settle(tester);

      expect((errors.single as CometChatException).code, 'NO_NAVIGATOR');
      expect(repo.initiatedCalls, isEmpty);
      expect(publicSpy.outgoing, isEmpty);

      await _close(tester, bloc);
    });

    // Round 2 review: the call screen after an accept needs the key's
    // overlay, so the call-log screen's own navigator no longer does.
    testWidgets('the call-log screen on a navigator that is not '
        'CallNavigationContext.navigatorKey: NO_NAVIGATOR, nothing asked or '
        'placed', (tester) async {
      final repo = _StubRepo(
        loggedInUser: User(uid: 'me', name: 'Me'),
      );
      final errors = <Exception>[];
      final bloc = _blocFor(repo, onError: errors.add);
      late BuildContext screen;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              screen = context;
              return const SizedBox();
            },
          ),
        ),
      );
      await _settle(tester);

      bloc.add(outgoingLog(screen));
      await _settle(tester);

      expect((errors.single as CometChatException).code, 'NO_NAVIGATOR');
      expect(PermissionChannelStub.requested, isEmpty);
      expect(repo.initiatedCalls, isEmpty);
      expect(publicSpy.outgoing, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await _close(tester, bloc);
    });

    testWidgets('placed, then the app navigator goes: the call is cancelled '
        'and onError gets NO_NAVIGATOR', (tester) async {
      final gate = Completer<void>();
      final repo =
          _StubRepo(
              loggedInUser: User(uid: 'me', name: 'Me'),
            )
            ..initiateGate = gate
            ..initiateResult = Success(
              Call(
                sessionId: 'log-1',
                receiverUid: 'them',
                receiverType: 'user',
                type: 'audio',
              ),
            );
      final errors = <Exception>[];
      final bloc = _blocFor(repo, onError: errors.add);
      late BuildContext screen;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          home: Builder(
            builder: (context) {
              screen = context;
              return const SizedBox();
            },
          ),
        ),
      );
      await _settle(tester);

      bloc.add(outgoingLog(screen));
      await tester.pump();
      expect(repo.initiatedCalls, hasLength(1));

      // The app goes while the call is being placed.
      await tester.pumpWidget(const SizedBox());
      gate.complete();
      await _settle(tester);

      expect((errors.single as CometChatException).code, 'NO_NAVIGATOR');
      expect(operations.calls, <String>['rejectCall:log-1:cancelled']);
      // Announced as placed (round 2: the one launcher announces first, as
      // the call buttons did), then cancelled.
      expect(publicSpy.outgoing.single.sessionId, 'log-1');

      await _close(tester, bloc);
    });

    testWidgets('placed while a logout starts: the logout waits for it, it is '
        'cancelled, and nothing is shown or reported (round 1b review)', (
      tester,
    ) async {
      final gate = Completer<void>();
      final repo =
          _StubRepo(
              loggedInUser: User(uid: 'me', name: 'Me'),
            )
            ..initiateGate = gate
            ..initiateResult = Success(
              Call(
                sessionId: 'log-2',
                receiverUid: 'them',
                receiverType: 'user',
                type: 'audio',
              ),
            );
      final errors = <Exception>[];
      final bloc = _blocFor(repo, onError: errors.add);
      await mountCallNavigator(tester);
      await _settle(tester);
      addTearDown(CallsLifecycle.debugReset);

      bloc.add(outgoingLog(CallNavigationContext.navigatorKey.currentContext!));
      await tester.pump();
      expect(repo.initiatedCalls, hasLength(1));

      unawaited(
        CallsLifecycle.prepareForLogout().then(
          (_) => operations.calls.add('cleaned up'),
        ),
      );
      await tester.pump();
      expect(operations.calls, isEmpty);

      gate.complete();
      await _settle(tester);

      expect(operations.calls, <String>[
        'rejectCall:log-2:cancelled',
        'cleaned up',
      ]);
      expect(publicSpy.outgoing, isEmpty);
      expect(find.byType(CometChatOutgoingCall), findsNothing);
      expect(errors, isEmpty);

      await _close(tester, bloc);
    });

    testWidgets('a call tapped while a logout cleans up is not placed', (
      tester,
    ) async {
      final repo = _StubRepo(
        loggedInUser: User(uid: 'me', name: 'Me'),
      );
      final bloc = _blocFor(repo);
      await mountCallNavigator(tester);
      await _settle(tester);
      addTearDown(CallsLifecycle.debugReset);
      // The logout is still declining a ringing call.
      operations.rejectGate = Completer<void>();
      ActiveCallTracker.ringingCall = Call(
        sessionId: 'ring-1',
        receiverUid: 'me',
        receiverType: 'user',
        type: 'audio',
      );
      final cleaning = CallsLifecycle.prepareForLogout();
      await tester.pump();

      bloc.add(outgoingLog(CallNavigationContext.navigatorKey.currentContext!));
      await tester.pump();
      expect(repo.initiatedCalls, isEmpty);

      operations.rejectGate!.complete();
      await _settle(tester);
      await cleaning;
      expect(repo.initiatedCalls, isEmpty);

      await _close(tester, bloc);
    });

    testWidgets("with no outgoing configuration, the app's calling "
        'configuration dresses the outgoing screen, as for the message '
        "header's call buttons (round 1b review)", (tester) async {
      void buttonsOnError(Exception e) {}
      void outgoingOnError(Exception e) {}
      public.CometChatUIKit.authenticationSettings =
          (public.UIKitSettingsBuilder()
                ..appId = 'app'
                ..enableCalls = true
                ..callingConfiguration = calls.CallingConfiguration(
                  callButtonsConfiguration: calls.CallButtonsConfiguration(
                    outgoingCallConfiguration:
                        calls.CometChatOutgoingCallConfiguration(
                          onError: buttonsOnError,
                          disableSoundForCalls: true,
                        ),
                  ),
                  outgoingCallConfiguration:
                      calls.CometChatOutgoingCallConfiguration(
                        onError: outgoingOnError,
                        disableSoundForCalls: true,
                      ),
                ))
              .build();
      addTearDown(() => public.CometChatUIKit.authenticationSettings = null);
      final repo = _StubRepo(
        loggedInUser: User(uid: 'me', name: 'Me'),
      );
      final bloc = _blocFor(repo);
      await mountCallNavigator(tester);
      await _settle(tester);

      bloc.add(outgoingLog(CallNavigationContext.navigatorKey.currentContext!));
      await tester.pumpAndSettle();

      final screen = tester.widget<CometChatOutgoingCall>(
        find.byType(CometChatOutgoingCall, skipOffstage: false),
      );
      expect(screen.onError, same(buttonsOnError));
      expect(screen.disableSoundForCalls, isTrue);

      await _close(tester, bloc);
    });

    testWidgets('a callLogsBloc of your own with no errorCallback reports to '
        "the widget's onError, and stops once the widget is gone (round 1b "
        'review)', (tester) async {
      final repo = _StubRepo(
        loggedInUser: User(uid: 'me', name: 'Me'),
      );
      final bloc = _blocFor(repo);
      final errors = <Exception>[];
      final context = await _defunctContext(tester);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: public.Translations.localizationsDelegates,
          home: Scaffold(
            body: calls.CometChatCallLogs(
              callLogsBloc: bloc,
              onError: errors.add,
            ),
          ),
        ),
      );
      await _settle(tester);

      bloc.add(outgoingLog(context));
      await _settle(tester);
      expect(errors.map((e) => (e as CometChatException).code), <String>[
        'NO_NAVIGATOR',
      ]);

      await tester.pumpWidget(const SizedBox());
      bloc.add(outgoingLog(context));
      await _settle(tester);
      expect(errors, hasLength(1));

      await _close(tester, bloc);
    });

    testWidgets("a failed initiate reaches onError as the SDK's own "
        'exception', (tester) async {
      final sdkError = CometChatException(
        'ERR_UID_NOT_FOUND',
        'No such user.',
        'User not found',
      );
      final repo =
          _StubRepo(
              loggedInUser: User(uid: 'me', name: 'Me'),
            )
            ..initiateResult = Failure(
              message: 'User not found',
              code: 'ERR_UID_NOT_FOUND',
              exception: sdkError,
            );
      final errors = <Exception>[];
      final bloc = _blocFor(repo, onError: errors.add);
      final context = await _defunctContext(tester);
      await mountCallNavigator(tester);
      await _settle(tester);

      bloc.add(outgoingLog(context));
      await _settle(tester);

      expect(errors.single, same(sdkError));

      await _close(tester, bloc);
    });
  });

  // =========================================================================
  // Round 2, P2-C04 / P5-C16: the call-back makes the header's checks, and
  // shows the callee's real name.
  group('CallLogsBloc — calling back (round 2, P2-C04 / P5-C16)', () {
    late FakeCallOperationsDataSource operations;

    setUp(() async {
      await CallOperationsServiceLocator.instance.reset();
      operations = FakeCallOperationsDataSource();
      CallOperationsServiceLocator.instance.setup(dataSource: operations);
    });

    tearDown(() async {
      CallEventService.instance.activeCall = null;
      await CallOperationsServiceLocator.instance.reset();
      CallNavigationContext.navigatorKey = GlobalKey<NavigatorState>();
    });

    InitiateCallFromLog callBack(
      BuildContext context, {
      String type = 'audio',
    }) => InitiateCallFromLog(
      callLog: _log(
        initiator: CallUser(uid: 'me'),
        receiver: CallUser(uid: 'bob', name: 'bob-from-log'),
        type: type,
      ),
      context: context,
    );

    Future<(CallLogsBloc, _StubRepo, List<Exception>)> ready(
      WidgetTester tester,
    ) async {
      final repo = _StubRepo(
        loggedInUser: User(uid: 'me', name: 'Me'),
      );
      final errors = <Exception>[];
      final bloc = _blocFor(repo, onError: errors.add);
      await mountCallNavigator(tester);
      await _settle(tester);
      return (bloc, repo, errors);
    }

    String? codeOf(Exception e) => (e as CometChatException).code;

    testWidgets('P2-E25: two taps on the call icon place one call', (
      tester,
    ) async {
      final (bloc, repo, errors) = await ready(tester);
      final context = CallNavigationContext.navigatorKey.currentContext!;

      bloc
        ..add(callBack(context))
        ..add(callBack(context));
      await _settle(tester);

      expect(repo.initiatedCalls, hasLength(1));
      expect(errors, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await _close(tester, bloc);
    });

    testWidgets('P2-E25: the call icon of a CometChatCallLogs row tapped '
        'twice places one call', (tester) async {
      SoundChannelSpy.install();
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _StubRepo(
        loggedInUser: User(uid: 'me', name: 'Me'),
        pages: <Result<List<CallLog>>>[
          Success(<CallLog>[
            _log(
              initiator: CallUser(uid: 'me', name: 'Me'),
              receiver: CallUser(uid: 'bob', name: 'Bob'),
            ),
          ]),
        ],
      );
      final bloc = _blocFor(repo);
      const icon = Key('call-back');
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: CallNavigationContext.navigatorKey,
          localizationsDelegates: public.Translations.localizationsDelegates,
          home: Scaffold(
            body: calls.CometChatCallLogs(
              callLogsBloc: bloc,
              audioCallIcon: const Icon(Icons.call, key: icon),
            ),
          ),
        ),
      );
      await _settle(tester);

      await tester.tap(find.byKey(icon).first, warnIfMissed: false);
      await tester.tap(find.byKey(icon).first, warnIfMissed: false);
      await _settle(tester);

      expect(repo.initiatedCalls, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await _close(tester, bloc);
    });

    testWidgets('once it is done, the next tap is not dropped', (tester) async {
      final (bloc, repo, errors) = await ready(tester);
      CallUserLookup.debugFetchUser = (String uid) async =>
          User(uid: uid, name: 'Bob', blockedByMe: true);
      final context = CallNavigationContext.navigatorKey.currentContext!;

      bloc.add(callBack(context));
      await _settle(tester);
      bloc.add(callBack(context));
      await _settle(tester);

      expect(errors.map(codeOf), <String>['BLOCKED_BY_ME', 'BLOCKED_BY_ME']);
      await _close(tester, bloc);
    });

    testWidgets('with a call in progress: ACTIVE_CALL, nothing asked or '
        'placed', (tester) async {
      final (bloc, repo, errors) = await ready(tester);
      CallEventService.instance.activeCall = Call(
        sessionId: 'ongoing',
        receiverUid: 'someone',
        receiverType: 'user',
        type: 'audio',
      );

      bloc.add(callBack(CallNavigationContext.navigatorKey.currentContext!));
      await _settle(tester);

      expect(errors.map(codeOf), <String>['ACTIVE_CALL']);
      expect(PermissionChannelStub.requested, isEmpty);
      expect(repo.initiatedCalls, isEmpty);
      await _close(tester, bloc);
    });

    testWidgets('another component placing a call meanwhile: ACTIVE_CALL, '
        'nothing asked or placed; once it is done, the call-back goes '
        'through (round 2 review)', (tester) async {
      final (bloc, repo, errors) = await ready(tester);
      final Object callButtons = Object();
      final context = CallNavigationContext.navigatorKey.currentContext!;
      expect(ActiveCallTracker.beginPlacingCall(callButtons), isTrue);

      bloc.add(callBack(context));
      await _settle(tester);

      expect(errors.map(codeOf), <String>['ACTIVE_CALL']);
      expect(PermissionChannelStub.requested, isEmpty);
      expect(repo.initiatedCalls, isEmpty);

      ActiveCallTracker.endPlacingCall(callButtons);
      bloc.add(callBack(context));
      await _settle(tester);
      expect(repo.initiatedCalls, hasLength(1));
      // Its own placement is over too.
      expect(ActiveCallTracker.isPlacingCall, isFalse);
      await tester.pumpWidget(const SizedBox());
      await _close(tester, bloc);
    });

    testWidgets('the microphone refused: the callee is not fetched either', (
      tester,
    ) async {
      final (bloc, repo, errors) = await ready(tester);
      PermissionChannelStub.install(granted: false);
      var fetched = 0;
      CallUserLookup.debugFetchUser = (String uid) async {
        fetched++;
        return User(uid: uid, name: 'Bob');
      };

      bloc.add(callBack(CallNavigationContext.navigatorKey.currentContext!));
      await _settle(tester);

      expect(errors.map(codeOf), <String>['PERMISSION_DENIED']);
      expect(fetched, 0);
      expect(repo.initiatedCalls, isEmpty);
      await _close(tester, bloc);
    });

    testWidgets('the app navigator goes while the callee is fetched: '
        'NO_NAVIGATOR, and nothing is placed', (tester) async {
      final (bloc, repo, errors) = await ready(tester);
      final fetch = Completer<User>();
      CallUserLookup.debugFetchUser = (String uid) => fetch.future;

      bloc.add(callBack(CallNavigationContext.navigatorKey.currentContext!));
      await _settle(tester);
      await tester.pumpWidget(const SizedBox());
      fetch.complete(User(uid: 'bob', name: 'Bob'));
      await _settle(tester);

      expect(errors.map(codeOf), <String>['NO_NAVIGATOR']);
      expect(repo.initiatedCalls, isEmpty);
      await _close(tester, bloc);
    });

    testWidgets('P2-E24: the microphone refused: PERMISSION_DENIED naming '
        'it, and nothing placed', (tester) async {
      final (bloc, repo, errors) = await ready(tester);
      PermissionChannelStub.install(granted: false);

      bloc.add(callBack(CallNavigationContext.navigatorKey.currentContext!));
      await _settle(tester);

      final error = errors.single as CometChatException;
      expect(error.code, 'PERMISSION_DENIED');
      expect(error.details, 'microphone');
      expect(PermissionChannelStub.cameraRequested, isFalse);
      expect(repo.initiatedCalls, isEmpty);
      await _close(tester, bloc);
    });

    testWidgets('a video call-back asks for the camera too; permanently '
        'refused is PERMISSION_PERMANENTLY_DENIED', (tester) async {
      final (bloc, repo, errors) = await ready(tester);
      PermissionChannelStub.install(granted: false, permanentlyDenied: true);

      bloc.add(
        callBack(
          CallNavigationContext.navigatorKey.currentContext!,
          type: 'video',
        ),
      );
      await _settle(tester);

      final error = errors.single as CometChatException;
      expect(error.code, 'PERMISSION_PERMANENTLY_DENIED');
      expect(error.details, 'microphone,camera');
      expect(repo.initiatedCalls, isEmpty);
      await _close(tester, bloc);
    });

    testWidgets('a permission request that throws reaches onError with its '
        'code, and the next tap still goes through', (tester) async {
      final (bloc, repo, errors) = await ready(tester);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/permissions/methods'),
            (MethodCall call) async => throw PlatformException(
              code: 'PermissionHandler.PermissionManager',
              message: 'A request for permissions is already running.',
            ),
          );

      bloc.add(callBack(CallNavigationContext.navigatorKey.currentContext!));
      await _settle(tester);
      expect(errors.map(codeOf), <String>[
        'PermissionHandler.PermissionManager',
      ]);
      expect(repo.initiatedCalls, isEmpty);

      PermissionChannelStub.install(granted: true);
      bloc.add(callBack(CallNavigationContext.navigatorKey.currentContext!));
      await _settle(tester);
      expect(repo.initiatedCalls, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await _close(tester, bloc);
    });

    testWidgets('a callee the user has blocked: BLOCKED_BY_ME, nothing '
        'placed', (tester) async {
      final (bloc, repo, errors) = await ready(tester);
      CallUserLookup.debugFetchUser = (String uid) async =>
          User(uid: uid, name: 'Bob', blockedByMe: true);

      bloc.add(callBack(CallNavigationContext.navigatorKey.currentContext!));
      await _settle(tester);

      expect(errors.map(codeOf), <String>['BLOCKED_BY_ME']);
      expect(repo.initiatedCalls, isEmpty);
      await _close(tester, bloc);
    });

    testWidgets('a callee who has blocked the user: HAS_BLOCKED_ME, nothing '
        'placed', (tester) async {
      final (bloc, repo, errors) = await ready(tester);
      CallUserLookup.debugFetchUser = (String uid) async =>
          User(uid: uid, name: 'Bob', hasBlockedMe: true);

      bloc.add(callBack(CallNavigationContext.navigatorKey.currentContext!));
      await _settle(tester);

      expect(errors.map(codeOf), <String>['HAS_BLOCKED_ME']);
      expect(repo.initiatedCalls, isEmpty);
      await _close(tester, bloc);
    });

    testWidgets("the callee cannot be fetched: the SDK's own exception, and "
        'nothing placed', (tester) async {
      final (bloc, repo, errors) = await ready(tester);
      final sdkError = CometChatException(
        'ERR_UID_NOT_FOUND',
        'No user bob.',
        'User not found',
      );
      CallUserLookup.debugFetchUser = (String uid) async => throw sdkError;

      bloc.add(callBack(CallNavigationContext.navigatorKey.currentContext!));
      await _settle(tester);

      expect(errors.single, same(sdkError));
      expect(repo.initiatedCalls, isEmpty);
      await _close(tester, bloc);
    });

    testWidgets("P2-N12: the outgoing screen shows the callee's name and "
        'avatar, not the UID', (tester) async {
      final (bloc, repo, errors) = await ready(tester);
      CallUserLookup.debugFetchUser = (String uid) async =>
          User(uid: uid, name: 'Bob', avatar: 'https://a/bob.png');

      bloc.add(callBack(CallNavigationContext.navigatorKey.currentContext!));
      await _settle(tester);
      await tester.pumpAndSettle();

      final screen = tester.widget<CometChatOutgoingCall>(
        find.byType(CometChatOutgoingCall),
      );
      expect(screen.user?.name, 'Bob');
      expect(screen.user?.avatar, 'https://a/bob.png');
      expect(find.text('Bob'), findsWidgets);
      expect(find.text('bob'), findsNothing);
      expect(errors, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await _close(tester, bloc);
    });

    testWidgets('a group log is called back without fetching anyone', (
      tester,
    ) async {
      final (bloc, repo, errors) = await ready(tester);
      var fetched = 0;
      CallUserLookup.debugFetchUser = (String uid) async {
        fetched++;
        return User(uid: uid, name: uid);
      };

      bloc.add(
        InitiateCallFromLog(
          callLog: _log(
            initiator: CallUser(uid: 'me'),
            receiver: CallGroup(guid: 'g1'),
          ),
          context: CallNavigationContext.navigatorKey.currentContext!,
        ),
      );
      await _settle(tester);

      expect(fetched, 0);
      expect(repo.initiatedCalls.single.receiverType, 'group');
      await tester.pumpWidget(const SizedBox());
      await _close(tester, bloc);
    });
  });

  // =========================================================================
  // The ListBase hooks keep a session-id → index map in step with the list.
  // These need no event dispatch, so they run as plain tests.
  group('CallLogsBloc — session index map', () {
    late _StubRepo repo;
    late CallLogsBloc bloc;

    setUp(() {
      repo = _StubRepo();
      bloc = _blocFor(repo);
    });

    tearDown(() async {
      await bloc.close();
    });

    test('replaceAll rebuilds the map', () {
      bloc.replaceAll([_log(sessionId: 'a'), _log(sessionId: 'b')]);

      expect(bloc.findCallLogIndex('a'), 0);
      expect(bloc.findCallLogIndex('b'), 1);
    });

    test('an added item is indexed at the end', () {
      bloc.replaceAll([_log(sessionId: 'a')]);
      bloc.addItem(_log(sessionId: 'b'));

      expect(bloc.findCallLogIndex('b'), 1);
      expect(bloc.findCallLog('b')?.sessionId, 'b');
    });

    test('removing an item shifts the indices after it', () {
      final a = _log(sessionId: 'a');
      final b = _log(sessionId: 'b');
      final c = _log(sessionId: 'c');
      bloc.replaceAll([a, b, c]);

      bloc.removeItem(b);

      expect(bloc.findCallLogIndex('b'), isNull);
      expect(bloc.findCallLogIndex('a'), 0);
      expect(bloc.findCallLogIndex('c'), 1);
      expect(bloc.findCallLog('c')?.sessionId, 'c');
    });

    test('updating an item under a new session id re-keys the map', () {
      final a = _log(sessionId: 'a');
      bloc.replaceAll([a, _log(sessionId: 'b')]);

      bloc.updateItem(0, _log(sessionId: 'a2'));

      expect(bloc.findCallLogIndex('a'), isNull);
      expect(bloc.findCallLogIndex('a2'), 0);
    });

    test('updating an item under the same session id leaves the map alone', () {
      bloc.replaceAll([_log(sessionId: 'a'), _log(sessionId: 'b')]);

      bloc.updateItem(1, _log(sessionId: 'b', type: 'video'));

      expect(bloc.findCallLogIndex('b'), 1);
      expect(bloc.findCallLog('b')?.type, 'video');
    });

    test('clearing empties the map', () {
      bloc.replaceAll([_log(sessionId: 'a')]);

      bloc.clearItems();

      expect(bloc.findCallLogIndex('a'), isNull);
      expect(bloc.items, isEmpty);
    });

    test('a null or empty session id is never indexed', () {
      bloc.replaceAll([_log(sessionId: ''), _log(sessionId: 'b')]);

      expect(bloc.findCallLogIndex(null), isNull);
      expect(bloc.findCallLogIndex(''), isNull);
      expect(bloc.findCallLogIndex('b'), 1);
    });

    test('the map is rebuilt lazily after a clear', () {
      bloc.replaceAll([_log(sessionId: 'a')]);
      // clearItems marks the map as needing a rebuild ...
      bloc.clearItems();
      // ... and the next add goes in without one, so the first lookup after
      // that is what triggers the rebuild.
      bloc.addItem(_log(sessionId: 'z'));

      expect(bloc.findCallLogIndex('z'), 0);
      expect(bloc.findCallLogIndex('a'), isNull);
    });

    test('removing the last item leaves the lookup empty, not stale', () {
      final only = _log(sessionId: 'a');
      bloc.replaceAll([only]);

      bloc.removeItem(only);

      expect(bloc.items, isEmpty);
      expect(bloc.findCallLogIndex('a'), isNull);
    });
  });

  // =========================================================================
  test('use cases fall back to the service locator when none are injected', () {
    // The constructor's documented escape hatch: everything is optional and
    // resolved from CallLogsServiceLocator when left out.
    final bloc = CallLogsBloc();

    expect(bloc.getCallLogsUseCase, isA<GetCallLogsUseCase>());
    expect(bloc.loadMoreCallLogsUseCase, isA<LoadMoreCallLogsUseCase>());
    expect(bloc.initiateCallUseCase, isA<InitiateCallUseCase>());
    expect(bloc.getLoggedInUserUseCase, isA<GetLoggedInUserUseCase>());
    expect(bloc.state.status, CallLogsStatus.initial);
    // Not closed here: the locator-backed bloc reaches the real SDK in its
    // constructor, and closing would wait on that call.
  });

  test('close clears the session index', () async {
    final bloc = _blocFor(_StubRepo());
    bloc.replaceAll([_log(sessionId: 'a')]);
    expect(bloc.findCallLogIndex('a'), 0);

    await bloc.close();

    // The list itself survives, but the lookup map is dropped and does not
    // rebuild itself afterwards.
    expect(bloc.items.length, 1);
    expect(bloc.findCallLogIndex('a'), isNull);
    expect(bloc.isClosed, isTrue);
  });
}
