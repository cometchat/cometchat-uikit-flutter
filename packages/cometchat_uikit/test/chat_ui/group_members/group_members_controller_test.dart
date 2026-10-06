/// Behaviour tests for [CometChatGroupMembersController] — the legacy
/// `ChangeNotifier` view model behind `CometChatGroupMembers` (the screen also
/// ships a bloc; this controller is the public, subclassable one).
///
/// It sat at 3% line coverage because every concrete use of it goes through
/// the SDK. It does not have to: the base keeps `request` as `late dynamic`
/// and takes it from the injected [GroupMembersBuilderProtocol], so a fake
/// request drives every fetch. The only genuinely SDK-bound line is the
/// `CometChat.getLoggedInUser()` inside `loadMoreElements`, and that is
/// skipped once `loggedInUser` is set — which is what these tests do.
///
/// What is pinned here is the real-time half of the controller, which is what
/// an integrator actually depends on: the presence and membership listeners,
/// the guid guards that stop another group's traffic mutating this list, the
/// selection mixin, and the fetch/paging wiring. Four of those listeners are
/// broken; each has a FINDING beside it.
///
///   flutter test test/chat_ui/group_members/group_members_controller_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' as cc show Action;
// The SDK exports neither of these; registering a client here is the only way
// to answer `CometChat.getLoggedInUser()` without a live connection. Same seam
// as test/helpers/golden_fake_sdk.dart.
// ignore: implementation_imports
import 'package:cometchat_sdk/src/bootstrap/sdk_registry.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/client/sdk_client.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/auth/auth_repository.dart'
    as sdk;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Fixtures ────────────────────────────────────────────────────────────────

const _guid = 'g1';
const _otherGuid = 'g2';

Group _group({String guid = _guid, String owner = 'owner-uid'}) =>
    Group(guid: guid, name: 'Team', type: GroupTypeConstants.public)
      ..owner = owner;

GroupMember _member(
  String uid, {
  String scope = GroupMemberScope.participant,
  String status = CometChatUserStatus.offline,
}) =>
    GroupMember(uid: uid, name: uid.toUpperCase(), scope: scope)
      ..status = status;

User _user(String uid, {String status = CometChatUserStatus.offline}) =>
    User(uid: uid, name: uid.toUpperCase())..status = status;

cc.Action _action() => cc.Action(
  id: 1,
  receiverUid: _guid,
  type: MessageTypeConstants.groupActions,
  receiverType: ReceiverTypeConstants.group,
  conversationId: 'group_$_guid',
  action: 'joined',
);

// ─── Test doubles ────────────────────────────────────────────────────────────

/// A `GroupMembersRequest` that answers from a script instead of the network.
/// `request` on the base controller is `dynamic`, so only the two methods the
/// controller actually calls have to exist.
class _FakeRequest extends Fake implements GroupMembersRequest {
  _FakeRequest({
    this.pages = const [],
    this.failWith,
    this.label = 'plain',
    this.gate,
  });

  /// When set, the fetch parks on this until the test completes it — the only
  /// way to observe the base controller's `isFetching` re-entrancy guard,
  /// which a synchronous request never exercises.
  final Completer<void>? gate;

  /// Pages handed to `onSuccess` in order; running out yields an empty page,
  /// which is how the real request signals the end of the list.
  final List<List<GroupMember>> pages;

  /// When set, every fetch reports this through `onError` instead.
  final CometChatException? failWith;

  /// Lets a test tell the plain request from a search request.
  final String label;

  int calls = 0;
  int _page = 0;

  @override
  Future<List<GroupMember>> fetchNext({
    required Function(List<GroupMember> groupMemberList)? onSuccess,
    required Function(CometChatException excep)? onError,
  }) async {
    calls++;
    if (gate != null) await gate!.future;
    if (failWith != null) {
      onError!(failWith!);
      return const [];
    }
    final page = _page < pages.length ? pages[_page++] : const <GroupMember>[];
    onSuccess!(page);
    return page;
  }
}

/// The injectable seam the controller is built around. Hands out whatever
/// request the test scripted and records the search keywords it was asked for.
class _FakeBuilder extends GroupMembersBuilderProtocol {
  _FakeBuilder({_FakeRequest? request, _FakeRequest? searchRequest})
    : plain = request ?? _FakeRequest(),
      search = searchRequest ?? _FakeRequest(label: 'search'),
      super(GroupMembersRequestBuilder(_guid));

  final _FakeRequest plain;
  final _FakeRequest search;
  final List<String> searchKeywords = [];

  @override
  GroupMembersRequest getRequest() => plain;

  @override
  GroupMembersRequest getSearchRequest(String val) {
    searchKeywords.add(val);
    return search;
  }
}

/// Answers `CometChat.getLoggedInUser()` with a fixed user.
class _FakeAuthRepository extends Fake implements sdk.AuthRepository {
  _FakeAuthRepository(this._user);

