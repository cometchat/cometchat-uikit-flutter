import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/domain.dart';
import '../di/users_service_locator.dart';
import 'users_event.dart';
import 'users_state.dart';
import '../../../../shared_ui/cometchat_uikit_shared.dart';
import '../../shared/list_base.dart';
import '../../../../shared_ui/src/offline/offline_gate.dart';
import '../../../../shared_ui/src/offline/offline_hub_event.dart';
import '../../../../shared_ui/src/offline/offline_list_errors.dart';
import '../../../../shared_ui/src/offline/offline_list_reset.dart';
import '../../../../shared_ui/src/offline/offline_presence.dart';
import '../../../../shared_ui/src/offline/two_phase.dart';
import '../data/datasources/users_remote_datasource.dart';
import 'users_offline.dart';
import '../../../../src/chat_sdk_listeners.dart';

/// BLoC for managing users list
///
/// This BLoC manages the users list state and handles:
/// - Loading and pagination of users
/// - Real-time updates via SDK listeners (user online/offline)
/// - Selection management
/// - Search functionality with debouncing
///
/// This BLoC uses the [ListBase] mixin for list management operations.
/// Developers can extend this class and override the hook methods
/// (onItemAdded, onItemRemoved, onItemUpdated, onListCleared, onListReplaced)
/// to add custom logic like sorting, filtering, or validation.
class UsersBloc extends Bloc<UsersEvent, UsersState> with ListBase<User> {
  // Use cases
  final GetUsersUseCase getUsersUseCase;
  final GetLoggedInUserUseCase getLoggedInUserUseCase;

  // Pagination state tracking
  bool _isLoadingMore = false;

  // Logged in user
  User? _loggedInUser;

  // Current search keyword
  String? _currentSearchKeyword;

  /// The read version (ENG-41552 F). Every first-page read (load, refresh,
  /// search) and every keyword change bumps it; a read that finishes under
  /// an older version, a load-more included, drops its result, so only the
  /// current keyword's rows reach the state.
  int _readVersion = 0;

  /// Load-mores started, so a stale one knows whether a newer one owns the
  /// loading flag.
  int _loadMoreSeq = 0;

  /// The read to run once on reconnect: set when a first page ended in the
  /// offline state (D84 (3), (7)), cleared by any newer first-page read or
  /// keyword change.
  UsersEvent? _reloadOnConnect;

  /// A load-more a newer read made stale drops its page. Unless a newer
  /// load-more is running, it also clears the loading flag and footer it set.
  void _dropStaleLoadMore(int seq, Emitter<UsersState> emit) {
    if (seq != _loadMoreSeq) return;
    _isLoadingMore = false;
    final s = state;
    if (s is UsersLoaded && s.isLoadingMore) {
      emit(s.copyWith(isLoadingMore: false));
    }
  }

  // Search debounce timer for preventing excessive API calls
  Timer? _searchDebounceTimer;

  // Debounce duration for search (300ms is a good balance)
  static const Duration _searchDebounceDuration = Duration(milliseconds: 300);

  // Original users list before search (for restoration when search is cleared)
  List<User>? _originalUsers;

  // ============================================================
  // OPTIMIZATION: Map-based O(1) user lookups
  // ============================================================
  final Map<String, int> _userIndexMap = {};

  // SDK listener IDs
  final String _userListenerKey =
      'users_bloc_user_${DateTime.now().millisecondsSinceEpoch}';
  final String _connectionListenerKey =
      'users_bloc_connection_${DateTime.now().millisecondsSinceEpoch}';

  // CC UI Event listener IDs
  final String _ccUserListenerKey =
      'users_bloc_cc_user_${DateTime.now().millisecondsSinceEpoch}';

  // Configuration options
  final bool usersStatusVisibility;
  final bool includeBlockedUsers;

  /// Whether to disable SDK listeners
  final bool disableSDKListeners;

  /// Custom users request builder for filtering users
  final UsersRequestBuilder? usersRequestBuilder;

  /// Users per page: the app builder's limit, as Android uses it, else 30.
  int get _pageSize => usersRequestBuilder?.limit ?? 30;

  // ============================================================
  // OPTIMIZATION: Per-user status using ValueNotifier
  // Each user has its own notifier - only affected item rebuilds
  // ============================================================
  final Map<String, ValueNotifier<String>> _statusNotifiers = {};

