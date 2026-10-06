/// Golden pins for [CometChatGroups]: its rows and the three state views.
///
/// The real screen is rendered, held in a fixed state through its `groupsBloc`
/// seam. Group icons have no URL, so they fall back to initials and nothing
/// touches the network.
///
///   flutter test test/chat_ui/groups/goldens/                  # verify
///   flutter test test/chat_ui/groups/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_harness.dart';

class _MockGroupsBloc extends MockBloc<GroupsEvent, GroupsState>
    implements GroupsBloc {
  @override
  List<Group> getSelectedGroups() {
    final current = state;
    if (current is! GroupsLoaded) return const [];
    return current.groups
        .where((g) => current.selectedGroups.contains(g.guid))
        .toList();
  }

  @override
  // ignore: must_call_super
  void add(GroupsEvent event) {}
}

/// One group of each type, with member counts of one, a few and many, so the
/// subtitle pins both its singular and plural form.
List<Group> _groups() => [
  Group(
    guid: 'g-townhall',
    name: 'Company Townhall',
    type: CometChatGroupType.public,
    membersCount: 248,
    hasJoined: true,
  ),
  Group(
    guid: 'g-design',
    name: 'Design Review',
    type: CometChatGroupType.private,
    membersCount: 12,
    hasJoined: true,
  ),
  Group(
    guid: 'g-payroll',
    name: 'Payroll',
    type: CometChatGroupType.password,
    membersCount: 1,
    hasJoined: false,
  ),
  Group(
    guid: 'g-hiking',
    name: 'Weekend Hiking',
    type: CometChatGroupType.public,
    membersCount: 37,
    hasJoined: false,
  ),
];

_MockGroupsBloc _bloc(GroupsState state) {
  final bloc = _MockGroupsBloc();
  whenListen(bloc, Stream<GroupsState>.value(state), initialState: state);
  return bloc;
}

const _size = Size(375, 520);

void main() {
  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      lightDarkGolden(
        'groups list: public, private and password rows with member counts',
        fileName: 'groups_list_loaded',
        size: _size,
        builder: () => CometChatGroups(
          groupsBloc: _bloc(GroupsLoaded(groups: _groups(), hasMore: false)),
        ),
      );

      lightDarkGolden(
        'groups list in multi-select, two rows checked',
        fileName: 'groups_list_selection',
        size: _size,
        builder: () => CometChatGroups(
          selectionMode: SelectionMode.multiple,
          activateSelection: ActivateSelection.onClick,
          groupsBloc: _bloc(
            GroupsLoaded(
              groups: _groups(),
              hasMore: false,
              selectedGroups: const {'g-design', 'g-hiking'},
            ),
          ),
        ),
      );

      lightDarkGolden(
        'groups empty state',
        fileName: 'groups_state_empty',
        size: _size,
        builder: () => CometChatGroups(groupsBloc: _bloc(const GroupsEmpty())),
      );

      lightDarkGolden(
        'groups error state',
        fileName: 'groups_state_error',
        size: _size,
        builder: () => CometChatGroups(
          groupsBloc: _bloc(const GroupsError(message: 'Something went wrong')),
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