  final User? _user;

  @override
  User? getLoggedInUser() => _user;
}

class _FakeSdkClient extends Fake implements sdk.SdkClient {
  _FakeSdkClient(User? user) : auth = _FakeAuthRepository(user);

  @override
  final sdk.AuthRepository auth;

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeBuilder builder;

  /// Builds a controller that is safe to drive without the SDK: `loggedInUser`
  /// is pre-set, so `loadMoreElements` never reaches `CometChat.getLoggedInUser`.
  CometChatGroupMembersController make({
    List<GroupMember> seed = const [],
    _FakeBuilder? withBuilder,
    Group? group,
    SelectionMode? mode,
    bool? userStatusVisibility,
    Function(Exception)? onError,
    void Function()? onEmpty,
    OnLoad<GroupMember>? onLoad,
    User? loggedInUser,
  }) {
    builder = withBuilder ?? _FakeBuilder();
    final c = CometChatGroupMembersController(
      groupMembersBuilderProtocol: builder,
      group: group ?? _group(),
      mode: mode,
      userStatusVisibility: userStatusVisibility,
      onError: onError,
      onEmpty: onEmpty,
      onLoad: onLoad,
    );
    c.loggedInUser = loggedInUser ?? _user('me');
    c.list = [...seed];
    addTearDown(c.dispose);
    return c;
  }

  // ===========================================================================
  group('construction', () {
    test('defaults: presence on, selection off, empty list, loading', () {
      final c = make();

      expect(c.usersStatusVisibility, isTrue);
      expect(c.selectionMode, SelectionMode.none);
      expect(c.group.guid, _guid);
      expect(c.isLoading, isTrue);
      expect(c.isOwner, isNull);
    });

    test('userStatusVisibility:false is honoured, null falls back to true', () {
      expect(make(userStatusVisibility: false).usersStatusVisibility, isFalse);
      expect(make(userStatusVisibility: true).usersStatusVisibility, isTrue);
      expect(make().usersStatusVisibility, isTrue);
    });

    test('the selection mode passed as `mode` is used', () {
      expect(
        make(mode: SelectionMode.multiple).selectionMode,
        SelectionMode.multiple,
      );
      expect(
        make(mode: SelectionMode.single).selectionMode,
        SelectionMode.single,
      );
    });

    test('the three listener ids share one timestamp but stay distinct', () {
      final c = make();

      expect(c.groupSDKListenerID, '${c.dateStamp}groupMembers_listener');
      expect(c.userSDKListenerID, '${c.dateStamp}user_listener');
      expect(c.groupUIListenerID, '${c.dateStamp}_ui_group_listener');
      expect({
        c.groupSDKListenerID,
        c.userSDKListenerID,
        c.groupUIListenerID,
      }, hasLength(3));
    });

    test('two controllers never collide on a listener id', () {
      final a = make();
      final b = make();

      expect(a.groupSDKListenerID, isNot(b.groupSDKListenerID));
    });

    test('the request comes from the injected builder protocol', () {
      final b = _FakeBuilder();
      final c = make(withBuilder: b);

      expect(c.request, same(b.plain));
    });

    test('the hide* option flags are carried verbatim', () {
      final c = CometChatGroupMembersController(
        groupMembersBuilderProtocol: _FakeBuilder(),
        group: _group(),
        hideBanMemberOption: true,
        hideKickMemberOption: false,
        hideScopeChangeOption: true,
      );
      addTearDown(c.dispose);

      expect(c.hideBanMemberOption, isTrue);
      expect(c.hideKickMemberOption, isFalse);
      expect(c.hideScopeChangeOption, isTrue);
    });
  });

  // ===========================================================================
  group('identity — match / getKey', () {
    test('two members match on uid alone, not on scope or name', () {
      final c = make();

      expect(
        c.match(
          _member('u1', scope: GroupMemberScope.admin),
          GroupMember(
            uid: 'u1',
            name: 'Someone else',
            scope: GroupMemberScope.owner,
          ),
        ),
        isTrue,
      );
      expect(c.match(_member('u1'), _member('u2')), isFalse);
    });

    test('getKey is the uid, which is what the selection map is keyed by', () {
      expect(make().getKey(_member('u9')), 'u9');
    });

    test('getMatchingIndexFromKey finds by uid and answers -1 otherwise', () {
      final c = make(seed: [_member('a'), _member('b')]);

      expect(c.getMatchingIndexFromKey('b'), 1);
      expect(c.getMatchingIndexFromKey('zz'), -1);
    });
  });

