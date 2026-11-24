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
import '../../../../shared_ui/src/offline/notification_feed_offline.dart';
import '../../../../shared_ui/src/offline/offline_gate.dart';
import '../../../../shared_ui/src/offline/offline_hub_event.dart';
import '../../../../shared_ui/src/offline/offline_list_errors.dart';
import '../../../../shared_ui/src/offline/offline_list_reset.dart';
import '../../../../shared_ui/src/offline/two_phase.dart';

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

  /// Bumped on a session end or cache reset (G8, ENG-41569). A load-more or
  /// unread-count read started under an older value drops its result; the
  /// first-page reads drop theirs through [_fetchGeneration], bumped too.
  int _resetGen = 0;

  StreamSubscription<OfflineHubEvent>? _offlineResetSub;

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

    // Session end and cache reset (G8): offline on only.
    on<_OfflineListReset>(_onOfflineListReset);
    on<_CacheResetReload>(
      (event, emit) => _onLoadNotificationFeed(
        const LoadNotificationFeed(),
        emit,
        quiet: true,
      ),
    );
    _offlineResetSub = OfflineListReset.listen(
      isClosed: () => isClosed,
      onReset: (event) {
        // Bump now so reads in flight stop writing at once.
        _fetchGeneration++;
        _resetGen++;
        add(_OfflineListReset(event));
      },
    );

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

  /// Session end or cache reset (G8): clears the items, the index map, the
  /// counts and the SDK requests before the next frame, and returns the feed
  /// to all categories. A session end leaves it empty until it is next asked
  /// to load; a cache reset reloads once from page one, quietly over items
  /// (D84 (5)).
  void _onOfflineListReset(
    _OfflineListReset event,
    Emitter<NotificationFeedState> emit,
  ) {
    final hubEvent = event.event;
    if (OfflineListReset.isStale(hubEvent)) return;
    _feedRequest = null;
    _categoriesRequest = null;
    _itemIndexMap.clear();
    _deliveredItemIds.clear();
    _viewedItemIds.clear();
    emit(
      state.copyWith(
        screenState: NotificationFeedScreenState.empty,
        items: const [],
        categories: const [],
        clearActiveCategory: true,
        totalUnreadCount: 0,
        categoryUnreadCounts: const {},
        isLoadingMore: false,
        isRefreshing: false,
        hasMorePages: false,
        clearError: true,
      ),
    );
    if (hubEvent is CacheReset) add(const _CacheResetReload());
  }

  /// Load initial notification feed: categories + first page of items.
  /// [quiet] marks the kit's own cache-reset reload: a real error over the
  /// cached items it shows does not reach `onError` (D84 (5)).
  Future<void> _onLoadNotificationFeed(
    LoadNotificationFeed event,
    Emitter<NotificationFeedState> emit, {
    bool quiet = false,
  }) async {
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

    final twoPhase = _twoPhaseSource();
    if (twoPhase != null) {
      emit(state.copyWith(categories: categories));
      return _readFirstPageTwoPhase(
        twoPhase,
        currentGeneration,
        emit,
        silent: quiet,
      );
    }

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
    final resetGen = _resetGen;

    final twoPhase = _twoPhaseSource();
    if (twoPhase != null) {
      return _loadMoreTwoPhase(twoPhase, emit, resetGen: resetGen);
    }

    final result = await _getFeedItemsUseCase(_feedRequest!);
    // A session end or cache reset cleared the feed meanwhile.
    if (resetGen != _resetGen) return;

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

    final twoPhase = _twoPhaseSource();
    if (twoPhase != null) {
      return _readFirstPageTwoPhase(twoPhase, currentGeneration, emit);
    }

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

    final twoPhase = _twoPhaseSource();
    if (twoPhase != null) {
      return _readFirstPageTwoPhase(
        twoPhase,
        currentGeneration,
        emit,
        refreshing: true,
        silent: event.silent,
      );
    }

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

  // ============================================================
  // OFFLINE ON (W7): two-round reads (PR #23 §3.9)
  // ============================================================

  /// The two-phase source when offline is on and the items use case can read
  /// in two rounds, else null (today's single read).
  NotificationFeedTwoPhaseSource? _twoPhaseSource() => OfflineGate.isOn()
      ? NotificationFeedOffline.sourceFor(_getFeedItemsUseCase)
      : null;

  /// First page (load, category switch, refresh): the cached page at once
  /// (a refresh keeps the rows shown instead), then the server page in its
  /// place. An empty cached page never ends the feed. A server error with rows
  /// shown keeps them; a real one reaches `onError` (D84 (2), (5)), except on
  /// the [silent] reconnect refresh. With nothing shown it is the offline
  /// state when the device is offline (D84 (3)), else the error view; the
  /// reconnect refresh replaces either.
  Future<void> _readFirstPageTwoPhase(
    NotificationFeedTwoPhaseSource source,
    int generation,
    Emitter<NotificationFeedState> emit, {
    bool refreshing = false,
    bool silent = false,
  }) async {
    void show(List<NotificationFeedItem> items, {required bool hasMore}) {
      _rebuildIndexMap(items);
      emit(
        state.copyWith(
          isRefreshing: false,
          items: items,
          screenState: items.isEmpty
              ? NotificationFeedScreenState.empty
              : NotificationFeedScreenState.loaded,
          categoryUnreadCounts: _computeCategoryUnreadCounts(items),
          totalUnreadCount: _computeTotalUnreadCount(items),
          hasMorePages: hasMore,
        ),
      );
    }

    await for (final result in source.fetchFeedItemsTwoPhase(_feedRequest!)) {
      if (isClosed || emit.isDone || generation != _fetchGeneration) return;
      switch (result) {
        case Cached(:final rows):
          if (!refreshing && rows.isNotEmpty) {
            show(NotificationFeedOffline.append(const [], rows), hasMore: true);
          }
        case Server(:final rows):
          final items = NotificationFeedOffline.append(const [], rows);
          show(items, hasMore: items.isNotEmpty);
          _markItemsAsDelivered(items);
        case PhaseError(:final error):
          final offline = NotificationFeedOffline.isOffline(error);
          if (state.items.isNotEmpty) {
            emit(
              state.copyWith(
                isRefreshing: false,
                screenState: NotificationFeedScreenState.loaded,
              ),
            );
            // Offline, nothing more (D84 (2)); a real error reaches onError
            // unless the kit started the read (D84 (5)).
            if (!silent && !offline) OfflineListErrors.report(this, error);
          } else {
            // Nothing shown: offline, the error state is the offline state
            // and onError fires once (D84 (3)); else the error view (D84 (4)).
            NotificationFeedOffline.setOfflineState(this, offline);
            emit(
              state.copyWith(
                isRefreshing: false,
                screenState: NotificationFeedScreenState.error,
                error: error.message,
              ),
            );
          }
      }
    }
  }

  /// "Load more": the cached page, then the server page in its place, each
  /// appending only items not already shown. The feed ends when a server page
  /// adds nothing new.
  Future<void> _loadMoreTwoPhase(
    NotificationFeedTwoPhaseSource source,
    Emitter<NotificationFeedState> emit, {
    required int resetGen,
  }) async {
    final before = state.items;
    void show(List<NotificationFeedItem> items, {bool? hasMore}) {
      _rebuildIndexMap(items);
      emit(
        state.copyWith(
          items: items,
          isLoadingMore: hasMore == null,
          hasMorePages: hasMore,
          categoryUnreadCounts: _computeCategoryUnreadCounts(items),
          totalUnreadCount: _computeTotalUnreadCount(items),
        ),
      );
    }

    await for (final result in source.fetchFeedItemsTwoPhase(_feedRequest!)) {
      if (isClosed || emit.isDone || resetGen != _resetGen) return;
      switch (result) {
        case Cached(:final rows):
          if (rows.isNotEmpty) {
            show(NotificationFeedOffline.append(before, rows));
          }
        case Server(:final rows):
          final items = NotificationFeedOffline.append(before, rows);
          show(items, hasMore: items.length > before.length);
          _markItemsAsDelivered(items.sublist(before.length));
        case PhaseError():
          // Keep what is shown (cached rows included); no error.
          emit(state.copyWith(isLoadingMore: false));
      }
    }
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
    final resetGen = _resetGen;
    final result = await _getUnreadCountUseCase();
    // A count read for the session that ended must not land.
    if (resetGen != _resetGen) return;

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
      add(const RefreshFeed(silent: true));
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
    _offlineResetSub?.cancel();
    if (!disableSDKListeners) {
      CometChat.removeNotificationFeedListener(_feedListenerKey);
      CometChat.removeConnectionListener(_connectionListenerKey);
    }
    return super.close();
  }
}

// ============================================================
// OFFLINE RESET EVENTS (G8)
// ============================================================

/// A current-gen session end or cache reset from the offline hub.
class _OfflineListReset extends NotificationFeedEvent {
  const _OfflineListReset(this.event);

  final OfflineHubEvent event;

  @override
  List<Object?> get props => [event];
}

/// The one reload after a cache reset, kit-started.
class _CacheResetReload extends NotificationFeedEvent {
  const _CacheResetReload();
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
