/// Golden pins for [CometChatGroupMembers]: the member row with each scope
/// chip, and the screen's state views.
///
/// The real screen is rendered, held in a fixed state through its
/// `groupMembersBloc` seam. Avatars have no URL, so they fall back to initials
/// and nothing touches the network.
///
///   flutter test test/chat_ui/group_members/goldens/                  # verify
///   flutter test test/chat_ui/group_members/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_harness.dart';

class _MockGroupMembersBloc
    extends MockBloc<GroupMembersEvent, GroupMembersState>
    implements GroupMembersBloc {}

/// The owner chip is driven by `group.owner`, not by the member's scope.
Group _group() => Group(
  guid: 'g-design',
  name: 'Design Review',
  type: CometChatGroupType.private,
  owner: 'u-priya',
  membersCount: 5,
  hasJoined: true,
);

/// One row per chip: owner, admin, moderator, none (participant), plus the
/// logged-in user, whose row is titled "You".
List<GroupMember> _members() => [
  GroupMember(
    uid: 'u-priya',
    name: 'Priya Raman',
    scope: GroupMemberScope.admin,
    status: 'online',
  ),
  GroupMember(
    uid: 'u-marcus',
    name: 'Marcus Webb',
    scope: GroupMemberScope.admin,
    status: 'offline',
  ),
  GroupMember(
    uid: 'u-bianca',
    name: 'Bianca Rossi',
    scope: GroupMemberScope.moderator,
    status: 'online',
  ),
  GroupMember(
    uid: 'u-chen',
    name: 'Chen Wei',
    scope: GroupMemberScope.participant,
    status: 'offline',
  ),
  GroupMember(
    uid: 'u-me',
    name: 'Sam Carter',
    scope: GroupMemberScope.participant,
    status: 'online',
  ),
];

_MockGroupMembersBloc _bloc(
  GroupMembersState state, {
  Set<String> selected = const {},
}) {
  final bloc = _MockGroupMembersBloc();
  whenListen(bloc, Stream<GroupMembersState>.value(state), initialState: state);
  when(
    () => bloc.loggedInUser,
  ).thenReturn(User(uid: 'u-me', name: 'Sam Carter'));
  when(() => bloc.getSelectedList()).thenReturn(
    state is GroupMembersLoaded
        ? state.members.where((m) => selected.contains(m.uid)).toList()
        : <GroupMember>[],
  );
  return bloc;
}

const _size = Size(375, 520);

void main() {
  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      lightDarkGolden(
        'member rows: owner, admin, moderator and participant scope chips',
        fileName: 'group_members_scope_chips',
        size: _size,
        builder: () => CometChatGroupMembers(
          group: _group(),
          groupMembersBloc: _bloc(
            GroupMembersLoaded(members: _members(), hasMore: false),
          ),
        ),
      );

      lightDarkGolden(
        'member rows in multi-select, two rows checked',
        fileName: 'group_members_selection',
        size: _size,
        builder: () => CometChatGroupMembers(
          group: _group(),
          selectionMode: SelectionMode.multiple,
          activateSelection: ActivateSelection.onClick,
          groupMembersBloc: _bloc(
            GroupMembersLoaded(
              members: _members(),
              hasMore: false,
              selectedMembers: const {'u-marcus', 'u-chen'},
            ),
            selected: const {'u-marcus', 'u-chen'},
          ),
        ),
      );

      lightDarkGolden(
        'group members empty state',
        fileName: 'group_members_state_empty',
        size: _size,
        builder: () => CometChatGroupMembers(
          group: _group(),
          groupMembersBloc: _bloc(const GroupMembersEmpty()),
        ),
      );

      lightDarkGolden(
        'group members error state',
        fileName: 'group_members_state_error',
        size: _size,
        builder: () => CometChatGroupMembers(
          group: _group(),
          groupMembersBloc: _bloc(
            const GroupMembersError(message: 'Something went wrong'),
          ),
        ),
      );

      // The loading (shimmer) state has no golden on purpose. The shimmer is an
      // animation, so the frame that gets rasterised depends on where its
      // controller happens to be: baked on macOS these passed locally and
      // failed on CI's Linux runner, in all five list components. A golden of
      // an animating gradient pins timing, not layout. The loading views keep
      // their widget-test coverage instead (ENG-38688).
    },
  );
}