  // ===========================================================================
  group('presence listeners', () {
    test('onUserOnline writes the status onto the matching member', () {
      final c = make(seed: [_member('a'), _member('b')]);
      var notified = 0;
      c.addListener(() => notified++);

      c.onUserOnline(_user('b', status: CometChatUserStatus.online));

      expect(c.list[1].status, CometChatUserStatus.online);
      expect(c.list[0].status, CometChatUserStatus.offline);
      expect(notified, 1);
    });

    test('onUserOffline writes the status onto the matching member', () {
      final c = make(seed: [_member('a', status: CometChatUserStatus.online)]);

      c.onUserOffline(_user('a'));

      expect(c.list[0].status, CometChatUserStatus.offline);
    });

    test('a presence event for a non-member changes nothing and is silent', () {
      final c = make(seed: [_member('a')]);
      var notified = 0;
      c.addListener(() => notified++);

      c.onUserOnline(_user('stranger', status: CometChatUserStatus.online));

      expect(c.list.single.status, CometChatUserStatus.offline);
      expect(notified, 0);
    });
  });

  // ===========================================================================
  group('scope-change listener', () {
    test('a scope change in this group is applied to the member', () {
      final c = make(seed: [_member('a'), _member('b')]);
      var notified = 0;
      c.addListener(() => notified++);

      c.onGroupMemberScopeChanged(
        _action(),
        _user('me'),
        _user('b'),
        GroupMemberScope.admin,
        GroupMemberScope.participant,
        _group(),
      );

      expect(c.list[1].scope, GroupMemberScope.admin);
      expect(c.list[0].scope, GroupMemberScope.participant);
      expect(notified, 1);
    });

    test('a scope change in another group is ignored', () {
      final c = make(seed: [_member('b')]);
      var notified = 0;
      c.addListener(() => notified++);

      c.onGroupMemberScopeChanged(
        _action(),
        _user('me'),
        _user('b'),
        GroupMemberScope.admin,
        GroupMemberScope.participant,
        _group(guid: _otherGuid),
      );

      expect(c.list.single.scope, GroupMemberScope.participant);
      expect(notified, 0);
    });

    test('a scope change for someone not in the list is ignored', () {
      final c = make(seed: [_member('a')]);
      var notified = 0;
      c.addListener(() => notified++);

      c.onGroupMemberScopeChanged(
        _action(),
        _user('me'),
        _user('not-here'),
        GroupMemberScope.admin,
        GroupMemberScope.participant,
        _group(),
      );

      expect(notified, 0);
    });
  });

  // ===========================================================================
  group('getGroupMemberFromUser', () {
    test('finds the member holding that uid', () {
      final c = make(seed: [_member('a'), _member('b')]);

      expect(c.getGroupMemberFromUser(_user('b'))?.uid, 'b');
    });

    test('answers null for a uid the list does not hold', () {
      final c = make(seed: [_member('a')]);

      expect(c.getGroupMemberFromUser(_user('zz')), isNull);
    });

    test('answers null on an empty list', () {
      expect(make().getGroupMemberFromUser(_user('a')), isNull);
    });
  });

  // ===========================================================================
  group('removal listeners — kicked / left / banned', () {
    for (final kind in ['kicked', 'left', 'banned']) {
      void fire(CometChatGroupMembersController c, User who, Group from) {
        switch (kind) {
          case 'kicked':
            c.onGroupMemberKicked(_action(), who, _user('me'), from);
          case 'left':
            c.onGroupMemberLeft(_action(), who, from);
          case 'banned':
            c.onGroupMemberBanned(_action(), who, _user('me'), from);
        }
      }

      test('$kind drops the member from this group\'s list', () {
        final c = make(seed: [_member('a'), _member('b')]);
        var notified = 0;
        c.addListener(() => notified++);

        fire(c, _user('a'), _group());

        expect(c.list.map((m) => m.uid), ['b']);
        expect(notified, 1);
      });

      test('$kind in another group leaves the list alone', () {
        final c = make(seed: [_member('a')]);
        var notified = 0;
        c.addListener(() => notified++);

        fire(c, _user('a'), _group(guid: _otherGuid));

        expect(c.list, hasLength(1));
        expect(notified, 0);
      });

      test('$kind for someone not in the list is a silent no-op', () {
        final c = make(seed: [_member('a')]);
        var notified = 0;
        c.addListener(() => notified++);

        fire(c, _user('ghost'), _group());

        expect(c.list, hasLength(1));
        expect(notified, 0);
      });
    }
  });

