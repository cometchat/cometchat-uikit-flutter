import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import '../../../../shared_ui/src/clean_architecture/core/result.dart';
import '../di/notification_feed_service_locator.dart';
import '../domain/usecases/get_feed_items_usecase.dart';
import '../domain/usecases/get_categories_usecase.dart';
import '../domain/usecases/mark_feed_delivered_usecase.dart';
import '../domain/usecases/mark_feed_read_usecase.dart';
import '../domain/usecases/report_feed_engagement_usecase.dart';
import '../domain/usecases/get_unread_count_usecase.dart';
import '../domain/usecases/get_feed_item_usecase.dart';
import 'notification_feed_event.dart';
import 'notification_feed_state.dart';
import '../../../../shared_ui/src/logging/cometchat_log.dart';

/// BLoC for managing the notification feed lifecycle.
///
/// Handles:
/// - Loading and pagination of feed items
/// - Category filtering
/// - Real-time updates via NotificationFeedListener
/// - Engagement reporting (delivered, viewed, read, clicked)
/// - Unread count polling
/// - Connection state (offline/online)
class NotificationFeedBloc
    extends Bloc<NotificationFeedEvent, NotificationFeedState>
    with NotificationFeedListener {
  // Use cases
  final GetFeedItemsUseCase _getFeedItemsUseCase;
  final GetCategoriesUseCase _getCategoriesUseCase;
  final MarkFeedDeliveredUseCase _markFeedDeliveredUseCase;
  final MarkFeedReadUseCase _markFeedReadUseCase;
  final ReportFeedEngagementUseCase _reportFeedEngagementUseCase;
  final GetUnreadCountUseCase _getUnreadCountUseCase;
  final GetFeedItemUseCase _getFeedItemUseCase;

  // SDK request objects (manage cursor-based pagination internally)
  NotificationFeedRequest? _feedRequest;
  NotificationCategoriesRequest? _categoriesRequest;

  // Builder configuration (provided externally or defaults)
  final NotificationFeedRequestBuilder? _externalFeedRequestBuilder;
  final NotificationCategoriesRequestBuilder? _externalCategoriesRequestBuilder;

  /// The request builder the feed was configured with, if any. Exposed so the
  /// value can be observed where it lands rather than only where it was set.
  NotificationFeedRequestBuilder? get feedRequestBuilder =>
      _externalFeedRequestBuilder;

  /// The categories request builder the feed was configured with, if any.
  NotificationCategoriesRequestBuilder? get categoriesRequestBuilder =>
      _externalCategoriesRequestBuilder;

  /// Whether to disable SDK listeners (for testing or web platform).
  final bool disableSDKListeners;

  // Engagement tracking — avoid duplicate reporting
  final Set<String> _deliveredItemIds = {};
  final Set<String> _viewedItemIds = {};

  // O(1) item lookup by ID
  final Map<String, int> _itemIndexMap = {};

  // Unread count polling timer
  Timer? _unreadCountTimer;
  static const Duration _unreadCountPollInterval = Duration(seconds: 30);

  // Connection listener ID
  final String _connectionListenerKey =
      'notification_feed_bloc_connection_${DateTime.now().millisecondsSinceEpoch}';

  // Notification feed listener ID
  final String _feedListenerKey =
      'notification_feed_bloc_feed_${DateTime.now().millisecondsSinceEpoch}';

  // Generation counter for category switch cancellation
  int _fetchGeneration = 0;

  /// Helper to get initialized service locator.
  static NotificationFeedServiceLocator _getServiceLocator() {
    if (!NotificationFeedServiceLocator.instance.isInitialized) {
      NotificationFeedServiceLocator.instance.setup();
    }
    return NotificationFeedServiceLocator.instance;
  }

  /// Creates a NotificationFeedBloc.
  ///
  /// All use cases are optional — if not provided, they will be automatically
  /// initialized from the default service locator.
  NotificationFeedBloc({
    GetFeedItemsUseCase? getFeedItemsUseCase,
    GetCategoriesUseCase? getCategoriesUseCase,
    MarkFeedDeliveredUseCase? markFeedDeliveredUseCase,
    MarkFeedReadUseCase? markFeedReadUseCase,
    ReportFeedEngagementUseCase? reportFeedEngagementUseCase,
    GetUnreadCountUseCase? getUnreadCountUseCase,
    GetFeedItemUseCase? getFeedItemUseCase,
    NotificationFeedRequestBuilder? notificationFeedRequestBuilder,
    NotificationCategoriesRequestBuilder? notificationCategoriesRequestBuilder,
    this.disableSDKListeners = false,
  }) : _getFeedItemsUseCase =
           getFeedItemsUseCase ?? _getServiceLocator().getFeedItemsUseCase,
       _getCategoriesUseCase =
           getCategoriesUseCase ?? _getServiceLocator().getCategoriesUseCase,
       _markFeedDeliveredUseCase =
           markFeedDeliveredUseCase ??
           _getServiceLocator().markFeedDeliveredUseCase,
       _markFeedReadUseCase =
           markFeedReadUseCase ?? _getServiceLocator().markFeedReadUseCase,
       _reportFeedEngagementUseCase =
           reportFeedEngagementUseCase ??
           _getServiceLocator().reportFeedEngagementUseCase,
       _getUnreadCountUseCase =
           getUnreadCountUseCase ?? _getServiceLocator().getUnreadCountUseCase,
       _getFeedItemUseCase =
           getFeedItemUseCase ?? _getServiceLocator().getFeedItemUseCase,
       _externalFeedRequestBuilder = notificationFeedRequestBuilder,
       _externalCategoriesRequestBuilder = notificationCategoriesRequestBuilder,
       super(NotificationFeedState()) {
    // Register event handlers
    on<LoadNotificationFeed>(_onLoadNotificationFeed);
    on<LoadMoreFeedItems>(_onLoadMoreFeedItems);
    on<RefreshFeed>(_onRefreshFeed);
    on<SwitchCategory>(_onSwitchCategory);
    on<FeedItemReceived>(_onFeedItemReceived);
    on<FeedItemRetracted>(_onFeedItemRetracted);
    on<MarkItemAsRead>(_onMarkItemAsRead);
    on<ReportDelivered>(_onReportDelivered);
    on<ReportViewed>(_onReportViewed);
    on<ReportClicked>(_onReportClicked);
    on<UpdateUnreadCounts>(_onUpdateUnreadCounts);
    on<ConnectionStateChanged>(_onConnectionStateChanged);

    // Register real-time listener (skip in tests)
    if (!disableSDKListeners) {
      CometChat.addNotificationFeedListener(_feedListenerKey, this);

      // Register connection listener
      CometChat.addConnectionListener(
        _connectionListenerKey,
        _NotificationFeedConnectionListener(
          onConnectedCallback: () {
            if (!isClosed) {
              add(const ConnectionStateChanged(false));
            }
          },
          onDisconnectedCallback: () {
            if (!isClosed) {
              add(const ConnectionStateChanged(true));
            }
          },
        ),
      );
    }

    // Start unread count polling
    _startUnreadCountPolling();

    // Trigger initial load
    add(const LoadNotificationFeed());
  }

  // ============================================================
  // NotificationFeedListener callback
  // ============================================================

  @override
  void onFeedItemReceived(NotificationFeedItem feedItem) {
    if (!isClosed) {
      add(FeedItemReceived(feedItem));
    }
  }

  // ============================================================
  // O(1) LOOKUP HELPERS
  // ============================================================

  void _rebuildIndexMap(List<NotificationFeedItem> items) {
    _itemIndexMap.clear();
    for (int i = 0; i < items.length; i++) {
      _itemIndexMap[items[i].id] = i;
    }
  }

  int? _findItemIndex(String itemId) {
    return _itemIndexMap[itemId];
  }

  // ============================================================
  // UNREAD COUNT HELPERS
  // ============================================================

  Map<String, int> _computeCategoryUnreadCounts(
    List<NotificationFeedItem> items,
  ) {
    final counts = <String, int>{};
    for (final item in items) {
      if (item.readAt == null) {
        // Use categoryId as key (matches NotificationCategory.id used by filter chips).
        // Fall back to category name for items without categoryId.
        final key = item.categoryId ?? item.category;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    return counts;
  }

  int _computeTotalUnreadCount(List<NotificationFeedItem> items) {
    return items.where((item) => item.readAt == null).length;
  }

  // ============================================================
  // EVENT HANDLERS
  // ============================================================

  /// Load initial notification feed: categories + first page of items.
  Future<void> _onLoadNotificationFeed(
    LoadNotificationFeed event,
    Emitter<NotificationFeedState> emit,
  ) async {
    emit(
      state.copyWith(
        screenState: NotificationFeedScreenState.loading,
        clearError: true,
      ),
    );

    final currentGeneration = ++_fetchGeneration;

    // 1. Fetch categories (graceful failure = empty list)
    List<NotificationCategory> categories = [];
    _categoriesRequest =
        (_externalCategoriesRequestBuilder ??
                NotificationCategoriesRequestBuilder())
            .build();

    final categoriesResult = await _getCategoriesUseCase(_categoriesRequest!);
    categoriesResult.fold(
      (failure) {
        if (kDebugMode) {
          ccLog(
            '[NotificationFeedBloc] Categories fetch failed: ${failure.message}',
          );
        }
      },
      (data) {
        categories = data;
      },
    );

    // Check if a newer fetch has been triggered (category switch during load)
    if (currentGeneration != _fetchGeneration) return;

    // 2. Fetch first page of items
    _feedRequest =
        (_externalFeedRequestBuilder ?? NotificationFeedRequestBuilder())
            .build();

    final itemsResult = await _getFeedItemsUseCase(_feedRequest!);

    // Check generation again after async gap
    if (currentGeneration != _fetchGeneration) return;

    itemsResult.fold(
      (failure) {
        emit(
          state.copyWith(
            screenState: NotificationFeedScreenState.error,
            error: failure.message,
            categories: categories,
          ),
        );
      },
      (items) {
        _rebuildIndexMap(items);
        final categoryUnreadCounts = _computeCategoryUnreadCounts(items);
        final totalUnread = _computeTotalUnreadCount(items);

        if (items.isEmpty) {
          emit(
            state.copyWith(
              screenState: NotificationFeedScreenState.empty,
              items: items,
              categories: categories,
              categoryUnreadCounts: categoryUnreadCounts,
              totalUnreadCount: totalUnread,
              hasMorePages: false,
            ),
          );
        } else {
          emit(
            state.copyWith(
              screenState: NotificationFeedScreenState.loaded,
              items: items,
              categories: categories,
              categoryUnreadCounts: categoryUnreadCounts,
              totalUnreadCount: totalUnread,
              hasMorePages: items.isNotEmpty,
            ),
          );
        }

        // Mark all fetched items as delivered (fire-and-forget)
        _markItemsAsDelivered(items);
      },
    );
  }

  /// Load more feed items (pagination).
  Future<void> _onLoadMoreFeedItems(
    LoadMoreFeedItems event,
    Emitter<NotificationFeedState> emit,
  ) async {
    // Guard: don't load if no more pages or already loading
    if (!state.hasMorePages || state.isLoadingMore) return;
    if (_feedRequest == null) return;

    emit(state.copyWith(isLoadingMore: true));

    final result = await _getFeedItemsUseCase(_feedRequest!);

    result.fold(
      (failure) {
        // Pagination failure: show inline error, keep existing items
        emit(state.copyWith(isLoadingMore: false));
        if (kDebugMode) {
          ccLog('[NotificationFeedBloc] Pagination failed: ${failure.message}');
        }
      },
      (newItems) {
        if (newItems.isEmpty) {
          emit(state.copyWith(isLoadingMore: false, hasMorePages: false));
          return;
        }

        final allItems = [...state.items, ...newItems];
        _rebuildIndexMap(allItems);
        final categoryUnreadCounts = _computeCategoryUnreadCounts(allItems);
        final totalUnread = _computeTotalUnreadCount(allItems);

        emit(
          state.copyWith(
            items: allItems,
            isLoadingMore: false,
            categoryUnreadCounts: categoryUnreadCounts,
            totalUnreadCount: totalUnread,
          ),
        );

        // Mark new items as delivered
        _markItemsAsDelivered(newItems);
      },
    );
  }

  /// Switch category filter.
  Future<void> _onSwitchCategory(
    SwitchCategory event,
    Emitter<NotificationFeedState> emit,
  ) async {
    // If same category, do nothing
    if (event.categoryId == state.activeCategory) return;

    final currentGeneration = ++_fetchGeneration;

    emit(
      state.copyWith(
        screenState: NotificationFeedScreenState.loading,
        activeCategory: event.categoryId,
        clearActiveCategory: event.categoryId == null,
        items: [],
        hasMorePages: true,
        clearError: true,
      ),
    );

    // Create a fresh request builder with the selected category
    final builder =
        _externalFeedRequestBuilder ?? NotificationFeedRequestBuilder();
    if (event.categoryId != null) {
      // The API's templateCategory filter expects the category name (subCategory),
      // not the category ID. Look up the label from the categories list.
      String categoryFilter = event.categoryId!;
      for (final c in state.categories) {
        if (c.id == event.categoryId) {
          categoryFilter = c.label;
          break;
        }
      }
      builder.setCategory(categoryFilter);
    }
    _feedRequest = builder.build();

    final result = await _getFeedItemsUseCase(_feedRequest!);

    // Check if a newer category switch has occurred
    if (currentGeneration != _fetchGeneration) return;

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            screenState: NotificationFeedScreenState.error,
            error: failure.message,
          ),
        );
      },
      (items) {
        _rebuildIndexMap(items);
        final categoryUnreadCounts = _computeCategoryUnreadCounts(items);
        final totalUnread = _computeTotalUnreadCount(items);

        if (items.isEmpty) {
          emit(
            state.copyWith(
              screenState: NotificationFeedScreenState.empty,
              items: items,
              categoryUnreadCounts: categoryUnreadCounts,
              totalUnreadCount: totalUnread,
              hasMorePages: false,
            ),
          );
        } else {
          emit(
            state.copyWith(
              screenState: NotificationFeedScreenState.loaded,
              items: items,
              categoryUnreadCounts: categoryUnreadCounts,
              totalUnreadCount: totalUnread,
              hasMorePages: items.isNotEmpty,
            ),
          );
        }

        _markItemsAsDelivered(items);
      },
    );
  }

  /// Pull-to-refresh.
  Future<void> _onRefreshFeed(
    RefreshFeed event,
    Emitter<NotificationFeedState> emit,
  ) async {
    // Debounce: ignore if already loading or refreshing
    if (state.screenState == NotificationFeedScreenState.loading ||
        state.isRefreshing) {
      return;
    }

    final currentGeneration = ++_fetchGeneration;

    emit(state.copyWith(isRefreshing: true));

    // Create a fresh request builder for the current category
    final builder =
        _externalFeedRequestBuilder ?? NotificationFeedRequestBuilder();
    if (state.activeCategory != null) {
      // The API's templateCategory filter expects the category name (subCategory),
      // not the category ID. Look up the label from the categories list.
      String categoryFilter = state.activeCategory!;
      for (final c in state.categories) {
        if (c.id == state.activeCategory) {
          categoryFilter = c.label;
          break;
        }
      }
      builder.setCategory(categoryFilter);
    }
    _feedRequest = builder.build();

    final result = await _getFeedItemsUseCase(_feedRequest!);

    if (currentGeneration != _fetchGeneration) return;

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            isRefreshing: false,
            screenState: NotificationFeedScreenState.error,
            error: failure.message,
          ),
        );
      },
      (items) {
        _rebuildIndexMap(items);
        final categoryUnreadCounts = _computeCategoryUnreadCounts(items);
        final totalUnread = _computeTotalUnreadCount(items);

        emit(
          state.copyWith(
            isRefreshing: false,
            items: items,
            screenState: items.isEmpty
                ? NotificationFeedScreenState.empty
                : NotificationFeedScreenState.loaded,
            categoryUnreadCounts: categoryUnreadCounts,
            totalUnreadCount: totalUnread,
            hasMorePages: items.isNotEmpty,
          ),
        );

        _markItemsAsDelivered(items);
      },
    );
  }

  /// Handle real-time feed item received.
  void _onFeedItemReceived(
    FeedItemReceived event,
    Emitter<NotificationFeedState> emit,
  ) {
    final newItem = event.feedItem;
    final itemCategoryKey = newItem.categoryId ?? newItem.category;

    // Always update unread counts for the new item's category,
    // regardless of whether it matches the current filter.
    // This ensures chip badges reflect all incoming items.
    final categoryUnreadCounts = Map<String, int>.from(
      state.categoryUnreadCounts,
    );
    if (newItem.readAt == null) {
      categoryUnreadCounts[itemCategoryKey] =
          (categoryUnreadCounts[itemCategoryKey] ?? 0) + 1;
    }
    final totalUnread =
        state.totalUnreadCount + (newItem.readAt == null ? 1 : 0);

    // If filtering by category and item doesn't match, update counts only
    // (don't add to the visible list).
    if (state.activeCategory != null) {
      if (itemCategoryKey != state.activeCategory) {
        emit(
          state.copyWith(
            categoryUnreadCounts: categoryUnreadCounts,
            totalUnreadCount: totalUnread,
          ),
        );
        // Mark as delivered even though it's not in the visible list
        _markSingleItemAsDelivered(newItem);
        return;
      }
    }

    // Insert at position 0 (top)
    final updatedItems = [newItem, ...state.items];
    _rebuildIndexMap(updatedItems);

    emit(
      state.copyWith(
        items: updatedItems,
        screenState: NotificationFeedScreenState.loaded,
        categoryUnreadCounts: categoryUnreadCounts,
        totalUnreadCount: totalUnread,
      ),
    );

    // Mark as delivered
    _markSingleItemAsDelivered(newItem);
  }

  /// Handle feed item retraction/deletion.
  void _onFeedItemRetracted(
    FeedItemRetracted event,
    Emitter<NotificationFeedState> emit,
  ) {
    final index = _findItemIndex(event.itemId);
    if (index == null) return;

    final removedItem = state.items[index];
    final updatedItems = List<NotificationFeedItem>.from(state.items)
      ..removeAt(index);
    _rebuildIndexMap(updatedItems);

    // Decrement unread count if item was unread
    int totalUnread = state.totalUnreadCount;
    final categoryUnreadCounts = Map<String, int>.from(
      state.categoryUnreadCounts,
    );
    if (removedItem.readAt == null) {
      totalUnread = (totalUnread - 1).clamp(0, totalUnread);
      final catKey = removedItem.categoryId ?? removedItem.category;
      final catCount = categoryUnreadCounts[catKey] ?? 0;
      if (catCount > 0) {
        categoryUnreadCounts[catKey] = catCount - 1;
      }
    }

    emit(
      state.copyWith(
        items: updatedItems,
        totalUnreadCount: totalUnread,
        categoryUnreadCounts: categoryUnreadCounts,
        screenState: updatedItems.isEmpty
            ? NotificationFeedScreenState.empty
            : NotificationFeedScreenState.loaded,
      ),
    );
  }

  /// Mark a feed item as read.
  Future<void> _onMarkItemAsRead(
    MarkItemAsRead event,
    Emitter<NotificationFeedState> emit,
  ) async {
    final item = event.feedItem;

    // Already read, skip
    if (item.readAt != null) return;

    final result = await _markFeedReadUseCase(item);

    result.fold(
      (failure) {
        // On failure, keep item as unread — retry on next visibility
        if (kDebugMode) {
          ccLog(
            '[NotificationFeedBloc] Mark as read failed: ${failure.message}',
          );
        }
      },
      (_) {
        // Update item's readAt locally
        final index = _findItemIndex(item.id);
        if (index == null || index >= state.items.length) return;

        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final updatedItem = state.items[index].copyWith(readAt: now);
        final updatedItems = List<NotificationFeedItem>.from(state.items);
        updatedItems[index] = updatedItem;
        _rebuildIndexMap(updatedItems);

        // Decrement unread counts
        int totalUnread = (state.totalUnreadCount - 1).clamp(
          0,
          state.totalUnreadCount,
        );
        final categoryUnreadCounts = Map<String, int>.from(
          state.categoryUnreadCounts,
        );
        final catKey = item.categoryId ?? item.category;
        final catCount = categoryUnreadCounts[catKey] ?? 0;
        if (catCount > 0) {
          categoryUnreadCounts[catKey] = catCount - 1;
        }

        emit(
          state.copyWith(
            items: updatedItems,
            totalUnreadCount: totalUnread,
            categoryUnreadCounts: categoryUnreadCounts,
          ),
        );
      },
    );
  }

  /// Report delivered engagement (fire-and-forget, deduplicated).
  Future<void> _onReportDelivered(
    ReportDelivered event,
    Emitter<NotificationFeedState> emit,
  ) async {
    final itemId = event.feedItem.id;
    if (_deliveredItemIds.contains(itemId)) return;
    _deliveredItemIds.add(itemId);

    // Fire-and-forget
    unawaited(_markFeedDeliveredUseCase(event.feedItem));
  }

  /// Report viewed engagement (fire-and-forget, deduplicated).
  Future<void> _onReportViewed(
    ReportViewed event,
    Emitter<NotificationFeedState> emit,
  ) async {
    final itemId = event.feedItem.id;
    if (_viewedItemIds.contains(itemId)) return;
    _viewedItemIds.add(itemId);

    // Fire-and-forget
    unawaited(_reportFeedEngagementUseCase(event.feedItem, 'viewed'));
  }

  /// Report clicked engagement (fire-and-forget).
  Future<void> _onReportClicked(
    ReportClicked event,
    Emitter<NotificationFeedState> emit,
  ) async {
    // Clicked can be reported multiple times (not deduplicated)
    unawaited(_reportFeedEngagementUseCase(event.feedItem, 'clicked'));
  }

  /// Update unread counts from server.
  Future<void> _onUpdateUnreadCounts(
    UpdateUnreadCounts event,
    Emitter<NotificationFeedState> emit,
  ) async {
    final result = await _getUnreadCountUseCase();

    result.fold(
      (failure) {
        // Silently fail — don't disrupt UI
        if (kDebugMode) {
          ccLog(
            '[NotificationFeedBloc] Unread count poll failed: ${failure.message}',
          );
        }
      },
      (count) {
        if (count != state.totalUnreadCount) {
          emit(state.copyWith(totalUnreadCount: count));
        }
      },
    );
  }

  /// Handle connection state changes.
  void _onConnectionStateChanged(
    ConnectionStateChanged event,
    Emitter<NotificationFeedState> emit,
  ) {
    emit(state.copyWith(isOffline: event.isOffline));

    // On reconnect, refresh feed to catch missed items
    if (!event.isOffline &&
        state.screenState != NotificationFeedScreenState.loading) {
      add(const RefreshFeed());
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Mark multiple items as delivered (fire-and-forget, deduplicated).
  void _markItemsAsDelivered(List<NotificationFeedItem> items) {
    for (final item in items) {
      _markSingleItemAsDelivered(item);
    }
  }

  /// Mark a single item as delivered (fire-and-forget, deduplicated).
  void _markSingleItemAsDelivered(NotificationFeedItem item) {
    if (_deliveredItemIds.contains(item.id)) return;
    _deliveredItemIds.add(item.id);
    _markFeedDeliveredUseCase(item);
  }

  /// Start periodic unread count polling.
  void _startUnreadCountPolling() {
    _unreadCountTimer?.cancel();
    _unreadCountTimer = Timer.periodic(_unreadCountPollInterval, (_) {
      if (!isClosed) {
        add(const UpdateUnreadCounts());
      }
    });
  }

  /// Get a feed item by ID for deep linking.
  Future<Result<NotificationFeedItem>> getFeedItem(String id) {
    return _getFeedItemUseCase(id);
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  Future<void> close() {
    _unreadCountTimer?.cancel();
    if (!disableSDKListeners) {
      CometChat.removeNotificationFeedListener(_feedListenerKey);
      CometChat.removeConnectionListener(_connectionListenerKey);
    }
    return super.close();
  }
}

// ============================================================
// CONNECTION LISTENER
// ============================================================

class _NotificationFeedConnectionListener with ConnectionListener {
  final VoidCallback onConnectedCallback;
  final VoidCallback onDisconnectedCallback;

  _NotificationFeedConnectionListener({
    required this.onConnectedCallback,
    required this.onDisconnectedCallback,
  });

  @override
  void onConnected() {
    onConnectedCallback();
  }

  @override
  void onDisconnected() {
    onDisconnectedCallback();
  }
}
