import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../shared_ui/cometchat_uikit_shared.dart';
import '../../shared/list_base.dart';
import '../di/ai_assistant_chat_history_service_locator.dart';
import '../domain/usecases/usecases.dart';
import 'ai_assistant_chat_history_event.dart';
import 'ai_assistant_chat_history_state.dart';
import '../../../../shared_ui/src/logging/cometchat_log.dart';

/// BLoC for managing AI Assistant Chat History.
///
/// Handles:
/// - Loading and pagination of AI conversation messages
/// - Real-time updates via SDK listeners (message received, edited, deleted)
/// - Message deletion with confirmation
/// - Connection state (reconnect → sync)
///
/// Uses [ListBase] mixin for list management operations.
class AIAssistantChatHistoryBloc
    extends Bloc<AIAssistantChatHistoryEvent, AIAssistantChatHistoryState>
    with ListBase<BaseMessage> {
  // Use cases
  final FetchChatHistoryUseCase fetchChatHistoryUseCase;
  final DeleteChatHistoryMessageUseCase deleteChatHistoryMessageUseCase;
  final GetLoggedInUserUseCase getLoggedInUserUseCase;

  // Configuration
  final User? user;
  final Group? group;
  final MessagesRequestBuilder? messagesRequestBuilder;

  // Internal state
  late MessagesRequest _messagesRequest;
  User? _loggedInUser;

  // O(1) message lookup by ID
  final Map<int, int> _messageIndexMap = {};
  bool _mapNeedsRebuild = true;

  // SDK listener IDs
  final String _messageListenerId =
      'ai_chat_history_msg_${DateTime.now().millisecondsSinceEpoch}';
  final String _connectionListenerId =
      'ai_chat_history_conn_${DateTime.now().millisecondsSinceEpoch}';

  // CC UI Event listener IDs
  final String _ccMessageListenerId =
      'ai_chat_history_cc_msg_${DateTime.now().millisecondsSinceEpoch}';

  /// Sticky date notifier for scroll-based date header.
  final ValueNotifier<DateTime?> stickyDateNotifier = ValueNotifier<DateTime?>(
    null,
  );

  /// Custom date string for sticky header (from dateSeparatorPattern).
  String? stickyDateString;

  /// Helper to get initialized service locator.
  static AIAssistantChatHistoryServiceLocator _getServiceLocator() {
    if (!AIAssistantChatHistoryServiceLocator.instance.isInitialized) {
      AIAssistantChatHistoryServiceLocator.instance.setup();
    }
    return AIAssistantChatHistoryServiceLocator.instance;
  }

  AIAssistantChatHistoryBloc({
    FetchChatHistoryUseCase? fetchChatHistoryUseCase,
    DeleteChatHistoryMessageUseCase? deleteChatHistoryMessageUseCase,
    GetLoggedInUserUseCase? getLoggedInUserUseCase,
    this.user,
    this.group,
    this.messagesRequestBuilder,
  }) : fetchChatHistoryUseCase =
           fetchChatHistoryUseCase ??
           _getServiceLocator().fetchChatHistoryUseCase,
       deleteChatHistoryMessageUseCase =
           deleteChatHistoryMessageUseCase ??
           _getServiceLocator().deleteChatHistoryMessageUseCase,
       getLoggedInUserUseCase =
           getLoggedInUserUseCase ??
           _getServiceLocator().getLoggedInUserUseCase,
       assert(
         user != null || group != null,
         'One of user or group must be provided',
       ),
       assert(
         user == null || group == null,
         'Only one of user or group should be provided',
       ),
       super(AIAssistantChatHistoryState()) {
    // Build the messages request
    _messagesRequest = _buildMessagesRequest();

    // Register event handlers
    on<LoadChatHistory>(_onLoadChatHistory);
    on<LoadMoreChatHistory>(_onLoadMoreChatHistory);
    on<DeleteChatHistoryMessage>(_onDeleteMessage);
    on<ChatHistoryMessageReceived>(_onMessageReceived);
    on<ChatHistoryMessageEdited>(_onMessageEdited);
    on<ChatHistoryMessageDeleted>(_onMessageDeleted);
    on<ChatHistoryReconnected>(_onReconnected);

    // Register SDK listeners
    _registerListeners();
  }

  // ============================================================
  // REQUEST BUILDER
  // ============================================================

  MessagesRequest _buildMessagesRequest() {
    final builder = messagesRequestBuilder ?? MessagesRequestBuilder();

    // Set default types/categories if not provided
    if (messagesRequestBuilder == null) {
      builder.types = MessageTemplateUtils.getAllMessageTypes();
      builder.categories = MessageTemplateUtils.getAllMessageCategories();
      builder.hideReplies ??= true;
    }

    // Set conversation target
    if (user != null) {
      builder.uid = user!.uid;
    } else {
      builder.guid = group!.guid;
    }

    return builder.build();
  }

  // ============================================================
  // O(1) LOOKUP HELPERS
  // ============================================================

  void _rebuildIndexMap() {
    _messageIndexMap.clear();
    for (int i = 0; i < items.length; i++) {
      _messageIndexMap[items[i].id] = i;
    }
    _mapNeedsRebuild = false;
  }

  /// O(1) lookup for message index by ID.
  int findMessageIndex(int messageId) {
    if (_mapNeedsRebuild) _rebuildIndexMap();
    return _messageIndexMap[messageId] ?? -1;
  }

  // ============================================================
  // EVENT HANDLERS
  // ============================================================

  Future<void> _onLoadChatHistory(
    LoadChatHistory event,
    Emitter<AIAssistantChatHistoryState> emit,
  ) async {
    emit(state.copyWith(status: AIAssistantChatHistoryStatus.loading));

    // Get logged in user
    final userResult = await getLoggedInUserUseCase();
    userResult.onSuccess((u) => _loggedInUser = u);

    // Rebuild request for fresh load
    _messagesRequest = _buildMessagesRequest();

    final result = await fetchChatHistoryUseCase(_messagesRequest);

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: AIAssistantChatHistoryStatus.error,
            errorMessage: failure.message,
          ),
        );
      },
      (messages) {
        if (messages.isEmpty) {
          emit(
            state.copyWith(
              status: AIAssistantChatHistoryStatus.empty,
              messages: [],
              hasMore: false,
              loggedInUser: _loggedInUser,
            ),
          );
        } else {
          // Reverse to show recent messages first
          final reversed = messages.reversed.toList();
          clearItems();
          addAllItems(reversed);
          _mapNeedsRebuild = true;
          emit(
            state.copyWith(
              status: AIAssistantChatHistoryStatus.loaded,
              messages: items,
              hasMore: messages.isNotEmpty,
              loggedInUser: _loggedInUser,
            ),
          );
        }
      },
    );
  }

  Future<void> _onLoadMoreChatHistory(
    LoadMoreChatHistory event,
    Emitter<AIAssistantChatHistoryState> emit,
  ) async {
    if (state.isLoadingMore || !state.hasMore) return;

    emit(state.copyWith(isLoadingMore: true));

    final result = await fetchChatHistoryUseCase(_messagesRequest);

    result.fold(
      (failure) {
        emit(
          state.copyWith(isLoadingMore: false, errorMessage: failure.message),
        );
      },
      (messages) {
        if (messages.isEmpty) {
          emit(state.copyWith(isLoadingMore: false, hasMore: false));
        } else {
          addAllItems(messages);
          _mapNeedsRebuild = true;
          emit(
            state.copyWith(
              messages: items,
              isLoadingMore: false,
              hasMore: true,
            ),
          );
        }
      },
    );
  }

  Future<void> _onDeleteMessage(
    DeleteChatHistoryMessage event,
    Emitter<AIAssistantChatHistoryState> emit,
  ) async {
    final result = await deleteChatHistoryMessageUseCase(event.message.id);

    result.fold(
      (failure) {
        // Deletion failed — no state change needed, caller can show error
        if (kDebugMode) {
          ccLog('AIAssistantChatHistory: delete failed: ${failure.message}');
        }
      },
      (updatedMessage) {
        // Mark as deleted in list
        updatedMessage.deletedAt ??= DateTime.now();
        final index = findMessageIndex(event.message.id);
        if (index != -1) {
          updateItem(index, updatedMessage);
          _mapNeedsRebuild = true;
          emit(state.copyWith(messages: items));
        }

        // Notify UI event system
        CometChatMessageEvents.ccMessageDeleted(
          updatedMessage,
          EventStatus.success,
        );
      },
    );
  }

  void _onMessageReceived(
    ChatHistoryMessageReceived event,
    Emitter<AIAssistantChatHistoryState> emit,
  ) {
    if (!_isForThisConversation(event.message)) return;

    addItem(event.message);
    _mapNeedsRebuild = true;
    emit(
      state.copyWith(
        status: AIAssistantChatHistoryStatus.loaded,
        messages: items,
      ),
    );
  }

  void _onMessageEdited(
    ChatHistoryMessageEdited event,
    Emitter<AIAssistantChatHistoryState> emit,
  ) {
    if (!_isForThisConversation(event.message)) return;

    final index = findMessageIndex(event.message.id);
    if (index != -1) {
      updateItem(index, event.message);
      _mapNeedsRebuild = true;
      emit(state.copyWith(messages: items));
    }
  }

  void _onMessageDeleted(
    ChatHistoryMessageDeleted event,
    Emitter<AIAssistantChatHistoryState> emit,
  ) {
    if (!_isForThisConversation(event.message)) return;

    final index = findMessageIndex(event.message.id);
    if (index != -1) {
      updateItem(index, event.message);
      _mapNeedsRebuild = true;
      emit(state.copyWith(messages: items));
    }
  }

  Future<void> _onReconnected(
    ChatHistoryReconnected event,
    Emitter<AIAssistantChatHistoryState> emit,
  ) async {
    // Reload from scratch on reconnect
    add(const LoadChatHistory());
  }

  // ============================================================
  // CONVERSATION MATCHING
  // ============================================================

  bool _isForThisConversation(BaseMessage message) {
    if (message.receiverType == CometChatReceiverType.user) {
      return user?.uid == message.sender?.uid ||
          user?.uid == message.receiverUid;
    } else if (message.receiverType == CometChatReceiverType.group) {
      return group?.guid == message.receiverUid;
    }
    return false;
  }

  // ============================================================
  // SDK LISTENERS
  // ============================================================

  void _registerListeners() {
    // Message listeners
    CometChat.addMessageListener(
      _messageListenerId,
      _AIAssistantMessageListener(this),
    );

    // Connection listener
    CometChat.addConnectionListener(
      _connectionListenerId,
      _AIAssistantConnectionListener(this),
    );

    // CC UI Event listeners
    CometChatMessageEvents.addMessagesListener(
      _ccMessageListenerId,
      _AIAssistantCCMessageListener(this),
    );
  }

  void _removeListeners() {
    CometChat.removeMessageListener(_messageListenerId);
    CometChat.removeConnectionListener(_connectionListenerId);
    CometChatMessageEvents.removeMessagesListener(_ccMessageListenerId);
  }

  @override
  Future<void> close() {
    _removeListeners();
    stickyDateNotifier.dispose();
    return super.close();
  }
}

