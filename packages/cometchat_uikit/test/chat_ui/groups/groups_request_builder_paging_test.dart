/// CometChatGroups.groupsRequestBuilder keeps its limit and its search
/// keyword — ENG-38688.
///
/// The data source used to build the first request by writing into the app's
/// own builder: the bloc's hard-coded limit of 30 replaced the app's, and the
/// search box's keyword stayed on the builder after the search was cleared, so
/// every later load was still filtered by it. Paging then stopped early (a
/// page shorter than 30 read as the last), and after a cleared search the next
/// page came from a default builder, deduped to nothing, and ended the list.
///
/// These run the kit's real chain — bloc, use cases, repository, data source —
/// against an app builder whose `build()` hands back a request served from an
/// in-memory list, so every request the SDK would have been sent is recorded.
///
///   flutter test test/chat_ui/groups/groups_request_builder_paging_test.dart
library;

import 'package:cometchat_chat_uikit/chat_ui/src/groups/bloc/groups_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/bloc/groups_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/bloc/groups_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/data/datasources/groups_remote_datasource.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/data/repositories/groups_repository_impl.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/domain/usecases/get_groups_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/domain/usecases/load_more_groups_usecase.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import 'package:flutter_test/flutter_test.dart';

// ─── Fakes ───────────────────────────────────────────────────────────────────

class _FakeGroup extends Fake implements Group {
  _FakeGroup(this.guid, this.name);

  @override
  final String guid;
  @override
  final String name;
}

/// What a request was built with, and which of its pages was fetched.
typedef _Sent = ({int? limit, String? keyword, bool? joinedOnly, int page});

/// Serves pages of [groups], filtered by keyword, to every request built from
/// an [_AppBuilder], and records each fetch.
class _Server {
  _Server(this.groups);

  final List<Group> groups;
  final sent = <_Sent>[];

  List<Group> serve(GroupsRequestBuilder built, int page) {
    final limit = built.limit ?? 30;
    final keyword = built.searchKeyword?.toLowerCase();
    sent.add((
      limit: built.limit,
      keyword: built.searchKeyword,
      joinedOnly: built.joinedOnly,
      page: page,
    ));
    final matching = [
      for (final g in groups)
        if (keyword == null || g.name.toLowerCase().contains(keyword)) g,
    ];
    return matching.skip(page * limit).take(limit).toList();
  }
}

/// An app's builder. `build()` snapshots the fields as they are at that
/// moment, exactly as the SDK's GroupsRequest copies them into finals.
class _AppBuilder extends GroupsRequestBuilder {
  _AppBuilder(this.server);

  final _Server server;
  bool failBuild = false;

  @override
  GroupsRequest build() {
    if (failBuild) throw StateError('build failed');
    final snapshot = GroupsRequestBuilder()
      ..limit = limit
      ..searchKeyword = searchKeyword
      ..joinedOnly = joinedOnly;
    return _ServedRequest(server, snapshot);
  }
}

class _ServedRequest extends Fake implements GroupsRequest {
  _ServedRequest(this.server, this.built);

  final _Server server;
  final GroupsRequestBuilder built;
  int _page = 0;

  @override
  Future<List<Group>> fetchNext({
    required Function(List<Group> groupList)? onSuccess,
    required Function(CometChatException excep)? onError,
  }) async {
    final page = server.serve(built, _page++);
    onSuccess?.call(page);
    return page;
  }
}

/// The kit's data source, minus the one SDK call the bloc makes on start-up.
class _Remote extends GroupsRemoteDataSourceImpl {
  @override
  Future<User?> getLoggedInUser() async => null;
}

// ─── Fixtures ────────────────────────────────────────────────────────────────

/// 23 groups; three of them match "abc".
List<Group> _catalogue() => [
  for (var i = 0; i < 20; i++) _FakeGroup('g$i', 'Group $i'),
  for (var i = 0; i < 3; i++) _FakeGroup('abc$i', 'abc team $i'),
];

GroupsBloc _blocWith(GroupsRequestBuilder builder) {
  final repo = GroupsRepositoryImpl(remoteDataSource: _Remote());
  return GroupsBloc(
    getGroupsUseCase: GetGroupsUseCase(repo),
    loadMoreGroupsUseCase: LoadMoreGroupsUseCase(repo),
    getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
    disableSDKListeners: true,
    groupsRequestBuilder: builder,
  );
}

List<String> _guids(GroupsBloc bloc) => [
  for (final g in (bloc.state as GroupsLoaded).groups) g.guid,
];

bool _hasMore(GroupsBloc bloc) => (bloc.state as GroupsLoaded).hasMore;

