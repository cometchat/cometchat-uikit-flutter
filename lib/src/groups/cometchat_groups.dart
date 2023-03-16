import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/src/utils/utils.dart';
import 'package:get/get.dart';
import '../../../flutter_chat_ui_kit.dart';
import '../../../flutter_chat_ui_kit.dart' as cc;

///[CometChatGroups] is a  component that wraps the list  in  [CometChatListBase] and format it with help of [CometChatListItem]
///
/// it list down groups according to different parameter set in order of recent activity
class CometChatGroups extends StatelessWidget {
  CometChatGroups(
      {Key? key,
      this.groupsProtocol,
      this.subtitleView,
      this.listItemView,
      this.groupsStyle = const GroupsStyle(),
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
      this.errorText,
      this.emptyText,
      this.stateCallBack,
      this.groupsRequestBuilder,
      this.hideError,
      this.loadingView,
      this.emptyView,
      this.errorView,
      this.listItemStyle,
      this.options,
      this.avatarStyle,
      this.statusIndicatorStyle,
      this.hideSeparator = false,
      this.appBarOptions,
      this.passwordGroupIcon,
      this.privateGroupIcon,
      this.activateSelection,
      this.onBack,
      this.onItemTap,
      this.onItemLongPress,
      OnError? onError})
      : groupsController = CometChatGroupsController(
            groupsBuilderProtocol: groupsProtocol ??
                UIGroupsBuilder(
                  groupsRequestBuilder ?? GroupsRequestBuilder(),
                ),
            mode: selectionMode,
            theme: theme ?? cometChatTheme,
            onError: onError),
        super(key: key);

  ///property to be set internally by using passed parameters [groupsProtocol] ,[selectionMode] ,[options]
  ///these are passed to the [CometChatGroupsController] which is responsible for the business logic
  final CometChatGroupsController groupsController;

  ///[groupsProtocol] set custom groups request builder protocol
  final GroupsBuilderProtocol? groupsProtocol;

  ///[groupsRequestBuilder] custom request builder
  final GroupsRequestBuilder? groupsRequestBuilder;

  ///[subtitleView] to set subtitle for each group
  final Widget? Function(BuildContext, Group)? subtitleView;

  ///[listItemView] set custom view for each group
  final Widget Function(Group)? listItemView;

  ///[groupsStyle] sets style
  final GroupsStyle groupsStyle;

  ///[controller] sets controller for the list
  final ScrollController? controller;

  ///[options]  set options which will be visible at slide of each banned member
  final List<CometChatOption>? Function(Group group,
      CometChatGroupsController controller, BuildContext context)? options;

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

  ///[selectionMode] specifies mode groups module is opening in
  final SelectionMode? selectionMode;

  ///[onSelection] function will be performed
  final Function(List<Group>?)? onSelection;

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

  ///[stateCallBack] to access controller functions  from parent pass empty reference of  CometChatGroupsController object
  final Function(CometChatGroupsController controller)? stateCallBack;

  ///[listItemStyle] style for every list item
  final ListItemStyle? listItemStyle;

  ///[avatarStyle] set style for avatar
  final AvatarStyle? avatarStyle;

  ///[statusIndicatorStyle] set style for status indicator
  final StatusIndicatorStyle? statusIndicatorStyle;

  ///[appBarOptions] list of options to be visible in app bar
  final List<Widget> Function(BuildContext context)? appBarOptions;

  ///[hideSeparator]
  final bool hideSeparator;

  ///[passwordGroupIcon] sets icon in status indicator for password group
  final Widget? passwordGroupIcon;

  ///[privateGroupIcon] sets icon in status indicator for private group
  final Widget? privateGroupIcon;

  ///[activateSelection] lets the widget know if groups are allowed to be selected
  final ActivateSelection? activateSelection;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  ///[onItemTap] callback triggered on tapping a group item
  final Function(Group)? onItemTap;

  ///[onItemLongPress] callback triggered on pressing for long on a group item
  final Function(Group)? onItemLongPress;

