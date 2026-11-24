/// Group members list with offline support on (W6, ENG-41129): two-phase
/// pages, replace by uid, the D84 list rules, reconnect reload, own actions
/// offline, and offline off unchanged.
///
/// These run the kit's real chain — bloc, use case, repository, data source —
/// against an app builder whose `build()` hands back a scripted request, so
/// every SDK call and the callbacks it was given are recorded.
///
///   flutter test test/chat_ui/group_members/group_members_offline_test.dart
library;

// Aliased: the barrel re-exports two different `GetLoggedInUserUseCase`
// classes (group_members' and groups'), so this one has to be named.
import 'dart:async';

import 'package:cometchat_chat_uikit/chat_ui/src/group_members/domain/usecases/get_logged_in_user_usecase.dart'
    as gm;
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/group_members/bloc/group_members_offline.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_list_errors.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_presence.dart';
import 'package:cometchat_chat_uikit/src/chat_sdk_listeners.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Fakes ───────────────────────────────────────────────────────────────────

GroupMember _m(String uid) =>
    GroupMember(uid: uid, name: 'Member $uid', scope: 'participant');

class _Page {
  const _Page({
    this.cached,
    this.server,
    this.error = false,
    this.errorCode = 'ERR_CONNECTION',
    this.hold,
  });
  final List<GroupMember>? cached;
  final List<GroupMember>? server;
  final bool error;
  final String errorCode;

  /// When set, the answer waits for it (ENG-41552 F race tests).
  final Completer<void>? hold;
}

typedef _Call = ({bool listener, bool onSuccess, String? keyword});

class _Script {
  _Script(this.pages);
  final List<_Page> pages;
  final calls = <_Call>[];
}

class _ScriptedRequest extends Fake implements GroupMembersRequest {
  _ScriptedRequest(this.script, this.keyword);
  final _Script script;
  final String? keyword;

  @override
  Future<List<GroupMember>> fetchNext({
    required Function(List<GroupMember> groupMemberList)? onSuccess,
    required Function(CometChatException excep)? onError,
    GroupMemberFetchListener? listener,
  }) async {
    script.calls.add((
      listener: listener != null,
      onSuccess: onSuccess != null,
      keyword: keyword,
    ));
    final page = script.pages.removeAt(0);
    if (page.hold != null) await page.hold!.future;
    await Future<void>.delayed(Duration.zero);
    if (page.cached != null) listener?.onCachedGroupMembers(page.cached!);
    await Future<void>.delayed(Duration.zero);
    if (page.error) {
      final e = CometChatException(page.errorCode, 'offline', 'offline');
      onError?.call(e);
      listener?.onError(e);
      return const [];
    }
    final rows = page.server ?? const <GroupMember>[];
    onSuccess?.call(rows);
    listener?.onServerGroupMembers(rows);
    return rows;
  }
}

class _AppBuilder extends GroupMembersRequestBuilder {
  _AppBuilder(this.script) : super('g1');
  final _Script script;

  @override
  GroupMembersRequest build() => _ScriptedRequest(script, searchKeyword);
}

class _Remote extends GroupMembersRemoteDataSourceImpl {
  int kicks = 0;

  @override
  Future<User?> getLoggedInUser() async => null;

  @override
  Future<Conversation?> getConversation(String guid) async => null;

  @override
  Future<void> kickGroupMember({
    required String guid,
    required String uid,
  }) async {
    kicks++;
    throw const GroupMembersRemoteDataSourceException(message: 'offline');
  }
}

final _group = Group(guid: 'g1', name: 'Dev Team', type: 'public');

GroupMembersBloc _bloc(GroupMembersRequestBuilder builder, {_Remote? remote}) {
  final repo = GroupMembersRepositoryImpl(
    remoteDataSource: remote ?? _Remote(),
  );
  return GroupMembersBloc(
    group: _group,
    getGroupMembersUseCase: GetGroupMembersUseCase(repo),
    loadMoreGroupMembersUseCase: LoadMoreGroupMembersUseCase(repo),
    kickGroupMemberUseCase: KickGroupMemberUseCase(repo),
    banGroupMemberUseCase: BanGroupMemberUseCase(repo),
    updateMemberScopeUseCase: UpdateMemberScopeUseCase(repo),
    getLoggedInUserUseCase: gm.GetLoggedInUserUseCase(repo),
    repository: repo,
    disableSDKListeners: true,
    groupMembersRequestBuilder: builder,
  );
}

