/// Banned members screen with offline support on (W6, ENG-41129): the
/// two-phase stream and how each phase lands on the screen's rows.
///
///   flutter test test/screens/banned_members_offline_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/two_phase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/screens/banned_members_offline.dart';

GroupMember _m(String uid) =>
    GroupMember(uid: uid, name: 'Member $uid', scope: 'participant');

class _Request extends Fake implements BannedGroupMembersRequest {
  _Request({this.cached, this.server, this.error = false});
  final List<GroupMember>? cached;
  final List<GroupMember>? server;
  final bool error;
  int calls = 0;
  bool legacyCallbacks = false;

  @override
  Future<List<GroupMember>> fetchNext({
    required Function(List<GroupMember> groupList)? onSuccess,
    required Function(CometChatException excep)? onError,
    BannedGroupMemberFetchListener? listener,
  }) async {
    calls++;
    legacyCallbacks = onSuccess != null || onError != null;
    if (cached != null) listener?.onCachedBannedGroupMembers(cached!);
    if (error) {
      listener?.onError(CometChatException('ERR_NETWORK', 'x', 'x'));
      return const [];
    }
    listener?.onServerBannedGroupMembers(server ?? const []);
    return server ?? const [];
  }
}

const BannedPageView _empty = (
  rows: <GroupMember>[],
  hasMore: true,
  hasError: false,
  isLoading: true,
);

List<String> _uids(BannedPageView v) => [for (final m in v.rows) m.uid];

Future<BannedPageView> _run(
  _Request request,
  BannedPageView start, {
  bool reload = false,
  List<BannedPageView>? steps,
}) async {
  final page = BannedMembersPage(reload: reload);
  var view = start;
  await for (final phase in bannedMembersFetchStream(request)) {
    view = page.apply(phase, view);
    steps?.add(view);
  }
  return view;
}

void main() {
  test('one fetch per page, listener only; cached paints, server replaces by '
      'uid with no duplicates', () async {
    final request = _Request(
      cached: [_m('a'), _m('b')],
      server: [_m('b'), _m('c')],
    );
    final steps = <BannedPageView>[];
    final view = await _run(request, _empty, steps: steps);

    expect(request.calls, 1);
    expect(request.legacyCallbacks, isFalse);
    expect(_uids(steps.first), ['a', 'b']);
    expect(steps.first.isLoading, isFalse);
    expect(_uids(view), ['b', 'c']);
    expect(view.hasMore, isTrue);
  });

  test(
    'next page: cached rows append, server page replaces them in place',
    () async {
      final start = (
        rows: [_m('a'), _m('b')],
        hasMore: true,
        hasError: false,
        isLoading: false,
      );
      final view = await _run(
        _Request(cached: [_m('b'), _m('c')], server: [_m('d')]),
        start,
      );
      expect(_uids(view), ['a', 'b', 'd']);
    },
  );

  test('an empty server page ends paging', () async {
    final start = (
      rows: [_m('a')],
      hasMore: true,
      hasError: false,
      isLoading: false,
    );
    final view = await _run(_Request(cached: [_m('z')], server: []), start);
    expect(_uids(view), ['a']);
    expect(view.hasMore, isFalse);
  });

  test('a server error after a cached page keeps the rows, no error', () async {
    final view = await _run(_Request(cached: [_m('a')], error: true), _empty);
    expect(_uids(view), ['a']);
    expect(view.hasError, isFalse);
    expect(view.hasMore, isTrue);
  });

  test('no cached page and an error shows today\'s error view', () async {
    final view = await _run(_Request(cached: [], error: true), _empty);
    expect(view.hasError, isTrue);
    expect(view.rows, isEmpty);
  });

  test('reconnect reload: rows stay, the cached page is skipped, the server '
      'page becomes the list', () async {
    final start = (
      rows: [_m('a'), _m('b'), _m('c')],
      hasMore: false,
      hasError: false,
      isLoading: false,
    );
    final request = _Request(cached: [_m('stale')], server: [_m('b'), _m('x')]);
    final steps = <BannedPageView>[];
    final view = await _run(request, start, reload: true, steps: steps);

    expect(request.calls, 1);
    expect(steps.expand(_uids), isNot(contains('stale')));
    expect(_uids(view), ['b', 'x']);
    expect(view.hasMore, isTrue);
  });

  test('reconnect reload after the error view recovers the list', () async {
    final start = (
      rows: <GroupMember>[],
      hasMore: true,
      hasError: true,
      isLoading: false,
    );
    final view = await _run(_Request(server: [_m('a')]), start, reload: true);
    expect(view.hasError, isFalse);
    expect(_uids(view), ['a']);
  });

  test('a late server page after an error is ignored', () async {
    final events = <TwoPhaseResult<GroupMember>>[];
    await for (final e in bannedMembersFetchStream(
      _Request(cached: [_m('a')], error: true),
    )) {
      events.add(e);
    }
    expect(events, hasLength(2));
    expect(events.last, isA<PhaseError<GroupMember>>());
  });

  group('BannedPageQueue', () {
    test('a reconnect while a page is loading queues one reload that runs '
        'when the page finishes', () {
      final queue = BannedPageQueue();
      expect(queue.tryStart(), isTrue);
      expect(queue.tryStart(), isFalse, reason: 'one page in flight');

      expect(queue.reconnect(), isFalse, reason: 'queued, not started');
      expect(queue.reconnect(), isFalse, reason: 'repeats collapse');

      expect(queue.finish(), isTrue, reason: 'the queued reload runs');
      expect(queue.reconnect(), isTrue);
      expect(queue.tryStart(), isTrue);
      expect(queue.finish(), isFalse, reason: 'ran once, nothing left');
    });

    test('a reconnect with no page loading reloads at once', () {
      final queue = BannedPageQueue();
      expect(queue.reconnect(), isTrue);
      expect(queue.tryStart(), isTrue);
      expect(queue.finish(), isFalse);
    });

    test('a page finishing with no reconnect queues nothing', () {
      final queue = BannedPageQueue();
      expect(queue.tryStart(), isTrue);
      expect(queue.finish(), isFalse);
      expect(queue.tryStart(), isTrue);
    });
  });
}