  // ===========================================================================
  group('addition listeners', () {
    test('onGroupMemberJoined prepends a joiner that really is a member', () {
      final c = make(seed: [_member('a')]);

      c.onGroupMemberJoined(_action(), _member('new'), _group());

      expect(c.list.map((m) => m.uid), ['new', 'a']);
    });

    test('onGroupMemberJoined in another group adds nothing', () {
      final c = make(seed: [_member('a')]);

      c.onGroupMemberJoined(
        _action(),
        _member('new'),
        _group(guid: _otherGuid),
      );

      expect(c.list.map((m) => m.uid), ['a']);
    });

    test(
      'FINDING: onGroupMemberJoined throws on the plain User the SDK sends',
      () {
        // FINDING: the body is `addElement(joinedUser as GroupMember)`, but
        // `CometChat._dispatchGroupAction` hands the listener whatever
        // `Action.actionOn` deserialised to — a `User` for a plain join. The
        // cast then throws inside the SDK's listener fan-out. A joiner never
        // appears in the list; worse, the throw escapes into the SDK's
        // `forEach` over every registered group listener.
        final c = make(seed: [_member('a')]);

        expect(
          () => c.onGroupMemberJoined(_action(), _user('new'), _group()),
          throwsA(isA<TypeError>()),
        );
        expect(c.list.map((m) => m.uid), ['a']);
      },
    );

    test(
      'FINDING: onMemberAddedToGroup adds the GROUP, not the added user',
      () {
        // FINDING: the body is `addElement(addedTo as GroupMember)` — it casts
        // the `Group` the member was added TO, not `userAdded`. `Group` is not
        // a `GroupMember`, so this always throws; even if it were reachable it
        // would be the wrong object. `userAdded` is never read.
        final c = make(seed: [_member('a')]);

        expect(
          () => c.onMemberAddedToGroup(
            _action(),
            _user('admin'),
            _member('added'),
            _group(),
          ),
          throwsA(isA<TypeError>()),
        );
        expect(c.list.map((m) => m.uid), ['a']);
      },
    );

    test('onMemberAddedToGroup for another group returns before the cast', () {
      final c = make(seed: [_member('a')]);

      expect(
        () => c.onMemberAddedToGroup(
          _action(),
          _user('admin'),
          _member('added'),
          _group(guid: _otherGuid),
        ),
        returnsNormally,
      );
      expect(c.list, hasLength(1));
    });
  });

  // ===========================================================================
  group('UI-bus listeners', () {
    test('ccGroupMemberAdded prepends every added member, in order', () {
      final c = make(seed: [_member('a')]);

      c.ccGroupMemberAdded(
        [_action()],
        [_member('x'), _member('y')],
        _group(),
        _user('me'),
      );

      // addElement inserts at index 0, so the last added ends up first.
      expect(c.list.map((m) => m.uid), ['y', 'x', 'a']);
    });

    test('ccGroupMemberAdded for another group adds nothing', () {
      final c = make(seed: [_member('a')]);

      c.ccGroupMemberAdded(
        [_action()],
        [_member('x')],
        _group(guid: _otherGuid),
        _user('me'),
      );

      expect(c.list.map((m) => m.uid), ['a']);
    });

    test('ccOwnershipChanged replaces the member row for the new owner', () {
      final c = make(seed: [_member('a'), _member('b')]);
      final owner = _member('b', scope: GroupMemberScope.owner);

      c.ccOwnershipChanged(_group(), owner);

      expect(c.list[1], same(owner));
      expect(c.list[1].scope, GroupMemberScope.owner);
    });

    test('FINDING: ccOwnershipChanged does not actually check the group', () {
      // FINDING: the guard is `if (group.guid == group.guid)` — the
      // PARAMETER shadows the field, so it compares the argument with
      // itself and is always true. An ownership change in an unrelated
      // group still rewrites a row here whenever the uids happen to match.
      final c = make(seed: [_member('b')]);
      final owner = _member('b', scope: GroupMemberScope.owner);

      c.ccOwnershipChanged(_group(guid: _otherGuid), owner);

      expect(c.list.single, same(owner));
    });

    test('ccOwnershipChanged for a uid not in the list changes nothing', () {
      final c = make(seed: [_member('a')]);
      var notified = 0;
      c.addListener(() => notified++);

      c.ccOwnershipChanged(_group(), _member('stranger'));

      expect(c.list.single.uid, 'a');
      expect(notified, 0);
    });
  });

  // ===========================================================================
  group('selection', () {
    test('onTap does nothing while the mode is none', () {
      final c = make(seed: [_member('a')]);

      c.onTap(_member('a'));

      expect(c.getSelectedList(), isEmpty);
    });

    test('single mode keeps at most one selection', () {
      final c = make(mode: SelectionMode.single);

      c.onTap(_member('a'));
      c.onTap(_member('b'));

      expect(c.getSelectedList().map((m) => m.uid), ['b']);
    });

    test('multiple mode accumulates, and a second tap deselects', () {
      final c = make(mode: SelectionMode.multiple);

      c.onTap(_member('a'));
      c.onTap(_member('b'));
      expect(c.getSelectedList().map((m) => m.uid), ['a', 'b']);

      c.onTap(_member('a'));
      expect(c.getSelectedList().map((m) => m.uid), ['b']);
    });

    test('clearSelection empties the map and notifies', () {
      final c = make(mode: SelectionMode.multiple);
      c.onTap(_member('a'));
      c.onTap(_member('b'));
      var notified = 0;
      c.addListener(() => notified++);

      c.clearSelection();

      expect(c.getSelectedList(), isEmpty);
      expect(c.selectionMap, isEmpty);
      expect(notified, 1);
    });

    test('clearSelection on an empty selection still notifies', () {
      final c = make(mode: SelectionMode.multiple);
      var notified = 0;
      c.addListener(() => notified++);

      c.clearSelection();

      expect(notified, 1);
    });
  });

