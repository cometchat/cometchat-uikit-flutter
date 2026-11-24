/// Users list on session end and cache reset (G8, ENG-41569).
///
/// The kit's real chain — bloc, use case, repository, data source — runs
/// against an app builder whose `build()` hands back a scripted request. The
/// hub is driven the way a logout produces it: offline on during the session,
/// the SDK then reports offline off, and only then do the logout signals come.
///
///   flutter test test/chat_ui/users/users_session_end_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/chat_ui/src/users/bloc/users_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/bloc/users_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/bloc/users_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/data/datasources/users_local_datasource.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/data/datasources/users_remote_datasource.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/data/repositories/users_repository_impl.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/domain/usecases/get_users_usecase.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_list_errors.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import 'package:flutter_test/flutter_test.dart';

User _u(String uid) => User(uid: uid, name: 'User $uid', status: 'offline');

/// One page's answer: an optional cached phase, then a server page or error.
class _Page {
  const _Page({this.cached, this.server, this.errorCode, this.hold});
  final List<User>? cached;
  final List<User>? server;
  final String? errorCode;
  final Completer<void>? hold;
}

class _Script {
  _Script(this.pages);
  final List<_Page> pages;
  int calls = 0;
  int builds = 0;
}

class _ScriptedRequest extends Fake implements UsersRequest {
  _ScriptedRequest(this.script);
  final _Script script;

  @override
  Future<List<User>> fetchNext({
    UserFetchListener? listener,
    required Function(List<User> userList)? onSuccess,
    required Function(CometChatException excep)? onError,
  }) async {
    script.calls++;
    final page = script.pages.removeAt(0);
    if (page.hold != null) await page.hold!.future;
    await Future<void>.delayed(Duration.zero);
    if (page.cached != null) listener?.onCachedUsers(page.cached!);
    await Future<void>.delayed(Duration.zero);
    if (page.errorCode != null) {
      final e = CometChatException(page.errorCode!, 'failed', 'failed');
      onError?.call(e);
      listener?.onError(e);
      return const [];
    }
    final rows = page.server ?? const <User>[];
    onSuccess?.call(rows);
    listener?.onServerUsers(rows);
    return rows;
  }
}

class _AppBuilder extends UsersRequestBuilder {
  _AppBuilder(this.script);
  final _Script script;

  @override
  UsersRequest build() {
    script.builds++;
    return _ScriptedRequest(script);
  }
}

class _Repository extends UsersRepositoryImpl {
  _Repository()
    : super(
        remoteDataSource: UsersRemoteDataSourceImpl(),
        localDataSource: UsersLocalDataSourceImpl(),
      );

  @override
  Future<Result<User?>> getLoggedInUser() async => const Success(null);
}

UsersBloc _bloc(_Script script) {
  final r = _Repository();
  return UsersBloc(
    getUsersUseCase: GetUsersUseCase(r),
    getLoggedInUserUseCase: GetLoggedInUserUseCase(r),
    disableSDKListeners: true,
    usersRequestBuilder: _AppBuilder(script),
  );
}

List<String> _uids(UsersState s) => [
  for (final u in (s as UsersLoaded).users) u.uid,
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
    bloc.add(const LoadUsers());
    await _settle();
    expect(_uids(bloc.state), ['a', 'b']);

    _logout();
    await _settle();

    expect(bloc.state, isA<UsersEmpty>());
    expect(bloc.items, isEmpty);
    // Paging is closed: nothing is read past the cleared page.
    bloc.add(const LoadMoreUsers());
    await _settle();
    expect(script.calls, 1);

    // The next load reads page one from a fresh request.
    bloc.add(const LoadUsers());
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
    bloc.add(const LoadUsers());
    await _settle();
    bloc.add(const RefreshUsers());
    await _settle();
    expect(script.calls, 2); // the refresh is waiting on the server

    _logout();
    await _settle();
    hold.complete();
    await _settle();

    expect(bloc.state, isA<UsersEmpty>());
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
    bloc.add(const LoadUsers());
    await _settle();
    bloc.add(const LoadMoreUsers());
    await _settle();

    _logout();
    await _settle();
    hold.complete();
    await _settle();

    expect(bloc.state, isA<UsersEmpty>());
    expect(bloc.items, isEmpty);
  });

  test('stale event is ignored', () async {
    final script = _Script([
      _Page(server: [_u('a')]),
      _Page(server: [_u('b')]),
    ]);
    final bloc = _bloc(script);
    addTearDown(bloc.close);
    bloc.add(const LoadUsers());
    await _settle();

    // The cache reset is published, then the session ends before it is
    // delivered: it belongs to the old session, so it must not reload.
    _cacheReset();
    _logout();
    await _settle();

    expect(script.calls, 1);
    expect(bloc.state, isA<UsersEmpty>());
  });

  test('cacheReset clears then reloads once', () async {
    final script = _Script([
      _Page(server: [_u('a'), _u('b')]),
      _Page(server: [_u('c')]),
    ]);
    final bloc = _bloc(script);
    addTearDown(bloc.close);
    bloc.add(const LoadUsers());
    await _settle();
    final states = <UsersState>[];
    final sub = bloc.stream.listen(states.add);
    addTearDown(sub.cancel);

    _cacheReset();
    await _settle();

    expect(states.first, isA<UsersEmpty>());
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
    bloc.add(const LoadUsers());
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
    bloc.add(const LoadUsers());
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
