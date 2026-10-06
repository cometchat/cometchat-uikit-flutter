import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../cometchat_chat_uikit.dart';
import '../../shared/list_options_menu.dart';

/// Internal widget for rendering the users list
class UsersList extends StatelessWidget {
  const UsersList({
    super.key,
    required this.usersBloc,
    required this.style,
    required this.colorPalette,
    required this.spacing,
    required this.typography,
    this.scrollController,
    this.loadingStateView,
    this.emptyStateView,
    this.errorStateView,
    this.listItemView,
    this.subtitleView,
    this.trailingView,
    this.leadingView,
    this.titleView,
    this.usersStatusVisibility,
    this.selectionMode,
    this.activateSelection,
    this.onItemTap,
    this.onItemLongPress,
    this.options,
    this.stickyHeaderVisibility,
    this.avatarStyle,
    this.statusIndicatorStyle,
  });

  final UsersBloc usersBloc;
  final CometChatUsersStyle style;
  final CometChatColorPalette colorPalette;
  final CometChatSpacing spacing;
  final CometChatTypography typography;
  final ScrollController? scrollController;
  final WidgetBuilder? loadingStateView;
  final WidgetBuilder? emptyStateView;
  final WidgetBuilder? errorStateView;
  final Widget Function(User)? listItemView;
  final Widget? Function(BuildContext, User)? subtitleView;
  final Widget? Function(BuildContext, User)? trailingView;
  final Widget? Function(BuildContext, User)? leadingView;
  final Widget? Function(BuildContext, User)? titleView;
  final bool? usersStatusVisibility;
  final SelectionMode? selectionMode;
  final ActivateSelection? activateSelection;
  final Function(BuildContext, User)? onItemTap;
  final Function(BuildContext, User)? onItemLongPress;

  /// Builds the menu a long press opens on a user. Nothing opens when it is
  /// null or returns no options. Starting a long-press selection comes first,
  /// then [onItemLongPress], when set, takes the long press instead.
  final List<CometChatOption> Function(BuildContext context, User user)?
  options;

  final bool? stickyHeaderVisibility;
  final CometChatAvatarStyle? avatarStyle;
  final CometChatStatusIndicatorStyle? statusIndicatorStyle;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UsersBloc, UsersState>(
      bloc: usersBloc,
      buildWhen: (previous, current) {
        if (previous.runtimeType != current.runtimeType) return true;
        if (previous is UsersLoaded && current is UsersLoaded) {
          return previous.users.length != current.users.length ||
              previous.isLoadingMore != current.isLoadingMore ||
              previous.selectedUsers != current.selectedUsers;
        }
        return true;
      },
      builder: (context, state) {
        if (state is UsersError) {
          return _buildErrorState(context, state);
        } else if (state is UsersLoading) {
          return _buildLoadingState(context);
        } else if (state is UsersEmpty) {
          return _buildEmptyState(context);
        } else if (state is UsersLoaded) {
          return _buildUsersList(context, state);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    if (loadingStateView != null) {
      return Center(child: loadingStateView!(context));
    }
    return CometChatShimmerEffect(
      colorPalette: colorPalette,
      child: ListView.builder(
        itemCount: 20,
        shrinkWrap: true,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.padding4 ?? 0,
              vertical: spacing.padding3 ?? 0,
            ),
            child: Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(right: spacing.padding3 ?? 0),
                  child: const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey,
                  ),
                ),
                Container(
                  height: 22.0,
                  width: MediaQuery.of(context).size.width * 0.4,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(spacing.radius2 ?? 0),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    if (emptyStateView != null) {
      return Center(child: emptyStateView!(context));
    }
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: spacing.padding5 ?? 0),
              child: Image.asset(
                AssetConstants(
                  CometChatThemeHelper.getBrightness(context),
                ).emptyUserList,
                package: UIConstants.packageName,
                width: 120,
                height: 120,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: spacing.padding1 ?? 0),
              child: Text(
                Translations.of(context).usersUnavailable,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: style.emptyStateTextColor ?? colorPalette.textPrimary,
                  fontSize: typography.heading3?.bold?.fontSize,
                  fontWeight: typography.heading3?.bold?.fontWeight,
                  fontFamily: typography.heading3?.bold?.fontFamily,
                ).merge(style.emptyStateTextStyle),
              ),
            ),
            Text(
              Translations.of(context).addContactsToStartConversations,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    style.emptyStateSubTitleTextColor ??
                    colorPalette.textSecondary,
                fontSize: typography.body?.regular?.fontSize,
                fontWeight: typography.body?.regular?.fontWeight,
                fontFamily: typography.body?.regular?.fontFamily,
              ).merge(style.emptyStateSubTitleTextStyle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, UsersError state) {
    if (errorStateView != null) {
      return Center(child: errorStateView!(context));
    }
    return UIStateUtils.getDefaultErrorStateView(
      context,
      colorPalette,
      typography,
      spacing,
      () => usersBloc.add(const RefreshUsers()),
      errorStateTextColor: style.errorStateTextColor,
      errorStateTextStyle: style.errorStateTextStyle,
      errorStateSubtitleColor: style.errorStateSubTitleTextColor,
      errorStateSubtitleStyle: style.errorStateSubTitleTextStyle,
      buttonTextStyle: style.retryButtonTextStyle,
      buttonTextColor: style.retryButtonTextColor,
      buttonBackgroundColor: style.retryButtonBackgroundColor,
      buttonBorderSide: style.retryButtonBorder,
      buttonBorderRadius: style.retryButtonBorderRadius,
    );
  }