  /// Get or create a status notifier for a specific user.
  /// Use this with ValueListenableBuilder in list items for isolated rebuilds.
  ValueNotifier<String> getStatusNotifier(String uid) {
    return _statusNotifiers.putIfAbsent(
      uid,
      () => ValueNotifier<String>('offline'),
    );
  }

  /// Get current status for a user
  String getUserStatus(String uid) {
    return _statusNotifiers[uid]?.value ?? 'offline';
  }

  /// Helper to get initialized service locator
  static UsersServiceLocator _getServiceLocator() {
    if (!UsersServiceLocator.instance.isInitialized) {
      UsersServiceLocator.instance.setup();
    }
    return UsersServiceLocator.instance;
  }

  /// Creates a UsersBloc.
  UsersBloc({
    GetUsersUseCase? getUsersUseCase,
    GetLoggedInUserUseCase? getLoggedInUserUseCase,
    this.usersStatusVisibility = true,
    this.includeBlockedUsers = false,
    this.disableSDKListeners = false,
    this.usersRequestBuilder,
  }) : getUsersUseCase =
           getUsersUseCase ?? _getServiceLocator().getUsersUseCase,
       getLoggedInUserUseCase =
           getLoggedInUserUseCase ??
           _getServiceLocator().getLoggedInUserUseCase,
       super(const UsersInitial()) {
    // Register event handlers
    on<LoadUsers>(_onLoadUsers);
    on<LoadMoreUsers>(_onLoadMoreUsers);
    on<RefreshUsers>(_onRefreshUsers);
    on<SearchUsers>(_onSearchUsers);
    on<ToggleUserSelection>(_onToggleUserSelection);
    on<ClearUserSelection>(_onClearUserSelection);
    on<UpdateUser>(_onUpdateUser);

    // Internal events
    on<_UserStatusUpdate>(_onUserStatusUpdate);
    on<_ConnectionStateUpdate>(_onConnectionStateUpdate);
    on<_UserBlockedUpdate>(_onUserBlockedUpdate);
    on<_UserUnblockedUpdate>(_onUserUnblockedUpdate);
    on<_ListStateChanged>(_onListStateChanged);

    // Internal events for search functionality
    on<_ExecuteSearch>(_onExecuteSearch);
    on<_RestoreOriginalUsers>(_onRestoreOriginalUsers);

    // Session end and cache reset (G8): offline on only.
    on<_OfflineListReset>(_onOfflineListReset);
    on<_CacheResetReload>(
      (event, emit) => _onLoadUsers(
        LoadUsers(searchKeyword: event.keyword),
        emit,
        quiet: true,
      ),
    );
    _offlineResetSub = OfflineListReset.listen(
      isClosed: () => isClosed,
      onReset: (event) {
        // Bump now so reads in flight stop writing at once.
        _readVersion++;
        add(_OfflineListReset(event));
      },
    );

    // Initialize and register SDK listeners
    _initializeAndRegisterListeners();
  }

  StreamSubscription<OfflineHubEvent>? _offlineResetSub;

  /// Session end or cache reset (G8): clears the rows, the index map and the
  /// SDK request before the next frame. A session end leaves the list empty
  /// until it is next asked to load; a cache reset reloads once from page
  /// one, quietly over rows (D84 (5)).
  void _onOfflineListReset(_OfflineListReset event, Emitter<UsersState> emit) {
    final hubEvent = event.event;
    if (OfflineListReset.isStale(hubEvent)) return;
    final reload = hubEvent is CacheReset;
    // A debounced search typed by the user who left must not run.
    if (!reload) _searchDebounceTimer?.cancel();
    _isLoadingMore = false;
    _reloadOnConnect = null;
    _originalUsers = null;
    getUsersUseCase.resetRequest();
    clearItems();
    _userIndexMap.clear();
    _mapNeedsRebuild = true;
    emit(const UsersEmpty());
    if (reload) add(_CacheResetReload(_currentSearchKeyword));
  }

  // ============================================================
  // OPTIMIZATION: Map-based lookup helpers
  // ============================================================

  bool _mapNeedsRebuild = true;

  /// Set by the offline-on path just before it replaces the list with a
  /// server page, so the view redraws rows whose count did not change.
  bool _markNextReplace = false;

  void _rebuildIndexMap() {
    _userIndexMap.clear();
    for (int i = 0; i < items.length; i++) {
      _userIndexMap[items[i].uid] = i;
    }
    _mapNeedsRebuild = false;
  }

