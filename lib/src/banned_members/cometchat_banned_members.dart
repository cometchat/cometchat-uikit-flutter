import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/src/utils/section_separator.dart';
import 'package:flutter_chat_ui_kit/src/utils/utils.dart';
import 'package:get/get.dart';
import '../../../flutter_chat_ui_kit.dart';
import '../../../flutter_chat_ui_kit.dart' as cc;

///[CometChatBannedMembers] is a  component that wraps the list  in  [CometChatListBase] and format it with help of [CometChatListItem]
///
/// it list down banned members according to different parameter set in order of recent activity
class CometChatBannedMembers extends StatelessWidget {
  CometChatBannedMembers(
      {Key? key,
      required this.group,
      this.bannedMemberProtocol,
      this.subtitle,
      this.hideSeparator = true,
      this.listItemView,
      this.style = const BannedMembersStyle(),
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
      this.errorText,
      this.emptyText,
      this.stateCallBack,
      this.bannedMemberRequestBuilder,
      this.hideError,
      this.loadingView,
      this.emptyView,
      this.errorView,
      this.tail,
      this.disableUsersPresence = true,
      this.avatarStyle,
      this.statusIndicatorStyle,
      this.appBarOptions,
      this.listItemStyle,
      OnError? onError,
      this.onBack,
      this.onItemTap,
      this.onItemLongPress,
      this.activateSelection})
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
            onError: onError),
        super(key: key);

  ///[group] stores a reference to the group for which banned members will be shown
  final Group group;

  ///[bannedMembersController] contains the business logic
  final CometChatBannedMembersController bannedMembersController;

  ///[bannedMemberProtocol] is a wrapper for request builder
  final BannedMemberBuilderProtocol? bannedMemberProtocol;

  ///[bannedMemberRequestBuilder] set custom request builder
  final BannedGroupMembersRequestBuilder? bannedMemberRequestBuilder;

  ///[subtitle] to set subtitle for each banned member
  final Widget? Function(GroupMember)? subtitle;

  ///[hideSeparator] toggle visibility of separator
  final bool? hideSeparator;

  ///[listItemView] set custom view for each banned member
  final Widget Function(GroupMember)? listItemView;

  ///[style] sets style
  final BannedMembersStyle style;

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



  ///[emptyText] text to be displayed when the list is empty
  final String? emptyText;

  ///[errorText] text to be displayed when error occur
  final String? errorText;

  ///[loadingView] returns view fow loading state
  final WidgetBuilder? loadingView;

  ///[emptyView] returns view fow empty state
  final WidgetBuilder? emptyView;

  ///[errorView] returns view fow error state behind the dialog
  final WidgetBuilder? errorView;

  ///[hideError] toggle visibility of error dialog
  final bool? hideError;

  ///[stateCallBack] to access controller functions  from parent pass empty reference of  CometChatBannedMembersController object
  final Function(CometChatBannedMembersController controller)? stateCallBack;

  ///[tail] to set tail/trailing widget for each banned member
  final Widget? Function(GroupMember)? tail;

  ///[disableUsersPresence] controls visibility of status indicator
  final bool disableUsersPresence;

  ///[avatarStyle] is applied to the avatar of the user banned from the group
  final AvatarStyle? avatarStyle;

  ///[statusIndicatorStyle] is applied to the online/offline status indicator of the user banned from the group
  final StatusIndicatorStyle? statusIndicatorStyle;

  ///[appBarOptions] list of options to be visible in app bar
  final List<Widget>? appBarOptions;

  ///[listItemStyle] style for every list item
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
    CometChatBannedMembersController _controller,
    CometChatTheme _theme,
    BuildContext context,
  ) {
    Widget? _subtitle;
    if (subtitle != null) {
      _subtitle = subtitle!(bannedMember);
    }

    Color? backgroundColor;
    Widget? icon;

    StatusIndicatorUtils statusIndicatorUtils =
        StatusIndicatorUtils.getStatusIndicatorFromParams(
      isSelected: _controller.selectionMap[bannedMember.uid] != null,
      theme: _theme,
      groupMember: bannedMember,
      onlineStatusIndicatorColor:
          style.onlineStatusColor ?? _theme.palette.getSuccess(),
      disableUsersPresence: disableUsersPresence,
    );

    backgroundColor = statusIndicatorUtils.statusIndicatorColor;
    icon = statusIndicatorUtils.icon;

    Widget? _tail;
    if (tail != null) {
      _tail = tail!(bannedMember);
    }

    return GestureDetector(
      onLongPress: () {
        if (activateSelection == ActivateSelection.onLongClick &&
            _controller.selectionMap.isEmpty &&
            !(selectionMode == null || selectionMode == SelectionMode.none)) {
          _controller.onTap(bannedMember);

          _isSelectionOn.value = true;
        } else if (onItemLongPress != null) {
          onItemLongPress!(bannedMember);
        }
      },
      onTap: () {
        if (activateSelection == ActivateSelection.onClick ||
            (activateSelection == ActivateSelection.onLongClick &&
                    _controller.selectionMap.isNotEmpty) &&
                !(selectionMode == null ||
                    selectionMode == SelectionMode.none)) {
          _controller.onTap(bannedMember);
          if (_controller.selectionMap.isEmpty) {
            _isSelectionOn.value = false;
          } else if (activateSelection == ActivateSelection.onClick &&
              _controller.selectionMap.isNotEmpty &&
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
        subtitleView: _subtitle,
        statusIndicatorColor:
            disableUsersPresence == false ? backgroundColor : null,
        statusIndicatorIcon: disableUsersPresence == false ? icon : null,
        statusIndicatorStyle:
            statusIndicatorStyle ?? const StatusIndicatorStyle(),
        avatarStyle: avatarStyle ?? const AvatarStyle(),
        tailView: _tail ??
            Text(
              cc.Translations.of(context).banned,
              style: style.tailTextStyle ??
                  TextStyle(
                      fontSize: _theme.typography.text1.fontSize,
                      fontWeight: _theme.typography.text1.fontWeight,
                      color: _theme.palette.getAccent500()),
            ),
        style: ListItemStyle(
            background: listItemStyle?.background ?? Colors.transparent,
            titleStyle: listItemStyle?.titleStyle ??
                TextStyle(
                    fontSize: _theme.typography.name.fontSize,
                    fontWeight: _theme.typography.name.fontWeight,
                    fontFamily: _theme.typography.name.fontFamily,
                    color: _theme.palette.getAccent()),
            height: listItemStyle?.height,
            border: listItemStyle?.border,
            borderRadius: listItemStyle?.borderRadius,
            gradient: listItemStyle?.gradient,
            separatorColor: listItemStyle?.separatorColor,
            width: listItemStyle?.width),
        options: options != null
            ? options!(group, bannedMember, _controller, context)
            : _controller.defaultFunction(group, bannedMember),
      ),
    );
  }

  Widget getListItem(
      GroupMember bannedMember,
      CometChatBannedMembersController _controller,
      CometChatTheme _theme,
      BuildContext context) {
    if (listItemView != null) {
      return listItemView!(bannedMember);
    } else {
      return getDefaultItem(bannedMember, _controller, _theme, context);
    }
  }

  Widget _getLoadingIndicator(BuildContext context, CometChatTheme _theme) {
    if (loadingView != null) {
      return Center(child: loadingView!(context));
    } else {
      return Center(
        child: Image.asset(
          AssetConstants.spinner,
          package: UIConstants.packageName,
          color: style.loadingIconTint ?? _theme.palette.getAccent600(),
        ),
      );
    }
  }

  Widget _getNoBannedMemberIndicator(
      BuildContext context, CometChatTheme _theme) {
    if (emptyView != null) {
      return Center(child: emptyView!(context));
    } else {
      return Center(
        child: Text(
          emptyText ?? cc.Translations.of(context).no_banned_members_found,
          style: style.emptyTextStyle ??
              TextStyle(
                  fontSize: _theme.typography.title1.fontSize,
                  fontWeight: _theme.typography.title1.fontWeight,
                  color: _theme.palette.getAccent400()),
        ),
      );
    }
  }

  Widget _getBannedMemberListDivider(
      CometChatBannedMembersController _controller,
      int index,
      BuildContext context,
      CometChatTheme _theme) {
    if (index == 0 ||
        _controller.list[index].name.substring(0, 1) !=
            _controller.list[index - 1].name.substring(0, 1)) {
      return SectionSeparator(
        text: _controller.list[index].name.substring(0, 1),
        dividerColor: _theme.palette.getAccent100(),
        textStyle: style.sectionHeaderTextStyle ??
            TextStyle(
                color: _theme.palette.getAccent500(),
                fontSize: _theme.typography.text2.fontSize,
                fontWeight: _theme.typography.text2.fontWeight),
      );
    } else {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }
  }

  _showErrorDialog(String _errorText, BuildContext context,
      CometChatTheme _theme, CometChatBannedMembersController _controller) {
    showCometChatConfirmDialog(
        context: context,
        messageText: Text(
          errorText ?? _errorText,
          style: style.errorTextStyle ??
              TextStyle(
                  fontSize: _theme.typography.title2.fontSize,
                  fontWeight: _theme.typography.title2.fontWeight,
                  color: _theme.palette.getAccent(),
                  fontFamily: _theme.typography.title2.fontFamily),
        ),
        confirmButtonText: cc.Translations.of(context).try_again,
        cancelButtonText: cc.Translations.of(context).cancel_capital,
        style: ConfirmDialogStyle(
            backgroundColor: _theme.palette.mode == PaletteThemeModes.light
                ? _theme.palette.getBackground()
                : Color.alphaBlend(_theme.palette.getAccent200(),
                    _theme.palette.getBackground()),
            shadowColor: _theme.palette.getAccent300(),
            confirmButtonTextStyle: TextStyle(
                fontSize: _theme.typography.text2.fontSize,
                fontWeight: _theme.typography.text2.fontWeight,
                color: _theme.palette.getPrimary()),
            cancelButtonTextStyle: TextStyle(
                fontSize: _theme.typography.text2.fontSize,
                fontWeight: _theme.typography.text2.fontWeight,
                color: _theme.palette.getPrimary())),
        onCancel: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        onConfirm: () {
          Navigator.pop(context);
          _controller.loadMoreElements();
        });
  }

  _showError(CometChatBannedMembersController _controller, BuildContext context,
      CometChatTheme _theme) {
    if (hideError == true) return;
    String _error;
    if (_controller.error != null && _controller.error is CometChatException) {
      _error = Utils.getErrorTranslatedText(
          context, (_controller.error as CometChatException).code);
    } else {
      _error = cc.Translations.of(context).no_banned_members_found;
    }
    if (errorView != null) {}
    _showErrorDialog(_error, context, _theme, _controller);
  }

  Widget _getList(CometChatBannedMembersController _controller,
      BuildContext context, CometChatTheme _theme) {
    return GetBuilder(
      init: _controller,
      global: false,
      dispose: (GetBuilderState<CometChatBannedMembersController> state) =>
          state.controller?.onClose(),
      builder: (CometChatBannedMembersController value) {
        if (value.hasError == true) {
          WidgetsBinding.instance
              ?.addPostFrameCallback((_) => _showError(value, context, _theme));

          if (errorView != null) {
            return errorView!(context);
          }

          return _getLoadingIndicator(context, _theme);
        } else if (value.isLoading == true && (value.list.isEmpty)) {
          return _getLoadingIndicator(context, _theme);
        } else if (value.list.isEmpty) {
          //----------- empty list widget-----------
          return _getNoBannedMemberIndicator(context, _theme);
        } else {
          return ListView.builder(
            controller: controller,
            itemCount:
                value.hasMoreItems ? value.list.length + 1 : value.list.length,
            itemBuilder: (context, index) {
              if (index >= value.list.length) {
                value.loadMoreElements();
                return _getLoadingIndicator(context, _theme);
              }

              return Column(
                children: [
                  if (hideSeparator == false)
                    _getBannedMemberListDivider(value, index, context, _theme),
                  getListItem(value.list[index], value, _theme, context),
                ],
              );
            },
          );
        }
      },
    );
  }

  Widget getSelectionWidget(
      CometChatBannedMembersController _bannedMembersController,
      CometChatTheme _theme) {
    if (_isSelectionOn.value) {
      return IconButton(
          onPressed: () {
            List<GroupMember>? bannedMembers =
                _bannedMembersController.getSelectedList();
            if (onSelection != null) {
              onSelection!(bannedMembers);
            }
          },
          icon: Image.asset(AssetConstants.checkmark,
              package: UIConstants.packageName,
              color: _theme.palette.getPrimary()));
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

    if (stateCallBack != null) {
      WidgetsBinding.instance?.addPostFrameCallback(
          (_) => stateCallBack!(bannedMembersController));
    }

    return CometChatListBase(
        title: title ?? cc.Translations.of(context).banned_members,
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
          Obx(() => getSelectionWidget(bannedMembersController, _theme))
        ],
        style: ListBaseStyle(
            background:
                style.gradient == null ? style.background : Colors.transparent,
            titleStyle: style.titleStyle,
            gradient: style.gradient,
            height: style.height,
            width: style.width,
            backIconTint: style.backIconTint,
            searchIconTint: style.searchIconTint,
            border: style.border,
            borderRadius: style.borderRadius,
            searchTextStyle: style.searchStyle,
            searchPlaceholderStyle: style.searchPlaceholderStyle,
            searchBorderColor: style.searchBorderColor,
            searchBoxRadius: style.searchBorderRadius,
            searchBoxBackground: style.searchBackground,
            searchBorderWidth: style.searchBorderWidth),
        container: _getList(bannedMembersController, context, _theme));
  }
}
