import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../flutter_chat_ui_kit.dart';
import '../../../flutter_chat_ui_kit.dart' as cc;
import '../utils/section_separator.dart';
import '../utils/utils.dart';

///[CometChatUsers] is a  component that wraps the list  in  [CometChatListBase] and format it with help of [CometChatListItem]
///
/// it list down users according to different parameter set in order of recent activity
class CometChatUsers extends StatefulWidget {
  const CometChatUsers({
    Key? key,
    this.usersProtocol,
    this.subtitleView,
    this.hideSeparator = true,
    this.listItemView,
    this.usersStyle = const UsersStyle(),
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
    this.usersRequestBuilder,
    this.hideError,
    this.loadingStateView,
    this.emptyStateView,
    this.errorStateView,
    this.listItemStyle,
    this.options,
    this.avatarStyle,
    this.statusIndicatorStyle,
    this.appBarOptions,
    this.hideSectionSeparator = false,
    this.disableUsersPresence,
    this.activateSelection,
    this.onError,
    this.onBack,
    this.onItemTap,
    this.onItemLongPress,
    this.selectionIcon
  }) : super(key: key);

  ///property to be set internally by using passed parameters [usersProtocol] ,[selectionMode] ,[options]
  ///these are passed to the [CometChatUsersController] which is responsible for the business logic

  ///[usersProtocol] set custom users request builder protocol
  final UsersBuilderProtocol? usersProtocol;

  ///[usersRequestBuilder] custom request builder
  final UsersRequestBuilder? usersRequestBuilder;

  ///[subtitleView] to set subtitle for each user item
  final Widget? Function(BuildContext, User)? subtitleView;

  ///[hideSeparator] toggle visibility of separator
  final bool? hideSeparator;

  ///[listItemView] set custom view for each user item
  final Widget Function(User)? listItemView;

  ///[usersStyle] sets style
  final UsersStyle usersStyle;

  ///[controller] sets controller for the list
  final ScrollController? controller;

  final List<CometChatOption>? Function(
      User, CometChatUsersController controller)? options;

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

  ///[selectionMode] specifies mode users module is opening in
  final SelectionMode? selectionMode;

  ///[onSelection] a custom callback that would utilize the selected users to execute some task
  final Function(List<User>?, BuildContext)? onSelection;

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

  ///[stateCallBack] to access controller functions  from parent pass empty reference of  CometChatUsersController object
  final Function(CometChatUsersController controller)? stateCallBack;

  ///[listItemStyle] style for every list item
  final ListItemStyle? listItemStyle;

  ///[avatarStyle] set style for avatar
  final AvatarStyle? avatarStyle;

  ///[statusIndicatorStyle] set style for status indicator
  final StatusIndicatorStyle? statusIndicatorStyle;

  ///[appBarOptions] list of options to be visible in app bar
  final List<Widget> Function(BuildContext context)? appBarOptions;

  ///[hideSeparator] toggle visibility of separator
  final bool? hideSectionSeparator;

  ///[disableUsersPresence] controls visibility of status indicator shown if user is online
  final bool? disableUsersPresence;

  ///[activateSelection] lets the widget know if users are allowed to be selected
  final ActivateSelection? activateSelection;

  ///[onError] callback triggered in case any error happens when fetching users
  final OnError? onError;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  ///[onItemTap] callback triggered on tapping a user item
  final Function(User)? onItemTap;

  ///[onItemLongPress] callback triggered on pressing for long on a user item
  final Function(User)? onItemLongPress;

  ///[selectionIcon] will override the default selection complete icon
  final Widget? selectionIcon;

  @override
  State<CometChatUsers> createState() => _CometChatUsersState();
}

class _CometChatUsersState extends State<CometChatUsers> {
  late CometChatUsersController usersController;
  late String dateString;

  final RxBool _isSelectionOn = false.obs;