  int? _findUserIndex(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    if (_mapNeedsRebuild && items.isNotEmpty) {
      _rebuildIndexMap();
    }
    return _userIndexMap[uid];
  }

  // ============================================================
  // ListBase hooks - dispatch events for state changes
  // ============================================================

  @override
  void onItemAdded(User item, List<User> updatedList) {
    _mapNeedsRebuild = true;
    if (!isClosed) {
      add(_ListStateChanged(users: updatedList, isEmpty: false));
    }
  }

  @override
  void onItemRemoved(User item, List<User> updatedList) {
    _mapNeedsRebuild = true;
    if (!isClosed) {
      add(_ListStateChanged(users: updatedList, isEmpty: updatedList.isEmpty));
    }
  }

  @override
  void onItemUpdated(User oldItem, User newItem, List<User> updatedList) {
    if (!isClosed) {
      add(_ListStateChanged(users: updatedList, isEmpty: false));
    }
  }

  @override
  void onListReplaced(List<User> previousList, List<User> newList) {
    _mapNeedsRebuild = true;
    if (_markNextReplace) {
      _markNextReplace = false;
      UsersOffline.markServerReplace(newList);
    }
    // Don't set hasMore here — let the caller (_onLoadUsers / _onLoadMoreUsers)
    // control hasMore based on the actual page size, not total list length.
    if (!isClosed) {
      add(_ListStateChanged(users: newList, isEmpty: newList.isEmpty));
    }
  }

