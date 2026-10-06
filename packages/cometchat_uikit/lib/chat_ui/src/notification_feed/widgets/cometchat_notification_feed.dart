import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

/// A full-screen notification feed component that displays campaign/promotional
/// notifications in a scrollable list with category-based filtering, timestamp
/// grouping, rich card rendering, real-time updates, and engagement reporting.
class CometChatNotificationFeed extends StatefulWidget {
  /// Title displayed in the header.
  final String title;

  /// Whether to show the header.
  final bool showHeader;

  /// Whether to show the back button in the header.
  final bool showBackButton;

  /// Whether to show filter chips row.
  final bool showFilterChips;

  /// Custom header view to replace the default header.
  final Widget? headerView;

  /// Deep link: scroll to a specific item by ID.
  final String? scrollToItemId;

  /// Custom request builder for feed items.
  final NotificationFeedRequestBuilder? notificationFeedRequestBuilder;

  /// Custom request builder for categories.
  final NotificationCategoriesRequestBuilder?
  notificationCategoriesRequestBuilder;

  /// Callback when a feed item card is tapped.
  final void Function(NotificationFeedItem feedItem)? onItemClick;

  /// Callback when an action button within a card is tapped.
  final void Function(
    NotificationFeedItem feedItem,
    CometChatCardActionEvent action,
  )?
  onActionClick;

  /// Callback when an error occurs.
  final void Function(String error)? onError;

  /// Callback when back button is pressed.
  final VoidCallback? onBackPress;

  /// Custom empty state view.
  final Widget? emptyStateView;

  /// Custom error state view.
  final Widget? errorStateView;

  /// Custom loading state view.
  final Widget? loadingStateView;

  /// Style configuration for the notification feed.
  final CometChatNotificationFeedStyle? style;

  /// Theme mode forwarded to CometChatCardView.
  final CometChatCardThemeMode? cardThemeMode;

  /// Theme override forwarded to CometChatCardView.
  final CometChatCardThemeOverride? cardThemeOverride;

  ///[notificationFeedBloc] Optional external NotificationFeedBloc instance.
  ///If provided, it is used instead of creating one internally and the widget
  ///does not close it on dispose. Mirrors
  ///[CometChatConversations.conversationsBloc] and
  ///[CometChatGroupMembers.groupMembersBloc] — the seam that lets a test
  ///supply feed data without a live SDK.
  final NotificationFeedBloc? notificationFeedBloc;

  const CometChatNotificationFeed({
    super.key,
    this.title = 'Notifications',
    this.showHeader = true,
    this.showBackButton = false,
    this.showFilterChips = true,
    this.headerView,
    this.scrollToItemId,
    this.notificationFeedRequestBuilder,
    this.notificationCategoriesRequestBuilder,
    this.onItemClick,
    this.onActionClick,
    this.onError,
    this.onBackPress,
    this.emptyStateView,
    this.errorStateView,
    this.loadingStateView,
    this.style,
    this.cardThemeMode,
    this.cardThemeOverride,
    this.notificationFeedBloc,
  });

  @override
  State<CometChatNotificationFeed> createState() =>
      _CometChatNotificationFeedState();
}

class _CometChatNotificationFeedState extends State<CometChatNotificationFeed> {
  late NotificationFeedBloc _bloc;
  bool _isExternalBloc = false;
  late FeedVisibilityTracker _visibilityTracker;
  late ScrollController _scrollController;
  CometChatNotificationFeedStyle _style =
      const CometChatNotificationFeedStyle();
  CometChatCardThemeOverride? _resolvedCardThemeOverride;

  static const double _paginationThreshold = 200.0;

