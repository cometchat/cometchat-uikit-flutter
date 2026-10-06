import 'dart:async';
import 'package:flutter/widgets.dart' hide Action;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import '../domain/usecases/get_group_members_usecase.dart';
import '../domain/usecases/load_more_group_members_usecase.dart';
import '../domain/usecases/kick_group_member_usecase.dart';
import '../domain/usecases/ban_group_member_usecase.dart';
import '../domain/usecases/update_member_scope_usecase.dart';
import '../domain/usecases/get_logged_in_user_usecase.dart';
import '../domain/repositories/group_members_repository.dart';
import '../di/group_members_service_locator.dart';
import '../../shared/list_base.dart';
import '../../../../shared_ui/src/clean_architecture/core/result.dart';
import '../../../../shared_ui/src/clean_architecture/core/utils/detail_utils.dart';
import '../../../../shared_ui/src/clean_architecture/data/models/cometchat_group_member_option.dart';
import '../../../../shared_ui/src/clean_architecture/presentation/theme/colors/cometchat_color_palette.dart';
import '../../../../shared_ui/src/clean_architecture/presentation/theme/typography/cometchat_typography.dart';
import '../../../../shared_ui/src/clean_architecture/presentation/theme/spacing/cometchat_spacing.dart';
import '../../../../shared_ui/src/events/group_events/cometchat_group_events.dart';
import '../../../../shared_ui/src/constants/ui_kit_constants.dart';
import 'group_members_event.dart';
import 'group_members_state.dart';

