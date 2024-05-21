import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:get/get_state_manager/get_state_manager.dart';

///[CometChatGroupsWithMessages] is a component that uses [CometChatGroups] to display a list of groups and allows to access the [CometChatMessages] component for each group
///
/// it list down groups according to different parameter set in order of recent activity and opens message by default on click
///
///Usage
///```dart
///
/// CometChatGroupWithMessages(
///      groupsConfiguration: GroupsConfiguration(),
///      messageConfiguration: MessageConfiguration(),
///      createGroupConfiguration: CreateGroupConfiguration(),
///      joinProtectedGroupConfiguration: JoinProtectedGroupConfiguration()
///      theme: CometChatTheme(palette: Palette(),typography: Typography.fromDefault()),
///  );
/// ```
class CometChatGroupsWithMessages extends StatefulWidget {
  const CometChatGroupsWithMessages({
    super.key,
    this.group,
    this.theme,
    this.groupsConfiguration = const GroupsConfiguration(),
    this.messageConfiguration = const MessageConfiguration(),
    this.joinProtectedGroupConfiguration,
    this.createGroupConfiguration = const CreateGroupConfiguration(),
    this.createGroupIcon,
    this.onCreateGroupIconClick,
  });

  ///[group] if null will return [CometChatGroups] screen else will navigate to [CometChatMessages]
  final Group? group;

  ///[theme] parameter used to pass custom theme to this module
  final CometChatTheme? theme;

  ///[groupsConfiguration] parameter used to set   Group's configuration properties
  final GroupsConfiguration groupsConfiguration;

  ///[messageConfiguration] parameter used to set message's configuration properties
  final MessageConfiguration messageConfiguration;

  ///[joinProtectedGroupConfiguration] sets configuration for [CometChatJoinProtectedGroup]
  final JoinProtectedGroupConfiguration? joinProtectedGroupConfiguration;

  ///[createGroupConfiguration] set properties for create group screen
  final CreateGroupConfiguration createGroupConfiguration;

  ///[createGroupIcon] create group icon
  final Widget? createGroupIcon;

  ///[onCreateGroupIconClick] on create group icon click
  final Function(BuildContext context)? onCreateGroupIconClick;

  @override
  State<CometChatGroupsWithMessages> createState() =>
      _CometChatGroupsWithMessagesState();
}

class _CometChatGroupsWithMessagesState
    extends State<CometChatGroupsWithMessages> {
  late CometChatGroupsWithMessagesController
      _cometChatGroupsWithMessagesController;
  late CometChatTheme theme;

  @override
  void initState() {
    super.initState();
    theme = widget.theme ?? cometChatTheme;

    _cometChatGroupsWithMessagesController =
        CometChatGroupsWithMessagesController(
            messageConfiguration: widget.messageConfiguration,
            joinProtectedGroupConfiguration:
                widget.joinProtectedGroupConfiguration,
            theme: theme,
            createGroupConfiguration: widget.createGroupConfiguration);
    if (widget.group != null) {
      if (widget.group?.hasJoined == true) {
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          _cometChatGroupsWithMessagesController.navigateToMessagesScreen(
              group: widget.group!, context: context);
        });
      } else if (widget.group?.type == GroupTypeConstants.password) {
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          _cometChatGroupsWithMessagesController
              .navigateToJoinProtectedGroupScreen(
                  group: widget.group!, context: context);
        });
      }
    }
  }

  @override
  void dispose() {
    _cometChatGroupsWithMessagesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder(
        init: _cometChatGroupsWithMessagesController,
        global: false,
        dispose:
            (GetBuilderState<CometChatGroupsWithMessagesController> state) =>
                state.controller?.onClose(),
        builder: (CometChatGroupsWithMessagesController
            groupsWithMessagesController) {
          groupsWithMessagesController.context = context;
          return CometChatGroups(
            groupsRequestBuilder:
                widget.groupsConfiguration.groupsRequestBuilder,
            theme: widget.groupsConfiguration.theme ?? theme,
            title: widget.groupsConfiguration.title,
            showBackButton: widget.groupsConfiguration.showBackButton ?? true,
            hideSearch: widget.groupsConfiguration.hideSearch ?? false,
            searchPlaceholder: widget.groupsConfiguration.searchPlaceholder,
            emptyStateText: widget.groupsConfiguration.emptyStateText,
            emptyStateView: widget.groupsConfiguration.emptyStateView,
            errorStateText: widget.groupsConfiguration.errorStateText,
            errorStateView: widget.groupsConfiguration.errorStateView,
            hideSeparator: widget.groupsConfiguration.hideSeparator ?? false,
            avatarStyle: widget.groupsConfiguration.avatarStyle,
            backButton: widget.groupsConfiguration.backButton,
            listItemStyle: widget.groupsConfiguration.listItemStyle,
            listItemView: widget.groupsConfiguration.listItemView,
            loadingStateView: widget.groupsConfiguration.loadingStateView,
            onSelection: widget.groupsConfiguration.onSelection,
            options: widget.groupsConfiguration.options,
            passwordGroupIcon: widget.groupsConfiguration.passwordGroupIcon,
            privateGroupIcon: widget.groupsConfiguration.privateGroupIcon,
            searchBoxIcon: widget.groupsConfiguration.searchBoxIcon,
            selectionMode: widget.groupsConfiguration.selectionMode,
            statusIndicatorStyle:
                widget.groupsConfiguration.statusIndicatorStyle,
            subtitleView: widget.groupsConfiguration.subtitleView,
            groupsStyle:
                widget.groupsConfiguration.groupsStyle ?? const GroupsStyle(),
            activateSelection: widget.groupsConfiguration.activateSelection,
            appBarOptions: widget.groupsConfiguration.appBarOptions ??
                (context) {
                  return [
                    IconButton(
                      onPressed: () {
                        if (widget.onCreateGroupIconClick != null) {
                          widget.onCreateGroupIconClick!(context);
                        } else {
                          groupsWithMessagesController.navigateCreateGroup();
                        }
                      },
                      icon: widget.createGroupIcon ??
                          Image.asset(
                            AssetConstants.write,
                            package: UIConstants.packageName,
                            color: theme.palette.getPrimary(),
                          ),
                    )
                  ];
                },
            controller: widget.groupsConfiguration.controller,
            groupsProtocol: widget.groupsConfiguration.groupsProtocol,
            hideError: widget.groupsConfiguration.hideError,
            stateCallBack: widget.groupsConfiguration.stateCallBack,
            onItemTap: widget.groupsConfiguration.onItemTap ??
                groupsWithMessagesController.onItemTap,
            onItemLongPress: widget.groupsConfiguration.onItemLongPress,
            onBack: widget.groupsConfiguration.onBack,
            onError: widget.groupsConfiguration.onError,
            selectionIcon: widget.groupsConfiguration.selectionIcon,
            submitIcon: widget.groupsConfiguration.submitIcon,
            hideAppbar: widget.groupsConfiguration.hideAppbar,
          );
        });
  }
}
