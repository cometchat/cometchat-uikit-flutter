/// CometChatUsers.usersRequestBuilder keeps its limit and its search keyword —
/// ENG-38688.
///
/// Shipped in 6.1.1: the data source built the first request by writing into
/// the app's own builder, so the bloc's hard-coded limit of 30 replaced the
/// app's and the search box's keyword stayed on the builder once the search
/// was cleared. Paging with a smaller limit stopped after the first page, and
/// the first load-more after a cleared search re-fetched page one — still
/// filtered by the stale keyword — and appended it.
///
/// These run the kit's real chain — bloc, use case, repository, data source —
/// against an app builder whose `build()` hands back a request served from an
/// in-memory list, so every request the SDK would have been sent is recorded.
///
///   flutter test test/chat_ui/users/users_request_builder_paging_test.dart
library;

import 'package:cometchat_chat_uikit/chat_ui/src/users/bloc/users_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/bloc/users_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/bloc/users_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/data/datasources/users_local_datasource.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/data/datasources/users_remote_datasource.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/data/repositories/users_repository_impl.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/domain/usecases/get_users_usecase.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import 'package:flutter_test/flutter_test.dart';

// ─── Fakes ───────────────────────────────────────────────────────────────────

class _FakeUser extends Fake implements User {
  _FakeUser(this.uid, this.name);

  @override
  final String uid;
  @override
  final String name;
  @override
  String? get status => 'offline';
}

/// What a request was built with, and which of its pages was fetched.
typedef _Sent = ({int limit, String? keyword, int page});

/// Serves pages of [users], filtered by keyword, to every request built from
/// a [_AppBuilder], and records each fetch.
class _Server {
  _Server(this.users);

  final List<User> users;
  final sent = <_Sent>[];

  List<User> serve(UsersRequestBuilder built, int page) {
    final keyword = built.searchKeyword?.toLowerCase();
    sent.add((limit: built.limit, keyword: built.searchKeyword, page: page));
    final matching = [
      for (final u in users)
        if (keyword == null || u.name.toLowerCase().contains(keyword)) u,
    ];
    return matching.skip(page * built.limit).take(built.limit).toList();
  }
}

/// An app's builder. `build()` snapshots the fields as they are at that
/// moment, exactly as the SDK's UsersRequest copies them into finals.
class _AppBuilder extends UsersRequestBuilder {
  _AppBuilder(this.server);

  final _Server server;
  bool failBuild = false;

  @override
  UsersRequest build() {
    if (failBuild) throw StateError('build failed');
    final snapshot = UsersRequestBuilder()
      ..limit = limit
      ..searchKeyword = searchKeyword;
    return _ServedRequest(server, snapshot);
  }
}

class _ServedRequest extends Fake implements UsersRequest {
  _ServedRequest(this.server, this.built);

  final _Server server;
  final UsersRequestBuilder built;
  int _page = 0;

  @override
  Future<List<User>> fetchNext({
    required Function(List<User> userList)? onSuccess,
    required Function(CometChatException excep)? onError,
  }) async {
    final page = server.serve(built, _page++);
    onSuccess?.call(page);
    return page;
  }
}

/// The kit's repository, minus the SDK call for the logged-in user.
class _Repository extends UsersRepositoryImpl {
  _Repository()
    : super(
        remoteDataSource: UsersRemoteDataSourceImpl(),
        localDataSource: UsersLocalDataSourceImpl(),
      );

  @override
  Future<Result<User?>> getLoggedInUser() async => const Success(null);
}

// ─── Fixtures ────────────────────────────────────────────────────────────────

/// 23 users; three of them match "abc".
List<User> _directory() => [
  for (var i = 0; i < 20; i++) _FakeUser('u$i', 'User $i'),
  for (var i = 0; i < 3; i++) _FakeUser('abc$i', 'abc person $i'),
];

UsersBloc _blocWith(UsersRequestBuilder builder) {
  final repo = _Repository();
  return UsersBloc(
    getUsersUseCase: GetUsersUseCase(repo),
    getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
    disableSDKListeners: true,
    usersRequestBuilder: builder,
  );
}

List<String> _uids(UsersBloc bloc) => [
  for (final u in (bloc.state as UsersLoaded).users) u.uid,
];

bool _hasMore(UsersBloc bloc) => (bloc.state as UsersLoaded).hasMore;