  Widget _buildUsersList(BuildContext context, UsersLoaded state) {
    return ListView.builder(
      controller: scrollController,
      itemCount: state.hasMore ? state.users.length + 1 : state.users.length,
      itemBuilder: (context, index) {
        if (index >= state.users.length) {
          usersBloc.add(const LoadMoreUsers());
          return _buildLoadingIndicator();
        }
        final user = state.users[index];
        return Column(
          children: [
            if (stickyHeaderVisibility != true)
              _buildUserListDivider(state.users, index),
            _buildUserItem(context, user, state),
          ],
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: EdgeInsets.all(spacing.padding4 ?? 16),
      child: Center(
        child: CircularProgressIndicator(color: colorPalette.primary),
      ),
    );
  }

  Widget _buildUserListDivider(List<User> users, int index) {
    if (index == 0 ||
        users[index].name.substring(0, 1).toLowerCase() !=
            users[index - 1].name.substring(0, 1).toLowerCase()) {
      return Padding(
        padding: EdgeInsets.only(
          left: spacing.padding5 ?? 0,
          right: spacing.padding5 ?? 0,
          top: spacing.padding2 ?? 0,
        ),
        child: SectionSeparator(
          text: users[index].name.substring(0, 1).toUpperCase(),
          dividerColor: colorPalette.transparent,
          textStyle: TextStyle(
            color: style.stickyTitleColor ?? colorPalette.primary,
            fontSize: typography.heading4?.medium?.fontSize,
            fontWeight: typography.heading4?.medium?.fontWeight,
            fontFamily: typography.heading4?.medium?.fontFamily,
          ).merge(style.stickyTitleTextStyle),
          height: 0,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildUserItem(BuildContext context, User user, UsersLoaded state) {
    if (listItemView != null) {
      return listItemView!(user);
    }
    final isSelected = state.selectedUsers.contains(user.uid);
    final showCheckbox =
        selectionMode != null && selectionMode != SelectionMode.none;

    return ValueListenableBuilder<String>(
      valueListenable: usersBloc.getStatusNotifier(user.uid),
      builder: (context, status, child) {
        // Use the real-time status from ValueNotifier (not stale user.status)
        final isStatusVisible =
            usersStatusVisibility != false &&
            user.blockedByMe != true &&
            user.hasBlockedMe != true;
        final isOnline =
            isStatusVisible && status == UserStatusConstants.online;

        final statusColor = isOnline
            ? (statusIndicatorStyle?.backgroundColor ?? colorPalette.success)
            : null;

        return Container(
          decoration: BoxDecoration(
            color: isSelected
                ? (style.listItemSelectedBackgroundColor ??
                      colorPalette.background4)
                : colorPalette.transparent,
          ),
          child: GestureDetector(
            onTap: () => _handleItemTap(context, user, state),
            // This builder's context is the row's own, so an options menu
            // opens over the pressed row.
            onLongPress: () => _handleItemLongPress(context, user, state),
            child: Row(
              children: [
                if (showCheckbox || state.selectedUsers.isNotEmpty)
                  Checkbox(
                    fillColor: isSelected
                        ? WidgetStateProperty.all(
                            style.checkBoxCheckedBackgroundColor ??
                                colorPalette.iconHighlight,
                          )
                        : WidgetStateProperty.all(
                            style.checkBoxBackgroundColor ??
                                colorPalette.transparent,
                          ),
                    value: isSelected,
                    onChanged: (_) => _handleItemTap(context, user, state),
                    activeColor:
                        style.checkBoxCheckedBackgroundColor ??
                        colorPalette.iconHighlight,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          style.checkBoxBorderRadius ??
                          BorderRadius.circular(spacing.radius1 ?? 4),
                    ),
                    checkColor:
                        style.checkboxSelectedIconColor ?? colorPalette.white,
                    side:
                        style.checkBoxBorder ??
                        BorderSide(
                          color:
                              colorPalette.borderDefault ?? Colors.transparent,
                          width: 1.25,
                        ),
                  ),
                Expanded(
                  child: CometChatListItem(
                    id: user.uid,
                    avatarName: user.name,
                    avatarURL: user.avatar,
                    avatarHeight: 40,
                    avatarWidth: 40,
                    title: user.name,
                    subtitleView: subtitleView?.call(context, user),
                    tailView: trailingView?.call(context, user),
                    avatarStyle:
                        avatarStyle ?? CometChatAvatarStyle.of(context),
                    statusIndicatorColor: statusColor,
                    statusIndicatorIcon: null,
                    statusIndicatorStyle: CometChatStatusIndicatorStyle(
                      border:
                          statusIndicatorStyle?.border ??
                          Border.all(
                            width: spacing.spacing ?? 0,
                            color:
                                colorPalette.background1 ?? Colors.transparent,
                          ),
                      backgroundColor:
                          statusIndicatorStyle?.backgroundColor ??
                          colorPalette.success,
                    ),
                    hideSeparator: true,
                    style: ListItemStyle(
                      background: isSelected
                          ? (style.listItemSelectedBackgroundColor ??
                                colorPalette.background4)
                          : colorPalette.transparent,
                      titleStyle: TextStyle(
                        overflow: TextOverflow.ellipsis,
                        fontSize: typography.heading4?.medium?.fontSize,
                        fontWeight: typography.heading4?.medium?.fontWeight,
                        fontFamily: typography.heading4?.medium?.fontFamily,
                        color:
                            style.itemTitleTextColor ??
                            colorPalette.textPrimary,
                      ).merge(style.itemTitleTextStyle),
                      padding: EdgeInsets.only(
                        left: (showCheckbox || state.selectedUsers.isNotEmpty)
                            ? 0
                            : spacing.padding4 ?? 0,
                        right: spacing.padding4 ?? 0,
                        top: spacing.padding2 ?? 0,
                        bottom: spacing.padding2 ?? 0,
                      ),
                      border: style.itemBorder,
                    ),
                    leadingStateView: leadingView?.call(context, user),
                    titleView: titleView?.call(context, user),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleItemTap(BuildContext context, User user, UsersLoaded state) {
    if (activateSelection == ActivateSelection.onClick ||
        (activateSelection == ActivateSelection.onLongClick &&
            state.selectedUsers.isNotEmpty)) {
      usersBloc.add(ToggleUserSelection(user.uid));
    } else if (onItemTap != null) {
      onItemTap!(context, user);
    }
  }

  /// [rowContext] is the pressed row's own context, so the options menu
  /// opens over that row.
  void _handleItemLongPress(
    BuildContext rowContext,
    User user,
    UsersLoaded state,
  ) {
    if (activateSelection == ActivateSelection.onLongClick &&
        state.selectedUsers.isEmpty) {
      usersBloc.add(ToggleUserSelection(user.uid));
    } else if (onItemLongPress != null) {
      onItemLongPress!(rowContext, user);
    } else if (options != null) {
      showListOptionsMenu(
        rowContext: rowContext,
        options: options!(rowContext, user),
        colorPalette: colorPalette,
        spacing: spacing,
      );
    }
  }
}