List<String> _uids(GroupMembersState s) => [
  for (final m in (s as GroupMembersLoaded).members) m.uid,
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

    test('cached page paints, server page replaces it by uid, one fetch, '
        'no duplicates', () async {
      final script = _Script([
        _Page(cached: [_m('a'), _m('b')], server: [_m('b'), _m('c')]),
      ]);
      final bloc = _bloc(_AppBuilder(script)..limit = 2);
      final seen = <List<String>>[];
      final sub = bloc.stream.listen((s) {
        if (s is GroupMembersLoaded) seen.add(_uids(s));
      });

      bloc.add(const LoadGroupMembers());
      await _settle();

      expect(script.calls, hasLength(1));
      expect(script.calls.single.listener, isTrue);
      expect(script.calls.single.onSuccess, isFalse);
      expect(seen.first, ['a', 'b']);
      expect(_uids(bloc.state), ['b', 'c']);
      expect((bloc.state as GroupMembersLoaded).hasMore, isTrue);
      await sub.cancel();
      await bloc.close();
    });

    test('load more: cached page appended, server page replaces it in place; '
        'rows already listed are never duplicated', () async {
      final script = _Script([
        _Page(server: [_m('a'), _m('b')]),
        _Page(cached: [_m('b'), _m('c'), _m('d')], server: [_m('d'), _m('e')]),
      ]);
      final bloc = _bloc(_AppBuilder(script)..limit = 2);
      bloc.add(const LoadGroupMembers());
      await _settle();

      bloc.add(const LoadMoreGroupMembers());
      await _settle();

      expect(script.calls, hasLength(2));
      expect(_uids(bloc.state), ['a', 'b', 'd', 'e']);
      expect((bloc.state as GroupMembersLoaded).isLoadingMore, isFalse);
      await bloc.close();
    });

    test(
      'an empty server page ends paging and drops the cached page',
      () async {
        final script = _Script([
          _Page(server: [_m('a'), _m('b')]),
          _Page(cached: [_m('z')], server: const []),
        ]);
        final bloc = _bloc(_AppBuilder(script)..limit = 2);
        bloc.add(const LoadGroupMembers());
        await _settle();
        bloc.add(const LoadMoreGroupMembers());
        await _settle();

        expect(_uids(bloc.state), ['a', 'b']);
        expect((bloc.state as GroupMembersLoaded).hasMore, isFalse);
        await bloc.close();
      },
    );

    test(
      'a server error after a cached page keeps the rows, no error',
      () async {
        final script = _Script([
          _Page(cached: [_m('a'), _m('b')], error: true),
        ]);
        final bloc = _bloc(_AppBuilder(script));
        final states = <GroupMembersState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const LoadGroupMembers());
        await _settle();

        expect(_uids(bloc.state), ['a', 'b']);
        expect(states.whereType<GroupMembersError>(), isEmpty);
        await sub.cancel();
        await bloc.close();
      },
    );

    test('a load-more error keeps every row and shows no error', () async {
      final script = _Script([
        _Page(server: [_m('a'), _m('b')]),
        const _Page(error: true),
      ]);
      final bloc = _bloc(_AppBuilder(script)..limit = 2);
      bloc.add(const LoadGroupMembers());
      await _settle();
      bloc.add(const LoadMoreGroupMembers());
      await _settle();

      expect(_uids(bloc.state), ['a', 'b']);
      expect((bloc.state as GroupMembersLoaded).isLoadingMore, isFalse);
      expect((bloc.state as GroupMembersLoaded).hasMore, isFalse);
      await bloc.close();
    });

    test(
      'no cached page and a server error shows today\'s error state',
      () async {
        final script = _Script([
          const _Page(error: true, errorCode: 'ERR_TOO_MANY_REQUESTS'),
        ]);
        final bloc = _bloc(_AppBuilder(script));
        bloc.add(const LoadGroupMembers());
        await _settle();
        expect(bloc.state, isA<GroupMembersError>());
        await bloc.close();
      },
    );

    test('D84 (7): a keyword search offline with no cached match shows '
        '"Connect to search"', () async {
      final script = _Script([
        _Page(server: [_m('a')]),
        const _Page(cached: [], error: true),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      bloc.add(const LoadGroupMembers());
      await _settle();
      final states = <GroupMembersState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const SearchGroupMembers('abc'));
      await _afterDebounce();

      expect(script.calls.last.keyword, 'abc');
      expect(bloc.state, isA<GroupMembersConnectToSearch>());
      await sub.cancel();
      await bloc.close();
    });

    test('D84 (3): a presence filter with no keyword, offline with nothing '
        'cached, is a plain list: "Connect to load members"', () async {
      final script = _Script([const _Page(cached: [], error: true)]);
      final builder = _AppBuilder(script)..status = 'online';
      final bloc = _bloc(builder);
      bloc.add(const LoadGroupMembers());
      await _settle();
      expect(bloc.state, isA<GroupMembersConnectToLoad>());
      await bloc.close();
    });

    test('D84 (3): a scope filter with no keyword is a plain list', () async {
      final script = _Script([const _Page(cached: [], error: true)]);
      final builder = _AppBuilder(script)..scopes = ['admin', 'moderator'];
      final bloc = _bloc(builder);
      bloc.add(const LoadGroupMembers());
      await _settle();
      expect(bloc.state, isA<GroupMembersConnectToLoad>());
      await bloc.close();
    });

    test('D84 (3): a blank app-builder keyword is no keyword: a plain '
        'list', () async {
      final script = _Script([const _Page(cached: [], error: true)]);
      final builder = _AppBuilder(script)
        ..searchKeyword = '   '
        ..status = 'online';
      final bloc = _bloc(builder);
      bloc.add(const LoadGroupMembers());
      await _settle();
      expect(bloc.state, isA<GroupMembersConnectToLoad>());
      await bloc.close();
    });

    test('D84 (7): an app-builder keyword with a presence filter shows '
        '"Connect to search"', () async {
      final script = _Script([const _Page(cached: [], error: true)]);
      final builder = _AppBuilder(script)
        ..searchKeyword = 'abc'
        ..status = 'online';
      final bloc = _bloc(builder);
      bloc.add(const LoadGroupMembers());
      await _settle();
      expect(bloc.state, isA<GroupMembersConnectToSearch>());
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
        bloc.add(const LoadGroupMembers());
        await _settle();
        expect(bloc.state, isA<GroupMembersConnectToSearch>(), reason: code);
        await bloc.close();
      }
    });

    test('online, a server error under a presence filter shows today\'s '
        'error', () async {
      final script = _Script([
        const _Page(
          cached: [],
          error: true,
          errorCode: 'ERR_TOO_MANY_REQUESTS',
        ),
      ]);
      final builder = _AppBuilder(script)..status = 'online';
      final bloc = _bloc(builder);
      bloc.add(const LoadGroupMembers());
      await _settle();
      expect(bloc.state, isA<GroupMembersError>());
      await bloc.close();
    });

    test('online, a keyword search that hits a server error shows today\'s '
        'result', () async {
      final script = _Script([
        _Page(server: [_m('a')]),
        const _Page(cached: [], error: true, errorCode: 'ERR_INTERNAL_SERVER'),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      bloc.add(const LoadGroupMembers());
      await _settle();
      final states = <Object>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const SearchGroupMembers('abc'));
      await _afterDebounce();

      expect(script.calls.last.keyword, 'abc');
      // Today a failed search keeps the list.
      expect(_uids(bloc.state), ['a']);
      await sub.cancel();
      await bloc.close();
    });

    test('a keyword search online runs as today', () async {
      final script = _Script([
        _Page(server: [_m('a')]),
        _Page(cached: const [], server: [_m('abc1')]),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      bloc.add(const LoadGroupMembers());
      await _settle();
      bloc.add(const SearchGroupMembers('abc'));
      await _afterDebounce();
      expect(_uids(bloc.state), ['abc1']);
      await bloc.close();
    });

    test('reconnect (RefreshGroupMembers, which the connection listener '
        'dispatches) reads the first page once, two-phase, and swaps rows '
        'once, with no loading state', () async {
      final script = _Script([
        _Page(server: [_m('a'), _m('b')]),
        _Page(cached: [_m('stale')], server: [_m('b'), _m('c')]),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      bloc.add(const LoadGroupMembers());
      await _settle();
      final states = <GroupMembersState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const RefreshGroupMembers());
      await _settle();

      expect(script.calls, hasLength(2));
      expect(script.calls.last.listener, isTrue);
      expect(states.whereType<GroupMembersLoading>(), isEmpty);
      expect(
        states.whereType<GroupMembersLoaded>().expand(_uids),
        isNot(contains('stale')),
      );
      expect(_uids(bloc.state), ['b', 'c']);
      await sub.cancel();
      await bloc.close();
    });

    test('an own action offline (kick) ends in the error and leaves the '
        'list as it was', () async {
      final script = _Script([
        _Page(server: [_m('a'), _m('b')]),
      ]);
      final remote = _Remote();
      final bloc = _bloc(_AppBuilder(script), remote: remote);
      bloc.add(const LoadGroupMembers());
      await _settle();
      final countBefore = _group.membersCount;

      bloc.add(KickMember(_m('a')));
      await _settle();

      expect(remote.kicks, 1);
      final state = bloc.state as GroupMembersError;
      expect([for (final m in state.previousMembers!) m.uid], ['a', 'b']);
      expect(_group.membersCount, countBefore);
      await bloc.close();
    });
  });

  group('offline off', () {
    setUp(() => CometChat.debugSetOfflineEnabledOverride(false));

    test('each page is one legacy fetch, no listener, as today', () async {
      final script = _Script([
        _Page(cached: [_m('x')], server: [_m('a'), _m('b')]),
        _Page(server: [_m('c')]),
      ]);
      final bloc = _bloc(_AppBuilder(script)..limit = 2);
      final states = <GroupMembersState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const LoadGroupMembers());
      await _settle();
      bloc.add(const LoadMoreGroupMembers());
      await _settle();

      expect(script.calls, hasLength(2));
      expect(script.calls.every((c) => !c.listener && c.onSuccess), isTrue);
      expect(_uids(bloc.state), ['a', 'b', 'c']);
      expect(
        states.whereType<GroupMembersLoaded>().expand(_uids),
        isNot(contains('x')),
      );
      await sub.cancel();
      await bloc.close();
    });

    test('a keyword search that fails keeps the list, as today', () async {
      final script = _Script([
        _Page(server: [_m('a')]),
        const _Page(error: true),
      ]);
      final bloc = _bloc(_AppBuilder(script));
      bloc.add(const LoadGroupMembers());
      await _settle();
      bloc.add(const SearchGroupMembers('abc'));
      await _afterDebounce();
      expect(_uids(bloc.state), ['a']);
      await bloc.close();
    });
  });

  // ENG-41552: the D84 list rules and stale search (F).
  group('ENG-41552', () {
    final listeners = <String, ConnectionListener>{};

    setUp(() {
      listeners.clear();
      ChatSdkListeners.debugAddConnectionListener = (id, l) =>
          listeners[id] = l;
      ChatSdkListeners.debugRemoveConnectionListener = listeners.remove;
    });

    tearDown(() {
      ChatSdkListeners.debugReset();
      OfflinePresence.debugReset();
    });

    /// A bloc with its SDK listeners on, so the connection listener is live.
    GroupMembersBloc listening(_AppBuilder builder) {
      final repo = GroupMembersRepositoryImpl(remoteDataSource: _Remote());
      return GroupMembersBloc(
        group: _group,
        getGroupMembersUseCase: GetGroupMembersUseCase(repo),
        loadMoreGroupMembersUseCase: LoadMoreGroupMembersUseCase(repo),
        kickGroupMemberUseCase: KickGroupMemberUseCase(repo),
        banGroupMemberUseCase: BanGroupMemberUseCase(repo),
        updateMemberScopeUseCase: UpdateMemberScopeUseCase(repo),
        getLoggedInUserUseCase: gm.GetLoggedInUserUseCase(repo),
        repository: repo,
        groupMembersRequestBuilder: builder,
      );
    }

    test('D84 (2): offline on, cached rows and a not-connected error keep '
        'the rows, show no error and do not reach onError', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final script = _Script([
        _Page(cached: [_m('a')], error: true, errorCode: 'ERR_CONNECTION'),
      ]);
      final bloc = listening(_AppBuilder(script));
      final errors = <CometChatException>[];
      OfflineListErrors.listen(bloc, errors.add);
      final states = <GroupMembersState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const LoadGroupMembers());
      await _settle();

      expect(_uids(bloc.state), ['a']);
      expect(states.whereType<GroupMembersError>(), isEmpty);
      expect(errors, isEmpty);
      await sub.cancel();
      await bloc.close();
    });

    test('D84 (5): offline on, cached rows and a real server error on an '
        'open keep the rows and reach onError once', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final script = _Script([
        _Page(
          cached: [_m('a')],
          error: true,
          errorCode: 'ERR_TOO_MANY_REQUESTS',
        ),
      ]);
      final bloc = listening(_AppBuilder(script));
      final errors = <CometChatException>[];
      OfflineListErrors.listen(bloc, errors.add);
      bloc.add(const LoadGroupMembers());
      await _settle();

      expect(_uids(bloc.state), ['a']);
      expect(errors.single.code, 'ERR_TOO_MANY_REQUESTS');
      await bloc.close();
    });

    test('D-349: with offline on a connection error (a lost network) hides '
        'presence; the reconnect restores it; with offline off it never '
        'hides', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final script = _Script([
        _Page(server: [_m('a')]),
        _Page(server: [_m('a')]),
      ]);
      final bloc = listening(_AppBuilder(script));
      bloc.add(const LoadGroupMembers());
      await _settle();
      final listener = listeners.values.single;

      listener.onConnectionError(
        CometChatException('ERROR_CONNECTION_FAILED', 'WebSocket error', ''),
      );
      expect(OfflinePresence.hidden, isTrue);
      listener.onConnected();
      expect(OfflinePresence.hidden, isFalse);
      await _settle();

      CometChat.debugSetOfflineEnabledOverride(false);
      listener.onConnectionError(
        CometChatException('ERROR_CONNECTION_FAILED', 'WebSocket error', ''),
      );
      expect(OfflinePresence.hidden, isFalse);
      await bloc.close();
    });

    test('D84 (10): with offline on a disconnect hides presence until the '
        'reconnect; with offline off it never does', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final script = _Script([
        _Page(server: [_m('a')]),
        _Page(server: [_m('a')]),
      ]);
      final bloc = listening(_AppBuilder(script));
      bloc.add(const LoadGroupMembers());
      await _settle();
      final listener = listeners.values.single;

      listener.onDisconnected();
      expect(OfflinePresence.hidden, isTrue);
      listener.onConnected();
      expect(OfflinePresence.hidden, isFalse);
      await _settle();

      CometChat.debugSetOfflineEnabledOverride(false);
      listener.onDisconnected();
      expect(OfflinePresence.hidden, isFalse);
      await bloc.close();
    });

    test('D84 (3), (8): offline on, nothing cached and a not-connected error '
        'shows "Connect to load members"; a reconnect loads once and '
        'replaces it', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final script = _Script([
        const _Page(cached: [], error: true, errorCode: 'ERR_CONNECTION'),
        _Page(server: [_m('a')]),
      ]);
      final bloc = listening(_AppBuilder(script));
      final errors = <CometChatException>[];
      OfflineListErrors.listen(bloc, errors.add);
      bloc.add(const LoadGroupMembers());
      await _settle();
      expect(bloc.state, isA<GroupMembersConnectToLoad>());
      expect(errors, isEmpty, reason: 'the offline state itself fires onError');

      listeners.values.single.onConnected();
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
        _Page(server: [_m('a')], hold: hold),
      ]);
      final bloc = listening(_AppBuilder(script));
      bloc.add(const LoadGroupMembers());
      await _settle();
      expect(bloc.state, isA<GroupMembersConnectToLoad>());
      listeners.values.single.onConnected();
      await _settle();
      listeners.values.single.onConnected();
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
        _Page(server: [_m('a')]),
        const _Page(cached: [], error: true, errorCode: 'ERR_CONNECTION'),
        _Page(server: [_m('abc1')]),
      ]);
      final bloc = listening(_AppBuilder(script));
      bloc.add(const LoadGroupMembers());
      await _settle();
      bloc.add(const SearchGroupMembers('abc'));
      await _afterDebounce();
      expect(bloc.state, isA<GroupMembersConnectToSearch>());

      listeners.values.single.onConnected();
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
        bloc.add(const LoadGroupMembers());
        await _settle();
        expect(bloc.state, isA<GroupMembersEmpty>());
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
      final bloc = listening(_AppBuilder(script));
      bloc.add(const LoadGroupMembers());
      await _settle();
      expect(bloc.state, isA<GroupMembersError>());
      listeners.values.single.onConnected();
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
        final bloc = listening(_AppBuilder(script));
        bloc.add(const LoadGroupMembers());
        await _settle();
        expect(bloc.state, isA<GroupMembersError>());
        listeners.values.single.onConnected();
        await _settle();
        expect(script.calls, hasLength(1));
        await bloc.close();
      },
    );

    test('review: ERR_NETWORK over cached rows on a user-started load keeps '
        'the rows and reaches onError once', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final script = _Script([
        _Page(cached: [_m('a')], error: true, errorCode: 'ERR_NETWORK'),
      ]);
      final bloc = listening(_AppBuilder(script));
      final errors = <CometChatException>[];
      OfflineListErrors.listen(bloc, errors.add);
      bloc.add(const LoadGroupMembers());
      await _settle();
      expect(_uids(bloc.state), ['a']);
      expect(errors.single.code, 'ERR_NETWORK');
      await bloc.close();
    });

    test('review: ERR_CONNECTION stays not-connected: no onError over cached '
        'rows, and the offline state with nothing shown', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      final script = _Script([
        _Page(cached: [_m('a')], error: true, errorCode: 'ERR_CONNECTION'),
        const _Page(cached: [], error: true, errorCode: 'ERR_CONNECTION'),
      ]);
      final errors = <CometChatException>[];
      final kept = listening(_AppBuilder(script));
      OfflineListErrors.listen(kept, errors.add);
      kept.add(const LoadGroupMembers());
      await _settle();
      expect(_uids(kept.state), ['a']);
      expect(errors, isEmpty);
      await kept.close();

      final empty = listening(_AppBuilder(script));
      OfflineListErrors.listen(empty, errors.add);
      empty.add(const LoadGroupMembers());
      await _settle();
      expect(empty.state, isA<GroupMembersConnectToLoad>());
      expect(errors, isEmpty);
      await empty.close();
    });

    test('D84 (11): offline off, a connection error shows today\'s error and '
        'a reconnect does not reload it', () async {
      CometChat.debugSetOfflineEnabledOverride(false);
      final script = _Script([
        const _Page(error: true, errorCode: 'ERR_CONNECTION'),
      ]);
      final bloc = listening(_AppBuilder(script));
      bloc.add(const LoadGroupMembers());
      await _settle();
      expect(bloc.state, isA<GroupMembersError>());
      listeners.values.single.onConnected();
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
          _Page(server: [_m('a')]),
          _Page(server: [_m('old')], hold: hold),
          _Page(server: [_m('new')]),
        ]);
        final bloc = _bloc(_AppBuilder(script));
        bloc.add(const LoadGroupMembers());
        await _settle();

        bloc.add(const SearchGroupMembers('ol'));
        await _afterDebounce();
        bloc.add(const SearchGroupMembers('ne'));
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
