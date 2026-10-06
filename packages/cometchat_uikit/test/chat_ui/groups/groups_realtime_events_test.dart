/// The realtime half of [GroupsBloc]: the events its SDK listeners dispatch.
///
/// Every handler here branches on "is this the logged-in user?" and, for the
/// three eviction events, on "is this a private group?". Wiring one of those
/// the wrong way round silently leaves a group the user can no longer see
/// sitting in the list (or drops one they can). The bloc runs over a mocked
/// repository with `disableSDKListeners: true`, so the events are dispatched
/// directly, exactly as the listeners would.
///
/// The second half pins the `props` of every event: the bloc pipeline dedupes
/// on equality, so a field missing from `props` makes a distinct realtime
/// update indistinguishable from the previous one.
///
///   flutter test test/chat_ui/groups/groups_realtime_events_test.dart
library;

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/groups/bloc/groups_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/bloc/groups_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/bloc/groups_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/domain/repositories/groups_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/domain/usecases/get_groups_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/domain/usecases/load_more_groups_usecase.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/constants/ui_kit_constants.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';

class MockGroupsRepository extends Mock implements GroupsRepository {}

/// Unlike the fake in `groups_bloc_test.dart`, the setters here really write —
/// the realtime handlers mutate `hasJoined` and `scope` in place and a no-op
/// setter would make every assertion below vacuous.
class FakeGroup extends Fake implements Group {
  FakeGroup(
    this._guid, {
    String name = 'Group',
    String type = GroupTypeConstants.public,
    bool hasJoined = true,
    String? scope = GroupMemberScope.participant,
  }) : _name = name,
       _type = type,
       _hasJoined = hasJoined,
       _scope = scope;

  final String _guid;
  final String _name;
  String _type;
  bool _hasJoined;
  String? _scope;

  @override
  String get guid => _guid;
  @override
  String get name => _name;
  @override
  String get type => _type;
  @override
  set type(String value) => _type = value;
  @override
  bool get hasJoined => _hasJoined;
  @override
  set hasJoined(bool value) => _hasJoined = value;
  @override
  String? get scope => _scope;
  @override
  set scope(String? value) => _scope = value;
  @override
  int get membersCount => 5;
  @override
  set membersCount(int value) {}
}

class FakeUser extends Fake implements User {
  FakeUser([this._uid = 'test_user']);
  final String _uid;
  @override
  String get uid => _uid;
  @override
  String get name => 'User $_uid';
}

class FakeMember extends Fake implements GroupMember {
  FakeMember([this._uid = 'test_user']);
  final String _uid;
  @override
  String get uid => _uid;
}

