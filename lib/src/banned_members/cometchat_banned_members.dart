import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../cometchat_chat_uikit.dart';
import '../../../cometchat_chat_uikit.dart' as cc;

///[CometChatBannedMembers] is a component that displays members banned from a particular [Group] in a listed form using [CometChatListBase] and [CometChatListItem]
///fetched banned members are listed down according to the sequence they were added to the list initially
///banned members are fetched using [BannedMemberBuilderProtocol] and [BannedGroupMembersRequestBuilder]
///
/// ```dart
///   CometChatBannedMembers(
///   group: Group(guid: 'guid', name: 'name', type: 'public'),
///   bannedMembersStyle: BannedMembersStyle(),
/// );
/// ```
class CometChatBannedMembers extends StatelessWidget {
  CometChatBannedMembers(
      {super.key,
      required this.group,
      this.bannedMemberProtocol,
      this.subtitleView,
      this.hideSeparator = true,
      this.listItemView,
      this.bannedMembersStyle = const BannedMembersStyle(),
      this.options,
      this.controller,
      this.theme,
      this.searchPlaceholder,
      this.backButton,
      this.showBackButton = true,
      this.searchBoxIcon,
      this.hideSearch = true,
      this.selectionMode,
      this.onSelection,
      this.title,
      this.errorStateText,
      this.emptyStateText,
      this.stateCallBack,
      this.bannedMemberRequestBuilder,
      this.hideError,
      this.loadingStateView,
      this.emptyStateView,
      this.errorStateView,
      this.disableUsersPresence = true,
      this.avatarStyle,
      this.statusIndicatorStyle,
      this.appBarOptions,
      this.listItemStyle,
      OnError? onError,
      this.onBack,
      this.onItemTap,
      this.onItemLongPress,
      this.activateSelection,
      String? unbanIconUrl,
      String? unbanIconUrlPackageName})
      : bannedMembersController = CometChatBannedMembersController(
            bannedMemberBuilderProtocol: bannedMemberProtocol ??
                UIBannedMemberBuilder(
                  bannedMemberRequestBuilder ??
                      BannedGroupMembersRequestBuilder(guid: group.guid),
                ),
            mode: selectionMode,
            theme: theme ?? cometChatTheme,
            group: group,
            disableUsersPresence: disableUsersPresence,
            onError: onError,
            unbanIconUrl: unbanIconUrl,
            unbanIconUrlPackageName: unbanIconUrlPackageName);

  ///[group] stores a reference to the group for which banned members will be shown
  final Group group;

  ///[bannedMembersController] contains the business logic
  final CometChatBannedMembersController bannedMembersController;

  ///[bannedMemberProtocol] is a wrapper for request builder
  final BannedMemberBuilderProtocol? bannedMemberProtocol;

  ///[bannedMemberRequestBuilder] set custom request builder
  final BannedGroupMembersRequestBuilder? bannedMemberRequestBuilder;

  ///[subtitleView] to set subtitleView for each banned member
  final Widget? Function(GroupMember)? subtitleView;

  ///[hideSeparator] toggle visibility of separator
  final bool? hideSeparator;

  ///[listItemView] set custom view for each banned member
  final Widget Function(GroupMember)? listItemView;

  ///[bannedMembersStyle] sets bannedMembersStyle
  final BannedMembersStyle bannedMembersStyle;

  ///[controller] sets controller for the list
  final ScrollController? controller;

  ///[options]  set options which will be visible at slide of each banned member
  final List<CometChatOption>? Function(
      Group group,
      GroupMember member,
      CometChatBannedMembersController controller,
      BuildContext context)? options;

  ///[searchPlaceholder] placeholder text of search input
  final String? searchPlaceholder;

  ///[backButton] back button
  final Widget? backButton;

  ///[showBackButton] switch on/off back button
  final bool showBackButton;

  ///[searchBoxIcon] search icon
  final Widget? searchBoxIcon;

  ///[hideSearch] switch on/off search input
  final bool hideSearch;

  ///[theme] can pass custom theme
  final CometChatTheme? theme;

  ///[selectionMode] specifies mode banned members module is opening in
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

  ///[stateCallBack] to access controller functions  from parent pass empty reference of  CometChatBannedMembersController object
  final Function(CometChatBannedMembersController controller)? stateCallBack;

  ///[disableUsersPresence] controls visibility of status indicator
  final bool disableUsersPresence;

  ///[avatarStyle] is applied to the avatar of the user banned from the group
  final AvatarStyle? avatarStyle;

  ///[statusIndicatorStyle] is applied to the online/offline status indicator of the user banned from the group
  final StatusIndicatorStyle? statusIndicatorStyle;

  ///[appBarOptions] list of options to be visible in app bar
  final List<Widget>? appBarOptions;

  ///[listItemStyle] bannedMembersStyle for every list item
  final ListItemStyle? listItemStyle;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  ///[onItemTap] callback triggered on tapping a user item
  final Function(User)? onItemTap;

  ///[onItemLongPress] callback triggered on pressing for long on a user item
  final Function(User)? onItemLongPress;