  // ===========================================================================
  group('loadMoreElements', () {
    test('a page lands in the list and clears the loading flag', () async {
      final b = _FakeBuilder(
        request: _FakeRequest(
          pages: [
            [_member('a'), _member('b')],
          ],
        ),
      );
      final c = make(withBuilder: b);
      final loaded = <List<GroupMember>>[];
      c.onLoad = loaded.add;

      await c.loadMoreElements();

      expect(c.list.map((m) => m.uid), ['a', 'b']);
      expect(c.isLoading, isFalse);
      expect(c.hasMoreItems, isTrue);
      expect(b.plain.calls, 1);
      expect(loaded, hasLength(1));
    });

    test('an empty page ends the list and fires onEmpty', () async {
      var empties = 0;
      final c = make(onEmpty: () => empties++);

      await c.loadMoreElements();

      expect(c.list, isEmpty);
      expect(c.hasMoreItems, isFalse);
      expect(c.hasMoreNext, isFalse);
      expect(c.isLoading, isFalse);
      expect(empties, 1);
    });

    test('isIncluded filters the page before it reaches the list', () async {
      final b = _FakeBuilder(
        request: _FakeRequest(
          pages: [
            [_member('a', scope: GroupMemberScope.admin), _member('b')],
          ],
        ),
      );
      final c = make(withBuilder: b);

      await c.loadMoreElements(
        isIncluded: (m) => m.scope == GroupMemberScope.admin,
      );

      expect(c.list.map((m) => m.uid), ['a']);
    });

    test('a pre-set loggedInUser keeps the SDK out of the fetch', () async {
      final c = make(loggedInUser: _user('me'));

      await c.loadMoreElements();

      // Reaching here at all means CometChat.getLoggedInUser was never called;
      // it would have thrown without an initialised SDK.
      expect(c.loggedInUser?.uid, 'me');
      expect(c.isOwner, isNull);
    });

    test(
      'without a logged-in user it asks the SDK once, and stays null',
      () async {
        // `CometChat.getLoggedInUser` swallows the missing-SDK failure and
        // answers null, so the fetch still proceeds — it just cannot decide
        // ownership. An owner-only screen therefore renders as a participant.
        final c = make();
        c.loggedInUser = null;

        await c.loadMoreElements();

        expect(c.loggedInUser, isNull);
        expect(c.isOwner, isNull);
        expect(c.isLoading, isFalse);
      },
    );

    group('with a logged-in user answered by the SDK registry', () {
      setUp(() async {
        await sdk.SdkRegistry.clear();
        sdk.SdkRegistry.register(_FakeSdkClient(_user('owner-uid')));
      });
      tearDown(() => sdk.SdkRegistry.clear());

      test('the first fetch resolves the user and flags ownership', () async {
        final c = make();
        c.loggedInUser = null;

        await c.loadMoreElements();

        expect(c.loggedInUser?.uid, 'owner-uid');
        expect(c.isOwner, isTrue);
      });

      test('a non-owner is resolved but not flagged as owner', () async {
        final c = make(group: _group(owner: 'someone-else'));
        c.loggedInUser = null;

        await c.loadMoreElements();

        expect(c.loggedInUser?.uid, 'owner-uid');
        expect(c.isOwner, isNull);
      });

      test('the lookup happens once, not on every page', () async {
        final b = _FakeBuilder(
          request: _FakeRequest(
            pages: [
              [_member('a')],
              [_member('b')],
            ],
          ),
        );
        final c = make(withBuilder: b);
        c.loggedInUser = null;

        await c.loadMoreElements();
        final resolved = c.loggedInUser;
        await c.loadMoreElements();

        expect(c.loggedInUser, same(resolved));
        expect(b.plain.calls, 2);
      });
    });

    test('successive calls page through the request', () async {
      final b = _FakeBuilder(
        request: _FakeRequest(
          pages: [
            [_member('a')],
            [_member('b')],
          ],
        ),
      );
      final c = make(withBuilder: b);

      await c.loadMoreElements();
      await c.loadMoreElements();
      await c.loadMoreElements();

      expect(c.list.map((m) => m.uid), ['a', 'b']);
      expect(c.hasMoreItems, isFalse);
      expect(b.plain.calls, 3);
    });

    test(
      'FINDING: an SDK error never reaches the integrator onError callback',
      () async {
        // FINDING: `CometChatListController.loadMoreElements` passes the
        // request an `onError` that starts with `_onError(e)`, whose parameter
        // is typed `CometChatListException`. The SDK reports a
        // `CometChatException`, which is an unrelated class, so the implicit
        // downcast throws before `onError?.call(e)` can run. The throw is then
        // swallowed by the surrounding `catch`, which replaces the real error
        // with a generic "ERR". The integrator's own `onError` is never
        // invoked and the real code/message is lost.
        final reported = <Exception>[];
        final b = _FakeBuilder(
          request: _FakeRequest(
            failWith: CometChatException('ERR_GUID', 'bad guid', 'bad guid'),
          ),
        );
        final c = make(withBuilder: b, onError: reported.add);

        await c.loadMoreElements();

        expect(reported, isEmpty, reason: 'the integrator is never told');
        expect(c.hasError, isTrue);
        expect(c.isLoading, isFalse);
        expect((c.error! as CometChatListException).code, 'ERR');
        expect(c.error.toString(), isNot(contains('bad guid')));
      },
    );

    test('the re-entrancy guard drops a fetch started mid-flight', () async {
      final gate = Completer<void>();
      final b = _FakeBuilder(
        request: _FakeRequest(
          gate: gate,
          pages: [
            [_member('a')],
            [_member('b')],
          ],
        ),
      );
      final c = make(withBuilder: b);

      final first = c.loadMoreElements();
      // The first fetch is parked; a second call must be dropped outright.
      await c.loadMoreElements();
      expect(b.plain.calls, 1);

      gate.complete();
      await first;

      expect(b.plain.calls, 1);
      expect(c.list.map((m) => m.uid), ['a']);
      expect(c.isFetching, isFalse);
    });
  });

