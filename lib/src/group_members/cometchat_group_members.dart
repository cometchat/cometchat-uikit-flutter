import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../cometchat_chat_uikit.dart';
import '../../../cometchat_chat_uikit.dart' as cc;

///[CometChatGroupMembers] is a component that displays all the members of a [Group] in the form of a list with the help of [CometChatListBase] and [CometChatListItem]
///fetched  are listed down alphabetically and in order of recent activity
///group members are fetched using [GroupMembersBuilderProtocol] and [GroupMembersRequestBuilder]
///
/// ```dart
///   CometChatGroupMembers(
///    group: Group(guid: 'guid', name: 'name', type: 'public'),
///    groupMemberStyle: GroupMembersStyle(),
///    groupScopeStyle: GroupScopeStyle(),
///  );
/// ```
///
class CometChatGroupMembers extends StatelessWidget {
  CometChatGroupMembers(
      {Key? key,
      this.groupMembersProtocol,
      this.subtitleView,
      this.hideSeparator,
      this.listItemView,
      this.groupMemberStyle = const GroupMembersStyle(),
      this.controller,
      this.theme,
      this.searchPlaceholder,
      this.backButton,
      this.showBackButton = true,
      this.searchBoxIcon,
      this.hideSearch = false,
      this.selectionMode,
      this.onSelection,
      this.title,
      this.errorStateText,
      this.emptyStateText,
      this.stateCallBack,
      this.groupMembersRequestBuilder,
      this.hideError,
      this.loadingStateView,
      this.emptyStateView,
      this.errorStateView,
      this.listItemStyle,
      this.avatarStyle,
      this.statusIndicatorStyle,
      this.appBarOptions,
      this.options,
      required this.group,
      this.groupScopeStyle,
      this.tailView,
      this.selectIcon,
      this.submitIcon,
      this.disableUsersPresence = false,
      this.onError,
      this.onBack,
      this.onItemTap,
      this.onItemLongPress,
      this.activateSelection})
      : super(key: key);

  ///property to be set internally by using passed parameters [groupMembersProtocol] ,[selectionMode] ,[options]
  ///these are passed to the [CometChatGroupMembersController] which is responsible for the business logic

  ///[groupMembersProtocol] set custom request builder protocol
  final GroupMembersBuilderProtocol? groupMembersProtocol;

  ///[groupMembersRequestBuilder] set custom request builder
  final GroupMembersRequestBuilder? groupMembersRequestBuilder;

  ///[subtitleView] to set subtitle for each groupMember
  final Widget? Function(BuildContext, GroupMember)? subtitleView;

  ///[hideSeparator] toggle visibility of separator
  final bool? hideSeparator;

  ///[listItemView] set custom view for each groupMember
  final Widget Function(GroupMember)? listItemView;

  ///[groupMemberStyle] sets style
  final GroupMembersStyle groupMemberStyle;

  ///[controller] sets controller for the list
  final ScrollController? controller;

