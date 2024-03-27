import 'package:flutter/material.dart';

import '../../cometchat_chat_uikit.dart';

///[MessageHeaderConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [CometChatMessageHeader]
///can be used by a component where [CometChatMessageHeader] is a child component
class MessageHeaderConfiguration {
  const MessageHeaderConfiguration(
      {this.backButton,
      this.subtitleView,
      this.listItemView,
      this.disableUserPresence,
      this.protectedGroupIcon,
      this.privateGroupIcon,
      this.messageHeaderStyle,
      this.hideBackButton,
      this.theme,
      this.avatarStyle,
      this.listItemStyle,
      this.statusIndicatorStyle,
      this.appBarOptions,
      this.onBack});

  ///[backButton]  to set back button widget
  final WidgetBuilder? backButton;

  ///[subtitleView] to set custom subtitle view
  final Widget? Function(Group? group, User? user, BuildContext context)?
      subtitleView;

  ///[listItemView] to set custom list item view
  final Widget Function(Group? group, User? user, BuildContext context)?
      listItemView;

  ///[disableUserPresence] to toggle functionality to show user's presence
  final bool? disableUserPresence;

  ///[protectedGroupIcon] group icon to be shown for protected groups
  final Widget? protectedGroupIcon;

  ///[privateGroupIcon] group icon to be shown for protected groups
  final Widget? privateGroupIcon;

  ///[MessageHeaderStyle] to set styling properties for [CometChatMessageHeader]
  final MessageHeaderStyle? messageHeaderStyle;

  ///[hideBackButton] toggle visibility for back button, default false
  final bool? hideBackButton;

  ///[theme] set custom theme
  final CometChatTheme? theme;

  ///[avatarStyle] set style for [CometChatAvatar]
  final AvatarStyle? avatarStyle;

  ///[listItemStyle] set style for [CometChatListItem]
  final ListItemStyle? listItemStyle;

  ///[statusIndicatorStyle] set style for status indicator
  final StatusIndicatorStyle? statusIndicatorStyle;

  ///[appBarOptions] gives the tail view in [CometChatMessageHeader]
  final List<Widget>? Function(User? user, Group? group, BuildContext context)?
      appBarOptions;

  ///[onBack] callback triggered on back button click
  final VoidCallback? onBack;
}
