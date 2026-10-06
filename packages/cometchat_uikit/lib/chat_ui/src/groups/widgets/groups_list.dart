import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../cometchat_chat_uikit.dart';
import '../../shared/list_options_menu.dart';

/// A widget that displays the list of groups with state handling and pagination.
///
/// This widget uses [BlocBuilder] to listen to [GroupsBloc] and renders
/// the appropriate view based on the current state:
/// - [GroupsLoading] → Loading view with shimmer effect
/// - [GroupsEmpty] → Empty state view
/// - [GroupsError] → Error view with retry button
/// - [GroupsLoaded] → ListView.builder with [CometChatGroupListItem]
///
/// The widget handles pagination by dispatching [LoadMoreGroups] event
/// when the user scrolls to the bottom of the list.
///
/// ## Usage
///
/// ```dart
/// GroupsList(
///   groupsBloc: groupsBloc,
///   style: CometChatGroupsStyle(),
///   colorPalette: colorPalette,
///   spacing: spacing,
///   typography: typography,
///   onItemTap: (context, group) => navigateToGroup(group),
/// )
/// ```
///
/// Requirements: 5.2, 5.6
class GroupsList extends StatelessWidget {
  const GroupsList({
    super.key,
    required this.groupsBloc,
    required this.style,
    required this.colorPalette,
    required this.spacing,
    required this.typography,
    this.scrollController,
    this.loadingStateView,
    this.emptyStateView,
    this.errorStateView,
    this.hideError,
    this.listItemView,
    this.subtitleView,
    this.trailingView,
    this.leadingView,
    this.titleView,
    this.hideGroupTypeIcon,
    this.selectionMode,
    this.activateSelection,
    this.onItemTap,
    this.onItemLongPress,
    this.options,
    this.avatarStyle,
    this.statusIndicatorStyle,
    this.privateGroupIcon,
    this.protectedGroupIcon,
  });

  /// The BLoC managing groups state.
  final GroupsBloc groupsBloc;

  /// The style configuration for the groups widget.
  final CometChatGroupsStyle style;

  /// The color palette used for styling.
  final CometChatColorPalette colorPalette;

  /// The spacing configuration for padding and margins.
  final CometChatSpacing spacing;

  /// The typography configuration for text styles.
  final CometChatTypography typography;

  /// Optional scroll controller for the list.
  final ScrollController? scrollController;

  /// Custom loading state view builder.
  final WidgetBuilder? loadingStateView;

  /// Custom empty state view builder.
  final WidgetBuilder? emptyStateView;

  /// Custom error state view builder.
  final WidgetBuilder? errorStateView;

  /// Hides the error view, including a custom [errorStateView], when true.
  /// Matches CometChatGroupMembers.
  final bool? hideError;

  /// Custom list item view builder for full customization.
  /// When provided, this completely replaces the default [CometChatGroupListItem].
  final Widget Function(Group)? listItemView;

  /// Custom subtitle view builder.
  final Widget? Function(BuildContext, Group)? subtitleView;

  /// Custom trailing view builder.
  final Widget? Function(BuildContext, Group)? trailingView;

  /// Custom leading view builder.
  final Widget? Function(BuildContext, Group)? leadingView;

  /// Custom title view builder.
  final Widget? Function(BuildContext, Group)? titleView;

  /// Whether to hide the group type icon (private/password indicators).
  final bool? hideGroupTypeIcon;

  /// The selection mode for the groups list.
  final SelectionMode? selectionMode;

  /// When selection should be activated.
  final ActivateSelection? activateSelection;

  /// Callback when an item is tapped.
  final Function(BuildContext, Group)? onItemTap;

  /// Callback when an item is long-pressed.
  final Function(BuildContext, Group)? onItemLongPress;

  /// Builds the menu a long press opens on a group. Nothing opens when it is
  /// null or returns no options. [onItemLongPress], when set, takes the long
  /// press instead, and starting a long-press selection comes first.
  final List<CometChatOption> Function(BuildContext context, Group group)?
  options;

  /// Style for the avatar.
  final CometChatAvatarStyle? avatarStyle;

  /// Style for the status indicator.
  final CometChatStatusIndicatorStyle? statusIndicatorStyle;