/// BLoC for managing group members list
///
/// This BLoC manages the group members list state and handles:
/// - Loading and pagination of group members
/// - Real-time updates via SDK listeners (member joined/left/kicked/banned/scope changed)
/// - User presence updates (online/offline) via ValueNotifier for isolated rebuilds
/// - Selection management for batch operations
/// - Search functionality with debouncing
/// - Member actions (kick, ban, change scope)
///
/// This BLoC uses the [ListBase] mixin for list management operations.
/// Developers can extend this class and override the hook methods
/// (onItemAdded, onItemRemoved, onItemUpdated, onListCleared, onListReplaced)
/// to add custom logic like sorting, filtering, or validation.
class GroupMembersBloc extends Bloc<GroupMembersEvent, GroupMembersState>
    with ListBase<GroupMember> {
  // ============================================================
  // USE CASES
  // ============================================================

  /// Use case for fetching group members
  final GetGroupMembersUseCase getGroupMembersUseCase;

  /// Use case for loading more group members (pagination)
  final LoadMoreGroupMembersUseCase loadMoreGroupMembersUseCase;

  /// Use case for kicking a member from the group
  final KickGroupMemberUseCase kickGroupMemberUseCase;

  /// Use case for banning a member from the group
  final BanGroupMemberUseCase banGroupMemberUseCase;

  /// Use case for updating a member's scope
  final UpdateMemberScopeUseCase updateMemberScopeUseCase;

  /// Use case for getting the logged-in user
  final GetLoggedInUserUseCase getLoggedInUserUseCase;

  // ============================================================
  // GROUP CONTEXT
  // ============================================================

  /// The group whose members are being managed
  final Group group;

  /// The app's request builder, from `CometChatGroupMembers`'
  /// `groupMembersRequestBuilder`. Threaded down to
  /// GroupMembersRemoteDataSourceImpl, which builds each first page from it
  /// with [group]'s guid and the search keyword on top, and leaves it
  /// unchanged.
  final GroupMembersRequestBuilder? groupMembersRequestBuilder;

  /// Members per page: the app builder's limit, as Android uses it, else 30.
  int get _pageSize => groupMembersRequestBuilder?.limit ?? 30;

  // ============================================================
  // OPTIMIZATION: Map-based O(1) member lookups
  // ============================================================

  /// Map from member UID to index in items list for O(1) lookups
  final Map<String, int> _memberIndexMap = {};

  /// Flag to track if the index map needs rebuilding
  bool _mapNeedsRebuild = true;

  // ============================================================
  // OPTIMIZATION: Per-member status using ValueNotifier
  // Each member has its own notifier - only affected item rebuilds
  // ============================================================

  /// Map from member UID to status ValueNotifier for isolated rebuilds
  final Map<String, ValueNotifier<String>> _statusNotifiers = {};

  // ============================================================
  // SDK LISTENER IDS
  // ============================================================

  /// Unique key for group SDK listener
  final String _groupListenerKey;

  /// Unique key for user SDK listener (presence)
  final String _userListenerKey;

  /// Unique key for connection SDK listener
  final String _connectionListenerKey;

  // ============================================================
  // CONFIGURATION OPTIONS
  // ============================================================

  /// Whether to show user online/offline status
  final bool usersStatusVisibility;

  /// Whether to hide the kick member option in actions
  final bool hideKickMemberOption;

  /// Whether to hide the ban member option in actions
  final bool hideBanMemberOption;

  /// Whether to hide the scope change option in actions
  final bool hideScopeChangeOption;

  /// Whether to disable SDK listeners
  final bool disableSDKListeners;

  // ============================================================
  // INTERNAL STATE
  // ============================================================

  /// Currently logged-in user
  User? _loggedInUser;

  /// Getter for logged-in user (used by adapter)
  User? get loggedInUser => _loggedInUser;

  /// Cached conversation ID for action messages
  String? _conversationId;

  /// Repository reference for fetching conversation
  final GroupMembersRepository _repository;

  /// Pagination state tracking
  bool _isLoadingMore = false;

  /// First-page reloads after a cleared search still in flight. Load-more
  /// waits for them: until one lands there is no cursor past page one.
  int _firstPageReloads = 0;

  /// Current search keyword
  String? _currentSearchKeyword;

  /// Search debounce timer for preventing excessive API calls
  Timer? _searchDebounceTimer;

  /// Debounce duration for search (300ms is a good balance)
  static const Duration _searchDebounceDuration = Duration(milliseconds: 300);

  /// Original members list before search (for restoration when search is cleared)
  List<GroupMember>? _originalMembers;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  /// Helper to get initialized service locator
  static GroupMembersServiceLocator _getServiceLocator() {
    if (!GroupMembersServiceLocator.instance.isInitialized) {
      GroupMembersServiceLocator.instance.setup();
    }
    return GroupMembersServiceLocator.instance;
  }

  /// Creates a GroupMembersBloc.
  ///
  /// [group] - The group whose members to manage (required).
  /// [getGroupMembersUseCase] - Optional custom use case for fetching members.
  /// [loadMoreGroupMembersUseCase] - Optional custom use case for pagination.
  /// [kickGroupMemberUseCase] - Optional custom use case for kicking members.
  /// [banGroupMemberUseCase] - Optional custom use case for banning members.
  /// [updateMemberScopeUseCase] - Optional custom use case for scope changes.
  /// [getLoggedInUserUseCase] - Optional custom use case for logged-in user.
  /// [usersStatusVisibility] - Whether to show online/offline status (default: true).
  /// [hideKickMemberOption] - Whether to hide kick option (default: false).
  /// [hideBanMemberOption] - Whether to hide ban option (default: false).
  /// [hideScopeChangeOption] - Whether to hide scope change option (default: false).
  /// [disableSDKListeners] - Whether to disable SDK listeners (default: false).
  /// [groupMembersRequestBuilder] - Optional app builder every page is
  /// fetched with; its limit is the page size.
  GroupMembersBloc({
    required this.group,
    GetGroupMembersUseCase? getGroupMembersUseCase,
    LoadMoreGroupMembersUseCase? loadMoreGroupMembersUseCase,
    KickGroupMemberUseCase? kickGroupMemberUseCase,
    BanGroupMemberUseCase? banGroupMemberUseCase,
    UpdateMemberScopeUseCase? updateMemberScopeUseCase,
    GetLoggedInUserUseCase? getLoggedInUserUseCase,
    GroupMembersRepository? repository,
    this.usersStatusVisibility = true,
    this.hideKickMemberOption = false,
    this.hideBanMemberOption = false,
    this.hideScopeChangeOption = false,
    this.disableSDKListeners = false,
    this.groupMembersRequestBuilder,
  }) : getGroupMembersUseCase =
           getGroupMembersUseCase ??
           _getServiceLocator().getGroupMembersUseCase,
       loadMoreGroupMembersUseCase =
           loadMoreGroupMembersUseCase ??
           _getServiceLocator().loadMoreGroupMembersUseCase,
       kickGroupMemberUseCase =
           kickGroupMemberUseCase ??
           _getServiceLocator().kickGroupMemberUseCase,
       banGroupMemberUseCase =
           banGroupMemberUseCase ?? _getServiceLocator().banGroupMemberUseCase,
       updateMemberScopeUseCase =
           updateMemberScopeUseCase ??
           _getServiceLocator().updateMemberScopeUseCase,
       getLoggedInUserUseCase =
           getLoggedInUserUseCase ??
           _getServiceLocator().getLoggedInUserUseCase,
       _repository = repository ?? _getServiceLocator().repository,
       _groupListenerKey =
           'group_members_bloc_group_${DateTime.now().millisecondsSinceEpoch}',
       _userListenerKey =
           'group_members_bloc_user_${DateTime.now().millisecondsSinceEpoch}',
       _connectionListenerKey =
           'group_members_bloc_connection_${DateTime.now().millisecondsSinceEpoch}',
       super(const GroupMembersInitial()) {
    // Register public event handlers
    on<LoadGroupMembers>(_onLoadGroupMembers);
    on<LoadMoreGroupMembers>(_onLoadMoreGroupMembers);
    on<RefreshGroupMembers>(_onRefreshGroupMembers);
    on<SearchGroupMembers>(_onSearchGroupMembers);
    on<ToggleMemberSelection>(_onToggleMemberSelection);
    on<ClearMemberSelection>(_onClearMemberSelection);
    on<KickMember>(_onKickMember);
    on<BanMember>(_onBanMember);
    on<ChangeMemberScope>(_onChangeMemberScope);
    on<UpdateMember>(_onUpdateMember);

    // Register internal event handlers
    on<_MemberJoined>(_onMemberJoined);
    on<_MemberLeft>(_onMemberLeft);
    on<_MemberKicked>(_onMemberKicked);
    on<_MemberBanned>(_onMemberBanned);
    on<_MemberScopeChanged>(_onMemberScopeChanged);
    on<_UserStatusUpdate>(_onUserStatusUpdate);
    on<_ConnectionStateUpdate>(_onConnectionStateUpdate);
    on<_ListStateChanged>(_onListStateChanged);

    // Internal events for search functionality
    on<_ExecuteSearch>(_onExecuteSearch);
    on<_RestoreOriginalMembers>(_onRestoreOriginalMembers);
    on<_ReloadFirstPage>(_onReloadFirstPage);

    // Initialize and register SDK listeners
    _initializeAndRegisterListeners();
  }

  // ============================================================
  // O(1) MEMBER LOOKUP HELPERS
  // ============================================================

  /// Rebuild the index map from the current items list
  void _rebuildIndexMap() {
    _memberIndexMap.clear();
    for (int i = 0; i < items.length; i++) {
      _memberIndexMap[items[i].uid] = i;
    }
    _mapNeedsRebuild = false;
  }

  /// Find the index of a member by UID using O(1) lookup
  ///
  /// Returns null if the member is not found or UID is invalid.
  int? findMemberIndex(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    if (_mapNeedsRebuild && items.isNotEmpty) {
      _rebuildIndexMap();
    }
    return _memberIndexMap[uid];
  }

  /// Find a member by UID using O(1) lookup
  ///
  /// Returns null if the member is not found.
  GroupMember? findMember(String? uid) {
    final index = findMemberIndex(uid);
    if (index == null || index >= items.length) return null;
    return items[index];
  }

  // ============================================================
  // STATUS NOTIFIER HELPERS
  // ============================================================

  /// Get or create a status notifier for a specific member.
  /// Use this with ValueListenableBuilder in list items for isolated rebuilds.
  ///
  /// [uid] - The member's user ID.
  /// Returns a ValueNotifier containing the member's status ('online' or 'offline').
  ValueNotifier<String> getStatusNotifier(String uid) {
    return _statusNotifiers.putIfAbsent(
      uid,
      () => ValueNotifier<String>('offline'),
    );
  }

  /// Get current status for a member
  String getMemberStatus(String uid) {
    return _statusNotifiers[uid]?.value ?? 'offline';
  }

  // ============================================================
  // ListBase HOOKS - dispatch events for state changes
  // ============================================================

  @override
  void onItemAdded(GroupMember item, List<GroupMember> updatedList) {
    _mapNeedsRebuild = true;
    if (!isClosed) {
      add(_ListStateChanged(members: updatedList, isEmpty: false));
    }
  }

  @override
  void onItemRemoved(GroupMember item, List<GroupMember> updatedList) {
    _mapNeedsRebuild = true;
    if (!isClosed) {
      add(
        _ListStateChanged(members: updatedList, isEmpty: updatedList.isEmpty),
      );
    }
  }

  @override
  void onItemUpdated(
    GroupMember oldItem,
    GroupMember newItem,
    List<GroupMember> updatedList,
  ) {
    if (!isClosed) {
      add(_ListStateChanged(members: updatedList, isEmpty: false));
    }
  }

  @override
  void onListReplaced(
    List<GroupMember> previousList,
    List<GroupMember> newList,
  ) {
    _mapNeedsRebuild = true;
    if (!isClosed) {
      add(
        _ListStateChanged(
          members: newList,
          isEmpty: newList.isEmpty,
          hasMore: newList.length >= _pageSize,
        ),
      );
    }
  }

  @override
  void onListCleared(List<GroupMember> previousList) {
    _mapNeedsRebuild = true;
    if (!isClosed) {
      add(const _ListStateChanged(members: [], isEmpty: true));
    }
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> _initializeAndRegisterListeners() async {
    // Get logged-in user
    final result = await getLoggedInUserUseCase();
    if (result.isSuccess) {
      _loggedInUser = result.getOrNull();
    }

    // Get conversation for action messages
    final conversationResult = await _repository.getConversation(group.guid);
    if (conversationResult.isSuccess) {
      _conversationId = conversationResult.getOrNull()?.conversationId;
    }

    // Register SDK listeners if not disabled
    if (!disableSDKListeners) {
      _registerSDKListeners();
    }
  }

  void _registerSDKListeners() {
    // Register group listener for real-time member events
    CometChat.addGroupListener(
      _groupListenerKey,
      _GroupMembersGroupListener(
        onGroupMemberJoinedCallback: _handleMemberJoined,
        onGroupMemberLeftCallback: _handleMemberLeft,
        onGroupMemberKickedCallback: _handleMemberKicked,
        onGroupMemberBannedCallback: _handleMemberBanned,
        onGroupMemberScopeChangedCallback: _handleMemberScopeChanged,
        onMemberAddedToGroupCallback:
            _handleMemberJoined, // Same behavior as joined
      ),
    );

    // Register user listener for online/offline status updates
    if (usersStatusVisibility) {
      CometChat.addUserListener(
        _userListenerKey,
        _GroupMembersUserListener(
          onUserOnlineCallback: _handleUserOnline,
          onUserOfflineCallback: _handleUserOffline,
        ),
      );
    }

    // Register connection listener for reconnection handling
    CometChat.addConnectionListener(
      _connectionListenerKey,
      _GroupMembersConnectionListener(
        onConnectedCallback: _handleConnected,
        onDisconnectedCallback: _handleDisconnected,
      ),
    );
  }

  // ============================================================
  // SDK LISTENER CALLBACKS (stubs for task 12)
  // ============================================================

  void _handleMemberJoined(Action action, User joinedUser, Group joinedGroup) {
    if (isClosed) return;
    if (joinedGroup.guid != group.guid) return;

    // Create a GroupMember from the joinedUser
    final member = GroupMember(
      uid: joinedUser.uid,
      name: joinedUser.name,
      avatar: joinedUser.avatar,
      status: joinedUser.status ?? '',
      role: joinedUser.role ?? '',
      lastActiveAt: joinedUser.lastActiveAt,
      link: joinedUser.link,
      metadata: joinedUser.metadata,
      statusMessage: joinedUser.statusMessage,
      scope: GroupMemberScope.participant, // New members join as participants
      joinedAt: DateTime.now(),
    );

    // Dispatch _MemberJoined event with the member
    add(_MemberJoined(member: member));

    // Increment group members count
    group.membersCount++;
  }

  void _handleMemberLeft(Action action, User leftUser, Group leftGroup) {
    if (isClosed) return;
    if (leftGroup.guid != group.guid) return;

    // Dispatch _MemberLeft event with the user's UID
    add(_MemberLeft(uid: leftUser.uid));

    // Decrement group members count
    group.membersCount--;
  }

  void _handleMemberKicked(
    Action action,
    User kickedUser,
    User kickedBy,
    Group kickedFrom,
  ) {
    if (isClosed) return;
    if (kickedFrom.guid != group.guid) return;

    // Dispatch _MemberKicked event with the user's UID
    add(_MemberKicked(uid: kickedUser.uid));

    // Decrement group members count
    group.membersCount--;
  }

  void _handleMemberBanned(
    Action action,
    User bannedUser,
    User bannedBy,
    Group bannedFrom,
  ) {
    if (isClosed) return;
    if (bannedFrom.guid != group.guid) return;

    // Dispatch _MemberBanned event with the user's UID
    add(_MemberBanned(uid: bannedUser.uid));

    // Decrement group members count
    group.membersCount--;
  }

  void _handleMemberScopeChanged(
    Action action,
    User updatedBy,
    User updatedUser,
    String scopeChangedTo,
    String scopeChangedFrom,
    Group scopeGroup,
  ) {
    if (isClosed) return;
    if (scopeGroup.guid != group.guid) return;

    // Dispatch _MemberScopeChanged event with uid and newScope
    add(_MemberScopeChanged(uid: updatedUser.uid, newScope: scopeChangedTo));
  }

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
    if (isClosed) return;
    add(const _ConnectionStateUpdate(isConnected: true));
  }

  void _handleDisconnected() {
    if (isClosed) return;
    add(const _ConnectionStateUpdate(isConnected: false));
  }

  // ============================================================
  // EVENT HANDLERS (stubs for tasks 8.2, 8.3, 8.4)
  // ============================================================

  Future<void> _onLoadGroupMembers(
    LoadGroupMembers event,
    Emitter<GroupMembersState> emit,
  ) async {
    // Reset the pagination cursor so we always start from page 1.
    // The datasource is a singleton — without this, a previously exhausted
    // cursor returns 0 members on subsequent opens of the same group.
    _repository.resetPagination();

    // This page is unfiltered, so the pages load-more fetches after it must be
    // too, even when a refresh lands while a search is active.
    _currentSearchKeyword = null;

    // Emit loading state
    emit(const GroupMembersLoading());

    // Call use case to fetch group members
    final pageLimit = _pageSize;
    final result = await getGroupMembersUseCase(
      guid: group.guid,
      limit: pageLimit,
      groupMembersRequestBuilder: groupMembersRequestBuilder,
    );

    if (result.isSuccess) {
      final members = result.getOrNull() ?? [];

      if (members.isEmpty) {
        // Emit empty state when no members found
        emit(const GroupMembersEmpty());
      } else {
        // If we got fewer than the limit, there are no more pages
        final hasMore = members.length >= pageLimit;

        // Update the internal list (triggers onListReplaced hook which also
        // emits _ListStateChanged, but we override with the correct hasMore below)
        replaceAll(members);

        // Initialize status notifiers for each member for isolated rebuilds
        for (final member in members) {
          getStatusNotifier(member.uid);
        }

        // Emit directly with correct hasMore — overrides whatever the hook emitted
        emit(GroupMembersLoaded(members: members, hasMore: hasMore));
      }
    } else if (result is Failure) {
      // Emit error state with the failure message
      emit(GroupMembersError(message: result.message));
    }
  }

  Future<void> _onLoadMoreGroupMembers(
    LoadMoreGroupMembers event,
    Emitter<GroupMembersState> emit,
  ) async {
    // Check if state is GroupMembersLoaded - if not, return early
    if (state is! GroupMembersLoaded) return;

    final currentState = state as GroupMembersLoaded;

    // Check hasMore flag - if false, return early
    if (!currentState.hasMore) return;

    // Check isLoadingMore flag - if true, return early (prevent duplicate requests)
    if (currentState.isLoadingMore || _isLoadingMore || _firstPageReloads > 0) {
      return;
    }

    // Set loading flag and emit state with isLoadingMore: true
    _isLoadingMore = true;
    emit(currentState.copyWith(isLoadingMore: true));

    // Call LoadMoreGroupMembersUseCase with current members. The keyword and
    // builder are the ones the list's first page was fetched with, so the data
    // source pages on from that request instead of starting a new one.
    final result = await loadMoreGroupMembersUseCase(
      guid: group.guid,
      limit: _pageSize,
      searchKeyword: _currentSearchKeyword,
      currentMembers: items,
      groupMembersRequestBuilder: groupMembersRequestBuilder,
    );

    // Reset loading flag
    _isLoadingMore = false;

    if (result.isSuccess) {
      final newMembers = result.getOrNull() ?? [];

      if (newMembers.isEmpty) {
        // No more members to load
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
        return;
      }

      // Append new members using addItems (triggers onItemAdded hooks)
      for (final member in newMembers) {
        addItem(member);
        // Initialize status notifiers for new members
        getStatusNotifier(member.uid);
      }
    } else {
      // On failure: emit with isLoadingMore: false (don't show error for pagination failures)
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onRefreshGroupMembers(
    RefreshGroupMembers event,
    Emitter<GroupMembersState> emit,
  ) async {
    _repository.resetPagination();
    add(const LoadGroupMembers());
  }

  /// Search group members by keyword with debouncing
  ///
  /// This method implements search functionality with the following behavior:
  /// - Debounces search requests to prevent excessive API calls
  /// - Stores the original members list before searching
  /// - Restores the original list when search is cleared
  Future<void> _onSearchGroupMembers(
    SearchGroupMembers event,
    Emitter<GroupMembersState> emit,
  ) async {
    // Cancel any pending search request
    _searchDebounceTimer?.cancel();

    final keyword = event.keyword.trim();

    // If search is cleared, restore original list immediately (no debounce needed)
    if (keyword.isEmpty) {
      _currentSearchKeyword = null;

      // Restore original members if we have them stored
      if (_originalMembers != null && _originalMembers!.isNotEmpty) {
        add(_RestoreOriginalMembers(_originalMembers!));
        _originalMembers = null;
      } else if (_originalMembers != null && _originalMembers!.isEmpty) {
        // Original list was empty
        _originalMembers = null;
        emit(const GroupMembersEmpty());
      } else {
        // No original members stored, refresh from API
        add(const LoadGroupMembers());
      }
      return;
    }

    // Store original members before first search
    if (_currentSearchKeyword == null && state is GroupMembersLoaded) {
      final currentState = state as GroupMembersLoaded;
      _originalMembers = List<GroupMember>.from(currentState.members);
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
    Emitter<GroupMembersState> emit,
  ) async {
    _currentSearchKeyword = event.keyword;

    // Reset cursor so search always fetches from page 1
    _repository.resetPagination();

    // Call use case to fetch group members with search keyword
    final pageLimit = _pageSize;
    final result = await getGroupMembersUseCase(
      guid: group.guid,
      searchKeyword: event.keyword,
      limit: pageLimit,
      groupMembersRequestBuilder: groupMembersRequestBuilder,
    );

    if (isClosed) return;

    if (result.isSuccess) {
      final members = result.getOrNull() ?? [];

      if (members.isEmpty) {
        emit(const GroupMembersEmpty());
      } else {
        final hasMore = members.length >= pageLimit;
        for (final member in members) {
          getStatusNotifier(member.uid);
        }
        replaceAll(members);
        emit(GroupMembersLoaded(members: members, hasMore: hasMore));
      }
    }
    // On failure: keep current state (don't show error for search failures)
  }

  /// Restore original members after search is cleared, then reload the first
  /// page.
  ///
  /// The search replaced the SDK request, so the cursor that paged the
  /// original list is gone. A load-more from a reset cursor fetched page one
  /// again, deduped it to nothing and ended the list. A fresh first page,
  /// built from [groupMembersRequestBuilder] as Android rebuilds its request
  /// on clear, gives later pages a cursor to follow. The restored list shows
  /// in the meantime.
  void _onRestoreOriginalMembers(
    _RestoreOriginalMembers event,
    Emitter<GroupMembersState> emit,
  ) {
    // Clear search-related state
    _currentSearchKeyword = null;

    // Drop the search's request so nothing pages on from it before the reload
    _repository.resetPagination();

    // Replace list with original members (triggers onListReplaced hook)
    replaceAll(event.members);
    _firstPageReloads++;
    add(const _ReloadFirstPage());
  }

  /// Reload the first page in place, keeping the list on screen: no loading
  /// state, and the restored list stays if the page fails or comes back empty.
  Future<void> _onReloadFirstPage(
    _ReloadFirstPage event,
    Emitter<GroupMembersState> emit,
  ) async {
    _repository.resetPagination();
    final result = await getGroupMembersUseCase(
      guid: group.guid,
      limit: _pageSize,
      groupMembersRequestBuilder: groupMembersRequestBuilder,
    );
    _firstPageReloads--;

    // A search typed while this page loaded owns the list now.
    if (isClosed || _currentSearchKeyword != null) return;

    final members = result.getOrNull() ?? const <GroupMember>[];
    if (members.isEmpty) return;
    for (final member in members) {
      getStatusNotifier(member.uid);
    }
    // Triggers onListReplaced, which sets hasMore from the page's length.
    replaceAll(members);
  }

  // ============================================================
  // SELECTION EVENT HANDLERS (stubs for task 9)
  // ============================================================

  void _onToggleMemberSelection(
    ToggleMemberSelection event,
    Emitter<GroupMembersState> emit,
  ) {
    // Check if state is GroupMembersLoaded - if not, return early
    if (state is! GroupMembersLoaded) return;

    final currentState = state as GroupMembersLoaded;

    // Find the member by UID using O(1) lookup
    final member = findMember(event.uid);

    // If member not found, return early
    if (member == null) return;

    // Check if member is owner (scope == 'owner') - owners are not selectable
    if (member.scope == 'owner') return;

    // Create a mutable copy of the selected members set
    final selected = Set<String>.from(currentState.selectedMembers);

    // Toggle the member's selection state
    if (selected.contains(event.uid)) {
      selected.remove(event.uid);
    } else {
      selected.add(event.uid);
    }

    // Emit new state with updated selectedMembers
    emit(currentState.copyWith(selectedMembers: selected));
  }

  void _onClearMemberSelection(
    ClearMemberSelection event,
    Emitter<GroupMembersState> emit,
  ) {
    // Check if state is GroupMembersLoaded - if not, return early
    if (state is! GroupMembersLoaded) return;

    final currentState = state as GroupMembersLoaded;

    // Emit new state with empty selectedMembers set
    emit(currentState.copyWith(selectedMembers: const {}));
  }

  /// Get list of selected GroupMember objects
  ///
  /// Returns null if not in loaded state.
  List<GroupMember>? getSelectedList() {
    // Check if state is GroupMembersLoaded - if not, return null
    if (state is! GroupMembersLoaded) return null;

    final currentState = state as GroupMembersLoaded;

    // Get the selectedMembers set from state
    final selectedUids = currentState.selectedMembers;

    // Map each selected UID to its GroupMember using findMember(uid)
    // Filter out any null results (in case member was removed)
    return selectedUids
        .map((uid) => findMember(uid))
        .whereType<GroupMember>()
        .toList();
  }

  // ============================================================
  // DEFAULT OPTIONS
  // ============================================================

  /// Get default options for a group member based on logged-in user permissions.
  ///
  /// Returns available options (kick, ban, change scope) based on:
  /// - The logged-in user's scope/permissions in the group
  /// - The target member's scope
  /// - Configuration flags (hideKickMemberOption, hideBanMemberOption, hideScopeChangeOption)
  ///
  /// [member] - The group member to get options for.
  /// [context] - BuildContext for localization.
  /// [colorPalette] - Theme color palette.
  /// [typography] - Theme typography.
  /// [spacing] - Theme spacing.
  ///
  /// Returns a list of [CometChatGroupMemberOption] that can be displayed to the user.
  List<CometChatGroupMemberOption> getDefaultOptions(
    GroupMember member,
    BuildContext context,
    CometChatColorPalette colorPalette,
    CometChatTypography typography,
    CometChatSpacing spacing,
  ) {
    return DetailUtils.getDefaultGroupMemberOptions(
      loggedInUser: _loggedInUser,
      group: group,
      member: member,
      context: context,
      hideKickMemberOption: hideKickMemberOption,
      hideBanMemberOption: hideBanMemberOption,
      hideScopeChangeOption: hideScopeChangeOption,
    );
  }

  // ============================================================
  // MEMBER ACTION EVENT HANDLERS (stubs for task 10)
  // ============================================================

  Future<void> _onKickMember(
    KickMember event,
    Emitter<GroupMembersState> emit,
  ) async {
    // Call KickGroupMemberUseCase
    final result = await kickGroupMemberUseCase(
      guid: group.guid,
      uid: event.member.uid,
    );

    if (result.isSuccess) {
      // Decrement group members count
      group.membersCount--;

      // Create action message for the event
      final actionMessage = Action(
        conversationId: _conversationId ?? 'group_${group.guid}',
        message:
            '${_loggedInUser?.name ?? 'Someone'} kicked ${event.member.name}',
        oldScope: event.member.scope ?? GroupMemberScope.participant,
        newScope: '',
        muid: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: _loggedInUser,
        receiver: group,
        receiverUid: group.guid,
        type: MessageTypeConstants.groupActions,
        receiverType: ReceiverTypeConstants.group,
        parentMessageId: 0,
      );

      // Emit CometChatGroupEvents.ccGroupMemberKicked
      CometChatGroupEvents.ccGroupMemberKicked(
        actionMessage,
        event.member,
        _loggedInUser!,
        group,
      );

      // Remove member from list using ListBase mixin
      removeItem(event.member);
    } else if (result is Failure) {
      // Get previous members for recovery
      List<GroupMember>? previousMembers;
      if (state is GroupMembersLoaded) {
        previousMembers = (state as GroupMembersLoaded).members;
      }

      // Emit error state with failure message
      emit(
        GroupMembersError(
          message: result.message,
          previousMembers: previousMembers,
        ),
      );
    }
  }

  Future<void> _onBanMember(
    BanMember event,
    Emitter<GroupMembersState> emit,
  ) async {
    // Call BanGroupMemberUseCase
    final result = await banGroupMemberUseCase(
      guid: group.guid,
      uid: event.member.uid,
    );

    if (result.isSuccess) {
      // Decrement group members count
      group.membersCount--;

      // Create action message for the event
      final actionMessage = Action(
        conversationId: _conversationId ?? 'group_${group.guid}',
        message:
            '${_loggedInUser?.name ?? 'Someone'} banned ${event.member.name}',
        oldScope: event.member.scope ?? GroupMemberScope.participant,
        newScope: '',
        muid: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: _loggedInUser,
        receiver: group,
        receiverUid: group.guid,
        type: MessageTypeConstants.groupActions,
        receiverType: ReceiverTypeConstants.group,
        parentMessageId: 0,
      );

      // Emit CometChatGroupEvents.ccGroupMemberBanned
      CometChatGroupEvents.ccGroupMemberBanned(
        actionMessage,
        event.member,
        _loggedInUser!,
        group,
      );

      // Remove member from list using ListBase mixin
      removeItem(event.member);
    } else if (result is Failure) {
      // Get previous members for recovery
      List<GroupMember>? previousMembers;
      if (state is GroupMembersLoaded) {
        previousMembers = (state as GroupMembersLoaded).members;
      }

      // Emit error state with failure message
      emit(
        GroupMembersError(
          message: result.message,
          previousMembers: previousMembers,
        ),
      );
    }
  }

  Future<void> _onChangeMemberScope(
    ChangeMemberScope event,
    Emitter<GroupMembersState> emit,
  ) async {
    // Store old scope before updating
    final oldScope = event.member.scope ?? GroupMemberScope.participant;

    // Call UpdateMemberScopeUseCase
    final result = await updateMemberScopeUseCase(
      guid: group.guid,
      uid: event.member.uid,
      scope: event.newScope,
    );

    if (result.isSuccess) {
      // Find the member index using O(1) lookup
      final memberIndex = findMemberIndex(event.member.uid);

      if (memberIndex != null) {
        // Create updated member with new scope
        final updatedMember = GroupMember(
          uid: event.member.uid,
          name: event.member.name,
          avatar: event.member.avatar,
          status: event.member.status ?? '',
          role: event.member.role ?? '',
          lastActiveAt: event.member.lastActiveAt,
          link: event.member.link,
          metadata: event.member.metadata,
          statusMessage: event.member.statusMessage,
          scope: event.newScope,
          joinedAt: event.member.joinedAt,
        );

        // Update member in list using ListBase mixin
        updateItem(memberIndex, updatedMember);
      }

      // Create action message for the event
      final actionMessage = Action(
        conversationId: _conversationId ?? 'group_${group.guid}',
        message:
            '${_loggedInUser?.name ?? 'Someone'} made ${event.member.name} ${event.newScope}',
        oldScope: oldScope,
        newScope: event.newScope,
        muid: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: _loggedInUser,
        receiver: group,
        receiverUid: group.guid,
        type: MessageTypeConstants.groupActions,
        receiverType: ReceiverTypeConstants.group,
        parentMessageId: 0,
      );

      // Emit CometChatGroupEvents.ccGroupMemberScopeChanged
      CometChatGroupEvents.ccGroupMemberScopeChanged(
        actionMessage,
        event.member,
        event.newScope,
        oldScope,
        group,
      );
    } else if (result is Failure) {
      // Get previous members for recovery
      List<GroupMember>? previousMembers;
      if (state is GroupMembersLoaded) {
        previousMembers = (state as GroupMembersLoaded).members;
      }

      // Emit error state with failure message
      emit(
        GroupMembersError(
          message: result.message,
          previousMembers: previousMembers,
        ),
      );
    }
  }

  void _onUpdateMember(UpdateMember event, Emitter<GroupMembersState> emit) {
    if (state is! GroupMembersLoaded) return;

    final memberIndex = findMemberIndex(event.member.uid);

    if (memberIndex == null) {
      addItem(event.member);
      return;
    }

    updateItem(memberIndex, event.member);
  }

  // ============================================================
  // INTERNAL EVENT HANDLERS (stubs for task 12)
  // ============================================================

  void _onMemberJoined(_MemberJoined event, Emitter<GroupMembersState> emit) {
    // Check if state is GroupMembersLoaded - if not, return early
    if (state is! GroupMembersLoaded) return;

    // Check if member already exists using findMember(event.member.uid) - if exists, return early
    if (findMember(event.member.uid) != null) return;

    // Add member to list using addItem (triggers onItemAdded hook)
    addItem(event.member);

    // Initialize status notifier for the new member
    getStatusNotifier(event.member.uid);
  }

  void _onMemberLeft(_MemberLeft event, Emitter<GroupMembersState> emit) {
    // Check if state is GroupMembersLoaded - if not, return early
    if (state is! GroupMembersLoaded) return;

    // Find the member using findMember(event.uid)
    final member = findMember(event.uid);

    // If member found, remove using removeItem (triggers onItemRemoved hook)
    if (member != null) {
      removeItem(member);

      // Clean up status notifier for the removed member
      _statusNotifiers[event.uid]?.dispose();
      _statusNotifiers.remove(event.uid);
    }
  }

  void _onMemberKicked(_MemberKicked event, Emitter<GroupMembersState> emit) {
    // Check if state is GroupMembersLoaded - if not, return early
    if (state is! GroupMembersLoaded) return;

    // Find the member using findMember(event.uid)
    final member = findMember(event.uid);

    // If member found, remove using removeItem (triggers onItemRemoved hook)
    if (member != null) {
      removeItem(member);

      // Clean up status notifier for the removed member
      _statusNotifiers[event.uid]?.dispose();
      _statusNotifiers.remove(event.uid);
    }
  }

  void _onMemberBanned(_MemberBanned event, Emitter<GroupMembersState> emit) {
    // Check if state is GroupMembersLoaded - if not, return early
    if (state is! GroupMembersLoaded) return;

    // Find the member using findMember(event.uid)
    final member = findMember(event.uid);

    // If member found, remove using removeItem (triggers onItemRemoved hook)
    if (member != null) {
      removeItem(member);

      // Clean up status notifier for the removed member
      _statusNotifiers[event.uid]?.dispose();
      _statusNotifiers.remove(event.uid);
    }
  }

  void _onMemberScopeChanged(
    _MemberScopeChanged event,
    Emitter<GroupMembersState> emit,
  ) {
    // Check if state is GroupMembersLoaded - if not, return early
    if (state is! GroupMembersLoaded) return;

    // Find the member using findMember(event.uid)
    final member = findMember(event.uid);

    // If member not found, return early
    if (member == null) return;

    // Find the member index using O(1) lookup
    final memberIndex = findMemberIndex(event.uid);

    if (memberIndex != null) {
      // Create updated member with new scope
      final updatedMember = GroupMember(
        uid: member.uid,
        name: member.name,
        avatar: member.avatar,
        status: member.status ?? '',
        role: member.role ?? '',
        lastActiveAt: member.lastActiveAt,
        link: member.link,
        metadata: member.metadata,
        statusMessage: member.statusMessage,
        scope: event.newScope,
        joinedAt: member.joinedAt,
      );

      // Update member in list using ListBase mixin (triggers onItemUpdated hook)
      updateItem(memberIndex, updatedMember);
    }
  }

  void _onUserStatusUpdate(
    _UserStatusUpdate event,
    Emitter<GroupMembersState> emit,
  ) {
    // Check if state is GroupMembersLoaded - if not, return early
    if (state is! GroupMembersLoaded) return;

    // Check if the user is a member of this group using O(1) lookup
    final member = findMember(event.userId);

    // If member not found, return early (user is not in this group)
    if (member == null) return;

    // The ValueNotifier is already updated by the callback (_handleUserOnline/_handleUserOffline)
    // before this event is dispatched, so no additional action needed for isolated rebuilds.
    //
    // Note: We intentionally don't update the member's status field in the list here
    // because the ValueNotifier pattern provides isolated rebuilds without requiring
    // a full list state change. The UI uses ValueListenableBuilder with getStatusNotifier()
    // to react to status changes efficiently.
  }

  void _onConnectionStateUpdate(
    _ConnectionStateUpdate event,
    Emitter<GroupMembersState> emit,
  ) {
    if (event.isConnected && state is GroupMembersLoaded) {
      add(const RefreshGroupMembers());
    }
  }

  void _onListStateChanged(
    _ListStateChanged event,
    Emitter<GroupMembersState> emit,
  ) {
    if (event.isEmpty) {
      emit(const GroupMembersEmpty());
    } else {
      final currentState = state;
      if (currentState is GroupMembersLoaded) {
        emit(
          currentState.copyWith(
            members: event.members,
            hasMore: event.hasMore ?? currentState.hasMore,
            // Always reset isLoadingMore when list state changes from a hook
            isLoadingMore: false,
          ),
        );
      } else {
        emit(
          GroupMembersLoaded(
            members: event.members,
            hasMore: event.hasMore ?? true,
          ),
        );
      }
    }
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  Future<void> close() {
    // Cancel search debounce timer
    _searchDebounceTimer?.cancel();

    // Remove SDK listeners
    CometChat.removeGroupListener(_groupListenerKey);
    CometChat.removeUserListener(_userListenerKey);
    CometChat.removeConnectionListener(_connectionListenerKey);

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

/// Internal event when a member joins the group
class _MemberJoined extends GroupMembersEvent {
  final GroupMember member;

  const _MemberJoined({required this.member});

  @override
  List<Object> get props => [member];
}

/// Internal event when a member leaves the group
class _MemberLeft extends GroupMembersEvent {
  final String uid;

  const _MemberLeft({required this.uid});

  @override
  List<Object> get props => [uid];
}

/// Internal event when a member is kicked from the group
class _MemberKicked extends GroupMembersEvent {
  final String uid;

  const _MemberKicked({required this.uid});

  @override
  List<Object> get props => [uid];
}

/// Internal event when a member is banned from the group
class _MemberBanned extends GroupMembersEvent {
  final String uid;

  const _MemberBanned({required this.uid});

  @override
  List<Object> get props => [uid];
}

/// Internal event when a member's scope changes
class _MemberScopeChanged extends GroupMembersEvent {
  final String uid;
  final String newScope;

  const _MemberScopeChanged({required this.uid, required this.newScope});

  @override
  List<Object> get props => [uid, newScope];
}

/// Internal event for user status updates (online/offline)
class _UserStatusUpdate extends GroupMembersEvent {
  final String userId;
  final String status;

  const _UserStatusUpdate({required this.userId, required this.status});

  @override
  List<Object> get props => [userId, status];
}

/// Internal event for connection state changes
class _ConnectionStateUpdate extends GroupMembersEvent {
  final bool isConnected;

  const _ConnectionStateUpdate({required this.isConnected});

  @override
  List<Object> get props => [isConnected];
}

/// Internal event for list state changes (from ListBase hooks)
class _ListStateChanged extends GroupMembersEvent {
  final List<GroupMember> members;
  final bool isEmpty;
  final bool? hasMore;

  const _ListStateChanged({
    required this.members,
    required this.isEmpty,
    this.hasMore,
  });

  @override
  List<Object?> get props => [members, isEmpty, hasMore];
}

/// Internal event to execute search after debounce
class _ExecuteSearch extends GroupMembersEvent {
  final String keyword;

  const _ExecuteSearch(this.keyword);

  @override
  List<Object> get props => [keyword];
}

/// Internal event to restore original members after search is cleared
class _RestoreOriginalMembers extends GroupMembersEvent {
  final List<GroupMember> members;

  const _RestoreOriginalMembers(this.members);

  @override
  List<Object> get props => [members];
}

/// Internal event to reload the first page silently after a cleared search
class _ReloadFirstPage extends GroupMembersEvent {
  const _ReloadFirstPage();
}

// ============================================================
// SDK LISTENER CLASSES
// ============================================================

/// Group listener for real-time group member events
class _GroupMembersGroupListener with GroupListener {
  final void Function(Action, User, Group) onGroupMemberJoinedCallback;
  final void Function(Action, User, Group) onGroupMemberLeftCallback;
  final void Function(Action, User, User, Group) onGroupMemberKickedCallback;
  final void Function(Action, User, User, Group) onGroupMemberBannedCallback;
  final void Function(Action, User, User, String, String, Group)
  onGroupMemberScopeChangedCallback;
  final void Function(Action, User, Group) onMemberAddedToGroupCallback;

  _GroupMembersGroupListener({
    required this.onGroupMemberJoinedCallback,
    required this.onGroupMemberLeftCallback,
    required this.onGroupMemberKickedCallback,
    required this.onGroupMemberBannedCallback,
    required this.onGroupMemberScopeChangedCallback,
    required this.onMemberAddedToGroupCallback,
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
    // Treat member added same as member joined
    onMemberAddedToGroupCallback(action, userAdded, addedTo);
  }
}

/// User listener for online/offline status updates
class _GroupMembersUserListener with UserListener {
  final void Function(User user) onUserOnlineCallback;
  final void Function(User user) onUserOfflineCallback;

  _GroupMembersUserListener({
    required this.onUserOnlineCallback,
    required this.onUserOfflineCallback,
  });

  @override
  void onUserOnline(User user) => onUserOnlineCallback(user);

  @override
  void onUserOffline(User user) => onUserOfflineCallback(user);
}

/// Connection listener for reconnection handling
class _GroupMembersConnectionListener with ConnectionListener {
  final void Function() onConnectedCallback;
  final void Function() onDisconnectedCallback;

  _GroupMembersConnectionListener({
    required this.onConnectedCallback,
    required this.onDisconnectedCallback,
  });

  @override
  void onConnected() => onConnectedCallback();

  @override
  void onDisconnected() => onDisconnectedCallback();
}
