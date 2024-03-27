import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[GroupMembersConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [CometChatGroupMembers]
///can be used by a component where [CometChatGroupMembers] is a child component
/// ```dart
/// GroupMembersConfiguration(
///        avatarStyle: AvatarStyle(),
///        listItemStyle: ListItemStyle(),
///        statusIndicatorStyle: StatusIndicatorStyle(),
///        groupScopeStyle: GroupScopeStyle(),
///        groupMemberStyle: GroupMembersStyle()
///        );
/// ```
class GroupMembersConfiguration {
  const GroupMembersConfiguration(
      {this.groupMembersProtocol,
      this.subtitleView,
      this.hideSeparator,
      this.listItemView,
      this.groupMemberStyle = const GroupMembersStyle(),
      this.controller,
      this.theme,
      this.searchPlaceholder,
      this.backButton,
      this.showBackButton = true,
      this.searchBoxIcon,
      this.hideSearch = false,
      this.selectionMode,
      this.onSelection,
      this.title,
      this.errorStateText,
      this.emptyStateText,
      this.stateCallBack,
      this.groupMembersRequestBuilder,
      this.hideError,
      this.loadingStateView,
      this.emptyStateView,
      this.errorStateView,
      this.listItemStyle,
      this.avatarStyle,
      this.statusIndicatorStyle,
      this.appBarOptions,
      this.options,
      this.group,
      this.groupScopeStyle,
      this.tailView,
      this.selectIcon,
      this.submitIcon,
      this.disableUsersPresence = false,
      this.onError,
      this.onBack,
      this.onItemTap,
      this.onItemLongPress,
      this.activateSelection});

  ///property to be set internally by using passed parameters [groupMembersProtocol] ,[selectionMode] ,[options]
  ///these are passed to the [CometChatGroupMembersController] which is responsible for the business logic

  ///[groupMembersProtocol] set custom request builder protocol
  final GroupMembersBuilderProtocol? groupMembersProtocol;

  ///[groupMembersRequestBuilder] set custom request builder
  final GroupMembersRequestBuilder? groupMembersRequestBuilder;

  ///[subtitleView] to set subtitle for each groupMember
  final Widget? Function(BuildContext, GroupMember)? subtitleView;

  ///[hideSeparator] toggle visibility of separator
  final bool? hideSeparator;

  ///[listItemView] set custom view for each groupMember
  final Widget Function(GroupMember)? listItemView;

  ///[groupMemberStyle] sets style
  final GroupMembersStyle groupMemberStyle;

  ///[controller] sets controller for the list
  final ScrollController? controller;

  ///[options]  set options which will be visible at slide of each groupMember
  final List<CometChatOption>? Function(
      Group group,
      GroupMember member,
      CometChatGroupMembersController controller,
      BuildContext context)? options;

  ///[searchPlaceholder] placeholder text of search input
  final String? searchPlaceholder;

  ///[backButton] back button
  final Widget? backButton;

  ///[showBackButton] switch on/off back button
  final bool showBackButton;

  ///[searchBoxIcon] search icon
  final Widget? searchBoxIcon;

  ///[hideSearch] switch on/ff search input
  final bool hideSearch;

  ///[theme] can pass custom theme
  final CometChatTheme? theme;

  ///[selectionMode] specifies mode groupMembers module is opening in
  final SelectionMode? selectionMode;

  ///[onSelection] function will be performed
  final Function(List<GroupMember>?)? onSelection;

  ///[title] sets title for the list
  final String? title;

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

  ///[hideError] toggle visibility of error dialog
  final bool? hideError;

  ///[stateCallBack] to access controller functions  from parent pass empty reference of  CometChatGroupMembersController object
  final Function(CometChatGroupMembersController controller)? stateCallBack;

  ///[listItemStyle] style for every list item
  final ListItemStyle? listItemStyle;

  ///[avatarStyle] set style for avatar
  final AvatarStyle? avatarStyle;

  ///[statusIndicatorStyle] set style for status indicator
  final StatusIndicatorStyle? statusIndicatorStyle;

  ///[appBarOptions] list of options to be visible in app bar
  final List<Widget>? appBarOptions;

  ///object to passed across to fetch members of
  final Group? group;

  ///[groupScopeStyle] styling properties for group scope which is displayed on tail of every list item
  final GroupScopeStyle? groupScopeStyle;

  ///[tailView] a custom widget for the tail section of the group member list item
  final Function(BuildContext, GroupMember)? tailView;

  ///[submitIcon] will override the default selection complete icon
  final Widget? submitIcon;

  ///[selectIcon] will override the default selection icon
  final Widget? selectIcon;

  ///[disableUsersPresence] controls visibility of user online status indicator
  final bool disableUsersPresence;

  ///[onError] callback triggered in case any error happens when fetching users
  final OnError? onError;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  ///[onItemTap] callback triggered on tapping a user item
  final Function(User)? onItemTap;

  ///[onItemLongPress] callback triggered on pressing for long on a user item
  final Function(User)? onItemLongPress;

  ///[activateSelection] lets the widget know if groups are allowed to be selected
  final ActivateSelection? activateSelection;
}
