import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../../cometchat_chat_uikit.dart';

///[CometChatUsersController] is the view model for [CometChatUsers]
class CometChatContactsController extends GetxController {
  //--------------------Constructor-----------------------
  CometChatContactsController(
      {this.onItemTap,
      this.usersConfiguration,
      this.groupsConfiguration,
      this.theme,
      this.selectionMode = SelectionMode.none,
      this.tabVisibility = TabVisibility.usersAndGroups})
      : super();

  //-------------------------Variable Declaration-----------------------------

  int index = 0;
  late List<Widget> currentView;
  final UsersConfiguration? usersConfiguration;
  final GroupsConfiguration? groupsConfiguration;
  final UserGroupBuilder? onItemTap;
  late TabController tabController;
  String tabType = CometChatStartConversationType.user;
  final CometChatTheme? theme;
  late BuildContext context;
  SelectionMode selectionMode;
  final TabVisibility tabVisibility;
  String? dateTime;
  CometChatUsersController? _usersController;
  CometChatGroupsController? _groupsController;

  setUsersController(CometChatUsersController controller) {
    _usersController = controller;
  }

  setGroupsController(CometChatGroupsController controller) {
    _groupsController = controller;
  }

  CometChatUsersController? getUserController() {
    try {
      _usersController ??= Get.find<CometChatUsersController>(tag: dateTime);
    } catch (_) {}

    return _usersController;
  }

  CometChatGroupsController? getGroupsController() {
    try {
      _groupsController ??= Get.find<CometChatGroupsController>(tag: dateTime);
    } catch (_) {}
    return _groupsController;
  }

  _onItemTap(BuildContext context, User? user, Group? group) {
    if (onItemTap != null) {
      onItemTap!(context, user, group);
    }
  }

  onItemTapUser(BuildContext context, User? user) {
    _onItemTap(context, user, null);
  }

  onItemTapGroup(BuildContext context, Group? group) {
    _onItemTap(context, null, group);
  }

  //-------------------------LifeCycle Methods-----------------------------
  @override
  void onInit() {
    dateTime = DateTime.now().microsecondsSinceEpoch.toString();
    // dateTime2 = DateTime.now().microsecondsSinceEpoch.toString()+"group";
    currentView = [
      if (tabVisibility == TabVisibility.usersAndGroups ||
          tabVisibility == TabVisibility.users)
        CometChatUsers(
          usersRequestBuilder: usersConfiguration?.usersRequestBuilder,
          theme: usersConfiguration?.theme ?? theme,
          showBackButton: false,
          hideSearch: usersConfiguration?.hideSearch ?? false,
          searchPlaceholder: usersConfiguration?.searchPlaceholder,
          activateSelection: usersConfiguration?.activateSelection,
          appBarOptions: usersConfiguration?.appBarOptions,
          controller: usersConfiguration?.controller,
          hideError: usersConfiguration?.hideError,
          stateCallBack: usersConfiguration?.stateCallBack,
          usersProtocol: usersConfiguration?.usersProtocol,
          backButton: usersConfiguration?.backButton,
          disableUsersPresence: usersConfiguration?.disableUsersPresence,
          emptyStateText: usersConfiguration?.emptyStateText,
          emptyStateView: usersConfiguration?.emptyStateView,
          errorStateText: usersConfiguration?.errorStateText,
          errorStateView: usersConfiguration?.errorStateView,
          hideSectionSeparator: usersConfiguration?.hideSectionSeparator,
          hideSeparator: usersConfiguration?.hideSeparator,
          loadingStateView: usersConfiguration?.loadingStateView,
          onSelection: usersConfiguration?.onSelection,
          options: usersConfiguration?.options,
          searchBoxIcon: usersConfiguration?.searchBoxIcon,
          selectionMode: usersConfiguration?.selectionMode ?? selectionMode,
          subtitleView: usersConfiguration?.subtitleView,
          statusIndicatorStyle: usersConfiguration?.statusIndicatorStyle,
          listItemView: usersConfiguration?.listItemView,
          listItemStyle: usersConfiguration?.listItemStyle,
          avatarStyle: usersConfiguration?.avatarStyle,
          usersStyle: usersConfiguration?.usersStyle ?? const UsersStyle(),
          onItemTap: usersConfiguration?.onItemTap ?? onItemTapUser,
          onItemLongPress: usersConfiguration?.onItemLongPress,
          onBack: usersConfiguration?.onBack,
          onError: usersConfiguration?.onError,
          selectionIcon: usersConfiguration?.selectionIcon,
          hideAppbar: true,
          controllerTag: dateTime,
        ),
      if (tabVisibility == TabVisibility.usersAndGroups ||
          tabVisibility == TabVisibility.groups)
        CometChatGroups(
          groupsRequestBuilder: groupsConfiguration?.groupsRequestBuilder,
          theme: groupsConfiguration?.theme ?? theme,
          showBackButton: false,
          hideSearch: groupsConfiguration?.hideSearch ?? false,
          searchPlaceholder: groupsConfiguration?.searchPlaceholder,
          emptyStateText: groupsConfiguration?.emptyStateText,
          emptyStateView: groupsConfiguration?.emptyStateView,
          errorStateText: groupsConfiguration?.errorStateText,
          errorStateView: groupsConfiguration?.errorStateView,
          hideSeparator: groupsConfiguration?.hideSeparator ?? false,
          avatarStyle: groupsConfiguration?.avatarStyle,
          backButton: groupsConfiguration?.backButton,
          listItemStyle: groupsConfiguration?.listItemStyle,
          listItemView: groupsConfiguration?.listItemView,
          loadingStateView: groupsConfiguration?.loadingStateView,
          onSelection: groupsConfiguration?.onSelection,
          options: groupsConfiguration?.options,
          passwordGroupIcon: groupsConfiguration?.passwordGroupIcon,
          privateGroupIcon: groupsConfiguration?.privateGroupIcon,
          searchBoxIcon: groupsConfiguration?.searchBoxIcon,
          selectionMode: groupsConfiguration?.selectionMode ?? selectionMode,
          statusIndicatorStyle: groupsConfiguration?.statusIndicatorStyle,
          subtitleView: groupsConfiguration?.subtitleView,
          groupsStyle: groupsConfiguration?.groupsStyle ?? const GroupsStyle(),
          activateSelection: groupsConfiguration?.activateSelection,
          appBarOptions: groupsConfiguration?.appBarOptions,
          controller: groupsConfiguration?.controller,
          groupsProtocol: groupsConfiguration?.groupsProtocol,
          hideError: groupsConfiguration?.hideError,
          stateCallBack: groupsConfiguration?.stateCallBack,
          onItemTap: groupsConfiguration?.onItemTap ?? onItemTapGroup,
          onItemLongPress: groupsConfiguration?.onItemLongPress,
          onBack: groupsConfiguration?.onBack,
          onError: groupsConfiguration?.onError,
          hideAppbar: true,
          controllerTag: dateTime,
        ),
    ];
    super.onInit();
  }

  @override
  void dispose() {
    super.dispose();
    tabController.dispose();
    // CometChatUsersController userController = Get.find<CometChatUsersController>(tag: "dateTime");
    // userController.onClose();
    Get.delete<CometChatUsersController>(tag: dateTime);
    Get.delete<CometChatGroupsController>(tag: dateTime);
  }

  // Tab controller listener
  void tabControllerListener() {
    if (tabController.index == 0) {
      tabType = CometChatStartConversationType.user;
    } else if (tabController.index == 1) {
      tabType = CometChatStartConversationType.group;
    }
    update();
  }
}
