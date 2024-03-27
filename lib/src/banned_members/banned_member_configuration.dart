import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[BannedMemberConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [CometChatBannedMembers]
///can be used by a component where [CometChatBannedMembers] is a child component
///
/// ```dart
/// BannedMemberConfiguration(
///     title: "members banished",
///     disableUsersPresence: true,
/// 		bannedMembersStyle: BannedMembersStyle(
///     backIconTint: Colors.green,
///     background: Colors.lightBlue,
///     titleStyle: TextStyle(
///     backgroundColor: Colors.yellow,
///           color: Colors.deepOrange,
///           fontSize: 21,
///           fontWeight: FontWeight.bold
///     )
///   )
///  );
/// ```
class BannedMemberConfiguration {
  BannedMemberConfiguration(
      {this.requestBuilder,
      this.hideSeparator,
      this.childView,
      this.bannedMembersStyle = const BannedMembersStyle(),
      this.options,
      this.controller,
      this.theme,
      this.searchPlaceholder,
      this.backButton,
      this.showBackButton = true,
      this.searchBoxIcon,
      this.hideSearch = true,
      this.selectionMode,
      this.onSelection,
      this.title,
      this.errorStateText,
      this.emptyStateText,
      this.subtitleView,
      this.avatarStyle,
      this.disableUsersPresence,
      this.loadingStateView,
      this.emptyStateView,
      this.errorStateView,
      this.hideError,
      this.statusIndicatorStyle,
      this.onError,
      this.onBack,
      this.onItemTap,
      this.onItemLongPress,
      this.activateSelection,
      this.appBarOptions,
      this.listItemStyle,
      this.bannedMemberProtocol,
      this.bannedMemberRequestBuilder,
      this.unbanIconUrl,
      this.unbanIconUrlPackageName,
      this.stateCallBack});

  ///[requestBuilder] set custom request builder
  final UIBannedGroupMemberRequestBuilder? requestBuilder;

  ///[hideSeparator] toggle visibility of separator
  final bool? hideSeparator;

  ///[childView] set custom view for each banned member
  final Widget Function(GroupMember)? childView;

  ///[bannedMembersStyle] sets bannedMembersStyle
  final BannedMembersStyle bannedMembersStyle;

  ///[controller] sets controller for the list
  final ScrollController? controller;

  ///[options]  set options which will be visible at slide of each banned member
  final List<CometChatOption>? Function(
      Group group,
      GroupMember member,
      CometChatBannedMembersController controller,
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

  ///[selectionMode] specifies mode banned members module is opening in
  final SelectionMode? selectionMode;

  ///[onSelection] function will be performed
  final Function(List<GroupMember>?)? onSelection;

  ///[title] sets title for the list
  final String? title;

  ///[emptyStateText] text to be displayed when the list is empty
  final String? emptyStateText;

  ///[errorStateText] text to be displayed when error occurs
  final String? errorStateText;

  ///[subtitleView] to set subtitleView for each banned member
  final Widget? Function(GroupMember)? subtitleView;

  ///[hideUserPresence] controls visibility of status indicator
  final bool? disableUsersPresence;

  ///[avatarStyle] is applied to the avatar of the user banned from the group
  final AvatarStyle? avatarStyle;

  ///[loadingStateView] returns view fow loading state
  final WidgetBuilder? loadingStateView;

  ///[emptyStateView] returns view fow empty state
  final WidgetBuilder? emptyStateView;

  ///[errorStateView] returns view fow error state behind the dialog
  final WidgetBuilder? errorStateView;

  ///[hideError] toggle visibility of error dialog
  final bool? hideError;

  ///[statusIndicatorStyle] is applied to the online/offline status indicator of the user banned from the group
  final StatusIndicatorStyle? statusIndicatorStyle;

  ///[onError] callback triggered in case any error happens when fetching users
  final OnError? onError;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  ///[onItemTap] callback triggered on tapping a user item
  final Function(User)? onItemTap;

  ///[onItemLongPress] callback triggered on pressing for long on a user item
  final Function(User)? onItemLongPress;

  ///[activateSelection] lets the widget know if banned members are allowed to be selected
  final ActivateSelection? activateSelection;

  ///[appBarOptions] list of options to be visible in app bar
  final List<Widget>? appBarOptions;

  ///[listItemStyle] bannedMembersStyle for every list item
  final ListItemStyle? listItemStyle;

  ///[bannedMemberProtocol] is a wrapper for request builder
  final BannedMemberBuilderProtocol? bannedMemberProtocol;

  ///[bannedMemberRequestBuilder] set custom request builder
  final BannedGroupMembersRequestBuilder? bannedMemberRequestBuilder;

  ///[unbanIconUrl] is a custom icon for the default option
  final String? unbanIconUrl;

  ///[unbanIconUrlPackageName] is the package for the asset image to show as custom icon for the default option
  final String? unbanIconUrlPackageName;

  ///[stateCallBack] to access controller functions  from parent pass empty reference of  CometChatBannedMembersController object
  final Function(CometChatBannedMembersController controller)? stateCallBack;
}