  ///[activateSelection] lets the widget know if banned members are allowed to be selected
  final ActivateSelection? activateSelection;

  final RxBool _isSelectionOn = false.obs;

  Widget getDefaultItem(
    GroupMember bannedMember,
    CometChatBannedMembersController controller,
    CometChatTheme theme,
    BuildContext context,
  ) {
    Widget? subtitle;
    if (subtitleView != null) {
      subtitle = subtitleView!(bannedMember);
    }

    Color? backgroundColor;
    Widget? icon;

    StatusIndicatorUtils statusIndicatorUtils =
        StatusIndicatorUtils.getStatusIndicatorFromParams(
      isSelected: controller.selectionMap[bannedMember.uid] != null,
      theme: theme,
      groupMember: bannedMember,
      onlineStatusIndicatorColor:
          bannedMembersStyle.onlineStatusColor ?? theme.palette.getSuccess(),
      disableUsersPresence: disableUsersPresence,
    );

    backgroundColor = statusIndicatorUtils.statusIndicatorColor;
    icon = statusIndicatorUtils.icon;

    return GestureDetector(
      onLongPress: () {
        if (activateSelection == ActivateSelection.onLongClick &&
            controller.selectionMap.isEmpty &&
            !(selectionMode == null || selectionMode == SelectionMode.none)) {
          controller.onTap(bannedMember);

          _isSelectionOn.value = true;
        } else if (onItemLongPress != null) {
          onItemLongPress!(bannedMember);
        }
      },
      onTap: () {
        if (activateSelection == ActivateSelection.onClick ||
            (activateSelection == ActivateSelection.onLongClick &&
                    controller.selectionMap.isNotEmpty) &&
                !(selectionMode == null ||
                    selectionMode == SelectionMode.none)) {
          controller.onTap(bannedMember);
          if (controller.selectionMap.isEmpty) {
            _isSelectionOn.value = false;
          } else if (activateSelection == ActivateSelection.onClick &&
              controller.selectionMap.isNotEmpty &&
              _isSelectionOn.value == false) {
            _isSelectionOn.value = true;
          }
        } else if (onItemTap != null) {
          onItemTap!(bannedMember);
        }
      },
      child: CometChatListItem(
        key: UniqueKey(),
        id: bannedMember.uid,
        avatarName: bannedMember.name,
        avatarURL: bannedMember.avatar,
        title: bannedMember.name,
        subtitleView: subtitle,
        statusIndicatorColor:
            disableUsersPresence == false ? backgroundColor : null,
        statusIndicatorIcon: disableUsersPresence == false ? icon : null,
        statusIndicatorStyle:
            statusIndicatorStyle ?? const StatusIndicatorStyle(),
        avatarStyle: avatarStyle ?? const AvatarStyle(),
        tailView: Text(
          cc.Translations.of(context).banned,
          style: bannedMembersStyle.tailTextStyle ??
              TextStyle(
                  fontSize: theme.typography.text1.fontSize,
                  fontWeight: theme.typography.text1.fontWeight,
                  color: theme.palette.getAccent500()),
        ),
        style: ListItemStyle(
            background: listItemStyle?.background ?? Colors.transparent,
            titleStyle: listItemStyle?.titleStyle ??
                TextStyle(
                    fontSize: theme.typography.name.fontSize,
                    fontWeight: theme.typography.name.fontWeight,
                    fontFamily: theme.typography.name.fontFamily,
                    color: theme.palette.getAccent()),
            height: listItemStyle?.height,
            border: listItemStyle?.border,
            borderRadius: listItemStyle?.borderRadius,
            gradient: listItemStyle?.gradient,
            separatorColor: listItemStyle?.separatorColor,
            width: listItemStyle?.width),
        options: options != null
            ? options!(group, bannedMember, controller, context)
            : controller.defaultFunction(group, bannedMember),
      ),
    );
  }

