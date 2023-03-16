import 'package:flutter/material.dart';

import '../../../../flutter_chat_ui_kit.dart';

///Configuration class to alter [CometChatGroups] properties from all parent widgets
///
/// ```dart
/// GroupsConfiguration(
///         hideCreateGroup: false,
///         showBackButton: true,
///         title: 'Groups',
///         hideSearch: false,
///         searchPlaceholder: 'Search',
///         groupListConfiguration: GroupListConfiguration(),
///       );
///```
///
class GroupsConfiguration {
  const GroupsConfiguration({
    this.title,
    this.searchPlaceholder,
    this.showBackButton = true,
    this.hideSearch = false,
    this.groupsStyle,
    this.groupsRequestBuilder,
    this.subtitleView,
    this.listItemView,
    this.controller,
    this.options,
    this.backButton,
    this.searchBoxIcon,
    this.theme,
    this.selectionMode,
    this.onSelection,
    this.emptyText,
    this.errorText,
    this.loadingView,
    this.emptyView,
    this.errorView,
    this.listItemStyle,
    this.avatarStyle,
    this.statusIndicatorStyle,
    this.createGroupIcon,
    this.joinProtectedGroupConfiguration,
    this.hideSeparator = false,
    this.passwordGroupIcon,
    this.privateGroupIcon,
    this.activateSelection,
    this.hideError,
    this.stateCallBack,
    this.groupsProtocol,
    this.appBarOptions,
    this.onError,
    this.onBack,
    this.onItemTap,
    this.onItemLongPress,
  });

  ///[groupsRequestBuilder] set custom request builder
  final GroupsRequestBuilder? groupsRequestBuilder;

  ///[subtitleView] to set subtitle for each group
  final Widget? Function(BuildContext, Group)? subtitleView;

  ///[listItemView] set custom view for each group
  final Widget Function(Group)? listItemView;

  ///[groupsStyle] sets style
  final GroupsStyle? groupsStyle;

  ///[controller] sets controller for the list
  final ScrollController? controller;

  ///[options]  set options which will be visible at slide of each banned member
  final List<CometChatOption>? Function(Group group,
      CometChatGroupsController controller, BuildContext context)? options;

  ///[searchPlaceholder] placeholder text of search input
  final String? searchPlaceholder;

  ///[backButton] back button
  final Widget? backButton;

  ///[showBackButton] switch on/off back button
  final bool? showBackButton;

  ///[searchBoxIcon] search icon
  final Widget? searchBoxIcon;

  ///[hideSearch] switch on/ff search input
  final bool hideSearch;

  ///[theme] can pass custom theme
  final CometChatTheme? theme;

  ///[selectionMode] specifies mode groups module is opening in
  final SelectionMode? selectionMode;

  ///[onSelection] function will be performed
  final Function(List<Group>?)? onSelection;

  ///[title] sets title for the list
  final String? title;

  ///[emptyText] text to be displayed when the list is empty
  final String? emptyText;

  ///[errorText] text to be displayed when error occur
  final String? errorText;

  ///[loadingView] returns view fow loading state
  final WidgetBuilder? loadingView;

  ///[emptyView] returns view fow empty state
  final WidgetBuilder? emptyView;

  ///[errorView] returns view fow error state behind the dialog
  final WidgetBuilder? errorView;

  ///[listItemStyle] style for every list item
  final ListItemStyle? listItemStyle;

  ///[avatarStyle] set style for avatar
  final AvatarStyle? avatarStyle;

  ///[statusIndicatorStyle] set style for status indicator
  final StatusIndicatorStyle? statusIndicatorStyle;

  ///[createGroupIcon] replace create group icon
  final Widget? createGroupIcon;

  ///[joinProtectedGroupConfiguration] sets configuration for [CometChatJoinProtectedGroup]
  final JoinProtectedGroupConfiguration? joinProtectedGroupConfiguration;

  ///[hideSeparator]
  final bool hideSeparator;

  ///[passwordGroupIcon] sets icon in status indicator for password group
  final Widget? passwordGroupIcon;

  ///[privateGroupIcon] sets icon in status indicator for private group
  final Widget? privateGroupIcon;

  ///[activateSelection] lets the widget know if conversations are allowed to be selected
  final ActivateSelection? activateSelection;

  ///[hideError] toggle visibility of error dialog
  final bool? hideError;

  ///[stateCallBack] to access controller functions  from parent pass empty reference of  CometChatGroupsController object
  final Function(CometChatGroupsController controller)? stateCallBack;

  ///[groupsProtocol] set custom groups request builder protocol
  final GroupsBuilderProtocol? groupsProtocol;

  ///[appBarOptions] list of options to be visible in app bar
  final List<Widget> Function(BuildContext context)? appBarOptions;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  ///[onItemTap] callback triggered on tapping a group item
  final Function(Group)? onItemTap;

  ///[onItemLongPress] callback triggered on pressing for long on a group item
  final Function(Group)? onItemLongPress;

  ///[onError] callback triggered in case any error happens when fetching groups
  final OnError? onError;
}
