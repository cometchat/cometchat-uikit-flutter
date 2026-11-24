import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/usecases/get_groups_usecase.dart';
import '../domain/usecases/load_more_groups_usecase.dart';
import '../domain/usecases/get_logged_in_user_usecase.dart';
import '../di/groups_service_locator.dart';
import '../../../../shared_ui/cometchat_uikit_shared.dart';
import '../../shared/list_base.dart';
import '../../../../shared_ui/src/offline/offline_gate.dart';
import '../../../../shared_ui/src/offline/offline_hub_event.dart';
import '../../../../shared_ui/src/offline/offline_list_errors.dart';
import '../../../../shared_ui/src/offline/offline_list_reset.dart';
import '../../../../shared_ui/src/offline/two_phase.dart';
import '../data/datasources/groups_remote_datasource.dart';
import 'groups_offline.dart';
import 'groups_event.dart';
import 'groups_state.dart';

/// BLoC for managing groups list
///
/// This BLoC manages the groups list state and handles:
/// - Loading and pagination of groups
/// - Real-time updates via SDK listeners (member joined, left, kicked, banned, scope changed)
/// - Selection management
/// - Search functionality
///
/// This BLoC uses the [ListBase] mixin for list management operations.
/// Developers can extend this class and override the hook methods
/// (onItemAdded, onItemRemoved, onItemUpdated, onListCleared, onListReplaced)
/// to add custom logic like sorting, filtering, or validation.
///
/// Requirements: 1.1, 1.2, 1.5, 8.3, 8.4
class GroupsBloc extends Bloc<GroupsEvent, GroupsState> with ListBase<Group> {
  // Use cases
  final GetGroupsUseCase getGroupsUseCase;
  final LoadMoreGroupsUseCase loadMoreGroupsUseCase;
  final GetLoggedInUserUseCase getLoggedInUserUseCase;

  /// Caller-supplied request builder, mirroring UsersBloc.usersRequestBuilder.
  /// Threaded down to GroupsRemoteDataSource, which builds each first page
  /// from it with the search keyword on top, and leaves it unchanged.
  final GroupsRequestBuilder? groupsRequestBuilder;

  /// Groups per page: the app builder's limit, as Android uses it, else 30.
  int get _pageSize => groupsRequestBuilder?.limit ?? 30;

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
  GroupsEvent? _reloadOnConnect;

  /// A load-more a newer read made stale drops its page. Unless a newer
  /// load-more is running, it also clears the loading flag and footer it set.
  void _dropStaleLoadMore(int seq, Emitter<GroupsState> emit) {
    if (seq != _loadMoreSeq) return;
    _isLoadingMore = false;
    final s = state;
    if (s is GroupsLoaded && s.isLoadingMore) {
      emit(s.copyWith(isLoadingMore: false));
    }
  }

  // Search debounce timer for preventing excessive API calls (Requirement 7.3)
  Timer? _searchDebounceTimer;

  // Debounce duration for search (300ms is a good balance between responsiveness and API efficiency)
  static const Duration _searchDebounceDuration = Duration(milliseconds: 300);

  // Original groups list before search (for restoration when search is cleared - Requirement 7.2)
  List<Group>? _originalGroups;

  // ============================================================
  // OPTIMIZATION: Map-based O(1) group lookups (Requirement 1.5)
  // ============================================================
  final Map<String, int> _groupIndexMap = {};

  // SDK listener IDs (will be used in Task 5.6)
  final String _groupListenerKey =
      'groups_bloc_group_${DateTime.now().millisecondsSinceEpoch}';
  final String _connectionListenerKey =
      'groups_bloc_connection_${DateTime.now().millisecondsSinceEpoch}';
  final String _ccGroupListenerKey =
      'groups_bloc_cc_group_${DateTime.now().millisecondsSinceEpoch}';

  /// Whether to disable SDK listeners
  final bool disableSDKListeners;

  /// Helper to get initialized service locator
  static GroupsServiceLocator _getServiceLocator() {
    if (!GroupsServiceLocator.instance.isInitialized) {
      GroupsServiceLocator.instance.setup();
    }
    return GroupsServiceLocator.instance;
  }