  @override
  void initState() {
    super.initState();

    dateString = DateTime.now().microsecondsSinceEpoch.toString();
    usersController = CometChatUsersController(
        usersBuilderProtocol: widget.usersProtocol ??
            UIUsersBuilder(
              widget.usersRequestBuilder ?? UsersRequestBuilder(),
            ),
        mode: widget.selectionMode,
        onError: widget.onError);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget getDefaultItem(
      User _user, CometChatUsersController _controller, CometChatTheme _theme) {
    Widget? _subtitle;
    Widget? _tail;
    Color? backgroundColor;
    Widget? icon;

    if (widget.subtitleView != null) {
      _subtitle = widget.subtitleView!(context, _user);
    }

    StatusIndicatorUtils statusIndicatorUtils =
        StatusIndicatorUtils.getStatusIndicatorFromParams(
            theme: _theme,
            user: _user,
            disableUsersPresence: widget.disableUsersPresence,
            onlineStatusIndicatorColor: widget.usersStyle.onlineStatusColor,
            isSelected: _controller.selectionMap[_user.uid] != null);

    backgroundColor = statusIndicatorUtils.statusIndicatorColor;
    icon = statusIndicatorUtils.icon;

    return GestureDetector(
      onLongPress: () {
        if (widget.activateSelection == ActivateSelection.onLongClick &&
            _controller.selectionMap.isEmpty &&
            !(widget.selectionMode == null ||
                widget.selectionMode == SelectionMode.none)) {
          _controller.onTap(_user);

          _isSelectionOn.value = true;
        } else if (widget.onItemLongPress != null) {
          widget.onItemLongPress!(_user);
        }
      },
      onTap: () {
        if (widget.activateSelection == ActivateSelection.onClick ||
            (widget.activateSelection == ActivateSelection.onLongClick &&
                    _controller.selectionMap.isNotEmpty) &&
                !(widget.selectionMode == null ||
                    widget.selectionMode == SelectionMode.none)) {
          _controller.onTap(_user);
          if (_controller.selectionMap.isEmpty) {
            _isSelectionOn.value = false;
          } else if (widget.activateSelection == ActivateSelection.onClick &&
              _controller.selectionMap.isNotEmpty &&
              _isSelectionOn.value == false) {
            _isSelectionOn.value = true;
          }
        } else if (widget.onItemTap != null) {
          widget.onItemTap!(_user);
        }
      },
      child: CometChatListItem(
        id: _user.uid,
        avatarName: _user.name,
        avatarURL: _user.avatar,
        title: _user.name,
        key: UniqueKey(),
        subtitleView: _subtitle,
        tailView: _tail,
        avatarStyle: widget.avatarStyle ?? const AvatarStyle(),
        statusIndicatorColor: backgroundColor,
        statusIndicatorIcon: icon,
        statusIndicatorStyle:
            widget.statusIndicatorStyle ?? const StatusIndicatorStyle(),
        theme: _theme,
        hideSeparator: widget.hideSeparator ?? true,
        options:
            widget.options != null ? widget.options!(_user, _controller) : [],
        style: widget.listItemStyle ??
            ListItemStyle(
                background: Colors.transparent,
                titleStyle: TextStyle(
                    fontSize: _theme.typography.name.fontSize,
                    fontWeight: _theme.typography.name.fontWeight,
                    fontFamily: _theme.typography.name.fontFamily,
                    color: _theme.palette.getAccent())),
      ),
    );
  }

  Widget getListItem(
      User _user, CometChatUsersController _controller, CometChatTheme _theme) {
    if (widget.listItemView != null) {
      return widget.listItemView!(_user);
    } else {
      return getDefaultItem(_user, _controller, _theme);
    }
  }

  Widget _getLoadingIndicator(BuildContext context, CometChatTheme _theme) {
    if (widget.loadingStateView != null) {
      return Center(child: widget.loadingStateView!(context));
    } else {
      return Center(
        child: Image.asset(
          AssetConstants.spinner,
          package: UIConstants.packageName,
          color: widget.usersStyle.loadingIconTint ??
              _theme.palette.getAccent600(),
        ),
      );
    }
  }

  Widget _getNoUserIndicator(BuildContext context, CometChatTheme _theme) {
    if (widget.emptyStateView != null) {
      return Center(child: widget.emptyStateView!(context));
    } else {
      return Center(
        child: Text(
          widget.emptyStateText ?? cc.Translations.of(context).no_users_found,
          style: widget.usersStyle.emptyTextStyle ??
              TextStyle(
                  fontSize: _theme.typography.title1.fontSize,
                  fontWeight: _theme.typography.title1.fontWeight,
                  color: _theme.palette.getAccent400()),
        ),
      );
    }
  }

  Widget _getUserListDivider(CometChatUsersController _controller, int index,
      BuildContext context, CometChatTheme _theme) {
    if (index == 0 ||
        _controller.list[index].name.substring(0, 1) !=
            _controller.list[index - 1].name.substring(0, 1)) {
      return SectionSeparator(
        text: _controller.list[index].name.substring(0, 1),
        dividerColor:
            widget.usersStyle.separatorColor ?? _theme.palette.getAccent100(),
        textStyle: widget.usersStyle.sectionHeaderTextStyle ??
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
      CometChatTheme _theme, CometChatUsersController _controller) {
    showCometChatConfirmDialog(
        context: context,
        messageText: Text(
          widget.errorStateText ?? _errorText,
          style: widget.usersStyle.errorTextStyle ??
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

  _showError(CometChatUsersController _controller, BuildContext context,
      CometChatTheme _theme) {
    if (widget.hideError == true) return;
    String _error;
    if (_controller.error != null && _controller.error is CometChatException) {
      _error = Utils.getErrorTranslatedText(
          context, (_controller.error as CometChatException).code);
    } else {
      _error = cc.Translations.of(context).no_users_found;
    }
    if (widget.errorStateView != null) {}
    _showErrorDialog(_error, context, _theme, _controller);
  }

  Widget _getList(BuildContext context, CometChatTheme _theme) {
    return GetBuilder(
      init: usersController,
      tag: dateString,
      builder: (CometChatUsersController value) {
        if (value.hasError == true) {
          WidgetsBinding.instance
              ?.addPostFrameCallback((_) => _showError(value, context, _theme));

          if (widget.errorStateView != null) {
            return widget.errorStateView!(context);
          }

          return _getLoadingIndicator(context, _theme);
        } else if (value.isLoading == true && (value.list.isEmpty)) {
          return _getLoadingIndicator(context, _theme);
        } else if (value.list.isEmpty) {
          //----------- empty list widget-----------
          return _getNoUserIndicator(context, _theme);
        } else {
          return ListView.builder(
            controller: widget.controller,
            itemCount:
                value.hasMoreItems ? value.list.length + 1 : value.list.length,
            itemBuilder: (context, index) {
              if (index >= value.list.length) {
                value.loadMoreElements();
                return _getLoadingIndicator(context, _theme);
              }

              return Column(
                children: [
                  if (widget.hideSectionSeparator != true)
                    _getUserListDivider(value, index, context, _theme),
                  getListItem(value.list[index], value, _theme),
                ],
              );
            },
          );
        }
      },
    );
  }

  Widget getSelectionWidget(CometChatUsersController _usersController,
      CometChatTheme _theme, BuildContext context) {
    if (_isSelectionOn.value) {
      return IconButton(
          onPressed: () {
            List<User>? users = _usersController.getSelectedList();
            if (widget.onSelection != null) {
              widget.onSelection!(users, context);
            }
          },
          icon: widget.selectionIcon ?? Image.asset(AssetConstants.checkmark,
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
    CometChatTheme _theme = widget.theme ?? cometChatTheme;

    // if (stateCallBack != null) {
    //   WidgetsBinding.instance
    //       ?.addPostFrameCallback((_) => stateCallBack!(usersController));
    // }

    return CometChatListBase(
        title: widget.title ?? cc.Translations.of(context).users,
        hideSearch: widget.hideSearch,
        backIcon: widget.backButton,
        onBack: widget.onBack,
        placeholder: widget.searchPlaceholder,
        showBackButton: widget.showBackButton,
        searchBoxIcon: widget.searchBoxIcon,
        onSearch: usersController.onSearch,
        theme: widget.theme,
        menuOptions: [
          if (widget.appBarOptions != null) ...widget.appBarOptions!(context),
          Obx(() => getSelectionWidget(usersController, _theme, context))
        ],
        style: ListBaseStyle(
            background: widget.usersStyle.gradient == null
                ? widget.usersStyle.background
                : Colors.transparent,
            titleStyle: widget.usersStyle.titleStyle,
            gradient: widget.usersStyle.gradient,
            height: widget.usersStyle.height,
            width: widget.usersStyle.width,
            backIconTint: widget.usersStyle.backIconTint,
            searchIconTint: widget.usersStyle.searchIconTint,
            border: widget.usersStyle.border,
            borderRadius: widget.usersStyle.borderRadius,
            searchTextStyle: widget.usersStyle.searchTextStyle,
            searchPlaceholderStyle: widget.usersStyle.searchPlaceholderStyle,
            searchBorderColor: widget.usersStyle.searchBorderColor,
            searchBoxRadius: widget.usersStyle.searchBorderRadius,
            searchBoxBackground: widget.usersStyle.searchBackground,
            searchBorderWidth: widget.usersStyle.searchBorderWidth),
        container: _getList(context, _theme));
  }
}