// ============================================================
// SDK MESSAGE LISTENER
// ============================================================

class _AIAssistantMessageListener with MessageListener {
  final AIAssistantChatHistoryBloc bloc;

  _AIAssistantMessageListener(this.bloc);

  @override
  void onTextMessageReceived(TextMessage textMessage) {
    bloc.add(ChatHistoryMessageReceived(textMessage));
  }

  @override
  void onMessageEdited(BaseMessage editedMessage) {
    bloc.add(ChatHistoryMessageEdited(editedMessage));
  }

  @override
  void onMessageDeleted(BaseMessage deletedMessage) {
    bloc.add(ChatHistoryMessageDeleted(deletedMessage));
  }
}

// ============================================================
// SDK CONNECTION LISTENER
// ============================================================

class _AIAssistantConnectionListener with ConnectionListener {
  final AIAssistantChatHistoryBloc bloc;

  _AIAssistantConnectionListener(this.bloc);

  @override
  void onConnected() {
    bloc.add(const ChatHistoryReconnected());
  }

  @override
  void onDisconnected() {}
}

// ============================================================
// CC UI MESSAGE EVENT LISTENER
// ============================================================

class _AIAssistantCCMessageListener with CometChatMessageEventListener {
  final AIAssistantChatHistoryBloc bloc;

  _AIAssistantCCMessageListener(this.bloc);

  @override
  void ccMessageEdited(BaseMessage message, MessageEditStatus status) {
    if (status == MessageEditStatus.success) {
      bloc.add(ChatHistoryMessageEdited(message));
    }
  }

  @override
  void ccMessageDeleted(BaseMessage message, EventStatus messageStatus) {
    if (messageStatus == EventStatus.success) {
      bloc.add(ChatHistoryMessageDeleted(message));
    }
  }
}
