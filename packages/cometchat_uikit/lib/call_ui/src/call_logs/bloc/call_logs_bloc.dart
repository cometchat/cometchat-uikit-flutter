import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared_ui/src/clean_architecture/core/result.dart';
import '../../../../shared_ui/src/clean_architecture/core/constants/ui_kit_constants.dart';
import '../../../../chat_ui/src/shared/list_base.dart';
import '../../call_event_service.dart';
import '../../outgoing_call/cometchat_outgoing_call_configuration.dart';
import '../../call_settings/call_navigation_context.dart';
import '../di/call_logs_service_locator.dart';
import '../data/repositories/call_logs_repository_impl.dart';
import '../domain/usecases/get_call_logs_usecase.dart';
import '../domain/usecases/get_logged_in_user_usecase.dart';
import '../domain/usecases/initiate_call_usecase.dart';
import '../domain/usecases/load_more_call_logs_usecase.dart';
import 'call_logs_event.dart';
import 'call_logs_state.dart';
import '../../../../shared_ui/src/logging/cometchat_log.dart';
import '../../../../src/active_call_tracker.dart';
import '../../../../src/call_errors.dart';
import '../../../../src/call_permission_check.dart';
import '../../../../src/call_user_lookup.dart';
import '../../../../src/calling_configuration_resolver.dart';
import '../../../../src/calls_lifecycle.dart';
import '../../../../src/chat_sdk_listeners.dart';
import '../../../../src/outgoing_call_launcher.dart';
import '../../../../shared_ui/src/events/call_events/cometchat_call_event_listener.dart';
import '../../../../shared_ui/src/events/call_events/cometchat_call_events.dart';
import '../../utils/call_state_service.dart';

