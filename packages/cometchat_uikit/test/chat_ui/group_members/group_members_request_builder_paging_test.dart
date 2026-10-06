/// CometChatGroupMembers.groupMembersRequestBuilder shapes what the list
/// loads — ENG-38688.
///
/// The prop only reached the legacy controller stub: GroupMembersBloc took no
/// builder and the data source always built a fresh
/// `GroupMembersRequestBuilder(guid)..limit = 30`, so an app's limit, scopes,
/// status and search keyword had no effect. The builder now reaches the data
/// source, which sets the group, a missing limit and the search box's keyword
/// on it only for `build()` and restores them after, as the groups and users
/// data sources do.
///
/// These run the kit's real chain — bloc, use cases, repository, data source —
/// against an app builder whose `build()` hands back a request served from an
/// in-memory list, so every request the SDK would have been sent is recorded.
///
///   flutter test test/chat_ui/group_members/group_members_request_builder_paging_test.dart
library;

import 'dart:async';

// Aliased: the barrel re-exports two different `GetLoggedInUserUseCase`
// classes (group_members' and groups'), so this one has to be named.
import 'package:cometchat_chat_uikit/chat_ui/src/group_members/domain/usecases/get_logged_in_user_usecase.dart'
    as gm;
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Fakes ───────────────────────────────────────────────────────────────────

/// What a request was built with, and which of its pages was fetched.
typedef _Sent = ({
  String guid,
  int? limit,
  String? keyword,
  List<String>? scopes,
  int page,
});

/// Serves pages of [members], filtered by keyword and scope, to every request
/// built from an [_AppBuilder], and records each fetch.
class _Server {
  _Server(this.members);

  final List<GroupMember> members;
  final sent = <_Sent>[];

  List<GroupMember> serve(GroupMembersRequestBuilder built, int page) {
    final limit = built.limit ?? 30;
    final keyword = built.searchKeyword?.toLowerCase();
    final scopes = built.scopes;
    sent.add((
      guid: built.guid,
      limit: built.limit,
      keyword: built.searchKeyword,
      scopes: scopes,
      page: page,
    ));
    final matching = [
      for (final m in members)
        if ((keyword == null || m.name.toLowerCase().contains(keyword)) &&
            (scopes == null || scopes.contains(m.scope)))
          m,
    ];
    return matching.skip(page * limit).take(limit).toList();
  }
}

/// An app's builder. `build()` snapshots the fields as they are at that
/// moment, exactly as the SDK's GroupMembersRequest copies them into finals.
class _AppBuilder extends GroupMembersRequestBuilder {
  _AppBuilder(this.server, super.guid);

  final _Server server;
  bool failBuild = false;

  @override
  GroupMembersRequest build() {
    if (failBuild) throw StateError('build failed');
    final snapshot = GroupMembersRequestBuilder(guid)
      ..limit = limit
      ..searchKeyword = searchKeyword
      ..scopes = scopes
      ..status = status;
    return _ServedRequest(server, snapshot);
  }
}

class _ServedRequest extends Fake implements GroupMembersRequest {
  _ServedRequest(this.server, this.built);

  final _Server server;
  final GroupMembersRequestBuilder built;
  int _page = 0;

  @override
  Future<List<GroupMember>> fetchNext({
    required Function(List<GroupMember> groupMemberList)? onSuccess,
    required Function(CometChatException excep)? onError,
  }) async {
    final page = server.serve(built, _page++);
    onSuccess?.call(page);
    return page;
  }
}

/// The kit's data source, minus the two SDK calls the bloc makes on start-up.
class _Remote extends GroupMembersRemoteDataSourceImpl {
  @override
  Future<User?> getLoggedInUser() async => null;

  @override
  Future<Conversation?> getConversation(String guid) async => null;
}

/// What the kit's repository asked the data source for.
typedef _Asked = ({
  int limit,
  String? keyword,
  GroupMembersRequestBuilder? builder,
});

/// The kit's data source with the SDK fetch replaced: records each call and
/// answers from [pages], so the path without an app builder can be observed.
class _RecordingRemote extends _Remote {
  _RecordingRemote(this.pages);

