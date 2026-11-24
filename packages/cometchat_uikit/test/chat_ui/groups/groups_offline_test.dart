/// Groups list with offline support on (W6, ENG-41129): two-phase pages,
/// replace by guid, the D84 list rules, reconnect reload, and offline off
/// unchanged.
///
/// These run the kit's real chain — bloc, use case, repository, data source —
/// against an app builder whose `build()` hands back a scripted request, so
/// every SDK call and the callbacks it was given are recorded.
///
///   flutter test test/chat_ui/groups/groups_offline_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/chat_ui/src/groups/bloc/groups_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/bloc/groups_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/bloc/groups_offline.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/bloc/groups_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/data/datasources/groups_remote_datasource.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/data/repositories/groups_repository_impl.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/domain/usecases/get_groups_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/domain/usecases/join_group_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/domain/usecases/load_more_groups_usecase.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_list_errors.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import 'package:flutter_test/flutter_test.dart';

// ─── Fakes ───────────────────────────────────────────────────────────────────

Group _u(String guid) => Group(guid: guid, name: 'Group $guid', type: 'public');

/// One page's answer: an optional cached phase, then a server page or error.
class _Page {
  const _Page({
    this.cached,
    this.server,
    this.error = false,
    this.errorCode = 'ERR_CONNECTION',
    this.hold,
  });
  final List<Group>? cached;
  final List<Group>? server;
  final bool error;
  final String errorCode;

  /// When set, the answer waits for it (ENG-41552 F race tests).
  final Completer<void>? hold;
}

/// What one `fetchNext` call was given.
typedef _Call = ({bool listener, bool onSuccess, String? keyword});

class _Script {
  _Script(this.pages);
  final List<_Page> pages;
  final calls = <_Call>[];
}

class _ScriptedRequest extends Fake implements GroupsRequest {
  _ScriptedRequest(this.script, this.keyword);
  final _Script script;
  final String? keyword;

  @override
  Future<List<Group>> fetchNext({
    GroupFetchListener? listener,
    required Function(List<Group> groupList)? onSuccess,
    required Function(CometChatException excep)? onError,
  }) async {
    script.calls.add((
      listener: listener != null,
      onSuccess: onSuccess != null,
      keyword: keyword,
    ));
    final page = script.pages.removeAt(0);
    if (page.hold != null) await page.hold!.future;
    await Future<void>.delayed(Duration.zero);
    if (page.cached != null) listener?.onCachedGroups(page.cached!);
    await Future<void>.delayed(Duration.zero);
    if (page.error) {
      final e = CometChatException(page.errorCode, 'offline', 'offline');
      onError?.call(e);
      listener?.onError(e);
      return const [];
    }
    final rows = page.server ?? const <Group>[];
    onSuccess?.call(rows);
    listener?.onServerGroups(rows);
    return rows;
  }
}

class _AppBuilder extends GroupsRequestBuilder {
  _AppBuilder(this.script);
  final _Script script;

  @override
  GroupsRequest build() => _ScriptedRequest(script, searchKeyword);
}

class _Remote extends GroupsRemoteDataSourceImpl {
  @override
  Future<User?> getLoggedInUser() async => null;

  @override
  Future<Group> joinGroup({
    required String guid,
    required String groupType,
    String? password,
  }) async {
    throw const GroupsRemoteDataSourceException(message: 'offline');
  }
}

GroupsRepositoryImpl _repo() =>
    GroupsRepositoryImpl(remoteDataSource: _Remote());

GroupsBloc _bloc(GroupsRequestBuilder builder, {GroupsRepositoryImpl? repo}) {
  final r = repo ?? _repo();
  return GroupsBloc(
    getGroupsUseCase: GetGroupsUseCase(r),
    loadMoreGroupsUseCase: LoadMoreGroupsUseCase(r),
    getLoggedInUserUseCase: GetLoggedInUserUseCase(r),
    disableSDKListeners: true,
    groupsRequestBuilder: builder,
  );
}

List<String> _uids(GroupsState s) => [
  for (final u in (s as GroupsLoaded).groups) u.guid,
];

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await pumpEventQueue();
  }
}

