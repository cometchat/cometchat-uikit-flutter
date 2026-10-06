/// [GroupMembersBloc] — pagination, search, selection and the three member
/// actions (kick / ban / scope change).
///
/// `group_members_bloc_test.dart` covers the initial load; this file covers
/// what happens after it. The bloc runs over a mocked repository with
/// `disableSDKListeners: true`, so no SDK listener is registered and the
/// public events are dispatched directly.
///
/// The three member actions announce themselves on [CometChatGroupEvents],
/// a plain in-process map, so the action message each one broadcasts is
/// asserted too — that message is what the message list renders as
/// "X kicked Y", and it is built from four different sources.
///
///   flutter test test/chat_ui/group_members/group_members_bloc_actions_test.dart
library;

import 'dart:async';

// Aliased: the barrel re-exports two different `GetLoggedInUserUseCase`
// classes (group_members' and groups'), so this one has to be named.
import 'package:cometchat_chat_uikit/chat_ui/src/group_members/domain/usecases/get_logged_in_user_usecase.dart'
    as gm;
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements GroupMembersRepository {}

class FakeMember extends Fake implements GroupMember {
  FakeMember(this._uid, [this._scope = GroupMemberScope.participant]);
  final String _uid;
  final String _scope;
  @override
  String get uid => _uid;
  @override
  String get name => 'Member $_uid';
  @override
  String? get scope => _scope;
  @override
  String? get avatar => null;
  @override
  String? get status => 'offline';
  @override
  String? get role => null;
  @override
  DateTime? get lastActiveAt => null;
  @override
  String? get link => null;
  @override
  Map<String, dynamic>? get metadata => null;
  @override
  String? get statusMessage => null;
  @override
  DateTime? get joinedAt => null;
}

class FakeUser extends Fake implements User {
  @override
  String get uid => 'me';
  @override
  String get name => 'Admin';
}

class FakeGroup extends Fake implements Group {
  @override
  String get guid => 'g1';
  @override
  String get name => 'G1';
  int _count = 5;
  @override
  int get membersCount => _count;
  @override
  set membersCount(int value) => _count = value;
}

class FakeConversation extends Fake implements Conversation {
  @override
  String? get conversationId => 'group_g1';
}

/// Records the member-action broadcasts the bloc puts on the kit group bus.
class GroupEventRecorder with CometChatGroupEventListener {
  final List<(String, Action, GroupMember)> events = [];

  @override
  void ccGroupMemberKicked(
    Action message,
    User kickedUser,
    User kickedBy,
    Group kickedFrom,
  ) => events.add(('kicked', message, kickedUser as GroupMember));

  @override
  void ccGroupMemberBanned(
    Action message,
    User bannedUser,
    User bannedBy,
    Group bannedFrom,
  ) => events.add(('banned', message, bannedUser as GroupMember));

  @override
  void ccGroupMemberScopeChanged(
    Action message,
    User updatedUser,
    String scopeChangedTo,
    String scopeChangedFrom,
    Group group,
  ) => events.add(('scope', message, updatedUser as GroupMember));
}