class FakeAction extends Fake implements Action {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeGroup('fallback'));
    registerFallbackValue(FakeUser());
  });

  late MockGroupsRepository repo;

  void stubGroups(List<Group> groups) {
    when(
      () => repo.getGroups(
        limit: any(named: 'limit'),
        searchKeyword: any(named: 'searchKeyword'),
        joinedOnly: any(named: 'joinedOnly'),
      ),
    ).thenAnswer((_) async => Success(groups));
  }

  setUp(() {
    repo = MockGroupsRepository();
    when(
      () => repo.getLoggedInUser(),
    ).thenAnswer((_) async => Success(FakeUser()));
    stubGroups(const []);
  });

  GroupsBloc makeBloc() => GroupsBloc(
    getGroupsUseCase: GetGroupsUseCase(repo),
    loadMoreGroupsUseCase: LoadMoreGroupsUseCase(repo),
    getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
    disableSDKListeners: true,
  );

  /// Builds a bloc already loaded with [groups] and hands it to [body].
  /// `_loggedInUser` is resolved from the repo during construction, so the
  /// "is this me?" branches are live by the time [body] runs.
  Future<void> withLoaded(
    List<Group> groups,
    Future<void> Function(GroupsBloc bloc) body,
  ) async {
    stubGroups(groups);
    final bloc = makeBloc();
    bloc.add(const LoadGroups());
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(bloc.state, isA<GroupsLoaded>());
    await body(bloc);
    await bloc.close();
  }

  List<String> guidsOf(GroupsBloc bloc) =>
      (bloc.state as GroupsLoaded).groups.map((g) => g.guid).toList();

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  // -------------------------------------------------------------------------
  // GroupCreated
  // -------------------------------------------------------------------------

  test('GroupCreated puts the new group at the top', () async {
    await withLoaded([FakeGroup('g1')], (bloc) async {
      bloc.add(GroupCreated(FakeGroup('g2')));
      await settle();
      expect(guidsOf(bloc), ['g2', 'g1']);
    });
  });

  test('GroupCreated for a guid already listed updates in place', () async {
    await withLoaded([FakeGroup('g1', name: 'Old'), FakeGroup('g2')], (
      bloc,
    ) async {
      bloc.add(GroupCreated(FakeGroup('g1', name: 'New')));
      await settle();
      expect(guidsOf(bloc), ['g1', 'g2'], reason: 'no duplicate row');
      expect((bloc.state as GroupsLoaded).groups.first.name, 'New');
    });
  });

  // -------------------------------------------------------------------------
  // GroupMemberJoined
  // -------------------------------------------------------------------------

  test('GroupMemberJoined flips hasJoined when it is me', () async {
    final g = FakeGroup('g1', hasJoined: false);
    await withLoaded([g], (bloc) async {
      bloc.add(
        GroupMemberJoined(
          action: FakeAction(),
          joinedUser: FakeUser(),
          group: g,
        ),
      );
      await settle();
      expect(g.hasJoined, isTrue);
      expect(guidsOf(bloc), ['g1'], reason: 'the group stays in place');
    });
  });

  test('GroupMemberJoined leaves hasJoined alone for somebody else', () async {
    final g = FakeGroup('g1', hasJoined: false);
    await withLoaded([g], (bloc) async {
      bloc.add(
        GroupMemberJoined(
          action: FakeAction(),
          joinedUser: FakeUser('someone_else'),
          group: g,
        ),
      );
      await settle();
      expect(g.hasJoined, isFalse);
      expect(guidsOf(bloc), ['g1']);
    });
  });

  // -------------------------------------------------------------------------
  // The three eviction events share one branch shape.
  // -------------------------------------------------------------------------

  final evictions = <String, GroupsEvent Function(Group g, User who)>{
    'GroupMemberLeft': (g, who) =>
        GroupMemberLeft(action: FakeAction(), leftUser: who, group: g),
    'GroupMemberKicked': (g, who) => GroupMemberKicked(
      action: FakeAction(),
      kickedUser: who,
      kickedBy: FakeUser('admin'),
      group: g,
    ),
    'GroupMemberBanned': (g, who) => GroupMemberBanned(
      action: FakeAction(),
      bannedUser: who,
      bannedBy: FakeUser('admin'),
      group: g,
    ),
  };

  evictions.forEach((name, build) {
    test('$name drops a PRIVATE group when it is me', () async {
      final g = FakeGroup('g1', type: GroupTypeConstants.private);
      await withLoaded([g, FakeGroup('g2')], (bloc) async {
        bloc.add(build(g, FakeUser()));
        await settle();
        expect(guidsOf(bloc), ['g2']);
      });
    });

    test('$name only resets a PUBLIC group when it is me', () async {
      final g = FakeGroup('g1');
      await withLoaded([g], (bloc) async {
        bloc.add(build(g, FakeUser()));
        await settle();
        expect(guidsOf(bloc), ['g1'], reason: 'public groups stay listed');
        expect(g.hasJoined, isFalse);
        expect(g.scope, isNull);
      });
    });

    test('$name leaves a private group alone for somebody else', () async {
      final g = FakeGroup('g1', type: GroupTypeConstants.private);
      await withLoaded([g], (bloc) async {
        bloc.add(build(g, FakeUser('someone_else')));
        await settle();
        expect(guidsOf(bloc), ['g1']);
        expect(g.hasJoined, isTrue);
        expect(g.scope, GroupMemberScope.participant);
      });
    });
  });

  // -------------------------------------------------------------------------
  // GroupMemberUnbanned / ScopeChanged / OwnershipTransferred
  // -------------------------------------------------------------------------

  test('GroupMemberUnbanned updates without touching membership', () async {
    final g = FakeGroup('g1', hasJoined: false);
    await withLoaded([g], (bloc) async {
      bloc.add(
        GroupMemberUnbanned(
          action: FakeAction(),
          unbannedUser: FakeUser(),
          unbannedBy: FakeUser('admin'),
          group: g,
        ),
      );
      await settle();
      expect(guidsOf(bloc), ['g1']);
      expect(
        g.hasJoined,
        isFalse,
        reason: 'unban does not re-join, it only refreshes the row',
      );
    });
  });

  test('GroupMemberScopeChanged writes my new scope onto the group', () async {
    final g = FakeGroup('g1');
    await withLoaded([g], (bloc) async {
      bloc.add(
        GroupMemberScopeChanged(
          action: FakeAction(),
          updatedUser: FakeUser(),
          scopeChangedTo: GroupMemberScope.admin,
          scopeChangedFrom: GroupMemberScope.participant,
          group: g,
        ),
      );
      await settle();
      expect(g.scope, GroupMemberScope.admin);
    });
  });

  test('GroupMemberScopeChanged ignores somebody else\'s scope', () async {
    final g = FakeGroup('g1');
    await withLoaded([g], (bloc) async {
      bloc.add(
        GroupMemberScopeChanged(
          action: FakeAction(),
          updatedUser: FakeUser('someone_else'),
          scopeChangedTo: GroupMemberScope.admin,
          scopeChangedFrom: GroupMemberScope.participant,
          group: g,
        ),
      );
      await settle();
      expect(g.scope, GroupMemberScope.participant);
      expect(guidsOf(bloc), ['g1']);
    });
  });

  test('GroupOwnershipTransferred promotes me to owner', () async {
    final g = FakeGroup('g1');
    await withLoaded([g], (bloc) async {
      bloc.add(GroupOwnershipTransferred(group: g, newOwner: FakeMember()));
      await settle();
      expect(g.scope, GroupMemberScope.owner);
    });
  });

  test('GroupOwnershipTransferred to somebody else leaves my scope', () async {
    final g = FakeGroup('g1');
    await withLoaded([g], (bloc) async {
      bloc.add(
        GroupOwnershipTransferred(
          group: g,
          newOwner: FakeMember('someone_else'),
        ),
      );
      await settle();
      expect(g.scope, GroupMemberScope.participant);
    });
  });

  // -------------------------------------------------------------------------
  // InitializeLoggedInUser — the switch behind every "is this me?" branch
  // -------------------------------------------------------------------------

  test(
    'InitializeLoggedInUser(null) disarms the is-this-me branches',
    () async {
      final g = FakeGroup('g1', type: GroupTypeConstants.private);
      await withLoaded([g], (bloc) async {
        bloc.add(const InitializeLoggedInUser(null));
        await settle();
        bloc.add(
          GroupMemberKicked(
            action: FakeAction(),
            kickedUser: FakeUser(),
            kickedBy: FakeUser('admin'),
            group: g,
          ),
        );
        await settle();
        expect(guidsOf(bloc), [
          'g1',
        ], reason: 'with no logged-in user nothing can be "me"');
      });
    },
  );

  test('InitializeLoggedInUser re-points who counts as me', () async {
    final g = FakeGroup('g1', type: GroupTypeConstants.private);
    await withLoaded([g, FakeGroup('g2')], (bloc) async {
      bloc.add(InitializeLoggedInUser(FakeUser('someone_else')));
      await settle();
      bloc.add(
        GroupMemberKicked(
          action: FakeAction(),
          kickedUser: FakeUser('someone_else'),
          kickedBy: FakeUser('admin'),
          group: g,
        ),
      );
      await settle();
      expect(guidsOf(bloc), ['g2']);
    });
  });

  // -------------------------------------------------------------------------
  // ConnectionRestored
  // -------------------------------------------------------------------------

  test('ConnectionRestored refetches while loaded', () async {
    await withLoaded([FakeGroup('g1')], (bloc) async {
      stubGroups([FakeGroup('g1'), FakeGroup('g9')]);
      bloc.add(const ConnectionRestored());
      await settle();
      expect(guidsOf(bloc), ['g1', 'g9']);
    });
  });

  test('ConnectionRestored is inert before the first load', () async {
    final bloc = makeBloc();
    await settle();
    bloc.add(const ConnectionRestored());
    await settle();
    expect(bloc.state, isA<GroupsInitial>());
    verifyNever(
      () => repo.getGroups(
        limit: any(named: 'limit'),
        searchKeyword: any(named: 'searchKeyword'),
        joinedOnly: any(named: 'joinedOnly'),
      ),
    );
    await bloc.close();
  });

  // -------------------------------------------------------------------------
  // Event equality — `props` completeness
  // -------------------------------------------------------------------------

  group('event props', () {
    final action = FakeAction();
    final otherAction = FakeAction();
    final user = FakeUser('u1');
    final otherUser = FakeUser('u2');
    final group = FakeGroup('g1');
    final otherGroup = FakeGroup('g2');
    final member = FakeMember('u1');

    /// Asserts that [a] and [b] are `==` (and hash alike) and that each of
    /// [variants] differs from [a] — i.e. that the varied field is in `props`.
    void pins(String label, Object a, Object b, Map<String, Object> variants) {
      test(label, () {
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
        variants.forEach((field, variant) {
          expect(
            variant,
            isNot(equals(a)),
            reason: '$field must be part of props',
          );
        });
      });
    }

    pins(
      'LoadGroups',
      const LoadGroups(searchKeyword: 'x', silent: true),
      const LoadGroups(searchKeyword: 'x', silent: true),
      {
        'searchKeyword': const LoadGroups(searchKeyword: 'y', silent: true),
        'silent': const LoadGroups(searchKeyword: 'x'),
      },
    );

    test('the valueless load events are const-equal', () {
      expect(const LoadMoreGroups(), const LoadMoreGroups());
      expect(const RefreshGroups(), const RefreshGroups());
      expect(const ClearGroupSelection(), const ClearGroupSelection());
      expect(const ConnectionRestored(), const ConnectionRestored());
      // ...but still distinguishable from one another.
      expect(const LoadMoreGroups(), isNot(equals(const RefreshGroups())));
      expect(
        const ClearGroupSelection(),
        isNot(equals(const ConnectionRestored())),
      );
    });

    pins('SearchGroups', const SearchGroups('a'), const SearchGroups('a'), {
      'keyword': const SearchGroups('b'),
    });

    pins(
      'ToggleGroupSelection',
      const ToggleGroupSelection('g1'),
      const ToggleGroupSelection('g1'),
      {'guid': const ToggleGroupSelection('g2')},
    );

    pins('UpdateGroup', UpdateGroup(group), UpdateGroup(group), {
      'group': UpdateGroup(otherGroup),
    });

    pins('AddGroup', AddGroup(group), AddGroup(group), {
      'group': AddGroup(otherGroup),
    });

    pins('RemoveGroup', const RemoveGroup('g1'), const RemoveGroup('g1'), {
      'guid': const RemoveGroup('g2'),
    });

    pins('GroupCreated', GroupCreated(group), GroupCreated(group), {
      'group': GroupCreated(otherGroup),
    });

    pins(
      'GroupMemberJoined',
      GroupMemberJoined(action: action, joinedUser: user, group: group),
      GroupMemberJoined(action: action, joinedUser: user, group: group),
      {
        'action': GroupMemberJoined(
          action: otherAction,
          joinedUser: user,
          group: group,
        ),
        'joinedUser': GroupMemberJoined(
          action: action,
          joinedUser: otherUser,
          group: group,
        ),
        'group': GroupMemberJoined(
          action: action,
          joinedUser: user,
          group: otherGroup,
        ),
      },
    );

    pins(
      'GroupMemberLeft',
      GroupMemberLeft(action: action, leftUser: user, group: group),
      GroupMemberLeft(action: action, leftUser: user, group: group),
      {
        'action': GroupMemberLeft(
          action: otherAction,
          leftUser: user,
          group: group,
        ),
        'leftUser': GroupMemberLeft(
          action: action,
          leftUser: otherUser,
          group: group,
        ),
        'group': GroupMemberLeft(
          action: action,
          leftUser: user,
          group: otherGroup,
        ),
      },
    );

    pins(
      'GroupMemberKicked',
      GroupMemberKicked(
        action: action,
        kickedUser: user,
        kickedBy: otherUser,
        group: group,
      ),
      GroupMemberKicked(
        action: action,
        kickedUser: user,
        kickedBy: otherUser,
        group: group,
      ),
      {
        'action': GroupMemberKicked(
          action: otherAction,
          kickedUser: user,
          kickedBy: otherUser,
          group: group,
        ),
        'kickedUser': GroupMemberKicked(
          action: action,
          kickedUser: otherUser,
          kickedBy: otherUser,
          group: group,
        ),
        'kickedBy': GroupMemberKicked(
          action: action,
          kickedUser: user,
          kickedBy: user,
          group: group,
        ),
        'group': GroupMemberKicked(
          action: action,
          kickedUser: user,
          kickedBy: otherUser,
          group: otherGroup,
        ),
      },
    );

    pins(
      'GroupMemberBanned',
      GroupMemberBanned(
        action: action,
        bannedUser: user,
        bannedBy: otherUser,
        group: group,
      ),
      GroupMemberBanned(
        action: action,
        bannedUser: user,
        bannedBy: otherUser,
        group: group,
      ),
      {
        'action': GroupMemberBanned(
          action: otherAction,
          bannedUser: user,
          bannedBy: otherUser,
          group: group,
        ),
        'bannedUser': GroupMemberBanned(
          action: action,
          bannedUser: otherUser,
          bannedBy: otherUser,
          group: group,
        ),
        'bannedBy': GroupMemberBanned(
          action: action,
          bannedUser: user,
          bannedBy: user,
          group: group,
        ),
        'group': GroupMemberBanned(
          action: action,
          bannedUser: user,
          bannedBy: otherUser,
          group: otherGroup,
        ),
      },
    );

    pins(
      'GroupMemberUnbanned',
      GroupMemberUnbanned(
        action: action,
        unbannedUser: user,
        unbannedBy: otherUser,
        group: group,
      ),
      GroupMemberUnbanned(
        action: action,
        unbannedUser: user,
        unbannedBy: otherUser,
        group: group,
      ),
      {
        'action': GroupMemberUnbanned(
          action: otherAction,
          unbannedUser: user,
          unbannedBy: otherUser,
          group: group,
        ),
        'unbannedUser': GroupMemberUnbanned(
          action: action,
          unbannedUser: otherUser,
          unbannedBy: otherUser,
          group: group,
        ),
        'unbannedBy': GroupMemberUnbanned(
          action: action,
          unbannedUser: user,
          unbannedBy: user,
          group: group,
        ),
        'group': GroupMemberUnbanned(
          action: action,
          unbannedUser: user,
          unbannedBy: otherUser,
          group: otherGroup,
        ),
      },
    );

    pins(
      'GroupMemberScopeChanged',
      GroupMemberScopeChanged(
        action: action,
        updatedUser: user,
        scopeChangedTo: GroupMemberScope.admin,
        scopeChangedFrom: GroupMemberScope.participant,
        group: group,
      ),
      GroupMemberScopeChanged(
        action: action,
        updatedUser: user,
        scopeChangedTo: GroupMemberScope.admin,
        scopeChangedFrom: GroupMemberScope.participant,
        group: group,
      ),
      {
        'action': GroupMemberScopeChanged(
          action: otherAction,
          updatedUser: user,
          scopeChangedTo: GroupMemberScope.admin,
          scopeChangedFrom: GroupMemberScope.participant,
          group: group,
        ),
        'updatedUser': GroupMemberScopeChanged(
          action: action,
          updatedUser: otherUser,
          scopeChangedTo: GroupMemberScope.admin,
          scopeChangedFrom: GroupMemberScope.participant,
          group: group,
        ),
        'scopeChangedTo': GroupMemberScopeChanged(
          action: action,
          updatedUser: user,
          scopeChangedTo: GroupMemberScope.moderator,
          scopeChangedFrom: GroupMemberScope.participant,
          group: group,
        ),
        'scopeChangedFrom': GroupMemberScopeChanged(
          action: action,
          updatedUser: user,
          scopeChangedTo: GroupMemberScope.admin,
          scopeChangedFrom: GroupMemberScope.moderator,
          group: group,
        ),
        'group': GroupMemberScopeChanged(
          action: action,
          updatedUser: user,
          scopeChangedTo: GroupMemberScope.admin,
          scopeChangedFrom: GroupMemberScope.participant,
          group: otherGroup,
        ),
      },
    );

    pins(
      'GroupOwnershipTransferred',
      GroupOwnershipTransferred(group: group, newOwner: member),
      GroupOwnershipTransferred(group: group, newOwner: member),
      {
        'group': GroupOwnershipTransferred(group: otherGroup, newOwner: member),
        'newOwner': GroupOwnershipTransferred(
          group: group,
          newOwner: FakeMember('u9'),
        ),
      },
    );

    pins(
      'InitializeLoggedInUser',
      InitializeLoggedInUser(user),
      InitializeLoggedInUser(user),
      {
        'user': InitializeLoggedInUser(otherUser),
        'null user': const InitializeLoggedInUser(null),
      },
    );
  });
}