Future<void> _afterDebounce() async {
  await Future<void>.delayed(const Duration(milliseconds: 350));
  await _settle();
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  tearDown(() => CometChat.debugSetOfflineEnabledOverride(null));

  group('offline on', () {
    setUp(() => CometChat.debugSetOfflineEnabledOverride(true));

    test('cached page paints, server page replaces it by guid, one fetch, '
        'no duplicates', () async {
      final script = _Script([
        _Page(cached: [_u('a'), _u('b')], server: [_u('b'), _u('c')]),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      final seen = <List<String>>[];
      final sub = bloc.stream.listen((s) {
        if (s is GroupsLoaded) seen.add(_uids(s));
      });

      bloc.add(const LoadGroups());
      await _settle();

      expect(script.calls, hasLength(1));
      expect(script.calls.single.listener, isTrue);
      expect(script.calls.single.onSuccess, isFalse);
      expect(seen.first, ['a', 'b']);
      expect(_uids(bloc.state), ['b', 'c']);
      expect((bloc.state as GroupsLoaded).hasMore, isTrue);
      await sub.cancel();
      await bloc.close();
    });

    test('load more: cached page appended, server page replaces it in place; '
        'rows already listed are never duplicated', () async {
      final script = _Script([
        _Page(server: [_u('a'), _u('b')]),
        _Page(cached: [_u('b'), _u('c'), _u('d')], server: [_u('d'), _u('e')]),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      bloc.add(const LoadGroups());
      await _settle();

      bloc.add(const LoadMoreGroups());
      await _settle();

      expect(script.calls, hasLength(2));
      expect(_uids(bloc.state), ['a', 'b', 'd', 'e']);
      expect((bloc.state as GroupsLoaded).isLoadingMore, isFalse);
      expect((bloc.state as GroupsLoaded).hasMore, isTrue);
      await bloc.close();
    });

    test(
      'an empty server page ends paging and drops the cached page',
      () async {
        final script = _Script([
          _Page(server: [_u('a')]),
          _Page(cached: [_u('z')], server: const []),
        ]);
        final bloc = _bloc(_AppBuilder(script));
        bloc.add(const LoadGroups());
        await _settle();
        bloc.add(const LoadMoreGroups());
        await _settle();

        expect(_uids(bloc.state), ['a']);
        expect((bloc.state as GroupsLoaded).hasMore, isFalse);
        await bloc.close();
      },
    );

    test(
      'a server error after a cached page keeps the rows, no error',
      () async {
        final script = _Script([
          _Page(cached: [_u('a'), _u('b')], error: true),
        ]);
        final bloc = _bloc(_AppBuilder(script));
        final states = <GroupsState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const LoadGroups());
        await _settle();

        expect(_uids(bloc.state), ['a', 'b']);
        expect(states.whereType<GroupsError>(), isEmpty);
        await sub.cancel();
        await bloc.close();
      },
    );

    test('a load-more error keeps every row and shows no error', () async {
      final script = _Script([
        _Page(server: [_u('a')]),
        _Page(error: true),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      bloc.add(const LoadGroups());
      await _settle();
      bloc.add(const LoadMoreGroups());
      await _settle();

      expect(_uids(bloc.state), ['a']);
      expect((bloc.state as GroupsLoaded).isLoadingMore, isFalse);
      expect((bloc.state as GroupsLoaded).hasMore, isFalse);
      await bloc.close();
    });

    test(
      'no cached page and a server error shows today\'s error state',
      () async {
        final script = _Script([
          const _Page(error: true, errorCode: 'ERR_TOO_MANY_REQUESTS'),
        ]);
        final bloc = _bloc(_AppBuilder(script));
        bloc.add(const LoadGroups());
        await _settle();
        expect(bloc.state, isA<GroupsError>());
        await bloc.close();
      },
    );

    test('D84 (7): a keyword search offline with no cached match shows '
        '"Connect to search"', () async {
      final script = _Script([
        _Page(server: [_u('a')]),
        const _Page(cached: [], error: true),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      bloc.add(const LoadGroups());
      await _settle();
      final states = <GroupsState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const SearchGroups('abc'));
      await _afterDebounce();

      expect(script.calls.last.keyword, 'abc');
      expect(bloc.state, isA<GroupsConnectToSearch>());
      await sub.cancel();
      await bloc.close();
    });

    test("D84 (7): an app builder's keyword offline with nothing cached shows "
        '"Connect to search"', () async {
      final script = _Script([const _Page(cached: [], error: true)]);
      final builder = _AppBuilder(script)..searchKeyword = 'abc';
      final bloc = _bloc(builder);
      bloc.add(const LoadGroups());
      await _settle();
      expect(bloc.state, isA<GroupsConnectToSearch>());
      await bloc.close();
    });

    test(
      'D84 (3): type, joined-only and tag filters with no keyword, offline '
      'with nothing cached, are a plain list: "Connect to load groups"',
      () async {
        final script = _Script([const _Page(cached: [], error: true)]);
        final builder = _AppBuilder(script)
          ..joinedOnly = true
          ..tags = ['team'];
        final bloc = _bloc(builder);
        bloc.add(const LoadGroups());
        await _settle();
        expect(bloc.state, isA<GroupsConnectToLoad>());
        await bloc.close();
      },
    );

    test('D84 (3): a blank app-builder keyword is no keyword: a plain '
        'list', () async {
      final script = _Script([const _Page(cached: [], error: true)]);
      final builder = _AppBuilder(script)..searchKeyword = '   ';
      final bloc = _bloc(builder);
      bloc.add(const LoadGroups());
      await _settle();
      expect(bloc.state, isA<GroupsConnectToLoad>());
      await bloc.close();
    });

    test('D84 (7): every connection error code under an app-builder keyword '
        'shows "Connect to search"', () async {
      for (final code in const [
        'ERR_CONNECTION',
        'ERR_NETWORK_TIMEOUT',
        'ERROR_INTERNET_UNAVAILABLE',
        'ERROR_IO_EXCEPTION',
      ]) {
        final script = _Script([
          _Page(cached: const [], error: true, errorCode: code),
        ]);
        final builder = _AppBuilder(script)..searchKeyword = 'abc';
        final bloc = _bloc(builder);
        bloc.add(const LoadGroups());
        await _settle();
        expect(bloc.state, isA<GroupsConnectToSearch>(), reason: code);
        await bloc.close();
      }
    });

    test('online, a server error under an app-builder keyword shows today\'s '
        'error', () async {
      final script = _Script([
        const _Page(
          cached: [],
          error: true,
          errorCode: 'ERR_TOO_MANY_REQUESTS',
        ),
      ]);
      final builder = _AppBuilder(script)..searchKeyword = 'abc';
      final bloc = _bloc(builder);
      bloc.add(const LoadGroups());
      await _settle();
      expect(bloc.state, isA<GroupsError>());
      await bloc.close();
    });

    test('online, a keyword search that hits a server error shows today\'s '
        'result', () async {
      final script = _Script([
        _Page(server: [_u('a')]),
        const _Page(cached: [], error: true, errorCode: 'ERR_INTERNAL_SERVER'),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      bloc.add(const LoadGroups());
      await _settle();
      final states = <Object>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const SearchGroups('abc'));
      await _afterDebounce();

      expect(script.calls.last.keyword, 'abc');
      expect(bloc.state, isA<GroupsError>());
      await sub.cancel();
      await bloc.close();
    });

    test('a keyword search online runs as today', () async {
      final script = _Script([
        _Page(server: [_u('a')]),
        _Page(cached: const [], server: [_u('abc1')]),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      bloc.add(const LoadGroups());
      await _settle();
      bloc.add(const SearchGroups('abc'));
      await _afterDebounce();
      expect(_uids(bloc.state), ['abc1']);
      await bloc.close();
    });

    test('reconnect (ConnectionRestored, the connection listener\'s event) '
        'reads the first page once, two-phase, and swaps rows once', () async {
      final script = _Script([
        _Page(server: [_u('a'), _u('b')]),
        _Page(cached: [_u('stale')], server: [_u('b'), _u('c')]),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      bloc.add(const LoadGroups());
      await _settle();
      final seen = <List<String>>[];
      final sub = bloc.stream.listen((s) {
        if (s is GroupsLoaded) seen.add(_uids(s));
      });

      bloc.add(const ConnectionRestored());
      await _settle();

      expect(script.calls, hasLength(2));
      expect(script.calls.last.listener, isTrue);
      expect(seen.expand((e) => e), isNot(contains('stale')));
      expect(_uids(bloc.state), ['b', 'c']);
      await sub.cancel();
      await bloc.close();
    });

    test(
      'a server page with the same row count tells the view to redraw',
      () async {
        final script = _Script([
          _Page(cached: [_u('a')], server: [_u('b')]),
        ]);
        final bloc = _bloc(_AppBuilder(script));
        final loaded = <GroupsLoaded>[];
        final sub = bloc.stream.listen((s) {
          if (s is GroupsLoaded) loaded.add(s);
        });
        bloc.add(const LoadGroups());
        await _settle();

        final cached = loaded.firstWhere((s) => s.groups.first.guid == 'a');
        final server = loaded.lastWhere((s) => s.groups.first.guid == 'b');
        expect(
          GroupsOffline.needsRebuild(cached.groups, server.groups),
          isTrue,
        );
        expect(
          GroupsOffline.needsRebuild(server.groups, server.groups),
          isFalse,
        );
        await sub.cancel();
        await bloc.close();
      },
    );

    test('an own action offline (join) ends in the error and leaves the '
        'list as it was', () async {
      final script = _Script([
        _Page(server: [_u('a')]),
      ]);
      final repo = _repo();
      final bloc = _bloc(_AppBuilder(script), repo: repo);
      bloc.add(const LoadGroups());
      await _settle();
      final before = bloc.state;

      final result = await JoinGroupUseCase(repo)(
        guid: 'a',
        groupType: 'public',
      );
      await _settle();

      expect(result, isA<Failure>());
      expect(bloc.state, before);
      expect((bloc.state as GroupsLoaded).groups.single.hasJoined, isNot(true));
      await bloc.close();
    });
  });

  group('offline off', () {
    setUp(() => CometChat.debugSetOfflineEnabledOverride(false));

    test('each page is one legacy fetch, no listener, as today', () async {
      final script = _Script([
        _Page(cached: [_u('x')], server: [_u('a'), _u('b')]),
        _Page(server: [_u('c')]),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      final states = <GroupsState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const LoadGroups());
      await _settle();
      bloc.add(const LoadMoreGroups());
      await _settle();

      expect(script.calls, hasLength(2));
      expect(script.calls.every((c) => !c.listener && c.onSuccess), isTrue);
      expect(_uids(bloc.state), ['a', 'b', 'c']);
      expect(
        states.whereType<GroupsLoaded>().expand(_uids),
        isNot(contains('x')),
      );
      await sub.cancel();
      await bloc.close();
    });

    test('a keyword search that fails shows today\'s error', () async {
      final script = _Script([
        _Page(server: [_u('a')]),
        const _Page(error: true),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      bloc.add(const LoadGroups());
      await _settle();
      bloc.add(const SearchGroups('abc'));
      await _afterDebounce();
      expect(bloc.state, isA<GroupsError>());
      await bloc.close();
    });
  });

  group('GroupsOffline.replacePage', () {
    test('updates in place, drops unconfirmed cached rows, appends new', () {
      final out = GroupsOffline.replacePage(
        [_u('a'), _u('b'), _u('c')],
        {'b', 'c'},
        [_u('c'), _u('d'), _u('d')],
      );
      expect([for (final u in out) u.guid], ['a', 'c', 'd']);
    });
  });

  // ENG-41552: the D84 list rules and stale search (F).
  group('ENG-41552', () {
    test('D84 (2): offline on, cached rows and a not-connected error keep '
        'the rows, show no error and do not reach onError', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final script = _Script([
        _Page(cached: [_u('a')], error: true, errorCode: 'ERR_CONNECTION'),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      final errors = <CometChatException>[];
      OfflineListErrors.listen(bloc, errors.add);
      final states = <GroupsState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const LoadGroups());
      await _settle();

      expect(_uids(bloc.state), ['a']);
      expect(states.whereType<GroupsError>(), isEmpty);
      expect(errors, isEmpty);
      await sub.cancel();
      await bloc.close();
    });

    test('D84 (5): offline on, cached rows and a real server error on an '
        'open keep the rows and reach onError once', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final script = _Script([
        _Page(
          cached: [_u('a')],
          error: true,
          errorCode: 'ERR_TOO_MANY_REQUESTS',
        ),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      final errors = <CometChatException>[];
      OfflineListErrors.listen(bloc, errors.add);
      bloc.add(const LoadGroups());
      await _settle();

      expect(_uids(bloc.state), ['a']);
      expect(errors.single.code, 'ERR_TOO_MANY_REQUESTS');
      await bloc.close();
    });

    test('D84 (5): a kit-started (silent) read over cached rows that hits a '
        'real server error stays quiet', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final script = _Script([
        _Page(
          cached: [_u('a')],
          error: true,
          errorCode: 'ERR_TOO_MANY_REQUESTS',
        ),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      final errors = <CometChatException>[];
      OfflineListErrors.listen(bloc, errors.add);
      bloc.add(const LoadGroups(silent: true));
      await _settle();

      expect(_uids(bloc.state), ['a']);
      expect(errors, isEmpty);
      await bloc.close();
    });

    test('D84 (3), (8): offline on, nothing cached and a not-connected error '
        'shows "Connect to load groups"; a reconnect loads once and replaces '
        'it', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final script = _Script([
        const _Page(cached: [], error: true, errorCode: 'ERR_CONNECTION'),
        _Page(server: [_u('a')]),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      final errors = <CometChatException>[];
      OfflineListErrors.listen(bloc, errors.add);
      bloc.add(const LoadGroups());
      await _settle();
      expect(bloc.state, isA<GroupsConnectToLoad>());
      expect((bloc.state as GroupsConnectToLoad).error.code, 'ERR_CONNECTION');
      expect(errors, isEmpty, reason: 'the offline state itself fires onError');

      bloc.add(const ConnectionRestored());
      await _settle();
      expect(_uids(bloc.state), ['a']);
      expect(script.calls, hasLength(2));
      await bloc.close();
    });

    test('D84 (8): two reconnects over the offline state load once', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final hold = Completer<void>();
      final script = _Script([
        const _Page(cached: [], error: true, errorCode: 'ERR_CONNECTION'),
        _Page(server: [_u('a')], hold: hold),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      bloc.add(const LoadGroups());
      await _settle();
      expect(bloc.state, isA<GroupsConnectToLoad>());
      bloc.add(const ConnectionRestored());
      await _settle();
      bloc.add(const ConnectionRestored());
      await _settle();
      hold.complete();
      await _settle();
      expect(script.calls, hasLength(2));
      expect(_uids(bloc.state), ['a']);
      await bloc.close();
    });

    test('D84 (7), (8): a search offline with no cached match shows "Connect '
        'to search" and runs again once on reconnect', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final script = _Script([
        _Page(server: [_u('a')]),
        const _Page(cached: [], error: true, errorCode: 'ERR_CONNECTION'),
        _Page(server: [_u('abc1')]),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      bloc.add(const LoadGroups());
      await _settle();
      bloc.add(const SearchGroups('abc'));
      await _afterDebounce();
      expect(bloc.state, isA<GroupsConnectToSearch>());

      bloc.add(const ConnectionRestored());
      await _settle();
      expect(script.calls.map((c) => c.keyword), [null, 'abc', 'abc']);
      expect(_uids(bloc.state), ['abc1']);
      await bloc.close();
    });

    test(
      'D84 (6): offline on, an empty server page shows the empty view',
      () async {
        CometChat.debugSetOfflineEnabledOverride(true);
        final script = _Script([const _Page(cached: [], server: [])]);
        final bloc = _bloc(_AppBuilder(script));
        bloc.add(const LoadGroups());
        await _settle();
        expect(bloc.state, isA<GroupsEmpty>());
        await bloc.close();
      },
    );

    test('D84 (4), (8): offline on, a server error (not offline) shows the '
        'error view and is not reloaded on reconnect', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final script = _Script([
        const _Page(
          cached: [],
          error: true,
          errorCode: 'ERR_TOO_MANY_REQUESTS',
        ),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      bloc.add(const LoadGroups());
      await _settle();
      expect(bloc.state, isA<GroupsError>());
      bloc.add(const ConnectionRestored());
      await _settle();
      expect(script.calls, hasLength(1));
      await bloc.close();
    });

    // Review fix (D84): ERR_NETWORK is the SDK's catch-all for an unexpected
    // failure, not a lost connection (that is ERR_CONNECTION).
    test(
      'review: ERR_NETWORK with nothing shown is the error view (Retry, '
      'onError), not the offline state; a reconnect does not reload it',
      () async {
        CometChat.debugSetOfflineEnabledOverride(true);
        final script = _Script([
          const _Page(cached: [], error: true, errorCode: 'ERR_NETWORK'),
        ]);
        final bloc = _bloc(_AppBuilder(script));
        bloc.add(const LoadGroups());
        await _settle();
        expect(bloc.state, isA<GroupsError>());
        bloc.add(const ConnectionRestored());
        await _settle();
        expect(script.calls, hasLength(1));
        await bloc.close();
      },
    );

    test('review: ERR_NETWORK over cached rows on a user-started load keeps '
        'the rows and reaches onError once', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final script = _Script([
        _Page(cached: [_u('a')], error: true, errorCode: 'ERR_NETWORK'),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      final errors = <CometChatException>[];
      OfflineListErrors.listen(bloc, errors.add);
      bloc.add(const LoadGroups());
      await _settle();
      expect(_uids(bloc.state), ['a']);
      expect(errors.single.code, 'ERR_NETWORK');
      await bloc.close();
    });

    test('review: ERR_CONNECTION stays not-connected: no onError over cached '
        'rows, and the offline state with nothing shown', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final script = _Script([
        _Page(cached: [_u('a')], error: true, errorCode: 'ERR_CONNECTION'),
        const _Page(cached: [], error: true, errorCode: 'ERR_CONNECTION'),
      ]);
      final errors = <CometChatException>[];
      final kept = _bloc(_AppBuilder(script));
      OfflineListErrors.listen(kept, errors.add);
      kept.add(const LoadGroups());
      await _settle();
      expect(_uids(kept.state), ['a']);
      expect(errors, isEmpty);
      await kept.close();

      final empty = _bloc(_AppBuilder(script));
      OfflineListErrors.listen(empty, errors.add);
      empty.add(const LoadGroups());
      await _settle();
      expect(empty.state, isA<GroupsConnectToLoad>());
      expect(errors, isEmpty);
      await empty.close();
    });

    test('D84 (11): offline off, a connection error shows today\'s error and '
        'a reconnect does not reload it', () async {
      CometChat.debugSetOfflineEnabledOverride(false);
      final script = _Script([
        const _Page(error: true, errorCode: 'ERR_CONNECTION'),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      bloc.add(const LoadGroups());
      await _settle();
      expect(bloc.state, isA<GroupsError>());
      bloc.add(const ConnectionRestored());
      await _settle();
      expect(script.calls, hasLength(1));
      await bloc.close();
    });

    for (final on in [true, false]) {
      test('F: a search for the old keyword that answers after the new one '
          'is ignored (offline ${on ? 'on' : 'off'})', () async {
        CometChat.debugSetOfflineEnabledOverride(on);
        final hold = Completer<void>();
        final script = _Script([
          _Page(server: [_u('a')]),
          _Page(server: [_u('old')], hold: hold),
          _Page(server: [_u('new')]),
        ]);
        final bloc = _bloc(_AppBuilder(script));
        bloc.add(const LoadGroups());
        await _settle();

        bloc.add(const SearchGroups('ol'));
        await _afterDebounce();
        bloc.add(const SearchGroups('ne'));
        await _afterDebounce();
        expect(_uids(bloc.state), ['new']);

        hold.complete();
        await _settle();
        expect(script.calls.map((c) => c.keyword), [null, 'ol', 'ne']);
        expect(_uids(bloc.state), ['new']);
        await bloc.close();
      });
    }
  });
}