  final RxBool _isSelectionOn = false.obs;

  Widget getDefaultItem(Group _group, CometChatGroupsController _controller,
      CometChatTheme _theme, int index, BuildContext context) {
    Widget? _subtitle;

    StatusIndicatorUtils statusIndicatorUtils =
        StatusIndicatorUtils.getStatusIndicatorFromParams(
            theme: _theme,
            group: _group,
            privateGroupIconBackground: groupsStyle.privateGroupIconBackground,
            protectedGroupIconBackground:
                groupsStyle.passwordGroupIconBackground,
            privateGroupIcon: privateGroupIcon,
            protectedGroupIcon: passwordGroupIcon,
            isSelected: _controller.selectionMap[_group.guid] != null);

    if (subtitleView != null) {
      _subtitle = subtitleView!(context, _group);
    } else {
      _subtitle = Text(
        "${_group.membersCount} ${cc.Translations.of(context).members}",
        style: TextStyle(
                fontSize: _theme.typography.subtitle1.fontSize,
                fontWeight: _theme.typography.subtitle1.fontWeight,
                fontFamily: _theme.typography.subtitle1.fontFamily,
                color: _theme.palette.getAccent600())
            .merge(groupsStyle.subtitleTextStyle),
      );
    }

    Color? backgroundColor = statusIndicatorUtils.statusIndicatorColor;
    Widget? icon = statusIndicatorUtils.icon;

    return GestureDetector(
      onLongPress: () {
        if (activateSelection == ActivateSelection.onLongClick &&
            _controller.selectionMap.isEmpty &&
            !(selectionMode == null || selectionMode == SelectionMode.none)) {
          _controller.onTap(_group);

          _isSelectionOn.value = true;
        } else if (onItemLongPress != null) {
          onItemLongPress!(_group);
        }
      },
      onTap: () {
        if (activateSelection == ActivateSelection.onClick ||
            (activateSelection == ActivateSelection.onLongClick &&
                    _controller.selectionMap.isNotEmpty) &&
                !(selectionMode == null ||
                    selectionMode == SelectionMode.none)) {
          _controller.onTap(_group);
          if (_controller.selectionMap.isEmpty) {
            _isSelectionOn.value = false;
          } else if (activateSelection == ActivateSelection.onClick &&
              _controller.selectionMap.isNotEmpty &&
              _isSelectionOn.value == false) {
            _isSelectionOn.value = true;
          }
        } else if (onItemTap != null) {
          onItemTap!(_group);
        }
      },
      child: CometChatListItem(
        id: _group.guid,
        avatarName: _group.name,
        avatarURL: _group.icon,
        title: _group.name,
        key: UniqueKey(),
        subtitleView: _subtitle,
        avatarStyle: avatarStyle ?? const AvatarStyle(),
        statusIndicatorColor: backgroundColor,
        statusIndicatorIcon: icon,
        statusIndicatorStyle:
            statusIndicatorStyle ?? const StatusIndicatorStyle(),
        theme: _theme,
        options:
            options != null ? options!(_group, _controller, context) : null,
        style: ListItemStyle(
            background: listItemStyle?.background ?? Colors.transparent,
            titleStyle: TextStyle(
                    fontSize: _theme.typography.name.fontSize,
                    fontWeight: _theme.typography.name.fontWeight,
                    fontFamily: _theme.typography.name.fontFamily,
                    color: _theme.palette.getAccent())
                .merge(listItemStyle?.titleStyle),
            height: listItemStyle?.height ?? 72,
            border: listItemStyle?.border,
            borderRadius: listItemStyle?.borderRadius,
            gradient: listItemStyle?.gradient,
            separatorColor: listItemStyle?.separatorColor,
            width: listItemStyle?.width),
        hideSeparator: hideSeparator,
      ),
    );
  }