  @override
  void onListCleared(List<User> previousList) {
    _mapNeedsRebuild = true;
    if (!isClosed) {
      add(const _ListStateChanged(users: [], isEmpty: true));
    }
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> _initializeAndRegisterListeners() async {
    final result = await getLoggedInUserUseCase();

    if (result is Success<User?>) {
      _loggedInUser = result.data;
    }

    if (!disableSDKListeners) {
      _registerSDKListeners();
      unawaited(OfflinePresence.sync());
    }
  }

  void _registerSDKListeners() {
    if (usersStatusVisibility) {
      CometChat.addUserListener(
        _userListenerKey,
        _UsersUserListener(
          onUserOnlineCallback: _handleUserOnline,
          onUserOfflineCallback: _handleUserOffline,
        ),
      );
    }

    // Through the seam so a test can reach the listener (D83).
    ChatSdkListeners.addConnectionListener(
      _connectionListenerKey,
      _UsersConnectionListener(
        onConnectedCallback: _handleConnected,
        onDisconnectedCallback: _handleDisconnected,
        onConnectionErrorCallback: OfflinePresence.disconnected,
      ),
    );

    // Register CC UI Event listeners for block/unblock
    CometChatUserEvents.addUsersListener(
      _ccUserListenerKey,
      _UsersCCEventListener(
        onUserBlockedCallback: _handleUserBlocked,
        onUserUnblockedCallback: _handleUserUnblocked,
      ),
    );
  }

  // ============================================================
  // SDK LISTENER CALLBACKS
  // ============================================================

  void _handleUserOnline(User user) {
    if (isClosed) return;
    // Update ValueNotifier for isolated rebuild
    _statusNotifiers[user.uid]?.value = 'online';
    add(_UserStatusUpdate(userId: user.uid, status: 'online'));
  }

  void _handleUserOffline(User user) {
    if (isClosed) return;
    _statusNotifiers[user.uid]?.value = 'offline';
    add(_UserStatusUpdate(userId: user.uid, status: 'offline'));
  }

  void _handleConnected() {
    OfflinePresence.connected();
    if (isClosed) return;
    add(const _ConnectionStateUpdate(isConnected: true));
  }

  void _handleDisconnected() {
    OfflinePresence.disconnected();
    if (isClosed) return;
    add(const _ConnectionStateUpdate(isConnected: false));
  }

  void _handleUserBlocked(User user) {
    if (isClosed) return;
    add(_UserBlockedUpdate(user: user));
  }

  void _handleUserUnblocked(User user) {
    if (isClosed) return;
    add(_UserUnblockedUpdate(user: user));
  }

  // ============================================================
  // EVENT HANDLERS
  // ============================================================

  /// [quiet] marks the kit's own cache-reset reload: a real error over the
  /// cached rows it shows does not reach `onError` (D84 (5)).
  Future<void> _onLoadUsers(
    LoadUsers event,
    Emitter<UsersState> emit, {
    bool quiet = false,
  }) async {
    // Silent refresh: keep existing list visible, skip loading shimmer.
    final isSilentRefresh = event.silent || state is UsersLoaded;

    if (!isSilentRefresh) {
      emit(const UsersLoading());
    }

    _isLoadingMore = false;
    _currentSearchKeyword = event.searchKeyword;
    final version = ++_readVersion;
    _reloadOnConnect = null;

    // Reset the SDK request cursor for a fresh load
    getUsersUseCase.resetRequest();

    if (_loggedInUser == null) {
      final userResult = await getLoggedInUserUseCase();
      if (userResult is Success<User?>) {
        _loggedInUser = userResult.data;
      }
    }

    final offlineSource = OfflineGate.isOn()
        ? UsersOffline.twoPhaseSourceFor(getUsersUseCase)
        : null;
    if (offlineSource != null) {
      await _loadFirstPageTwoPhase(
        offlineSource,
        emit,
        keyword: event.searchKeyword,
        isSilentRefresh: isSilentRefresh,
        isSearch: false,
        version: version,
        quiet: quiet,
      );
      return;
    }

    final result = await getUsersUseCase(
      limit: _pageSize,
      searchKeyword: event.searchKeyword,
      usersRequestBuilder: usersRequestBuilder,
    );

    if (version != _readVersion) return;

    if (result is Success<List<User>>) {
      final users = result.data;
      if (users.isEmpty && !isSilentRefresh) {
        emit(const UsersEmpty());
      } else if (users.isNotEmpty) {
        // Initialize status notifiers for loaded users
        for (final user in users) {
          _statusNotifiers.putIfAbsent(
            user.uid,
            () => ValueNotifier<String>(user.status ?? 'offline'),
          );
        }
        replaceAll(users);
        // A fresh first page reopens paging. A silent reload keeps the
        // previous state's hasMore otherwise, which is false once a search's
        // pages ran out, or once a refreshed list had been paged to its end.
        if (state is UsersLoaded) {
          emit((state as UsersLoaded).copyWith(hasMore: true));
        }
      }
    } else if (result is Failure && !isSilentRefresh) {
      emit(UsersError(message: result.message));
    }
  }

  Future<void> _onLoadMoreUsers(
    LoadMoreUsers event,
    Emitter<UsersState> emit,
  ) async {
    if (state is! UsersLoaded) return;

    final currentState = state as UsersLoaded;

    if (!currentState.hasMore || currentState.isLoadingMore || _isLoadingMore) {
      return;
    }

    _isLoadingMore = true;
    emit(currentState.copyWith(isLoadingMore: true));
    final version = _readVersion;
    final seq = ++_loadMoreSeq;

    final offlineSource = OfflineGate.isOn()
        ? UsersOffline.twoPhaseSourceFor(getUsersUseCase)
        : null;
    if (offlineSource != null) {
      await _loadMoreTwoPhase(offlineSource, emit, version: version, seq: seq);
      return;
    }

    final result = await getUsersUseCase(
      limit: _pageSize,
      searchKeyword: _currentSearchKeyword,
      usersRequestBuilder: usersRequestBuilder,
    );

    // A newer read owns the list now.
    if (version != _readVersion) {
      _dropStaleLoadMore(seq, emit);
      return;
    }

    _isLoadingMore = false;

    if (result is Success<List<User>>) {
      final newUsers = result.data;

      if (newUsers.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
        return;
      }

      // Initialize status notifiers for new users
      for (final user in newUsers) {
        _statusNotifiers.putIfAbsent(
          user.uid,
          () => ValueNotifier<String>(user.status ?? 'offline'),
        );
      }

      final allUsers = [...currentState.users, ...newUsers];
      replaceAll(allUsers);
      // Only an empty page ends paging, as on Android and as CometChatGroups
      // does. The request after the last page is answered by the SDK from its
      // page count. Emitted after replaceAll, since onListReplaced does not
      // set hasMore or isLoadingMore.
      if (state is UsersLoaded) {
        emit(
          (state as UsersLoaded).copyWith(hasMore: true, isLoadingMore: false),
        );
      }
    } else if (result is Failure) {
      emit(
        UsersError(message: result.message, previousUsers: currentState.users),
      );
    }
  }

  // ============================================================
  // OFFLINE-ON READS (W6). Reached only when OfflineGate.isOn() was true
  // for this operation and the kit's own data source is in use.
  // ============================================================

  void _seedStatusNotifiers(List<User> users) {
    for (final user in users) {
      _statusNotifiers.putIfAbsent(
        user.uid,
        () => ValueNotifier<String>(user.status ?? 'offline'),
      );
    }
  }

  String _offlineFailureMessage(CometChatException e) =>
      'Failed to load users: ${e.message ?? 'Failed to fetch users'}';

  /// A first page (load, refresh, reconnect, search) read in two phases: the
  /// cached page paints at once, the server page then replaces it by uid.
  /// A silent reload over rows already shown skips the cached page, so the
  /// rows swap once. An error after a cached page keeps the rows; only a real
  /// error on a load the user or app started reaches `onError` (D84 (2),
  /// (5)). With nothing shown, offline is the offline state ("Connect to load
  /// users", or "Connect to search" under a filter), which loads again once
  /// on reconnect; any other error is the error view, as today (D84 (3),
  /// (4), (7)). A read that a newer one replaced ([version]) stops at once.
  Future<void> _loadFirstPageTwoPhase(
    UsersRemoteDataSourceImpl source,
    Emitter<UsersState> emit, {
    required String? keyword,
    required bool isSilentRefresh,
    required bool isSearch,
    required int version,
    bool quiet = false,
  }) async {
    final current = state;
    final rowsShown = current is UsersLoaded && current.users.isNotEmpty;
    var cachedShown = false;
    final pages = UsersOffline.readNextPage(
      source,
      limit: _pageSize,
      searchKeyword: keyword,
      usersRequestBuilder: usersRequestBuilder,
    );
    await for (final phase in pages) {
      if (isClosed || version != _readVersion) return;
      switch (phase) {
        case Cached<User>(:final rows):
          if (rowsShown || rows.isEmpty) break;
          _seedStatusNotifiers(rows);
          cachedShown = true;
          replaceAll(rows);
        case Server<User>(:final rows):
          if (rows.isEmpty) {
            if (cachedShown) {
              replaceAll(const <User>[]);
            } else if (isSearch || !isSilentRefresh) {
              emit(const UsersEmpty());
            }
            break;
          }
          _seedStatusNotifiers(rows);
          _markNextReplace = true;
          replaceAll(rows);
          if (!isSearch && state is UsersLoaded) {
            emit((state as UsersLoaded).copyWith(hasMore: true));
          }
        case PhaseError<User>(:final error):
          final offline = UsersOffline.isConnectivityError(error);
          if (cachedShown) {
            // The cached rows stay. Offline, nothing more (D84 (2)); a real
            // error reaches onError when the user or app started the load
            // (D84 (5)).
            if (!offline && !isSilentRefresh && !quiet) {
              OfflineListErrors.report(this, error);
            }
            break;
          }
          if (isSilentRefresh && rowsShown) break;
          if (offline && (isSearch || !isSilentRefresh)) {
            // Nothing shown: the offline state, which loads again once on
            // reconnect (D84 (3), (7), (8)).
            _reloadOnConnect = isSearch && keyword != null
                ? _ExecuteSearch(keyword)
                : LoadUsers(searchKeyword: keyword);
            emit(
              UsersOffline.hasServerOnlyFilter(keyword, usersRequestBuilder)
                  ? const UsersConnectToSearch()
                  : UsersConnectToLoad(error),
            );
            break;
          }
          if (isSearch) {
            emit(
              UsersError(
                message: _offlineFailureMessage(error),
                previousUsers: _originalUsers,
              ),
            );
          } else if (!isSilentRefresh) {
            emit(UsersError(message: _offlineFailureMessage(error)));
          }
      }
    }
  }

  /// The next page read in two phases. The cached page is appended at once
  /// (rows already listed are skipped), and the server page then replaces it
  /// by uid. Only an empty server page ends paging. An error keeps every row;
  /// paging stays open only if a cached page was shown (more may be cached),
  /// and a reconnect reload reopens it otherwise.
  Future<void> _loadMoreTwoPhase(
    UsersRemoteDataSourceImpl source,
    Emitter<UsersState> emit, {
    required int version,
    required int seq,
  }) async {
    final provisional = <String>{};
    final pages = UsersOffline.readNextPage(
      source,
      limit: _pageSize,
      searchKeyword: _currentSearchKeyword,
      usersRequestBuilder: usersRequestBuilder,
    );
    await for (final phase in pages) {
      if (isClosed) return;
      if (version != _readVersion) {
        _dropStaleLoadMore(seq, emit);
        return;
      }
      switch (phase) {
        case Cached<User>(:final rows):
          final merged = UsersOffline.appendCached(items, rows, provisional);
          if (provisional.isEmpty) break;
          _seedStatusNotifiers(rows);
          replaceAll(merged);
        case Server<User>(:final rows):
          _isLoadingMore = false;
          if (rows.isEmpty) {
            if (provisional.isNotEmpty) {
              _markNextReplace = true;
              replaceAll(UsersOffline.replacePage(items, provisional, rows));
            }
            if (state is UsersLoaded) {
              emit(
                (state as UsersLoaded).copyWith(
                  hasMore: false,
                  isLoadingMore: false,
                ),
              );
            }
            break;
          }
          _seedStatusNotifiers(rows);
          _markNextReplace = true;
          replaceAll(UsersOffline.replacePage(items, provisional, rows));
          if (state is UsersLoaded) {
            emit(
              (state as UsersLoaded).copyWith(
                hasMore: true,
                isLoadingMore: false,
              ),
            );
          }
        case PhaseError<User>():
          _isLoadingMore = false;
          if (state is UsersLoaded) {
            emit(
              (state as UsersLoaded).copyWith(
                hasMore: provisional.isNotEmpty,
                isLoadingMore: false,
              ),
            );
          }
      }
    }
  }

  Future<void> _onRefreshUsers(
    RefreshUsers event,
    Emitter<UsersState> emit,
  ) async {
    add(LoadUsers(searchKeyword: _currentSearchKeyword, silent: true));
  }

  /// Search users by keyword with debouncing
  ///
  /// This method implements search functionality with the following behavior:
  /// - Debounces search requests to prevent excessive API calls
  /// - Stores the original users list before searching
  /// - Restores the original list when search is cleared
  Future<void> _onSearchUsers(
    SearchUsers event,
    Emitter<UsersState> emit,
  ) async {
    // Cancel any pending search request
    _searchDebounceTimer?.cancel();

    final keyword = event.keyword.trim();
    // The keyword changed: a read for the previous one is stale now.
    _readVersion++;
    _reloadOnConnect = null;

    // If search is cleared, restore original list immediately (no debounce needed)
    if (keyword.isEmpty) {
      _currentSearchKeyword = null;

      // Restore original users if we have them stored
      if (_originalUsers != null && _originalUsers!.isNotEmpty) {
        add(_RestoreOriginalUsers(_originalUsers!));
        _originalUsers = null;
      } else if (_originalUsers != null && _originalUsers!.isEmpty) {
        // Original list was empty
        _originalUsers = null;
        emit(const UsersEmpty());
      } else {
        // No original users stored, refresh from API
        add(const LoadUsers());
      }
      return;
    }

    // Store original users before first search
    if (_currentSearchKeyword == null && state is UsersLoaded) {
      final currentState = state as UsersLoaded;
      _originalUsers = List<User>.from(currentState.users);
    }

    // Debounce the search request
    _searchDebounceTimer = Timer(_searchDebounceDuration, () {
      if (isClosed) return;
      add(_ExecuteSearch(keyword));
    });
  }

  /// Execute the actual search API call (called after debounce)
  Future<void> _onExecuteSearch(
    _ExecuteSearch event,
    Emitter<UsersState> emit,
  ) async {
    _currentSearchKeyword = event.keyword;
    final version = ++_readVersion;
    _reloadOnConnect = null;
    // A load-more of the previous list drops its page; paging restarts here.
    _isLoadingMore = false;

    // Reset the SDK request cursor for a new search
    getUsersUseCase.resetRequest();

    // Emit loading state while searching
    emit(const UsersLoading());

    final offlineSource = OfflineGate.isOn()
        ? UsersOffline.twoPhaseSourceFor(getUsersUseCase)
        : null;
    if (offlineSource != null) {
      await _loadFirstPageTwoPhase(
        offlineSource,
        emit,
        keyword: event.keyword,
        isSilentRefresh: false,
        isSearch: true,
        version: version,
      );
      return;
    }

    final result = await getUsersUseCase(
      limit: _pageSize,
      searchKeyword: event.keyword,
      usersRequestBuilder: usersRequestBuilder,
    );

    if (isClosed || version != _readVersion) return;

    if (result is Success<List<User>>) {
      final users = result.data;
      if (users.isEmpty) {
        emit(const UsersEmpty());
      } else {
        // Initialize status notifiers for loaded users
        for (final user in users) {
          _statusNotifiers.putIfAbsent(
            user.uid,
            () => ValueNotifier<String>(user.status ?? 'offline'),
          );
        }
        replaceAll(users);
      }
    } else if (result is Failure) {
      emit(UsersError(message: result.message, previousUsers: _originalUsers));
    }
  }

  /// Restore original users after search is cleared, then reload the first
  /// page.
  ///
  /// The search replaced the SDK request, so the cursor that paged the
  /// original list is gone. A load-more from a reset cursor fetched page one
  /// again and appended it, duplicating the rows already shown. A fresh first
  /// page, built from [usersRequestBuilder] as Android rebuilds its request
  /// on clear, gives later pages a cursor to follow. The restored list shows
  /// in the meantime.
  void _onRestoreOriginalUsers(
    _RestoreOriginalUsers event,
    Emitter<UsersState> emit,
  ) {
    // Drop the search's request so nothing pages on from it before the reload
    getUsersUseCase.resetRequest();
    replaceAll(event.users);
    add(const LoadUsers(silent: true));
  }

  void _onToggleUserSelection(
    ToggleUserSelection event,
    Emitter<UsersState> emit,
  ) {
    if (state is! UsersLoaded) return;

    final currentState = state as UsersLoaded;
    final selected = Set<String>.from(currentState.selectedUsers);

    if (selected.contains(event.uid)) {
      selected.remove(event.uid);
    } else {
      selected.add(event.uid);
    }

    emit(currentState.copyWith(selectedUsers: selected));
  }

  void _onClearUserSelection(
    ClearUserSelection event,
    Emitter<UsersState> emit,
  ) {
    if (state is! UsersLoaded) return;

    final currentState = state as UsersLoaded;
    emit(currentState.copyWith(selectedUsers: {}));
  }

  void _onUpdateUser(UpdateUser event, Emitter<UsersState> emit) {
    if (state is! UsersLoaded) return;

    final userIndex = _findUserIndex(event.user.uid);

    if (userIndex == null) {
      addItem(event.user);
      return;
    }

    updateItem(userIndex, event.user);
  }

  void _onUserStatusUpdate(_UserStatusUpdate event, Emitter<UsersState> emit) {
    if (state is! UsersLoaded) return;

    final matchingIndex = _findUserIndex(event.userId);
    if (matchingIndex == null || matchingIndex >= items.length) return;

    final user = items[matchingIndex];
    final updatedUser = User(
      uid: user.uid,
      name: user.name,
      avatar: user.avatar,
      status: event.status,
      role: user.role,
      blockedByMe: user.blockedByMe,
      hasBlockedMe: user.hasBlockedMe,
      lastActiveAt: user.lastActiveAt,
      link: user.link,
      metadata: user.metadata,
      statusMessage: user.statusMessage,
      tags: user.tags,
    );

    updateItem(matchingIndex, updatedUser);
  }

  void _onConnectionStateUpdate(
    _ConnectionStateUpdate event,
    Emitter<UsersState> emit,
  ) {
    final reload = _reloadOnConnect;
    if (event.isConnected && state is UsersLoaded) {
      add(const RefreshUsers());
    } else if (event.isConnected &&
        reload != null &&
        (state is UsersConnectToLoad || state is UsersConnectToSearch)) {
      // The offline state: the failed read runs again, once (D84 (8)).
      _reloadOnConnect = null;
      add(reload);
    }
  }

  void _onUserBlockedUpdate(
    _UserBlockedUpdate event,
    Emitter<UsersState> emit,
  ) {
    if (state is! UsersLoaded) return;

    final userIndex = _findUserIndex(event.user.uid);
    if (userIndex == null) return;

    // Update the user with blocked status
    updateItem(userIndex, event.user);
  }

  void _onUserUnblockedUpdate(
    _UserUnblockedUpdate event,
    Emitter<UsersState> emit,
  ) {
    if (state is! UsersLoaded) return;

    final userIndex = _findUserIndex(event.user.uid);
    if (userIndex == null) return;

    // Update the user with unblocked status
    updateItem(userIndex, event.user);
  }

  void _onListStateChanged(_ListStateChanged event, Emitter<UsersState> emit) {
    if (event.isEmpty) {
      emit(const UsersEmpty());
    } else {
      final currentState = state;
      if (currentState is UsersLoaded) {
        emit(currentState.copyWith(users: event.users));
      } else {
        emit(UsersLoaded(users: event.users, hasMore: true));
      }
    }
  }

  @override
  Future<void> close() {
    // Cancel search debounce timer
    _searchDebounceTimer?.cancel();
    _offlineResetSub?.cancel();

    CometChat.removeUserListener(_userListenerKey);
    ChatSdkListeners.removeConnectionListener(_connectionListenerKey);
    CometChatUserEvents.removeUsersListener(_ccUserListenerKey);

    // Dispose all status notifiers
    for (final notifier in _statusNotifiers.values) {
      notifier.dispose();
    }
    _statusNotifiers.clear();

    return super.close();
  }
}

// ============================================================
// INTERNAL EVENTS
// ============================================================

class _UserStatusUpdate extends UsersEvent {
  final String userId;
  final String status;