  /// Custom icon for private groups.
  final Widget? privateGroupIcon;

  /// Custom icon for protected (password) groups.
  final Widget? protectedGroupIcon;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GroupsBloc, GroupsState>(
      bloc: groupsBloc,
      // Optimization: Only rebuild on state type changes or significant data changes
      // Requirement: 5.6
      buildWhen: (previous, current) {
        // Always rebuild if state type changes
        if (previous.runtimeType != current.runtimeType) return true;

        // For GroupsLoaded, rebuild on list length, loading more, or selection changes
        if (previous is GroupsLoaded && current is GroupsLoaded) {
          return previous.groups.length != current.groups.length ||
              previous.isLoadingMore != current.isLoadingMore ||
              previous.selectedGroups != current.selectedGroups;
        }
        return true;
      },
      builder: (context, state) {
        // Handle error state
        if (state is GroupsError) {
          if (hideError == true) return const SizedBox.shrink();
          return _buildErrorState(context, state);
        }

        // Handle loading state
        if (state is GroupsLoading) {
          return _buildLoadingState(context);
        }

        // Handle empty state
        if (state is GroupsEmpty) {
          return _buildEmptyState(context);
        }

        // Handle loaded state
        if (state is GroupsLoaded) {
          return _buildGroupsList(context, state);
        }

        // Default to loading view for initial/unknown states
        return _buildLoadingState(context);
      },
    );
  }

  /// Builds the loading state view with shimmer effect.
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16.0,
                        width: MediaQuery.of(context).size.width * 0.4,
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(
                            spacing.radius2 ?? 0,
                          ),
                        ),
                      ),
                      SizedBox(height: spacing.padding1 ?? 4),
                      Container(
                        height: 12.0,
                        width: MediaQuery.of(context).size.width * 0.25,
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(
                            spacing.radius2 ?? 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds the empty state view.
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
                ).emptyGroupList,
                package: UIConstants.packageName,
                width: 120,
                height: 120,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: spacing.padding1 ?? 0),
              child: Text(
                Translations.of(context).noGroupsFound,
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
              'Create or join groups to see them listed here\nand start collaborating.',
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

  /// Builds the error state view with retry button.
  Widget _buildErrorState(BuildContext context, GroupsError state) {
    if (hideError == true) {
      return const SizedBox();
    }
    if (errorStateView != null) {
      return Center(child: errorStateView!(context));
    }
    return UIStateUtils.getDefaultErrorStateView(
      context,
      colorPalette,
      typography,
      spacing,
      () => groupsBloc.add(const RefreshGroups()),
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

  /// Builds the groups list for the loaded state.
  Widget _buildGroupsList(BuildContext context, GroupsLoaded state) {
    final groups = state.groups;
    final hasMore = state.hasMore;
    final selectedGroups = state.selectedGroups;

    return ListView.builder(
      controller: scrollController,
      itemCount: hasMore ? groups.length + 1 : groups.length,
      itemBuilder: (context, index) {
        // Handle pagination - load more when reaching the end
        if (index >= groups.length) {
          groupsBloc.add(const LoadMoreGroups());
          return _buildLoadingIndicator();
        }

        final group = groups[index];
        return _buildGroupItem(context, group, selectedGroups);
      },
    );
  }

  /// Builds the loading indicator for pagination.
  Widget _buildLoadingIndicator() {
    return Padding(
      padding: EdgeInsets.all(spacing.padding4 ?? 16),
      child: Center(
        child: CircularProgressIndicator(color: colorPalette.primary),
      ),
    );
  }

  /// Builds a single group item.
  Widget _buildGroupItem(
    BuildContext context,
    Group group,
    Set<String> selectedGroups,
  ) {
    // Use custom listItemView if provided for full customization
    if (listItemView != null) {
      return listItemView!(group);
    }

    final isSelected = selectedGroups.contains(group.guid);

    // The row's own context anchors the options menu on the row.
    return Builder(
      builder: (rowContext) => _buildGroupListItem(
        context,
        rowContext,
        group,
        selectedGroups,
        isSelected,
      ),
    );
  }

  Widget _buildGroupListItem(
    BuildContext context,
    BuildContext rowContext,
    Group group,
    Set<String> selectedGroups,
    bool isSelected,
  ) {
    return CometChatGroupListItem(
      group: group,
      onItemClick: (g) => _handleItemTap(context, g, selectedGroups),
      onItemLongClick:
          onItemLongPress != null ||
              options != null ||
              activateSelection == ActivateSelection.onLongClick
          ? (g) => _handleItemLongPress(context, g, selectedGroups, rowContext)
          : null,
      onSelectionToggle: () => _handleSelectionToggle(group),
      isSelected: isSelected,
      selectionMode: selectionMode ?? SelectionMode.none,
      hideGroupTypeIcon: hideGroupTypeIcon ?? false,
      avatarStyle: avatarStyle ?? style.avatarStyle,
      statusIndicatorStyle: statusIndicatorStyle ?? style.statusIndicatorStyle,
      privateGroupIcon: privateGroupIcon,
      protectedGroupIcon: protectedGroupIcon,
      privateGroupIconBackground: style.privateGroupIconBackground,
      protectedGroupIconBackground: style.protectedGroupIconBackground,
      colorPalette: colorPalette,
      spacing: spacing,
      typography: typography,
      // Pass custom view slots
      leadingView: leadingView != null ? (g) => leadingView!(context, g) : null,
      titleView: titleView != null ? (g) => titleView!(context, g) : null,
      subtitleView: subtitleView != null
          ? (g) => subtitleView!(context, g)
          : null,
      trailingView: trailingView != null
          ? (g) => trailingView!(context, g)
          : null,
      // Pass item-level styles from CometChatGroupsStyle
      style: CometChatGroupListItemStyle(
        titleTextStyle: style.itemTitleTextStyle,
        titleTextColor: style.itemTitleTextColor,
        subtitleTextStyle: style.itemSubtitleTextStyle,
        subtitleTextColor: style.itemSubtitleTextColor,
        selectedBackgroundColor: style.listItemSelectedBackgroundColor,
        checkBoxBackgroundColor: style.checkBoxBackgroundColor,
        checkBoxCheckedBackgroundColor: style.checkBoxCheckedBackgroundColor,
        // Resolved rather than cast: the style takes any geometry, and a
        // BorderRadiusDirectional used to throw here.
        checkBoxBorderRadius: style.checkBoxBorderRadius?.resolve(
          Directionality.of(context),
        ),
        checkBoxStrokeColor: style.checkBoxBorder?.color,
        checkBoxStrokeWidth: style.checkBoxBorder?.width,
        checkBoxCheckColor: style.checkboxSelectedIconColor,
        privateGroupIconBackground: style.privateGroupIconBackground,
        protectedGroupIconBackground: style.protectedGroupIconBackground,
      ),
    );
  }

  /// Handles tap on a group item.
  void _handleItemTap(
    BuildContext context,
    Group group,
    Set<String> selectedGroups,
  ) {
    // If selection mode is active, toggle selection
    if ((activateSelection == ActivateSelection.onClick ||
            (activateSelection == ActivateSelection.onLongClick &&
                selectedGroups.isNotEmpty)) &&
        !(selectionMode == null || selectionMode == SelectionMode.none)) {
      groupsBloc.add(ToggleGroupSelection(group.guid));
    } else if (onItemTap != null) {
      onItemTap!(context, group);
    }
  }

  /// Handles long press on a group item.
  void _handleItemLongPress(
    BuildContext context,
    Group group,
    Set<String> selectedGroups,
    BuildContext rowContext,
  ) {
    // If selection mode is active and no items selected, start selection
    if (activateSelection == ActivateSelection.onLongClick &&
        selectedGroups.isEmpty &&
        !(selectionMode == null || selectionMode == SelectionMode.none)) {
      groupsBloc.add(ToggleGroupSelection(group.guid));
    } else if (onItemLongPress != null) {
      onItemLongPress!(context, group);
    } else if (options != null) {
      showListOptionsMenu(
        rowContext: rowContext,
        options: options!(rowContext, group),
        colorPalette: colorPalette,
        spacing: spacing,
      );
    }
  }

  /// Handles selection toggle for a group.
  void _handleSelectionToggle(Group group) {
    groupsBloc.add(ToggleGroupSelection(group.guid));
  }
}
