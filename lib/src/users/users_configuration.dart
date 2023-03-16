import 'package:flutter/material.dart';

import '../../../../flutter_chat_ui_kit.dart';

///
///  ```dart
///     UsersConfiguration(
///               hideSearch: false,
///               showBackButton: true,
///               searchPlaceholder: "search",
///               title: "Users",
///               userListConfiguration: UserListConfiguration(),
///             )
///   ```
///
class UsersConfiguration {
  const UsersConfiguration(
      {this.title,
      this.searchPlaceholder,
      this.showBackButton = true,
      this.hideSearch = false,
      this.usersRequestBuilder,
      this.subtitleView,
      this.hideSeparator,
      this.listItemView,
      this.usersStyle,
      this.options,
      this.backButton,
      this.searchBoxIcon,
      this.theme,
      this.selectionMode,
      this.onSelection,
      this.emptyStateText,
      this.errorStateText,
      this.loadingStateView,
      this.emptyStateView,
      this.errorStateView,
      this.listItemStyle,
      this.avatarStyle,
      this.statusIndicatorStyle,
      this.appBarOptions,
      this.hideSectionSeparator,
      this.disableUsersPresence,
      this.activateSelection,
      this.hideError,
      this.stateCallBack,
      this.controller,
      this.usersProtocol,
      this.onError,
      this.onBack,
      this.onItemTap,
      this.onItemLongPress,
      this.selectionIcon});

  ///[title] Title of the user list component
  final String? title;

  ///[searchPlaceholder] placeholder text of search input
  final String? searchPlaceholder;

  ///[showBackButton] switch on/off back button
  final bool showBackButton;

  ///[hideSearch] switch on/off search input
  final bool hideSearch;

  ///[usersRequestBuilder] custom request builder
  final UsersRequestBuilder? usersRequestBuilder;

  ///[subtitleView] to set subtitle for each user
  final Widget? Function(BuildContext, User)? subtitleView;

  ///[hideSeparator] toggle visibility of separator
  final bool? hideSeparator;

  ///[listItemView] set custom view for each user
  final Widget Function(User)? listItemView;

  ///[usersStyle] sets style for the [CometChatUsers]
  final UsersStyle? usersStyle;

  final List<CometChatOption>? Function(
      User, CometChatUsersController controller)? options;

  ///[backButton] back button
  final Widget? backButton;

  ///[searchBoxIcon] search icon
  final Widget? searchBoxIcon;

  ///[theme] can pass custom theme
  final CometChatTheme? theme;

  ///[selectionMode] specifies mode users module is opening in
  final SelectionMode? selectionMode;

  ///[onSelection] function will be performed
  final Function(List<User>?, BuildContext)? onSelection;

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

  ///[appBarOptions] list of options to be visible in app bar
  final List<Widget> Function(BuildContext context)? appBarOptions;

  ///[hideSeparator] toggle visibility of separator
  final bool? hideSectionSeparator;

  ///[disableUsersPresence] controls visibility of status indicator shown if user is online
  final bool? disableUsersPresence;

  ///[activateSelection] lets the widget know if users are allowed to be selected
  final ActivateSelection? activateSelection;

  ///[hideError] toggle visibility of error dialog
  final bool? hideError;

  ///[stateCallBack] to access controller functions  from parent pass empty reference of  CometChatUsersController object
  final Function(CometChatUsersController controller)? stateCallBack;

  ///[controller] sets controller for the list
  final ScrollController? controller;

  ///[usersProtocol] set custom users request builder protocol
  final UsersBuilderProtocol? usersProtocol;

  ///[onError] callback triggered in case any error happens when fetching users
  final OnError? onError;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  ///[onItemTap] callback triggered on tapping a user item
  final Function(User)? onItemTap;

  ///[onItemLongPress] callback triggered on pressing for long on a user item
  final Function(User)? onItemLongPress;

  ///[selectionIcon] will override the default selection complete icon
  final Widget? selectionIcon;
}