  Widget getListItem(
      GroupMember bannedMember,
      CometChatBannedMembersController controller,
      CometChatTheme theme,
      BuildContext context) {
    if (listItemView != null) {
      return listItemView!(bannedMember);
    } else {
      return getDefaultItem(bannedMember, controller, theme, context);
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
          color: bannedMembersStyle.loadingIconTint ??
              theme.palette.getAccent600(),
        ),
      );
    }
  }

  Widget _getNoBannedMemberIndicator(
      BuildContext context, CometChatTheme theme) {
    if (emptyStateView != null) {
      return Center(child: emptyStateView!(context));
    } else {
      return Center(
        child: Text(
          emptyStateText ?? cc.Translations.of(context).noBannedMembersFound,
          style: bannedMembersStyle.emptyTextStyle ??
              TextStyle(
                  fontSize: theme.typography.title1.fontSize,
                  fontWeight: theme.typography.title1.fontWeight,
                  color: theme.palette.getAccent400()),
        ),
      );
    }
  }

  Widget _getBannedMemberListDivider(
      CometChatBannedMembersController controller,
      int index,
      BuildContext context,
      CometChatTheme theme) {
    if (index == 0 ||
        controller.list[index].name.substring(0, 1) !=
            controller.list[index - 1].name.substring(0, 1)) {
      return SectionSeparator(
        text: controller.list[index].name.substring(0, 1),
        dividerColor: theme.palette.getAccent100(),
        textStyle: bannedMembersStyle.sectionHeaderTextStyle ??
            TextStyle(
                color: theme.palette.getAccent500(),
                fontSize: theme.typography.text2.fontSize,
                fontWeight: theme.typography.text2.fontWeight),
      );
    } else {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }
  }

  _showErrorDialog(String errorText, BuildContext context, CometChatTheme theme,
      CometChatBannedMembersController controller) {
    showCometChatConfirmDialog(
        context: context,
        messageText: Text(
          errorStateText ?? errorText,
          style: bannedMembersStyle.errorTextStyle ??
              TextStyle(
                  fontSize: theme.typography.title2.fontSize,
                  fontWeight: theme.typography.title2.fontWeight,
                  color: theme.palette.getAccent(),
                  fontFamily: theme.typography.title2.fontFamily),
        ),
        confirmButtonText: cc.Translations.of(context).tryAgain,
        cancelButtonText: cc.Translations.of(context).cancelCapital,
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

  _showError(CometChatBannedMembersController controller, BuildContext context,
      CometChatTheme theme) {
    if (hideError == true) return;
    String error;
    if (controller.error != null && controller.error is CometChatException) {
      error = Utils.getErrorTranslatedText(
          context, (controller.error as CometChatException).code);
    } else {
      error = cc.Translations.of(context).noBannedMembersFound;
    }
    if (errorStateView != null) {}
    _showErrorDialog(error, context, theme, controller);
  }

  Widget _getList(CometChatBannedMembersController bannedMemberController,
      BuildContext context, CometChatTheme theme) {
    return GetBuilder(
      init: bannedMemberController,
      global: false,
      dispose: (GetBuilderState<CometChatBannedMembersController> state) =>
          state.controller?.onClose(),
      builder: (CometChatBannedMembersController value) {
        if (value.hasError == true) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _showError(value, context, theme));

          if (errorStateView != null) {
            return errorStateView!(context);
          }

          return _getLoadingIndicator(context, theme);
        } else if (value.isLoading == true && (value.list.isEmpty)) {
          return _getLoadingIndicator(context, theme);
        } else if (value.list.isEmpty) {
          //----------- empty list widget-----------
          return _getNoBannedMemberIndicator(context, theme);
        } else {
          return ListView.builder(
            controller: controller,
            itemCount:
                value.hasMoreItems ? value.list.length + 1 : value.list.length,
            itemBuilder: (context, index) {
              if (index >= value.list.length) {
                value.loadMoreElements();
                return _getLoadingIndicator(context, theme);
              }

              return Column(
                children: [
                  if (hideSeparator == false)
                    _getBannedMemberListDivider(value, index, context, theme),
                  getListItem(value.list[index], value, theme, context),
                ],
              );
            },
          );
        }
      },
    );
  }

  Widget getSelectionWidget(
      CometChatBannedMembersController bannedMembersController,
      CometChatTheme theme) {
    if (_isSelectionOn.value) {
      return IconButton(
          onPressed: () {
            List<GroupMember>? bannedMembers =
                bannedMembersController.getSelectedList();
            if (onSelection != null) {
              onSelection!(bannedMembers);
            }
          },
          icon: Image.asset(AssetConstants.checkmark,
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
    CometChatTheme theme = this.theme ?? cometChatTheme;

    if (stateCallBack != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => stateCallBack!(bannedMembersController));
    }

    return CometChatListBase(
        title: title ?? cc.Translations.of(context).bannedMembers,
        hideSearch: hideSearch,
        backIcon: backButton,
        onBack: onBack,
        placeholder: searchPlaceholder,
        showBackButton: showBackButton,
        searchBoxIcon: searchBoxIcon,
        onSearch: bannedMembersController.onSearch,
        theme: theme,
        menuOptions: [
          if (appBarOptions != null && appBarOptions!.isNotEmpty)
            ...appBarOptions!,
          Obx(() => getSelectionWidget(bannedMembersController, theme))
        ],
        style: ListBaseStyle(
            background: bannedMembersStyle.gradient == null
                ? bannedMembersStyle.background
                : Colors.transparent,
            titleStyle: bannedMembersStyle.titleStyle,
            gradient: bannedMembersStyle.gradient,
            height: bannedMembersStyle.height,
            width: bannedMembersStyle.width,
            backIconTint: bannedMembersStyle.backIconTint,
            searchIconTint: bannedMembersStyle.searchIconTint,
            border: bannedMembersStyle.border,
            borderRadius: bannedMembersStyle.borderRadius,
            searchTextStyle: bannedMembersStyle.searchStyle,
            searchPlaceholderStyle: bannedMembersStyle.searchPlaceholderStyle,
            searchBorderColor: bannedMembersStyle.searchBorderColor,
            searchBoxRadius: bannedMembersStyle.searchBorderRadius,
            searchBoxBackground: bannedMembersStyle.searchBackground,
            searchBorderWidth: bannedMembersStyle.searchBorderWidth),
        container: _getList(bannedMembersController, context, theme));
  }
}
