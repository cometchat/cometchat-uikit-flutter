import 'package:flutter/material.dart';

import '../../flutter_chat_ui_kit.dart';

class GroupsWithMessagesConfiguration {
  const GroupsWithMessagesConfiguration({
    this.theme,
    this.groupsConfiguration,
    this.messageConfiguration,
    this.createGroupConfiguration,
    this.createGroupIcon,
    this.onCreateGroupIconClick,
    this.hideCreateGroup = false,
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

  ///[hideCreateGroup] switch on/off option to create group
  final bool hideCreateGroup;
}