/// Lets a search's 300 ms debounce elapse and its fetch land.
Future<void> _afterDebounce() async {
  await Future<void>.delayed(const Duration(milliseconds: 350));
  await pumpEventQueue();
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('UsersRemoteDataSourceImpl with an app builder', () {
    test("builds with the app's limit, not the caller's, and leaves the "
        'builder as the app set it', () async {
      final server = _Server(_directory());
      final builder = _AppBuilder(server)..limit = 10;

      final page = await UsersRemoteDataSourceImpl().getUsers(
        limit: 30,
        usersRequestBuilder: builder,
      );

      expect(page, hasLength(10));
      expect(server.sent.single.limit, 10);
      expect(builder.limit, 10);
    });

    test("a search keyword applies to that request only; the app's own "
        'comes back', () async {
      final server = _Server(_directory());
      final builder = _AppBuilder(server)..searchKeyword = 'User';
      final source = UsersRemoteDataSourceImpl();

      await source.getUsers(searchKeyword: 'abc', usersRequestBuilder: builder);
      expect(server.sent.last.keyword, 'abc');
      expect(builder.searchKeyword, 'User');

      source.resetRequest();
      await source.getUsers(usersRequestBuilder: builder);
      expect(server.sent.last.keyword, 'User');
    });

    test('the builder is restored even when building fails', () async {
      final builder = _AppBuilder(_Server(const []))
        ..limit = 10
        ..failBuild = true;

      await expectLater(
        UsersRemoteDataSourceImpl().getUsers(
          searchKeyword: 'abc',
          usersRequestBuilder: builder,
        ),
        throwsA(isA<UsersRemoteDataSourceException>()),
      );
      expect(builder.searchKeyword, isNull);
      expect(builder.limit, 10);
    });
  });

  group('UsersBloc with an app builder', () {
    test('pages by the builder limit past the first page, and stops on the '
        'empty page', () async {
      final server = _Server(_directory());
      final bloc = _blocWith(_AppBuilder(server)..limit = 10);
      addTearDown(bloc.close);

      bloc.add(const LoadUsers());
      await pumpEventQueue();
      expect(_uids(bloc), hasLength(10));

      bloc.add(const LoadMoreUsers());
      await pumpEventQueue();
      expect(_uids(bloc), hasLength(20));
      expect(_hasMore(bloc), isTrue);

      bloc.add(const LoadMoreUsers());
      await pumpEventQueue();
      expect(_uids(bloc), hasLength(23));
      expect(_hasMore(bloc), isTrue);

      bloc.add(const LoadMoreUsers());
      await pumpEventQueue();
      expect(_uids(bloc), hasLength(23));
      expect(_hasMore(bloc), isFalse);

      expect([for (final s in server.sent) s.limit], [10, 10, 10, 10]);
      expect([for (final s in server.sent) s.page], [0, 1, 2, 3]);
    });

    test('a cleared search reloads from the app builder without the stale '
        'keyword, and paging carries on without duplicates', () async {
      final server = _Server(_directory());
      final builder = _AppBuilder(server)..limit = 10;
      final bloc = _blocWith(builder);
      addTearDown(bloc.close);

      bloc.add(const LoadUsers());
      await pumpEventQueue();
      bloc.add(const LoadMoreUsers());
      await pumpEventQueue();
      expect(_uids(bloc), hasLength(20));

      bloc.add(const SearchUsers('abc'));
      await _afterDebounce();
      expect(_uids(bloc), ['abc0', 'abc1', 'abc2']);
      expect(builder.searchKeyword, isNull);

      bloc.add(const LoadMoreUsers());
      await pumpEventQueue();
      expect(_hasMore(bloc), isFalse);

      bloc.add(const SearchUsers(''));
      await pumpEventQueue();
      expect(builder.searchKeyword, isNull);
      expect(server.sent.last.keyword, isNull);
      expect(server.sent.last.page, 0);
      expect(_uids(bloc), hasLength(10));
      expect(_hasMore(bloc), isTrue);

      bloc.add(const LoadMoreUsers());
      await pumpEventQueue();
      expect(server.sent.last.keyword, isNull);
      expect(server.sent.last.page, 1);
      expect(_uids(bloc), hasLength(20));
      expect(_uids(bloc).toSet(), hasLength(20));

      expect(
        [for (final s in server.sent) s.keyword],
        [null, null, 'abc', 'abc', null, null],
      );
      expect([for (final s in server.sent) s.limit], everyElement(10));
    });
  });
}