  final List<List<GroupMember>> pages;
  final asked = <_Asked>[];

  @override
  Future<List<GroupMember>> getGroupMembers({
    required String guid,
    int limit = 30,
    String? searchKeyword,
    GroupMembersRequestBuilder? groupMembersRequestBuilder,
  }) async {
    asked.add((
      limit: limit,
      keyword: searchKeyword,
      builder: groupMembersRequestBuilder,
    ));
    final i = asked.length - 1;
    return i < pages.length ? pages[i] : const <GroupMember>[];
  }
}

// ─── Fixtures ────────────────────────────────────────────────────────────────

final _group = Group(guid: 'g1', name: 'Dev Team', type: 'public');

GroupMember _member(String uid, String name, [String? scope]) => GroupMember(
  uid: uid,
  name: name,
  scope: scope ?? GroupMemberScope.participant,
);

/// 23 members; three of them match "team", and those three are admins.
List<GroupMember> _roster() => [
  for (var i = 0; i < 20; i++) _member('m$i', 'Member $i'),
  for (var i = 0; i < 3; i++)
    _member('a$i', 'abc team $i', GroupMemberScope.admin),
];

GroupMembersBloc _blocWith(
  GroupMembersRequestBuilder? builder, {
  GroupMembersRemoteDataSource? source,
}) {
  final repo = GroupMembersRepositoryImpl(
    remoteDataSource: source ?? _Remote(),
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

List<String> _uids(GroupMembersBloc bloc) => [
  for (final m in (bloc.state as GroupMembersLoaded).members) m.uid,
];

bool _hasMore(GroupMembersBloc bloc) =>
    (bloc.state as GroupMembersLoaded).hasMore;

/// Lets a search's 300 ms debounce elapse and its fetch land.
Future<void> _afterDebounce() async {
  await Future<void>.delayed(const Duration(milliseconds: 350));
  await pumpEventQueue();
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('GroupMembersRemoteDataSourceImpl with an app builder', () {
    test("builds with the app's limit and filters, and leaves the builder as "
        'the app set it', () async {
      final server = _Server(_roster());
      final builder = _AppBuilder(server, 'g1')
        ..limit = 2
        ..scopes = [GroupMemberScope.admin];

      final page = await GroupMembersRemoteDataSourceImpl().getGroupMembers(
        guid: 'g1',
        limit: 30,
        groupMembersRequestBuilder: builder,
      );

      expect([for (final m in page) m.uid], ['a0', 'a1']);
      expect(server.sent.single.limit, 2);
      expect(server.sent.single.scopes, [GroupMemberScope.admin]);
      expect(builder.limit, 2);
      expect(builder.scopes, [GroupMemberScope.admin]);
    });

    test("uses the caller's limit when the app set none, and does not keep "
        'it', () async {
      final server = _Server(_roster());
      final builder = _AppBuilder(server, 'g1');

      await GroupMembersRemoteDataSourceImpl().getGroupMembers(
        guid: 'g1',
        limit: 25,
        groupMembersRequestBuilder: builder,
      );

      expect(server.sent.single.limit, 25);
      expect(builder.limit, isNull);
    });

    test("a search keyword applies to that request only; the app's own "
        'comes back', () async {
      final server = _Server(_roster());
      final builder = _AppBuilder(server, 'g1')..searchKeyword = 'team';
      final source = GroupMembersRemoteDataSourceImpl();

      await source.getGroupMembers(
        guid: 'g1',
        searchKeyword: 'Member 1',
        groupMembersRequestBuilder: builder,
      );
      expect(server.sent.last.keyword, 'Member 1');
      expect(builder.searchKeyword, 'team');

      source.reset();
      await source.getGroupMembers(
        guid: 'g1',
        groupMembersRequestBuilder: builder,
      );
      expect(server.sent.last.keyword, 'team');

      source.reset();
      await source.getGroupMembers(
        guid: 'g1',
        searchKeyword: '',
        groupMembersRequestBuilder: builder,
      );
      expect(server.sent.last.keyword, 'team');
    });

    test("the list's group wins over the builder's; the builder keeps its "
        'own', () async {
      final server = _Server(_roster());
      final builder = _AppBuilder(server, 'some-other-group')..limit = 5;

      final page = await GroupMembersRemoteDataSourceImpl().getGroupMembers(
        guid: 'g1',
        groupMembersRequestBuilder: builder,
      );

      expect(page, hasLength(5));
      expect(server.sent.single.guid, 'g1');
      expect(builder.guid, 'some-other-group');
    });

    test('pages on from the same request; another builder starts a new '
        'one', () async {
      final server = _Server(_roster());
      final builder = _AppBuilder(server, 'g1')..limit = 10;
      final other = _AppBuilder(server, 'g1')..limit = 10;
      final source = GroupMembersRemoteDataSourceImpl();

      await source.getGroupMembers(
        guid: 'g1',
        groupMembersRequestBuilder: builder,
      );
      await source.getGroupMembers(
        guid: 'g1',
        groupMembersRequestBuilder: builder,
      );
      await source.getGroupMembers(
        guid: 'g1',
        groupMembersRequestBuilder: other,
      );

      expect([for (final s in server.sent) s.page], [0, 1, 0]);
    });

    test('the builder is restored even when building fails', () async {
      final builder = _AppBuilder(_Server(const []), 'app-guid')
        ..searchKeyword = 'team'
        ..failBuild = true;

      await expectLater(
        GroupMembersRemoteDataSourceImpl().getGroupMembers(
          guid: 'g1',
          searchKeyword: 'abc',
          groupMembersRequestBuilder: builder,
        ),
        throwsA(isA<GroupMembersRemoteDataSourceException>()),
      );
      expect(builder.guid, 'app-guid');
      expect(builder.searchKeyword, 'team');
      expect(builder.limit, isNull);
    });
  });

  group('GroupMembersBloc with an app builder', () {
    test('pages by the builder limit past the first page, and stops on the '
        'empty page', () async {
      final server = _Server(_roster());
      final bloc = _blocWith(_AppBuilder(server, 'g1')..limit = 10);
      addTearDown(bloc.close);

      bloc.add(const LoadGroupMembers());
      await pumpEventQueue();
      expect(_uids(bloc), hasLength(10));
      expect(_hasMore(bloc), isTrue);

      bloc.add(const LoadMoreGroupMembers());
      await pumpEventQueue();
      expect(_uids(bloc), hasLength(20));

      bloc.add(const LoadMoreGroupMembers());
      await pumpEventQueue();
      expect(_uids(bloc), hasLength(23));
      expect(_hasMore(bloc), isTrue);

      bloc.add(const LoadMoreGroupMembers());
      await pumpEventQueue();
      expect(_uids(bloc), hasLength(23));
      expect(_hasMore(bloc), isFalse);

      expect([for (final s in server.sent) s.limit], [10, 10, 10, 10]);
      expect([for (final s in server.sent) s.page], [0, 1, 2, 3]);
      expect([for (final s in server.sent) s.guid], everyElement('g1'));
      expect(_uids(bloc).toSet(), hasLength(23));
    });

    test("the builder's filters apply to every page", () async {
      final server = _Server(_roster());
      final bloc = _blocWith(
        _AppBuilder(server, 'g1')
          ..limit = 2
          ..scopes = [GroupMemberScope.admin],
      );
      addTearDown(bloc.close);

      bloc.add(const LoadGroupMembers());
      await pumpEventQueue();
      bloc.add(const LoadMoreGroupMembers());
      await pumpEventQueue();

      expect(_uids(bloc), ['a0', 'a1', 'a2']);
      expect([
        for (final s in server.sent) s.scopes,
      ], everyElement([GroupMemberScope.admin]));
    });

    test('load-more during a search pages on through the search', () async {
      final server = _Server(_roster());
      final bloc = _blocWith(_AppBuilder(server, 'g1')..limit = 2);
      addTearDown(bloc.close);

      bloc.add(const LoadGroupMembers());
      await pumpEventQueue();
      bloc.add(const SearchGroupMembers('team'));
      await _afterDebounce();
      expect(_uids(bloc), ['a0', 'a1']);

      bloc.add(const LoadMoreGroupMembers());
      await pumpEventQueue();

      expect(_uids(bloc), ['a0', 'a1', 'a2']);
      expect(server.sent.last.keyword, 'team');
      expect(server.sent.last.page, 1);
    });

    test('a cleared search reloads from the app builder, without the typed '
        'keyword, and paging carries on', () async {
      final server = _Server(_roster());
      final builder = _AppBuilder(server, 'g1')..limit = 10;
      final bloc = _blocWith(builder);
      addTearDown(bloc.close);

      bloc.add(const LoadGroupMembers());
      await pumpEventQueue();
      bloc.add(const LoadMoreGroupMembers());
      await pumpEventQueue();
      expect(_uids(bloc), hasLength(20));

      bloc.add(const SearchGroupMembers('abc'));
      await _afterDebounce();
      expect(_uids(bloc), ['a0', 'a1', 'a2']);
      expect(builder.searchKeyword, isNull);

      bloc.add(const SearchGroupMembers(''));
      await pumpEventQueue();
      expect(builder.searchKeyword, isNull);
      expect(server.sent.last.keyword, isNull);
      expect(server.sent.last.page, 0);
      expect(_uids(bloc), hasLength(10));
      expect(_hasMore(bloc), isTrue);

      bloc.add(const LoadMoreGroupMembers());
      await pumpEventQueue();
      expect(server.sent.last.keyword, isNull);
      expect(server.sent.last.page, 1);
      expect(_uids(bloc), hasLength(20));
      expect(_uids(bloc).toSet(), hasLength(20));

      expect(
        [for (final s in server.sent) s.keyword],
        [null, null, 'abc', null, null],
      );
      expect([for (final s in server.sent) s.limit], everyElement(10));
      expect(builder.limit, 10);
    });

    test(
      "a cleared search brings back the app builder's own keyword",
      () async {
        final server = _Server(_roster());
        final builder = _AppBuilder(server, 'g1')
          ..limit = 10
          ..searchKeyword = 'team';
        final bloc = _blocWith(builder);
        addTearDown(bloc.close);

        bloc.add(const LoadGroupMembers());
        await pumpEventQueue();
        expect(_uids(bloc), ['a0', 'a1', 'a2']);

        bloc.add(const SearchGroupMembers('Member 1'));
        await _afterDebounce();
        expect(server.sent.last.keyword, 'Member 1');
        expect(builder.searchKeyword, 'team');

        bloc.add(const SearchGroupMembers(''));
        await pumpEventQueue();
        expect(server.sent.last.keyword, 'team');
        expect(_uids(bloc), ['a0', 'a1', 'a2']);
        expect(builder.searchKeyword, 'team');
      },
    );

    test('after a refresh lands during a search, load-more pages the '
        'refreshed list, not the search', () async {
      final server = _Server(_roster());
      final bloc = _blocWith(_AppBuilder(server, 'g1')..limit = 10);
      addTearDown(bloc.close);

      bloc.add(const LoadGroupMembers());
      await pumpEventQueue();
      bloc.add(const SearchGroupMembers('Member'));
      await _afterDebounce();
      expect(server.sent.last.keyword, 'Member');

      bloc.add(const RefreshGroupMembers());
      await pumpEventQueue();
      bloc.add(const LoadMoreGroupMembers());
      await pumpEventQueue();

      expect(server.sent.last.keyword, isNull);
      expect(server.sent.last.page, 1);
      expect(_uids(bloc), hasLength(20));
      expect(_uids(bloc).toSet(), hasLength(20));
    });

    test('load-more waits for the reload a cleared search starts', () async {
      final server = _Server(_roster());
      final gate = Completer<void>();
      final builder = _GatedBuilder(server, 'g1', gate)..limit = 10;
      final bloc = _blocWith(builder);
      addTearDown(bloc.close);

      bloc.add(const LoadGroupMembers());
      await pumpEventQueue();
      bloc.add(const LoadMoreGroupMembers());
      await pumpEventQueue();
      bloc.add(const SearchGroupMembers('abc'));
      await _afterDebounce();

      builder.holdNextFetch = true;
      bloc.add(const SearchGroupMembers(''));
      await pumpEventQueue();
      // The restored list shows while the reload is held.
      expect(_uids(bloc), hasLength(20));
      final sentBefore = server.sent.length;

      bloc.add(const LoadMoreGroupMembers());
      await pumpEventQueue();
      expect(server.sent, hasLength(sentBefore));

      gate.complete();
      await pumpEventQueue();
      expect(_uids(bloc), hasLength(10));
      expect(server.sent.last.page, 0);
    });
  });

  group('GroupMembersBloc without an app builder', () {
    test('asks for pages of 30 with no builder, as before', () async {
      final full = [for (var i = 0; i < 30; i++) _member('p$i', 'P $i')];
      final source = _RecordingRemote([
        full,
        [_member('x', 'X')],
        const [],
      ]);
      final bloc = _blocWith(null, source: source);
      addTearDown(bloc.close);

      bloc.add(const LoadGroupMembers());
      await pumpEventQueue();
      expect(_hasMore(bloc), isTrue);

      bloc.add(const LoadMoreGroupMembers());
      await pumpEventQueue();
      expect(_uids(bloc), hasLength(31));
      expect(_hasMore(bloc), isTrue);

      bloc.add(const LoadMoreGroupMembers());
      await pumpEventQueue();
      expect(_hasMore(bloc), isFalse);

      expect([for (final a in source.asked) a.limit], [30, 30, 30]);
      expect([for (final a in source.asked) a.builder], everyElement(isNull));
      expect([for (final a in source.asked) a.keyword], everyElement(isNull));
    });

    test('a first page shorter than 30 is the last, as before', () async {
      final source = _RecordingRemote([
        [_member('a', 'A'), _member('b', 'B')],
      ]);
      final bloc = _blocWith(null, source: source);
      addTearDown(bloc.close);

      bloc.add(const LoadGroupMembers());
      await pumpEventQueue();

      expect(_uids(bloc), ['a', 'b']);
      expect(_hasMore(bloc), isFalse);
    });
  });

  group('CometChatGroupMembers', () {
    testWidgets('groupMembersRequestBuilder shapes the request the list '
        'loads', (tester) async {
      final server = _Server(_roster());
      final builder = _AppBuilder(server, 'g1')
        ..limit = 10
        ..scopes = [GroupMemberScope.admin];

      await runZonedGuarded(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Translations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: CometChatGroupMembers(
                group: _group,
                groupMembersRequestBuilder: builder,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }, (_, _) {});

      expect(find.text('abc team 0'), findsOneWidget);
      expect(find.text('abc team 2'), findsOneWidget);
      expect(find.text('Member 0'), findsNothing);
      expect(server.sent.first.guid, 'g1');
      expect(server.sent.first.limit, 10);
      expect(server.sent.first.scopes, [GroupMemberScope.admin]);
      expect(builder.limit, 10);
      expect(builder.searchKeyword, isNull);
    });
  });
}

/// An [_AppBuilder] whose next request can be held until [gate] completes.
class _GatedBuilder extends _AppBuilder {
  _GatedBuilder(super.server, super.guid, this.gate);

  final Completer<void> gate;
  bool holdNextFetch = false;

  @override
  GroupMembersRequest build() {
    final request = super.build() as _ServedRequest;
    if (!holdNextFetch) return request;
    holdNextFetch = false;
    return _HeldRequest(request, gate.future);
  }
}

class _HeldRequest extends Fake implements GroupMembersRequest {
  _HeldRequest(this.inner, this.held);

  final _ServedRequest inner;
  final Future<void> held;

  @override
  Future<List<GroupMember>> fetchNext({
    required Function(List<GroupMember> groupMemberList)? onSuccess,
    required Function(CometChatException excep)? onError,
  }) async {
    await held;
    return inner.fetchNext(onSuccess: onSuccess, onError: onError);
  }
}
