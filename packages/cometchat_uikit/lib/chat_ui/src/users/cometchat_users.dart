import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cometchat_chat_uikit.dart';
import '../../../cometchat_chat_uikit.dart' as cc;

/// [CometChatUsers] is a component that displays a list of users
/// using Clean Architecture with BLoC pattern.
class CometChatUsers extends StatefulWidget {
  const CometChatUsers({
    super.key,
    this.usersStyle = const CometChatUsersStyle(),
    this.scrollController,
    this.searchPlaceholder,
    this.backButton,
    this.showBackButton = true,
    this.searchBoxIcon,
    this.hideSearch = false,
    this.selectionMode,
    this.onSelection,
    this.title,
    this.loadingStateView,
    this.emptyStateView,
    this.errorStateView,
    this.appBarOptions,
    this.usersStatusVisibility = true,
    this.activateSelection,
    this.onError,
    this.onBack,
    this.onItemTap,
    this.onItemLongPress,
    this.setOptions,
    this.addOptions,
    this.submitIcon,
    this.hideAppbar = false,
    this.height,
    this.width,
    this.stickyHeaderVisibility = false,
    this.searchKeyword,
    this.onLoad,
    this.onEmpty,
    this.subtitleView,
    this.listItemView,
    this.titleView,
    this.leadingView,
    this.trailingView,
    this.usersBloc,
    this.usersRequestBuilder,
  });

  final UsersBloc? usersBloc;

  /// [usersRequestBuilder] custom request builder for filtering users
  final UsersRequestBuilder? usersRequestBuilder;

  final Widget? Function(BuildContext, User)? subtitleView;
  final Widget Function(User)? listItemView;
  final CometChatUsersStyle usersStyle;
  final ScrollController? scrollController;
  final String? searchPlaceholder;
  final Widget? backButton;
  final bool showBackButton;
  final Widget? searchBoxIcon;
  final bool hideSearch;
  final SelectionMode? selectionMode;
  final Function(List<User>?, BuildContext)? onSelection;
  final String? title;
  final WidgetBuilder? loadingStateView;
  final WidgetBuilder? emptyStateView;
  final WidgetBuilder? errorStateView;
  final List<Widget> Function(BuildContext context)? appBarOptions;
  final bool? usersStatusVisibility;
  final ActivateSelection? activateSelection;
  final OnError? onError;
  final VoidCallback? onBack;
  final Function(BuildContext context, User)? onItemTap;
  final Function(BuildContext context, User)? onItemLongPress;

  /// [setOptions] sets the list of actions a long press on a user offers.
  /// When it is set, [addOptions] is ignored, as on Android. Starting a
  /// long-press selection comes first, then [onItemLongPress], when set,
  /// takes the long press instead.
  final List<CometChatOption>? Function(
    User user,
    UsersBloc bloc,
    BuildContext context,
  )?
  setOptions;

  /// [addOptions] adds to the actions a long press on a user offers. The
  /// list has no built-in entries, so on its own it behaves as [setOptions]
  /// does; with [setOptions] set it is not used.
  final List<CometChatOption>? Function(
    User user,
    UsersBloc bloc,
    BuildContext context,
  )?
  addOptions;
  final Widget? submitIcon;
  final bool? hideAppbar;
  final double? height;
  final double? width;
  final bool? stickyHeaderVisibility;
  final String? searchKeyword;
  final OnLoad<User>? onLoad;
  final OnEmpty? onEmpty;
  final Widget? Function(BuildContext context, User user)? trailingView;
  final Widget? Function(BuildContext context, User user)? leadingView;
  final Widget? Function(BuildContext context, User user)? titleView;

  @override
  State<CometChatUsers> createState() => _CometChatUsersState();
}