  // ===========================================================================
  group('onSearch', () {
    testWidgets('swaps in a search request, empties the list and refetches', (
      tester,
    ) async {
      final b = _FakeBuilder(
        request: _FakeRequest(
          pages: [
            [_member('a')],
          ],
        ),
        searchRequest: _FakeRequest(
          pages: [
            [_member('found')],
          ],
          label: 'search',
        ),
      );
      final c = make(seed: [_member('stale')], withBuilder: b);

      c.onSearch('bo');
      // Debounced by 500ms — nothing has happened yet.
      expect(b.searchKeywords, isEmpty);
      expect(c.list, hasLength(1));

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(b.searchKeywords, ['bo']);
      expect(c.request, same(b.search));
      expect(c.list.map((m) => m.uid), ['found']);
      expect(b.plain.calls, 0);
    });

    testWidgets('only the last keystroke within the window survives', (
      tester,
    ) async {
      final b = _FakeBuilder();
      final c = make(withBuilder: b);

      c.onSearch('b');
      await tester.pump(const Duration(milliseconds: 200));
      c.onSearch('bo');
      await tester.pump(const Duration(milliseconds: 200));
      c.onSearch('bob');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(b.searchKeywords, ['bob']);
    });
  });

  // ===========================================================================
  group('lifecycle', () {
    test('onInit registers all three listeners and starts a fetch', () async {
      final b = _FakeBuilder(
        request: _FakeRequest(
          pages: [
            [_member('a')],
          ],
        ),
      );
      final c = make(withBuilder: b);

      c.onInit();
      await Future<void>.delayed(Duration.zero);

      expect(CometChatGroupEvents.groupsListener[c.groupUIListenerID], same(c));
      expect(b.plain.calls, 1);
      expect(c.list.map((m) => m.uid), ['a']);

      c.onClose();
      expect(CometChatGroupEvents.groupsListener[c.groupUIListenerID], isNull);
    });

    test('onClose is idempotent and safe without a prior onInit', () {
      final c = make();

      expect(c.onClose, returnsNormally);
      expect(c.onClose, returnsNormally);
    });

    test('with presence off, onInit/onClose still run cleanly', () async {
      final c = make(userStatusVisibility: false);

      c.onInit();
      await Future<void>.delayed(Duration.zero);
      expect(CometChatGroupEvents.groupsListener[c.groupUIListenerID], same(c));

      c.onClose();
      expect(CometChatGroupEvents.groupsListener[c.groupUIListenerID], isNull);
    });

    test(
      'dispose runs onClose, so the UI bus does not keep the controller',
      () {
        final c = CometChatGroupMembersController(
          groupMembersBuilderProtocol: _FakeBuilder(),
          group: _group(),
        );
        c.loggedInUser = _user('me');
        CometChatGroupEvents.addGroupsListener(c.groupUIListenerID, c);

        c.dispose();

        expect(
          CometChatGroupEvents.groupsListener[c.groupUIListenerID],
          isNull,
        );
      },
    );
  });

