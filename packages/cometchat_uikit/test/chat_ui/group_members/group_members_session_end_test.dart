/// Group members list on session end and cache reset (G8, ENG-41569).
///
/// The kit's real chain — bloc, use case, repository, data source — runs
/// against an app builder whose `build()` hands back a scripted request. The
/// hub is driven the way a logout produces it: offline on during the session,
/// the SDK then reports offline off, and only then do the logout signals come.
///
///   flutter test test/chat_ui/group_members/group_members_session_end_test.dart
library;

import 'dart:async';

// Aliased: the barrel re-exports two different `GetLoggedInUserUseCase`
// classes (group_members' and groups'), so this one has to be named.
import 'package:cometchat_chat_uikit/chat_ui/src/group_members/domain/usecases/get_logged_in_user_usecase.dart'
    as gm;
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_list_errors.dart';
import 'package:flutter_test/flutter_test.dart';

GroupMember _u(String uid) =>
    GroupMember(uid: uid, name: 'Member $uid', scope: 'participant');

/// One page's answer: an optional cached phase, then a server page or error.
class _Page {
  const _Page({this.cached, this.server, this.errorCode, this.hold});
  final List<GroupMember>? cached;
  final List<GroupMember>? server;
  final String? errorCode;
  final Completer<void>? hold;
}

class _Script {
  _Script(this.pages);
  final List<_Page> pages;
  int calls = 0;
  int builds = 0;
}

class _ScriptedRequest extends Fake implements GroupMembersRequest {
  _ScriptedRequest(this.script);
  final _Script script;