class _CometChatUsersState extends State<CometChatUsers>
    with AutomaticKeepAliveClientMixin {
  late UsersBloc usersBloc;
  bool _isExternalBloc = false;
  bool _themeInitialized = false;
  Brightness? _cachedBrightness;
  @override
  bool get wantKeepAlive => true;

  late CometChatColorPalette colorPalette;
  late CometChatTypography typography;
  late CometChatSpacing spacing;
  late CometChatUsersStyle style;
  late CometChatAvatarStyle avatarStyle;
  late CometChatStatusIndicatorStyle statusIndicatorStyle;

  @override
  void initState() {
    super.initState();
    if (widget.usersBloc != null) {
      usersBloc = widget.usersBloc!;
      _isExternalBloc = true;
    } else {
      _initializeServiceLocator();
      usersBloc = UsersBloc(
        usersStatusVisibility: widget.usersStatusVisibility ?? true,
        usersRequestBuilder: widget.usersRequestBuilder,
      );
      _isExternalBloc = false;
    }
    usersBloc.add(LoadUsers(searchKeyword: widget.searchKeyword));
  }

  void _initializeServiceLocator() {
    if (!UsersServiceLocator.instance.isInitialized) {
      UsersServiceLocator.instance.setup();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentBrightness = CometChatThemeHelper.getBrightness(context);
    final brightnessChanged =
        _cachedBrightness != null && _cachedBrightness != currentBrightness;
    if (_themeInitialized && !brightnessChanged) return;
    _cachedBrightness = currentBrightness;
    _themeInitialized = true;

    typography = CometChatThemeHelper.getTypography(context);
    colorPalette = CometChatThemeHelper.getColorPalette(context);
    spacing = CometChatThemeHelper.getSpacing(context);

    style = CometChatThemeHelper.getTheme<CometChatUsersStyle>(
      context: context,
      defaultTheme: CometChatUsersStyle.of,
    ).merge(widget.usersStyle);

    avatarStyle = CometChatThemeHelper.getTheme<CometChatAvatarStyle>(
      context: context,
      defaultTheme: CometChatAvatarStyle.of,
    ).merge(style.avatarStyle);

    statusIndicatorStyle =
        CometChatThemeHelper.getTheme<CometChatStatusIndicatorStyle>(
          context: context,
          defaultTheme: CometChatStatusIndicatorStyle.of,
        ).merge(style.statusIndicatorStyle);
  }

  @override
  void dispose() {
    if (!_isExternalBloc) {
      usersBloc.close();
    }
    super.dispose();
  }

  /// Reports a state transition to the caller's callbacks exactly once per
  /// entry into that state. ENG-39104: `onLoad`, `onEmpty` and `onError` were
  /// declared, documented and never read — the list widget does not even take
  /// them — so an integrator's "no results yet" affordance never ran.
  ///
  /// Keyed on the state's runtime type rather than the state itself: a loaded
  /// state that gains a user is still `loaded`, and re-reporting on every such
  /// rebuild would turn `onLoad` into a per-frame callback.
  Type? _lastReportedState;

  void _reportUsersState(UsersState state) {
    if (state.runtimeType == _lastReportedState) return;
    _lastReportedState = state.runtimeType;

    if (state is UsersError) {
      widget.onError?.call(Exception(state.message));
    } else if (state is UsersEmpty) {
      widget.onEmpty?.call();
    } else if (state is UsersLoaded) {
      if (state.users.isEmpty) {
        widget.onEmpty?.call();
      } else {
        widget.onLoad?.call(state.users);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Required for AutomaticKeepAliveClientMixin
    super.build(context);

    return RepaintBoundary(
      child: BlocListener<UsersBloc, UsersState>(
        bloc: usersBloc,
        listener: (context, state) => _reportUsersState(state),
        child: BlocProvider.value(
          value: usersBloc,
          child: ClipRRect(
            borderRadius: style.borderRadius ?? BorderRadius.circular(0),
            child: CometChatListBase(
              titleView: _buildTitleView(),
              titleSpacing: widget.showBackButton ? 0 : 16,
              hideSearch: widget.hideSearch,
              backIcon: _buildBackIcon(),
              placeholder: widget.searchPlaceholder,
              showBackButton: widget.showBackButton,
              searchBoxIcon: widget.searchBoxIcon,
              onSearch: (keyword) => usersBloc.add(SearchUsers(keyword)),
              hideAppBar: widget.hideAppbar,
              searchText: widget.searchKeyword,
              searchPadding: EdgeInsets.symmetric(
                horizontal: spacing.padding4 ?? 0,
                vertical: spacing.padding3 ?? 0,
              ),
              searchContentPadding: EdgeInsets.symmetric(
                horizontal: spacing.padding3 ?? 0,
                vertical: spacing.padding2 ?? 0,
              ),
              searchBoxHeight: 40,
              menuOptions: [
                if (widget.appBarOptions != null)
                  ...widget.appBarOptions!(context),
                _getSelectionWidget(),
              ],
              onBack: widget.onBack,
              style: _buildListBaseStyle(),
              container: UsersList(
                usersBloc: usersBloc,
                style: style,
                colorPalette: colorPalette,
                spacing: spacing,
                typography: typography,
                scrollController: widget.scrollController,
                loadingStateView: widget.loadingStateView,
                emptyStateView: widget.emptyStateView,
                errorStateView: widget.errorStateView,
                listItemView: widget.listItemView,
                subtitleView: widget.subtitleView,
                trailingView: widget.trailingView,
                leadingView: widget.leadingView,
                titleView: widget.titleView,
                usersStatusVisibility: widget.usersStatusVisibility,
                selectionMode: widget.selectionMode,
                activateSelection: widget.activateSelection,
                onItemTap: widget.onItemTap,
                onItemLongPress: widget.onItemLongPress,
                options: widget.setOptions == null && widget.addOptions == null
                    ? null
                    : _longPressOptions,
                stickyHeaderVisibility: widget.stickyHeaderVisibility,
                avatarStyle: avatarStyle,
                statusIndicatorStyle: statusIndicatorStyle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The long-press menu for [user]: [CometChatUsers.setOptions] when set,
  /// else [CometChatUsers.addOptions] — Android's CometChatUsers rule.
  List<CometChatOption> _longPressOptions(BuildContext context, User user) {
    final build = widget.setOptions ?? widget.addOptions!;
    return build(user, usersBloc, context) ?? const <CometChatOption>[];
  }

  Widget _buildTitleView() {
    return BlocBuilder<UsersBloc, UsersState>(
      bloc: usersBloc,
      builder: (context, state) {
        final selectedCount = state is UsersLoaded
            ? state.selectedUsers.length
            : 0;
        return Text(
          selectedCount > 0
              ? "$selectedCount"
              : widget.title ?? cc.Translations.of(context).users,
          style: TextStyle(
            color: colorPalette.textPrimary,
            fontSize: typography.heading1?.bold?.fontSize,
            fontWeight: typography.heading1?.bold?.fontWeight,
            fontFamily: typography.heading1?.bold?.fontFamily,
          ).merge(style.titleTextStyle).copyWith(color: style.titleTextColor),
        );
      },
    );
  }

  Widget _buildBackIcon() {
    return BlocBuilder<UsersBloc, UsersState>(
      bloc: usersBloc,
      builder: (context, state) {
        final hasSelection =
            state is UsersLoaded && state.selectedUsers.isNotEmpty;
        return hasSelection
            ? IconButton(
                tooltip: Translations.of(context).clearSearch,
                onPressed: () => usersBloc.add(const ClearUserSelection()),
                icon: Icon(
                  Icons.clear,
                  color: colorPalette.iconPrimary,
                  size: 24,
                ),
                padding: EdgeInsets.zero,
              )
            : (widget.backButton ??
                  IconButton(
                    tooltip: Translations.of(context).back,
                    onPressed: widget.onBack,
                    icon: Icon(
                      Icons.arrow_back,
                      // Resolve the style before the palette: ListBase applies
                      // backIconTint as IconButton.color, which cannot reach an
                      // icon that sets its own. ENG-39105.
                      color: style.backIconColor ?? colorPalette.iconPrimary,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                  ));
      },
    );
  }

  ListBaseStyle _buildListBaseStyle() {
    return ListBaseStyle(
      width: widget.width,
      height: widget.height,
      background: style.backgroundColor ?? colorPalette.background1,
      titleStyle: TextStyle(
        color: style.titleTextColor ?? colorPalette.textPrimary,
        fontSize: typography.heading1?.bold?.fontSize,
        fontWeight: typography.heading1?.bold?.fontWeight,
        fontFamily: typography.heading1?.bold?.fontFamily,
      ).merge(style.titleTextStyle),
      backIconTint: style.backIconColor ?? colorPalette.iconPrimary,
      searchIconTint: style.searchIconColor ?? colorPalette.iconSecondary,
      border: style.border,
      borderRadius: style.borderRadius,
      searchTextStyle: TextStyle(
        color: style.searchInputTextColor ?? colorPalette.textPrimary,
        fontSize: typography.heading4?.regular?.fontSize,
        fontWeight: typography.heading4?.regular?.fontWeight,
        fontFamily: typography.heading4?.regular?.fontFamily,
      ).merge(style.searchInputTextStyle),
      searchPlaceholderStyle: TextStyle(
        color: style.searchPlaceHolderTextColor ?? colorPalette.textTertiary,
        fontSize: typography.heading4?.regular?.fontSize,
        fontWeight: typography.heading4?.regular?.fontWeight,
        fontFamily: typography.heading4?.regular?.fontFamily,
      ).merge(style.searchPlaceHolderTextStyle),
      searchBoxBackground:
          style.searchBackgroundColor ?? colorPalette.background3,
      borderSide: style.searchBorder,
      searchTextFieldRadius:
          style.searchBorderRadius ??
          BorderRadius.circular(spacing.radiusMax ?? 0),
      appBarShape: Border(
        bottom: BorderSide(
          color:
              style.separatorColor ??
              colorPalette.borderLight ??
              Colors.transparent,
          width: style.separatorHeight ?? 1,
        ),
      ),
    );
  }

  Widget _getSelectionWidget() {
    return BlocBuilder<UsersBloc, UsersState>(
      bloc: usersBloc,
      builder: (context, state) {
        if (state is UsersLoaded && state.selectedUsers.isNotEmpty) {
          return IconButton(
            tooltip: Translations.of(context).done,
            onPressed: () {
              final selectedIds = state.selectedUsers;
              final selectedUsers = state.users
                  .where((u) => selectedIds.contains(u.uid))
                  .toList();
              widget.onSelection?.call(selectedUsers, context);
            },
            icon:
                widget.submitIcon ??
                Icon(
                  Icons.check,
                  color: style.submitIconColor ?? colorPalette.iconPrimary,
                  size: 24,
                ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