  Widget getListItem(Group _group, CometChatGroupsController _controller,
      CometChatTheme _theme, int index, BuildContext context) {
    if (listItemView != null) {
      return listItemView!(_group);
    } else {
      return getDefaultItem(_group, _controller, _theme, index, context);
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
          color: groupsStyle.loadingIconTint ?? _theme.palette.getAccent600(),
        ),
      );
    }
  }

  Widget _getNoGroupIndicator(BuildContext context, CometChatTheme _theme) {
    if (emptyView != null) {
      return Center(child: emptyView!(context));
    } else {
      return Center(
        child: Text(
          emptyText ?? cc.Translations.of(context).no_groups_found,
          style: groupsStyle.emptyTextStyle ??
              TextStyle(
                  fontSize: _theme.typography.title1.fontSize,
                  fontWeight: _theme.typography.title1.fontWeight,
                  color: _theme.palette.getAccent400()),
        ),
      );
    }
  }

  _showErrorDialog(String _errorText, BuildContext context,
      CometChatTheme _theme, CometChatGroupsController _controller) {
    showCometChatConfirmDialog(
        context: context,
        messageText: Text(
          errorText ?? _errorText,
          style: groupsStyle.errorTextStyle ??
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

  _showError(CometChatGroupsController _controller, BuildContext context,
      CometChatTheme _theme) {
    if (hideError == true) return;
    String _error;
    if (_controller.error != null && _controller.error is CometChatException) {
      _error = Utils.getErrorTranslatedText(
          context, (_controller.error as CometChatException).code);
    } else {
      _error = cc.Translations.of(context).no_groups_found;
    }
    if (errorView != null) {}
    _showErrorDialog(_error, context, _theme, _controller);
  }

  Widget _getList(CometChatGroupsController _controller, BuildContext context,
      CometChatTheme _theme) {
    return GetBuilder(
      init: _controller,
      global: false,
      dispose: (GetBuilderState<CometChatGroupsController> state) =>
          state.controller?.onClose(),
      builder: (CometChatGroupsController value) {
        value.context = context;
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
          return _getNoGroupIndicator(context, _theme);
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
                  getListItem(value.list[index], value, _theme, index, context),
                ],
              );
            },
          );
        }
      },
    );
  }

  Widget getSelectionWidget(
      CometChatGroupsController _groupsController, CometChatTheme _theme) {
    if (_isSelectionOn.value) {
      return IconButton(
          onPressed: () {
            List<Group>? groups = _groupsController.getSelectedList();
            if (onSelection != null) {
              onSelection!(groups);
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
      WidgetsBinding.instance
          ?.addPostFrameCallback((_) => stateCallBack!(groupsController));
    }

    return CometChatListBase(
        title: title ?? cc.Translations.of(context).groups,
        hideSearch: hideSearch,
        backIcon: backButton,
        onBack: onBack,
        placeholder: searchPlaceholder,
        showBackButton: showBackButton,
        searchBoxIcon: searchBoxIcon,
        onSearch: groupsController.onSearch,
        theme: theme,
        menuOptions: [
          if (appBarOptions != null) ...appBarOptions!(context),
          Obx(
            () => getSelectionWidget(groupsController, _theme),
          )
        ],
        style: ListBaseStyle(
            background: groupsStyle.gradient == null
                ? groupsStyle.background
                : Colors.transparent,
            titleStyle: groupsStyle.titleStyle,
            gradient: groupsStyle.gradient,
            height: groupsStyle.height,
            width: groupsStyle.width,
            backIconTint: groupsStyle.backIconTint,
            searchIconTint: groupsStyle.searchIconTint,
            border: groupsStyle.border,
            borderRadius: groupsStyle.borderRadius,
            searchTextStyle: groupsStyle.searchTextStyle,
            searchPlaceholderStyle: groupsStyle.searchPlaceholderStyle,
            searchBorderColor: groupsStyle.searchBorderColor,
            searchBoxRadius: groupsStyle.searchBorderRadius,
            searchBoxBackground: groupsStyle.searchBackground,
            searchBorderWidth: groupsStyle.searchBorderWidth),
        container: _getList(groupsController, context, _theme));
  }
}