  @override
  Future<List<GroupMember>> fetchNext({
    required Function(List<GroupMember> groupMemberList)? onSuccess,
    required Function(CometChatException excep)? onError,
    GroupMemberFetchListener? listener,
  }) async {
    script.calls++;
    final page = script.pages.removeAt(0);
    if (page.hold != null) await page.hold!.future;
    await Future<void>.delayed(Duration.zero);
    if (page.cached != null) listener?.onCachedGroupMembers(page.cached!);
    await Future<void>.delayed(Duration.zero);
    if (page.errorCode != null) {
      final e = CometChatException(page.errorCode!, 'failed', 'failed');
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
  GroupMembersRequest build() {
    script.builds++;
    return _ScriptedRequest(script);
  }
}

class _Remote extends GroupMembersRemoteDataSourceImpl {
  @override
  Future<User?> getLoggedInUser() async => null;

  @override
  Future<Conversation?> getConversation(String guid) async => null;
}

final _group = Group(guid: 'g1', name: 'Dev Team', type: 'public');

GroupMembersBloc _bloc(_Script script) {
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
    disableSDKListeners: true,
    // One row per page, so a page of one leaves paging open.
    groupMembersRequestBuilder: _AppBuilder(script)..limit = 1,
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

final _hub = OfflineHub.instance;

/// Logs out the way the SDK does: offline reads false first, then the kit and
/// SDK logout signals arrive.
void _logout() {
  CometChat.debugSetOfflineEnabledOverride(false);
  _hub.onKitLogout();
  _hub.debugLogout();
}

void _cacheReset() =>
    _hub.debugCacheReset(OfflineCacheResetReason.encryptionChanged, 0);

void main() {
  setUp(() {
    _hub.debugReset();
    CometChat.debugSetOfflineEnabledOverride(true);
    _hub.debugLoginSuccess('alice'); // offline on during this session
  });

  tearDown(() => CometChat.debugSetOfflineEnabledOverride(null));

  test('sessionEnded clears rows and resets paging', () async {
    final script = _Script([
      _Page(server: [_u('a'), _u('b')]),
      _Page(server: [_u('c')]),
    ]);
    final bloc = _bloc(script);
    addTearDown(bloc.close);
    bloc.add(const LoadGroupMembers());
    await _settle();
    expect(_uids(bloc.state), ['a', 'b']);

    _logout();
    await _settle();

    expect(bloc.state, isA<GroupMembersEmpty>());
    expect(bloc.items, isEmpty);
    // Paging is closed: nothing is read past the cleared page.
    bloc.add(const LoadMoreGroupMembers());
    await _settle();
    expect(script.calls, 1);

    // The next load reads page one from a fresh request.
    bloc.add(const LoadGroupMembers());
    await _settle();
    expect(script.builds, 2);
    expect(_uids(bloc.state), ['c']);
  });

  test('sessionEnded drops the result of a read in flight', () async {
    final hold = Completer<void>();
    final script = _Script([
      _Page(server: [_u('a')]),
      _Page(server: [_u('b')], hold: hold),
    ]);
    final bloc = _bloc(script);
    addTearDown(bloc.close);
    bloc.add(const LoadGroupMembers());
    await _settle();
    bloc.add(const RefreshGroupMembers());
    await _settle();
    expect(script.calls, 2); // the refresh is waiting on the server

    _logout();
    await _settle();
    hold.complete();
    await _settle();

    expect(bloc.state, isA<GroupMembersEmpty>());
    expect(bloc.items, isEmpty);
  });

  test('sessionEnded drops a load-more in flight', () async {
    final hold = Completer<void>();
    final script = _Script([
      _Page(server: [_u('a')]),
      _Page(cached: [_u('b')], server: [_u('c')], hold: hold),
    ]);
    final bloc = _bloc(script);
    addTearDown(bloc.close);
    bloc.add(const LoadGroupMembers());
    await _settle();
    bloc.add(const LoadMoreGroupMembers());
    await _settle();

    _logout();
    await _settle();
    hold.complete();
    await _settle();

    expect(bloc.state, isA<GroupMembersEmpty>());
    expect(bloc.items, isEmpty);
  });

  test('stale event is ignored', () async {
    final script = _Script([
      _Page(server: [_u('a')]),
      _Page(server: [_u('b')]),
    ]);
    final bloc = _bloc(script);
    addTearDown(bloc.close);
    bloc.add(const LoadGroupMembers());
    await _settle();

    // The cache reset is published, then the session ends before it is
    // delivered: it belongs to the old session, so it must not reload.
    _cacheReset();
    _logout();
    await _settle();

    expect(script.calls, 1);
    expect(bloc.state, isA<GroupMembersEmpty>());
  });

  test('cacheReset clears then reloads once', () async {
    final script = _Script([
      _Page(server: [_u('a'), _u('b')]),
      _Page(server: [_u('c')]),
    ]);
    final bloc = _bloc(script);
    addTearDown(bloc.close);
    bloc.add(const LoadGroupMembers());
    await _settle();
    final states = <GroupMembersState>[];
    final sub = bloc.stream.listen(states.add);
    addTearDown(sub.cancel);

    _cacheReset();
    await _settle();

    expect(states.first, isA<GroupMembersEmpty>());
    expect(script.calls, 2);
    expect(script.builds, 2);
    expect(_uids(bloc.state), ['c']);
  });

  test('cacheReset reload failure over rows is quiet', () async {
    final script = _Script([
      _Page(server: [_u('a')]),
      _Page(cached: [_u('b')], errorCode: 'ERR_INTERNAL_SERVER'),
    ]);
    final bloc = _bloc(script);
    addTearDown(bloc.close);
    final errors = <CometChatException>[];
    void sink(CometChatException e) => errors.add(e);
    OfflineListErrors.listen(bloc, sink);
    addTearDown(() => OfflineListErrors.cancel(bloc, sink));
    bloc.add(const LoadGroupMembers());
    await _settle();

    _cacheReset();
    await _settle();

    expect(_uids(bloc.state), ['b']);
    expect(errors, isEmpty);
  });

  test('offline off: no change', () async {
    _hub.debugReset();
    CometChat.debugSetOfflineEnabledOverride(false);
    _hub.debugLoginSuccess('alice');
    final script = _Script([
      _Page(server: [_u('a')]),
    ]);
    final bloc = _bloc(script);
    addTearDown(bloc.close);
    bloc.add(const LoadGroupMembers());
    await _settle();

    _cacheReset();
    _hub.onKitLogout();
    _hub.debugLogout();
    await _settle();

    expect(_uids(bloc.state), ['a']);
    expect(script.calls, 1);
  });

  test('close cancels the hub subscription', () async {
    final bloc = _bloc(_Script([]));
    expect(_hub.debugHasListeners, isTrue);
    await bloc.close();
    expect(_hub.debugHasListeners, isFalse);
  });
}
