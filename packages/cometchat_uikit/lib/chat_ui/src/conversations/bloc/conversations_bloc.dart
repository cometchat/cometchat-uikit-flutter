import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/domain.dart';
import '../di/conversations_service_locator.dart';
import 'conversations_event.dart';
import 'conversations_state.dart';
import '../utils/conversation_tier_ordering.dart';
import '../../../../shared_ui/cometchat_uikit_shared.dart';
import '../../shared/list_base.dart';
import '../conversations_builder_protocol.dart';
import '../../../../shared_ui/src/logging/cometchat_log.dart';
import '../../../../src/chat_sdk_listeners.dart';

/// BLoC for managing conversations list
///
/// This BLoC manages the conversations list state and handles:
/// - Loading and pagination of conversations
/// - Real-time updates via SDK listeners (messages, users, groups, calls)
/// - Selection management
/// - Typing indicators
/// - User presence (online/offline)
/// - Read/delivery receipts
/// - Group member events
/// - Call events
/// - Connection state
///
/// This BLoC uses the [ListBase] mixin for list management operations.
/// Developers can extend this class and override the hook methods
/// (onItemAdded, onItemRemoved, onItemUpdated, onListCleared, onListReplaced)
/// to add custom logic like sorting, filtering, or validation.
///
/// Example:
/// ```dart
/// class CustomConversationsBloc extends ConversationsBloc {
///   @override
///   void onItemAdded(Conversation item, List<Conversation> updatedList) {
///     // Custom sorting logic
///     final sortedList = _sortWithPinnedFirst(updatedList);
///     super.onItemAdded(item, sortedList);
///   }
/// }
/// ```
class ConversationsBloc extends Bloc<ConversationsEvent, ConversationsState>
    with ListBase<Conversation> {
  // Use cases - initialized from service locator if not provided
  final GetLoggedInUserUseCase getLoggedInUserUseCase;
  final GetConversationUseCase getConversationUseCase;
  final MarkAsDeliveredUseCase markAsDeliveredUseCase;
  final DeleteConversationUseCase deleteConversationUseCase;

  // Optional use cases - initialized from service locator if not provided
  final GetConversationsUseCase? getConversationsUseCase;
  final LoadMoreConversationsUseCase? loadMoreConversationsUseCase;

  // SDK request for pagination
  ConversationsRequest? _conversationsRequest;

  // Pagination state tracking
  bool _isLoadingMore = false;

  // Logged in user
  User? _loggedInUser;

  // ============================================================
  // OPTIMIZATION: Map-based O(1) conversation lookups
  // ============================================================
  final Map<String, int> _conversationIndexMap = {};

  // ============================================================
  // OPTIMIZATION: Debounce timers for rapid updates
  // ============================================================
  Timer? _typingDebounceTimer;
  Timer? _batchEmitTimer;
  final List<ConversationsEvent> _pendingEvents = [];
  static const Duration _batchDelay = Duration(milliseconds: 50);
  static const Duration _typingDebounceDelay = Duration(milliseconds: 100);

  // SDK listener IDs
  final String _messageListenerKey =
      'conversations_bloc_message_${DateTime.now().millisecondsSinceEpoch}';
  final String _userListenerKey =
      'conversations_bloc_user_${DateTime.now().millisecondsSinceEpoch}';
  final String _groupListenerKey =
      'conversations_bloc_group_${DateTime.now().millisecondsSinceEpoch}';
  final String _callListenerKey =
      'conversations_bloc_call_${DateTime.now().millisecondsSinceEpoch}';
  final String _connectionListenerKey =
      'conversations_bloc_connection_${DateTime.now().millisecondsSinceEpoch}';
  final String _conversationListenerKey =
      'conversations_bloc_conversation_${DateTime.now().millisecondsSinceEpoch}';

  // CC UI Event listener IDs
  final String _ccMessageListenerKey =
      'conversations_bloc_cc_message_${DateTime.now().millisecondsSinceEpoch}';
  final String _ccGroupListenerKey =
      'conversations_bloc_cc_group_${DateTime.now().millisecondsSinceEpoch}';
  final String _ccConversationListenerKey =
      'conversations_bloc_cc_conversation_${DateTime.now().millisecondsSinceEpoch}';
  final String _ccCallListenerKey =
      'conversations_bloc_cc_call_${DateTime.now().millisecondsSinceEpoch}';

  // Configuration options
  final bool disableSoundForMessages;
  final String? customSoundForMessages;
  final bool usersStatusVisibility;
  final bool receiptsVisibility;
  final bool includeBlockedUsers;

  /// Caller-provided request builder. Its filter fields (tags, userTags,
  /// groupTags, withTags, withUserAndGroupTags, includeBlockedUsers,
  /// withBlockedInfo, conversationType, unread) are applied to the initial
  /// fetch, pagination fetch, and the realtime-add predicate.
  final ConversationsRequestBuilder? conversationsRequestBuilder;

  /// Caller-provided builder protocol. If supplied, its [ConversationsBuilderProtocol.getRequest] result
  /// takes precedence over [conversationsRequestBuilder].
  final ConversationsBuilderProtocol? conversationsProtocol;

  /// Effective builder resolved from [conversationsProtocol] (preferred) or
  /// [conversationsRequestBuilder]. Cached so we don't call
  /// `protocol.getRequest()` on every event.
  ConversationsRequestBuilder? _effectiveRequestBuilder;

  /// Whether to disable SDK listeners (for web platform where native SDK is unavailable)
  final bool disableSDKListeners;

  // ============================================================
  // OPTIMIZATION: Per-conversation typing indicators using ValueNotifier
  // Each conversation has its own notifier - only affected item rebuilds
  // Stores a List to support multiple typers in group conversations
  // ============================================================
  final Map<String, ValueNotifier<List<TypingIndicator>>> _typingNotifiers = {};

  /// Get or create a typing notifier for a specific conversation.
  /// Use this with ValueListenableBuilder in list items for isolated rebuilds.
  /// Returns a list of typing indicators (empty if no one is typing).
  ValueNotifier<List<TypingIndicator>> getTypingNotifier(
    String conversationId,
  ) {
    return _typingNotifiers.putIfAbsent(
      conversationId,
      () => ValueNotifier<List<TypingIndicator>>([]),
    );
  }

  /// Get current typing indicators for a conversation (for initial value)
  List<TypingIndicator> getTypingIndicators(String conversationId) {
    return _typingNotifiers[conversationId]?.value ?? [];
  }

  /// Visible item threshold for lazy updates (user status updates skip items beyond this)
  final int visibleItemThreshold;

  /// Helper to get initialized service locator
  static ConversationsServiceLocator _getServiceLocator() {
    if (!ConversationsServiceLocator.instance.isInitialized) {
      ConversationsServiceLocator.instance.setup();
    }
    return ConversationsServiceLocator.instance;
  }

  /// Creates a ConversationsBloc.
  ///
  /// All use cases are optional - if not provided, they will be automatically
  /// initialized from the default service locator. This makes it easy to extend
  /// the bloc without worrying about dependency injection.
  ConversationsBloc({
    GetLoggedInUserUseCase? getLoggedInUserUseCase,
    GetConversationUseCase? getConversationUseCase,
    MarkAsDeliveredUseCase? markAsDeliveredUseCase,
    DeleteConversationUseCase? deleteConversationUseCase,
    GetConversationsUseCase? getConversationsUseCase,
    LoadMoreConversationsUseCase? loadMoreConversationsUseCase,
    this.disableSoundForMessages = false,
    this.customSoundForMessages,
    this.usersStatusVisibility = true,
    this.receiptsVisibility = true,
    this.includeBlockedUsers = false,
    this.visibleItemThreshold = 30,
    this.disableSDKListeners = false,
    this.conversationsRequestBuilder,
    this.conversationsProtocol,
  }) : getLoggedInUserUseCase =
           getLoggedInUserUseCase ??
           _getServiceLocator().getLoggedInUserUseCase,
       getConversationUseCase =
           getConversationUseCase ??
           _getServiceLocator().getConversationUseCase,
       markAsDeliveredUseCase =
           markAsDeliveredUseCase ??
           _getServiceLocator().markAsDeliveredUseCase,
       deleteConversationUseCase =
           deleteConversationUseCase ??
           _getServiceLocator().deleteConversationUseCase,
       getConversationsUseCase =
           getConversationsUseCase ??
           _getServiceLocator().getConversationsUseCase,
       loadMoreConversationsUseCase =
           loadMoreConversationsUseCase ??
           _getServiceLocator().loadMoreConversationsUseCase,
       super(const ConversationsInitial()) {
    // Resolve effective request builder once. Protocol wins over direct builder.
    _effectiveRequestBuilder =
        conversationsProtocol?.requestBuilder ?? conversationsRequestBuilder;
    // Register event handlers
    on<LoadConversations>(_onLoadConversations);
    on<LoadMoreConversations>(_onLoadMoreConversations);
    on<RefreshConversations>(_onRefreshConversations);
    on<DeleteConversation>(_onDeleteConversation);
    on<RemoveConversation>(_onRemoveConversation);
    on<SetActiveConversation>(_onSetActiveConversation);
    on<ToggleConversationSelection>(_onToggleConversationSelection);
    on<ClearConversationSelection>(_onClearConversationSelection);
    on<UpdateConversation>(_onUpdateConversation);
    on<ResetUnreadCount>(_onResetUnreadCount);

    // Internal events
    on<_MessageReceivedUpdate>(_onMessageReceivedUpdate);
    on<_UserStatusUpdate>(_onUserStatusUpdate);
    on<_ReceiptUpdate>(_onReceiptUpdate);
    on<_MessageEditedUpdate>(_onMessageEditedUpdate);
    on<_GroupUpdate>(_onGroupUpdate);
    on<_RemoveGroupConversation>(_onRemoveGroupConversation);
    on<_ConnectionStateUpdate>(_onConnectionStateUpdate);
    on<_ConversationUnreadUpdate>(_onConversationUnreadUpdate);
    on<_ConversationPinUpdate>(_onConversationPinUpdate);

    // List base hook events
    on<_ListItemAdded>(_onListItemAdded);
    on<_ListItemRemoved>(_onListItemRemoved);
    on<_ListItemUpdated>(_onListItemUpdated);
    on<_ListCleared>(_onListCleared);
    on<_ListReplaced>(_onListReplaced);

    // Initialize logged in user and register SDK listeners
    _initializeAndRegisterListeners();
  }

  /// Conversations per page: the effective builder's limit, else 30. The
  /// first page, load-more and the first page's hasMore all use it.
  int get _pageSize => _effectiveRequestBuilder?.limit ?? 30;

  /// Build a ConversationsRequestBuilder seeded from the effective
  /// caller-provided builder (if any), then stamp [limit]/[fromId].
  /// Mirrors the pattern used by SearchBloc._searchConversations.
  ConversationsRequestBuilder _buildRequestBuilder({required int limit}) {
    final builder = ConversationsRequestBuilder();
    final source = _effectiveRequestBuilder;
    if (source != null) {
      builder.withUserAndGroupTags = source.withUserAndGroupTags;
      builder.withTags = source.withTags;
      builder.tags = source.tags;
      builder.includeBlockedUsers = source.includeBlockedUsers;
      builder.withBlockedInfo = source.withBlockedInfo;
      builder.userTags = source.userTags;
      builder.groupTags = source.groupTags;
      builder.conversationType = source.conversationType;
      builder.unread = source.unread;
    }
    builder.limit = limit;
    return builder;
  }

  /// Returns `true` if [conversation] is compatible with the caller-provided
  /// filter (i.e. safe to add/update from the realtime SDK listener).
  ///
  /// Only enforces constraints we can evaluate client-side without a round
  /// trip: conversation type (user vs group) and, when the corresponding
  /// User/Group object carries `tags`, the tag filters. When we can't tell
  /// (no effective builder, or the SDK payload doesn't expose tags), we err
  /// on the side of keeping the conversation — this matches the previous
  /// behavior and avoids silently dropping messages in the unfiltered case.
  bool _matchesFilter(Conversation conversation) {
    final source = _effectiveRequestBuilder;
    if (source == null) return true;

    // Conversation type filter (user vs group).
    if (source.conversationType != null &&
        source.conversationType!.isNotEmpty &&
        conversation.conversationType != source.conversationType) {
      return false;
    }

    final tagsToMatch = <String>{};
    final withObj = conversation.conversationWith;

    if (withObj is Group) {
      final groupTags = source.groupTags;
      if (groupTags != null && groupTags.isNotEmpty) {
        final objTags = withObj.tags;
        if (objTags == null || !_anyMatch(objTags, groupTags)) {
          return false;
        }
      }
      if (source.withUserAndGroupTags == true || source.withTags == true) {
        final tags = source.tags;
        if (tags != null && tags.isNotEmpty) tagsToMatch.addAll(tags);
      }
      if (tagsToMatch.isNotEmpty) {
        final objTags = withObj.tags;
        if (objTags == null || !_anyMatch(objTags, tagsToMatch.toList())) {
          return false;
        }
      }
    } else if (withObj is User) {
      final userTags = source.userTags;
      if (userTags != null && userTags.isNotEmpty) {
        final objTags = withObj.tags;
        if (objTags == null || !_anyMatch(objTags, userTags)) {
          return false;
        }
      }
    }

    return true;
  }

  bool _anyMatch(List<String> actual, List<String> expected) {
    for (final e in expected) {
      if (actual.contains(e)) return true;
    }
    return false;
  }

  // ============================================================
  // OPTIMIZATION: Map-based lookup helpers with incremental updates
  // ============================================================

  /// Flag to track if map needs full rebuild (only on initial load/refresh)
  bool _mapNeedsRebuild = true;

  /// Full rebuild - only called on initial load or refresh
  void _rebuildIndexMap() {
    _conversationIndexMap.clear();
    for (int i = 0; i < items.length; i++) {
      final id = items[i].conversationId;
      if (id != null && id.isNotEmpty) {
        _conversationIndexMap[id] = i;
      }
    }
    _mapNeedsRebuild = false;
  }

  /// Incremental: Add single item to map at index
  void _addToIndexMap(String? conversationId, int index) {
    if (conversationId != null && conversationId.isNotEmpty) {
      _conversationIndexMap[conversationId] = index;
    }
  }

  /// Incremental: Remove single item from map
  void _removeFromIndexMap(String? conversationId) {
    if (conversationId != null && conversationId.isNotEmpty) {
      _conversationIndexMap.remove(conversationId);
    }
  }

  /// Incremental: Shift indices after removal (items after removedIndex move up)
  void _shiftIndicesAfterRemoval(int removedIndex) {
    _conversationIndexMap.updateAll((key, index) {
      return index > removedIndex ? index - 1 : index;
    });
  }

  /// O(1) conversation index lookup
  int? _findConversationIndex(String? conversationId) {
    if (conversationId == null || conversationId.isEmpty) return null;
    // Lazy rebuild if needed
    if (_mapNeedsRebuild && items.isNotEmpty) {
      _rebuildIndexMap();
    }
    return _conversationIndexMap[conversationId];
  }

  /// O(1) conversation lookup by ID
  Conversation? _findConversation(String? conversationId) {
    final index = _findConversationIndex(conversationId);
    return index != null && index < items.length ? items[index] : null;
  }

  // ============================================================
  // OPTIMIZATION: Batch event processing
  // ============================================================

  /// Queue an event for batched processing
  void _queueEvent(ConversationsEvent event) {
    _pendingEvents.add(event);
    _batchEmitTimer?.cancel();
    _batchEmitTimer = Timer(_batchDelay, _processBatchedEvents);
  }

  /// Process all pending events in a single batch
  void _processBatchedEvents() {
    if (_pendingEvents.isEmpty || isClosed) return;

    final events = List<ConversationsEvent>.from(_pendingEvents);
    _pendingEvents.clear();

    // Check isClosed once before processing all events
    if (isClosed) return;

    for (final event in events) {
      add(event);
    }
  }

  /// Initialize logged in user and register all SDK listeners
  Future<void> _initializeAndRegisterListeners() async {
    final result = await getLoggedInUserUseCase();

    if (result is Success<User?>) {
      _loggedInUser = result.data;
    } else if (result is Failure) {
      ccLog('Warning: Failed to get logged-in user: ${result.message}');
    }

    // Skip SDK listeners if disabled (e.g., for web platform)
    if (!disableSDKListeners) {
      _registerSDKListeners();
    }
  }

  /// Register all CometChat SDK listeners for real-time updates
  void _registerSDKListeners() {
    CometChat.addMessageListener(
      _messageListenerKey,
      _ConversationMessageListener(
        onMessageReceivedCallback: _handleMessageReceived,
        onTypingStartedCallback: _handleTypingStarted,
        onTypingEndedCallback: _handleTypingEnded,
        onMessagesDeliveredCallback: _handleMessagesDelivered,
        onMessagesReadCallback: _handleMessagesRead,
        onMessagesDeliveredToAllCallback: _handleMessagesDeliveredToAll,
        onMessagesReadByAllCallback: _handleMessagesReadByAll,
        onMessageEditedCallback: _handleMessageEdited,
        onMessageDeletedCallback: _handleMessageDeleted,
      ),
    );

    if (usersStatusVisibility) {
      CometChat.addUserListener(
        _userListenerKey,
        _ConversationUserListener(
          onUserOnlineCallback: _handleUserOnline,
          onUserOfflineCallback: _handleUserOffline,
        ),
      );
    }

    CometChat.addGroupListener(
      _groupListenerKey,
      _ConversationGroupListener(
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

    ChatSdkListeners.addCallListener(
      _callListenerKey,
      _ConversationCallListener(
        onIncomingCallReceivedCallback: _handleIncomingCallReceived,
        onOutgoingCallAcceptedCallback: _handleOutgoingCallAccepted,
        onOutgoingCallRejectedCallback: _handleOutgoingCallRejected,
        onIncomingCallCancelledCallback: _handleIncomingCallCancelled,
        onCallEndedMessageReceivedCallback: _handleCallEndedMessageReceived,
      ),
    );

    CometChat.addConnectionListener(
      _connectionListenerKey,
      _ConversationConnectionListener(
        onConnectedCallback: _handleConnected,
        onDisconnectedCallback: _handleDisconnected,
      ),
    );

    // Pin Conversation: self-echo events for the logged-in user's pins —
    // fired locally on this device's own REST success and via socket from
    // their other devices (plus admin app_system pins).
    CometChat.addConversationListener(
      _conversationListenerKey,
      _ConversationPinListener(
        onPinnedCallback: (conversation) {
          if (!isClosed) {
            add(_ConversationPinUpdate(conversation, pinned: true));
          }
        },
        onUnpinnedCallback: (conversation) {
          if (!isClosed) {
            add(_ConversationPinUpdate(conversation, pinned: false));
          }
        },
      ),
    );

    _registerCCEventListeners();
  }

  /// Register all CometChat UI Event listeners
  void _registerCCEventListeners() {
    CometChatMessageEvents.addMessagesListener(
      _ccMessageListenerKey,
      _CCMessageEventListener(
        onCCMessageSentCallback: _handleCCMessageSent,
        onCCMessageReadCallback: _handleCCMessageRead,
        onCCMessageEditedCallback: _handleCCMessageEdited,
        onCCMessageDeletedCallback: _handleCCMessageDeleted,
        onMessagesDeliveredCallback: _handleMessagesDelivered,
        onMessagesReadCallback: _handleMessagesRead,
        onMessagesDeliveredToAllCallback: _handleMessagesDeliveredToAll,
        onMessagesReadByAllCallback: _handleMessagesReadByAll,
      ),
    );

    CometChatGroupEvents.addGroupsListener(
      _ccGroupListenerKey,
      _CCGroupEventListener(
        onCCGroupLeftCallback: _handleCCGroupLeft,
        onCCGroupDeletedCallback: _handleCCGroupDeleted,
        onCCGroupMemberAddedCallback: _handleCCGroupMemberAdded,
        onCCGroupMemberKickedCallback: _handleCCGroupMemberKicked,
        onCCGroupMemberBannedCallback: _handleCCGroupMemberBanned,
        onCCOwnershipChangedCallback: _handleCCOwnershipChanged,
      ),
    );

    CometChatConversationEvents.addConversationListListener(
      _ccConversationListenerKey,
      _CCConversationEventListener(
        onCCConversationDeletedCallback: _handleCCConversationDeleted,
        onCCConversationUpdatedCallback: _handleCCConversationUpdated,
      ),
    );

    // This device's own calls: the chat SDK does not tell the caller about
    // the call it just placed ("initiated"), nor this device about a call
    // it accepted, declined or ended itself.
    CometChatCallEvents.addCallEventsListener(
      _ccCallListenerKey,
      _ConversationCallEventsListener(onCallCallback: _handleCCCall),
    );
  }

  // ============================================================
  // EVENT HANDLERS
  // ============================================================

  /// Load initial conversations using use case
  Future<void> _onLoadConversations(
    LoadConversations event,
    Emitter<ConversationsState> emit,
  ) async {
    // Silent refresh: keep existing list visible, skip loading shimmer.
    // Triggered explicitly via event.silent (reconnect, background→foreground)
    // OR inferred when conversations are already loaded.
    final isSilentRefresh = event.silent || state is ConversationsLoaded;

    if (!isSilentRefresh) {
      emit(const ConversationsLoading());
    }

    _isLoadingMore = false;

    if (_loggedInUser == null) {
      final userResult = await getLoggedInUserUseCase();
      if (userResult is Success<User?>) {
        _loggedInUser = userResult.data;
      }
    }

    if (getConversationsUseCase != null) {
      final result = await getConversationsUseCase!(
        limit: _pageSize,
        requestBuilder: _effectiveRequestBuilder,
      );

      if (result is Success<List<Conversation>>) {
        final conversations = result.data;
        if (conversations.isEmpty && !isSilentRefresh) {
          emit(const ConversationsEmpty());
        } else if (conversations.isNotEmpty) {
          replaceAll(conversations);
        }
      } else if (result is Failure && !isSilentRefresh) {
        if (kDebugMode) {
          ccLog('[ConversationsBloc] _onLoadConversations useCase Failure');
          ccLog('[ConversationsBloc]   message: ${result.message}');
          ccLog('[ConversationsBloc]   -> emitting ConversationsError');
        }
        emit(ConversationsError(message: result.message));
      }
    } else {
      try {
        final requestBuilder = _buildRequestBuilder(limit: _pageSize);
        _conversationsRequest = requestBuilder.build();

        final completer = Completer<List<Conversation>>();

        await _conversationsRequest!.fetchNext(
          onSuccess: (List<Conversation> conversations) {
            completer.complete(conversations);
          },
          onError: (CometChatException exception) {
            completer.completeError(exception);
          },
        );

        final conversations = await completer.future;

        if (conversations.isEmpty && !isSilentRefresh) {
          emit(const ConversationsEmpty());
        } else if (conversations.isNotEmpty) {
          replaceAll(conversations);
        }
      } on CometChatException catch (e) {
        if (!isSilentRefresh) {
          if (kDebugMode) {
            ccLog(
              '[ConversationsBloc] _onLoadConversations CometChatException',
            );
            ccLog('[ConversationsBloc]   code:    ${e.code}');
            ccLog('[ConversationsBloc]   message: ${e.message}');
            ccLog('[ConversationsBloc]   details: ${e.details}');
            ccLog('[ConversationsBloc]   -> emitting ConversationsError');
          }
          emit(
            ConversationsError(
              message: e.message ?? 'Failed to load conversations',
            ),
          );
        }
      } catch (e) {
        if (!isSilentRefresh) {
          if (kDebugMode) {
            ccLog('[ConversationsBloc] _onLoadConversations generic catch: $e');
            ccLog('[ConversationsBloc]   -> emitting ConversationsError');
          }
          emit(ConversationsError(message: 'Failed to load conversations: $e'));
        }
      }
    }
  }

  /// Load more conversations (pagination)
  Future<void> _onLoadMoreConversations(
    LoadMoreConversations event,
    Emitter<ConversationsState> emit,
  ) async {
    if (state is! ConversationsLoaded) return;

    final currentState = state as ConversationsLoaded;

    if (!currentState.hasMore || currentState.isLoadingMore || _isLoadingMore) {
      return;
    }

    _isLoadingMore = true;
    emit(currentState.copyWith(isLoadingMore: true));

    if (loadMoreConversationsUseCase != null &&
        currentState.conversations.isNotEmpty) {
      final lastConversationId = currentState.conversations.last.conversationId;

      if (lastConversationId == null || lastConversationId.isEmpty) {
        _isLoadingMore = false;
        emit(currentState.copyWith(isLoadingMore: false, hasMore: false));
        return;
      }

      final result = await loadMoreConversationsUseCase!(
        limit: _pageSize,
        fromId: lastConversationId,
        currentConversations: currentState.conversations,
        requestBuilder: _effectiveRequestBuilder,
      );

      _isLoadingMore = false;

      if (result is Success<List<Conversation>>) {
        final newConversations = result.data;

        if (newConversations.isEmpty) {
          emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
          return;
        }

        // Dedupe against rows already loaded: a row that moved (to the
        // top on new message, or into the pinned shelf) can reappear in a
        // later page — and the unpin drop rule relies on pagination
        // re-adding rows, so pages routinely carry ids we already show.
        final allConversations = [
          ...currentState.conversations,
          ...newConversations.where(
            (conversation) =>
                _findConversationIndex(conversation.conversationId) == null,
          ),
        ];

        replaceAll(allConversations);
      } else if (result is Failure) {
        if (kDebugMode) {
          ccLog('[ConversationsBloc] _onLoadMoreConversations useCase Failure');
          ccLog('[ConversationsBloc]   message: ${result.message}');
          ccLog('[ConversationsBloc]   -> emitting ConversationsError');
        }
        emit(
          ConversationsError(
            message: result.message,
            previousConversations: currentState.conversations,
          ),
        );
      }
    } else if (_conversationsRequest != null) {
      try {
        final completer = Completer<List<Conversation>>();

        await _conversationsRequest!.fetchNext(
          onSuccess: (List<Conversation> conversations) {
            completer.complete(conversations);
          },
          onError: (CometChatException exception) {
            completer.completeError(exception);
          },
        );

        final newConversations = await completer.future;

        _isLoadingMore = false;

        if (newConversations.isEmpty) {
          emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
          return;
        }

        // Dedupe against rows already loaded: a row that moved (to the
        // top on new message, or into the pinned shelf) can reappear in a
        // later page — and the unpin drop rule relies on pagination
        // re-adding rows, so pages routinely carry ids we already show.
        final allConversations = [
          ...currentState.conversations,
          ...newConversations.where(
            (conversation) =>
                _findConversationIndex(conversation.conversationId) == null,
          ),
        ];

        replaceAll(allConversations);
      } on CometChatException catch (e) {
        _isLoadingMore = false;
        if (kDebugMode) {
          ccLog(
            '[ConversationsBloc] _onLoadMoreConversations CometChatException',
          );
          ccLog('[ConversationsBloc]   code:    ${e.code}');
          ccLog('[ConversationsBloc]   message: ${e.message}');
          ccLog('[ConversationsBloc]   details: ${e.details}');
          ccLog('[ConversationsBloc]   -> emitting ConversationsError');
        }
        emit(
          ConversationsError(
            message: e.message ?? 'Failed to load more conversations',
            previousConversations: currentState.conversations,
          ),
        );
      } catch (e) {
        _isLoadingMore = false;
        if (kDebugMode) {
          ccLog(
            '[ConversationsBloc] _onLoadMoreConversations generic catch: $e',
          );
          ccLog('[ConversationsBloc]   -> emitting ConversationsError');
        }
        emit(
          ConversationsError(
            message: 'Failed to load more conversations: $e',
            previousConversations: currentState.conversations,
          ),
        );
      }
    } else {
      _isLoadingMore = false;
      emit(currentState.copyWith(isLoadingMore: false, hasMore: false));
    }
  }

  /// Refresh conversations list
  Future<void> _onRefreshConversations(
    RefreshConversations event,
    Emitter<ConversationsState> emit,
  ) async {
    // Refresh is always silent when data is already loaded
    add(const LoadConversations(silent: true));
  }

  /// Delete a conversation (calls use case and removes from list)
  Future<void> _onDeleteConversation(
    DeleteConversation event,
    Emitter<ConversationsState> emit,
  ) async {
    if (state is! ConversationsLoaded) return;

    // Resolve the SDK delete target from the Conversation OBJECT. The id
    // string cannot distinguish which participant is the peer in a 1:1
    // conversation ("{uidA}_user_{uidB}"), so parsing it can select the
    // logged-in user's own uid → ERR_CONVERSATION_NOT_ACCESSIBLE.
    final conversation = _findConversation(event.conversationId);
    String? conversationWith;
    String? conversationType;
    final target = conversation?.conversationWith;
    if (target is User) {
      conversationWith = target.uid;
      conversationType = conversation?.conversationType;
    } else if (target is Group) {
      conversationWith = target.guid;
      conversationType = conversation?.conversationType;
    }

    final result = await deleteConversationUseCase(
      event.conversationId,
      conversationWith: conversationWith,
      conversationType: conversationType,
    );

    if (result is Success<void>) {
      if (conversation != null) {
        removeItem(conversation);
      }
    } else if (result is Failure) {
      // Don't replace the list with an error view — just log the failure.
      // The conversation stays in the list so the user can retry.
      ccLog(
        'Failed to delete conversation ${event.conversationId}: ${result.message}',
      );
    }
  }

  /// Remove a conversation from list without calling SDK
  void _onRemoveConversation(
    RemoveConversation event,
    Emitter<ConversationsState> emit,
  ) {
    if (state is! ConversationsLoaded) return;

    // OPTIMIZATION: Use O(1) lookup
    final conversation = _findConversation(event.conversationId);
    if (conversation != null) {
      removeItem(conversation);
    }
  }

  /// Set active conversation
  void _onSetActiveConversation(
    SetActiveConversation event,
    Emitter<ConversationsState> emit,
  ) {
    if (state is! ConversationsLoaded) return;

    final currentState = state as ConversationsLoaded;
    emit(currentState.copyWith(activeConversationId: event.conversationId));
  }

  /// Toggle conversation selection
  void _onToggleConversationSelection(
    ToggleConversationSelection event,
    Emitter<ConversationsState> emit,
  ) {
    if (state is! ConversationsLoaded) return;

    final currentState = state as ConversationsLoaded;
    final selected = Set<String>.from(currentState.selectedConversations);

    if (selected.contains(event.conversationId)) {
      selected.remove(event.conversationId);
    } else {
      selected.add(event.conversationId);
    }

    emit(currentState.copyWith(selectedConversations: selected));
  }

  /// Clear conversation selection
  void _onClearConversationSelection(
    ClearConversationSelection event,
    Emitter<ConversationsState> emit,
  ) {
    if (state is! ConversationsLoaded) return;

    final currentState = state as ConversationsLoaded;
    emit(currentState.copyWith(selectedConversations: {}));
  }

  /// Update a conversation with modified data from external sources
  void _onUpdateConversation(
    UpdateConversation event,
    Emitter<ConversationsState> emit,
  ) {
    if (state is! ConversationsLoaded) return;

    // OPTIMIZATION: Use O(1) lookup
    final conversationIndex = _findConversationIndex(event.conversationId);

    if (conversationIndex == null) {
      // Tier ordering [system pins][user pins][normal]: a row that isn't
      // loaded yet enters at the top of its own tier — never appended below
      // the fold, never above a shelf it doesn't belong to.
      insertItemAt(
        ConversationTierOrdering.tierTopIndex(
          ConversationTierOrdering.tierOf(event.updatedConversation),
          items,
        ),
        event.updatedConversation,
      );
      return;
    }

    updateItem(conversationIndex, event.updatedConversation);
  }

  /// Reset unread count for a conversation
  void _onResetUnreadCount(
    ResetUnreadCount event,
    Emitter<ConversationsState> emit,
  ) {
    if (state is! ConversationsLoaded) return;

    // OPTIMIZATION: Use O(1) lookup
    final matchingIndex = _findConversationIndex(event.conversationId);
    if (matchingIndex == null || matchingIndex >= items.length) return;

    // Use items from ListBase (source of truth) not state
    final updatedConversation = items[matchingIndex].copyWith(
      unreadMessageCount: 0,
    );
    updateItem(matchingIndex, updatedConversation);
  }

  // ============================================================
  // INTERNAL EVENT HANDLERS
  // ============================================================

  /// Handle message received update event
  /// Moves conversation to top of list when new message arrives
  void _onMessageReceivedUpdate(
    _MessageReceivedUpdate event,
    Emitter<ConversationsState> emit,
  ) {
    if (state is! ConversationsLoaded) return;

    final currentState = state as ConversationsLoaded;
    final updatedConversation = event.conversation;

    final isActiveConversation =
        currentState.activeConversationId != null &&
        currentState.activeConversationId == updatedConversation.conversationId;

    Conversation finalConversation = updatedConversation;
    if (isActiveConversation) {
      finalConversation = updatedConversation.copyWith(unreadMessageCount: 0);
    }

    final existingIndex = _findConversationIndex(
      finalConversation.conversationId,
    );

    // Tier ordering [system pins][user pins][normal]: activity floats the
    // row to the top of ITS OWN tier only. A pinned row keeps its pin
    // fields (finalConversation was built from the incoming message and
    // knows nothing about them) and rises within its shelf section; a
    // normal row rises to the top of the unpinned region — index 0 would
    // put it above the pins.
    if (existingIndex != null &&
        currentState.conversations[existingIndex].pinnedAt != null) {
      final local = currentState.conversations[existingIndex];
      finalConversation.pinnedAt = local.pinnedAt;
      finalConversation.pinnedBy = local.pinnedBy;
    }

    // Computed on the full list: the row's current slot is always at or
    // below its own tier top, so removing it never shifts this boundary.
    final insertAt = ConversationTierOrdering.tierTopIndex(
      ConversationTierOrdering.tierOf(finalConversation),
      currentState.conversations,
    );

    if (existingIndex != null && existingIndex == insertAt) {
      // Already at its tier top - use updateItem for O(1) operation
      updateItem(insertAt, finalConversation);
      return;
    }

    // replaceAll updates ListBase's internal items and triggers onListReplaced with rebuild
    final conversations = List<Conversation>.from(currentState.conversations);

    if (existingIndex != null) {
      conversations.removeAt(existingIndex);
    }
    conversations.insert(
      insertAt.clamp(0, conversations.length),
      finalConversation,
    );

    replaceAll(conversations);
  }

  /// Pin Conversation: reorders the list when a pin/unpin lands (own action
  /// on any device, or an admin pin).
  ///
  /// Pin → into the pinned shelf, kept in pinnedAt-descending order so
  /// crossing frames from two devices settle deterministically. Unpin → back
  /// into the activity-ordered region at its updatedAt slot; when that slot
  /// is beyond the loaded window and more pages exist, the row is dropped —
  /// pagination restores it where it belongs.
  Future<void> _onConversationPinUpdate(
    _ConversationPinUpdate event,
    Emitter<ConversationsState> emit,
  ) async {
    if (state is! ConversationsLoaded) return;
    final currentState = state as ConversationsLoaded;

    final incoming = event.conversation;
    final conversationId = incoming.conversationId;
    if (conversationId == null) return;

    final existingIndex = _findConversationIndex(conversationId);

    if (event.pinned) {
      Conversation merged;
      if (existingIndex != null) {
        // Keep the local row's live fields (last message, unread count) —
        // the frame's conversation may be staler than local state — and
        // take only the pin fields from the event.
        merged = currentState.conversations[existingIndex];
        merged.pinnedAt = incoming.pinnedAt;
        merged.pinnedBy = incoming.pinnedBy;
      } else {
        // Pinned a conversation that isn't loaded (beyond pagination or
        // never fetched): it belongs on the shelf, so bring it in — but
        // never leak past a caller-provided type filter.
        if (!_matchesFilter(incoming)) return;
        merged = incoming;
      }

      final conversations = List<Conversation>.from(currentState.conversations);
      if (existingIndex != null) {
        conversations.removeAt(existingIndex);
      }

      // Insert at the top of its own tier: a system pin (pinnedBy ==
      // app_system) enters above the user-pin section, a user pin enters
      // below the system section — never interleaved. Freshest pin lands
      // on top within its tier; the server's canonical order re-asserts on
      // the next fetch.
      final insertAt = ConversationTierOrdering.tierTopIndex(
        ConversationTierOrdering.tierOf(merged),
        conversations,
      );
      conversations.insert(insertAt, merged);
      replaceAll(conversations);
      return;
    }

    // ── unpin ──
    if (existingIndex == null) return;

    // copyWith cannot null the pin fields (`pinnedAt ?? this.pinnedAt`), so
    // clear them by direct mutation on the local row.
    final row = currentState.conversations[existingIndex];
    row.pinnedAt = null;
    row.pinnedBy = null;

    final conversations = List<Conversation>.from(currentState.conversations)
      ..removeAt(existingIndex);

    // Its slot in the activity-ordered region: first unpinned row older than
    // this one. A row with no updatedAt can't be placed by time — park it at
    // the top of the unpinned region rather than risking the drop branch.
    final updatedAt = row.updatedAt;
    var insertAt = ConversationTierOrdering.tierTopIndex(
      ConversationTierOrdering.normalTier,
      conversations,
    );
    var found = updatedAt == null;
    while (updatedAt != null && insertAt < conversations.length) {
      final rowUpdatedAt = conversations[insertAt].updatedAt;
      if (rowUpdatedAt == null || rowUpdatedAt.isBefore(updatedAt)) {
        found = true;
        break;
      }
      insertAt++;
    }
    if (insertAt >= conversations.length && !found && currentState.hasMore) {
      // Older than everything loaded with more pages out there: keeping it
      // at the loaded bottom would be a lie and a duplicate once its real
      // page loads. Drop it; pagination restores it in place.
      replaceAll(conversations);
      return;
    }
    conversations.insert(insertAt.clamp(0, conversations.length), row);
    replaceAll(conversations);
  }

  /// Handle conversation unread update — updates unread count in-place
  /// without moving the conversation to the top of the list.
  void _onConversationUnreadUpdate(
    _ConversationUnreadUpdate event,
    Emitter<ConversationsState> emit,
  ) {
    if (state is! ConversationsLoaded) return;

    final updatedConversation = event.conversation;
    final existingIndex = _findConversationIndex(
      updatedConversation.conversationId,
    );
    if (existingIndex == null || existingIndex >= items.length) return;

    final existing = items[existingIndex];
    final merged = existing.copyWith(
      unreadMessageCount: updatedConversation.unreadMessageCount,
      lastMessage: updatedConversation.lastMessage ?? existing.lastMessage,
    );
    updateItem(existingIndex, merged);
  }

  /// Handle user status update event (online/offline)
  /// OPTIMIZATION: Skip updates for conversations beyond visible threshold
  void _onUserStatusUpdate(
    _UserStatusUpdate event,
    Emitter<ConversationsState> emit,
  ) {
    if (state is! ConversationsLoaded) return;

    // Find user conversation using items (source of truth)
    int matchingIndex = -1;
    for (int i = 0; i < items.length; i++) {
      final c = items[i];
      if (c.conversationType == 'user' &&
          (c.conversationWith as User).uid == event.userId) {
        matchingIndex = i;
        break;
      }
    }

    if (matchingIndex == -1) return;

    // OPTIMIZATION: Skip updates for items beyond visible threshold
    if (matchingIndex > visibleItemThreshold) return;

    final conversation = items[matchingIndex];
    final user = conversation.conversationWith as User;

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

    final updatedConversation = Conversation(
      conversationId: conversation.conversationId,
      conversationType: conversation.conversationType,
      conversationWith: updatedUser,
      lastMessage: conversation.lastMessage,
      unreadMessageCount: conversation.unreadMessageCount,
      unreadMentionsCount: conversation.unreadMentionsCount,
      updatedAt: conversation.updatedAt,
      tags: conversation.tags,
      lastReadMessageId: conversation.lastReadMessageId,
    );

    updateItem(matchingIndex, updatedConversation);
  }

  /// Handle receipt update event
  ///
  /// Receipts are cumulative — a receipt for messageId X means all messages
  /// with id <= X are delivered/read. So if the conversation's lastMessage.id
  /// is <= receipt.messageId, the lastMessage should be updated.
  void _onReceiptUpdate(
    _ReceiptUpdate event,
    Emitter<ConversationsState> emit,
  ) {
    if (state is! ConversationsLoaded) return;

    final receipt = event.receipt;

    // Find the conversation that matches this receipt.
    // For user receipts: sender is the other user who delivered/read the message
    // For group receipts: receiverId is the group GUID
    final targetConversationId = _findConversationIdForReceipt(items, receipt);

    // OPTIMIZATION: Use O(1) lookup instead of O(n) scan
    final matchingIndex = _findConversationIndex(targetConversationId);
    if (matchingIndex == null || matchingIndex >= items.length) return;

    final conversation = items[matchingIndex];
    final lastMessage = conversation.lastMessage;

    if (lastMessage == null) return;

    // Receipts are cumulative: "delivered/read up to messageId".
    // If receipt.messageId >= lastMessage.id, the lastMessage is also covered.
    if (lastMessage.id > receipt.messageId!) return;

    bool shouldUpdate = false;

    if (conversation.conversationType == 'user') {
      if (receipt.receiptType == 'delivered' &&
          lastMessage.deliveredAt == null) {
        lastMessage.deliveredAt = receipt.deliveredAt;
        shouldUpdate = true;
      } else if (receipt.receiptType == 'read' && lastMessage.readAt == null) {
        lastMessage.readAt = receipt.readAt;
        lastMessage.deliveredAt ??= receipt.readAt;
        shouldUpdate = true;
      }
    } else if (conversation.conversationType == 'group') {
      if (receipt.receiptType == 'deliveredToAll' &&
          lastMessage.deliveredAt == null) {
        lastMessage.deliveredAt = receipt.deliveredAt;
        shouldUpdate = true;
      } else if (receipt.receiptType == 'readByAll' &&
          lastMessage.readAt == null) {
        lastMessage.readAt = receipt.readAt;
        lastMessage.deliveredAt ??= receipt.readAt;
        shouldUpdate = true;
      }
    }

    if (shouldUpdate) {
      final updatedConversation = Conversation(
        conversationId: conversation.conversationId,
        conversationType: conversation.conversationType,
        conversationWith: conversation.conversationWith,
        lastMessage: lastMessage,
        unreadMessageCount: conversation.unreadMessageCount,
        unreadMentionsCount: conversation.unreadMentionsCount,
        updatedAt: conversation.updatedAt,
        tags: conversation.tags,
        lastReadMessageId: conversation.lastReadMessageId,
      );

      updateItem(matchingIndex, updatedConversation);
    }
  }

  /// Handle message edited update event
  void _onMessageEditedUpdate(
    _MessageEditedUpdate event,
    Emitter<ConversationsState> emit,
  ) {
    if (state is! ConversationsLoaded) return;

    final message = event.message;

    // OPTIMIZATION: Use O(1) lookup
    final matchingIndex = _findConversationIndex(message.conversationId);
    if (matchingIndex == null || matchingIndex >= items.length) return;

    // Use items from ListBase (source of truth)
    final conversation = items[matchingIndex];
    if (conversation.lastMessage?.id != message.id) return;

    final updatedConversation = conversation.copyWith(lastMessage: message);
    updateItem(matchingIndex, updatedConversation);
  }

  /// Handle group update event
  void _onGroupUpdate(_GroupUpdate event, Emitter<ConversationsState> emit) {
    if (state is! ConversationsLoaded) return;

    // Find group conversation by GUID
    int matchingIndex = -1;
    for (int i = 0; i < items.length; i++) {
      final c = items[i];
      if (c.conversationType == 'group' &&
          (c.conversationWith as Group).guid == event.group.guid) {
        matchingIndex = i;
        break;
      }
    }

    if (matchingIndex != -1) {
      final updatedConversation = items[matchingIndex].copyWith(
        conversationWith: event.group,
      );
      updateItem(matchingIndex, updatedConversation);
    }
  }

  /// Handle remove group conversation event
  void _onRemoveGroupConversation(
    _RemoveGroupConversation event,
    Emitter<ConversationsState> emit,
  ) {
    if (state is! ConversationsLoaded) return;

    // Find and remove the group conversation using items (source of truth)
    Conversation? toRemove;
    for (final c in items) {
      if (c.conversationType == 'group' &&
          (c.conversationWith as Group).guid == event.groupId) {
        toRemove = c;
        break;
      }
    }

    if (toRemove != null) {
      removeItem(toRemove);
    }
  }

  /// Handle connection state update event
  void _onConnectionStateUpdate(
    _ConnectionStateUpdate event,
    Emitter<ConversationsState> emit,
  ) {
    if (event.isConnected) {
      add(const LoadConversations(silent: true));
    }
  }

  // ============================================================
  // SDK LISTENER CALLBACKS
  // ============================================================

  /// Handle new message received
  void _handleMessageReceived(BaseMessage message) {
    if (isClosed) return;
    if (state is! ConversationsLoaded) return;

    if (message.sender?.uid != _loggedInUser?.uid) {
      markAsDeliveredUseCase(message);
    }

    _playIncomingMessageSound(message);
    _updateConversationFromMessage(message);
  }

  /// Plays the incoming-message sound for a message from someone else.
  ///
  /// Silent when [disableSoundForMessages] is on, for custom messages that
  /// don't count as unread, and for the conversation that is open, whose
  /// message list plays its own. [customSoundForMessages] replaces the kit's
  /// sound when set.
  void _playIncomingMessageSound(BaseMessage message) {
    if (disableSoundForMessages) return;
    if (message.sender?.uid == _loggedInUser?.uid) return;
    if (message is CustomMessage &&
        message.metadata?[UpdateSettingsConstant.incrementUnreadCount] !=
            true) {
      return;
    }
    final activeConversationId =
        (state as ConversationsLoaded).activeConversationId;
    if (activeConversationId != null &&
        activeConversationId == message.conversationId) {
      return;
    }
    CometChatUIKit.soundManager.play(
      sound: activeConversationId == null
          ? Sound.incomingMessageFromOther
          : Sound.incomingMessage,
      customSound: customSoundForMessages,
    );
  }

  /// Update conversation directly from message data
  void _updateConversationFromMessage(BaseMessage message) {
    if (state is! ConversationsLoaded) return;

    final currentState = state as ConversationsLoaded;
    final targetConversationId = message.conversationId;

    if (targetConversationId == null || targetConversationId.isEmpty) {
      return;
    }

    // OPTIMIZATION: Use O(1) lookup
    final existingIndex = _findConversationIndex(targetConversationId);

    if (existingIndex != null) {
      final sdkConversation = currentState.conversations[existingIndex];

      final isActiveConversation =
          currentState.activeConversationId != null &&
          currentState.activeConversationId == targetConversationId;

      bool shouldIncrementUnread = false;
      if (message.sender?.uid != _loggedInUser?.uid && !isActiveConversation) {
        if (message is CustomMessage) {
          shouldIncrementUnread =
              message.updateConversation == true ||
              (message.metadata?['incrementUnreadCount'] == true);
        } else {
          shouldIncrementUnread = true;
        }
      }

      final newUnreadCount = shouldIncrementUnread
          ? sdkConversation.unreadMessageCount + 1
          : sdkConversation.unreadMessageCount;

      final updatedConversation = sdkConversation.copyWith(
        lastMessage: message,
        unreadMessageCount: newUnreadCount,
        updatedAt: message.sentAt,
      );

      add(_MessageReceivedUpdate(updatedConversation));
    } else {
      _fetchNewConversation(message);
    }
  }

  /// Fetch a new conversation
  Future<void> _fetchNewConversation(BaseMessage message) async {
    if (state is! ConversationsLoaded) return;

    final conversationWith = message.receiverType == 'user'
        ? message.sender?.uid
        : message.receiverUid;

    if (conversationWith == null) return;

    final result = await getConversationUseCase(
      conversationWith: conversationWith,
      conversationType: message.receiverType,
    );

    if (result is Success<Conversation>) {
      // Don't leak conversations that don't satisfy the caller-provided
      // filter. Existing conversations in the list already passed this
      // check at load time; this only applies to conversations appearing
      // for the first time via the realtime SDK listener.
      if (!_matchesFilter(result.data)) return;
      add(_MessageReceivedUpdate(result.data));
    }
  }

  /// Handle typing started
  /// OPTIMIZATION: Uses ValueNotifier per conversation - only affected item rebuilds
  /// Supports multiple typers in group conversations
  void _handleTypingStarted(TypingIndicator typingIndicator) {
    if (state is! ConversationsLoaded) return;
    if (!_userIsNotBlocked(typingIndicator.sender)) return;

    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = Timer(_typingDebounceDelay, () {
      if (isClosed) return;

      final currentState = state;
      if (currentState is! ConversationsLoaded) return;

      final conversationId = _findConversationIdForTypingIndicator(
        currentState.conversations,
        typingIndicator,
      );

      if (conversationId == null) return;

      // Add to list of typers (avoid duplicates by user ID)
      final notifier = getTypingNotifier(conversationId);
      final currentTypers = List<TypingIndicator>.from(notifier.value);

      // Remove existing indicator from same user (if any) and add new one
      currentTypers.removeWhere(
        (t) => t.sender.uid == typingIndicator.sender.uid,
      );
      currentTypers.add(typingIndicator);

      notifier.value = currentTypers;
    });
  }

  /// Handle typing ended
  /// OPTIMIZATION: Uses ValueNotifier per conversation - only affected item rebuilds
  void _handleTypingEnded(TypingIndicator typingIndicator) {
    if (state is! ConversationsLoaded) return;
    if (!_userIsNotBlocked(typingIndicator.sender)) return;

    final currentState = state as ConversationsLoaded;

    final conversationId = _findConversationIdForTypingIndicator(
      currentState.conversations,
      typingIndicator,
    );

    if (conversationId == null) return;

    // Remove this user from the list of typers
    final notifier = _typingNotifiers[conversationId];
    if (notifier != null) {
      final currentTypers = List<TypingIndicator>.from(notifier.value);
      currentTypers.removeWhere(
        (t) => t.sender.uid == typingIndicator.sender.uid,
      );
      notifier.value = currentTypers;
    }
  }

  /// Handle messages delivered receipt
  /// OPTIMIZATION: Use batched event queue for rapid receipts
  void _handleMessagesDelivered(MessageReceipt receipt) {
    if (isClosed) return;
    if (!receiptsVisibility) return;
    if (receipt.receiverType != 'user') return;
    _queueEvent(_ReceiptUpdate(receipt));
  }

  /// Handle messages read receipt
  void _handleMessagesRead(MessageReceipt receipt) {
    if (isClosed) return;
    if (!receiptsVisibility) return;
    if (receipt.receiverType != 'user') return;
    _queueEvent(_ReceiptUpdate(receipt));
  }

  /// Handle messages delivered to all (group)
  void _handleMessagesDeliveredToAll(MessageReceipt receipt) {
    if (isClosed) return;
    if (!receiptsVisibility) return;
    if (receipt.receiverType != 'group') return;
    _queueEvent(_ReceiptUpdate(receipt));
  }

  /// Handle messages read by all (group)
  void _handleMessagesReadByAll(MessageReceipt receipt) {
    if (isClosed) return;
    if (!receiptsVisibility) return;
    if (receipt.receiverType != 'group') return;
    _queueEvent(_ReceiptUpdate(receipt));
  }

  /// Handle message edited
  void _handleMessageEdited(BaseMessage message) {
    if (isClosed) return;
    add(_MessageEditedUpdate(message));
  }

  /// Handle message deleted
  void _handleMessageDeleted(BaseMessage message) {
    if (isClosed) return;
    add(_MessageEditedUpdate(message));
  }

  /// Handle user online
  void _handleUserOnline(User user) {
    if (isClosed) return;
    if (!_userIsNotBlocked(user)) return;
    // OPTIMIZATION: Use batched queue for status updates
    _queueEvent(_UserStatusUpdate(user.uid, 'online'));
  }

  /// Handle user offline
  void _handleUserOffline(User user) {
    if (isClosed) return;
    if (!_userIsNotBlocked(user)) return;
    _queueEvent(_UserStatusUpdate(user.uid, 'offline'));
  }

  /// Handle group member joined
  void _handleGroupMemberJoined(
    Action action,
    User joinedUser,
    Group joinedGroup,
  ) {
    if (isClosed) return;
    _refreshSingleConversation(action);
  }

  /// Handle group member left
  void _handleGroupMemberLeft(Action action, User leftUser, Group leftGroup) {
    if (isClosed) return;
    if (_loggedInUser?.uid == leftUser.uid) {
      add(_RemoveGroupConversation(leftGroup.guid));
    } else {
      _refreshSingleConversation(action);
    }
  }

  /// Handle group member kicked
  void _handleGroupMemberKicked(
    Action action,
    User kickedUser,
    User kickedBy,
    Group kickedFrom,
  ) {
    if (isClosed) return;
    if (_loggedInUser?.uid == kickedUser.uid) {
      add(_RemoveGroupConversation(kickedFrom.guid));
    } else {
      _refreshSingleConversation(action);
    }
  }

  /// Handle group member banned
  void _handleGroupMemberBanned(
    Action action,
    User bannedUser,
    User bannedBy,
    Group bannedFrom,
  ) {
    if (isClosed) return;
    if (_loggedInUser?.uid == bannedUser.uid) {
      add(_RemoveGroupConversation(bannedFrom.guid));
    } else {
      _refreshSingleConversation(action);
    }
  }

  /// Handle group member unbanned
  void _handleGroupMemberUnbanned(
    Action action,
    User unbannedUser,
    User unbannedBy,
    Group unbannedFrom,
  ) {
    if (isClosed) return;
    _refreshSingleConversation(action);
  }

  /// Handle group member scope changed
  void _handleGroupMemberScopeChanged(
    Action action,
    User updatedBy,
    User updatedUser,
    String scopeChangedTo,
    String scopeChangedFrom,
    Group group,
  ) {
    if (isClosed) return;
    _refreshSingleConversation(action);
  }

  /// Handle member added to group
  void _handleMemberAddedToGroup(
    Action action,
    User addedBy,
    User userAdded,
    Group addedTo,
  ) {
    if (isClosed) return;
    if (action.actionFor is Group &&
        (action.actionFor as Group).guid == addedTo.guid) {
      final updatedGroup = action.actionFor as Group;
      updatedGroup.hasJoined = true;
      action.actionFor = updatedGroup;

      if (action.receiver is Group &&
          (action.receiver as Group).guid == addedTo.guid) {
        action.receiver = updatedGroup;
      }
    }
    _refreshSingleConversation(action);
  }

  /// Whether calls update the conversations: the app's "call activities"
  /// conversation-update setting from the dashboard, on when it is unknown
  /// (Android's shouldUpdateOnCallActivities). It was fetched and never read.
  static bool get _updateOnCallActivities =>
      CometChatUIKit.conversationUpdateSettings?.callActivities ?? true;

  /// Handle incoming call received
  void _handleIncomingCallReceived(Call call) {
    if (isClosed || !_updateOnCallActivities) return;
    _refreshSingleConversation(call);
  }

  /// Handle outgoing call accepted
  void _handleOutgoingCallAccepted(Call call) {
    if (isClosed || !_updateOnCallActivities) return;
    _refreshSingleConversation(call);
  }

  /// Handle outgoing call rejected
  void _handleOutgoingCallRejected(Call call) {
    if (isClosed || !_updateOnCallActivities) return;
    _refreshSingleConversation(call);
  }

  /// Handle incoming call cancelled
  void _handleIncomingCallCancelled(Call call) {
    if (isClosed || !_updateOnCallActivities) return;
    _refreshSingleConversation(call);
  }

  /// Handle call ended message received
  void _handleCallEndedMessageReceived(Call call) {
    if (isClosed || !_updateOnCallActivities) return;
    _refreshSingleConversation(call);
  }

  /// A call this device placed, accepted, declined or ended (the UI Kit's
  /// call events), as Android's conversations view model hears them.
  void _handleCCCall(Call call) {
    if (isClosed || !_updateOnCallActivities) return;
    _refreshSingleConversation(call);
  }

  /// Handle connected
  void _handleConnected() {
    if (isClosed) return;
    add(const _ConnectionStateUpdate(true));
  }

  /// Handle disconnected
  void _handleDisconnected() {
    if (isClosed) return;
    add(const _ConnectionStateUpdate(false));
  }

  // ============================================================
  // CC UI EVENT LISTENER CALLBACKS
  // ============================================================

  /// Handle CC message sent event
  void _handleCCMessageSent(BaseMessage message, dynamic messageStatus) {
    if (isClosed) return;
    _updateConversationFromMessage(message);
  }

  /// Handle CC message read event
  void _handleCCMessageRead(BaseMessage message) {
    if (isClosed) return;
    if (state is! ConversationsLoaded) return;

    final conversationId = message.conversationId;

    if (conversationId == null || conversationId.isEmpty) return;

    // OPTIMIZATION: Use O(1) lookup
    final matchingIndex = _findConversationIndex(conversationId);
    if (matchingIndex == null || matchingIndex >= items.length) return;

    final conversation = items[matchingIndex];

    // ccMessageRead fires when the LOGGED-IN USER reads an incoming message.
    // This should only reset the unread count — NOT set readAt on the lastMessage.
    // readAt on a BaseMessage means "the recipient read this outgoing message"
    // and is only set via SDK receipt callbacks (onMessagesRead) when the OTHER
    // user reads our message.
    final updatedConversation = conversation.copyWith(unreadMessageCount: 0);
    updateItem(matchingIndex, updatedConversation);
  }

  /// Handle CC message edited event
  void _handleCCMessageEdited(BaseMessage message, dynamic status) {
    if (isClosed) return;
    add(_MessageEditedUpdate(message));
  }

  /// Handle CC message deleted event
  void _handleCCMessageDeleted(BaseMessage message, dynamic messageStatus) {
    if (isClosed) return;
    add(_MessageEditedUpdate(message));
  }

  /// Handle CC group left event
  void _handleCCGroupLeft(Action message, User leftUser, Group leftGroup) {
    if (isClosed) return;
    if (_loggedInUser?.uid == leftUser.uid) {
      add(_RemoveGroupConversation(leftGroup.guid));
    }
  }

  /// Handle CC group deleted event
  void _handleCCGroupDeleted(Group group) {
    if (isClosed) return;
    add(_RemoveGroupConversation(group.guid));
  }

  /// Handle CC group member added event
  void _handleCCGroupMemberAdded(
    List<Action> messages,
    List<User> usersAdded,
    Group groupAddedIn,
    User addedBy,
  ) {
    if (isClosed) return;
    if (messages.isNotEmpty) {
      _refreshSingleConversation(messages.first);
    }
  }

  /// Handle CC group member kicked event
  void _handleCCGroupMemberKicked(
    Action message,
    User kickedUser,
    User kickedBy,
    Group kickedFrom,
  ) {
    if (isClosed) return;
    if (_loggedInUser?.uid == kickedUser.uid) {
      add(_RemoveGroupConversation(kickedFrom.guid));
    } else {
      _refreshSingleConversation(message);
    }
  }

  /// Handle CC group member banned event
  void _handleCCGroupMemberBanned(
    Action message,
    User bannedUser,
    User bannedBy,
    Group bannedFrom,
  ) {
    if (isClosed) return;
    if (_loggedInUser?.uid == bannedUser.uid) {
      add(_RemoveGroupConversation(bannedFrom.guid));
    } else {
      _refreshSingleConversation(message);
    }
  }

  /// Handle CC ownership changed event
  void _handleCCOwnershipChanged(Group group, GroupMember newOwner) {
    if (isClosed) return;
    add(_GroupUpdate(group));
  }

  /// Handle CC conversation deleted event
  void _handleCCConversationDeleted(Conversation conversation) {
    if (isClosed) return;
    final conversationId = conversation.conversationId;
    if (conversationId != null && conversationId.isNotEmpty) {
      add(RemoveConversation(conversationId));
    }
  }

  /// Handle CC conversation updated event (e.g. mark as unread)
  void _handleCCConversationUpdated(Conversation conversation) {
    if (isClosed) return;
    add(_ConversationUnreadUpdate(conversation));
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Refresh a single conversation from a message/action
  Future<void> _refreshSingleConversation(BaseMessage message) async {
    if (state is! ConversationsLoaded) return;

    final conversationWith = message.receiverType == 'user'
        ? (message.sender?.uid == _loggedInUser?.uid
              ? message.receiverUid
              : message.sender?.uid)
        : message.receiverUid;

    if (conversationWith == null) return;

    final result = await getConversationUseCase(
      conversationWith: conversationWith,
      conversationType: message.receiverType,
    );

    if (result is Success<Conversation>) {
      final updatedConversation = result.data.copyWith(
        lastMessage: message,
        updatedAt: message.updatedAt ?? message.sentAt,
      );

      add(_MessageReceivedUpdate(updatedConversation));
    }
  }

  /// Find the conversation ID that matches the typing indicator
  String? _findConversationIdForTypingIndicator(
    List<Conversation> conversations,
    TypingIndicator typingIndicator,
  ) {
    final senderUid = typingIndicator.sender.uid;
    final receiverId = typingIndicator.receiverId;
    final receiverType = typingIndicator.receiverType;

    for (final conversation in conversations) {
      if (receiverType == 'user') {
        if (conversation.conversationType == 'user') {
          final conversationWith = conversation.conversationWith;
          if (conversationWith is User && conversationWith.uid == senderUid) {
            return conversation.conversationId;
          }
        }
      } else if (receiverType == 'group') {
        if (conversation.conversationType == 'group') {
          final conversationWith = conversation.conversationWith;
          if (conversationWith is Group &&
              conversationWith.guid == receiverId) {
            return conversation.conversationId;
          }
        }
      }
    }
    return null;
  }

  /// Check if user is not blocked
  bool _userIsNotBlocked(User user) {
    return user.blockedByMe != true && user.hasBlockedMe != true;
  }

  /// Find the conversation ID that matches the receipt.
  /// For user receipts: match by sender UID against conversationWith.
  /// For group receipts: match by receiverId (group GUID) against conversationWith.
  String? _findConversationIdForReceipt(
    List<Conversation> conversations,
    MessageReceipt receipt,
  ) {
    final senderUid = receipt.sender.uid;
    final receiverId = receipt.receiverId;
    final receiverType = receipt.receiverType;

    for (final conversation in conversations) {
      if (receiverType == 'user') {
        if (conversation.conversationType == 'user') {
          final conversationWith = conversation.conversationWith;
          if (conversationWith is User && conversationWith.uid == senderUid) {
            return conversation.conversationId;
          }
        }
      } else if (receiverType == 'group') {
        if (conversation.conversationType == 'group') {
          final conversationWith = conversation.conversationWith;
          if (conversationWith is Group &&
              conversationWith.guid == receiverId) {
            return conversation.conversationId;
          }
        }
      }
    }
    return null;
  }

  // ============================================================
  // LIST BASE HOOK OVERRIDES (with incremental map updates)
  // ============================================================

  /// Called when a conversation is added to the list.
  @override
  void onItemAdded(Conversation item, List<Conversation> updatedList) {
    // OPTIMIZATION: Incremental map update - item added at end
    final newIndex = updatedList.length - 1;
    _addToIndexMap(item.conversationId, newIndex);

    if (!isClosed) {
      add(_ListItemAdded(updatedList));
    }
  }

  /// Called when a conversation is removed from the list.
  @override
  void onItemRemoved(Conversation item, List<Conversation> updatedList) {
    // Get the index BEFORE removing from map (map still has old index)
    final removedIndex = _conversationIndexMap[item.conversationId];

    // Remove from map
    _removeFromIndexMap(item.conversationId);

    // Shift indices for items that were after the removed item
    if (removedIndex != null) {
      _shiftIndicesAfterRemoval(removedIndex);
    }

    if (!isClosed) {
      add(_ListItemRemoved(updatedList));
    }
  }

  /// Called when a conversation is updated in the list.
  @override
  void onItemUpdated(
    Conversation oldItem,
    Conversation newItem,
    List<Conversation> updatedList,
  ) {
    // OPTIMIZATION: No map update needed - index unchanged, ID unchanged
    // Only update map if conversationId changed (rare edge case)
    if (oldItem.conversationId != newItem.conversationId) {
      final index = _findConversationIndex(oldItem.conversationId);
      _removeFromIndexMap(oldItem.conversationId);
      if (index != null) {
        _addToIndexMap(newItem.conversationId, index);
      }
    }

    if (!isClosed) {
      add(_ListItemUpdated(updatedList));
    }
  }

  /// Called when the conversations list is cleared.
  @override
  void onListCleared(List<Conversation> previousList) {
    _conversationIndexMap.clear();
    _mapNeedsRebuild = true;
    if (!isClosed) {
      add(const _ListCleared());
    }
  }

  /// Called when the entire conversations list is replaced.
  /// This is the only case where full rebuild is necessary.
  @override
  void onListReplaced(
    List<Conversation> previousList,
    List<Conversation> newList,
  ) {
    if (isClosed) return;

    // Full rebuild only on list replacement (initial load, refresh, reorder)
    // This is O(n) but only happens on major list changes, not individual updates
    _rebuildIndexMap();

    add(_ListReplaced(newList));
  }

  // ============================================================
  // LIST BASE EVENT HANDLERS
  // ============================================================

  void _onListItemAdded(
    _ListItemAdded event,
    Emitter<ConversationsState> emit,
  ) {
    if (state is ConversationsLoaded) {
      emit(
        (state as ConversationsLoaded).copyWith(
          conversations: event.updatedList,
        ),
      );
    }
  }

  void _onListItemRemoved(
    _ListItemRemoved event,
    Emitter<ConversationsState> emit,
  ) {
    if (event.updatedList.isEmpty) {
      _mapNeedsRebuild = true;
      emit(const ConversationsEmpty());
    } else if (state is ConversationsLoaded) {
      emit(
        (state as ConversationsLoaded).copyWith(
          conversations: event.updatedList,
        ),
      );
    }
  }

  void _onListItemUpdated(
    _ListItemUpdated event,
    Emitter<ConversationsState> emit,
  ) {
    if (state is ConversationsLoaded) {
      emit(
        (state as ConversationsLoaded).copyWith(
          conversations: event.updatedList,
        ),
      );
    }
  }

  void _onListCleared(_ListCleared event, Emitter<ConversationsState> emit) {
    emit(const ConversationsEmpty());
  }

  void _onListReplaced(_ListReplaced event, Emitter<ConversationsState> emit) {
    if (event.newList.isEmpty) {
      emit(const ConversationsEmpty());
    } else if (state is ConversationsLoaded) {
      emit(
        (state as ConversationsLoaded).copyWith(conversations: event.newList),
      );
    } else {
      emit(
        ConversationsLoaded(
          conversations: event.newList,
          hasMore: event.newList.length >= _pageSize,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    // Cancel timers
    _typingDebounceTimer?.cancel();
    _batchEmitTimer?.cancel();
    _pendingEvents.clear();
    _conversationIndexMap.clear();

    // Dispose typing notifiers
    for (final notifier in _typingNotifiers.values) {
      notifier.dispose();
    }
    _typingNotifiers.clear();

    // Remove SDK listeners
    CometChat.removeMessageListener(_messageListenerKey);
    if (usersStatusVisibility) {
      CometChat.removeUserListener(_userListenerKey);
    }
    CometChat.removeGroupListener(_groupListenerKey);
    ChatSdkListeners.removeCallListener(_callListenerKey);
    CometChat.removeConnectionListener(_connectionListenerKey);
    CometChat.removeConversationListener(_conversationListenerKey);

    // Remove CC UI Event listeners
    CometChatMessageEvents.removeMessagesListener(_ccMessageListenerKey);
    CometChatGroupEvents.removeGroupsListener(_ccGroupListenerKey);
    CometChatConversationEvents.removeConversationListListener(
      _ccConversationListenerKey,
    );
    CometChatCallEvents.removeCallEventsListener(_ccCallListenerKey);

    _isLoadingMore = false;
    return super.close();
  }
}

// ============================================================
// INTERNAL EVENTS
// ============================================================

/// Internal event for message received updates
/// Pin Conversation: a pin/unpin landed for the logged-in user (own action
/// on this or another device, or an admin pin). Carries the server's updated
/// conversation; the handler reorders the list around the pinned block.
class _ConversationPinUpdate extends ConversationsEvent {
  final Conversation conversation;
  final bool pinned;

  const _ConversationPinUpdate(this.conversation, {required this.pinned});

  @override
  List<Object?> get props => [conversation, pinned];
}

class _MessageReceivedUpdate extends ConversationsEvent {
  final Conversation conversation;

  const _MessageReceivedUpdate(this.conversation);

  @override
  List<Object> get props => [conversation, conversation.conversationId ?? ''];
}

/// Internal event for updating unread count in-place (no move to top)
class _ConversationUnreadUpdate extends ConversationsEvent {
  final Conversation conversation;

  const _ConversationUnreadUpdate(this.conversation);

  @override
  List<Object> get props => [conversation, conversation.conversationId ?? ''];
}

/// Internal event for user status updates
class _UserStatusUpdate extends ConversationsEvent {
  final String userId;
  final String status;

  const _UserStatusUpdate(this.userId, this.status);

  @override
  List<Object> get props => [userId, status];
}

/// Internal event for receipt updates
class _ReceiptUpdate extends ConversationsEvent {
  final MessageReceipt receipt;

  const _ReceiptUpdate(this.receipt);

  @override
  List<Object> get props => [receipt];
}

/// Internal event for message edited updates
class _MessageEditedUpdate extends ConversationsEvent {
  final BaseMessage message;

  const _MessageEditedUpdate(this.message);

  @override
  List<Object> get props => [message];
}

/// Internal event for group updates
class _GroupUpdate extends ConversationsEvent {
  final Group group;

  const _GroupUpdate(this.group);

  @override
  List<Object> get props => [group];
}

/// Internal event for removing group conversation
class _RemoveGroupConversation extends ConversationsEvent {
  final String groupId;

  const _RemoveGroupConversation(this.groupId);

  @override
  List<Object> get props => [groupId];
}

/// Internal event for connection state updates
class _ConnectionStateUpdate extends ConversationsEvent {
  final bool isConnected;

  const _ConnectionStateUpdate(this.isConnected);

  @override
  List<Object> get props => [isConnected];
}

/// Internal event for list item added via ListBase hook
class _ListItemAdded extends ConversationsEvent {
  final List<Conversation> updatedList;

  const _ListItemAdded(this.updatedList);

  @override
  List<Object> get props => [updatedList];
}

/// Internal event for list item removed via ListBase hook
class _ListItemRemoved extends ConversationsEvent {
  final List<Conversation> updatedList;

  const _ListItemRemoved(this.updatedList);

  @override
  List<Object> get props => [updatedList];
}

/// Internal event for list item updated via ListBase hook
class _ListItemUpdated extends ConversationsEvent {
  final List<Conversation> updatedList;

  const _ListItemUpdated(this.updatedList);

  @override
  List<Object> get props => [updatedList];
}

/// Internal event for list cleared via ListBase hook
class _ListCleared extends ConversationsEvent {
  const _ListCleared();

  @override
  List<Object> get props => [];
}

/// Internal event for list replaced via ListBase hook
class _ListReplaced extends ConversationsEvent {
  final List<Conversation> newList;

  const _ListReplaced(this.newList);

  @override
  List<Object> get props => [newList];
}

// ============================================================
// SDK LISTENERS
// ============================================================

/// Message listener for real-time conversation updates
class _ConversationMessageListener with MessageListener {
  final void Function(BaseMessage) onMessageReceivedCallback;
  final void Function(TypingIndicator) onTypingStartedCallback;
  final void Function(TypingIndicator) onTypingEndedCallback;
  final void Function(MessageReceipt) onMessagesDeliveredCallback;
  final void Function(MessageReceipt) onMessagesReadCallback;
  final void Function(MessageReceipt) onMessagesDeliveredToAllCallback;
  final void Function(MessageReceipt) onMessagesReadByAllCallback;
  final void Function(BaseMessage) onMessageEditedCallback;
  final void Function(BaseMessage) onMessageDeletedCallback;

  _ConversationMessageListener({
    required this.onMessageReceivedCallback,
    required this.onTypingStartedCallback,
    required this.onTypingEndedCallback,
    required this.onMessagesDeliveredCallback,
    required this.onMessagesReadCallback,
    required this.onMessagesDeliveredToAllCallback,
    required this.onMessagesReadByAllCallback,
    required this.onMessageEditedCallback,
    required this.onMessageDeletedCallback,
  });

  @override
  void onTextMessageReceived(TextMessage textMessage) {
    onMessageReceivedCallback(textMessage);
  }

  @override
  void onMediaMessageReceived(MediaMessage mediaMessage) {
    onMessageReceivedCallback(mediaMessage);
  }

  @override
  void onCustomMessageReceived(CustomMessage customMessage) {
    onMessageReceivedCallback(customMessage);
  }

  @override
  void onInteractiveMessageReceived(InteractiveMessage interactiveMessage) {
    onMessageReceivedCallback(interactiveMessage);
  }

  @override
  void onAIAssistantMessageReceived(AIAssistantMessage aiAssistantMessage) {
    // Agent (agentic/assistant) reply — update the conversation's last message
    // and unread count in real time, like any other incoming message.
    // Otherwise the subtitle only refreshes after a re-fetch.
    onMessageReceivedCallback(aiAssistantMessage);
  }

  @override
  void onCardMessageReceived(CardMessage cardMessage) {
    // Developer card (category "card") — update the conversation's last message
    // and unread count in real time, like any other incoming message.
    // The SDK dispatches cards on a dedicated callback, so without this override
    // the list only refreshes after a re-fetch.
    onMessageReceivedCallback(cardMessage);
  }

  @override
  void onTypingStarted(TypingIndicator typingIndicator) {
    onTypingStartedCallback(typingIndicator);
  }

  @override
  void onTypingEnded(TypingIndicator typingIndicator) {
    onTypingEndedCallback(typingIndicator);
  }

  @override
  void onMessagesDelivered(MessageReceipt messageReceipt) {
    onMessagesDeliveredCallback(messageReceipt);
  }

  @override
  void onMessagesRead(MessageReceipt messageReceipt) {
    onMessagesReadCallback(messageReceipt);
  }

  @override
  void onMessagesDeliveredToAll(MessageReceipt messageReceipt) {
    onMessagesDeliveredToAllCallback(messageReceipt);
  }

  @override
  void onMessagesReadByAll(MessageReceipt messageReceipt) {
    onMessagesReadByAllCallback(messageReceipt);
  }

  @override
  void onMessageEdited(BaseMessage message) {
    onMessageEditedCallback(message);
  }

  @override
  void onMessageDeleted(BaseMessage message) {
    onMessageDeletedCallback(message);
  }

  @override
  void onMessageModerated(BaseMessage message) {
    // Moderation state change on a message — route through the edit callback
    // so the conversation's `lastMessage` picks up the new `moderationStatus`.
    // The conversation list row will then render the red error icon in place
    // of the sent/delivered tick via ModerationCheckUtil.
    onMessageEditedCallback(message);
  }
}

/// User listener for presence updates
class _ConversationUserListener with UserListener {
  final void Function(User) onUserOnlineCallback;
  final void Function(User) onUserOfflineCallback;

  _ConversationUserListener({
    required this.onUserOnlineCallback,
    required this.onUserOfflineCallback,
  });

  @override
  void onUserOnline(User user) {
    onUserOnlineCallback(user);
  }

  @override
  void onUserOffline(User user) {
    onUserOfflineCallback(user);
  }
}

/// Group listener for group events
class _ConversationGroupListener with GroupListener {
  final void Function(Action, User, Group) onGroupMemberJoinedCallback;
  final void Function(Action, User, Group) onGroupMemberLeftCallback;
  final void Function(Action, User, User, Group) onGroupMemberKickedCallback;
  final void Function(Action, User, User, Group) onGroupMemberBannedCallback;
  final void Function(Action, User, User, Group) onGroupMemberUnbannedCallback;
  final void Function(Action, User, User, String, String, Group)
  onGroupMemberScopeChangedCallback;
  final void Function(Action, User, User, Group) onMemberAddedToGroupCallback;
  final String? loggedInUserId;

  _ConversationGroupListener({
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

/// Call listener for call events
class _ConversationCallListener with CallListener {
  final void Function(Call) onIncomingCallReceivedCallback;
  final void Function(Call) onOutgoingCallAcceptedCallback;
  final void Function(Call) onOutgoingCallRejectedCallback;
  final void Function(Call) onIncomingCallCancelledCallback;
  final void Function(Call) onCallEndedMessageReceivedCallback;

  _ConversationCallListener({
    required this.onIncomingCallReceivedCallback,
    required this.onOutgoingCallAcceptedCallback,
    required this.onOutgoingCallRejectedCallback,
    required this.onIncomingCallCancelledCallback,
    required this.onCallEndedMessageReceivedCallback,
  });

  @override
  void onIncomingCallReceived(Call call) {
    onIncomingCallReceivedCallback(call);
  }

  @override
  void onOutgoingCallAccepted(Call call) {
    onOutgoingCallAcceptedCallback(call);
  }

  @override
  void onOutgoingCallRejected(Call call) {
    onOutgoingCallRejectedCallback(call);
  }

  @override
  void onIncomingCallCancelled(Call call) {
    onIncomingCallCancelledCallback(call);
  }

  @override
  void onCallEndedMessageReceived(Call call) {
    onCallEndedMessageReceivedCallback(call);
  }
}

/// The UI Kit's call events, for this device's own calls.
class _ConversationCallEventsListener with CometChatCallEventListener {
  final void Function(Call) onCallCallback;

  _ConversationCallEventsListener({required this.onCallCallback});

  @override
  void ccOutgoingCall(Call call) => onCallCallback(call);

  @override
  void ccCallAccepted(Call call) => onCallCallback(call);

  @override
  void ccCallRejected(Call call) => onCallCallback(call);

  @override
  void ccCallEnded(Call call) => onCallCallback(call);
}

/// Connection listener for connection state
class _ConversationConnectionListener with ConnectionListener {
  final void Function() onConnectedCallback;
  final void Function() onDisconnectedCallback;

  _ConversationConnectionListener({
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

/// CC Message event listener for UI-triggered message events
class _CCMessageEventListener with CometChatMessageEventListener {
  final void Function(BaseMessage, dynamic) onCCMessageSentCallback;
  final void Function(BaseMessage) onCCMessageReadCallback;
  final void Function(BaseMessage, dynamic) onCCMessageEditedCallback;
  final void Function(BaseMessage, dynamic) onCCMessageDeletedCallback;
  final void Function(MessageReceipt) onMessagesDeliveredCallback;
  final void Function(MessageReceipt) onMessagesReadCallback;
  final void Function(MessageReceipt) onMessagesDeliveredToAllCallback;
  final void Function(MessageReceipt) onMessagesReadByAllCallback;

  _CCMessageEventListener({
    required this.onCCMessageSentCallback,
    required this.onCCMessageReadCallback,
    required this.onCCMessageEditedCallback,
    required this.onCCMessageDeletedCallback,
    required this.onMessagesDeliveredCallback,
    required this.onMessagesReadCallback,
    required this.onMessagesDeliveredToAllCallback,
    required this.onMessagesReadByAllCallback,
  });

  @override
  void ccMessageSent(BaseMessage message, dynamic messageStatus) {
    onCCMessageSentCallback(message, messageStatus);
  }

  @override
  void ccMessageRead(BaseMessage message) {
    onCCMessageReadCallback(message);
  }

  @override
  void ccMessageEdited(BaseMessage message, dynamic status) {
    onCCMessageEditedCallback(message, status);
  }

  @override
  void ccMessageDeleted(BaseMessage message, dynamic messageStatus) {
    onCCMessageDeletedCallback(message, messageStatus);
  }

  @override
  void onMessagesDelivered(MessageReceipt messageReceipt) {
    onMessagesDeliveredCallback(messageReceipt);
  }

  @override
  void onMessagesRead(MessageReceipt messageReceipt) {
    onMessagesReadCallback(messageReceipt);
  }

  @override
  void onMessagesDeliveredToAll(MessageReceipt messageReceipt) {
    onMessagesDeliveredToAllCallback(messageReceipt);
  }

  @override
  void onMessagesReadByAll(MessageReceipt messageReceipt) {
    onMessagesReadByAllCallback(messageReceipt);
  }
}

/// CC Group event listener for UI-triggered group events
class _CCGroupEventListener with CometChatGroupEventListener {
  final void Function(Action, User, Group) onCCGroupLeftCallback;
  final void Function(Group) onCCGroupDeletedCallback;
  final void Function(List<Action>, List<User>, Group, User)
  onCCGroupMemberAddedCallback;
  final void Function(Action, User, User, Group) onCCGroupMemberKickedCallback;
  final void Function(Action, User, User, Group) onCCGroupMemberBannedCallback;
  final void Function(Group, GroupMember) onCCOwnershipChangedCallback;

  _CCGroupEventListener({
    required this.onCCGroupLeftCallback,
    required this.onCCGroupDeletedCallback,
    required this.onCCGroupMemberAddedCallback,
    required this.onCCGroupMemberKickedCallback,
    required this.onCCGroupMemberBannedCallback,
    required this.onCCOwnershipChangedCallback,
  });

  @override
  void ccGroupLeft(Action message, User leftUser, Group leftGroup) {
    onCCGroupLeftCallback(message, leftUser, leftGroup);
  }

  @override
  void ccGroupDeleted(Group group) {
    onCCGroupDeletedCallback(group);
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
  void ccOwnershipChanged(Group group, GroupMember newOwner) {
    onCCOwnershipChangedCallback(group, newOwner);
  }
}

/// CC Conversation event listener for UI-triggered conversation events
class _CCConversationEventListener with CometChatConversationEventListener {
  final void Function(Conversation) onCCConversationDeletedCallback;
  final void Function(Conversation)? onCCConversationUpdatedCallback;

  _CCConversationEventListener({
    required this.onCCConversationDeletedCallback,
    this.onCCConversationUpdatedCallback,
  });

  @override
  void ccConversationDeleted(Conversation conversation) {
    onCCConversationDeletedCallback(conversation);
  }

  @override
  void ccUpdateConversation(Conversation conversation) {
    onCCConversationUpdatedCallback?.call(conversation);
  }
}

/// SDK ConversationListener adapter (Pin Conversation).
class _ConversationPinListener with ConversationListener {
  _ConversationPinListener({
    required this.onPinnedCallback,
    required this.onUnpinnedCallback,
  });

  final void Function(Conversation conversation) onPinnedCallback;
  final void Function(Conversation conversation) onUnpinnedCallback;

  @override
  void onConversationPinned(Conversation conversation) =>
      onPinnedCallback(conversation);

  @override
  void onConversationUnpinned(Conversation conversation) =>
      onUnpinnedCallback(conversation);
}