  // ===========================================================================
  group('changeScope', () {
    test(
      'a rejected scope change reports and leaves the member alone',
      () async {
        // `CometChat.updateGroupMemberScope` routes its failure to the
        // controller's `onError`, which is the integrator's callback. The
        // member's scope must not move optimistically.
        final reported = <Exception>[];
        final member = _member('bob');
        final c = make(seed: [member], onError: reported.add);

        await c.changeScope(
          c.group,
          member,
          GroupMemberScope.admin,
          GroupMemberScope.participant,
        );

        expect(reported, hasLength(1));
        expect(c.list.single.scope, GroupMemberScope.participant);
      },
    );

    test(
      'with no onError a rejected scope change is simply swallowed',
      () async {
        final member = _member('bob');
        final c = make(seed: [member]);

        await expectLater(
          c.changeScope(
            c.group,
            member,
            GroupMemberScope.admin,
            GroupMemberScope.participant,
          ),
          completes,
        );
        expect(c.list.single.scope, GroupMemberScope.participant);
      },
    );
  });

  // ===========================================================================
  group('isActionRunning', () {
    test('starts false and is a live ValueNotifier the dialog can watch', () {
      final c = make();
      final seen = <bool>[];
      c.isActionRunning.addListener(() => seen.add(c.isActionRunning.value));

      expect(c.isActionRunning.value, isFalse);
      c.isActionRunning.value = true;
      c.isActionRunning.value = false;

      expect(seen, [true, false]);
    });
  });

