import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

/// Adapter that wraps [GroupMembersBloc] to implement [CometChatGroupMembersControllerProtocol].
///
/// This adapter allows the BLoC-based group members list to work with existing
/// code that expects the controller protocol, enabling backward compatibility
/// during the migration from GetX to BLoC.
///
/// Example usage:
/// ```dart
/// final bloc = GroupMembersBloc(group: myGroup);
/// final adapter = GroupMembersBlocAdapter(
///   bloc: bloc,
///   context: context,
/// );
///
/// // Use adapter with stateCallBack
/// CometChatGroupMembers(
///   group: myGroup,
///   stateCallBack: (controller) {
///     // controller is the adapter
///   },
/// );
/// ```
class GroupMembersBlocAdapter
    implements CometChatGroupMembersControllerProtocol {
  /// The underlying BLoC instance
  final GroupMembersBloc bloc;

  /// Creates a [GroupMembersBlocAdapter].
  ///
  /// [bloc] - The GroupMembersBloc to wrap
  /// [context] - Current build context
  GroupMembersBlocAdapter({required this.bloc, required BuildContext context});

  /// Update the context (call this in didChangeDependencies)
  void updateContext(BuildContext context) {
    // Context tracking reserved for future use
  }

  // ============================================================
  // CometChatGroupMembersControllerProtocol Implementation
  // ============================================================

  @override
  List<CometChatOption> defaultFunction(
    Group group,
    GroupMember member,
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    // Delegate to bloc's getDefaultOptions and convert CometChatGroupMemberOption to CometChatOption
    final options = bloc.getDefaultOptions(
      member,
      context,
      colorPalette,
      typography,
      spacing,
    );

    return options
        .map(
          (option) => CometChatOption(
            id: option.id,
            title: option.title,
            icon: option.icon,
            packageName: option.packageName,
            backgroundColor: option.backgroundColor,
            iconTint: option.iconTint,
            titleStyle: option.titleStyle,
            onClick: option.onClick != null
                ? () => option.onClick!(group, member, this)
                : null,
          ),
        )
        .toList();
  }

  // ============================================================
  // CometChatSearchListControllerProtocol Implementation
  // ============================================================

  @override
  onSearch(String val) {
    bloc.add(SearchGroupMembers(val));
  }

  // ============================================================
  // CometChatListProtocol Implementation
  // ============================================================

  @override
  bool match(GroupMember elementA, GroupMember elementB) {
    return elementA.uid == elementB.uid;
  }

  @override
  loadMoreElements({bool Function(GroupMember element)? isIncluded}) {
    bloc.add(const LoadMoreGroupMembers());
  }

  @override
  int getMatchingIndex(GroupMember element) {
    return bloc.findMemberIndex(element.uid) ?? -1;
  }

  @override
  updateElement(GroupMember element, {int? index}) {
    bloc.add(UpdateMember(element));
  }

  @override
  addElement(GroupMember element, {int index = 0}) {
    bloc.addItem(element);
  }

  @override
  removeElement(GroupMember element) {
    bloc.removeItem(element);
  }

  @override
  int getMatchingIndexFromKey(String key) {
    return bloc.findMemberIndex(key) ?? -1;
  }

  @override
  removeElementAt(int index) {
    final state = bloc.state;
    if (state is GroupMembersLoaded &&
        index >= 0 &&
        index < state.members.length) {
      bloc.removeItem(state.members[index]);
    }
  }

  @override
  List<GroupMember> getList() {
    final state = bloc.state;
    if (state is GroupMembersLoaded) {
      return state.members;
    }
    return [];
  }
}