/// BLoC for managing call logs list
///
/// This BLoC manages the call logs list state and handles:
/// - Loading and pagination of call logs
/// - Grouping call logs by date for display
/// - Initiating calls from call log entries
/// - O(1) lookups via session ID map
/// - Keeping the list current: a call event of the chat SDK or of the UI
///   Kit, a reconnect, or a call screen closing refreshes the first page
///   1.5 s after the last of them, without the loading state, merging it in
///   by session id (new rows on top, changed rows in place, older pages and
///   the scroll position kept). It needs the UI Kit's own repository,
///   [CallLogsRepositoryImpl]; a repository of your own is left alone.
///
/// This BLoC uses the [ListBase] mixin for list management operations.
/// Developers can extend this class and override the hook methods
/// (onItemAdded, onItemRemoved, onItemUpdated, onListCleared, onListReplaced)
/// to add custom logic like sorting, filtering, or validation.
class CallLogsBloc extends Bloc<CallLogsEvent, CallLogsState>
    with ListBase<CallLog> {
  // Use cases - initialized from service locator if not provided
  final GetCallLogsUseCase getCallLogsUseCase;
  final LoadMoreCallLogsUseCase loadMoreCallLogsUseCase;
  final InitiateCallUseCase initiateCallUseCase;
  final GetLoggedInUserUseCase getLoggedInUserUseCase;

  /// Optional custom request builder provided by the widget.
  /// When set, this builder is used instead of the default one, exactly as
  /// given, allowing callers to configure filters (uid, guid, callCategory,
  /// etc.). The default lists 1:1 calls only (callCategory "call", 30 per
  /// page); a builder with no callCategory lists meetings too.
  final CallLogRequestBuilder? callLogsRequestBuilder;

  /// Configuration for the outgoing call screen this bloc pushes when a call
  /// is initiated from a log row, from
  /// CometChatCallLogs.outgoingCallConfiguration. When none is given, the
  /// app's `CallingConfiguration` is used, as the message header's call
  /// buttons use it: its `callButtonsConfiguration.outgoingCallConfiguration`,
  /// else its `outgoingCallConfiguration`.
  final CometChatOutgoingCallConfiguration? _outgoingCallConfiguration;

  /// Called when a call started from a log row is refused or fails:
  ///
  /// * `ACTIVE_CALL`: another call is in progress on this device, or is
  ///   being placed from another call component (one at a time);
  /// * `NO_NAVIGATOR`: `CallNavigationContext.navigatorKey` has no navigator
  ///   to show the call on, as for the call buttons (checked before the call
  ///   is placed and again before it goes out; one placed meanwhile is
  ///   cancelled);
  /// * `PERMISSION_DENIED` / `PERMISSION_PERMANENTLY_DENIED`: microphone
  ///   (or, for video, camera) access was refused; `details` lists the
  ///   missing permissions;
  /// * `BLOCKED_BY_ME` / `HAS_BLOCKED_ME`: the logged-in user has blocked
  ///   the callee, or the callee has blocked them;
  /// * the SDK's own exception, code kept, when fetching the callee, placing
  ///   the call (or cancelling one that could not be shown) fails;
  /// * a platform error, its code kept, when asking for permissions fails
  ///   (a request already running, say).
  ///
  /// A second tap while a call is being placed is dropped without a word.
  /// `CometChatCallLogs` passes its `onError`.
  ///
  /// When this is null and the bloc is handed to a `CometChatCallLogs`
  /// (`callLogsBloc:`), that widget's `onError` gets these instead.
  final OnError? errorCallback;

  // Pagination state tracking
  bool _isLoadingMore = false;

  // Logged in user
  User? _loggedInUser;

  /// Cached auth token — no longer needed in V5, SDK handles auth internally
  // ============================================================
  // OPTIMIZATION: Map-based O(1) call log lookups by session ID
  // ============================================================
  final Map<String, int> _callLogIndexMap = {};

  /// Flag to track if map needs full rebuild (only on initial load/refresh)
  bool _mapNeedsRebuild = true;

  // ============================================================
  // Keeping the list current (round 5, P5-C14)
  // ============================================================

  /// How long the list waits after the last trigger before it refreshes:
  /// a burst of call events refreshes once, and the server has written the
  /// log by then.
  static const Duration _refreshDebounce = Duration(milliseconds: 1500);

  static int _instances = 0;

  /// This bloc's listener id, the same for each kind of listener.
  final String _listenerId = 'call_logs_bloc_${++_instances}';

  late final _CallLogsSdkCallListener _sdkCallListener =
      _CallLogsSdkCallListener(_scheduleRefresh);
  late final _CallLogsConnectionListener _connectionListener =
      _CallLogsConnectionListener(_scheduleRefresh);
  late final _CallLogsUiCallListener _uiCallListener = _CallLogsUiCallListener(
    _scheduleRefresh,
  );

  /// Whether a call screen was up at the last change of
  /// [CallStateService.isActiveCall].
  bool _wasActiveCall = CallStateService.instance.isActiveCall.value;

  Timer? _refreshTimer;

  /// Set while a silent refresh fetches.
  bool _refreshing = false;

  /// Bumped by every load from scratch: a refresh that started before one
  /// drops its result.
  int _loadGeneration = 0;

  /// Helper to get initialized service locator
  static CallLogsServiceLocator _getServiceLocator() {
    if (!CallLogsServiceLocator.instance.isInitialized) {
      CallLogsServiceLocator.instance.setup();
    }
    return CallLogsServiceLocator.instance;
  }

  /// Creates a CallLogsBloc.
  ///
  /// All use cases are optional - if not provided, they will be automatically
  /// initialized from the default service locator. This makes it easy to extend
  /// the bloc without worrying about dependency injection.
  ///
  /// [callLogsRequestBuilder] - Optional custom request builder for filtering.
  /// [outgoingCallConfiguration] - Configuration for the outgoing call screen
  /// pushed when a call is started from a log row.
  /// [errorCallback] - Told when a call started from a log row fails.
  CallLogsBloc({
    GetCallLogsUseCase? getCallLogsUseCase,
    LoadMoreCallLogsUseCase? loadMoreCallLogsUseCase,
    InitiateCallUseCase? initiateCallUseCase,
    GetLoggedInUserUseCase? getLoggedInUserUseCase,
    this.callLogsRequestBuilder,
    CometChatOutgoingCallConfiguration? outgoingCallConfiguration,
    this.errorCallback,
  }) : _outgoingCallConfiguration = outgoingCallConfiguration,
       getCallLogsUseCase =
           getCallLogsUseCase ?? _getServiceLocator().getCallLogsUseCase,
       loadMoreCallLogsUseCase =
           loadMoreCallLogsUseCase ??
           _getServiceLocator().loadMoreCallLogsUseCase,
       initiateCallUseCase =
           initiateCallUseCase ?? _getServiceLocator().initiateCallUseCase,
       getLoggedInUserUseCase =
           getLoggedInUserUseCase ??
           _getServiceLocator().getLoggedInUserUseCase,
       super(CallLogsState.initial()) {
    // Register event handlers
    on<LoadCallLogs>(_onLoadCallLogs);
    on<LoadMoreCallLogs>(_onLoadMoreCallLogs);
    on<RefreshCallLogs>(_onRefreshCallLogs);
    on<InitiateCallFromLog>(_onInitiateCallFromLog);
    on<_SilentRefreshCallLogs>(_onSilentRefresh);

    // Initialize logged in user
    _initializeLoggedInUser();
    _listenForChanges();
  }

  /// Registers what keeps the list current: Android's triggers (the chat
  /// SDK's call events, a reconnect) and more: the UI Kit's own call events,
  /// which also tell of a call this device placed or declined that the SDK
  /// does not echo here, and a call screen closing. Private delegates, so
  /// the bloc's public API does not grow listener methods.
  void _listenForChanges() {
    ChatSdkListeners.addCallListener(_listenerId, _sdkCallListener);
    ChatSdkListeners.addConnectionListener(_listenerId, _connectionListener);
    CometChatCallEvents.addCallEventsListener(_listenerId, _uiCallListener);
    CallStateService.instance.isActiveCall.addListener(_onActiveCallChanged);
  }

  /// A call or meeting screen closed: its log is new or has changed.
  void _onActiveCallChanged() {
    final active = CallStateService.instance.isActiveCall.value;
    if (_wasActiveCall && !active) _scheduleRefresh();
    _wasActiveCall = active;
  }

  /// Refreshes the list [_refreshDebounce] after the last trigger. Nothing
  /// to do before the first load, nor over a repository of the host's own.
  void _scheduleRefresh() {
    if (isClosed || state.status == CallLogsStatus.initial) return;
    if (getCallLogsUseCase.repository is! CallLogsRepositoryImpl) return;
    _refreshTimer?.cancel();
    _refreshTimer = Timer(_refreshDebounce, _refreshDue);
  }

  void _refreshDue() {
    _refreshTimer = null;
    if (isClosed) return;
    // A load, a page or a refresh on the way: once it is done.
    if (state.status == CallLogsStatus.loading ||
        _isLoadingMore ||
        _refreshing) {
      _scheduleRefresh();
      return;
    }
    add(const _SilentRefreshCallLogs());
  }

  /// Initialize logged in user
  Future<void> _initializeLoggedInUser() async {
    final result = await getLoggedInUserUseCase();

    if (result is Success<User?>) {
      _loggedInUser = result.data;
    }
  }

  /// Auth token handling removed in V5 — SDK handles auth internally.
  /// Keeping _ensureCallsSdkInitialized for SDK init gating.

  /// Ensure the CometChat Calls SDK is initialized.
  ///
  /// Delegates to [CallEventService.waitForCallsSdk] which is the single
  /// source of truth for Calls SDK initialization. This avoids duplicate
  /// init calls that cause race conditions and 408 errors.
  Future<void> _ensureCallsSdkInitialized() async {
    await CallEventService.instance.waitForCallsSdk();
  }

  /// Build a CallLogRequest and configure the repository this bloc fetches
  /// through ([getCallLogsUseCase]'s). It used to configure the service
  /// locator's, which a bloc given use cases of its own does not fetch from.
  /// In V5, the SDK handles auth internally — no authToken needed.
  Future<void> _configureRequest({int limit = 30}) async {
    final repo = getCallLogsUseCase.repository;
    if (repo is CallLogsRepositoryImpl) {
      repo.setRequest(_buildRequest(limit: limit));
    }
  }

  /// A fresh request: the host's builder exactly as given, or the default,
  /// [limit] per page and 1:1 calls only (category "call"), as Android's
  /// CometChatCallLogsViewModel. Meetings are left out by default: their
  /// rows had no working call-back (P5-D12).
  CallLogRequest _buildRequest({int limit = 30}) {
    final hostBuilder = callLogsRequestBuilder;
    if (hostBuilder != null) return hostBuilder.build();
    return (CallLogRequestBuilder()
          ..limit = limit
          ..callCategory = CometChatCallsConstants.callCategoryCall)
        .build();
  }

  // ============================================================
  // OPTIMIZATION: Map-based lookup helpers with incremental updates
  // ============================================================

  /// Full rebuild - only called on initial load or refresh
  void _rebuildIndexMap() {
    _callLogIndexMap.clear();
    for (int i = 0; i < items.length; i++) {
      final sessionId = items[i].sessionId;
      if (sessionId != null && sessionId.isNotEmpty) {
        _callLogIndexMap[sessionId] = i;
      }
    }
    _mapNeedsRebuild = false;
  }

  /// Incremental: Add single item to map at index
  void _addToIndexMap(String? sessionId, int index) {
    if (sessionId != null && sessionId.isNotEmpty) {
      _callLogIndexMap[sessionId] = index;
    }
  }

  /// Incremental: Remove single item from map
  void _removeFromIndexMap(String? sessionId) {
    if (sessionId != null && sessionId.isNotEmpty) {
      _callLogIndexMap.remove(sessionId);
    }
  }

  /// Incremental: Shift indices after removal (items after removedIndex move up)
  void _shiftIndicesAfterRemoval(int removedIndex) {
    _callLogIndexMap.updateAll((key, index) {
      return index > removedIndex ? index - 1 : index;
    });
  }

  /// O(1) call log index lookup by session ID
  int? findCallLogIndex(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) return null;
    // Lazy rebuild if needed
    if (_mapNeedsRebuild && items.isNotEmpty) {
      _rebuildIndexMap();
    }
    return _callLogIndexMap[sessionId];
  }

  /// O(1) call log lookup by session ID
  CallLog? findCallLog(String? sessionId) {
    final index = findCallLogIndex(sessionId);
    return index != null && index < items.length ? items[index] : null;
  }

  // ============================================================
  // EVENT HANDLERS
  // ============================================================

  /// Maximum number of retry attempts when SDK fetch fails due to
  /// initialization race condition (408 / generateToken errors).
  static const int _maxRetries = 3;

  /// Delay between retries.
  static const Duration _retryDelay = Duration(seconds: 1);

  /// Load initial call logs.
  /// Ensures the Calls SDK is initialized and configures the repository
  /// with auth token before fetching.
  ///
  /// If the first fetch fails (typically because the Calls SDK hasn't
  /// finished internal initialization), retries up to [_maxRetries] times.
  Future<void> _onLoadCallLogs(
    LoadCallLogs event,
    Emitter<CallLogsState> emit,
  ) async {
    emit(
      state.copyWith(status: CallLogsStatus.loading, clearLoadMoreError: true),
    );

    _loadGeneration++;
    _isLoadingMore = false;
    _mapNeedsRebuild = true;

    // Ensure logged in user is available
    if (_loggedInUser == null) {
      final userResult = await getLoggedInUserUseCase();
      if (userResult is Success<User?>) {
        _loggedInUser = userResult.data;
      }
    }

    // Wait for the Calls SDK to be ready (initialized by CallEventService)
    await _ensureCallsSdkInitialized();

    // Configure the repository with auth token and optional custom builder
    await _configureRequest(limit: 30);

    Result<List<CallLog>> result = await getCallLogsUseCase(limit: 30);

    // Retry logic: if the SDK fetch failed, wait and retry with a fresh request.
    for (
      int attempt = 1;
      attempt <= _maxRetries && result is Failure;
      attempt++
    ) {
      ccLog(
        'CallLogsBloc: fetch failed, retrying in '
        '${_retryDelay.inSeconds}s (attempt $attempt/$_maxRetries)',
      );

      await Future.delayed(_retryDelay);

      // Reset the request on the repository so fetchNext gets a fresh
      // CallLogRequest with a new generateToken cycle
      _resetRepositoryRequest();
      await _configureRequest(limit: 30);

      result = await getCallLogsUseCase(limit: 30);

      ccLog(
        'CallLogsBloc: retry attempt $attempt result: ${result is Success ? "SUCCESS" : "FAILED"}',
      );
    }

    if (result is Success<List<CallLog>>) {
      final callLogs = result.data;
      if (callLogs.isEmpty) {
        emit(
          state.copyWith(
            status: CallLogsStatus.empty,
            loggedInUser: _loggedInUser,
          ),
        );
      } else {
        // Group call logs by date
        final groupedEntries = _groupCallLogsByDate(callLogs);

        replaceAll(callLogs);

        emit(
          state.copyWith(
            status: CallLogsStatus.loaded,
            callLogs: callLogs,
            // More pages until one comes back empty, as on Android: a page
            // shorter than 30 is not the last when the host asked for fewer.
            hasMore: callLogs.isNotEmpty,
            loggedInUser: _loggedInUser,
            groupedEntries: groupedEntries,
          ),
        );
      }
    } else if (result is Failure) {
      emit(
        state.copyWith(
          status: CallLogsStatus.error,
          errorMessage: result.message,
          loggedInUser: _loggedInUser,
        ),
      );
    }
  }

  /// Resets the repository's current request so the next [_configureRequest]
  /// builds a fresh [CallLogRequest]. This is needed for retries because
  /// the SDK's fetchNext uses internal state from the previous request.
  void _resetRepositoryRequest() {
    final repo = getCallLogsUseCase.repository;
    if (repo is CallLogsRepositoryImpl) {
      repo.resetRequest();
    }
  }

  /// Load more call logs (pagination)
  Future<void> _onLoadMoreCallLogs(
    LoadMoreCallLogs event,
    Emitter<CallLogsState> emit,
  ) async {
    if (state.status != CallLogsStatus.loaded) return;

    if (!state.hasMore || state.isLoadingMore || _isLoadingMore) {
      return;
    }

    _isLoadingMore = true;
    emit(state.copyWith(isLoadingMore: true, clearLoadMoreError: true));

    // The page as the server sent it: whether there is more comes from the
    // page itself (empty at the end), not from what is left once the rows
    // already listed are dropped, which can be nothing mid-list.
    final result = await loadMoreCallLogsUseCase(limit: 30);

    _isLoadingMore = false;

    if (result is Success<List<CallLog>>) {
      final page = result.data;

      if (page.isEmpty) {
        emit(state.copyWith(hasMore: false, isLoadingMore: false));
        return;
      }

      // Rows already listed (moved down a page by newer calls) once only.
      final listed = {for (final log in state.callLogs) log.sessionId};
      final newCallLogs = page
          .where((log) => !listed.contains(log.sessionId))
          .toList();
      final allCallLogs = [...state.callLogs, ...newCallLogs];

      // Re-group all call logs by date
      final groupedEntries = _groupCallLogsByDate(allCallLogs);

      replaceAll(allCallLogs);

      emit(
        state.copyWith(
          callLogs: allCallLogs,
          hasMore: true,
          isLoadingMore: false,
          groupedEntries: groupedEntries,
        ),
      );
    } else if (result is Failure) {
      // The list stays as it is, with a retry row that asks for the same
      // page again (the repository keeps its place); CometChatCallLogs tells
      // its onError. It used to replace the whole list with the error view.
      emit(state.copyWith(isLoadingMore: false, loadMoreError: result.message));
    }
  }

  /// Refreshes the first page without the loading state (round 5, P5-C14).
  ///
  /// With rows listed, the first page is fetched through a request of its
  /// own, so the one load-more pages with keeps its place, and merged in by
  /// session id: new rows on top, changed rows in place, the older pages
  /// (and so the scroll position) kept. Android replaces the list and
  /// scrolls to the top instead. With nothing listed (empty, or the first
  /// load failed), the first page is loaded the usual way, quietly.
  ///
  /// It waits for the Calls SDK first, as a call screen that just closed may
  /// leave it re-initialising, and tries once more on a failure. A failure
  /// after that keeps the list as it is; it is logged, not reported. A load
  /// from scratch that starts meanwhile wins: this one's result is dropped.
  Future<void> _onSilentRefresh(
    _SilentRefreshCallLogs event,
    Emitter<CallLogsState> emit,
  ) async {
    final repository = getCallLogsUseCase.repository;
    if (repository is! CallLogsRepositoryImpl) return;
    final status = state.status;
    if (status == CallLogsStatus.initial || status == CallLogsStatus.loading) {
      return;
    }
    final generation = _loadGeneration;
    _refreshing = true;
    try {
      if (status == CallLogsStatus.loaded) {
        final page = await _fetchFirstPage(
          () => repository.remoteDataSource.getCallLogs(_buildRequest()),
        );
        if (page == null || isClosed || generation != _loadGeneration) return;
        _mergeFirstPage(page, emit);
      } else {
        final page = await _fetchFirstPage(() async {
          _resetRepositoryRequest();
          await _configureRequest(limit: 30);
          final result = await getCallLogsUseCase(limit: 30);
          if (result is Failure) throw Exception(result.message);
          return (result as Success<List<CallLog>>).data;
        });
        if (page == null || isClosed || generation != _loadGeneration) return;
        replaceAll(page);
        emit(
          state.copyWith(
            status: page.isEmpty ? CallLogsStatus.empty : CallLogsStatus.loaded,
            callLogs: page,
            hasMore: page.isNotEmpty,
            loggedInUser: _loggedInUser,
            groupedEntries: _groupCallLogsByDate(page),
          ),
        );
      }
    } finally {
      _refreshing = false;
    }
  }

  /// Runs [fetch] once the Calls SDK is ready, and once more after
  /// [_retryDelay] if it fails; null when both fail or the bloc closed.
  Future<List<CallLog>?> _fetchFirstPage(
    Future<List<CallLog>> Function() fetch,
  ) async {
    for (var attempt = 1; attempt <= 2; attempt++) {
      if (attempt > 1) await Future<void>.delayed(_retryDelay);
      await _ensureCallsSdkInitialized();
      if (isClosed) return null;
      try {
        return await fetch();
      } catch (e) {
        ccLog('CallLogsBloc: silent refresh, attempt $attempt failed: $e');
      }
    }
    return null;
  }

  /// Merges a fresh first page into the list by session id: rows not
  /// listed yet go on top, in the server's order, listed ones are replaced
  /// where they are, and everything else stays.
  void _mergeFirstPage(List<CallLog> page, Emitter<CallLogsState> emit) {
    final fresh = <String, CallLog>{
      for (final log in page)
        if (log.sessionId?.isNotEmpty ?? false) log.sessionId!: log,
    };
    final listed = {for (final log in state.callLogs) log.sessionId};
    final merged = <CallLog>[
      ...fresh.values.where((log) => !listed.contains(log.sessionId)),
      for (final log in state.callLogs) fresh[log.sessionId] ?? log,
    ];
    replaceAll(merged);
    emit(
      state.copyWith(
        status: CallLogsStatus.loaded,
        callLogs: merged,
        loggedInUser: _loggedInUser,
        groupedEntries: _groupCallLogsByDate(merged),
      ),
    );
  }

  /// Refresh call logs list
  Future<void> _onRefreshCallLogs(
    RefreshCallLogs event,
    Emitter<CallLogsState> emit,
  ) async {
    // Reset repository request so it's re-built on next load
    _resetRepositoryRequest();
    add(const LoadCallLogs());
  }

  /// Set while a call from a log row is being placed, from the tap until
  /// its screen is up or it has failed.
  bool _placingCall = false;

  /// Calls back the other party of a log row, with the checks the chat
  /// header's call buttons make, in order: one call at a time (a second tap
  /// while one is being placed is dropped), not while another call is in
  /// progress (ACTIVE_CALL), only with somewhere to show it (NO_NAVIGATOR),
  /// only with the microphone (and, for video, the camera) granted
  /// (PERMISSION_DENIED / PERMISSION_PERMANENTLY_DENIED). A user is then
  /// fetched, for the outgoing screen's real name and avatar and to refuse
  /// a call either side has blocked (BLOCKED_BY_ME / HAS_BLOCKED_ME); a
  /// failed fetch reports the SDK's code. Every refusal and failure reaches
  /// onError; the list stays as it is. Android's sample app calls back the
  /// same way (CallsFragment, CallsFragmentViewModel), and the owner kept
  /// this default with its checks (P5-D15).
  Future<void> _onInitiateCallFromLog(
    InitiateCallFromLog event,
    Emitter<CallLogsState> emit,
  ) async {
    // The handler runs concurrently: a second tap placed a second call.
    if (_placingCall) return;
    // Another call component (the chat header's call buttons, say) is
    // placing a call right now: one at a time across the app.
    if (!ActiveCallTracker.beginPlacingCall(this)) {
      _reportError(activeCallException());
      return;
    }
    _placingCall = true;
    try {
      await _callBack(event.callLog, emit);
    } catch (e, stackTrace) {
      ccLog('CallLogs: calling back failed: $e\n$stackTrace');
      _reportError(callExceptionFrom(e));
    } finally {
      _placingCall = false;
      ActiveCallTracker.endPlacingCall(this);
    }
  }

  Future<void> _callBack(CallLog callLog, Emitter<CallLogsState> emit) async {
    // Determine receiver ID and type from call log
    final String receiverId;
    final String receiverType;
    final String callType;

    // Get the receiver - if logged in user initiated the call, receiver is the other party
    // Otherwise, receiver is the initiator
    // CallLog.initiator and CallLog.receiver are CallEntity types
    // Need to cast to CallUser or CallGroup to access uid/guid
    if (_isLoggedInUserInitiator(callLog)) {
      // User initiated the original call, so call the receiver
      if (callLog.receiver is CallUser) {
        receiverId = (callLog.receiver as CallUser).uid ?? '';
        receiverType = CometChatReceiverType.user;
      } else if (callLog.receiver is CallGroup) {
        receiverId = (callLog.receiver as CallGroup).guid ?? '';
        receiverType = CometChatReceiverType.group;
      } else {
        return; // Unknown receiver type
      }
    } else {
      // User received the original call, so call the initiator
      if (callLog.initiator is CallUser) {
        receiverId = (callLog.initiator as CallUser).uid ?? '';
        receiverType = CometChatReceiverType.user;
      } else if (callLog.initiator is CallGroup) {
        receiverId = (callLog.initiator as CallGroup).guid ?? '';
        receiverType = CometChatReceiverType.group;
      } else {
        return; // Unknown initiator type
      }
    }

    // Determine call type from the original call
    callType = callLog.type ?? CometChatCallType.audio;

    if (receiverId.isEmpty) {
      return;
    }

    // Already on a call, or a meeting is on screen (round 5, D06 A): as the
    // call buttons, and Android's sample.
    if (ActiveCallTracker.isInCallOrMeeting) {
      _reportError(activeCallException());
      return;
    }

    // Nowhere to show the outgoing call screen: refuse before placing the
    // call. One placed with no screen for it left the callee ringing with
    // nobody to cancel.
    if (!_canShowOutgoingCall) {
      _reportError(noNavigatorException('outgoing call screen'));
      return;
    }

    // The call-back used to place the call without asking, and a refused
    // microphone then failed only once the callee had answered.
    final isVideo = callType == CometChatCallType.video;
    final permissions = await CallPermissionCheck.request(isVideoCall: isVideo);
    if (!permissions.isGranted) {
      _reportError(
        permissions.toException(
          'Microphone${isVideo ? ' and camera' : ''} permission is required '
          'to start the call.',
        ),
      );
      return;
    }

    // The callee as the server has them now: the title shows their name and
    // avatar, not their UID, and a call either side has blocked is refused
    // here rather than left to the server.
    User? callee;
    if (receiverType == CometChatReceiverType.user) {
      try {
        callee = await CallUserLookup.fetchUser(receiverId);
      } catch (e) {
        ccLog('CallLogs: fetching $receiverId failed: $e');
        _reportError(callExceptionFrom(e));
        return;
      }
      if (callee.blockedByMe == true) {
        _reportError(
          CometChatException(
            CallErrorCodes.blockedByMe,
            'Call cannot be initiated as user is blocked',
            'You have blocked this user.',
          ),
        );
        return;
      }
      if (callee.hasBlockedMe == true) {
        _reportError(
          CometChatException(
            CallErrorCodes.hasBlockedMe,
            'Call cannot be initiated as user has blocked you',
            'This user has blocked you.',
          ),
        );
        return;
      }
    }

    // Again: the navigator can go while the prompt or the fetch is on.
    if (!_canShowOutgoingCall) {
      _reportError(noNavigatorException('outgoing call screen'));
      return;
    }

    // A logout is ending this device's calls and has picked the ones it
    // cancels: a call placed now would be closed with nothing sent.
    if (CallsLifecycle.isPreparingLogout) {
      ccLog('CallLogs: logging out; the call was not placed');
      return;
    }

    // Create call object
    final call = Call(
      receiverUid: receiverId,
      receiverType: receiverType,
      type: callType,
    );

    // Tracked, so a logout that starts meanwhile waits for it, and the call
    // is cancelled while the user can still be heard.
    final epoch = CallsLifecycle.callEpoch;
    final uid = CallsLifecycle.uid;
    final result = await ActiveCallTracker.trackCallRequest(() async {
      final placed = await initiateCallUseCase(call);
      if (epoch != CallsLifecycle.callEpoch && placed is Success<Call>) {
        await CallsLifecycle.cancelPlacedDuringTeardown(
          placed.data,
          placedBy: uid,
        );
      }
      return placed;
    });

    if (epoch != CallsLifecycle.callEpoch) {
      // Calls were torn down meanwhile: no screen, nothing to report.
      return;
    }

    if (result is Success<Call>) {
      // The call is already placed, so its screen must appear even if the
      // call-log screen that asked for it has gone meanwhile.
      await OutgoingCallLauncher.show(
        result.data,
        epoch: epoch,
        user: callee,
        configuration: _outgoingConfiguration,
        onError: errorCallback ?? callLogsWidgetOnError[this],
      );
    } else if (result is Failure) {
      // Error handling - could emit error state or show snackbar
      emit(state.copyWith(errorMessage: result.message));
      _reportError(callFailureException(result));
    }
  }

  /// Whether the outgoing call screen can be shown: on the app's navigator,
  /// `CallNavigationContext.navigatorKey`, as for the call buttons.
  ///
  /// The call-log screen's own navigator used to do when that key was not
  /// set, but the call screen that follows an accept needs the key's
  /// overlay: such a call rang, and once the callee answered the caller got
  /// NO_NAVIGATOR instead of the call (round 2 review).
  static bool get _canShowOutgoingCall {
    final appContext = CallNavigationContext.navigatorKey.currentContext;
    return appContext != null && appContext.mounted;
  }

  /// Hands [error] to [errorCallback], if the host gave one; a throwing
  /// callback is only logged.
  void _reportError(CometChatException error) => reportCallError(
    errorCallback ?? callLogsWidgetOnError[this],
    error,
    where: 'CallLogs',
  );

  /// Check if logged in user is the initiator of the call
  bool _isLoggedInUserInitiator(CallLog callLog) {
    if (_loggedInUser == null) return false;

    if (callLog.initiator is CallUser) {
      return (callLog.initiator as CallUser).uid == _loggedInUser!.uid;
    }
    return false;
  }

  /// The configuration of the outgoing call screen a call from a log row
  /// opens: this bloc's own, else the app's `CallingConfiguration`, as the
  /// message header's call buttons read it.
  CometChatOutgoingCallConfiguration? get _outgoingConfiguration {
    final calling = CallingConfigurationResolver.resolved;
    return _outgoingCallConfiguration ??
        calling?.callButtonsConfiguration?.outgoingCallConfiguration ??
        calling?.outgoingCallConfiguration;
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Group call logs by date for display
  Map<String, List<CallLog>> _groupCallLogsByDate(List<CallLog> callLogs) {
    final Map<String, List<CallLog>> grouped = {};

    for (final callLog in callLogs) {
      final initiatedAt = callLog.initiatedAt;
      if (initiatedAt == null) continue;

      // Convert timestamp to date string
      final date = DateTime.fromMillisecondsSinceEpoch(initiatedAt * 1000);
      final dateKey = _getDateKey(date);

      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(callLog);
    }

    return grouped;
  }

  /// Get date key for grouping (Today, Yesterday, or date string)
  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final callDate = DateTime(date.year, date.month, date.day);

    if (callDate == today) {
      return 'Today';
    } else if (callDate == yesterday) {
      return 'Yesterday';
    } else {
      // Format as "MMM dd, yyyy"
      return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
    }
  }

  /// Get month name abbreviation
  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  // ============================================================
  // LISTBASE HOOK OVERRIDES (incremental map updates only)
  // State emission is handled by event handlers, not hooks
  // ============================================================

  /// Called when a call log is added to the list.
  /// Only updates the index map - state emission is in event handlers.
  @override
  void onItemAdded(CallLog item, List<CallLog> updatedList) {
    // OPTIMIZATION: Incremental map update - item added at end
    final newIndex = updatedList.length - 1;
    _addToIndexMap(item.sessionId, newIndex);
  }

  /// Called when a call log is removed from the list.
  /// Only updates the index map - state emission is in event handlers.
  @override
  void onItemRemoved(CallLog item, List<CallLog> updatedList) {
    // Get the index BEFORE removing from map (map still has old index)
    final removedIndex = _callLogIndexMap[item.sessionId];

    // Remove from map
    _removeFromIndexMap(item.sessionId);

    // Shift indices for items that were after the removed item
    if (removedIndex != null) {
      _shiftIndicesAfterRemoval(removedIndex);
    }

    if (updatedList.isEmpty) {
      _mapNeedsRebuild = true;
    }
  }

  /// Called when a call log is updated in the list.
  /// Only updates the index map if sessionId changed - state emission is in event handlers.
  @override
  void onItemUpdated(
    CallLog oldItem,
    CallLog newItem,
    List<CallLog> updatedList,
  ) {
    // OPTIMIZATION: No map update needed - index unchanged, ID unchanged
    // Only update map if sessionId changed (rare edge case)
    if (oldItem.sessionId != newItem.sessionId) {
      final index = findCallLogIndex(oldItem.sessionId);
      _removeFromIndexMap(oldItem.sessionId);
      if (index != null) {
        _addToIndexMap(newItem.sessionId, index);
      }
    }
  }

  /// Called when the call logs list is cleared.
  /// Only clears the index map - state emission is in event handlers.
  @override
  void onListCleared(List<CallLog> previousList) {
    _callLogIndexMap.clear();
    _mapNeedsRebuild = true;
  }

  /// Called when the entire call logs list is replaced.
  /// Rebuilds the index map - state emission is in event handlers.
  @override
  void onListReplaced(List<CallLog> previousList, List<CallLog> newList) {
    if (isClosed) return;

    // Full rebuild only on list replacement (initial load, refresh, pagination)
    // This is O(n) but only happens on major list changes, not individual updates
    _rebuildIndexMap();
  }

  @override
  Future<void> close() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    ChatSdkListeners.removeCallListener(_listenerId);
    ChatSdkListeners.removeConnectionListener(_listenerId);
    CometChatCallEvents.removeCallEventsListener(_listenerId);
    CallStateService.instance.isActiveCall.removeListener(_onActiveCallChanged);

    // Clear index map
    _callLogIndexMap.clear();

    // Reset pagination state
    _isLoadingMore = false;

    return super.close();
  }
}