void main() {
  late MockRepo repo;
  late FakeGroup theGroup;
  late GroupEventRecorder groupEvents;

  setUpAll(() {
    registerFallbackValue(FakeMember('fallback'));
  });

  setUp(() {
    repo = MockRepo();
    theGroup = FakeGroup();
    groupEvents = GroupEventRecorder();
    CometChatGroupEvents.addGroupsListener('gm_actions', groupEvents);
    when(() => repo.resetPagination()).thenReturn(null);
    when(
      () => repo.getLoggedInUser(),
    ).thenAnswer((_) async => Success(FakeUser()));
    when(
      () => repo.getConversation(any()),
    ).thenAnswer((_) async => Success(FakeConversation()));
    when(
      () => repo.getGroupMembers(
        guid: any(named: 'guid'),
        limit: any(named: 'limit'),
        searchKeyword: any(named: 'searchKeyword'),
      ),
    ).thenAnswer((_) async => const Success(<GroupMember>[]));
  });

  tearDown(() {
    CometChatGroupEvents.removeGroupsListener('gm_actions');
  });

  GroupMembersBloc makeBloc() => GroupMembersBloc(
    group: theGroup,
    getGroupMembersUseCase: GetGroupMembersUseCase(repo),
    loadMoreGroupMembersUseCase: LoadMoreGroupMembersUseCase(repo),
    kickGroupMemberUseCase: KickGroupMemberUseCase(repo),
    banGroupMemberUseCase: BanGroupMemberUseCase(repo),
    updateMemberScopeUseCase: UpdateMemberScopeUseCase(repo),
    getLoggedInUserUseCase: gm.GetLoggedInUserUseCase(repo),
    repository: repo,
    disableSDKListeners: true,
  );

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 40));

  /// Answers successive `getGroupMembers` calls from [pages]; the last repeats.
  void stubPages(List<List<GroupMember>> pages) {
    var call = 0;
    when(
      () => repo.getGroupMembers(
        guid: any(named: 'guid'),
        limit: any(named: 'limit'),
        searchKeyword: any(named: 'searchKeyword'),
      ),
    ).thenAnswer((_) async {
      final page = pages[call < pages.length ? call : pages.length - 1];
      call++;
      return Success(page);
    });
  }

  /// A bloc already loaded with [members].
  Future<GroupMembersBloc> loaded(List<GroupMember> members) async {
    stubPages([members]);
    final bloc = makeBloc();
    bloc.add(const LoadGroupMembers());
    await settle();
    expect(bloc.state, isA<GroupMembersLoaded>());
    return bloc;
  }

  List<String> uids(GroupMembersBloc bloc) =>
      (bloc.state as GroupMembersLoaded).members.map((m) => m.uid).toList();

  /// A full first page, so the bloc believes there is more to fetch.
  List<GroupMember> fullPage([String prefix = 'p']) =>
      List.generate(30, (i) => FakeMember('$prefix$i'));

  // =========================================================================
  // Pagination
  // =========================================================================

  group('LoadMoreGroupMembers', () {
    test('appends the next page and de-duplicates', () async {
      final first = fullPage();
      stubPages([
        first,
        [...first.take(2), FakeMember('new1'), FakeMember('new2')],
      ]);
      final bloc = makeBloc();
      bloc.add(const LoadGroupMembers());
      await settle();
      expect((bloc.state as GroupMembersLoaded).hasMore, isTrue);

      bloc.add(const LoadMoreGroupMembers());
      await settle();

      expect(uids(bloc).length, 32);
      expect(uids(bloc).sublist(30), ['new1', 'new2']);
      expect((bloc.state as GroupMembersLoaded).isLoadingMore, isFalse);
      await bloc.close();
    });

    test('an empty next page ends pagination without losing rows', () async {
      stubPages([fullPage(), const []]);
      final bloc = makeBloc();
      bloc.add(const LoadGroupMembers());
      await settle();

      bloc.add(const LoadMoreGroupMembers());
      await settle();

      final state = bloc.state as GroupMembersLoaded;
      expect(state.hasMore, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.members, hasLength(30));
      await bloc.close();
    });

    test('a further load-more is refused once hasMore is false', () async {
      final bloc = await loaded([FakeMember('a')]);
      expect((bloc.state as GroupMembersLoaded).hasMore, isFalse);

      clearInteractions(repo);
      bloc.add(const LoadMoreGroupMembers());
      await settle();

      verifyNever(
        () => repo.getGroupMembers(
          guid: any(named: 'guid'),
          limit: any(named: 'limit'),
          searchKeyword: any(named: 'searchKeyword'),
        ),
      );
      await bloc.close();
    });

    test('load-more before the first load is refused', () async {
      final bloc = makeBloc();
      bloc.add(const LoadMoreGroupMembers());
      await settle();

      expect(bloc.state, isA<GroupMembersInitial>());
      await bloc.close();
    });

    test('a failed page leaves the list and clears the spinner', () async {
      var call = 0;
      when(
        () => repo.getGroupMembers(
          guid: any(named: 'guid'),
          limit: any(named: 'limit'),
          searchKeyword: any(named: 'searchKeyword'),
        ),
      ).thenAnswer((_) async {
        if (call++ == 0) return Success(fullPage());
        return const Failure(message: 'page failed', code: 'PAGE');
      });

      final bloc = makeBloc();
      bloc.add(const LoadGroupMembers());
      await settle();
      bloc.add(const LoadMoreGroupMembers());
      await settle();

      final state = bloc.state as GroupMembersLoaded;
      expect(
        state.members,
        hasLength(30),
        reason: 'a pagination failure must not clear the list',
      );
      expect(state.isLoadingMore, isFalse);
      await bloc.close();
    });

    test('two load-mores in flight only fire one request', () async {
      stubPages([
        fullPage(),
        [FakeMember('extra')],
      ]);
      final bloc = makeBloc();
      bloc.add(const LoadGroupMembers());
      await settle();
      clearInteractions(repo);

      bloc.add(const LoadMoreGroupMembers());
      bloc.add(const LoadMoreGroupMembers());
      await settle();

      verify(
        () => repo.getGroupMembers(
          guid: any(named: 'guid'),
          limit: any(named: 'limit'),
          searchKeyword: any(named: 'searchKeyword'),
        ),
      ).called(1);
      await bloc.close();
    });
  });

  // =========================================================================
  // Refresh
  // =========================================================================

  test('RefreshGroupMembers resets the cursor and reloads', () async {
    stubPages([
      [FakeMember('a')],
      [FakeMember('b'), FakeMember('c')],
    ]);
    final bloc = makeBloc();
    bloc.add(const LoadGroupMembers());
    await settle();
    expect(uids(bloc), ['a']);

    bloc.add(const RefreshGroupMembers());
    await settle();

    expect(uids(bloc), ['b', 'c']);
    verify(() => repo.resetPagination()).called(greaterThanOrEqualTo(2));
    await bloc.close();
  });

  // =========================================================================
  // Search
  // =========================================================================

  group('SearchGroupMembers', () {
    test(
      'debounces, then queries the server with the trimmed keyword',
      () async {
        stubPages([
          [FakeMember('a'), FakeMember('b')],
          [FakeMember('b')],
        ]);
        final bloc = makeBloc();
        bloc.add(const LoadGroupMembers());
        await settle();

        bloc.add(const SearchGroupMembers('  bee  '));
        await settle();
        expect(uids(bloc), ['a', 'b'], reason: 'not yet — still debouncing');

        await Future<void>.delayed(const Duration(milliseconds: 400));

        expect(uids(bloc), ['b']);
        final captured = verify(
          () => repo.getGroupMembers(
            guid: any(named: 'guid'),
            limit: any(named: 'limit'),
            searchKeyword: captureAny(named: 'searchKeyword'),
          ),
        ).captured;
        expect(captured.last, 'bee');
        await bloc.close();
      },
    );

    test('a later keystroke cancels the pending one', () async {
      final bloc = await loaded([FakeMember('a')]);
      clearInteractions(repo);

      bloc.add(const SearchGroupMembers('b'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      bloc.add(const SearchGroupMembers('bo'));
      await Future<void>.delayed(const Duration(milliseconds: 400));

      verify(
        () => repo.getGroupMembers(
          guid: any(named: 'guid'),
          limit: any(named: 'limit'),
          searchKeyword: any(named: 'searchKeyword'),
        ),
      ).called(1);
      await bloc.close();
    });

    test('a search with no matches shows the empty state', () async {
      stubPages([
        [FakeMember('a')],
        const [],
      ]);
      final bloc = makeBloc();
      bloc.add(const LoadGroupMembers());
      await settle();

      bloc.add(const SearchGroupMembers('zzz'));
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(bloc.state, isA<GroupMembersEmpty>());
      await bloc.close();
    });

    test('a failed search keeps the results already on screen', () async {
      var call = 0;
      when(
        () => repo.getGroupMembers(
          guid: any(named: 'guid'),
          limit: any(named: 'limit'),
          searchKeyword: any(named: 'searchKeyword'),
        ),
      ).thenAnswer((_) async {
        if (call++ == 0) return Success([FakeMember('a')]);
        return const Failure(message: 'search failed');
      });

      final bloc = makeBloc();
      bloc.add(const LoadGroupMembers());
      await settle();

      bloc.add(const SearchGroupMembers('x'));
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(uids(bloc), ['a']);
      await bloc.close();
    });

    test('clearing the keyword restores the pre-search list at once, then '
        'reloads the first page in place', () async {
      // The search replaced the SDK request, so the restored list has no
      // cursor to page on from; a fresh first page gives it one.
      final reload = Completer<Result<List<GroupMember>>>();
      var call = 0;
      when(
        () => repo.getGroupMembers(
          guid: any(named: 'guid'),
          limit: any(named: 'limit'),
          searchKeyword: any(named: 'searchKeyword'),
        ),
      ).thenAnswer((_) {
        switch (call++) {
          case 0:
            return Future.value(Success([FakeMember('a'), FakeMember('b')]));
          case 1:
            return Future.value(Success([FakeMember('b')]));
          default:
            return reload.future;
        }
      });
      final bloc = makeBloc();
      bloc.add(const LoadGroupMembers());
      await settle();

      bloc.add(const SearchGroupMembers('bee'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(uids(bloc), ['b']);

      clearInteractions(repo);
      final states = <GroupMembersState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const SearchGroupMembers(''));
      await settle();

      // Restored at once, while the reload is still in flight.
      expect(uids(bloc), ['a', 'b']);
      final keywords = verify(
        () => repo.getGroupMembers(
          guid: any(named: 'guid'),
          limit: any(named: 'limit'),
          searchKeyword: captureAny(named: 'searchKeyword'),
        ),
      ).captured;
      expect(keywords, [null]);

      reload.complete(
        Success([FakeMember('a'), FakeMember('b'), FakeMember('c')]),
      );
      await settle();

      expect(uids(bloc), ['a', 'b', 'c']);
      expect(
        states.whereType<GroupMembersLoading>(),
        isEmpty,
        reason: 'the reload is silent: the list stays on screen',
      );
      await sub.cancel();
      await bloc.close();
    });

    test(
      'a failed reload after a cleared search keeps the restored list',
      () async {
        var call = 0;
        when(
          () => repo.getGroupMembers(
            guid: any(named: 'guid'),
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
          ),
        ).thenAnswer((_) async {
          switch (call++) {
            case 0:
              return Success([FakeMember('a'), FakeMember('b')]);
            case 1:
              return Success([FakeMember('b')]);
            default:
              return const Failure(message: 'reload failed');
          }
        });
        final bloc = makeBloc();
        bloc.add(const LoadGroupMembers());
        await settle();
        bloc.add(const SearchGroupMembers('bee'));
        await Future<void>.delayed(const Duration(milliseconds: 400));

        bloc.add(const SearchGroupMembers(''));
        await settle();

        expect(bloc.state, isA<GroupMembersLoaded>());
        expect(uids(bloc), ['a', 'b']);
        await bloc.close();
      },
    );

    test('clearing with nothing stored refetches from the server', () async {
      final bloc = makeBloc();
      await settle();
      clearInteractions(repo);

      bloc.add(const SearchGroupMembers(''));
      await settle();

      verify(
        () => repo.getGroupMembers(
          guid: any(named: 'guid'),
          limit: any(named: 'limit'),
          searchKeyword: any(named: 'searchKeyword'),
        ),
      ).called(1);
      await bloc.close();
    });
  });

  // =========================================================================
  // Selection
  // =========================================================================

  group('selection', () {
    test('toggling adds and removes a uid', () async {
      final bloc = await loaded([FakeMember('a'), FakeMember('b')]);

      bloc.add(const ToggleMemberSelection('a'));
      await settle();
      expect((bloc.state as GroupMembersLoaded).selectedMembers, {'a'});
      expect(bloc.getSelectedList()?.map((m) => m.uid), ['a']);

      bloc.add(const ToggleMemberSelection('b'));
      await settle();
      expect((bloc.state as GroupMembersLoaded).selectedMembers, {'a', 'b'});

      bloc.add(const ToggleMemberSelection('a'));
      await settle();
      expect((bloc.state as GroupMembersLoaded).selectedMembers, {'b'});
      await bloc.close();
    });

    test('the owner cannot be selected', () async {
      final bloc = await loaded([
        FakeMember('owner', GroupMemberScope.owner),
        FakeMember('a'),
      ]);

      bloc.add(const ToggleMemberSelection('owner'));
      await settle();

      expect((bloc.state as GroupMembersLoaded).selectedMembers, isEmpty);
      await bloc.close();
    });

    test('an unknown uid is ignored', () async {
      final bloc = await loaded([FakeMember('a')]);

      bloc.add(const ToggleMemberSelection('nobody'));
      await settle();

      expect((bloc.state as GroupMembersLoaded).selectedMembers, isEmpty);
      await bloc.close();
    });

    test('clearing drops every selection', () async {
      final bloc = await loaded([FakeMember('a'), FakeMember('b')]);

      bloc.add(const ToggleMemberSelection('a'));
      bloc.add(const ToggleMemberSelection('b'));
      await settle();
      bloc.add(const ClearMemberSelection());
      await settle();

      expect((bloc.state as GroupMembersLoaded).selectedMembers, isEmpty);
      expect(bloc.getSelectedList(), isEmpty);
      await bloc.close();
    });

    test(
      'selection events and getSelectedList are inert before loading',
      () async {
        final bloc = makeBloc();
        await settle();

        bloc.add(const ToggleMemberSelection('a'));
        bloc.add(const ClearMemberSelection());
        await settle();

        expect(bloc.state, isA<GroupMembersInitial>());
        expect(bloc.getSelectedList(), isNull);
        await bloc.close();
      },
    );

    test(
      'a selected member who is then removed drops out of the list',
      () async {
        final bloc = await loaded([FakeMember('a'), FakeMember('b')]);

        bloc.add(const ToggleMemberSelection('a'));
        bloc.add(const ToggleMemberSelection('b'));
        await settle();

        bloc.removeItem(bloc.items.first);
        await settle();

        expect((bloc.state as GroupMembersLoaded).selectedMembers, {'a', 'b'});
        expect(bloc.getSelectedList()?.map((m) => m.uid), [
          'b',
        ], reason: 'a stale uid must not resurrect a member');
        await bloc.close();
      },
    );
  });

  // =========================================================================
  // Member actions
  // =========================================================================

  group('KickMember', () {
    test(
      'removes the row, decrements the count and announces the action',
      () async {
        when(
          () => repo.kickGroupMember(
            guid: any(named: 'guid'),
            uid: any(named: 'uid'),
          ),
        ).thenAnswer((_) async => const Success(null));

        final bloc = await loaded([FakeMember('a'), FakeMember('b')]);
        bloc.add(KickMember(bloc.items.first));
        await settle();

        expect(uids(bloc), ['b']);
        expect(theGroup.membersCount, 4);

        final event = groupEvents.events.single;
        expect(event.$1, 'kicked');
        expect(event.$3.uid, 'a');
        expect(event.$2.message, 'Admin kicked Member a');
        expect(event.$2.conversationId, 'group_g1');
        expect(event.$2.oldScope, GroupMemberScope.participant);
        expect(event.$2.newScope, '');
        expect(event.$2.receiverUid, 'g1');
        expect(event.$2.type, MessageTypeConstants.groupActions);
        expect(event.$2.receiverType, ReceiverTypeConstants.group);
        await bloc.close();
      },
    );

    test('a failure keeps the row and reports the message', () async {
      when(
        () => repo.kickGroupMember(
          guid: any(named: 'guid'),
          uid: any(named: 'uid'),
        ),
      ).thenAnswer((_) async => const Failure(message: 'not allowed'));

      final bloc = await loaded([FakeMember('a'), FakeMember('b')]);
      bloc.add(KickMember(bloc.items.first));
      await settle();

      final state = bloc.state as GroupMembersError;
      expect(state.message, 'not allowed');
      expect(state.previousMembers?.map((m) => m.uid), [
        'a',
        'b',
      ], reason: 'the error state carries the list so the UI can recover');
      expect(theGroup.membersCount, 5, reason: 'the count must not move');
      expect(groupEvents.events, isEmpty);
      await bloc.close();
    });
  });

  group('BanMember', () {
    test('removes the row and announces a ban', () async {
      when(
        () => repo.banGroupMember(
          guid: any(named: 'guid'),
          uid: any(named: 'uid'),
        ),
      ).thenAnswer((_) async => const Success(null));

      final bloc = await loaded([FakeMember('a'), FakeMember('b')]);
      bloc.add(BanMember(bloc.items.last));
      await settle();

      expect(uids(bloc), ['a']);
      expect(theGroup.membersCount, 4);
      expect(groupEvents.events.single.$1, 'banned');
      expect(groupEvents.events.single.$2.message, 'Admin banned Member b');
      await bloc.close();
    });

    test('a failure surfaces the message and keeps the row', () async {
      when(
        () => repo.banGroupMember(
          guid: any(named: 'guid'),
          uid: any(named: 'uid'),
        ),
      ).thenAnswer((_) async => const Failure(message: 'ban rejected'));

      final bloc = await loaded([FakeMember('a')]);
      bloc.add(BanMember(bloc.items.first));
      await settle();

      expect((bloc.state as GroupMembersError).message, 'ban rejected');
      expect(theGroup.membersCount, 5);
      await bloc.close();
    });
  });

  group('ChangeMemberScope', () {
    test('rewrites the scope in place and announces the change', () async {
      when(
        () => repo.updateMemberScope(
          guid: any(named: 'guid'),
          uid: any(named: 'uid'),
          scope: any(named: 'scope'),
        ),
      ).thenAnswer((_) async => const Success(null));

      final bloc = await loaded([FakeMember('a'), FakeMember('b')]);
      bloc.add(
        ChangeMemberScope(
          member: bloc.items.first,
          newScope: GroupMemberScope.admin,
        ),
      );
      await settle();

      final members = (bloc.state as GroupMembersLoaded).members;
      expect(members.map((m) => m.uid), ['a', 'b']);
      expect(members.first.scope, GroupMemberScope.admin);
      expect(
        theGroup.membersCount,
        5,
        reason: 'a scope change is not a membership change',
      );

      final event = groupEvents.events.single;
      expect(event.$1, 'scope');
      expect(event.$2.message, 'Admin made Member a admin');
      expect(event.$2.oldScope, GroupMemberScope.participant);
      expect(event.$2.newScope, GroupMemberScope.admin);
      await bloc.close();
    });

    test('a scope change for a member not listed still announces', () async {
      when(
        () => repo.updateMemberScope(
          guid: any(named: 'guid'),
          uid: any(named: 'uid'),
          scope: any(named: 'scope'),
        ),
      ).thenAnswer((_) async => const Success(null));

      final bloc = await loaded([FakeMember('a')]);
      bloc.add(
        ChangeMemberScope(
          member: FakeMember('not_listed'),
          newScope: GroupMemberScope.moderator,
        ),
      );
      await settle();

      expect(uids(bloc), ['a'], reason: 'nothing is added to the list');
      expect(groupEvents.events.single.$1, 'scope');
      await bloc.close();
    });

    test('a failure surfaces the message and leaves the scope alone', () async {
      when(
        () => repo.updateMemberScope(
          guid: any(named: 'guid'),
          uid: any(named: 'uid'),
          scope: any(named: 'scope'),
        ),
      ).thenAnswer((_) async => const Failure(message: 'scope rejected'));

      final bloc = await loaded([FakeMember('a')]);
      bloc.add(
        ChangeMemberScope(
          member: bloc.items.first,
          newScope: GroupMemberScope.admin,
        ),
      );
      await settle();

      final state = bloc.state as GroupMembersError;
      expect(state.message, 'scope rejected');
      expect(state.previousMembers?.single.scope, GroupMemberScope.participant);
      expect(groupEvents.events, isEmpty);
      await bloc.close();
    });
  });

  // =========================================================================
  // UpdateMember
  // =========================================================================

  group('UpdateMember', () {
    test('replaces a listed member without growing the list', () async {
      final bloc = await loaded([FakeMember('a'), FakeMember('b')]);

      bloc.add(UpdateMember(FakeMember('b', GroupMemberScope.moderator)));
      await settle();

      final members = (bloc.state as GroupMembersLoaded).members;
      expect(members.map((m) => m.uid), ['a', 'b']);
      expect(members.last.scope, GroupMemberScope.moderator);
      await bloc.close();
    });

    test('an unlisted member is appended', () async {
      final bloc = await loaded([FakeMember('a')]);

      bloc.add(UpdateMember(FakeMember('c')));
      await settle();

      expect(uids(bloc), ['a', 'c']);
      await bloc.close();
    });

    test('is inert before the first load', () async {
      final bloc = makeBloc();
      await settle();

      bloc.add(UpdateMember(FakeMember('a')));
      await settle();

      expect(bloc.state, isA<GroupMembersInitial>());
      await bloc.close();
    });
  });

  // =========================================================================
  // Status notifiers and cleanup
  // =========================================================================

  group('status notifiers', () {
    test('one is created per loaded member and reused', () async {
      final bloc = await loaded([FakeMember('a'), FakeMember('b')]);

      final notifier = bloc.getStatusNotifier('a');
      expect(notifier.value, 'offline');
      expect(bloc.getMemberStatus('a'), 'offline');
      expect(
        bloc.getStatusNotifier('a'),
        same(notifier),
        reason: 'a second call must not replace the notifier the UI listens to',
      );

      notifier.value = 'online';
      expect(bloc.getMemberStatus('a'), 'online');
      expect(
        bloc.getMemberStatus('nobody'),
        'offline',
        reason: 'an unknown uid reads as offline, never null',
      );
      await bloc.close();
    });

    test(
      'close() cancels the debounce so no search lands afterwards',
      () async {
        final bloc = await loaded([FakeMember('a')]);
        clearInteractions(repo);

        bloc.add(const SearchGroupMembers('x'));
        await settle();
        await bloc.close();
        await Future<void>.delayed(const Duration(milliseconds: 400));

        verifyNever(
          () => repo.getGroupMembers(
            guid: any(named: 'guid'),
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
          ),
        );
      },
    );
  });

  // =========================================================================
  // List-state hooks
  // =========================================================================

  group('the list-state hooks', () {
    test('the logged-in user is resolved during construction', () async {
      final bloc = makeBloc();
      await settle();
      expect(bloc.loggedInUser?.uid, 'me');
      await bloc.close();
    });

    test('removing the last member empties the list', () async {
      final bloc = await loaded([FakeMember('a')]);

      bloc.removeItem(bloc.items.first);
      await settle();

      expect(bloc.state, isA<GroupMembersEmpty>());
      await bloc.close();
    });

    test('clearing the list empties it too', () async {
      final bloc = await loaded([FakeMember('a'), FakeMember('b')]);

      bloc.clearItems();
      await settle();

      expect(bloc.state, isA<GroupMembersEmpty>());
      expect(bloc.items, isEmpty);
      await bloc.close();
    });

    test('adding to an empty list re-enters the loaded state', () async {
      stubPages([const []]);
      final bloc = makeBloc();
      bloc.add(const LoadGroupMembers());
      await settle();
      expect(bloc.state, isA<GroupMembersEmpty>());

      bloc.addItem(FakeMember('a'));
      await settle();

      final state = bloc.state as GroupMembersLoaded;
      expect(state.members.map((m) => m.uid), ['a']);
      expect(
        state.hasMore,
        isTrue,
        reason: 'nothing is known about the cursor, so assume there is more',
      );
      await bloc.close();
    });
  });

  // =========================================================================
  // Index lookups
  // =========================================================================

  group('index lookups', () {
    test('findMember and findMemberIndex survive a removal', () async {
      final bloc = await loaded([
        FakeMember('a'),
        FakeMember('b'),
        FakeMember('c'),
      ]);

      expect(bloc.findMemberIndex('b'), 1);
      expect(bloc.findMember('c')?.uid, 'c');

      bloc.removeItem(bloc.items.first);
      await settle();

      expect(
        bloc.findMemberIndex('b'),
        0,
        reason: 'the index map has to be rebuilt after a removal',
      );
      expect(bloc.findMember('a'), isNull);
      await bloc.close();
    });

    test('a null or empty uid resolves to nothing', () async {
      final bloc = await loaded([FakeMember('a')]);

      expect(bloc.findMemberIndex(null), isNull);
      expect(bloc.findMemberIndex(''), isNull);
      expect(bloc.findMember(null), isNull);
      await bloc.close();
    });
  });
}