  /// Creates a GroupsBloc.
  ///
  /// All use cases are optional - if not provided, they will be automatically
  /// initialized from the default service locator. This makes it easy to extend
  /// the bloc without worrying about dependency injection.
  ///
  /// Requirements: 1.1, 1.2
  GroupsBloc({
    GetGroupsUseCase? getGroupsUseCase,
    LoadMoreGroupsUseCase? loadMoreGroupsUseCase,
    GetLoggedInUserUseCase? getLoggedInUserUseCase,
    this.disableSDKListeners = false,
    this.groupsRequestBuilder,
  }) : getGroupsUseCase =
           getGroupsUseCase ?? _getServiceLocator().getGroupsUseCase,
       loadMoreGroupsUseCase =
           loadMoreGroupsUseCase ?? _getServiceLocator().loadMoreGroupsUseCase,
       getLoggedInUserUseCase =
           getLoggedInUserUseCase ??
           _getServiceLocator().getLoggedInUserUseCase,
       super(const GroupsInitial()) {
    // Register event handlers (Requirement 1.2)
    on<LoadGroups>(_onLoadGroups);
    on<LoadMoreGroups>(_onLoadMoreGroups);
    on<RefreshGroups>(_onRefreshGroups);
    on<SearchGroups>(_onSearchGroups);
    on<ToggleGroupSelection>(_onToggleGroupSelection);
    on<ClearGroupSelection>(_onClearGroupSelection);
    on<UpdateGroup>(_onUpdateGroup);
    on<AddGroup>(_onAddGroup);
    on<RemoveGroup>(_onRemoveGroup);

    // Internal events for SDK listeners (will be implemented in Task 5.6)
    on<GroupCreated>(_onGroupCreated);
    on<GroupMemberJoined>(_onGroupMemberJoined);
    on<GroupMemberLeft>(_onGroupMemberLeft);
    on<GroupMemberKicked>(_onGroupMemberKicked);
    on<GroupMemberBanned>(_onGroupMemberBanned);
    on<GroupMemberUnbanned>(_onGroupMemberUnbanned);
    on<GroupMemberScopeChanged>(_onGroupMemberScopeChanged);
    on<GroupOwnershipTransferred>(_onGroupOwnershipTransferred);
    on<ConnectionRestored>(_onConnectionRestored);
    on<InitializeLoggedInUser>(_onInitializeLoggedInUser);

    // Internal event for list state changes
    on<_ListStateChanged>(_onListStateChanged);

    // Internal events for search functionality (Requirement 7.1, 7.2, 7.3)
    on<_ExecuteSearch>(_onExecuteSearch);
    on<_RestoreOriginalGroups>(_onRestoreOriginalGroups);

    // Session end and cache reset (G8): offline on only.
    on<_OfflineListReset>(_onOfflineListReset);
    on<_CacheResetReload>(
      (event, emit) => _onLoadGroups(
        LoadGroups(searchKeyword: event.keyword),
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
  void _onOfflineListReset(_OfflineListReset event, Emitter<GroupsState> emit) {
    final hubEvent = event.event;
    if (OfflineListReset.isStale(hubEvent)) return;
    final reload = hubEvent is CacheReset;
    // A debounced search typed by the user who left must not run.
    if (!reload) _searchDebounceTimer?.cancel();
    _isLoadingMore = false;
    _reloadOnConnect = null;
    _originalGroups = null;
    getGroupsUseCase.resetRequest();
    clearItems();
    _groupIndexMap.clear();
    _mapNeedsRebuild = true;
    emit(const GroupsEmpty());
    if (reload) add(_CacheResetReload(_currentSearchKeyword));
  }

  // ============================================================
  // OPTIMIZATION: Map-based lookup helpers (Requirement 1.5)
  // ============================================================

  bool _mapNeedsRebuild = true;

  /// Set by the offline-on path just before it replaces the list with a
  /// server page, so the view redraws rows whose count did not change.
  bool _markNextReplace = false;

  void _rebuildIndexMap() {
    _groupIndexMap.clear();
    for (int i = 0; i < items.length; i++) {
      _groupIndexMap[items[i].guid] = i;
    }
    _mapNeedsRebuild = false;
  }

  /// Find the index of a group by its GUID using O(1) lookup
  ///
  /// Returns the index of the group in the items list, or null if not found.
  /// This method uses a Map for O(1) lookup performance.
  ///
  /// Requirement: 1.5
  int? findGroupIndex(String guid) {
    if (guid.isEmpty) return null;
    if (_mapNeedsRebuild && items.isNotEmpty) {
      _rebuildIndexMap();
    }
    return _groupIndexMap[guid];
  }

  /// Find a group by its GUID using O(1) lookup
  ///
  /// Returns the Group object if found, or null if not found.
  /// This method uses [findGroupIndex] for O(1) lookup performance.
  ///
  /// Requirement: 1.5
  Group? findGroup(String guid) {
    final index = findGroupIndex(guid);
    return index != null && index < items.length ? items[index] : null;
  }

  /// Get the list of selected Group objects
  ///
  /// Returns a list of Group objects whose GUIDs are in the selectedGroups set.
  /// Returns an empty list if the state is not GroupsLoaded.
  ///
  /// Requirement: 8.4
  List<Group> getSelectedGroups() {
    if (state is! GroupsLoaded) return [];
    final loaded = state as GroupsLoaded;
    return items.where((g) => loaded.selectedGroups.contains(g.guid)).toList();
  }

  // ============================================================
  // ListBase hooks - dispatch events for state changes
  // ============================================================

  @override
  void onItemAdded(Group item, List<Group> updatedList) {
    _mapNeedsRebuild = true;
    if (!isClosed) {
      add(_ListStateChanged(groups: updatedList, isEmpty: false));
    }
  }

  @override
  void onItemRemoved(Group item, List<Group> updatedList) {
    _mapNeedsRebuild = true;
    if (!isClosed) {
      add(_ListStateChanged(groups: updatedList, isEmpty: updatedList.isEmpty));
    }
  }

  @override
  void onItemUpdated(Group oldItem, Group newItem, List<Group> updatedList) {
    if (!isClosed) {
      add(_ListStateChanged(groups: updatedList, isEmpty: false));
    }
  }

  @override
  void onListReplaced(List<Group> previousList, List<Group> newList) {
    _mapNeedsRebuild = true;
    if (_markNextReplace) {
      _markNextReplace = false;
      GroupsOffline.markServerReplace(newList);
    }
    // Don't set hasMore here — let the caller (_onLoadGroups / _onLoadMoreGroups)
    // control hasMore based on the actual page size, not total list length.
    if (!isClosed) {
      add(_ListStateChanged(groups: newList, isEmpty: newList.isEmpty));
    }
  }

  @override
  void onListCleared(List<Group> previousList) {
    _mapNeedsRebuild = true;
    if (!isClosed) {
      add(const _ListStateChanged(groups: [], isEmpty: true));
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

    // SDK listener registration will be implemented in Task 5.6
    if (!disableSDKListeners) {
      _registerSDKListeners();
    }
  }

  /// Register all CometChat SDK listeners for real-time group updates
  ///
  /// This method registers:
  /// - GroupListener for member events (joined, left, kicked, banned, scope changed)
  /// - ConnectionListener for reconnection handling
  /// - CometChatGroupEvents for UI-triggered group events
  ///
  /// Requirements: 1.6
  void _registerSDKListeners() {
    // Register SDK GroupListener for real-time group member events
    CometChat.addGroupListener(
      _groupListenerKey,
      _GroupsGroupListener(
        onGroupMemberJoinedCallback: _handleGroupMemberJoined,
        onGroupMemberLeftCallback: _handleGroupMemberLeft,
        onGroupMemberKickedCallback: _handleGroupMemberKicked,
        onGroupMemberBannedCallback: _handleGroupMemberBanned,
        onGroupMemberUnbannedCallback: _handleGroupMemberUnbanned,
        onGroupMemberScopeChangedCallback: _handleGroupMemberScopeChanged,
        onMemberAddedToGroupCallback: _handleMemberAddedToGroup,
        loggedInUserId: _loggedInUser?.uid,
      ),
    );

    // Register ConnectionListener for reconnection handling
    CometChat.addConnectionListener(
      _connectionListenerKey,
      _GroupsConnectionListener(
        onConnectedCallback: _handleConnected,
        onDisconnectedCallback: _handleDisconnected,
      ),
    );

    // Register CometChatGroupEvents for UI-triggered group events
    CometChatGroupEvents.addGroupsListener(
      _ccGroupListenerKey,
      _GroupsCCEventListener(
        onCCGroupCreatedCallback: _handleCCGroupCreated,
        onCCGroupDeletedCallback: _handleCCGroupDeleted,
        onCCGroupLeftCallback: _handleCCGroupLeft,
        onCCGroupMemberJoinedCallback: _handleCCGroupMemberJoined,
        onCCGroupMemberAddedCallback: _handleCCGroupMemberAdded,
        onCCGroupMemberKickedCallback: _handleCCGroupMemberKicked,
        onCCGroupMemberBannedCallback: _handleCCGroupMemberBanned,
        onCCGroupMemberUnbannedCallback: _handleCCGroupMemberUnbanned,
        onCCGroupMemberScopeChangedCallback: _handleCCGroupMemberScopeChanged,
        onCCOwnershipChangedCallback: _handleCCOwnershipChanged,
      ),
    );
  }

  // ============================================================
  // SDK LISTENER CALLBACKS
  // ============================================================

  /// Handle group member joined event from SDK
  /// Requirement: 6.2
  void _handleGroupMemberJoined(Action action, User joinedUser, Group group) {
    if (isClosed) return;
    add(
      GroupMemberJoined(action: action, joinedUser: joinedUser, group: group),
    );
  }

  /// Handle group member left event from SDK
  /// Requirement: 6.3
  void _handleGroupMemberLeft(Action action, User leftUser, Group group) {
    if (isClosed) return;
    add(GroupMemberLeft(action: action, leftUser: leftUser, group: group));
  }

  /// Handle group member kicked event from SDK
  /// Requirement: 6.4
  void _handleGroupMemberKicked(
    Action action,
    User kickedUser,
    User kickedBy,
    Group group,
  ) {
    if (isClosed) return;
    add(
      GroupMemberKicked(
        action: action,
        kickedUser: kickedUser,
        kickedBy: kickedBy,
        group: group,
      ),
    );
  }

  /// Handle group member banned event from SDK
  /// Requirement: 6.5
  void _handleGroupMemberBanned(
    Action action,
    User bannedUser,
    User bannedBy,
    Group group,
  ) {
    if (isClosed) return;
    add(
      GroupMemberBanned(
        action: action,
        bannedUser: bannedUser,
        bannedBy: bannedBy,
        group: group,
      ),
    );
  }

  /// Handle group member unbanned event from SDK
  void _handleGroupMemberUnbanned(
    Action action,
    User unbannedUser,
    User unbannedBy,
    Group group,
  ) {
    if (isClosed) return;
    add(
      GroupMemberUnbanned(
        action: action,
        unbannedUser: unbannedUser,
        unbannedBy: unbannedBy,
        group: group,
      ),
    );
  }

  /// Handle group member scope changed event from SDK
  /// Requirement: 6.5
  void _handleGroupMemberScopeChanged(
    Action action,
    User updatedBy,
    User updatedUser,
    String scopeChangedTo,
    String scopeChangedFrom,
    Group group,
  ) {
    if (isClosed) return;
    add(
      GroupMemberScopeChanged(
        action: action,
        updatedUser: updatedUser,
        scopeChangedTo: scopeChangedTo,
        scopeChangedFrom: scopeChangedFrom,
        group: group,
      ),
    );
  }

  /// Handle member added to group event from SDK
  /// Requirement: 6.2
  void _handleMemberAddedToGroup(
    Action action,
    User addedBy,
    User userAdded,
    Group group,
  ) {
    if (isClosed) return;
    // When a member is added to a group, update the group
    // If the logged-in user was added, mark hasJoined = true
    if (_loggedInUser != null && userAdded.uid == _loggedInUser!.uid) {
      group.hasJoined = true;
    }
    add(UpdateGroup(group));
  }

  /// Handle connection restored event
  /// Requirement: 6.6
  void _handleConnected() {
    if (isClosed) return;
    add(const ConnectionRestored());
  }

  /// Handle connection disconnected event
  void _handleDisconnected() {
    // No action needed on disconnect for groups list
  }

  // ============================================================
  // CC UI EVENT CALLBACKS
  // ============================================================

  /// Handle group created event from UI
  /// Requirement: 6.1
  void _handleCCGroupCreated(Group group) {
    if (isClosed) return;
    add(GroupCreated(group));
  }

  /// Handle group deleted event from UI
  void _handleCCGroupDeleted(Group group) {
    if (isClosed) return;
    add(RemoveGroup(group.guid));
  }

  /// Handle group left event from UI
  /// Requirement: 6.3
  void _handleCCGroupLeft(Action action, User leftUser, Group group) {
    if (isClosed) return;
    // If the logged-in user left, handle accordingly
    if (_loggedInUser != null && leftUser.uid == _loggedInUser!.uid) {
      if (group.type == GroupTypeConstants.private) {
        // Remove private groups when user leaves
        add(RemoveGroup(group.guid));
      } else {
        // For public/password groups, update hasJoined status
        group.hasJoined = false;
        group.scope = null;
        add(UpdateGroup(group));
      }
    } else {
      add(GroupMemberLeft(action: action, leftUser: leftUser, group: group));
    }
  }

  /// Handle group member joined event from UI
  /// Requirement: 6.2
  void _handleCCGroupMemberJoined(User joinedUser, Group group) {
    if (isClosed) return;
    // If the logged-in user joined, mark hasJoined = true
    if (_loggedInUser != null && joinedUser.uid == _loggedInUser!.uid) {
      group.hasJoined = true;
    }
    add(UpdateGroup(group));
  }

  /// Handle group member added event from UI
  /// Requirement: 6.2
  void _handleCCGroupMemberAdded(
    List<Action> messages,
    List<User> usersAdded,
    Group group,
    User addedBy,
  ) {
    if (isClosed) return;
    // Check if logged-in user was added
    if (_loggedInUser != null) {
      final wasLoggedInUserAdded = usersAdded.any(
        (user) => user.uid == _loggedInUser!.uid,
      );
      if (wasLoggedInUserAdded) {
        group.hasJoined = true;
      }
    }
    add(UpdateGroup(group));
  }

  /// Handle group member kicked event from UI
  /// Requirement: 6.4
  void _handleCCGroupMemberKicked(
    Action action,
    User kickedUser,
    User kickedBy,
    Group group,
  ) {
    if (isClosed) return;
    // If the logged-in user was kicked
    if (_loggedInUser != null && kickedUser.uid == _loggedInUser!.uid) {
      if (group.type == GroupTypeConstants.private) {
        add(RemoveGroup(group.guid));
      } else {
        group.hasJoined = false;
        group.scope = null;
        add(UpdateGroup(group));
      }
    } else {
      add(UpdateGroup(group));
    }
  }

  /// Handle group member banned event from UI
  /// Requirement: 6.5
  void _handleCCGroupMemberBanned(
    Action action,
    User bannedUser,
    User bannedBy,
    Group group,
  ) {
    if (isClosed) return;
    // If the logged-in user was banned
    if (_loggedInUser != null && bannedUser.uid == _loggedInUser!.uid) {
      if (group.type == GroupTypeConstants.private) {
        add(RemoveGroup(group.guid));
      } else {
        group.hasJoined = false;
        group.scope = null;
        add(UpdateGroup(group));
      }
    } else {
      add(UpdateGroup(group));
    }
  }

  /// Handle group member unbanned event from UI
  void _handleCCGroupMemberUnbanned(
    Action action,
    User unbannedUser,
    User unbannedBy,
    Group group,
  ) {
    if (isClosed) return;
    add(UpdateGroup(group));
  }

  /// Handle group member scope changed event from UI
  /// Requirement: 6.5
  void _handleCCGroupMemberScopeChanged(
    Action action,
    User updatedUser,
    String scopeChangedTo,
    String scopeChangedFrom,
    Group group,
  ) {
    if (isClosed) return;
    // If the logged-in user's scope changed, update the group's scope
    if (_loggedInUser != null && updatedUser.uid == _loggedInUser!.uid) {
      group.scope = scopeChangedTo;
    }
    add(UpdateGroup(group));
  }

  /// Handle ownership changed event from UI
  void _handleCCOwnershipChanged(Group group, GroupMember newOwner) {
    if (isClosed) return;
    add(GroupOwnershipTransferred(group: group, newOwner: newOwner));
  }

  // ============================================================
  // EVENT HANDLERS
  // ============================================================

  /// Load initial groups
  /// [quiet] marks the kit's own cache-reset reload: a real error over the
  /// cached rows it shows does not reach `onError` (D84 (5)).
  Future<void> _onLoadGroups(
    LoadGroups event,
    Emitter<GroupsState> emit, {
    bool quiet = false,
  }) async {
    // Silent refresh: keep existing list visible, skip loading shimmer.
    final isSilentRefresh = event.silent || state is GroupsLoaded;

    if (!isSilentRefresh) {
      emit(const GroupsLoading());
    }

    _isLoadingMore = false;
    _currentSearchKeyword = event.searchKeyword;
    final version = ++_readVersion;
    _reloadOnConnect = null;

    // Reset the SDK request cursor for a fresh load
    getGroupsUseCase.resetRequest();

    if (_loggedInUser == null) {
      final userResult = await getLoggedInUserUseCase();
      if (userResult is Success<User?>) {
        _loggedInUser = userResult.data;
      }
    }

    final offlineSource = OfflineGate.isOn()
        ? GroupsOffline.twoPhaseSourceFor(getGroupsUseCase.repository)
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

    final result = await getGroupsUseCase(
      limit: _pageSize,
      searchKeyword: event.searchKeyword,
      groupsRequestBuilder: groupsRequestBuilder,
    );

    if (version != _readVersion) return;

    if (result is Success<List<Group>>) {
      final groups = result.data;
      if (groups.isEmpty && !isSilentRefresh) {
        emit(const GroupsEmpty());
      } else if (groups.isNotEmpty) {
        replaceAll(groups);
        // A fresh first page reopens paging. A silent reload keeps the
        // previous state's hasMore otherwise, which is false once a search's
        // pages ran out, or once a refreshed list had been paged to its end.
        if (state is GroupsLoaded) {
          emit((state as GroupsLoaded).copyWith(hasMore: true));
        }
      }
    } else if (result is Failure && !isSilentRefresh) {
      emit(GroupsError(message: result.message));
    }
  }

  /// Load more groups (pagination)
  Future<void> _onLoadMoreGroups(
    LoadMoreGroups event,
    Emitter<GroupsState> emit,
  ) async {
    if (state is! GroupsLoaded) return;

    final currentState = state as GroupsLoaded;

    if (!currentState.hasMore || currentState.isLoadingMore || _isLoadingMore) {
      return;
    }

    _isLoadingMore = true;
    emit(currentState.copyWith(isLoadingMore: true));
    final version = _readVersion;
    final seq = ++_loadMoreSeq;

    final offlineSource = OfflineGate.isOn()
        ? GroupsOffline.twoPhaseSourceFor(loadMoreGroupsUseCase.repository)
        : null;
    if (offlineSource != null) {
      await _loadMoreTwoPhase(offlineSource, emit, version: version, seq: seq);
      return;
    }

    final result = await loadMoreGroupsUseCase(
      limit: _pageSize,
      searchKeyword: _currentSearchKeyword,
      currentGroups: currentState.groups,
    );

    // A newer read owns the list now.
    if (version != _readVersion) {
      _dropStaleLoadMore(seq, emit);
      return;
    }

    _isLoadingMore = false;

    if (result is Success<List<Group>>) {
      final newGroups = result.data;

      if (newGroups.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
        return;
      }

      final allGroups = [...currentState.groups, ...newGroups];
      replaceAll(allGroups);
      // Only an empty page ends paging, as on Android. A short page proves
      // nothing here: this use case drops groups the list already holds, and
      // real-time events add groups ahead of the cursor. The request after the
      // last page is answered by the SDK from its page count.
      if (state is GroupsLoaded) {
        emit(
          (state as GroupsLoaded).copyWith(hasMore: true, isLoadingMore: false),
        );
      }
    } else if (result is Failure) {
      emit(
        GroupsError(
          message: result.message,
          previousGroups: currentState.groups,
        ),
      );
    }
  }

  // ============================================================
  // OFFLINE-ON READS (W6). Reached only when OfflineGate.isOn() was true
  // for this operation and the kit's own data source is in use.
  // ============================================================

  String _offlineFailureMessage(CometChatException e) =>
      'Failed to load groups: ${e.message ?? 'Failed to fetch groups'}';

  /// A first page (load, refresh, reconnect, search) read in two phases: the
  /// cached page paints at once, the server page then replaces it by guid.
  /// A silent reload over rows already shown skips the cached page, so the
  /// rows swap once. An error after a cached page keeps the rows; only a real
  /// error on a load the user or app started reaches `onError` (D84 (2),
  /// (5)). With nothing shown, offline is the offline state ("Connect to load
  /// groups", or "Connect to search" under a keyword), which loads again once
  /// on reconnect; any other error is the error view, as today (D84 (3),
  /// (4), (7)). A read that a newer one replaced ([version]) stops at once.
  Future<void> _loadFirstPageTwoPhase(
    GroupsRemoteDataSourceImpl source,
    Emitter<GroupsState> emit, {
    required String? keyword,
    required bool isSilentRefresh,
    required bool isSearch,
    required int version,
    bool quiet = false,
  }) async {
    final current = state;
    final rowsShown = current is GroupsLoaded && current.groups.isNotEmpty;
    var cachedShown = false;
    final pages = GroupsOffline.readNextPage(
      source,
      limit: _pageSize,
      searchKeyword: keyword,
      groupsRequestBuilder: groupsRequestBuilder,
    );
    await for (final phase in pages) {
      if (isClosed || version != _readVersion) return;
      switch (phase) {
        case Cached<Group>(:final rows):
          if (rowsShown || rows.isEmpty) break;
          cachedShown = true;
          replaceAll(rows);
        case Server<Group>(:final rows):
          if (rows.isEmpty) {
            if (cachedShown) {
              replaceAll(const <Group>[]);
            } else if (isSearch || !isSilentRefresh) {
              emit(const GroupsEmpty());
            }
            break;
          }
          _markNextReplace = true;
          replaceAll(rows);
          if (!isSearch && state is GroupsLoaded) {
            emit((state as GroupsLoaded).copyWith(hasMore: true));
          }
        case PhaseError<Group>(:final error):
          final offline = GroupsOffline.isConnectivityError(error);
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
                : LoadGroups(searchKeyword: keyword);
            emit(
              GroupsOffline.hasServerOnlyFilter(keyword, groupsRequestBuilder)
                  ? const GroupsConnectToSearch()
                  : GroupsConnectToLoad(error),
            );
            break;
          }
          if (isSearch) {
            emit(
              GroupsError(
                message: _offlineFailureMessage(error),
                previousGroups: _originalGroups,
              ),
            );
          } else if (!isSilentRefresh) {
            emit(GroupsError(message: _offlineFailureMessage(error)));
          }
      }
    }
  }

  /// The next page read in two phases. The cached page is appended at once
  /// (rows already listed are skipped), and the server page then replaces it
  /// by guid. Only an empty server page ends paging. An error keeps every
  /// row; paging stays open only if a cached page was shown (more may be
  /// cached), and a reconnect reload reopens it otherwise.
  Future<void> _loadMoreTwoPhase(
    GroupsRemoteDataSourceImpl source,
    Emitter<GroupsState> emit, {
    required int version,
    required int seq,
  }) async {
    final provisional = <String>{};
    final pages = GroupsOffline.readNextPage(
      source,
      limit: _pageSize,
      searchKeyword: _currentSearchKeyword,
      groupsRequestBuilder: groupsRequestBuilder,
    );
    await for (final phase in pages) {
      if (isClosed) return;
      if (version != _readVersion) {
        _dropStaleLoadMore(seq, emit);
        return;
      }
      switch (phase) {
        case Cached<Group>(:final rows):
          final merged = GroupsOffline.appendCached(items, rows, provisional);
          if (provisional.isEmpty) break;
          replaceAll(merged);
        case Server<Group>(:final rows):
          _isLoadingMore = false;
          if (rows.isNotEmpty || provisional.isNotEmpty) {
            _markNextReplace = true;
            replaceAll(GroupsOffline.replacePage(items, provisional, rows));
          }
          if (state is GroupsLoaded) {
            emit(
              (state as GroupsLoaded).copyWith(
                hasMore: rows.isNotEmpty,
                isLoadingMore: false,
              ),
            );
          }
        case PhaseError<Group>():
          _isLoadingMore = false;
          if (state is GroupsLoaded) {
            emit(
              (state as GroupsLoaded).copyWith(
                hasMore: provisional.isNotEmpty,
                isLoadingMore: false,
              ),
            );
          }
      }
    }
  }

  /// Refresh groups list
  Future<void> _onRefreshGroups(
    RefreshGroups event,
    Emitter<GroupsState> emit,
  ) async {
    add(LoadGroups(searchKeyword: _currentSearchKeyword, silent: true));
  }

  /// Search groups by keyword with debouncing
  ///
  /// This method implements search functionality with the following behavior:
  /// - Debounces search requests to prevent excessive API calls (Requirement 7.3)
  /// - Stores the original groups list before searching (Requirement 7.2)
  /// - Restores the original list when search is cleared (Requirement 7.2)
  /// - Fetches groups matching the search keyword (Requirement 7.1)
  ///
  /// Requirements: 7.1, 7.2, 7.3
  Future<void> _onSearchGroups(
    SearchGroups event,
    Emitter<GroupsState> emit,
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

      // Restore original groups if we have them stored
      if (_originalGroups != null && _originalGroups!.isNotEmpty) {
        add(_RestoreOriginalGroups(_originalGroups!));
        _originalGroups = null;
      } else if (_originalGroups != null && _originalGroups!.isEmpty) {
        // Original list was empty
        _originalGroups = null;
        emit(const GroupsEmpty());
      } else {
        // No original groups stored, refresh from API
        add(const LoadGroups());
      }
      return;
    }

    // Store original groups before first search (Requirement 7.2)
    if (_currentSearchKeyword == null && state is GroupsLoaded) {
      final currentState = state as GroupsLoaded;
      _originalGroups = List<Group>.from(currentState.groups);
    }

    // Debounce the search request (Requirement 7.3)
    _searchDebounceTimer = Timer(_searchDebounceDuration, () {
      if (isClosed) return;
      add(_ExecuteSearch(keyword));
    });
  }

  /// Execute the actual search API call
  ///
  /// This is called after the debounce period has elapsed.
  /// Requirements: 7.1
  Future<void> _onExecuteSearch(
    _ExecuteSearch event,
    Emitter<GroupsState> emit,
  ) async {
    _currentSearchKeyword = event.keyword;
    final version = ++_readVersion;
    _reloadOnConnect = null;
    // A load-more of the previous list drops its page; paging restarts here.
    _isLoadingMore = false;

    // Reset the SDK request cursor for a new search
    getGroupsUseCase.resetRequest();

    // Emit loading state while searching
    emit(const GroupsLoading());

    final offlineSource = OfflineGate.isOn()
        ? GroupsOffline.twoPhaseSourceFor(getGroupsUseCase.repository)
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

    final result = await getGroupsUseCase(
      limit: _pageSize,
      searchKeyword: event.keyword,
      groupsRequestBuilder: groupsRequestBuilder,
    );

    if (isClosed || version != _readVersion) return;

    if (result is Success<List<Group>>) {
      final groups = result.data;
      if (groups.isEmpty) {
        emit(const GroupsEmpty());
      } else {
        replaceAll(groups);
      }
    } else if (result is Failure) {
      emit(
        GroupsError(message: result.message, previousGroups: _originalGroups),
      );
    }
  }

  /// Restore original groups after search is cleared, then reload the first
  /// page.
  ///
  /// The search replaced the SDK request, so the cursor that paged the
  /// original list is gone. A load-more from a reset cursor fetched page one
  /// again — from a default builder, since load-more does not carry
  /// [groupsRequestBuilder] — deduped it to nothing and ended the list. A
  /// fresh first page, built from [groupsRequestBuilder] as Android rebuilds
  /// its request on clear, gives later pages a cursor to follow. The restored
  /// list shows in the meantime.
  ///
  /// Requirements: 7.2
  void _onRestoreOriginalGroups(
    _RestoreOriginalGroups event,
    Emitter<GroupsState> emit,
  ) {
    // Drop the search's request so nothing pages on from it before the reload
    getGroupsUseCase.resetRequest();
    replaceAll(event.groups);
    add(const LoadGroups(silent: true));
  }

  /// Toggle group selection (will be fully implemented in Task 5.10)
  void _onToggleGroupSelection(
    ToggleGroupSelection event,
    Emitter<GroupsState> emit,
  ) {
    if (state is! GroupsLoaded) return;

    final currentState = state as GroupsLoaded;
    final selected = Set<String>.from(currentState.selectedGroups);

    if (selected.contains(event.guid)) {
      selected.remove(event.guid);
    } else {
      selected.add(event.guid);
    }

    emit(currentState.copyWith(selectedGroups: selected));
  }

  /// Clear all group selections (will be fully implemented in Task 5.10)
  void _onClearGroupSelection(
    ClearGroupSelection event,
    Emitter<GroupsState> emit,
  ) {
    if (state is! GroupsLoaded) return;

    final currentState = state as GroupsLoaded;
    emit(currentState.copyWith(selectedGroups: {}));
  }

  /// Update a specific group
  void _onUpdateGroup(UpdateGroup event, Emitter<GroupsState> emit) {
    if (state is! GroupsLoaded) return;

    final groupIndex = findGroupIndex(event.group.guid);

    if (groupIndex == null) {
      addItem(event.group);
      return;
    }

    updateItem(groupIndex, event.group);
  }

  /// Add a new group to the list
  void _onAddGroup(AddGroup event, Emitter<GroupsState> emit) {
    if (state is! GroupsLoaded) return;

    // Check if group already exists
    final existingIndex = findGroupIndex(event.group.guid);
    if (existingIndex != null) {
      // Update existing group instead
      updateItem(existingIndex, event.group);
      return;
    }

    // Add new group at the beginning of the list
    insertItemAt(0, event.group);
  }

  /// Remove a group from the list
  void _onRemoveGroup(RemoveGroup event, Emitter<GroupsState> emit) {
    if (state is! GroupsLoaded) return;

    final group = findGroup(event.guid);
    if (group != null) {
      removeItem(group);
    }
  }

  // ============================================================
  // SDK LISTENER EVENT HANDLERS (Placeholders for Task 5.6)
  // ============================================================

  void _onGroupCreated(GroupCreated event, Emitter<GroupsState> emit) {
    // Requirement: 6.1 - Add newly created group to the list
    add(AddGroup(event.group));
  }

  void _onGroupMemberJoined(
    GroupMemberJoined event,
    Emitter<GroupsState> emit,
  ) {
    // Requirement: 6.2 - Update member count and hasJoined status
    final group = event.group;

    // If the logged-in user joined, mark hasJoined = true
    if (_loggedInUser != null && event.joinedUser.uid == _loggedInUser!.uid) {
      group.hasJoined = true;
    }

    add(UpdateGroup(group));
  }

  void _onGroupMemberLeft(GroupMemberLeft event, Emitter<GroupsState> emit) {
    // Requirement: 6.3 - Update group or remove if private
    final group = event.group;

    // If the logged-in user left
    if (_loggedInUser != null && event.leftUser.uid == _loggedInUser!.uid) {
      if (group.type == GroupTypeConstants.private) {
        // Remove private groups when user leaves
        add(RemoveGroup(group.guid));
      } else {
        // For public/password groups, update hasJoined status
        group.hasJoined = false;
        group.scope = null;
        add(UpdateGroup(group));
      }
    } else {
      // Another user left, just update the group
      add(UpdateGroup(group));
    }
  }

  void _onGroupMemberKicked(
    GroupMemberKicked event,
    Emitter<GroupsState> emit,
  ) {
    // Requirement: 6.4 - Handle kicked member
    final group = event.group;

    // If the logged-in user was kicked
    if (_loggedInUser != null && event.kickedUser.uid == _loggedInUser!.uid) {
      if (group.type == GroupTypeConstants.private) {
        add(RemoveGroup(group.guid));
      } else {
        group.hasJoined = false;
        group.scope = null;
        add(UpdateGroup(group));
      }
    } else {
      add(UpdateGroup(group));
    }
  }

  void _onGroupMemberBanned(
    GroupMemberBanned event,
    Emitter<GroupsState> emit,
  ) {
    // Requirement: 6.5 - Handle banned member
    final group = event.group;

    // If the logged-in user was banned
    if (_loggedInUser != null && event.bannedUser.uid == _loggedInUser!.uid) {
      if (group.type == GroupTypeConstants.private) {
        add(RemoveGroup(group.guid));
      } else {
        group.hasJoined = false;
        group.scope = null;
        add(UpdateGroup(group));
      }
    } else {
      add(UpdateGroup(group));
    }
  }

  void _onGroupMemberUnbanned(
    GroupMemberUnbanned event,
    Emitter<GroupsState> emit,
  ) {
    // Handle unbanned member - just update the group
    add(UpdateGroup(event.group));
  }

  void _onGroupMemberScopeChanged(
    GroupMemberScopeChanged event,
    Emitter<GroupsState> emit,
  ) {
    // Requirement: 6.5 - Handle scope change
    final group = event.group;

    // If the logged-in user's scope changed, update the group's scope
    if (_loggedInUser != null && event.updatedUser.uid == _loggedInUser!.uid) {
      group.scope = event.scopeChangedTo;
    }

    add(UpdateGroup(group));
  }

  void _onGroupOwnershipTransferred(
    GroupOwnershipTransferred event,
    Emitter<GroupsState> emit,
  ) {
    // Handle ownership transfer - update the group
    final group = event.group;

    // If the logged-in user became the owner, update scope
    if (_loggedInUser != null && event.newOwner.uid == _loggedInUser!.uid) {
      group.scope = GroupMemberScope.owner;
    }

    add(UpdateGroup(group));
  }

  void _onConnectionRestored(
    ConnectionRestored event,
    Emitter<GroupsState> emit,
  ) {
    // Requirement: 6.6 - Refresh groups list on connection restored
    final reload = _reloadOnConnect;
    if (state is GroupsLoaded) {
      add(const RefreshGroups());
    } else if (reload != null &&
        (state is GroupsConnectToLoad || state is GroupsConnectToSearch)) {
      // The offline state: the failed read runs again, once (D84 (8)).
      _reloadOnConnect = null;
      add(reload);
    }
  }

  void _onInitializeLoggedInUser(
    InitializeLoggedInUser event,
    Emitter<GroupsState> emit,
  ) {
    _loggedInUser = event.user;
  }

  // ============================================================
  // INTERNAL EVENT HANDLERS
  // ============================================================

  void _onListStateChanged(_ListStateChanged event, Emitter<GroupsState> emit) {
    if (event.isEmpty) {
      emit(const GroupsEmpty());
    } else {
      final currentState = state;
      if (currentState is GroupsLoaded) {
        emit(currentState.copyWith(groups: event.groups, isLoadingMore: false));
      } else {
        emit(GroupsLoaded(groups: event.groups, hasMore: true));
      }
    }
  }

  @override
  Future<void> close() {
    // Cancel search debounce timer
    _searchDebounceTimer?.cancel();
    _offlineResetSub?.cancel();

    // Remove SDK listeners (Requirement 1.7)
    if (!disableSDKListeners) {
      CometChat.removeGroupListener(_groupListenerKey);
      CometChat.removeConnectionListener(_connectionListenerKey);
      CometChatGroupEvents.removeGroupsListener(_ccGroupListenerKey);
    }

    return super.close();
  }
}

// ============================================================
// INTERNAL EVENTS
// ============================================================

class _ListStateChanged extends GroupsEvent {
  final List<Group> groups;
  final bool isEmpty;

  const _ListStateChanged({required this.groups, required this.isEmpty});

  @override
  List<Object?> get props => [groups, isEmpty];
}

/// Internal event for executing search after debounce
/// This is used internally by the BLoC and should not be dispatched externally
class _ExecuteSearch extends GroupsEvent {
  final String keyword;

  const _ExecuteSearch(this.keyword);

  @override
  List<Object> get props => [keyword];
}

/// Internal event for restoring original groups after search is cleared
/// This is used internally by the BLoC and should not be dispatched externally
class _RestoreOriginalGroups extends GroupsEvent {
  final List<Group> groups;

  const _RestoreOriginalGroups(this.groups);

  @override
  List<Object> get props => [groups];
}

/// A current-gen session end or cache reset from the offline hub (G8).
class _OfflineListReset extends GroupsEvent {
  const _OfflineListReset(this.event);

  final OfflineHubEvent event;

  @override
  List<Object?> get props => [event];
}

/// The one reload after a cache reset (G8), kit-started.
class _CacheResetReload extends GroupsEvent {
  const _CacheResetReload(this.keyword);

  final String? keyword;

  @override
  List<Object?> get props => [keyword];
}

// ============================================================
// SDK LISTENERS
// ============================================================

/// Group listener for SDK group events
class _GroupsGroupListener with GroupListener {
  final void Function(Action, User, Group) onGroupMemberJoinedCallback;
  final void Function(Action, User, Group) onGroupMemberLeftCallback;
  final void Function(Action, User, User, Group) onGroupMemberKickedCallback;
  final void Function(Action, User, User, Group) onGroupMemberBannedCallback;
  final void Function(Action, User, User, Group) onGroupMemberUnbannedCallback;
  final void Function(Action, User, User, String, String, Group)
  onGroupMemberScopeChangedCallback;
  final void Function(Action, User, User, Group) onMemberAddedToGroupCallback;
  final String? loggedInUserId;

  _GroupsGroupListener({
    required this.onGroupMemberJoinedCallback,
    required this.onGroupMemberLeftCallback,
    required this.onGroupMemberKickedCallback,
    required this.onGroupMemberBannedCallback,
    required this.onGroupMemberUnbannedCallback,
    required this.onGroupMemberScopeChangedCallback,
    required this.onMemberAddedToGroupCallback,
    this.loggedInUserId,
  });

  @override
  void onGroupMemberJoined(Action action, User joinedUser, Group joinedGroup) {
    onGroupMemberJoinedCallback(action, joinedUser, joinedGroup);
  }

  @override
  void onGroupMemberLeft(Action action, User leftUser, Group leftGroup) {
    onGroupMemberLeftCallback(action, leftUser, leftGroup);
  }

  @override
  void onGroupMemberKicked(
    Action action,
    User kickedUser,
    User kickedBy,
    Group kickedFrom,
  ) {
    onGroupMemberKickedCallback(action, kickedUser, kickedBy, kickedFrom);
  }

  @override
  void onGroupMemberBanned(
    Action action,
    User bannedUser,
    User bannedBy,
    Group bannedFrom,
  ) {
    onGroupMemberBannedCallback(action, bannedUser, bannedBy, bannedFrom);
  }

  @override
  void onGroupMemberUnbanned(
    Action action,
    User unbannedUser,
    User unbannedBy,
    Group unbannedFrom,
  ) {
    onGroupMemberUnbannedCallback(
      action,
      unbannedUser,
      unbannedBy,
      unbannedFrom,
    );
  }

  @override
  void onGroupMemberScopeChanged(
    Action action,
    User updatedBy,
    User updatedUser,
    String scopeChangedTo,
    String scopeChangedFrom,
    Group group,
  ) {
    onGroupMemberScopeChangedCallback(
      action,
      updatedBy,
      updatedUser,
      scopeChangedTo,
      scopeChangedFrom,
      group,
    );
  }

  @override
  void onMemberAddedToGroup(
    Action action,
    User addedBy,
    User userAdded,
    Group addedTo,
  ) {
    onMemberAddedToGroupCallback(action, addedBy, userAdded, addedTo);
  }
}

/// Connection listener for connection state
class _GroupsConnectionListener with ConnectionListener {
  final void Function() onConnectedCallback;
  final void Function() onDisconnectedCallback;

  _GroupsConnectionListener({
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

// ============================================================
// CC UI EVENT LISTENERS
// ============================================================

/// CC Group event listener for UI-triggered group events
class _GroupsCCEventListener with CometChatGroupEventListener {
  final void Function(Group) onCCGroupCreatedCallback;
  final void Function(Group) onCCGroupDeletedCallback;
  final void Function(Action, User, Group) onCCGroupLeftCallback;
  final void Function(User, Group) onCCGroupMemberJoinedCallback;
  final void Function(List<Action>, List<User>, Group, User)
  onCCGroupMemberAddedCallback;
  final void Function(Action, User, User, Group) onCCGroupMemberKickedCallback;
  final void Function(Action, User, User, Group) onCCGroupMemberBannedCallback;
  final void Function(Action, User, User, Group)
  onCCGroupMemberUnbannedCallback;
  final void Function(Action, User, String, String, Group)
  onCCGroupMemberScopeChangedCallback;
  final void Function(Group, GroupMember) onCCOwnershipChangedCallback;

  _GroupsCCEventListener({
    required this.onCCGroupCreatedCallback,
    required this.onCCGroupDeletedCallback,
    required this.onCCGroupLeftCallback,
    required this.onCCGroupMemberJoinedCallback,
    required this.onCCGroupMemberAddedCallback,
    required this.onCCGroupMemberKickedCallback,
    required this.onCCGroupMemberBannedCallback,
    required this.onCCGroupMemberUnbannedCallback,
    required this.onCCGroupMemberScopeChangedCallback,
    required this.onCCOwnershipChangedCallback,
  });

  @override
  void ccGroupCreated(Group group) {
    onCCGroupCreatedCallback(group);
  }

  @override
  void ccGroupDeleted(Group group) {
    onCCGroupDeletedCallback(group);
  }

  @override
  void ccGroupLeft(Action message, User leftUser, Group leftGroup) {
    onCCGroupLeftCallback(message, leftUser, leftGroup);
  }

  @override
  void ccGroupMemberJoined(User joinedUser, Group joinedGroup) {
    onCCGroupMemberJoinedCallback(joinedUser, joinedGroup);
  }

  @override
  void ccGroupMemberAdded(
    List<Action> messages,
    List<User> usersAdded,
    Group groupAddedIn,
    User addedBy,
  ) {
    onCCGroupMemberAddedCallback(messages, usersAdded, groupAddedIn, addedBy);
  }

  @override
  void ccGroupMemberKicked(
    Action message,
    User kickedUser,
    User kickedBy,
    Group kickedFrom,
  ) {
    onCCGroupMemberKickedCallback(message, kickedUser, kickedBy, kickedFrom);
  }

  @override
  void ccGroupMemberBanned(
    Action message,
    User bannedUser,
    User bannedBy,
    Group bannedFrom,
  ) {
    onCCGroupMemberBannedCallback(message, bannedUser, bannedBy, bannedFrom);
  }

  @override
  void ccGroupMemberUnbanned(
    Action message,
    User unbannedUser,
    User unbannedBy,
    Group unbannedFrom,
  ) {
    onCCGroupMemberUnbannedCallback(
      message,
      unbannedUser,
      unbannedBy,
      unbannedFrom,
    );
  }

  @override
  void ccGroupMemberScopeChanged(
    Action message,
    User updatedUser,
    String scopeChangedTo,
    String scopeChangedFrom,
    Group group,
  ) {
    onCCGroupMemberScopeChangedCallback(
      message,
      updatedUser,
      scopeChangedTo,
      scopeChangedFrom,
      group,
    );
  }

  @override
  void ccOwnershipChanged(Group group, GroupMember newOwner) {
    onCCOwnershipChangedCallback(group, newOwner);
  }
}
