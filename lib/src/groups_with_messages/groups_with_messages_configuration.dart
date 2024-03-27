import 'package:flutter/material.dart';

import '../../cometchat_chat_uikit.dart';

///[GroupsWithMessagesConfiguration] is a data class that has configuration properties
///to customize the functionality and appearance of [CometChatGroupsWithMessages]
///can be used by a component where [CometChatGroupsWithMessages] is a child component
class GroupsWithMessagesConfiguration {
  const GroupsWithMessagesConfiguration({
    this.theme,
    this.groupsConfiguration,
    this.messageConfiguration,
    this.createGroupConfiguration,
    this.createGroupIcon,
    this.onCreateGroupIconClick,
  });

  ///[theme] parameter used to pass custom theme to this module
  final CometChatTheme? theme;

  ///[groupsConfiguration] parameter used to set   Group's configuration properties
  final GroupsConfiguration? groupsConfiguration;

  ///[messageConfiguration] parameter used to set message's configuration properties
  final MessageConfiguration? messageConfiguration;

  ///[createGroupConfiguration] sets configurations for [CometChatCreateGroup]
  final CreateGroupConfiguration? createGroupConfiguration;

  ///[createGroupIcon] create group icon
  final Widget? createGroupIcon;

  ///[onCreateGroupIconClick] on click parameter
  final Function(BuildContext context)? onCreateGroupIconClick;
}