/// A silent refresh of the first page (round 5, P5-C14).
class _SilentRefreshCallLogs extends CallLogsEvent {
  const _SilentRefreshCallLogs();
}

/// The chat SDK's call events: any of them may mean a new or changed log.
class _CallLogsSdkCallListener with CallListener {
  _CallLogsSdkCallListener(this._onChange);

  final void Function() _onChange;

  @override
  void onIncomingCallReceived(Call call) => _onChange();

  @override
  void onOutgoingCallAccepted(Call call) => _onChange();

  @override
  void onOutgoingCallRejected(Call call) => _onChange();

  @override
  void onIncomingCallCancelled(Call call) => _onChange();

  @override
  void onCallEndedMessageReceived(Call call) => _onChange();
}

/// A reconnect: calls may have come and gone meanwhile.
class _CallLogsConnectionListener with ConnectionListener {
  _CallLogsConnectionListener(this._onChange);

  final void Function() _onChange;

  @override
  void onConnected() => _onChange();
}

/// The UI Kit's own call events, which also tell of calls this device
/// placed, accepted, declined or ended.
class _CallLogsUiCallListener with CometChatCallEventListener {
  _CallLogsUiCallListener(this._onChange);

  final void Function() _onChange;

  @override
  void ccOutgoingCall(Call call) => _onChange();

  @override
  void ccCallAccepted(Call call) => _onChange();

  @override
  void ccCallRejected(Call call) => _onChange();

  @override
  void ccCallEnded(Call call) => _onChange();
}
