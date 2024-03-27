import 'package:flutter/material.dart';

import '../../cometchat_chat_uikit.dart';

///[AddMemberConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [CometChatAddMembers]
///can be used by a component where [CometChatAddMembers] is a child component
/// ```dart
/// AddMembersConfiguration(
///   title: "Add to Group",
///   disableUsersPresence: true
///   addMembersStyle: AddMembersStyle()
/// );
/// ```
class AddMemberConfiguration {
  const AddMemberConfiguration({
    this.onSelection,
    this.subtitleView,
    this.disableUsersPresence,
    this.listItemView,
    this.appBarOptions,
    this.options,
    this.hideSeparator,
    this.selectionMode,
    this.emptyStateText,
    this.errorStateText,
    this.loadingStateView,
    this.emptyStateView,
    this.errorStateView,
    this.hideError,
    this.usersRequestBuilder,
    this.usersProtocol,
    this.title,
    this.searchPlaceholder,
    this.backButton,
    this.showBackButton = true,
    this.searchIcon,
    this.hideSearch = false,
    this.theme,
    this.addMembersStyle,
    this.onBack,
    this.selectionIcon,
    this.onError,
    this.avatarStyle,
    this.listItemStyle,
    this.statusIndicatorStyle,
    this.submitIcon,
  });

  ///[title] Title of the component
  final String? title;

  ///[searchPlaceholder] placeholder text of search input
  final String? searchPlaceholder;

  ///[backButton] back button widget
  final Widget? backButton;

  ///[showBackButton] switch visibility of back button
  final bool showBackButton;

  ///[searchIcon] replace search icon
  final Widget? searchIcon;

  ///[hideSearch] switch visibility of search input
  final bool? hideSearch;

  ///[theme] set custom theme
  final CometChatTheme? theme;

  ///[onSelection] method will be performed on complete selection
  final Function(List<User>?, BuildContext)? onSelection;

  ///[addMembersStyle] provides styling to this widget
  final AddMembersStyle? addMembersStyle;

  ///[subtitleView] provides custom view for subtitle in list item
  final Widget? Function(BuildContext, User)? subtitleView;

  ///[disableUsersPresence] controls visibility of status indicator shown if user is online
  final bool? disableUsersPresence;

  ///[listItemView] provides custom view for list item
  final Widget Function(User)? listItemView;

  ///[appBarOptions] custom options shown in the app bar
  final List<Widget> Function(BuildContext context)? appBarOptions;

  ///[options] are the actions available on swiping the user item
  final List<CometChatOption>? Function(
      User, CometChatUsersController controller)? options;

  ///[hideSeparator] controls visibility of the separator
  final bool? hideSeparator;

  ///[selectionMode] specifies mode users module is opening in
  final SelectionMode? selectionMode;

  ///[emptyStateText] text to be displayed when the list is empty
  final String? emptyStateText;

  ///[errorStateText] text to be displayed when error occurs
  final String? errorStateText;

  ///[loadingStateView] returns view fow loading state
  final WidgetBuilder? loadingStateView;

  ///[emptyStateView] returns view fow empty state
  final WidgetBuilder? emptyStateView;

  ///[errorStateView] returns view fow error state behind the dialog
  final WidgetBuilder? errorStateView;

  ///[hideError] toggle visibility of error dialog
  final bool? hideError;

  ///[usersRequestBuilder] custom request builder
  final UsersRequestBuilder? usersRequestBuilder;

  ///[usersProtocol] set custom request builder
  final UsersBuilderProtocol? usersProtocol;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  ///[selectionIcon] will override the default selection complete icon
  final Widget? selectionIcon;

  ///[onError] callback triggered in case any error happens when fetching users or adding members
  final OnError? onError;

  ///[avatarStyle] set style for avatar
  final AvatarStyle? avatarStyle;

  ///[statusIndicatorStyle] set style for status indicator
  final StatusIndicatorStyle? statusIndicatorStyle;

  ///[listItemStyle] style for every list item
  final ListItemStyle? listItemStyle;

  ///[submitIcon] will override the default selection complete icon
  final Widget? submitIcon;
}