  // ===========================================================================
  group('defaultFunction', () {
    /// Renders nothing; it only needs a BuildContext under a MaterialApp so
    /// `Translations.of(context)` and the theme helpers resolve.
    Future<List<CometChatOption>> optionsFor(
      WidgetTester tester,
      CometChatGroupMembersController c, {
      required GroupMember member,
      Group? group,
    }) async {
      late List<CometChatOption> options;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              options = c.defaultFunction(
                group ?? c.group,
                member,
                context,
                CometChatThemeHelper.getColorPalette(context),
                CometChatThemeHelper.getTypography(context),
                CometChatThemeHelper.getSpacing(context),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return options;
    }

    testWidgets('an owner sees scope-change, ban and kick for a participant', (
      tester,
    ) async {
      final c = make(loggedInUser: _user('owner-uid'));

      final options = await optionsFor(tester, c, member: _member('bob'));

      expect(options.map((o) => o.id), [
        GroupMemberOptionConstants.changeScope,
        GroupMemberOptionConstants.ban,
        GroupMemberOptionConstants.kick,
      ]);
      for (final o in options) {
        expect(o.title, isNotEmpty);
        expect(o.onClick, isNotNull);
      }
    });

    testWidgets('hideBanMemberOption / hideKickMemberOption drop their rows', (
      tester,
    ) async {
      final c = CometChatGroupMembersController(
        groupMembersBuilderProtocol: _FakeBuilder(),
        group: _group(),
        hideBanMemberOption: true,
        hideKickMemberOption: true,
      );
      c.loggedInUser = _user('owner-uid');
      addTearDown(c.dispose);

      final options = await optionsFor(tester, c, member: _member('bob'));

      expect(options.map((o) => o.id), [
        GroupMemberOptionConstants.changeScope,
      ]);
    });

    testWidgets('hideScopeChangeOption drops only the scope row', (
      tester,
    ) async {
      final c = CometChatGroupMembersController(
        groupMembersBuilderProtocol: _FakeBuilder(),
        group: _group(),
        hideScopeChangeOption: true,
      );
      c.loggedInUser = _user('owner-uid');
      addTearDown(c.dispose);

      final options = await optionsFor(tester, c, member: _member('bob'));

      expect(options.map((o) => o.id), [
        GroupMemberOptionConstants.ban,
        GroupMemberOptionConstants.kick,
      ]);
    });

    testWidgets('a participant gets no options over another participant', (
      tester,
    ) async {
      final c = make(loggedInUser: _user('nobody'));

      final options = await optionsFor(tester, c, member: _member('bob'));

      expect(options, isEmpty);
    });

    testWidgets('nobody gets options over the owner', (tester) async {
      final c = make(loggedInUser: _user('owner-uid'));

      final options = await optionsFor(
        tester,
        c,
        member: _member('owner-uid', scope: GroupMemberScope.owner),
      );

      expect(options, isEmpty);
    });

    testWidgets(
      'tapping the scope-change option opens the change-scope sheet',
      (tester) async {
        final c = make(loggedInUser: _user('owner-uid'));
        late List<CometChatOption> options;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  options = c.defaultFunction(
                    c.group,
                    _member('bob'),
                    context,
                    CometChatThemeHelper.getColorPalette(context),
                    CometChatThemeHelper.getTypography(context),
                    CometChatThemeHelper.getSpacing(context),
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );

        options
            .firstWhere((o) => o.id == GroupMemberOptionConstants.changeScope)
            .onClick!();
        await tester.pumpAndSettle();

        expect(find.byType(CometChatChangeScope), findsOneWidget);
      },
    );

    testWidgets('tapping ban raises a confirm dialog naming the member', (
      tester,
    ) async {
      final c = make(loggedInUser: _user('owner-uid'));
      late List<CometChatOption> options;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                options = c.defaultFunction(
                  c.group,
                  _member('bob'),
                  context,
                  CometChatThemeHelper.getColorPalette(context),
                  CometChatThemeHelper.getTypography(context),
                  CometChatThemeHelper.getSpacing(context),
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      options
          .firstWhere((o) => o.id == GroupMemberOptionConstants.ban)
          .onClick!();
      await tester.pumpAndSettle();

      expect(find.text('Ban BOB?'), findsOneWidget);
      expect(find.textContaining('BOB'), findsWidgets);
    });

    testWidgets('a failed ban closes the dialog and reports to onError', (
      tester,
    ) async {
      // With no SDK registered, `CometChat.banGroupMember` reports through
      // its onError. That is the arm an integrator sees when a ban is
      // rejected: their own onError fires, the spinner clears, the sheet goes.
      final reported = <Exception>[];
      final c = make(loggedInUser: _user('owner-uid'), onError: reported.add);
      late List<CometChatOption> options;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                options = c.defaultFunction(
                  c.group,
                  _member('bob'),
                  context,
                  CometChatThemeHelper.getColorPalette(context),
                  CometChatThemeHelper.getTypography(context),
                  CometChatThemeHelper.getSpacing(context),
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      options
          .firstWhere((o) => o.id == GroupMemberOptionConstants.ban)
          .onClick!();
      await tester.pumpAndSettle();
      await tester.tap(find.text('BAN'));
      await tester.pumpAndSettle();

      expect(reported, hasLength(1));
      expect(c.isActionRunning.value, isFalse);
      expect(find.text('Ban BOB?'), findsNothing);
      // The member is only dropped on success.
      expect(c.list, isEmpty);
    });

    testWidgets('a failed kick closes the dialog and reports to onError', (
      tester,
    ) async {
      final reported = <Exception>[];
      final c = make(
        seed: [_member('bob')],
        loggedInUser: _user('owner-uid'),
        onError: reported.add,
      );
      late List<CometChatOption> options;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                options = c.defaultFunction(
                  c.group,
                  _member('bob'),
                  context,
                  CometChatThemeHelper.getColorPalette(context),
                  CometChatThemeHelper.getTypography(context),
                  CometChatThemeHelper.getSpacing(context),
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      options
          .firstWhere((o) => o.id == GroupMemberOptionConstants.kick)
          .onClick!();
      await tester.pumpAndSettle();
      await tester.tap(find.text('KICK'));
      await tester.pumpAndSettle();

      expect(reported, hasLength(1));
      expect(c.isActionRunning.value, isFalse);
      expect(c.list.map((m) => m.uid), ['bob'], reason: 'kick did not succeed');
    });

    testWidgets('the confirm label becomes a spinner while an action runs', (
      tester,
    ) async {
      final c = make(loggedInUser: _user('owner-uid'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => c.showConfirmDialog(
                  context,
                  CometChatThemeHelper.getColorPalette(context),
                  CometChatThemeHelper.getTypography(context),
                  CometChatThemeHelper.getSpacing(context),
                  title: 'Ban BOB?',
                  messageText: 'Sure?',
                  confirmButtonText: 'BAN',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('BAN'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      c.isActionRunning.value = true;
      await tester.pump();

      expect(find.text('BAN'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('tapping kick raises a confirm dialog naming the member', (
      tester,
    ) async {
      final c = make(loggedInUser: _user('owner-uid'));
      late List<CometChatOption> options;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                options = c.defaultFunction(
                  c.group,
                  _member('bob'),
                  context,
                  CometChatThemeHelper.getColorPalette(context),
                  CometChatThemeHelper.getTypography(context),
                  CometChatThemeHelper.getSpacing(context),
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      options
          .firstWhere((o) => o.id == GroupMemberOptionConstants.kick)
          .onClick!();
      await tester.pumpAndSettle();

      expect(find.textContaining('BOB'), findsWidgets);
    });

    testWidgets('cancelling a confirm dialog clears the running flag', (
      tester,
    ) async {
      final c = make(loggedInUser: _user('owner-uid'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => c.showConfirmDialog(
                    context,
                    CometChatThemeHelper.getColorPalette(context),
                    CometChatThemeHelper.getTypography(context),
                    CometChatThemeHelper.getSpacing(context),
                    title: 'Ban BOB?',
                    messageText: 'Sure?',
                    confirmButtonText: 'BAN',
                  ),
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Ban BOB?'), findsOneWidget);

      c.isActionRunning.value = true;
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      expect(c.isActionRunning.value, isFalse);
      expect(find.text('Ban BOB?'), findsNothing);
    });
  });
}