  const _UserStatusUpdate({required this.userId, required this.status});

  @override
  List<Object> get props => [userId, status];
}

class _ConnectionStateUpdate extends UsersEvent {
  final bool isConnected;

  const _ConnectionStateUpdate({required this.isConnected});

  @override
  List<Object> get props => [isConnected];
}

class _UserBlockedUpdate extends UsersEvent {
  final User user;

  const _UserBlockedUpdate({required this.user});

  @override
  List<Object> get props => [user];
}

class _UserUnblockedUpdate extends UsersEvent {
  final User user;

  const _UserUnblockedUpdate({required this.user});

  @override
  List<Object> get props => [user];
}

class _ListStateChanged extends UsersEvent {
  final List<User> users;
  final bool isEmpty;

  const _ListStateChanged({required this.users, required this.isEmpty});

  @override
  List<Object?> get props => [users, isEmpty];
}

class _ExecuteSearch extends UsersEvent {
  final String keyword;

  const _ExecuteSearch(this.keyword);

  @override
  List<Object> get props => [keyword];
}

class _RestoreOriginalUsers extends UsersEvent {
  final List<User> users;

  const _RestoreOriginalUsers(this.users);

  @override
  List<Object> get props => [users];
}

/// A current-gen session end or cache reset from the offline hub (G8).
class _OfflineListReset extends UsersEvent {
  const _OfflineListReset(this.event);