  ///[options]  set options which will be visible at slide of each groupMember
  final List<CometChatOption>? Function(
      Group group,
      GroupMember member,
      CometChatGroupMembersController controller,
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

  ///[selectionMode] specifies mode groupMembers module is opening in
  final SelectionMode? selectionMode;

  ///[onSelection] function will be performed
  final Function(List<GroupMember>?)? onSelection;

  ///[title] sets title for the list
  final String? title;

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

  ///[hideError] toggle visibility of error dialog
  final bool? hideError;

  ///[stateCallBack] to access controller functions  from parent pass empty reference of  CometChatGroupMembersController object
  final Function(CometChatGroupMembersController controller)? stateCallBack;

  ///[listItemStyle] style for every list item
  final ListItemStyle? listItemStyle;

  ///[avatarStyle] set style for avatar
  final AvatarStyle? avatarStyle;

  ///[statusIndicatorStyle] set style for status indicator
  final StatusIndicatorStyle? statusIndicatorStyle;

  ///[appBarOptions] list of options to be visible in app bar
  final List<Widget>? appBarOptions;

  ///object to passed across to fetch members of
  final Group group;

  ///[groupScopeStyle] styling properties for group scope which is displayed on tail of every list item
  final GroupScopeStyle? groupScopeStyle;

  ///[tailView] a custom widget for the tail section of the group member list item
  final Function(BuildContext, GroupMember)? tailView;

  ///[submitIcon] will override the default selection complete icon
  final Widget? submitIcon;

  ///[selectIcon] will override the default selection icon
  final Widget? selectIcon;

  ///[disableUsersPresence] controls visibility of user online status indicator
  final bool disableUsersPresence;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  ///[onItemTap] callback triggered on tapping a user item
  final Function(GroupMember)? onItemTap;

  ///[onItemLongPress] callback triggered on pressing for long on a user item
  final Function(GroupMember)? onItemLongPress;

  ///[activateSelection] lets the widget know if groups are allowed to be selected
  final ActivateSelection? activateSelection;

  ///[onError] in case any error occurs
  final OnError? onError;

  final RxBool _isSelectionOn = false.obs;

  Widget getDefaultItem(
      GroupMember member,
      CometChatGroupMembersController controller,
      CometChatTheme theme,
      BuildContext context) {
    Widget? subtitle;
    Widget? tail;
    Color? backgroundColor;
    Widget? icon;

    if (subtitleView != null) {
      subtitle = subtitleView!(context, member);
    }

    if (tailView != null) {
      tail = tailView!(context, member);
    } else {
      tail = _getTail(member, theme, controller);
    }

    StatusIndicatorUtils statusIndicatorUtils =
        StatusIndicatorUtils.getStatusIndicatorFromParams(
      isSelected: controller.selectionMap[member.uid] != null,
      theme: theme,
      groupMember: member,
      onlineStatusIndicatorColor:
          groupMemberStyle.onlineStatusColor ?? theme.palette.getSuccess(),
      disableUsersPresence: disableUsersPresence,
      selectIcon: selectIcon,
    );

    backgroundColor = statusIndicatorUtils.statusIndicatorColor;
    icon = statusIndicatorUtils.icon;

    return GestureDetector(
      onLongPress: () {
        if (activateSelection == ActivateSelection.onLongClick &&
            controller.selectionMap.isEmpty &&
            !(selectionMode == null || selectionMode == SelectionMode.none)) {
          controller.onTap(member);

          _isSelectionOn.value = true;
        } else if (onItemLongPress != null) {
          onItemLongPress!(member);
        }
      },
      onTap: () {
        if (activateSelection == ActivateSelection.onClick ||
            (activateSelection == ActivateSelection.onLongClick &&
                    controller.selectionMap.isNotEmpty) &&
                !(selectionMode == null ||
                    selectionMode == SelectionMode.none)) {
          controller.onTap(member);
          if (controller.selectionMap.isEmpty) {
            _isSelectionOn.value = false;
          } else if (activateSelection == ActivateSelection.onClick &&
              controller.selectionMap.isNotEmpty &&
              _isSelectionOn.value == false) {
            _isSelectionOn.value = true;
          }
        } else if (onItemTap != null) {
          onItemTap!(member);
        }
      },
      child: CometChatListItem(
          id: member.uid,
          avatarName: member.name,
          avatarURL: member.avatar,
          title: member.name,
          key: UniqueKey(),
          subtitleView: subtitle,
          tailView: tail,
          avatarStyle: avatarStyle ?? const AvatarStyle(),
          statusIndicatorColor: backgroundColor,
          statusIndicatorIcon: icon,
          statusIndicatorStyle:
              statusIndicatorStyle ?? const StatusIndicatorStyle(),
          theme: theme,
          hideSeparator: hideSeparator ?? false,
          options: options != null
              ? options!(group, member, controller, context)
              : controller.defaultFunction(group, member),
          style: listItemStyle ??
              ListItemStyle(
                titleStyle: TextStyle(
                    fontSize: theme.typography.name.fontSize,
                    fontWeight: theme.typography.name.fontWeight,
                    fontFamily: theme.typography.name.fontFamily,
                    color: theme.palette.getAccent()),
              )),
    );
  }

  Widget getListItem(
      GroupMember member,
      CometChatGroupMembersController controller,
      CometChatTheme theme,
      BuildContext context) {
    if (listItemView != null) {
      return listItemView!(member);
    } else {
      return getDefaultItem(member, controller, theme, context);
    }
  }

  Widget _getLoadingIndicator(BuildContext context, CometChatTheme theme) {
    if (loadingStateView != null) {
      return Center(child: loadingStateView!(context));
    } else {
      return Center(
        child: Image.asset(
          AssetConstants.spinner,
          package: UIConstants.packageName,
          color:
              groupMemberStyle.loadingIconTint ?? theme.palette.getAccent600(),
        ),
      );
    }
  }

  Widget _getNoGroupMemberIndicator(
      BuildContext context, CometChatTheme theme) {
    if (emptyStateView != null) {
      return Center(child: emptyStateView!(context));
    } else {
      return Center(
        child: Text(
          emptyStateText ?? cc.Translations.of(context).no_groups_found,
          style: groupMemberStyle.emptyTextStyle ??
              TextStyle(
                  fontSize: theme.typography.title1.fontSize,
                  fontWeight: theme.typography.title1.fontWeight,
                  color: theme.palette.getAccent400()),
        ),
      );
    }
  }

  _showErrorDialog(String errorText, BuildContext context, CometChatTheme theme,
      CometChatGroupMembersController controller) {
    showCometChatConfirmDialog(
        context: context,
        messageText: Text(
          errorStateText ?? errorText,
          style: groupMemberStyle.errorTextStyle ??
              TextStyle(
                  fontSize: theme.typography.title2.fontSize,
                  fontWeight: theme.typography.title2.fontWeight,
                  color: theme.palette.getAccent(),
                  fontFamily: theme.typography.title2.fontFamily),
        ),
        confirmButtonText: cc.Translations.of(context).try_again,
        cancelButtonText: cc.Translations.of(context).cancel_capital,
        style: ConfirmDialogStyle(
            backgroundColor: theme.palette.mode == PaletteThemeModes.light
                ? theme.palette.getBackground()
                : Color.alphaBlend(theme.palette.getAccent200(),
                    theme.palette.getBackground()),
            shadowColor: theme.palette.getAccent300(),
            confirmButtonTextStyle: TextStyle(
                fontSize: theme.typography.text2.fontSize,
                fontWeight: theme.typography.text2.fontWeight,
                color: theme.palette.getPrimary()),
            cancelButtonTextStyle: TextStyle(
                fontSize: theme.typography.text2.fontSize,
                fontWeight: theme.typography.text2.fontWeight,
                color: theme.palette.getPrimary())),
        onCancel: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        onConfirm: () {
          Navigator.pop(context);
          controller.loadMoreElements();
        });
  }

  _showError(CometChatGroupMembersController controller, BuildContext context,
      CometChatTheme theme) {
    if (hideError == true) return;
    String error;
    if (controller.error != null && controller.error is CometChatException) {
      error = Utils.getErrorTranslatedText(
          context, (controller.error as CometChatException).code);
    } else {
      error = cc.Translations.of(context).cant_load_chats;
    }
    if (errorStateView != null) {}
    _showErrorDialog(error, context, theme, controller);
  }

  Widget _getList(CometChatGroupMembersController _controller,
      BuildContext context, CometChatTheme _theme) {
    return Padding(
      padding: groupMemberStyle.listPadding ?? const EdgeInsets.only(top: 8),
      child: GetBuilder(
        init: _controller,
        global: false,
        dispose: (GetBuilderState<CometChatGroupMembersController> state) =>
            state.controller?.onClose(),
        builder: (CometChatGroupMembersController value) {
          if (value.hasError == true) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => _showError(value, context, _theme));

            if (errorStateView != null) {
              return errorStateView!(context);
            }

            return _getLoadingIndicator(context, _theme);
          } else if (value.isLoading == true && (value.list.isEmpty)) {
            return _getLoadingIndicator(context, _theme);
          } else if (value.list.isEmpty) {
            //----------- empty list widget-----------
            return _getNoGroupMemberIndicator(context, _theme);
          } else {
            return ListView.builder(
              controller: controller,
              itemCount: value.hasMoreItems
                  ? value.list.length + 1
                  : value.list.length,
              itemBuilder: (context, index) {
                if (index >= value.list.length) {
                  value.loadMoreElements();
                  return _getLoadingIndicator(context, _theme);
                }

                return Column(
                  children: [
                    getListItem(value.list[index], value, _theme, context),
                  ],
                );
              },
            );
          }
        },
      ),
    );
  }

  Widget _getTail(GroupMember groupMember, CometChatTheme theme,
      CometChatGroupMembersController controller) {
    if (groupMember.uid == controller.group.owner) {
      return Text(GroupMemberScope.owner,
          style: groupScopeStyle?.scopeTextStyle ??
              TextStyle(
                  fontSize: cometChatTheme.typography.body.fontSize,
                  fontWeight: cometChatTheme.typography.body.fontWeight,
                  color: cometChatTheme.palette.getAccent700()));
    } else {
      return CometChatGroupScope(
        group: group,
        member: groupMember,
        onCLick: controller.changeScope,
        loggedInUserId: controller.loggedInUser?.uid,
        groupScopeStyle: groupScopeStyle ??
            GroupScopeStyle(
                backgroundColor: groupScopeStyle?.background,
                height: groupScopeStyle?.height,
                width: groupScopeStyle?.width,
                border: groupScopeStyle?.border,
                borderRadius: groupScopeStyle?.borderRadius,
                dropDownItemStyle: groupScopeStyle?.dropDownItemStyle,
                selectedItemTextStyle: groupScopeStyle?.selectedItemTextStyle,
                scopeTextStyle: groupScopeStyle?.scopeTextStyle ??
                    TextStyle(
                        fontSize: theme.typography.body.fontSize,
                        fontWeight: theme.typography.body.fontWeight,
                        color: theme.palette.getAccent500())),
      );
    }
  }

  Widget getSelectionWidget(
      CometChatGroupMembersController memberController, CometChatTheme theme) {
    if (_isSelectionOn.value) {
      return IconButton(
          onPressed: () {
            List<GroupMember>? member = memberController.getSelectedList();
            if (onSelection != null) {
              onSelection!(member);
            }
          },
          icon: submitIcon ??
              Image.asset(AssetConstants.checkmark,
                  package: UIConstants.packageName,
                  color: theme.palette.getPrimary()));
    } else {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    CometChatTheme _theme = theme ?? cometChatTheme;

    CometChatGroupMembersController groupMembersController =
        CometChatGroupMembersController(
            groupMembersBuilderProtocol: groupMembersProtocol ??
                UIGroupMembersBuilder(
                  groupMembersRequestBuilder ??
                      GroupMembersRequestBuilder(group.guid),
                ),
            mode: selectionMode,
            //options: options,

            group: group,
            theme: _theme,
            onError: onError);

    if (stateCallBack != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => stateCallBack!(groupMembersController));
    }

    return CometChatListBase(
        title: title ?? cc.Translations.of(context).members,
        hideSearch: hideSearch,
        backIcon: backButton,
        onBack: onBack,
        placeholder: searchPlaceholder,
        showBackButton: showBackButton,
        searchBoxIcon: searchBoxIcon,
        onSearch: groupMembersController.onSearch,
        theme: _theme,
        menuOptions: [
          if (appBarOptions != null && appBarOptions!.isNotEmpty)
            ...appBarOptions!,
          Obx(() => getSelectionWidget(groupMembersController, _theme))
        ],
        style: ListBaseStyle(
            background: groupMemberStyle.gradient == null
                ? groupMemberStyle.background
                : Colors.transparent,
            titleStyle: groupMemberStyle.titleStyle,
            gradient: groupMemberStyle.gradient,
            height: groupMemberStyle.height,
            width: groupMemberStyle.width,
            backIconTint: groupMemberStyle.backIconTint,
            searchIconTint: groupMemberStyle.searchIconTint,
            border: groupMemberStyle.border,
            borderRadius: groupMemberStyle.borderRadius,
            searchTextStyle: groupMemberStyle.searchTextStyle,
            searchPlaceholderStyle: groupMemberStyle.searchPlaceholderStyle,
            searchBorderColor: groupMemberStyle.searchBorderColor,
            searchBoxRadius: groupMemberStyle.searchBorderRadius,
            searchBoxBackground: groupMemberStyle.searchBackground,
            searchBorderWidth: groupMemberStyle.searchBorderWidth),
        container: _getList(groupMembersController, context, _theme));
  }
}