  @override
  void initState() {
    super.initState();
    if (widget.notificationFeedBloc != null) {
      // An externally supplied bloc owns its own dependencies and lifecycle.
      _bloc = widget.notificationFeedBloc!;
      _isExternalBloc = true;
    } else {
      _bloc = NotificationFeedBloc(
        notificationFeedRequestBuilder: widget.notificationFeedRequestBuilder,
        notificationCategoriesRequestBuilder:
            widget.notificationCategoriesRequestBuilder,
      );
      _isExternalBloc = false;
    }
    _visibilityTracker = FeedVisibilityTracker(bloc: _bloc);
    _scrollController = ScrollController()..addListener(_onScroll);

    // Handle deep linking after initial load
    if (widget.scrollToItemId != null) {
      _handleScrollToItem(widget.scrollToItemId!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-resolve style every time dependencies change (theme/brightness switch)
    // so the feed reacts to live dark mode toggles without requiring navigation.
    _style = CometChatNotificationFeedStyle.of(context).merge(widget.style);
    // Build a card theme override from the UIKit color palette so card
    // renderer fallback colors match the UIKit's light/dark theme.
    if (widget.cardThemeOverride == null) {
      final colorPalette = CometChatThemeHelper.getColorPalette(context);
      _resolvedCardThemeOverride = CometChatCardThemeOverride(
        textColor: _colorValueFromPalette(colorPalette.textPrimary),
        secondaryTextColor: _colorValueFromPalette(colorPalette.textSecondary),
        backgroundColor: _colorValueFromPalette(colorPalette.background2),
        borderColor: _colorValueFromPalette(colorPalette.borderLight),
        dividerColor: _colorValueFromPalette(colorPalette.borderLight),
        buttonFilledBg: _colorValueFromPalette(colorPalette.primary),
        buttonFilledText: _colorValueFromPalette(colorPalette.buttonText),
        linkColor: _colorValueFromPalette(colorPalette.primary),
      );
    }
  }

  /// Converts a single Color to a CometChatCardColorValue where both light
  /// and dark use the same resolved color (since the palette is already
  /// resolved for the current brightness).
  CometChatCardColorValue? _colorValueFromPalette(Color? color) {
    if (color == null) return null;
    final hex =
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    return CometChatCardColorValue(light: hex, dark: hex);
  }

  @override
  void dispose() {
    _visibilityTracker.dispose();
    _scrollController.dispose();
    if (!_isExternalBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - _paginationThreshold) {
      _bloc.add(const LoadMoreFeedItems());
    }
  }

  Future<void> _handleScrollToItem(String itemId) async {
    // Wait for initial load, then check if item exists
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final state = _bloc.state;
    final index = state.items.indexWhere((item) => item.id == itemId);

    if (index >= 0) {
      // Item found in list, scroll to it
      // Approximate position based on index
      unawaited(
        _scrollController.animateTo(
          index * 120.0, // Approximate card height
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
      );
    } else {
      // Item not found, fetch it and prepend
      final result = await _bloc.getFeedItem(itemId);
      result.fold(
        (_) {}, // Item not found, do nothing
        (item) {
          _bloc.add(FeedItemReceived(item));
          // Scroll to top where the item was inserted
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: _style.backgroundColor,
        appBar: widget.showHeader ? _buildAppBar() : null,
        body: Column(
          children: [
            if (widget.showFilterChips) _buildFilterChips(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (widget.headerView != null) {
      return PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: widget.headerView!,
      );
    }

    return AppBar(
      backgroundColor: _style.backgroundColor,
      elevation: 0,
      centerTitle: false,
      leading: widget.showBackButton
          ? IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: _style.backIconColor,
                semanticLabel: Translations.of(context).back,
              ),
              onPressed:
                  widget.onBackPress ?? () => Navigator.of(context).pop(),
            )
          : null,
      automaticallyImplyLeading: widget.showBackButton,
      title: Text(
        widget.title,
        style:
            (_style.headerTitleTextStyle ??
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
                .copyWith(color: _style.headerTitleColor),
      ),
    );
  }

  Widget _buildFilterChips() {
    return BlocBuilder<NotificationFeedBloc, NotificationFeedState>(
      buildWhen: (previous, current) =>
          previous.categories != current.categories ||
          previous.activeCategory != current.activeCategory ||
          previous.categoryUnreadCounts != current.categoryUnreadCounts ||
          previous.totalUnreadCount != current.totalUnreadCount ||
          previous.screenState != current.screenState,
      builder: (context, state) {
        // Hide chips during initial loading (no categories fetched yet)
        if (state.screenState == NotificationFeedScreenState.loading &&
            state.categories.isEmpty) {
          return const SizedBox.shrink();
        }
        return NotificationFeedFilterChips(
          categories: state.categories,
          activeCategory: state.activeCategory,
          totalUnreadCount: state.totalUnreadCount,
          categoryUnreadCounts: state.categoryUnreadCounts,
          style: _style,
          onCategorySelected: (categoryId) {
            _bloc.add(SwitchCategory(categoryId));
          },
        );
      },
    );
  }

  Widget _buildContent() {
    return BlocConsumer<NotificationFeedBloc, NotificationFeedState>(
      buildWhen: (previous, current) =>
          previous.screenState != current.screenState ||
          previous.items != current.items ||
          previous.isLoadingMore != current.isLoadingMore,
      listener: (context, state) {
        if (state.screenState == NotificationFeedScreenState.error &&
            state.error != null) {
          widget.onError?.call(state.error!);
        }
      },
      builder: (context, state) {
        switch (state.screenState) {
          case NotificationFeedScreenState.loading:
            return _buildLoadingView();
          case NotificationFeedScreenState.empty:
            return _buildEmptyView();
          case NotificationFeedScreenState.error:
            return _buildErrorView(state.error ?? 'Something went wrong');
          case NotificationFeedScreenState.loaded:
            return _buildFeedList(state);
        }
      },
    );
  }

  Widget _buildLoadingView() {
    if (widget.loadingStateView != null) {
      return widget.loadingStateView!;
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading...',
            style: TextStyle(
              fontSize: 14,
              color: _style.emptyStateSubtitleTextColor ?? Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    if (widget.emptyStateView != null) {
      return widget.emptyStateView!;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.move_to_inbox_outlined,
              size: 64,
              color:
                  _style.emptyStateTextColor?.withValues(alpha: 0.5) ??
                  Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing here yet',
              style:
                  (_style.emptyStateTextStyle ??
                          const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ))
                      .copyWith(color: _style.emptyStateTextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'New activity will appear here when available.',
              style:
                  (_style.emptyStateSubtitleTextStyle ??
                          const TextStyle(fontSize: 14))
                      .copyWith(color: _style.emptyStateSubtitleTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String errorMessage) {
    if (widget.errorStateView != null) {
      return widget.errorStateView!;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color:
                  _style.errorStateTextColor?.withValues(alpha: 0.5) ??
                  Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style:
                  (_style.errorStateTextStyle ??
                          const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ))
                      .copyWith(color: _style.errorStateTextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style:
                  (_style.errorStateSubtitleTextStyle ??
                          const TextStyle(fontSize: 14))
                      .copyWith(color: _style.errorStateSubtitleTextColor),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _bloc.add(const LoadNotificationFeed()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _style.retryButtonBackgroundColor,
              ),
              child: Text(
                'Retry',
                style: (_style.retryButtonTextStyle ?? const TextStyle())
                    .copyWith(color: _style.retryButtonTextColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedList(NotificationFeedState state) {
    return RefreshIndicator(
      onRefresh: () async {
        _bloc.add(const RefreshFeed());
        // Wait for refresh to complete
        await _bloc.stream
            .firstWhere((s) => !s.isRefreshing)
            .timeout(const Duration(seconds: 10), onTimeout: () => _bloc.state);
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Loading indicator at bottom
          if (index >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return _buildFeedItemCard(state.items[index]);
        },
      ),
    );
  }

  Widget _buildFeedItemCard(NotificationFeedItem item) {
    // Resolve card theme mode from CometChatThemeMode when not explicitly set.
    // CometChatCardView.auto uses MediaQuery.platformBrightnessOf which doesn't
    // respect CometChatThemeMode forced light/dark. Map it explicitly.
    final CometChatCardThemeMode resolvedCardThemeMode;
    if (widget.cardThemeMode != null) {
      resolvedCardThemeMode = widget.cardThemeMode!;
    } else if (CometChatThemeMode.mode == ThemeMode.light) {
      resolvedCardThemeMode = CometChatCardThemeMode.light;
    } else if (CometChatThemeMode.mode == ThemeMode.dark) {
      resolvedCardThemeMode = CometChatCardThemeMode.dark;
    } else {
      resolvedCardThemeMode = CometChatCardThemeMode.auto;
    }

    return FeedItemCard(
      key: ValueKey(item.id),
      feedItem: item,
      style: _style,
      cardThemeMode: resolvedCardThemeMode,
      cardThemeOverride: widget.cardThemeOverride ?? _resolvedCardThemeOverride,
      visibilityTracker: _visibilityTracker,
      onItemClick: widget.onItemClick,
      onActionClick: widget.onActionClick,
      onClicked: () {
        _bloc.add(ReportClicked(item));
      },
    );
  }
}
