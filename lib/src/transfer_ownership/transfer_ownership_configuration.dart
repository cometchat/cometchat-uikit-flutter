import 'package:flutter/material.dart';

import '../../cometchat_chat_uikit.dart';

///[TransferOwnershipConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [CometChatTransferOwnership]
/// ```dart
/// TransferOwnershipConfiguration(
///        avatarStyle: AvatarStyle(),
///        listItemStyle: ListItemStyle(),
///        statusIndicatorStyle: StatusIndicatorStyle(),
///        groupMemberStyle: GroupMembersStyle(),
///        transferOwnershipStyle:
///            TransferOwnershipStyle(memberScopeStyle: TextStyle())
///            );
/// ```
class TransferOwnershipConfiguration {
  const TransferOwnershipConfiguration(
      {this.title,
      this.searchPlaceholder,
      this.hideSearch,
      this.showBackButton,
      this.backButton,
      this.onTransferOwnership,
      this.disableUsersPresence = false,
      this.searchBoxIcon,
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
      this.transferOwnershipStyle,
      this.selectIcon,
      this.submitIcon,
      this.theme,
      this.onBack,
      this.onError,
      this.listItemView});

  ///[onTransferOwnership] overrides default on selection functionality
  final Function(GroupMember, Group)? onTransferOwnership;

  ///[disableUsersPresence] controls visibility of status indicator
  final bool disableUsersPresence;

  ///[backButton] back button
  final Widget? backButton;

  ///[showBackButton] switch on/off back button
  final bool? showBackButton;

  ///[searchBoxIcon] replace search icon
  final Widget? searchBoxIcon;

  ///[hideSearch] switch on/ff search input
  final bool? hideSearch;

  ///[title] Title of the component
  final String? title;

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

  ///[submitIcon] will override the default selection complete icon
  final Widget? submitIcon;

  ///[selectIcon] will override the default selection icon
  final Widget? selectIcon;

  ///[theme] custom theme
  final CometChatTheme? theme;

  ///[onError] callback triggered in case any error happens when transferring ownership
  final OnError? onError;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  ///[listItemView] set custom view for each groupMember
  final Widget Function(GroupMember)? listItemView;
}