  final OfflineHubEvent event;

  @override
  List<Object?> get props => [event];
}

/// The one reload after a cache reset (G8), kit-started.
class _CacheResetReload extends UsersEvent {
  const _CacheResetReload(this.keyword);

  final String? keyword;

  @override
  List<Object?> get props => [keyword];
}

// ============================================================
// SDK LISTENERS
// ============================================================

class _UsersUserListener with UserListener {
  final void Function(User user) onUserOnlineCallback;
  final void Function(User user) onUserOfflineCallback;

  _UsersUserListener({
    required this.onUserOnlineCallback,
    required this.onUserOfflineCallback,
  });

  @override
  void onUserOnline(User user) => onUserOnlineCallback(user);

  @override
  void onUserOffline(User user) => onUserOfflineCallback(user);
}

class _UsersConnectionListener with ConnectionListener {
  final void Function() onConnectedCallback;
  final void Function() onDisconnectedCallback;
  final void Function() onConnectionErrorCallback;

  _UsersConnectionListener({
    required this.onConnectedCallback,
    required this.onDisconnectedCallback,
    required this.onConnectionErrorCallback,
  });

  @override
  void onConnected() => onConnectedCallback();

  @override
  void onDisconnected() => onDisconnectedCallback();

  /// A lost network reports `error`, not `disconnected`: the SDK is not
  /// connected either way, so presence hides (D84 (10)).
  @override
  void onConnectionError(CometChatException error) =>
      onConnectionErrorCallback();
}

class _UsersCCEventListener with CometChatUserEventListener {
  final void Function(User user) onUserBlockedCallback;
  final void Function(User user) onUserUnblockedCallback;

  _UsersCCEventListener({
    required this.onUserBlockedCallback,
    required this.onUserUnblockedCallback,
  });

  @override
  void ccUserBlocked(User user) => onUserBlockedCallback(user);

  @override
  void ccUserUnblocked(User user) => onUserUnblockedCallback(user);
}
