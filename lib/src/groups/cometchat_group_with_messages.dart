import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

/// A container component that wraps and formats the [CometChatGroups] and [CometChatMessages] component
///
/// it list down groups according to different parameter set in order of recent activity and opens message by default on click
///
///Usage
///```dart
///import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart' as fl;
/// CometChatGroupWithMessages(
///      groupsConfiguration: GroupsConfiguration(),
///      messageConfiguration: MessageConfiguration(),
///      theme: CometChatTheme(palette: Palette(),typography: fl.Typography.fromDefault()),
///             );
/// ```
class CometChatGroupWithMessages extends StatefulWidget {
  const CometChatGroupWithMessages(
      {Key? key,
      this.theme,
      this.groupsConfiguration = const GroupsConfiguration(),
      this.messageConfiguration = const MessageConfiguration()})
      : super(key: key);

  ///[theme] parameter used to pass custom theme to this module
  final CometChatTheme? theme;

  ///[groupsConfiguration] parameter used to set   Group's configuration properties
  final GroupsConfiguration groupsConfiguration;

  ///[messageConfiguration] parameter used to set message's configuration properties
  final MessageConfiguration messageConfiguration;

  @override
  State<CometChatGroupWithMessages> createState() =>
      _CometChatGroupWithMessagesState();
}

class _CometChatGroupWithMessagesState extends State<CometChatGroupWithMessages>
    with CometChatGroupEventListener {
  @override
  void initState() {
    super.initState();
    CometChatGroupEvents.addGroupsListener(
        "cometchat_groups_with_messages_group_listener", this);
  }

  @override
  void dispose() {
    super.dispose();
    CometChatGroupEvents.removeGroupsListener(
        "cometchat_groups_with_messages_group_listener");
  }

  @override
  void onGroupTap(Group group, int index) {
    if (group.hasJoined) {
      _openMessageScreen(group);
    }
  }

  @override
  void onGroupMemberJoin(User joinedUser, Group joinedGroup) {
    _openMessageScreen(joinedGroup);
  }

  _openMessageScreen(Group group) {
    _openCometChatMessages(group);
  }

  @override
  void onGroupCreate(Group group) {
    _openCometChatMessages(group);
  }

  _openCometChatMessages(Group group) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CometChatMessages(
                  group: group.guid,
                  theme: widget.theme,
                  enableTypingIndicator:
                      widget.messageConfiguration.enableTypingIndicator,
                  enableSoundForMessages:
                      widget.messageConfiguration.enableSoundForMessages,
                  hideMessageComposer:
                      widget.messageConfiguration.hideMessageComposer,
                  messageHeaderConfiguration:
                      widget.messageConfiguration.messageHeaderConfiguration,
                  messageListConfiguration:
                      widget.messageConfiguration.messageListConfiguration,
                  messageComposerConfiguration:
                      widget.messageConfiguration.messageComposerConfiguration,
                )));
  }

  @override
  Widget build(BuildContext context) {
    return CometChatGroups(
      theme: widget.theme,
      title: widget.groupsConfiguration.title,
      showBackButton: widget.groupsConfiguration.showBackButton,
      hideSearch: widget.groupsConfiguration.hideSearch,
      searchPlaceholder: widget.groupsConfiguration.searchPlaceholder,
      activeGroup: widget.groupsConfiguration.activeGroup,
      groupListConfiguration: widget.groupsConfiguration.groupListConfiguration,
      hideCreateGroup: widget.groupsConfiguration.hideCreateGroup,
    );
  }
}
