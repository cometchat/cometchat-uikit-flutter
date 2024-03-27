import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as cc;

///[CometChatContacts] is a component that displays a list of users and groups with the help of [CometChatListBase] and [CometChatListItem]
///fetched users and groups  are listed down alphabetically and in order of recent activity
///users are fetched using [UsersBuilderProtocol] and [UsersRequestBuilder]
///groups are fetched using [GroupsBuilderProtocol] and [GroupsRequestBuilder]
///
///
/// ```dart
///   CometChatContacts(
///   contactsStyle: ContactsStyle(),
/// );
/// ```
///

class CometChatContacts extends StatefulWidget {
  const CometChatContacts(
      {Key? key,
      this.usersConfiguration,
      this.onItemTap,
      this.groupsConfiguration,
      this.usersTabTitle,
      this.groupsTabTitle,
      this.theme,
      this.title,
      this.closeIcon,
      this.contactsStyle = const ContactsStyle(),
      this.onClose,
      this.onSubmitIconTap,
      this.tabVisibility = TabVisibility.usersAndGroups,
      this.hideSubmitIcon,
      this.selectionLimit = 5,
      this.selectionMode,
      this.submitIcon,
      this.snackBarConfiguration})
      : super(key: key);

  ///[usersConfiguration] set custom users request builder protocol
  final UsersConfiguration? usersConfiguration;

  ///[onItemTap] callback triggered on tapping a user or group item
  final UserGroupBuilder? onItemTap;

  ///[GroupConfiguration] custom request groups request builder protocol
  final GroupsConfiguration? groupsConfiguration;

  ///[usersTabTitle] title text of user tab
  final String? usersTabTitle;

  ///[groupsTabTitle] title text of group tab
  final String? groupsTabTitle;

  ///[title] sets title for the list
  final String? title;

  ///[closeIcon] close icon widget
  final Widget? closeIcon;

  ///[contactsStyle] sets style
  final ContactsStyle contactsStyle;

  ///[onClose] call function to be called on close button click
  final VoidCallback? onClose;

  ///[theme] set custom theme
  final CometChatTheme? theme;

  ///[onSubmitIconTap] triggered when clicked on submit icon
  final Function(BuildContext context, List<User>? selectedUsersList,
      List<Group>? selectedGroupsList)? onSubmitIconTap;

  ///[tabVisibility] parameter to alter visibility of different tabs
  final TabVisibility tabVisibility;

  ///[submitIcon] triggered when clicked on submit icon
  final Widget? submitIcon;

  ///[selectionLimit] set the limit for maximum selection limit, default limit is 5
  final int? selectionLimit;

  ///[hideSubmitIcon] triggered visibility of selection icon
  final bool? hideSubmitIcon;

  ///[SelectionMode] sets the selection mode
  final SelectionMode? selectionMode;

  ///[snackBarConfiguration] sets configuration properties for showing snackBar
  final SnackBarConfiguration? snackBarConfiguration;

  @override
  State<CometChatContacts> createState() => _CometChatContactsState();
}

class _CometChatContactsState extends State<CometChatContacts>
    with SingleTickerProviderStateMixin {
  late CometChatContactsController cometChatStartConversationController;
  late CometChatTheme theme;

  @override
  void initState() {
    theme = widget.theme ?? cometChatTheme;
    cometChatStartConversationController = CometChatContactsController(
        onItemTap: widget.onItemTap,
        usersConfiguration: widget.usersConfiguration,
        groupsConfiguration: widget.groupsConfiguration,
        selectionMode: widget.selectionMode ?? SelectionMode.none,
        tabVisibility: widget.tabVisibility);
    cometChatStartConversationController.tabController = TabController(
        length: widget.tabVisibility == TabVisibility.usersAndGroups ? 2 : 1,
        vsync: this);
    cometChatStartConversationController.tabController.addListener(
        cometChatStartConversationController.tabControllerListener);
    super.initState();
  }

  @override
  void dispose() {
    cometChatStartConversationController.dispose();
    super.dispose();
  }

  Widget getSelectionWidget(CometChatTheme theme,
      CometChatContactsController controller, BuildContext context) {
    return IconButton(
        onPressed: () {
          List<Group>? groups;
          List<User>? users;

          users = controller.getUserController()?.getSelectedList();

          groups = controller.getGroupsController()?.getSelectedList();

          int total = 0;

          if (users != null) {
            total += users.length;
          }

          if (groups != null) {
            total += groups.length;
          }

          int selectionLimit = widget.selectionLimit ?? 5;
          if (total > selectionLimit) {
            SnackBarUtils.show(
                "${cc.Translations.of(context).max_selection_limit_is} $selectionLimit",
                context);
            return;
          }

          if (widget.onSubmitIconTap != null) {
            widget.onSubmitIconTap!(context, users, groups);
          }
        },
        icon: widget.submitIcon ??
            Image.asset(AssetConstants.checkmark,
                package: UIConstants.packageName,
                color: theme.palette.getPrimary()));
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder(
        init: cometChatStartConversationController,
        builder: (CometChatContactsController value) {
          value.context = context;
          return CometChatListBase(
            title: widget.title ?? cc.Translations.of(context).new_message,
            theme: theme,
            backIcon: widget.closeIcon ??
                Image.asset(
                  AssetConstants.close,
                  package: UIConstants.packageName,
                  color: theme.palette.getPrimary(),
                ),
            showBackButton: true,
            onBack: () {
              Navigator.pop(context);
            },
            hideSearch: true,
            menuOptions: [
              if (widget.hideSubmitIcon != true)
                getSelectionWidget(theme, value, context),
            ],
            container: Column(
              children: [
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.palette.getAccent100(),
                    borderRadius: BorderRadius.circular(
                      18.0,
                    ),
                  ),
                  child: TabBar(
                    controller: value.tabController,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        18.0,
                      ),
                      color: widget.contactsStyle.selectedTabColor ??
                          theme.palette.getPrimary(),
                    ),
                    labelColor:
                        widget.contactsStyle.selectedTabTextStyle?.color ??
                            theme.palette.getBackground(),
                    unselectedLabelColor:
                        widget.contactsStyle.tabTextStyle?.color ??
                            theme.palette.getAccent600(),
                    labelStyle: TextStyle(
                      color: theme.palette.getBackground(),
                      fontSize: theme.typography.text1.fontSize,
                      fontFamily: theme.typography.text1.fontFamily,
                      fontWeight: theme.typography.text1.fontWeight,
                    ).merge(widget.contactsStyle.selectedTabTextStyle),
                    unselectedLabelStyle: TextStyle(
                      color: theme.palette.getAccent600(),
                      fontSize: theme.typography.text1.fontSize,
                      fontFamily: theme.typography.text1.fontFamily,
                      fontWeight: theme.typography.text1.fontWeight,
                    ).merge(widget.contactsStyle.tabTextStyle),
                    tabs: [
                      if (widget.tabVisibility ==
                              TabVisibility.usersAndGroups ||
                          widget.tabVisibility == TabVisibility.users)
                        Tab(
                          text: widget.usersTabTitle ??
                              cc.Translations.of(context).users,
                        ),
                      if (widget.tabVisibility ==
                              TabVisibility.usersAndGroups ||
                          widget.tabVisibility == TabVisibility.groups)
                        Tab(
                          text: widget.groupsTabTitle ??
                              cc.Translations.of(context).groups,
                        ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Expanded(
                  child: value.currentView[value.tabController.index],
                ),
              ],
            ),
          );
        });
  }
}
