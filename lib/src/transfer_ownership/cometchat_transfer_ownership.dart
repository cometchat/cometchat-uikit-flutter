import 'package:flutter/material.dart';
import '../../cometchat_chat_uikit.dart';
import 'package:get/get_state_manager/get_state_manager.dart';

///[CometChatTransferOwnership] is a component that internally uses [CometChatGroupMembers]
///that displays a list of group members to whom the ownership of the group they are part of can be transferred to
///
/// ```dart
///   TransferOwnershipConfiguration(
///        avatarStyle: AvatarStyle(),
///        listItemStyle: ListItemStyle(),
///        statusIndicatorStyle: StatusIndicatorStyle(),
///        groupMemberStyle: GroupMembersStyle(),
///        transferOwnershipStyle:
///            TransferOwnershipStyle(memberScopeStyle: TextStyle())
///      );
/// ```
///
class CometChatTransferOwnership extends StatelessWidget {
  CometChatTransferOwnership(
      {super.key,
      required Group group,
      this.title,
      this.searchPlaceholder,
      this.hideSearch,
      this.searchBoxIcon,
      this.showBackButton,
      this.backButton,
      this.transferOwnershipStyle,
      Function(GroupMember, Group)? onTransferOwnership,
      this.disableUsersPresence,
      this.groupMembersRequestBuilder,
      this.groupMembersProtocol,
      this.subtitleView,
      this.hideSeparator,
      this.groupMemberStyle,
      this.emptyStateText,
      this.errorStateText,
      this.loadingStateView,
      this.emptyStateView,
      this.errorStateView,
      this.listItemStyle,
      this.avatarStyle,
      this.statusIndicatorStyle,
      this.selectIcon,
      this.submitIcon,
      this.theme,
      this.onBack,
      OnError? onError,
      this.listItemView})
      : _cometChatTransferOwnershipController =
            CometChatTransferOwnershipController(
                group: group,
                onTransferOwnership: onTransferOwnership,
                onError: onError);

  ///[disableUsersPresence] controls visibility of user online status indicator
  final bool? disableUsersPresence;

  ///[backButton] back button
  final Widget? backButton;

  ///[showBackButton] switch on/off back button
  final bool? showBackButton;

  ///[searchBoxIcon] replace search icon
  final Widget? searchBoxIcon;

  ///[hideSearch] switch on/off search input
  final bool? hideSearch;

  ///[title] Title of the component
  final String? title;

  ///[submitIcon] will override the default selection complete icon
  final Widget? submitIcon;

  ///[selectIcon] will override the default selection icon
  final Widget? selectIcon;

  ///[groupMembersRequestBuilder] set custom request builder
  final GroupMembersRequestBuilder? groupMembersRequestBuilder;

  ///[groupMembersProtocol] sets custom request builder protocol
  final GroupMembersBuilderProtocol? groupMembersProtocol;

  ///[subtitleView] to set subtitle for each groupMember
  final Widget? Function(BuildContext, GroupMember)? subtitleView;

  ///[hideSeparator] toggle visibility of separator
  final bool? hideSeparator;

  ///[groupMemberStyle] provides style to [CometChatGroupMembers]
  final GroupMembersStyle? groupMemberStyle;

  ///[searchPlaceholder] placeholder text of search input
  final String? searchPlaceholder;

  ///[emptyStateText] text to be displayed when the list is empty
  final String? emptyStateText;

  ///[errorStateText] text to be displayed when error occur
  final String? errorStateText;

  ///[loadingStateView] returns view fow loading state
  final WidgetBuilder? loadingStateView;

  ///[emptyStateView] returns view fow empty state
  final WidgetBuilder? emptyStateView;

  ///[errorStateView] returns view fow error state behind the dialog
  final WidgetBuilder? errorStateView;

  ///[listItemStyle] style for every list item
  final ListItemStyle? listItemStyle;

  ///[avatarStyle] set style for avatar
  final AvatarStyle? avatarStyle;

  ///[statusIndicatorStyle] set style for status indicator
  final StatusIndicatorStyle? statusIndicatorStyle;

  ///[transferOwnershipStyle] consists of all styling properties
  final TransferOwnershipStyle? transferOwnershipStyle;

  ///[theme] custom theme
  final CometChatTheme? theme;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  final CometChatTransferOwnershipController
      _cometChatTransferOwnershipController;

  ///[listItemView] set custom view for each groupMember
  final Widget Function(GroupMember)? listItemView;

  Widget _tailView(BuildContext context, GroupMember groupMember,
      CometChatTransferOwnershipController transferOwnershipController) {
    final CometChatTheme theme = this.theme ?? cometChatTheme;
    String scope;
    if (groupMember.uid == transferOwnershipController.group.owner) {
      scope = GroupMemberScope.owner;
    } else {
      scope = groupMember.scope ?? GroupMemberScope.participant;
    }
    return Text(
      scope,
      style: transferOwnershipStyle?.memberScopeStyle ??
          TextStyle(
            fontSize: theme.typography.body.fontSize,
            fontWeight: theme.typography.body.fontWeight,
            color: theme.palette.getAccent500(),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CometChatTheme theme = this.theme ?? cometChatTheme;
    return GetBuilder(
        init: _cometChatTransferOwnershipController,
        global: false,
        dispose:
            (GetBuilderState<CometChatTransferOwnershipController> state) =>
                state.controller?.onClose(),
        builder:
            (CometChatTransferOwnershipController transferOwnershipController) {
          return CometChatGroupMembers(
            group: transferOwnershipController.group,
            groupMembersRequestBuilder: groupMembersRequestBuilder,
            groupMembersProtocol: groupMembersProtocol,
            searchPlaceholder: searchPlaceholder,
            disableUsersPresence: disableUsersPresence ?? false,
            options: (group, member, controller, context) => [],
            hideSeparator: hideSeparator ?? true,
            selectionMode: SelectionMode.single,
            title: title ?? Translations.of(context).members,
            hideSearch: hideSearch ?? false,
            backButton: backButton,
            showBackButton: showBackButton ?? true,
            searchBoxIcon: searchBoxIcon,
            onSelection: (members) =>
                transferOwnershipController.getOnSelection(context, members),
            tailView: (context, groupMember) =>
                _tailView(context, groupMember, transferOwnershipController),
            emptyStateText: emptyStateText,
            errorStateText: errorStateText,
            emptyStateView: emptyStateView,
            errorStateView: errorStateView,
            loadingStateView: loadingStateView,
            subtitleView: subtitleView,
            listItemStyle: listItemStyle,
            statusIndicatorStyle: statusIndicatorStyle,
            avatarStyle: avatarStyle,
            groupMemberStyle: groupMemberStyle ?? const GroupMembersStyle(),
            submitIcon: submitIcon ??
                Image.asset(
                  AssetConstants.checkmark,
                  package: UIConstants.packageName,
                  color: transferOwnershipStyle?.submitIconTint ??
                      theme.palette.getPrimary(),
                ),
            selectIcon: selectIcon ??
                Icon(
                  Icons.check,
                  color: transferOwnershipStyle?.selectIconTint ?? Colors.white,
                  size: 12,
                ),
            onBack: onBack,
            activateSelection: ActivateSelection.onClick,
            theme: theme,
          );
        });
  }
}