/// Lets a search's 300 ms debounce elapse and its fetch land.
Future<void> _afterDebounce() async {
  await Future<void>.delayed(const Duration(milliseconds: 350));
  await pumpEventQueue();
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('GroupsRemoteDataSourceImpl with an app builder', () {
    test("builds with the app's limit and leaves the builder as the app set "
        'it', () async {
      final server = _Server(_catalogue());
      final builder = _AppBuilder(server)..limit = 10;

      final page = await GroupsRemoteDataSourceImpl().getGroups(
        limit: 30,
        groupsRequestBuilder: builder,
      );

      expect(page, hasLength(10));
      expect(server.sent.single.limit, 10);
      expect(builder.limit, 10);
    });

    test("uses the caller's limit when the app set none, and does not keep "
        'it', () async {
      final server = _Server(_catalogue());
      final builder = _AppBuilder(server);

      await GroupsRemoteDataSourceImpl().getGroups(
        limit: 25,
        groupsRequestBuilder: builder,
      );

      expect(server.sent.single.limit, 25);
      expect(builder.limit, isNull);
    });

    test("a search keyword applies to that request only; the app's own "
        'comes back', () async {
      final server = _Server(_catalogue());
      final builder = _AppBuilder(server)..searchKeyword = 'Group';
      final source = GroupsRemoteDataSourceImpl();

      await source.getGroups(
        searchKeyword: 'abc',
        groupsRequestBuilder: builder,
      );
      expect(server.sent.last.keyword, 'abc');
      expect(builder.searchKeyword, 'Group');

      source.resetRequest();
      await source.getGroups(groupsRequestBuilder: builder);
      expect(server.sent.last.keyword, 'Group');

      source.resetRequest();
      await source.getGroups(searchKeyword: '', groupsRequestBuilder: builder);
      expect(server.sent.last.keyword, 'Group');
    });

    test('joinedOnly applies to that request only', () async {
      final server = _Server(_catalogue());
      final builder = _AppBuilder(server);
      final source = GroupsRemoteDataSourceImpl();

      await source.getGroups(joinedOnly: true, groupsRequestBuilder: builder);
      expect(server.sent.last.joinedOnly, isTrue);
      expect(builder.joinedOnly, isNull);

      builder.joinedOnly = true;
      source.resetRequest();
      await source.getGroups(joinedOnly: false, groupsRequestBuilder: builder);
      expect(server.sent.last.joinedOnly, isFalse);
      expect(builder.joinedOnly, isTrue);
    });

    test('the builder is restored even when building fails', () async {
      final builder = _AppBuilder(_Server(const []))
        ..searchKeyword = 'Group'
        ..failBuild = true;

      await expectLater(
        GroupsRemoteDataSourceImpl().getGroups(
          searchKeyword: 'abc',
          joinedOnly: true,
          groupsRequestBuilder: builder,
        ),
        throwsA(isA<GroupsRemoteDataSourceException>()),
      );
      expect(builder.searchKeyword, 'Group');
      expect(builder.joinedOnly, isNull);
      expect(builder.limit, isNull);
    });
  });

  group('GroupsBloc with an app builder', () {
    test('pages by the builder limit past the first page, and stops on the '
        'empty page', () async {
      final server = _Server(_catalogue());
      final bloc = _blocWith(_AppBuilder(server)..limit = 10);
      addTearDown(bloc.close);

      bloc.add(const LoadGroups());
      await pumpEventQueue();
      expect(_guids(bloc), hasLength(10));
      expect(_hasMore(bloc), isTrue);

      bloc.add(const LoadMoreGroups());
      await pumpEventQueue();
      expect(_guids(bloc), hasLength(20));

      // A short page is not taken as the end: groups' load-more drops rows
      // the list already holds, so a short page proves nothing.
      bloc.add(const LoadMoreGroups());
      await pumpEventQueue();
      expect(_guids(bloc), hasLength(23));
      expect(_hasMore(bloc), isTrue);

      bloc.add(const LoadMoreGroups());
      await pumpEventQueue();
      expect(_guids(bloc), hasLength(23));
      expect(_hasMore(bloc), isFalse);

      expect([for (final s in server.sent) s.limit], [10, 10, 10, 10]);
      expect([for (final s in server.sent) s.page], [0, 1, 2, 3]);
      expect(_guids(bloc).toSet(), hasLength(23));
    });

    test('a cleared search reloads from the app builder, with its own '
        'keyword, and paging carries on', () async {
      final server = _Server(_catalogue());
      final builder = _AppBuilder(server)..limit = 10;
      final bloc = _blocWith(builder);
      addTearDown(bloc.close);

      bloc.add(const LoadGroups());
      await pumpEventQueue();
      bloc.add(const LoadMoreGroups());
      await pumpEventQueue();
      expect(_guids(bloc), hasLength(20));

      bloc.add(const SearchGroups('abc'));
      await _afterDebounce();
      expect(_guids(bloc), ['abc0', 'abc1', 'abc2']);
      expect(builder.searchKeyword, isNull);

      // The search runs out of pages, so hasMore goes false.
      bloc.add(const LoadMoreGroups());
      await pumpEventQueue();
      expect(_hasMore(bloc), isFalse);

      bloc.add(const SearchGroups(''));
      await pumpEventQueue();
      expect(builder.searchKeyword, isNull);
      expect(server.sent.last.keyword, isNull);
      expect(server.sent.last.page, 0);
      expect(_guids(bloc), hasLength(10));
      expect(_hasMore(bloc), isTrue);

      bloc.add(const LoadMoreGroups());
      await pumpEventQueue();
      expect(server.sent.last.keyword, isNull);
      expect(server.sent.last.page, 1);
      expect(_guids(bloc), hasLength(20));
      expect(_guids(bloc).toSet(), hasLength(20));

      expect(
        [for (final s in server.sent) s.keyword],
        [null, null, 'abc', 'abc', null, null],
      );
      expect([for (final s in server.sent) s.limit], everyElement(10));
    });

    test(
      "a cleared search brings back the app builder's own keyword",
      () async {
        final server = _Server(_catalogue());
        final builder = _AppBuilder(server)
          ..limit = 10
          ..searchKeyword = 'team';
        final bloc = _blocWith(builder);
        addTearDown(bloc.close);

        bloc.add(const LoadGroups());
        await pumpEventQueue();
        expect(_guids(bloc), ['abc0', 'abc1', 'abc2']);

        bloc.add(const SearchGroups('Group 1'));
        await _afterDebounce();
        expect(server.sent.last.keyword, 'Group 1');
        expect(builder.searchKeyword, 'team');

        bloc.add(const SearchGroups(''));
        await pumpEventQueue();
        expect(server.sent.last.keyword, 'team');
        expect(_guids(bloc), ['abc0', 'abc1', 'abc2']);
      },
    );
  });
}
