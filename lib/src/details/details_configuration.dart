import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class DetailsConfiguration {
  DetailsConfiguration({
    this.title,
    this.showCloseButton,
    this.closeButtonIcon,
    this.disableUsersPresence = false,
    this.appBarOptions,
    this.detailsStyle,
    this.listItemStyle,
    this.avatarStyle,
    this.statusIndicatorStyle,
    this.subtitleView,
    this.hideProfile,
    this.protectedGroupIcon,
    this.privateGroupIcon,
    this.addMemberConfiguration,
    this.transferOwnershipConfiguration,
    this.bannedMemberConfiguration,
    this.viewMemberConfiguration,
    this.stateCallBack,
    this.data,
    this.customProfileView,
    this.theme,
    this.onBack,
    this.onError
  });

  ///to pass [CometChatDetails] header text use [title]
  final String? title;

  ///[showCloseButton] toggles visibility for close button
  final bool? showCloseButton;

  ///to change [closeButtonIcon]
  final Icon? closeButtonIcon;

  ///[disableUsersPresence] controls visibility of status indicator
  final bool disableUsersPresence;

  ///[appBarOptions] list of options to be visible in app bar
  final List<Widget>? appBarOptions;

  ///[detailsStyle] is used to pass styling properties
  final DetailsStyle? detailsStyle;

  ///[listItemStyle] style for every list item
  final ListItemStyle? listItemStyle;

  ///[avatarStyle] set style for avatar
  final AvatarStyle? avatarStyle;

  ///[statusIndicatorStyle] set style for status indicator
  final StatusIndicatorStyle? statusIndicatorStyle;

  ///[subtitleView] to set subtitle for each conversation
  final Widget? Function({User? user, Group? group, BuildContext context})?
      subtitleView;

  ///[hideProfile] hides view profile for users
  final bool? hideProfile;

  ///[protectedGroupIcon] provides icon in status indicator for protected group
  final Widget? protectedGroupIcon;

  ///[privateGroupIcon] provides icon in status indicator for private group
  final Widget? privateGroupIcon;

  ///configurations for opening add members
  final AddMemberConfiguration? addMemberConfiguration;

  ///configurations for opening transfer ownership
  final TransferOwnershipConfiguration? transferOwnershipConfiguration;

  ///configurations for opening transfer ownership
  final BannedMemberConfiguration? bannedMemberConfiguration;

  ///configurations for opening view members
  final GroupMembersConfiguration? viewMemberConfiguration;

  ///[stateCallBack] a call back to give state to its parent
  final void Function(CometChatDetailsController)? stateCallBack;

  ///list of templates is passed to [data] which is used in displaying options
  final List<CometChatDetailsTemplate>? Function(Group? group, User? user)?
      data;

  ///[customProfileView] provides a customized view profile for users
  final Widget? customProfileView;

  ///[theme] custom theme
  final CometChatTheme? theme;

  ///[onError] callback triggered in case any error happens when fetching users
  final OnError? onError;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;
}
