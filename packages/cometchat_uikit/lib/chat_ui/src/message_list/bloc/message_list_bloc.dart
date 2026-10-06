import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart'
    show
        CometChatMessageEvents,
        CometChatMessageEventListener,
        CometChatGroupEvents,
        CometChatGroupEventListener,
        CometChatCallEvents,
        CometChatCallEventListener,
        CometChatUIKitHelper,
        CometChatUIKit,
        CometChatUIEvents,
        ExtensionType,
        AIConstants,
        StreamMessage,
        CometChatStreamService,
        CometChatStreamCallBackEvents,
        Sound;

import 'message_list_event.dart';
import 'message_list_state.dart';
import '../utils/message_operation.dart';
import '../di/message_list_service_locator.dart';
import '../domain/usecases/get_messages_usecase.dart';
import '../domain/usecases/load_older_messages_usecase.dart';
import '../domain/usecases/load_newer_messages_usecase.dart';
import '../domain/usecases/mark_as_read_usecase.dart';
import '../domain/usecases/mark_as_delivered_usecase.dart';
import '../domain/usecases/mark_as_unread_usecase.dart';
import '../domain/usecases/get_logged_in_user_usecase.dart';
import '../../../../shared_ui/src/clean_architecture/core/constants/enums.dart'
    as core_enums;
import '../../../../shared_ui/src/constants/ui_kit_constants.dart'
    show MessageCategoryConstants, UpdateSettingsConstant;
import '../../shared/list_base.dart';
import '../../../../shared_ui/src/logging/cometchat_log.dart';

// ============================================================================
// Message Receipt Status
// ============================================================================

/// Enum representing message receipt status for ValueNotifier updates
///
/// Used with [MessageListBloc.getReceiptNotifier] for isolated UI updates
/// when receipt status changes.
enum MessageReceiptStatus {
  /// Message is being sent
  sending,

  /// Message has been sent to server
  sent,

  /// Message has been delivered to recipient
  delivered,

  /// Message has been read by recipient
  read,

  /// Message failed to send
  error,
}

// ============================================================================
// MessageListBloc - Clean Architecture BLoC
// ============================================================================

/// BLoC for managing message list state with Clean Architecture
///
/// This BLoC manages the message list state and handles:
/// - Loading and pagination of messages (older/newer)
/// - Real-time updates via SDK listeners (messages, receipts, typing)
/// - O(1) message lookups via index maps
/// - ValueNotifier for isolated UI updates (receipts, typing)
/// - Operations stream for animated list integration
///
/// The BLoC composes with [AnimatedMessageListBloc] for animation support
/// rather than extending it, following composition over inheritance.
///
/// Example usage:
/// ```dart
/// final bloc = MessageListBloc(
///   user: targetUser,
///   // or group: targetGroup,
/// );
///
/// // Load messages
/// bloc.add(LoadMessages(
///   conversationWith: 'user123',
///   conversationType: 'user',
/// ));
///
/// // Access receipt notifier for isolated rebuilds
/// final receiptNotifier = bloc.getReceiptNotifier(messageId);
/// ```
///
/// **Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5, 9.1, 9.2, 9.3, 9.4**
class MessageListBloc extends Bloc<MessageListEvent, MessageListState>
    with ListBase<BaseMessage> {
  // ============================================================
  // USE CASES
  // ============================================================

  /// Use case for fetching initial messages
  final GetMessagesUseCase getMessagesUseCase;

  /// Use case for loading older messages (pagination - scroll up)
  final LoadOlderMessagesUseCase loadOlderMessagesUseCase;

  /// Use case for loading newer messages (pagination - scroll down)
  final LoadNewerMessagesUseCase loadNewerMessagesUseCase;

  /// Use case for marking messages as read
  final MarkAsReadUseCase markAsReadUseCase;

  /// Use case for marking messages as delivered
  final MarkAsDeliveredUseCase markAsDeliveredUseCase;

  /// Use case for marking messages as unread
  final MarkAsUnreadUseCase markAsUnreadUseCase;

  /// Use case for getting the logged-in user
  final GetLoggedInUserUseCase getLoggedInUserUseCase;

  // ============================================================
  // CONFIGURATION
  // ============================================================

  /// Target user for 1-on-1 conversation (mutually exclusive with [group])
  final User? user;

  /// Target group for group conversation (mutually exclusive with [user])
  final Group? group;

  /// Parent message ID for thread replies (null for main conversation)
  final int? parentMessageId;

  /// Whether to include the parent message in thread results (default: false).
  /// Set to true for AI chat history where the parent message should appear in the list.
  final bool withParent;

  /// Message types to include (null means all types)
  final List<String>? types;

  /// Message categories to include (null means all categories)
  final List<String>? categories;

  /// Whether to hide deleted messages (true = remove, false = show as deleted)
  final bool hideDeletedMessages;

  /// Whether to disable sound for incoming messages
  final bool disableSoundForMessages;

  /// Asset path of the sound played for an incoming message, in place of the
  /// kit's own. Ignored when [disableSoundForMessages] is true.
  final String? customSoundForMessages;

  /// Package holding [customSoundForMessages], when it ships in another one.
  final String? customSoundForMessagePackage;

  /// Whether to disable read/delivery receipts
  final bool disableReceipts;

  /// Whether to hide thread replies in main conversation
  final bool hideReplies;

  /// Whether to disable SDK listeners (for testing or web platform)
  final bool disableSDKListeners;

  // ============================================================
  // O(1) LOOKUP MAPS
  // ============================================================

  /// Map from message ID to index in the list (for sent messages)
  /// Enables O(1) lookup by message ID
  final Map<int, int> _messageIndexMap = {};

  /// Map from muid to index in the list (for pending messages)
  /// Enables O(1) lookup by muid before message ID is assigned
  final Map<String, int> _muidIndexMap = {};

  // ============================================================
  // VALUNOTIFIER MAPS FOR ISOLATED UPDATES
  // ============================================================

  /// Map of message ID to receipt status notifier
  /// Enables isolated UI updates when receipt status changes
  final Map<int, ValueNotifier<MessageReceiptStatus>> _receiptNotifiers = {};

  /// Map of message muid to receipt status notifier (for inProgress messages)
  /// Used when message.id is 0 (before server assigns ID)
  final Map<String, ValueNotifier<MessageReceiptStatus>>
  _receiptNotifiersByMuid = {};

  /// Map of conversation ID to typing indicators notifier
  /// Enables isolated UI updates when typing status changes
  final Map<String, ValueNotifier<List<TypingIndicator>>> _typingNotifiers = {};

  /// Map of parent message ID to thread reply count notifier
  /// Enables isolated UI updates when thread reply counts change
  /// **Validates: Requirements 15.4**
  final Map<int, ValueNotifier<int>> _threadReplyCountNotifiers = {};

  // ============================================================
  // OPERATIONS STREAM
  // ============================================================

  /// Stream controller for message operations (consumed by animated list)
  final _operationsController = StreamController<MessageOperation>.broadcast();

  /// Stream of message operations for the animated list to consume
  Stream<MessageOperation> get operationsStream => _operationsController.stream;

  /// Push a no-op set operation so the animated list re-renders all items.
  /// Used when state changes (e.g. unread anchor) need to be reflected
  /// without modifying the message list itself.
  ///
  /// Note: this triggers a full list re-render which resets scroll position
  /// to the bottom for reversed lists. Prefer [notifyMessageChanged] when
  /// only a single item needs to rebuild (e.g. showing the unread indicator
  /// above a specific message) — it preserves scroll offset.
  void notifyListChanged() {
    if (!_operationsController.isClosed) {
      _operationsController.add(
        MessageOperation.set(state.messages, animated: false),
      );
    }
  }

  /// Push an update operation for a single message so only that item rebuilds.
  /// Unlike [notifyListChanged], this preserves scroll position because the
  /// animated list's `_onUpdated` handler just bumps the update notifier
  /// without resetting the list key or jumping scroll.
  ///
  /// Used when state-driven per-item decorations (e.g. the "New Messages"
  /// indicator above the unread anchor) need to re-render without touching
  /// the list structure.
  void notifyMessageChanged(int messageId) {
    if (_operationsController.isClosed) return;
    final index = findMessageIndex(messageId);
    if (index == null) return;
    final message = state.messages[index];
    _operationsController.add(MessageOperation.update(message, message, index));
  }

  // ============================================================
  // SDK LISTENER IDS
  // ============================================================

  /// Unique ID for message listener
  late final String _messageListenerId;

  /// Unique ID for group listener
  late final String _groupListenerId;

  /// Unique ID for call listener
  late final String _callListenerId;

  /// Unique ID for connection listener
  late final String _connectionListenerId;

  /// Unique ID for AI assistant event listener
  late final String _aiAssistantListenerId;

  /// Unique ID for UI message events listener (ccMessageSent, ccMessageEdited, etc.)
  late final String _uiMessageListenerId;

  /// Unique ID for UI group events listener (ccGroupMemberAdded, ccGroupMemberKicked, etc.)
  /// Fires when the logged-in user performs group actions.
  late final String _uiGroupListenerId;

  /// Unique ID for UI call events listener (ccOutgoingCall, ccCallRejected, …)
  late final String _uiCallListenerId;

  // ============================================================
  // PAGINATION STATE
  // ============================================================

  /// Messages request for pagination (older messages)
  MessagesRequest? _olderMessagesRequest;

  /// Messages request for pagination (newer messages)
  MessagesRequest? _newerMessagesRequest;

  // ============================================================
  // INTERNAL STATE
  // ============================================================

  /// Logged in user (cached after first fetch)
  User? _loggedInUser;

  /// Stream service for AI streaming events
  final CometChatStreamService _streamService = CometChatStreamService();

  /// Flag to track if index maps need full rebuild
  bool _mapNeedsRebuild = true;

  /// Flag to skip unread anchor re-detection on the next LoadMessages.
  /// Set by ResetUnreadState so that a subsequent refresh doesn't
  /// re-fetch stale conversation metadata and re-set the indicator.
  bool _skipNextUnreadDetection = false;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  /// Helper to get initialized service locator
  static MessageListServiceLocator _getServiceLocator() {
    if (!MessageListServiceLocator.instance.isInitialized) {
      MessageListServiceLocator.instance.setup();
    }
    return MessageListServiceLocator.instance;
  }

  /// Creates a MessageListBloc.
  ///
  /// All use cases are optional - if not provided, they will be automatically
  /// initialized from the default service locator. This makes it easy to extend
  /// the bloc without worrying about dependency injection.
  ///
  /// Either [user] or [group] must be provided to identify the conversation.
  ///
  /// Example:
  /// ```dart
  /// // For 1-on-1 conversation
  /// final bloc = MessageListBloc(user: targetUser);
  ///
  /// // For group conversation
  /// final bloc = MessageListBloc(group: targetGroup);
  ///
  /// // For thread replies
  /// final bloc = MessageListBloc(
  ///   user: targetUser,
  ///   parentMessageId: parentMessage.id,
  /// );
  /// ```
  MessageListBloc({
    GetMessagesUseCase? getMessagesUseCase,
    LoadOlderMessagesUseCase? loadOlderMessagesUseCase,
    LoadNewerMessagesUseCase? loadNewerMessagesUseCase,
    MarkAsReadUseCase? markAsReadUseCase,
    MarkAsDeliveredUseCase? markAsDeliveredUseCase,
    MarkAsUnreadUseCase? markAsUnreadUseCase,
    GetLoggedInUserUseCase? getLoggedInUserUseCase,
    this.user,
    this.group,
    this.parentMessageId,
    this.types,
    this.categories,
    this.hideDeletedMessages = false,
    this.disableSoundForMessages = false,
    this.customSoundForMessages,
    this.customSoundForMessagePackage,
    this.disableReceipts = false,
    this.hideReplies = true,
    this.disableSDKListeners = false,
    this.withParent = true,
  }) : getMessagesUseCase =
           getMessagesUseCase ?? _getServiceLocator().getMessagesUseCase,
       loadOlderMessagesUseCase =
           loadOlderMessagesUseCase ??
           _getServiceLocator().loadOlderMessagesUseCase,
       loadNewerMessagesUseCase =
           loadNewerMessagesUseCase ??
           _getServiceLocator().loadNewerMessagesUseCase,
       markAsReadUseCase =
           markAsReadUseCase ?? _getServiceLocator().markAsReadUseCase,
       markAsDeliveredUseCase =
           markAsDeliveredUseCase ??
           _getServiceLocator().markAsDeliveredUseCase,
       markAsUnreadUseCase =
           markAsUnreadUseCase ?? _getServiceLocator().markAsUnreadUseCase,
       getLoggedInUserUseCase =
           getLoggedInUserUseCase ??
           _getServiceLocator().getLoggedInUserUseCase,
       super(const MessageListState()) {
    // Generate unique listener IDs
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _messageListenerId = 'message_list_bloc_message_$timestamp';
    _groupListenerId = 'message_list_bloc_group_$timestamp';
    _callListenerId = 'message_list_bloc_call_$timestamp';
    _connectionListenerId = 'message_list_bloc_connection_$timestamp';
    _uiMessageListenerId = 'message_list_bloc_ui_message_$timestamp';
    _uiGroupListenerId = 'message_list_bloc_ui_group_$timestamp';
    _uiCallListenerId = 'message_list_bloc_ui_call_$timestamp';
    _aiAssistantListenerId = 'message_list_bloc_ai_$timestamp';

    // Register event handlers (implementations in Task 9)
    on<LoadMessages>(_onLoadMessages);
    on<LoadOlderMessages>(_onLoadOlderMessages);
    on<LoadNewerMessages>(_onLoadNewerMessages);
    on<RefreshMessages>(_onRefreshMessages);
    on<SyncMessages>(_onSyncMessages);
    on<MessageReceived>(_onMessageReceived);
    on<MessageEdited>(_onMessageEdited);
    on<MessagePinSaveChanged>(_onMessagePinSaveChanged);
    on<MessageDeleted>(_onMessageDeleted);
    on<DeliveryReceiptReceived>(_onDeliveryReceiptReceived);
    on<ReadReceiptReceived>(_onReadReceiptReceived);
    on<MarkMessageAsRead>(_onMarkMessageAsRead);
    on<SetActiveConversation>(_onSetActiveConversation);
    on<JumpToMessage>(_onJumpToMessage);
    on<AddReaction>(_onAddReaction);
    on<RemoveReaction>(_onRemoveReaction);
    on<ReactionAddedFromSDK>(_onReactionAddedFromSDK);
    on<ReactionRemovedFromSDK>(_onReactionRemovedFromSDK);
    on<MarkMessageAsUnread>(_onMarkMessageAsUnread);
    on<LoadFromUnread>(_onLoadFromUnread);
    on<ResetUnreadState>(_onResetUnreadState);
    on<MessageSentByUser>(_onMessageSentByUser);
    on<ForceEmptyState>(_onForceEmptyState);
    on<LoadLastAgentConversation>(_onLoadLastAgentConversation);

    // List base hook events
    on<_ListMessageAdded>(_onListMessageAdded);
    on<_ListMessageRemoved>(_onListMessageRemoved);
    on<_ListMessageUpdated>(_onListMessageUpdated);
    on<_ListMessagesCleared>(_onListMessagesCleared);
    on<_ListMessagesReplaced>(_onListMessagesReplaced);

    // Initialize logged in user and register SDK listeners
    _initializeAndRegisterListeners();
  }

  // ============================================================
  // COMPUTED PROPERTIES
  // ============================================================

  /// Get the conversation ID for the current conversation
  String? get conversationId {
    if (user != null) {
      return 'user_${user!.uid}';
    } else if (group != null) {
      return 'group_${group!.guid}';
    }
    return null;
  }

  /// Get the conversation type ('user' or 'group')
  String get conversationType => user != null ? 'user' : 'group';

  /// Get the conversation with ID (user UID or group GUID)
  String? get conversationWith => user?.uid ?? group?.guid;

  // ============================================================
  // O(1) LOOKUP METHODS
  // ============================================================

  /// Rebuild the index maps from scratch
  ///
  /// Called on initial load, refresh, or when incremental updates
  /// are not possible. This is O(n) but only happens on major list changes.
  void _rebuildIndexMaps() {
    _messageIndexMap.clear();
    _muidIndexMap.clear();
    for (int i = 0; i < state.messages.length; i++) {
      final msg = state.messages[i];
      if (msg.id > 0) {
        _messageIndexMap[msg.id] = i;
      }
      final muid = msg.muid;
      if (muid.isNotEmpty) {
        _muidIndexMap[muid] = i;
      }
    }
    _mapNeedsRebuild = false;
  }

  /// Find message index by message ID (O(1))
  ///
  /// Returns the index of the message in the list, or null if not found.
  ///
  /// Example:
  /// ```dart
  /// final index = bloc.findMessageIndex(12345);
  /// if (index != null) {
  ///   final message = bloc.state.messages[index];
  /// }
  /// ```
  int? findMessageIndex(int messageId) {
    // Lazy rebuild if needed
    if (_mapNeedsRebuild && state.messages.isNotEmpty) {
      _rebuildIndexMaps();
    }
    return _messageIndexMap[messageId];
  }

  /// Find message index by muid (O(1))
  ///
  /// Useful for finding pending messages before they have a server-assigned ID.
  /// Returns the index of the message in the list, or null if not found.
  int? findMessageIndexByMuid(String muid) {
    // Lazy rebuild if needed
    if (_mapNeedsRebuild && state.messages.isNotEmpty) {
      _rebuildIndexMaps();
    }
    return _muidIndexMap[muid];
  }

  /// Find a message by ID (O(1))
  ///
  /// Returns the message with the given ID, or null if not found.
  ///
  /// Example:
  /// ```dart
  /// final message = bloc.findMessage(12345);
  /// if (message != null) {
  ///   print('Found message: ${message.id}');
  /// }
  /// ```
  BaseMessage? findMessage(int messageId) {
    final index = findMessageIndex(messageId);
    return index != null && index < state.messages.length
        ? state.messages[index]
        : null;
  }

  /// Find a message by muid (O(1))
  ///
  /// Useful for finding pending messages before they have a server-assigned ID.
  BaseMessage? findMessageByMuid(String muid) {
    final index = findMessageIndexByMuid(muid);
    return index != null && index < state.messages.length
        ? state.messages[index]
        : null;
  }

  // ============================================================
  // INCREMENTAL INDEX MAP UPDATES
  // ============================================================

  /// Add a single message to the index maps
  void _addToIndexMaps(BaseMessage message, int index) {
    if (message.id > 0) {
      _messageIndexMap[message.id] = index;
    }
    final muid = message.muid;
    if (muid.isNotEmpty) {
      _muidIndexMap[muid] = index;
    }
  }

  /// Remove a single message from the index maps
  /// Note: Does NOT clean up receipt notifiers - that's handled separately
  /// in message deletion to preserve notifiers during ID transitions
  void _removeFromIndexMaps(BaseMessage message) {
    if (message.id > 0) {
      _messageIndexMap.remove(message.id);
    }
    final muid = message.muid;
    if (muid.isNotEmpty) {
      _muidIndexMap.remove(muid);
    }
  }

  /// Derive the receipt status from a message's timestamps.
  MessageReceiptStatus _receiptStatusFromMessage(BaseMessage message) {
    if (message.readAt != null) return MessageReceiptStatus.read;
    if (message.deliveredAt != null) return MessageReceiptStatus.delivered;
    if (message.id > 0) return MessageReceiptStatus.sent;
    return MessageReceiptStatus.sending;
  }

  /// Clean up receipt notifiers for a message being removed from the list
  /// Called only when a message is actually deleted, not during ID transitions
  void _cleanupReceiptNotifiers(BaseMessage message) {
    if (message.id > 0) {
      _receiptNotifiers.remove(message.id);
    }
    final muid = message.muid;
    if (muid.isNotEmpty) {
      _receiptNotifiersByMuid.remove(muid);
    }
  }

  /// Shift indices after removal (items after removedIndex move up)
  void _shiftIndicesAfterRemoval(int removedIndex) {
    _messageIndexMap.updateAll((key, index) {
      return index > removedIndex ? index - 1 : index;
    });
    _muidIndexMap.updateAll((key, index) {
      return index > removedIndex ? index - 1 : index;
    });
  }

  // ============================================================
  // VALUENOTIFIER ACCESSORS
  // ============================================================

  /// Get or create a receipt status notifier for a specific message.
  ///
  /// Use this with [ValueListenableBuilder] in message bubbles for isolated
  /// rebuilds when receipt status changes.
  ///
  /// Example:
  /// ```dart
  /// ValueListenableBuilder<MessageReceiptStatus>(
  ///   valueListenable: bloc.getReceiptNotifier(message.id),
  ///   builder: (context, status, child) {
  ///     return ReceiptIcon(status: status);
  ///   },
  /// )
  /// ```
  ValueNotifier<MessageReceiptStatus> getReceiptNotifier(int messageId) {
    return _receiptNotifiers.putIfAbsent(
      messageId,
      () => ValueNotifier<MessageReceiptStatus>(MessageReceiptStatus.sent),
    );
  }

  /// Get or create a receipt status notifier for a message.
  ///
  /// This method handles both sent messages (with valid ID) and inProgress
  /// messages (with ID=0 but valid muid). Use this for message bubbles that
  /// need to show receipt status during the full message lifecycle.
  ///
  /// Optimized approach: Both maps may point to the SAME notifier instance
  /// after migration, ensuring stale message objects still get correct status.
  ValueNotifier<MessageReceiptStatus> getReceiptNotifierForMessage(
    BaseMessage message,
  ) {
    // For messages with valid ID, prefer ID-based lookup
    if (message.id > 0) {
      final idNotifier = _receiptNotifiers[message.id];
      if (idNotifier != null) return idNotifier;

      // Fallback: check muid map (handles race conditions during migration)
      if (message.muid.isNotEmpty) {
        final muidNotifier = _receiptNotifiersByMuid[message.muid];
        if (muidNotifier != null) {
          // Cache in id map for future lookups
          _receiptNotifiers[message.id] = muidNotifier;
          return muidNotifier;
        }
      }

      // Create new notifier with status derived from the message's timestamps
      final initialStatus = _receiptStatusFromMessage(message);
      final newNotifier = ValueNotifier<MessageReceiptStatus>(initialStatus);
      _receiptNotifiers[message.id] = newNotifier;
      return newNotifier;
    }

    // For inProgress messages (id=0), use muid-based lookup
    if (message.muid.isNotEmpty) {
      return _receiptNotifiersByMuid.putIfAbsent(
        message.muid,
        () => ValueNotifier<MessageReceiptStatus>(MessageReceiptStatus.sending),
      );
    }

    // Fallback: return a new notifier with sent status
    return ValueNotifier<MessageReceiptStatus>(MessageReceiptStatus.sent);
  }

  /// Get or create a typing indicator notifier for a specific conversation.
  ///
  /// Use this with [ValueListenableBuilder] for isolated rebuilds when
  /// typing status changes. Returns a list to support multiple typers
  /// in group conversations.
  ///
  /// Example:
  /// ```dart
  /// ValueListenableBuilder<List<TypingIndicator>>(
  ///   valueListenable: bloc.getTypingNotifier(conversationId),
  ///   builder: (context, typers, child) {
  ///     if (typers.isEmpty) return const SizedBox.shrink();
  ///     return TypingIndicatorWidget(typers: typers);
  ///   },
  /// )
  /// ```
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

  /// Get or create a thread reply count notifier for a specific parent message.
  ///
  /// Use this with [ValueListenableBuilder] in message bubbles for isolated
  /// rebuilds when thread reply counts change.
  ///
  /// Example:
  /// ```dart
  /// ValueListenableBuilder<int>(
  ///   valueListenable: bloc.getThreadReplyCountNotifier(parentMessageId),
  ///   builder: (context, replyCount, child) {
  ///     return Text('$replyCount replies');
  ///   },
  /// )
  /// ```
  ///
  /// **Validates: Requirements 15.4**
  ValueNotifier<int> getThreadReplyCountNotifier(int parentMessageId) {
    return _threadReplyCountNotifiers.putIfAbsent(
      parentMessageId,
      () => ValueNotifier<int>(0),
    );
  }

  /// Get current thread reply count for a parent message (for initial value)
  ///
  /// Returns the cached reply count or 0 if not tracked.
  ///
  /// **Validates: Requirements 15.4**
  int getThreadReplyCount(int parentMessageId) {
    return _threadReplyCountNotifiers[parentMessageId]?.value ?? 0;
  }

  /// Initialize thread reply count notifier with a specific value
  ///
  /// Used when loading messages to set initial reply counts from the message data.
  ///
  /// **Validates: Requirements 15.4**
  void initializeThreadReplyCount(int parentMessageId, int replyCount) {
    final notifier = getThreadReplyCountNotifier(parentMessageId);
    if (notifier.value != replyCount) {
      notifier.value = replyCount;
    }
  }

  /// Increment thread reply count for a parent message
  ///
  /// Called when a new thread reply is received.
  /// Also updates the underlying BaseMessage.replyCount so that
  /// re-seeding from the model (e.g. on widget rebuild) doesn't
  /// overwrite the live-incremented value.
  ///
  /// **Validates: Requirements 15.4**
  void _incrementThreadReplyCount(int parentMessageId) {
    final notifier = getThreadReplyCountNotifier(parentMessageId);
    notifier.value = notifier.value + 1;

    // Keep the BaseMessage.replyCount in sync so that
    // initializeThreadReplyCount (called on widget rebuild) doesn't
    // overwrite the notifier with a stale value.
    final index = findMessageIndex(parentMessageId);
    if (index != null && index < state.messages.length) {
      state.messages[index].replyCount = notifier.value;
    }
  }

  /// Consumer-side thread-subscription mirrors (stateless redesign §5).
  ///
  /// The SDK no longer infers anything; these mirror **server-side truths**
  /// locally for immediate UI feedback — the next fetch of the parent
  /// confirms, and a fetched flag always wins. Triggers handled here:
  ///
  /// * an incoming message that @-mentions the logged-in user (its thread:
  ///   the parent for a reply, the message itself for a root), and
  /// * the FIRST reply by someone else to a root the logged-in user
  ///   authored. First-reply-only is what protects a deliberate
  ///   unsubscribe: at reply one the author is guaranteed subscribed
  ///   (authoring set the flag and nothing has happened since); by reply
  ///   two they may have unsubscribed, so re-applying would silently undo
  ///   their choice. Must run BEFORE the reply-count increment — the
  ///   "first" test is `replyCount == 0` on the rendered parent.
  ///
  /// This is local mirroring, not a write — no subscribe call is made.
  void _applyThreadSubscriptionMirrors(BaseMessage message) {
    final myUid = _loggedInUser?.uid;
    if (myUid == null) return;

    final threadId = message.parentMessageId > 0
        ? message.parentMessageId
        : message.id;
    if (threadId <= 0) return;

    final mentionsMe = message.mentionedUsers.any(
      (mentioned) => mentioned.uid == myUid,
    );

    var firstReplyToOwnRoot = false;
    if (message.parentMessageId > 0 && message.sender?.uid != myUid) {
      final parent = findMessage(message.parentMessageId);
      firstReplyToOwnRoot =
          parent != null &&
          parent.sender?.uid == myUid &&
          parent.replyCount == 0;
    }

    if (!mentionsMe && !firstReplyToOwnRoot) return;

    final root = findMessage(threadId);
    if (root != null && root.threadSubscribed) return; // already known
    root?.threadSubscribed = true;
    CometChatMessageEvents.ccThreadSubscriptionChanged(threadId, true);
  }

  /// Restamps this bloc's copy of a thread root when any surface announces a
  /// subscription change — the message object is the single source of truth,
  /// so every list instance must converge on it. Silent: the options sheet
  /// reads the object lazily on open, no rebuild needed.
  void _handleThreadSubscriptionChangedEvent(
    int parentMessageId,
    bool subscribed,
  ) {
    if (isClosed) return;
    findMessage(parentMessageId)?.threadSubscribed = subscribed;
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  /// Initialize logged in user and register all SDK listeners
  Future<void> _initializeAndRegisterListeners() async {
    // Use cached logged-in user from UIKit level (avoids redundant platform channel calls)
    _loggedInUser = CometChatUIKit.loggedInUser;

    // Register SDK listeners if not disabled
    if (!disableSDKListeners) {
      _registerSDKListeners();
    }
  }

  /// Register all CometChat SDK listeners for real-time updates
  ///
  /// Registers listeners for:
  /// - Messages (received, edited, deleted, receipts, typing)
  /// - Groups (member events, action messages)
  /// - Calls (for call action messages)
  /// - Connection (for reconnection refresh)
  ///
  /// **Validates: Requirements 8.1**
  void _registerSDKListeners() {
    // Register message listener
    CometChat.addMessageListener(
      _messageListenerId,
      _MessageListMessageListener(
        onTextMessageReceivedCallback: _handleMessageReceived,
        onMediaMessageReceivedCallback: _handleMessageReceived,
        onCustomMessageReceivedCallback: _handleMessageReceived,
        onInteractiveMessageReceivedCallback: _handleMessageReceived,
        onAIAssistantMessageReceivedCallback: _handleMessageReceived,
        onMessageEditedCallback: _handleMessageEdited,
        onMessagePinSaveChangedCallback: _handleMessagePinSaveChanged,
        onMessageDeletedCallback: _handleMessageDeleted,
        onMessageModeratedCallback: _handleMessageModerated,
        onMessagesDeliveredCallback: _handleMessagesDelivered,
        onMessagesReadCallback: _handleMessagesRead,
        onMessagesDeliveredToAllCallback: _handleMessagesDeliveredToAll,
        onMessagesReadByAllCallback: _handleMessagesReadByAll,
        onTypingStartedCallback: _handleTypingStarted,
        onTypingEndedCallback: _handleTypingEnded,
        onMessageReactionAddedCallback: _handleMessageReactionAdded,
        onMessageReactionRemovedCallback: _handleMessageReactionRemoved,
      ),
    );

    // Register group listener
    CometChat.addGroupListener(
      _groupListenerId,
      _MessageListGroupListener(
        onGroupMemberJoinedCallback: _handleGroupMemberJoined,
        onGroupMemberLeftCallback: _handleGroupMemberLeft,
        onGroupMemberKickedCallback: _handleGroupMemberKicked,
        onGroupMemberBannedCallback: _handleGroupMemberBanned,
        onGroupMemberUnbannedCallback: _handleGroupMemberUnbanned,
        onGroupMemberScopeChangedCallback: _handleGroupMemberScopeChanged,
        onMemberAddedToGroupCallback: _handleMemberAddedToGroup,
      ),
    );

    // Register call listener (for call action messages)
    CometChat.addCallListener(
      _callListenerId,
      _MessageListCallListener(
        onIncomingCallReceivedCallback: _handleIncomingCallReceived,
        onOutgoingCallAcceptedCallback: _handleOutgoingCallAccepted,
        onOutgoingCallRejectedCallback: _handleOutgoingCallRejected,
        onIncomingCallCancelledCallback: _handleIncomingCallCancelled,
        onCallEndedMessageReceivedCallback: _handleCallEndedMessageReceived,
      ),
    );

    // Register connection listener
    CometChat.addConnectionListener(
      _connectionListenerId,
      _MessageListConnectionListener(
        onConnectedCallback: _handleConnected,
        onDisconnectedCallback: _handleDisconnected,
      ),
    );

    // Register AI assistant event listener (for streaming/thinking bubbles)
    if (user?.role == 'ai' || user?.role == AIConstants.aiRole) {
      CometChat.addAIAssistantListener(
        _aiAssistantListenerId,
        _MessageListAIAssistantListener(
          onAIAssistantEventReceivedCallback: _handleAIAssistantEvent,
        ),
      );
    }

    // Register UI message events listener (for messages sent by logged-in user)
    CometChatMessageEvents.addMessagesListener(
      _uiMessageListenerId,
      _MessageListUIEventListener(
        onCCMessageSentCallback: _handleCCMessageSent,
        onCCMessageEditedCallback: _handleCCMessageEdited,
        onCCMessageDeletedCallback: _handleCCMessageDeleted,
        onThreadSubscriptionChangedCallback:
            _handleThreadSubscriptionChangedEvent,
      ),
    );

    // Register UI group events listener (for group actions by logged-in user)
    // SDK group listeners only fire for OTHER users' actions — we need UI events
    // to catch action messages when the logged-in user adds/kicks/bans members.
    CometChatGroupEvents.addGroupsListener(
      _uiGroupListenerId,
      _MessageListUIGroupEventListener(
        onCCGroupMemberAddedCallback: _handleCCGroupMemberAdded,
        onCCGroupMemberKickedCallback: _handleCCGroupMemberKicked,
        onCCGroupMemberBannedCallback: _handleCCGroupMemberBanned,
      ),
    );

    // Register UI call events listener — the calls this device acted on
    // itself, which the SDK never reports back to it.
    CometChatCallEvents.addCallEventsListener(
      _uiCallListenerId,
      _MessageListUICallEventListener(onCallCallback: _handleCCCallEvent),
    );
  }

  // ============================================================
  // MESSAGE LISTENER CALLBACKS
  // ============================================================

  /// Handle new message received from SDK
  ///
  /// Dispatches MessageReceived event if message belongs to current conversation
  /// and passes type/category filters.
  ///
  /// **Validates: Requirements 8.2**
  void _handleMessageReceived(BaseMessage message) {
    if (isClosed) return;

    // Messages sent by the logged-in user from the CURRENT device are already
    // handled via ccMessageSent (inProgress → sent).  However, messages sent
    // from ANOTHER device on the same account arrive here via the SDK
    // real-time listener and must be accepted.
    //
    // Strategy: if the message is from the logged-in user AND already exists
    // in the list (by id or muid), it was handled by ccMessageSent → skip.
    // Otherwise it came from another device → let it through.
    //
    // Exception: server-originated custom messages (document, whiteboard,
    // polls) are created via callExtension and never go through ccMessageSent,
    // so we always accept them.
    if (message.sender?.uid == _loggedInUser?.uid) {
      // Always accept server-originated custom message types
      if (message is CustomMessage) {
        final type = message.type;
        const serverOriginatedTypes = {
          ExtensionType.document,
          ExtensionType.whiteboard,
          ExtensionType.extensionPoll,
        };
        if (serverOriginatedTypes.contains(type)) {
          // fall through — accept
        } else {
          // For other custom messages, skip only if already in the list
          if (_isMessageAlreadyInList(message)) return;
        }
      } else {
        // For text/media messages, skip only if already in the list
        if (_isMessageAlreadyInList(message)) return;
      }
    }

    // Mark as delivered if not from logged in user
    if (!disableReceipts && message.sender?.uid != _loggedInUser?.uid) {
      markAsDeliveredUseCase(message: message);
    }

    // Dispatch event - filtering happens in event handler
    add(MessageReceived(message));
  }

  /// Handle message edited from SDK
  ///
  /// **Validates: Requirements 8.3**
  void _handleMessageEdited(BaseMessage message) {
    if (isClosed) return;
    add(MessageEdited(message));
  }

  void _handleMessagePinSaveChanged(BaseMessage message, bool isPinScope) {
    if (isClosed) return;
    add(MessagePinSaveChanged(message, isPinScope: isPinScope));
  }

  /// Handle message deleted from SDK
  ///
  /// **Validates: Requirements 8.4**
  void _handleMessageDeleted(BaseMessage message) {
    if (isClosed) return;
    add(MessageDeleted(message));
  }

  /// Handle moderation status change from SDK.
  ///
  /// The SDK emits this when a message's moderation state changes after send
  /// (e.g., moderation pipeline marks it `disapproved`). We route it through
  /// the same `MessageEdited` pipeline since the update mechanics — locate by
  /// id/muid and replace — are identical. The next bubble rebuild will see
  /// the new `moderationStatus` and render the moderation banner + error
  /// receipt icon.
  void _handleMessageModerated(BaseMessage message) {
    if (isClosed) return;
    // Broadcast to any other UI surface (e.g. the conversation list row) so
    // they can flip their own representation (sent tick → error icon).
    CometChatMessageEvents.onMessageModerated(message);
    add(MessageEdited(message));
  }

  /// When replacing `oldMessage` with `newMessage`, keep whichever has the
  /// stronger moderation verdict. Prevents race conditions where an older
  /// snapshot (e.g. a later-arriving `sent` event carrying `pending`)
  /// overwrites a newer terminal state (`disapproved` / `approved`) that
  /// already arrived via the moderation stream.
  BaseMessage _preserveModerationStatus(
    BaseMessage oldMessage,
    BaseMessage newMessage,
  ) {
    final oldStatus = _extractModerationStatus(oldMessage);
    final newStatus = _extractModerationStatus(newMessage);
    if (oldStatus == null) return newMessage;
    if (_moderationRank(oldStatus) <= _moderationRank(newStatus)) {
      return newMessage;
    }
    // oldStatus is stronger — copy it onto the new message.
    if (newMessage is TextMessage && oldMessage is TextMessage) {
      newMessage.moderationStatus = oldMessage.moderationStatus;
    } else if (newMessage is MediaMessage && oldMessage is MediaMessage) {
      newMessage.moderationStatus = oldMessage.moderationStatus;
    }
    return newMessage;
  }

  ModerationStatusEnum? _extractModerationStatus(BaseMessage m) {
    if (m is TextMessage) return m.moderationStatus;
    if (m is MediaMessage) return m.moderationStatus;
    return null;
  }

  /// Higher rank = more terminal / more authoritative. `pending` is weakest;
  /// `approved` and `disapproved` are terminal.
  int _moderationRank(ModerationStatusEnum? s) {
    if (s == null) return 0;
    switch (s.value) {
      case 'pending':
        return 1;
      case 'unmoderated':
        return 2;
      case 'approved':
      case 'disapproved':
        return 3;
    }
    return 0;
  }

  /// Handle delivery receipt (1-on-1 conversations)
  ///
  /// **Validates: Requirements 8.5**
  void _handleMessagesDelivered(MessageReceipt receipt) {
    if (isClosed) return;
    if (disableReceipts) return;
    if (receipt.receiverType != 'user') return;
    add(DeliveryReceiptReceived(receipt));
  }

  /// Handle read receipt (1-on-1 conversations)
  ///
  /// **Validates: Requirements 8.6**
  void _handleMessagesRead(MessageReceipt receipt) {
    if (isClosed) return;
    if (disableReceipts) return;
    if (receipt.receiverType != 'user') return;
    add(ReadReceiptReceived(receipt));
  }

  /// Handle delivery receipt for all (group conversations)
  ///
  /// **Validates: Requirements 8.5**
  void _handleMessagesDeliveredToAll(MessageReceipt receipt) {
    if (isClosed) return;
    if (disableReceipts) return;
    if (receipt.receiverType != 'group') return;
    add(DeliveryReceiptReceived(receipt));
  }

  /// Handle read receipt for all (group conversations)
  ///
  /// **Validates: Requirements 8.6**
  void _handleMessagesReadByAll(MessageReceipt receipt) {
    if (isClosed) return;
    if (disableReceipts) return;
    if (receipt.receiverType != 'group') return;
    add(ReadReceiptReceived(receipt));
  }

  /// Handle typing started
  ///
  /// Updates the typing notifier directly for isolated UI updates.
  /// Supports multiple typers in group conversations.
  void _handleTypingStarted(TypingIndicator typingIndicator) {
    if (isClosed) return;

    // Check if typing is for current conversation
    if (!_isTypingForCurrentConversation(typingIndicator)) return;

    final convId = conversationId;
    if (convId == null) return;

    // Add to list of typers (avoid duplicates by user ID)
    final notifier = getTypingNotifier(convId);
    final currentTypers = List<TypingIndicator>.from(notifier.value);

    // Remove existing indicator from same user (if any) and add new one
    currentTypers.removeWhere(
      (t) => t.sender.uid == typingIndicator.sender.uid,
    );
    currentTypers.add(typingIndicator);

    notifier.value = currentTypers;
  }

  /// Handle typing ended
  ///
  /// Updates the typing notifier directly for isolated UI updates.
  void _handleTypingEnded(TypingIndicator typingIndicator) {
    if (isClosed) return;

    // Check if typing is for current conversation
    if (!_isTypingForCurrentConversation(typingIndicator)) return;

    final convId = conversationId;
    if (convId == null) return;

    // Remove this user from the list of typers
    final notifier = _typingNotifiers[convId];
    if (notifier != null) {
      final currentTypers = List<TypingIndicator>.from(notifier.value);
      currentTypers.removeWhere(
        (t) => t.sender.uid == typingIndicator.sender.uid,
      );
      notifier.value = currentTypers;
    }
  }

  /// Check if typing indicator is for current conversation
  bool _isTypingForCurrentConversation(TypingIndicator typingIndicator) {
    if (user != null) {
      // 1-on-1 conversation - check if sender is the target user
      return typingIndicator.receiverType == 'user' &&
          typingIndicator.sender.uid == user!.uid;
    } else if (group != null) {
      // Group conversation - check if receiver is the target group
      return typingIndicator.receiverType == 'group' &&
          typingIndicator.receiverId == group!.guid;
    }
    return false;
  }

  // ============================================================
  // GROUP LISTENER CALLBACKS
  // ============================================================

  /// Handle group member joined
  ///
  /// Adds the action message to the list if it belongs to current conversation.
  ///
  /// **Validates: Requirements 8.2**
  void _handleGroupMemberJoined(
    Action action,
    User joinedUser,
    Group joinedGroup,
  ) {
    if (isClosed) return;
    _handleGroupActionMessage(action);
  }

  /// Handle group member left
  void _handleGroupMemberLeft(Action action, User leftUser, Group leftGroup) {
    if (isClosed) return;
    _handleGroupActionMessage(action);
  }

  /// Handle group member kicked
  void _handleGroupMemberKicked(
    Action action,
    User kickedUser,
    User kickedBy,
    Group kickedFrom,
  ) {
    if (isClosed) return;
    _handleGroupActionMessage(action);
  }

  /// Handle group member banned
  void _handleGroupMemberBanned(
    Action action,
    User bannedUser,
    User bannedBy,
    Group bannedFrom,
  ) {
    if (isClosed) return;
    _handleGroupActionMessage(action);
  }

  /// Handle group member unbanned
  void _handleGroupMemberUnbanned(
    Action action,
    User unbannedUser,
    User unbannedBy,
    Group unbannedFrom,
  ) {
    if (isClosed) return;
    _handleGroupActionMessage(action);
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
    _handleGroupActionMessage(action);
  }

  /// Handle member added to group
  void _handleMemberAddedToGroup(
    Action action,
    User addedBy,
    User userAdded,
    Group addedTo,
  ) {
    if (isClosed) return;
    _handleGroupActionMessage(action);
  }

  // ============================================================
  // UI GROUP EVENT CALLBACKS (CometChatGroupEvents)
  // ============================================================
  // These fire when the LOGGED-IN user performs group actions.
  // SDK listeners only fire for OTHER users in the group.

  /// Handle member(s) added to group by the logged-in user
  ///
  /// Adds each action message to the list so "X added Y" appears immediately.
  void _handleCCGroupMemberAdded(
    List<Action> messages,
    List<User> usersAdded,
    Group groupAddedIn,
    User addedBy,
  ) {
    if (isClosed) return;
    // Only handle events for the current group
    if (group?.guid != groupAddedIn.guid) return;
    for (final action in messages) {
      _handleGroupActionMessage(action);
    }
  }

  /// Handle member kicked by the logged-in user
  void _handleCCGroupMemberKicked(
    Action action,
    User kickedUser,
    User kickedBy,
    Group kickedFrom,
  ) {
    if (isClosed) return;
    if (group?.guid != kickedFrom.guid) return;
    _handleGroupActionMessage(action);
  }

  /// Handle member banned by the logged-in user
  void _handleCCGroupMemberBanned(
    Action action,
    User bannedUser,
    User bannedBy,
    Group bannedFrom,
  ) {
    if (isClosed) return;
    if (group?.guid != bannedFrom.guid) return;
    _handleGroupActionMessage(action);
  }

  /// Handle group action message
  ///
  /// Dispatches MessageReceived event for action messages that belong
  /// to the current conversation.
  void _handleGroupActionMessage(Action action) {
    // Action messages are BaseMessage subclass, dispatch as received
    add(MessageReceived(action));
  }

  // ============================================================
  // CALL LISTENER CALLBACKS
  // ============================================================

  /// Handle incoming call received
  void _handleIncomingCallReceived(Call call) {
    if (isClosed) return;
    _handleCallMessage(call);
  }

  /// Handle outgoing call accepted
  void _handleOutgoingCallAccepted(Call call) {
    if (isClosed) return;
    _handleCallMessage(call);
  }

  /// Handle outgoing call rejected
  void _handleOutgoingCallRejected(Call call) {
    if (isClosed) return;
    _handleCallMessage(call);
  }

  /// Handle incoming call cancelled
  void _handleIncomingCallCancelled(Call call) {
    if (isClosed) return;
    _handleCallMessage(call);
  }

  /// Handle call ended message received
  void _handleCallEndedMessageReceived(Call call) {
    if (isClosed) return;
    _handleCallMessage(call);
  }

  /// Handle call message
  ///
  /// Dispatches MessageReceived event for call messages that belong
  /// to the current conversation.
  /// Handle a UI Kit call event (this device initiated, accepted, declined
  /// or ended a call).
  ///
  /// Goes through [MessageReceived], which updates the call's bubble by id if
  /// it is already on screen and adds it otherwise.
  void _handleCCCallEvent(Call call) {
    if (isClosed) return;
    // The events carry the Call the SDK returned for the action, which is not
    // always stamped with a category; without it the bubble would not be
    // recognised as a call.
    if (call.category.isEmpty) call.category = MessageCategoryConstants.call;
    add(MessageReceived(call));
  }

  void _handleCallMessage(Call call) {
    // Call messages are BaseMessage subclass, dispatch as received
    add(MessageReceived(call));
  }

  // ============================================================
  // CONNECTION LISTENER CALLBACKS
  // ============================================================

  /// Handle connected (reconnection)
  ///
  /// Refreshes the message list when connection is restored.
  ///
  /// **Validates: Requirements 8.2**
  void _handleConnected() {
    if (isClosed) return;
    // Silently sync any missed messages on reconnection (no loader)
    add(const SyncMessages());
  }

  /// Handle disconnected
  void _handleDisconnected() {
    if (isClosed) return;
    // Could emit a state indicating disconnection if needed
    // For now, we just log it
  }

  // ============================================================
  // UI MESSAGE EVENT CALLBACKS
  // ============================================================

  /// Handle message sent by logged-in user (from UI events)
  ///
  /// This is called when the composer sends a message via CometChatMessageEvents.ccMessageSent.
  /// We add the message to the list immediately for optimistic UI updates.
  ///
  /// The status parameter is dynamic but contains a [core_enums.MessageStatus] enum value.
  /// We compare using toString() to handle dynamic type comparison reliably.
  void _handleCCMessageSent(BaseMessage message, dynamic status) {
    if (isClosed) return;

    // Only process messages for the current conversation
    if (!_isMessageForCurrentConversation(message)) return;

    // Check parentMessageId for threads
    if (parentMessageId != null) {
      if (message.parentMessageId != parentMessageId) return;
    } else {
      // In main conversation mode — if this is a thread reply, increment
      // the parent message's reply count so the UI updates instantly.
      // Only increment on 'sent' status to avoid double-counting (this
      // callback fires for both inProgress and sent).
      if (message.parentMessageId > 0) {
        final statusStr = status.toString();
        final isSent = statusStr == core_enums.MessageStatus.sent.toString();
        if (isSent) {
          // Auto-subscribe-on-reply mirror (server truth A7): a successful
          // own threaded send subscribes the author — stamp the parent and
          // announce, no unconditional overwrite of a later unsubscribe
          // because this only fires on the send the user just performed.
          final parent = findMessage(message.parentMessageId);
          if (parent != null && !parent.threadSubscribed) {
            parent.threadSubscribed = true;
            CometChatMessageEvents.ccThreadSubscriptionChanged(
              message.parentMessageId,
              true,
            );
          }
          _incrementThreadReplyCount(message.parentMessageId);
        }
        if (hideReplies) return;
      }
    }

    // Dispatch a single event — all state mutations happen inside the BLoC
    // event handler where state is consistent (no race conditions).
    add(MessageSentByUser(message: message, status: status.toString()));
  }

  // ============================================================
  // AI ASSISTANT EVENT HANDLING
  // ============================================================

  /// Handle AI assistant streaming events.
  /// Creates thinking bubble on run_started, routes content to stream service.
  /// The CometChatStreamBubble widget handles word-by-word rendering.
  void _handleAIAssistantEvent(AIAssistantBaseEvent event) {
    if (isClosed) return;
    ccLog(
      '[MessageListBloc] AI event received: type=${event.type}, id=${event.id}',
    );
    final runId = event.id;
    if (runId == null) return;

    _streamService.handleIncomingEvent(runId, event);

    if (event.type == AgenticKeys.runStarted ||
        event.type == AgenticKeys.textMessageStart) {
      _createThinkingMessage(runId);
    }
  }

  /// Create a thinking/streaming bubble for a new AI run.
  /// Uses negative runId to avoid collision with the parent message ID.
  /// Initial text is empty — the CometChatStreamBubble widget shows shimmer
  /// via metadata[aiShimmer]=true, then updates text as content arrives.
  void _createThinkingMessage(int runId) {
    final thinkingMessageId = -runId;
    // Don't create duplicate thinking bubbles
    for (final msg in state.messages) {
      if (msg.id == thinkingMessageId) return;
    }

    final thinkingMessage = StreamMessage(
      id: thinkingMessageId,
      text: 'Thinking...', // Shown with shimmer effect until content arrives
      sender: user,
      receiver: _loggedInUser,
      receiverUid: _loggedInUser?.uid ?? '',
      receiverType: CometChatReceiverType.user,
      sentAt: DateTime.now(),
      runId: runId,
      muid: 'run_$runId',
      metadata: {AIConstants.aiShimmer: true},
      parentMessageId: parentMessageId ?? 0,
    );

    _streamService.setMessageIdForRun(runId, thinkingMessage.id);
    _streamService.getOrCreateBuffer(runId);
    _streamService.registerMessage(thinkingMessage);

    // Notify composer that AI is streaming (shows stop button)
    CometChatStreamCallBackEvents.ccStreamInProgress(true);

    add(MessageReceived(thinkingMessage));
  }

  /// Force the message list into empty state without loading messages.
  /// Used for AI users with no active thread (fresh chat).
  Future<void> _onForceEmptyState(
    ForceEmptyState event,
    Emitter<MessageListState> emit,
  ) async {
    // Use cached logged-in user from UIKit level
    _loggedInUser ??= CometChatUIKit.loggedInUser;
    emit(
      state.copyWith(
        status: MessageListStatus.empty,
        messages: [],
        hasMoreOlder: false,
        hasMoreNewer: false,
        loggedInUser: _loggedInUser,
      ),
    );
  }

  /// Handle LoadLastAgentConversation event.
  ///
  /// Fetches messages for the agent UID with hideReplies: true to find the
  /// latest parent message (conversation starter). If found, loads the full
  /// thread using that parentMessageId and emits [ccAgentChatThreadResolved]
  /// so sibling components (Composer) can update their parentMessageId.
  /// Falls back to empty state if no previous conversation exists.
  Future<void> _onLoadLastAgentConversation(
    LoadLastAgentConversation event,
    Emitter<MessageListState> emit,
  ) async {
    emit(state.copyWith(status: MessageListStatus.loading));
    _loggedInUser ??= CometChatUIKit.loggedInUser;

    // Step 1: Fetch messages with hideReplies to get parent messages only
    final result = await getMessagesUseCase(
      conversationWith: event.conversationWith,
      conversationType: 'user',
      hideReplies: true,
    );

    int? resolvedParentMessageId;
    result.fold(
      (failure) {
        // Fall through — will emit empty state below
      },
      (messages) {
        if (messages.isNotEmpty) {
          // The last message is the most recent parent (conversation starter)
          resolvedParentMessageId = messages.last.id;
        }
      },
    );

    if (resolvedParentMessageId == null || resolvedParentMessageId! <= 0) {
      // No previous conversation — show empty/greeting state
      emit(
        state.copyWith(
          status: MessageListStatus.empty,
          messages: [],
          hasMoreOlder: false,
          hasMoreNewer: false,
          loggedInUser: _loggedInUser,
        ),
      );
      return;
    }

    // Step 2: Emit the UI event so the Composer can sync its parentMessageId
    CometChatUIEvents.ccAgentChatThreadResolved(
      receiverId: event.conversationWith,
      parentMessageId: resolvedParentMessageId!,
    );

    // Step 3: Load the full thread using the resolved parentMessageId
    final threadResult = await getMessagesUseCase(
      conversationWith: event.conversationWith,
      conversationType: 'user',
      parentMessageId: resolvedParentMessageId,
      hideReplies: false,
      withParent: withParent,
    );

    // Extract value from fold — emit at top level per async-bloc-fold-pattern
    List<BaseMessage>? threadMessages;
    String? threadError;
    threadResult.fold(
      (failure) {
        threadError = failure.message;
      },
      (messages) {
        threadMessages = messages;
      },
    );

    if (threadError != null) {
      emit(
        state.copyWith(
          status: MessageListStatus.error,
          errorMessage: threadError,
        ),
      );
      return;
    }

    if (threadMessages == null || threadMessages!.isEmpty) {
      emit(
        state.copyWith(
          status: MessageListStatus.empty,
          messages: [],
          hasMoreOlder: false,
          hasMoreNewer: false,
          loggedInUser: _loggedInUser,
        ),
      );
      return;
    }

    final intercepted = onBeforeMessagesSet(threadMessages!);
    if (intercepted == null) return;

    _mapNeedsRebuild = true;

    for (final message in intercepted) {
      if (message.replyCount > 0) {
        initializeThreadReplyCount(message.id, message.replyCount);
      }
    }

    emit(
      state.copyWith(
        status: MessageListStatus.loaded,
        messages: intercepted,
        hasMoreOlder: intercepted.length >= 30,
        hasMoreNewer: false,
        loggedInUser: _loggedInUser,
      ),
    );

    if (!_operationsController.isClosed) {
      _operationsController.add(
        MessageOperation.set(intercepted, animated: true),
      );
    }

    onAfterMessagesSet(intercepted);

    _initializeMessagesRequests(
      conversationWith: event.conversationWith,
      conversationType: 'user',
      parentMessageId: resolvedParentMessageId,
      oldestMessageId: intercepted.isNotEmpty ? intercepted.first.id : null,
      newestMessageId: intercepted.isNotEmpty ? intercepted.last.id : null,
    );
  }

  /// Handle MessageSentByUser event
  ///
  /// Processes the full inProgress → sent/error lifecycle inside the BLoC
  /// event queue, eliminating race conditions that caused duplicate messages
  /// when the listener callback ran synchronous lookups against stale state.
  Future<void> _onMessageSentByUser(
    MessageSentByUser event,
    Emitter<MessageListState> emit,
  ) async {
    final message = event.message;
    final statusStr = event.status;
    final isInProgress =
        statusStr == core_enums.MessageStatus.inProgress.toString();
    final isSent = statusStr == core_enums.MessageStatus.sent.toString();
    final isError = statusStr == core_enums.MessageStatus.error.toString();

    if (isInProgress) {
      // Clear the "New Messages" indicator — user is actively sending,
      // so they've seen the conversation.
      if (state.unreadMessageAnchorId != null) {
        _skipNextUnreadDetection = true;
        emit(state.copyWithCleared(clearUnreadState: true));
      }

      // Check if message already exists
      if (message.muid.isNotEmpty &&
          findMessageIndexByMuid(message.muid) != null) {
        return;
      }
      if (message.id > 0 && findMessageIndex(message.id) != null) {
        return;
      }

      // Check type/category filters
      if (!_passesTypeAndCategoryFilters(message)) return;

      // Don't add if user has scrolled up
      if (state.hasMoreNewer) return;

      // Interceptor: allow subclass to filter/transform
      final intercepted = onBeforeMessageAdded(message);
      if (intercepted == null) return;

      // Add pending message to list
      final insertIndex = state.messages.length;
      final updatedMessages = [...state.messages, intercepted];
      _addToIndexMaps(intercepted, insertIndex);

      // Create receipt notifier with sending status
      if (intercepted.muid.isNotEmpty) {
        _receiptNotifiersByMuid[intercepted.muid] =
            ValueNotifier<MessageReceiptStatus>(MessageReceiptStatus.sending);
      }

      final newStatus = state.status == MessageListStatus.empty
          ? MessageListStatus.loaded
          : state.status;

      emit(state.copyWith(status: newStatus, messages: updatedMessages));

      _operationsController.add(
        MessageOperation.insert(intercepted, insertIndex, animated: true),
      );

      onAfterMessageAdded(intercepted, insertIndex);
    } else if (isSent) {
      // Find the pending message by muid — try O(1) map lookup first
      int? existingIndex = message.muid.isNotEmpty
          ? findMessageIndexByMuid(message.muid)
          : null;

      // Fallback: O(n) scan if map lookup failed (handles edge cases where
      // _mapNeedsRebuild or concurrent events caused the map to be stale)
      if (existingIndex == null && message.muid.isNotEmpty) {
        for (int i = 0; i < state.messages.length; i++) {
          if (state.messages[i].muid == message.muid) {
            existingIndex = i;
            break;
          }
        }
      }

      // Last resort: if muid is empty on the sent message (SDK didn't preserve it),
      // scan backwards for the most recent pending message (id <= 0).
      // This handles the case where the SDK response object has an empty muid.
      if (existingIndex == null && message.muid.isEmpty && message.id > 0) {
        for (int i = state.messages.length - 1; i >= 0; i--) {
          if (state.messages[i].id <= 0) {
            existingIndex = i;
            break;
          }
        }
      }

      if (existingIndex != null && existingIndex < state.messages.length) {
        // Update the pending message in place
        final oldMessage = state.messages[existingIndex];

        // Race-condition guard: the moderation socket event may arrive and
        // update `moderationStatus` to `disapproved` before the `sent` UI
        // event fires with its older snapshot (still `pending`). Carry the
        // stronger moderation state forward so we don't regress.
        final preservedMessage = _preserveModerationStatus(oldMessage, message);

        // Interceptor: allow subclass to filter/transform
        final intercepted = onBeforeMessageUpdated(
          oldMessage,
          preservedMessage,
        );
        if (intercepted == null) return;

        // Migrate receipt notifier
        if (intercepted.muid.isNotEmpty && intercepted.id > 0) {
          final notifier =
              _receiptNotifiersByMuid.remove(intercepted.muid) ??
              ValueNotifier<MessageReceiptStatus>(MessageReceiptStatus.sent);
          notifier.value = MessageReceiptStatus.sent;
          _receiptNotifiers[intercepted.id] = notifier;
        }

        // Update index maps
        _removeFromIndexMaps(oldMessage);
        _addToIndexMaps(intercepted, existingIndex);

        // Replace message in list
        final updatedMessages = List<BaseMessage>.from(state.messages);
        updatedMessages[existingIndex] = intercepted;
        emit(state.copyWith(messages: updatedMessages));

        _operationsController.add(
          MessageOperation.update(oldMessage, intercepted, existingIndex),
        );

        onAfterMessageUpdated(oldMessage, intercepted, existingIndex);
      } else {
        // Pending message not found — check by ID to avoid adding a duplicate
        final existingById = message.id > 0
            ? findMessageIndex(message.id)
            : null;
        if (existingById != null) {
          return;
        }

        // Also do an O(n) ID scan as safety net (in case map is stale)
        if (message.id > 0) {
          for (int i = 0; i < state.messages.length; i++) {
            if (state.messages[i].id == message.id) {
              return;
            }
          }
        }

        // Check filters
        if (!_passesTypeAndCategoryFilters(message)) return;
        if (state.hasMoreNewer) return;

        // Add as new sent message
        final insertIndex = state.messages.length;
        final updatedMessages = [...state.messages, message];
        _addToIndexMaps(message, insertIndex);

        if (message.id > 0) {
          _receiptNotifiers[message.id] = ValueNotifier<MessageReceiptStatus>(
            MessageReceiptStatus.sent,
          );
        }

        final newStatus = state.status == MessageListStatus.empty
            ? MessageListStatus.loaded
            : state.status;

        emit(state.copyWith(status: newStatus, messages: updatedMessages));

        _operationsController.add(
          MessageOperation.insert(message, insertIndex, animated: true),
        );
      }
    } else if (isError) {
      // Find the pending message by muid — try O(1) map lookup first
      int? existingIndex = message.muid.isNotEmpty
          ? findMessageIndexByMuid(message.muid)
          : null;

      // Fallback: O(n) scan if map lookup failed
      if (existingIndex == null && message.muid.isNotEmpty) {
        for (int i = 0; i < state.messages.length; i++) {
          if (state.messages[i].muid == message.muid) {
            existingIndex = i;
            break;
          }
        }
      }

      if (existingIndex != null && existingIndex < state.messages.length) {
        final oldMessage = state.messages[existingIndex];

        // Update receipt notifier to error
        if (message.muid.isNotEmpty) {
          final notifier = _receiptNotifiersByMuid[message.muid];
          if (notifier != null) {
            notifier.value = MessageReceiptStatus.error;
          }
        }

        // Update index maps if ID changed
        if (oldMessage.id != message.id) {
          _removeFromIndexMaps(oldMessage);
          _addToIndexMaps(message, existingIndex);
        }

        // Replace message in list
        final updatedMessages = List<BaseMessage>.from(state.messages);
        updatedMessages[existingIndex] = message;
        emit(state.copyWith(messages: updatedMessages));

        _operationsController.add(
          MessageOperation.update(oldMessage, message, existingIndex),
        );
      }
    }
  }

  /// Handle message edited by logged-in user (from UI events). Fires on the
  /// `success` status — which the composer sends both optimistically (right
  /// after submit, with editedAt stamped) and again with the authoritative
  /// server message; the second reconciles the first via [_onMessageEdited]'s
  /// id/muid replacement. (`inProgress` means "populate the composer to edit
  /// this message" and is deliberately ignored here.)
  void _handleCCMessageEdited(BaseMessage message, dynamic status) {
    if (isClosed) return;
    // Use string comparison for reliable dynamic type comparison
    final statusStr = status.toString();
    final expectedStatus = core_enums.MessageEditStatus.success.toString();
    if (statusStr == expectedStatus) {
      add(MessageEdited(message));
    }
  }

  /// Handle message deleted by logged-in user (from UI events)
  void _handleCCMessageDeleted(BaseMessage message, dynamic status) {
    if (isClosed) return;
    // Use string comparison for reliable dynamic type comparison
    final statusStr = status.toString();
    if (statusStr == core_enums.EventStatus.success.toString()) {
      add(MessageDeleted(message));
    }
  }

  // ============================================================
  // EVENT HANDLERS
  // ============================================================

  /// Handle LoadMessages event
  ///
  /// Loads initial messages for a conversation. Emits loading state,
  /// fetches messages via use case, and emits loaded/empty/error states.
  /// Also initializes MessagesRequest for pagination.
  ///
  /// **Validates: Requirements 6.1**
  Future<void> _onLoadMessages(
    LoadMessages event,
    Emitter<MessageListState> emit,
  ) async {
    // Emit loading state
    emit(state.copyWith(status: MessageListStatus.loading));

    // Use cached logged-in user from UIKit level (avoids redundant platform channel calls)
    _loggedInUser ??= CometChatUIKit.loggedInUser;

    // Call getMessagesUseCase
    final result = await getMessagesUseCase(
      conversationWith: event.conversationWith,
      conversationType: event.conversationType,
      parentMessageId: event.parentMessageId ?? parentMessageId,
      types: event.types ?? types,
      categories: event.categories ?? categories,
      hideReplies: hideReplies,
      withParent: withParent,
    );

    // Handle Success/Failure results
    // Extract messages from result for post-fold async processing
    List<BaseMessage>? loadedMessages0;
    result.fold(
      (failure) {
        // Emit error state
        emit(
          state.copyWith(
            status: MessageListStatus.error,
            errorMessage: failure.message,
          ),
        );
      },
      (messages) {
        loadedMessages0 = messages;
        if (messages.isEmpty) {
          // Emit empty state
          emit(
            state.copyWith(
              status: MessageListStatus.empty,
              messages: [],
              hasMoreOlder: false,
              loggedInUser: _loggedInUser,
            ),
          );
        } else {
          // Interceptor: allow subclass to filter/transform the loaded messages
          final intercepted = onBeforeMessagesSet(messages);
          if (intercepted == null) return;

          // Mark maps for rebuild
          _mapNeedsRebuild = true;

          // Initialize thread reply counts from loaded messages
          for (final message in intercepted) {
            if (message.replyCount > 0) {
              initializeThreadReplyCount(message.id, message.replyCount);
            }
          }

          // Emit loaded state
          emit(
            state.copyWith(
              status: MessageListStatus.loaded,
              messages: intercepted,
              hasMoreOlder: intercepted.length >= 30,
              hasMoreNewer: false,
              loggedInUser: _loggedInUser,
            ),
          );

          // Emit set operation for animated list
          if (!_operationsController.isClosed) {
            _operationsController.add(
              MessageOperation.set(intercepted, animated: true),
            );
          }

          onAfterMessagesSet(intercepted);
        }

        // Initialize MessagesRequest for pagination
        _initializeMessagesRequests(
          conversationWith: event.conversationWith,
          conversationType: event.conversationType,
          parentMessageId: event.parentMessageId ?? parentMessageId,
          types: event.types ?? types,
          categories: event.categories ?? categories,
          oldestMessageId: messages.isNotEmpty ? messages.first.id : null,
          newestMessageId: messages.isNotEmpty ? messages.last.id : null,
        );
      },
    );

    // Post-fold async processing: unread anchor detection + mark as read.
    // This runs in the async _onLoadMessages context where await works.
    final loadedMessages = loadedMessages0;
    if (loadedMessages == null || loadedMessages.isEmpty) {
      return;
    }

    // Detect unread anchor BEFORE marking as read so we get accurate
    // server-side unread counts. After MarkMessageAsRead the server
    // clears the count, but we need the pre-read values for the
    // "New Messages" indicator on first open.
    if (_skipNextUnreadDetection) {
      _skipNextUnreadDetection = false;
    } else if (state.status == MessageListStatus.loaded &&
        _loggedInUser != null &&
        parentMessageId == null &&
        state.unreadMessageAnchorId == null) {
      final convResult = await getMessagesUseCase.repository.getConversation(
        conversationWith: event.conversationWith,
        conversationType: event.conversationType,
      );
      convResult.fold(
        (_) {}, // ignore failure — indicator is optional
        (conversation) {
          final lastReadId = conversation.lastReadMessageId ?? 0;
          final unreadCnt = conversation.unreadMessageCount;
          if (lastReadId > 0 && unreadCnt > 0) {
            BaseMessage? anchor;
            for (final msg in state.messages) {
              if (msg.sender?.uid == _loggedInUser?.uid) continue;
              if (msg.deletedAt != null) continue;
              if (msg.parentMessageId > 0) continue;
              if (msg.category == MessageCategoryConstants.action) continue;
              if (msg.id > lastReadId) {
                anchor = msg;
                break;
              }
            }
            if (anchor != null) {
              emit(
                state.copyWith(
                  unreadMessageAnchor: anchor,
                  unreadMessageAnchorId: anchor.id,
                  lastReadMessageId: lastReadId,
                  unreadCount: unreadCnt,
                  conversation: conversation,
                ),
              );
              // Notify the animated list to rebuild so the indicator appears
              notifyListChanged();
            }
          }
        },
      );
    }

    // Now mark as read — this clears the server-side unread count.
    if (!disableReceipts && _loggedInUser != null) {
      final newest = loadedMessages.last;
      if (newest.id > 0) {
        add(MarkMessageAsRead(newest));
      }
    }
  }

  /// Initialize MessagesRequest objects for pagination
  void _initializeMessagesRequests({
    required String conversationWith,
    required String conversationType,
    int? parentMessageId,
    List<String>? types,
    List<String>? categories,
    int? oldestMessageId,
    int? newestMessageId,
  }) {
    // Build request for older messages (fetchPrevious)
    final olderRequestBuilder = MessagesRequestBuilder()
      ..limit = 30
      ..hideReplies = hideReplies;

    if (conversationType == 'user') {
      olderRequestBuilder.uid = conversationWith;
    } else {
      olderRequestBuilder.guid = conversationWith;
    }

    if (parentMessageId != null) {
      olderRequestBuilder.parentMessageId = parentMessageId;
    }

    if (types != null && types.isNotEmpty) {
      olderRequestBuilder.types = types;
    }

    if (categories != null && categories.isNotEmpty) {
      olderRequestBuilder.categories = categories;
    }

    // Set messageId to oldest message so fetchPrevious starts from there
    if (oldestMessageId != null && oldestMessageId > 0) {
      olderRequestBuilder.messageId = oldestMessageId;
    }

    _olderMessagesRequest = olderRequestBuilder.build();

    // Build request for newer messages (fetchNext)
    final newerRequestBuilder = MessagesRequestBuilder()
      ..limit = 30
      ..hideReplies = hideReplies;

    if (conversationType == 'user') {
      newerRequestBuilder.uid = conversationWith;
    } else {
      newerRequestBuilder.guid = conversationWith;
    }

    if (parentMessageId != null) {
      newerRequestBuilder.parentMessageId = parentMessageId;
    }

    if (types != null && types.isNotEmpty) {
      newerRequestBuilder.types = types;
    }

    if (categories != null && categories.isNotEmpty) {
      newerRequestBuilder.categories = categories;
    }

    // Set messageId to newest message so fetchNext starts from there
    if (newestMessageId != null && newestMessageId > 0) {
      newerRequestBuilder.messageId = newestMessageId;
    }

    _newerMessagesRequest = newerRequestBuilder.build();
  }

  /// Handle LoadOlderMessages event
  ///
  /// Loads older messages for pagination (scroll up). Checks flags,
  /// emits loading state, fetches messages, prepends to list, and
  /// emits operations for animated list.
  ///
  /// **Validates: Requirements 6.2, 11.1, 11.6**
  Future<void> _onLoadOlderMessages(
    LoadOlderMessages event,
    Emitter<MessageListState> emit,
  ) async {
    // Check hasMoreOlder and isLoadingOlder flags
    if (!state.hasMoreOlder || state.isLoadingOlder) {
      return;
    }

    // Check if request is initialized
    if (_olderMessagesRequest == null) {
      return;
    }

    // Emit isLoadingOlder state
    emit(state.copyWith(isLoadingOlder: true));

    // Call loadOlderMessagesUseCase
    final result = await loadOlderMessagesUseCase(
      request: _olderMessagesRequest!,
    );

    result.fold(
      (failure) {
        // Emit error but keep existing messages
        emit(
          state.copyWith(isLoadingOlder: false, errorMessage: failure.message),
        );
      },
      (olderMessages) {
        if (olderMessages.isEmpty) {
          // No more older messages - update hasMoreOlder flag
          emit(state.copyWith(isLoadingOlder: false, hasMoreOlder: false));
        } else {
          // Interceptor: allow subclass to filter/transform
          final intercepted = onBeforeMessagesSet([
            ...olderMessages,
            ...state.messages,
          ]);
          if (intercepted == null) return;

          // Mark maps for rebuild (prepending changes all indices)
          _mapNeedsRebuild = true;

          final hasMore = olderMessages.length >= 30;

          emit(
            state.copyWith(
              isLoadingOlder: false,
              messages: intercepted,
              hasMoreOlder: hasMore,
            ),
          );

          // Emit insertAll operation for animated list (prepend at index 0)
          if (!_operationsController.isClosed) {
            _operationsController.add(
              MessageOperation.insertAll(olderMessages, 0, animated: false),
            );
          }

          onAfterMessagesSet(intercepted);
        }
      },
    );
  }

  /// Handle LoadNewerMessages event
  ///
  /// Loads newer messages for pagination (scroll down in jump-to-message scenarios).
  /// Checks flags, emits loading state, fetches messages, appends to list,
  /// and emits operations for animated list.
  ///
  /// **Validates: Requirements 6.3, 11.2, 11.7**
  Future<void> _onLoadNewerMessages(
    LoadNewerMessages event,
    Emitter<MessageListState> emit,
  ) async {
    // Check hasMoreNewer and isLoadingNewer flags
    if (!state.hasMoreNewer || state.isLoadingNewer) {
      // Emit to unblock any stream listeners waiting for state change
      emit(
        state.copyWith(isLoadingNewer: false, hasMoreNewer: state.hasMoreNewer),
      );
      return;
    }

    // Check if request is initialized
    if (_newerMessagesRequest == null) {
      emit(state.copyWith(isLoadingNewer: false, hasMoreNewer: false));
      return;
    }

    // Emit isLoadingNewer state
    emit(state.copyWith(isLoadingNewer: true));

    // Call loadNewerMessagesUseCase
    final result = await loadNewerMessagesUseCase(
      request: _newerMessagesRequest!,
    );

    result.fold(
      (failure) {
        // Emit error but keep existing messages
        emit(
          state.copyWith(isLoadingNewer: false, errorMessage: failure.message),
        );
      },
      (newerMessages) {
        if (newerMessages.isEmpty) {
          // No more newer messages - update hasMoreNewer flag
          emit(state.copyWith(isLoadingNewer: false, hasMoreNewer: false));
        } else {
          // Interceptor: allow subclass to filter/transform
          final combined = [...state.messages, ...newerMessages];
          final intercepted = onBeforeMessagesSet(combined);
          if (intercepted == null) return;

          // Mark maps for rebuild
          _mapNeedsRebuild = true;

          final hasMore = newerMessages.length >= 30;

          emit(
            state.copyWith(
              isLoadingNewer: false,
              messages: intercepted,
              hasMoreNewer: hasMore,
            ),
          );

          // Emit insertAll operation for animated list (append at end)
          if (!_operationsController.isClosed) {
            _operationsController.add(
              MessageOperation.insertAll(
                newerMessages,
                state.messages.length - newerMessages.length,
                animated: false,
              ),
            );
          }

          onAfterMessagesSet(intercepted);
        }
      },
    );
  }

  /// Handle RefreshMessages event
  ///
  /// Clears existing messages and reloads from the server.
  Future<void> _onRefreshMessages(
    RefreshMessages event,
    Emitter<MessageListState> emit,
  ) async {
    // Clear existing state
    _mapNeedsRebuild = true;
    _olderMessagesRequest = null;
    _newerMessagesRequest = null;

    // Dispatch LoadMessages event with current configuration
    if (conversationWith != null) {
      add(
        LoadMessages(
          conversationWith: conversationWith!,
          conversationType: conversationType,
          parentMessageId: parentMessageId,
          types: types,
          categories: categories,
        ),
      );
    }
  }

  /// Handle SyncMessages event
  ///
  /// Silently fetches any messages newer than the latest message in the list
  /// without changing the status (no loader). Used on app foreground resume
  /// and SDK reconnection to avoid a jarring full-reload with spinner.
  /// Falls back to a full [RefreshMessages] if the list is empty/not loaded.
  Future<void> _onSyncMessages(
    SyncMessages event,
    Emitter<MessageListState> emit,
  ) async {
    // If list isn't loaded yet, fall back to normal load.
    // But if the list is loaded and simply empty (e.g., new conversation with
    // conversation starters), do NOT re-fetch — the empty state is intentional.
    if (state.status != MessageListStatus.loaded) {
      if (conversationWith != null) {
        add(
          LoadMessages(
            conversationWith: conversationWith!,
            conversationType: conversationType,
            parentMessageId: parentMessageId,
            types: types,
            categories: categories,
          ),
        );
      }
      return;
    }

    // List is loaded but empty — nothing to sync from, and the empty state
    // is intentional (new conversation). Don't trigger a full re-fetch.
    if (state.messages.isEmpty) {
      return;
    }

    // Build a fresh request starting from the newest message in the list
    final newestMessageId = state.messages.last.id;
    if (newestMessageId <= 0 || conversationWith == null) return;

    final syncRequestBuilder = MessagesRequestBuilder()
      ..limit = 30
      ..hideReplies = hideReplies
      ..messageId = newestMessageId;

    if (conversationType == 'user') {
      syncRequestBuilder.uid = conversationWith;
    } else {
      syncRequestBuilder.guid = conversationWith;
    }

    if (parentMessageId != null) {
      syncRequestBuilder.parentMessageId = parentMessageId;
    }

    if (types != null && types!.isNotEmpty) {
      syncRequestBuilder.types = types;
    }

    if (categories != null && categories!.isNotEmpty) {
      syncRequestBuilder.categories = categories;
    }

    final request = syncRequestBuilder.build();

    // Fetch newer messages silently — no status change, no loader
    final result = await loadNewerMessagesUseCase(request: request);

    result.fold((failure) {}, (newerMessages) {
      if (newerMessages.isEmpty) return;

      // Append to list
      final updatedMessages = [...state.messages, ...newerMessages];

      // Interceptor: allow subclass to filter/transform
      final intercepted = onBeforeMessagesSet(updatedMessages);
      if (intercepted == null) return;

      // Mark maps for rebuild
      _mapNeedsRebuild = true;

      // Reinitialize the newer messages request from the new newest message
      _initializeMessagesRequests(
        conversationWith: conversationWith!,
        conversationType: conversationType,
        parentMessageId: parentMessageId,
        types: types,
        categories: categories,
        oldestMessageId: intercepted.first.id,
        newestMessageId: intercepted.last.id,
      );

      // Emit updated state silently — status stays 'loaded'
      emit(
        state.copyWith(
          messages: intercepted,
          hasMoreNewer: newerMessages.length >= 30,
        ),
      );

      onAfterMessagesSet(intercepted);

      // Emit insert operation for animated list (silent, no animation)
      if (!_operationsController.isClosed) {
        _operationsController.add(
          MessageOperation.set(intercepted, animated: false),
        );
      }

      // Mark the newest message as read
      if (!disableReceipts && _loggedInUser != null && intercepted.isNotEmpty) {
        final newest = intercepted.last;
        if (newest.id > 0) {
          add(MarkMessageAsRead(newest));
        }
      }
    });
  }

  /// Handle JumpToMessage event
  ///
  /// Fetches messages around a target message ID, replaces the current list,
  /// Jump to a specific message by fetching messages around it.
  ///
  /// Fetch order optimized for reversed lists:
  /// 1. Fetch target + newer first → set list → widget scrolls behind shimmer
  /// 2. Fetch older → insertAll at index 0 (no scroll shift in reversed list)
  Future<void> _onJumpToMessage(
    JumpToMessage event,
    Emitter<MessageListState> emit,
  ) async {
    final targetId = event.messageId;
    final convWith = conversationWith;
    if (convWith == null) return;

    // Use cached logged-in user from UIKit level
    _loggedInUser ??= CometChatUIKit.loggedInUser;

    // 1. Get the target message details first
    BaseMessage? targetMessage;
    try {
      targetMessage = await CometChatHelper.getMessageDetails(
        targetId,
        onSuccess: (message) => message,
        onError: (e) {},
      );
    } catch (_) {
      // Non-fatal; intentionally ignored.
    }

    if (targetMessage == null) {
      return;
    }

    // 2. Fetch newer messages (after the target)
    final newerBuilder = MessagesRequestBuilder()
      ..limit = 30
      ..messageId = targetId
      ..hideReplies = hideReplies;
    if (user != null) {
      newerBuilder.uid = convWith;
    } else {
      newerBuilder.guid = convWith;
    }
    if (parentMessageId != null) {
      newerBuilder.parentMessageId = parentMessageId!;
    }
    if (types != null && types!.isNotEmpty) {
      newerBuilder.types = types!;
    }
    if (categories != null && categories!.isNotEmpty) {
      newerBuilder.categories = categories!;
    }

    final newerResult = await loadNewerMessagesUseCase(
      request: newerBuilder.build(),
    );

    List<BaseMessage> newerMessages = [];
    newerResult.fold((failure) {}, (messages) {
      newerMessages = messages;
    });

    // 3. Set list with [target, ...newer] — widget starts building frames
    final initialList = [targetMessage, ...newerMessages];

    // Interceptor: allow subclass to filter/transform
    final intercepted = onBeforeMessagesSet(initialList);
    if (intercepted == null || intercepted.isEmpty) return;

    _mapNeedsRebuild = true;

    for (final message in intercepted) {
      if (message.replyCount > 0) {
        initializeThreadReplyCount(message.id, message.replyCount);
      }
    }

    emit(
      state.copyWith(
        status: MessageListStatus.loaded,
        messages: intercepted,
        hasMoreOlder: true,
        hasMoreNewer: newerMessages.length >= 30,
        loggedInUser: _loggedInUser,
      ),
    );

    if (!_operationsController.isClosed) {
      _operationsController.add(
        MessageOperation.set(intercepted, animated: false),
      );
    }

    onAfterMessagesSet(intercepted);

    // 4. Fetch older messages in the background
    final olderBuilder = MessagesRequestBuilder()
      ..limit = 30
      ..messageId = targetId
      ..hideReplies = hideReplies;
    if (user != null) {
      olderBuilder.uid = convWith;
    } else {
      olderBuilder.guid = convWith;
    }
    if (parentMessageId != null) {
      olderBuilder.parentMessageId = parentMessageId!;
    }
    if (types != null && types!.isNotEmpty) {
      olderBuilder.types = types!;
    }
    if (categories != null && categories!.isNotEmpty) {
      olderBuilder.categories = categories!;
    }

    final olderResult = await loadOlderMessagesUseCase(
      request: olderBuilder.build(),
    );

    List<BaseMessage> olderMessages = [];
    olderResult.fold((failure) {}, (messages) {
      olderMessages = messages;
    });

    // 5. Prepend older at index 0 — reversed list adds above viewport
    if (olderMessages.isNotEmpty) {
      _mapNeedsRebuild = true;

      for (final message in olderMessages) {
        if (message.replyCount > 0) {
          initializeThreadReplyCount(message.id, message.replyCount);
        }
      }

      final combined = [...olderMessages, ...state.messages];
      final interceptedCombined = onBeforeMessagesSet(combined);
      if (interceptedCombined != null) {
        _mapNeedsRebuild = true;
        emit(
          state.copyWith(
            messages: interceptedCombined,
            hasMoreOlder: olderMessages.length >= 30,
          ),
        );

        if (!_operationsController.isClosed) {
          _operationsController.add(
            MessageOperation.insertAll(olderMessages, 0, animated: false),
          );
        }

        onAfterMessagesSet(interceptedCombined);
      }
    } else {
      emit(state.copyWith(hasMoreOlder: false));
    }

    // 6. Reinitialize pagination
    final allMessages = state.messages;
    if (allMessages.isNotEmpty) {
      _initializeMessagesRequests(
        conversationWith: convWith,
        conversationType: conversationType,
        parentMessageId: parentMessageId,
        types: types,
        categories: categories,
        oldestMessageId: allMessages.first.id,
        newestMessageId: allMessages.last.id,
      );
    }

    // 7. Mark as read
    if (!disableReceipts && _loggedInUser != null) {
      final newest = allMessages.isNotEmpty ? allMessages.last : targetMessage;
      if (newest.id > 0) {
        add(MarkMessageAsRead(newest));
      }
    }
  }

  /// Plays the incoming-message sound for a message from someone else in this
  /// conversation. The conversations list stays silent for the open
  /// conversation and leaves the sound to this list.
  ///
  /// Silent when [disableSoundForMessages] is on, and for custom messages that
  /// don't count as unread — the same rule the conversations list applies.
  void _playIncomingMessageSound(BaseMessage message) {
    if (disableSoundForMessages) return;
    if (message.sender?.uid == _loggedInUser?.uid) return;
    if (message is CustomMessage &&
        message.metadata?[UpdateSettingsConstant.incrementUnreadCount] !=
            true) {
      return;
    }
    CometChatUIKit.soundManager.play(
      sound: Sound.incomingMessage,
      customSound: customSoundForMessages,
      packageName: customSoundForMessagePackage,
    );
  }

  /// Handle MessageReceived event
  ///
  /// Adds a received message to the list if it belongs to the current
  /// conversation and passes type/category filters.
  ///
  /// **Validates: Requirements 6.4, 15.3, 15.4, 16.4**
  Future<void> _onMessageReceived(
    MessageReceived event,
    Emitter<MessageListState> emit,
  ) async {
    final message = event.message;

    // Nothing is shown until LoadMessages runs, and its fetch includes anything
    // delivered before then — so there is nothing to merge into yet. Accepting
    // the message here left a list holding messages with status `initial`.
    if (state.status == MessageListStatus.initial) return;

    ccLog(
      '[MessageListBloc] Message received: id=${message.id}, '
      'category=${message.category}, type=${message.type}, '
      'sender=${message.sender?.uid}, '
      'class=${message.runtimeType}',
    );

    // For AI assistant messages, replace the thinking/stream bubble
    if (message is AIAssistantMessage && message.runId != null) {
      final thinkingId = -(message.runId!);
      // Scan for thinking bubble (negative IDs may not be in index map)
      for (int i = 0; i < state.messages.length; i++) {
        if (state.messages[i].id == thinkingId) {
          final thinkingMsg = state.messages[i];
          _streamService.removeMessageById(thinkingId);
          _streamService.stopStreamingForRunId(message.runId!);
          final updatedMessages = List<BaseMessage>.from(state.messages);
          updatedMessages[i] = message;
          emit(
            state.copyWith(
              messages: updatedMessages,
              status: MessageListStatus.loaded,
            ),
          );
          _rebuildIndexMaps();
          _operationsController.add(
            MessageOperation.update(thinkingMsg, message, i),
          );
          // Notify composer that streaming is complete (restore send button)
          CometChatStreamCallBackEvents.ccStreamCompleted(true);
          return;
        }
      }
    }

    // Check if message belongs to current conversation
    final belongsHere = message is Call
        ? _isCallForCurrentConversation(message)
        : _isMessageForCurrentConversation(message);
    if (!belongsHere) {
      ccLog(
        '[MessageListBloc] Message FILTERED: not for current conversation. '
        'message.conversationId=${message.conversationId}',
      );
      return;
    }

    // Check parentMessageId for threads
    if (parentMessageId != null) {
      // In thread mode - only accept messages with matching parentMessageId
      if (message.parentMessageId != parentMessageId) {
        return;
      }
    } else {
      // In main conversation mode
      if (message.parentMessageId > 0) {
        // For AI users, accept all messages regardless of parentMessageId
        // (AI conversations use threading but display flat in the main view)
        final isAI = user?.role == 'ai' || user?.role == AIConstants.aiRole;
        if (!isAI) {
          // Subscription mirrors first — the first-reply test reads the
          // parent's replyCount, so it must see the PRE-increment value.
          _applyThreadSubscriptionMirrors(message);

          // This is a thread reply - increment the parent message's reply count
          // **Validates: Requirements 15.4**
          _incrementThreadReplyCount(message.parentMessageId);

          // Skip adding to list if hideReplies is true
          if (hideReplies) {
            _playIncomingMessageSound(message);
            return;
          }
        }
      }
    }

    // Mention-arrival mirror for ROOT messages (replies were handled above,
    // before the reply-count increment).
    if (message.parentMessageId == 0) {
      _applyThreadSubscriptionMirrors(message);
    }

    // Check message type/category filters
    if (!_passesTypeAndCategoryFilters(message)) {
      ccLog(
        '[MessageListBloc] Message FILTERED: type/category filter failed. '
        'category=${message.category}, type=${message.type}, '
        'allowedCategories=$categories',
      );
      return;
    }

    // Check if message already exists (by ID or muid).
    // For server-originated updates (polls, interactive messages), the SDK may
    // fire onCustomMessageReceived with the same message ID but updated metadata.
    // In that case, treat it as an edit rather than dropping it.
    if (message.id > 0) {
      final existingIndex = findMessageIndex(message.id);
      if (existingIndex != null) {
        // If the incoming message is a custom/interactive message with updated
        // metadata (e.g. poll vote, form submission), update the existing
        // message in-place.
        //
        // Calls too. A call keeps one id for its whole life while its status
        // moves on — initiated, then declined / cancelled / answered / ended —
        // and each step arrives as the same id. Dropping it as a duplicate
        // froze the bubble at its first status, so a declined call never read
        // as declined (ENG-39486). Kotlin updates call bubbles by id for the
        // same reason.
        if (message is CustomMessage ||
            message is InteractiveMessage ||
            message is Call) {
          final oldMessage = state.messages[existingIndex];
          final intercepted = onBeforeMessageUpdated(oldMessage, message);
          if (intercepted == null) return;

          final updatedMessages = List<BaseMessage>.from(state.messages);
          updatedMessages[existingIndex] = intercepted;
          emit(state.copyWith(messages: updatedMessages));

          _operationsController.add(
            MessageOperation.update(oldMessage, intercepted, existingIndex),
          );
          onAfterMessageUpdated(oldMessage, intercepted, existingIndex);
        }
        return;
      }
    }
    if (message.muid.isNotEmpty &&
        findMessageIndexByMuid(message.muid) != null) {
      return;
    }

    // O(n) fallback dedup — handles edge cases where index maps are stale
    for (final existing in state.messages) {
      if (message.id > 0 && existing.id == message.id) return;
      if (message.muid.isNotEmpty && existing.muid == message.muid) return;
    }

    // Sound before the scrolled-up check: a message the list holds back until
    // the user returns to the bottom has still arrived.
    _playIncomingMessageSound(message);

    // If user has scrolled up (hasMoreNewer = true), don't append new messages
    // This prevents messages from appearing while user is viewing older messages
    if (state.hasMoreNewer) {
      ccLog(
        '[MessageListBloc] Message FILTERED: hasMoreNewer=true (user scrolled up)',
      );
      return;
    }

    // Interceptor: allow subclass to filter/transform
    final intercepted = onBeforeMessageAdded(message);
    if (intercepted == null) return;

    // Add message to end of list (newest messages at end)
    final insertIndex = state.messages.length;
    final updatedMessages = [...state.messages, intercepted];

    ccLog(
      '[MessageListBloc] Adding message to list: id=${intercepted.id}, '
      'category=${intercepted.category}, type=${intercepted.type}, '
      'insertIndex=$insertIndex',
    );

    // Update index maps incrementally
    _addToIndexMaps(intercepted, insertIndex);

    // Update state
    final newStatus = state.status == MessageListStatus.empty
        ? MessageListStatus.loaded
        : state.status;

    emit(state.copyWith(status: newStatus, messages: updatedMessages));

    // Emit insert operation for animated list
    _operationsController.add(
      MessageOperation.insert(intercepted, insertIndex, animated: true),
    );

    onAfterMessageAdded(intercepted, insertIndex);

    // Mark incoming message as read since the conversation is open
    if (!disableReceipts &&
        intercepted.sender?.uid != _loggedInUser?.uid &&
        intercepted.id > 0) {
      add(MarkMessageAsRead(intercepted));
    } else {}
  }

  /// Handle MessageEdited event
  ///
  /// Updates an existing message in the list using O(1) lookup.
  ///
  /// First tries to find by message ID, then falls back to muid lookup.
  /// This handles both regular edits (by ID) and status updates for sent messages (by muid).
  ///
  /// **Validates: Requirements 6.5**
  /// Pin & Save: merges a pin/save change into the row already in the list.
  ///
  /// The incoming payload only speaks for its own feature — a pin frame
  /// carries no savedAt — so the flags it does not own are carried over from
  /// the row being replaced. Without this, pinning a message you had saved
  /// would drop its bookmark from the bubble until the next refetch.
  Future<void> _onMessagePinSaveChanged(
    MessagePinSaveChanged event,
    Emitter<MessageListState> emit,
  ) async {
    final incoming = event.message;
    final index = findMessageIndex(incoming.id);
    if (index == null || index >= state.messages.length) return;

    final oldMessage = state.messages[index];
    if (event.isPinScope) {
      incoming.savedAt ??= oldMessage.savedAt;
    } else {
      incoming.pinnedAt ??= oldMessage.pinnedAt;
      incoming.pinnedBy ??= oldMessage.pinnedBy;
    }

    add(MessageEdited(incoming));
  }

  Future<void> _onMessageEdited(
    MessageEdited event,
    Emitter<MessageListState> emit,
  ) async {
    final editedMessage = event.message;
    // First try to find message by ID using O(1) lookup
    int? index = findMessageIndex(editedMessage.id);

    // If not found by ID, try by muid (for inProgress -> sent transitions)
    if ((index == null || index >= state.messages.length) &&
        editedMessage.muid.isNotEmpty) {
      index = findMessageIndexByMuid(editedMessage.muid);
    }

    if (index == null || index >= state.messages.length) {
      return;
    }

    final oldMessage = state.messages[index];

    // Race-condition guard: never regress from a terminal moderation state
    // (approved/disapproved) back to pending or null.
    final preservedMessage = _preserveModerationStatus(
      oldMessage,
      editedMessage,
    );

    // Interceptor: allow subclass to filter/transform
    final intercepted = onBeforeMessageUpdated(oldMessage, preservedMessage);
    if (intercepted == null) return;

    // Update index maps if the message ID changed (pending -> sent)
    if (oldMessage.id != intercepted.id) {
      _removeFromIndexMaps(oldMessage);
      _addToIndexMaps(intercepted, index);
    }

    // Update message in list
    final updatedMessages = List<BaseMessage>.from(state.messages);
    updatedMessages[index] = intercepted;

    emit(state.copyWith(messages: updatedMessages));

    // Emit update operation for animated list
    _operationsController.add(
      MessageOperation.update(oldMessage, intercepted, index),
    );

    onAfterMessageUpdated(oldMessage, intercepted, index);
  }

  /// Handle MessageDeleted event
  ///
  /// Removes or marks a message as deleted based on hideDeletedMessages config.
  /// Uses O(1) lookup to find the message.
  ///
  /// **Validates: Requirements 6.6**
  Future<void> _onMessageDeleted(
    MessageDeleted event,
    Emitter<MessageListState> emit,
  ) async {
    final deletedMessage = event.message;
    ccLog(
      '🗑 [delete] event for id=${deletedMessage.id} '
      'muid=${deletedMessage.muid} '
      'batchId=${deletedMessage.metadata?['batchId']}',
    );

    // Find message by ID using O(1) lookup
    final index = findMessageIndex(deletedMessage.id);
    if (index == null || index >= state.messages.length) {
      return;
    }

    final oldMessage = state.messages[index];

    if (hideDeletedMessages) {
      // Interceptor: allow subclass to block removal
      if (!onBeforeMessageRemoved(oldMessage)) return;

      // Remove message from list
      final updatedMessages = List<BaseMessage>.from(state.messages);
      updatedMessages.removeAt(index);

      // Update index maps - remove and shift
      _removeFromIndexMaps(oldMessage);
      _shiftIndicesAfterRemoval(index);

      // Clean up receipt notifiers for the deleted message
      _cleanupReceiptNotifiers(oldMessage);

      // Check if list is now empty
      final newStatus = updatedMessages.isEmpty
          ? MessageListStatus.empty
          : state.status;

      emit(state.copyWith(status: newStatus, messages: updatedMessages));

      // Emit remove operation for animated list
      _operationsController.add(
        MessageOperation.remove(oldMessage, index, animated: true),
      );

      onAfterMessageRemoved(oldMessage);
    } else {
      // Mark message as deleted — preserve the original message object
      oldMessage.deletedAt = deletedMessage.deletedAt ?? DateTime.now();
      oldMessage.deletedBy = deletedMessage.deletedBy;

      // Interceptor: allow subclass to filter/transform
      final intercepted = onBeforeMessageUpdated(oldMessage, oldMessage);
      if (intercepted == null) return;

      final updatedMessages = List<BaseMessage>.from(state.messages);
      updatedMessages[index] = intercepted;

      emit(state.copyWith(messages: updatedMessages));

      // Emit update operation for animated list
      _operationsController.add(
        MessageOperation.update(oldMessage, intercepted, index),
      );

      onAfterMessageUpdated(oldMessage, intercepted, index);
    }

    // Update quotedMessage on any replies that reference the deleted message.
    // This ensures reply previews show "This message was deleted" instead of
    // going blank when the parent message is deleted.
    final deletedId = deletedMessage.id;
    if (deletedId > 0) {
      final currentMessages = state.messages;
      bool anyUpdated = false;
      for (int i = 0; i < currentMessages.length; i++) {
        final msg = currentMessages[i];
        if (msg.quotedMessage != null && msg.quotedMessage!.id == deletedId) {
          msg.quotedMessage!.deletedAt ??=
              deletedMessage.deletedAt ?? DateTime.now();
          anyUpdated = true;
          _operationsController.add(MessageOperation.update(msg, msg, i));
        }
      }
      if (anyUpdated) {
        emit(state.copyWith(messages: List<BaseMessage>.from(state.messages)));
      }
    }
  }

  /// Handle DeliveryReceiptReceived event
  ///
  /// Updates message delivery timestamps and ValueNotifiers for isolated rebuilds.
  /// Note: BaseMessage from CometChat SDK is mutable by design, so we update
  /// the timestamp directly. The ValueNotifier handles isolated UI updates.
  ///
  /// **Validates: Requirements 8.5**
  Future<void> _onDeliveryReceiptReceived(
    DeliveryReceiptReceived event,
    Emitter<MessageListState> emit,
  ) async {
    final receipt = event.receipt;

    // Receipts are cumulative — "delivered up to messageId".
    // Update all outgoing messages with id <= receipt.messageId.
    for (final message in state.messages) {
      if (message.id <= 0) continue;
      if (message.id > receipt.messageId!) continue;
      if (message.sender?.uid != _loggedInUser?.uid) continue;
      if (message.deliveredAt != null) continue; // already delivered

      message.deliveredAt = receipt.deliveredAt;
      final notifier = _receiptNotifiers[message.id];
      if (notifier != null &&
          notifier.value.index < MessageReceiptStatus.delivered.index) {
        notifier.value = MessageReceiptStatus.delivered;
      }
    }
  }

  /// Handle ReadReceiptReceived event
  ///
  /// Updates message read timestamps and ValueNotifiers for isolated rebuilds.
  /// Note: BaseMessage from CometChat SDK is mutable by design, so we update
  /// the timestamp directly. The ValueNotifier handles isolated UI updates.
  ///
  /// **Validates: Requirements 8.6**
  Future<void> _onReadReceiptReceived(
    ReadReceiptReceived event,
    Emitter<MessageListState> emit,
  ) async {
    final receipt = event.receipt;

    // Receipts are cumulative — "read up to messageId".
    // Update all outgoing messages with id <= receipt.messageId.
    for (final message in state.messages) {
      if (message.id <= 0) continue;
      if (message.id > receipt.messageId!) continue;
      if (message.sender?.uid != _loggedInUser?.uid) continue;
      if (message.readAt != null) continue; // already read

      message.readAt = receipt.readAt;
      // Also set deliveredAt if missing (read implies delivered)
      message.deliveredAt ??= receipt.readAt;
      final notifier = _receiptNotifiers[message.id];
      if (notifier != null && notifier.value != MessageReceiptStatus.read) {
        notifier.value = MessageReceiptStatus.read;
      }
    }
  }

  /// Handle MarkMessageAsRead event
  ///
  /// Marks a message as read by calling the use case.
  Future<void> _onMarkMessageAsRead(
    MarkMessageAsRead event,
    Emitter<MessageListState> emit,
  ) async {
    // Skip if receipts are disabled
    if (disableReceipts) {
      return;
    }

    // Call markAsReadUseCase
    final result = await markAsReadUseCase(message: event.message);

    result.fold((failure) {}, (_) {
      // Notify conversations list (and other listeners) so unread count resets
      CometChatMessageEvents.ccMessageRead(event.message);

      // Also clear the server-side unread count for this conversation.
      // markAsRead marks the individual message but does NOT reset the
      // conversation's unreadMessageCount on the server. Without this,
      // refreshing the conversations list will show stale unread badges.
      final convWith = conversationWith;
      if (convWith != null) {
        CometChat.markConversationAsRead(
          convWith,
          conversationType,
          onSuccess: (String result) {},
          onError: (CometChatException e) {},
        );
      }
    });
  }

  /// Handle SetActiveConversation event
  ///
  /// Updates the active conversation ID in state for unread count management.
  void _onSetActiveConversation(
    SetActiveConversation event,
    Emitter<MessageListState> emit,
  ) {
    emit(state.copyWith(activeConversationId: event.conversationId));
  }

  /// Handle AddReaction event
  ///
  /// Adds a reaction to a message via the CometChat SDK.
  Future<void> _onAddReaction(
    AddReaction event,
    Emitter<MessageListState> emit,
  ) async {
    final message = event.message;
    final reaction = event.reaction;

    try {
      // Use Completer to wait for the SDK callback
      final completer = Completer<BaseMessage?>();

      await CometChat.addReaction(
        message.id,
        reaction,
        onSuccess: (BaseMessage updatedMessage) {
          completer.complete(updatedMessage);
        },
        onError: (CometChatException e) {
          completer.complete(null);
        },
      );

      final updatedMessage = await completer.future;
      if (updatedMessage != null) {
        // Update the message in the list
        final index = findMessageIndex(message.id);
        if (index != null && index < state.messages.length) {
          _updateMessageAtIndex(index, message, updatedMessage, emit);
        } else {}
      }
    } catch (_) {
      // Non-fatal; intentionally ignored.
    }
  }

  /// Handle RemoveReaction event
  ///
  /// Removes a reaction from a message via the CometChat SDK.
  Future<void> _onRemoveReaction(
    RemoveReaction event,
    Emitter<MessageListState> emit,
  ) async {
    final message = event.message;
    final reaction = event.reaction;

    try {
      // Use Completer to wait for the SDK callback
      final completer = Completer<BaseMessage?>();

      await CometChat.removeReaction(
        message.id,
        reaction,
        onSuccess: (BaseMessage updatedMessage) {
          completer.complete(updatedMessage);
        },
        onError: (CometChatException e) {
          completer.complete(null);
        },
      );

      final updatedMessage = await completer.future;
      if (updatedMessage != null) {
        // Update the message in the list
        final index = findMessageIndex(message.id);
        if (index != null && index < state.messages.length) {
          _updateMessageAtIndex(index, message, updatedMessage, emit);
        } else {}
      }
    } catch (_) {
      // Non-fatal; intentionally ignored.
    }
  }

  // ============================================================
  // REACTION SDK LISTENER CALLBACKS
  // ============================================================

  /// Handle reaction added from SDK listener
  ///
  /// Dispatches ReactionAddedFromSDK event if reaction belongs to current conversation.
  void _handleMessageReactionAdded(ReactionEvent reactionEvent) {
    if (isClosed) return;

    final reaction = reactionEvent.reaction;
    if (reaction == null) return;

    final messageId = reaction.messageId;
    if (messageId == null) return;

    // Check if reaction is for current conversation
    if (!_isReactionForCurrentConversation(reactionEvent)) return;

    add(
      ReactionAddedFromSDK(
        messageId: messageId,
        reaction: reaction,
        receiverId: reactionEvent.receiverId,
        receiverType: reactionEvent.receiverType,
      ),
    );
  }

  /// Handle reaction removed from SDK listener
  ///
  /// Dispatches ReactionRemovedFromSDK event if reaction belongs to current conversation.
  void _handleMessageReactionRemoved(ReactionEvent reactionEvent) {
    if (isClosed) return;

    final reaction = reactionEvent.reaction;
    if (reaction == null) return;

    final messageId = reaction.messageId;
    if (messageId == null) return;

    // Check if reaction is for current conversation
    if (!_isReactionForCurrentConversation(reactionEvent)) return;

    add(
      ReactionRemovedFromSDK(
        messageId: messageId,
        reaction: reaction,
        receiverId: reactionEvent.receiverId,
        receiverType: reactionEvent.receiverType,
      ),
    );
  }

  /// Check if a reaction event belongs to the current conversation
  bool _isReactionForCurrentConversation(ReactionEvent reactionEvent) {
    final receiverId = reactionEvent.receiverId;
    final receiverType = reactionEvent.receiverType;

    if (user != null && receiverType == 'user') {
      // 1-on-1 conversation - check if receiver or sender matches target user
      final reaction = reactionEvent.reaction;
      final reactedByUid = reaction?.reactedBy?.uid;
      return receiverId == user!.uid ||
          receiverId == _loggedInUser?.uid ||
          reactedByUid == user!.uid;
    } else if (group != null && receiverType == 'group') {
      // Group conversation - check if receiver matches target group
      return receiverId == group!.guid;
    }
    return false;
  }

  /// Handle ReactionAddedFromSDK event
  ///
  /// Updates the message's reactions when a reaction is added via SDK listener.
  Future<void> _onReactionAddedFromSDK(
    ReactionAddedFromSDK event,
    Emitter<MessageListState> emit,
  ) async {
    final messageId = event.messageId;
    final reaction = event.reaction;

    final index = findMessageIndex(messageId);
    if (index == null || index >= state.messages.length) {
      return;
    }

    final message = state.messages[index];
    final updatedMessage = _addReactionToMessage(message, reaction);

    _updateMessageAtIndex(index, message, updatedMessage, emit);
  }

  /// Handle ReactionRemovedFromSDK event
  ///
  /// Updates the message's reactions when a reaction is removed via SDK listener.
  Future<void> _onReactionRemovedFromSDK(
    ReactionRemovedFromSDK event,
    Emitter<MessageListState> emit,
  ) async {
    final messageId = event.messageId;
    final reaction = event.reaction;

    final index = findMessageIndex(messageId);
    if (index == null || index >= state.messages.length) {
      return;
    }

    final message = state.messages[index];
    final updatedMessage = _removeReactionFromMessage(message, reaction);

    _updateMessageAtIndex(index, message, updatedMessage, emit);
  }

  /// Add a reaction to a message's reaction list
  ///
  /// Creates a new message object with updated reactions.
  BaseMessage _addReactionToMessage(BaseMessage message, Reaction reaction) {
    final currentReactions = List<ReactionCount>.from(message.reactions);
    final reactionEmoji = reaction.reaction;

    // Find existing reaction count for this emoji
    final existingIndex = currentReactions.indexWhere(
      (r) => r.reaction == reactionEmoji,
    );

    if (existingIndex != -1) {
      // Increment count for existing reaction
      final existing = currentReactions[existingIndex];
      currentReactions[existingIndex] = ReactionCount(
        reaction: existing.reaction,
        count: (existing.count ?? 0) + 1,
        reactedByMe: reaction.reactedBy?.uid == _loggedInUser?.uid
            ? true
            : existing.reactedByMe,
      );
    } else {
      // Add new reaction
      currentReactions.add(
        ReactionCount(
          reaction: reactionEmoji,
          count: 1,
          reactedByMe: reaction.reactedBy?.uid == _loggedInUser?.uid,
        ),
      );
    }

    // Create updated message with new reactions
    // Note: BaseMessage doesn't have copyWith, so we update reactions directly
    message.reactions = currentReactions;
    return message;
  }

  /// Remove a reaction from a message's reaction list
  ///
  /// Creates a new message object with updated reactions.
  BaseMessage _removeReactionFromMessage(
    BaseMessage message,
    Reaction reaction,
  ) {
    final currentReactions = List<ReactionCount>.from(message.reactions);
    final reactionEmoji = reaction.reaction;

    // Find existing reaction count for this emoji
    final existingIndex = currentReactions.indexWhere(
      (r) => r.reaction == reactionEmoji,
    );

    if (existingIndex != -1) {
      final existing = currentReactions[existingIndex];
      final newCount = (existing.count ?? 1) - 1;

      if (newCount <= 0) {
        // Remove reaction entirely
        currentReactions.removeAt(existingIndex);
      } else {
        // Decrement count
        currentReactions[existingIndex] = ReactionCount(
          reaction: existing.reaction,
          count: newCount,
          reactedByMe: reaction.reactedBy?.uid == _loggedInUser?.uid
              ? false
              : existing.reactedByMe,
        );
      }
    }

    // Update message reactions
    message.reactions = currentReactions;
    return message;
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Check if a message already exists in the list (by id or muid).
  /// Used to distinguish current-device sends (already in list via
  /// ccMessageSent) from other-device sends arriving via SDK listener.
  bool _isMessageAlreadyInList(BaseMessage message) {
    if (message.id > 0 && findMessageIndex(message.id) != null) {
      return true;
    }
    if (message.muid.isNotEmpty &&
        findMessageIndexByMuid(message.muid) != null) {
      return true;
    }
    return false;
  }

  /// Check if a message belongs to the current conversation
  bool _isMessageForCurrentConversation(BaseMessage message) {
    if (user != null) {
      // 1-on-1 conversation — only accept user-type messages
      if (message.receiverType != CometChatReceiverType.user) return false;

      final senderUid = message.sender?.uid;
      final receiverUid = message.receiverUid;
      final userUid = user!.uid;

      // Message is for this conversation if:
      // - Sender is the target user (incoming message)
      // - Receiver is the target user (outgoing message)
      return senderUid == userUid || receiverUid == userUid;
    } else if (group != null) {
      // Group conversation — only accept group-type messages
      if (message.receiverType != CometChatReceiverType.group) return false;

      return message.receiverUid == group!.guid;
    }
    return false;
  }

  /// Whether [call] belongs to this conversation.
  ///
  /// A [Call] is matched on its initiator rather than [BaseMessage.sender]:
  /// the SDK only fills `sender` when the server payload carries one, and the
  /// Call objects handed back by initiate/reject/end — which is what the UI Kit
  /// call events carry — may not. Mirrors Kotlin's `isCallForCurrentChat`,
  /// falling back to the generic check so nothing that matched before stops
  /// matching.
  bool _isCallForCurrentConversation(Call call) {
    if (user != null) {
      final initiator = call.callInitiator;
      final initiatorUid = initiator is User ? initiator.uid : call.sender?.uid;
      final loggedInUid =
          state.loggedInUser?.uid ?? CometChatUIKit.loggedInUser?.uid;
      final targetUid = user!.uid;
      if (call.receiverUid == targetUid) return true;
      if (initiatorUid == targetUid &&
          (loggedInUid == null || call.receiverUid == loggedInUid)) {
        return true;
      }
    } else if (group != null) {
      if (call.receiverUid == group!.guid) return true;
    }
    return _isMessageForCurrentConversation(call);
  }

  /// Check if a message passes type and category filters
  bool _passesTypeAndCategoryFilters(BaseMessage message) {
    // Check type filter
    if (types != null && types!.isNotEmpty) {
      if (!types!.contains(message.type)) {
        return false;
      }
    }

    // Check category filter
    if (categories != null && categories!.isNotEmpty) {
      if (!categories!.contains(message.category)) {
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // MESSAGE MUTATION INTERCEPTORS
  // ============================================================
  // These methods are called by ALL internal event handlers before mutating
  // the message list. Override them in subclasses to intercept, filter,
  // transform, or block any message mutation.
  //
  // Every message that enters, updates, or leaves the list goes through these.
  //
  // Example:
  // ```dart
  // class CustomMessageListBloc extends MessageListBloc {
  //   @override
  //   BaseMessage? onBeforeMessageAdded(BaseMessage message) {
  //     // Filter out messages containing "shshrishi"
  //     if (message is TextMessage && message.text.contains('shshrishi')) {
  //       return null; // Block this message
  //     }
  //     return message; // Allow it
  //   }
  // }
  // ```

  /// Called before a message is added to the list (new message, sent message).
  /// Return the message to allow it (optionally modified), or null to block it.
  BaseMessage? onBeforeMessageAdded(BaseMessage message) => message;

  /// Called after a message is added to the list.
  void onAfterMessageAdded(BaseMessage message, int index) {}

  /// Called before a message is updated in the list (edit, reaction, receipt).
  /// Return the new message to allow the update (optionally modified), or null to block it.
  BaseMessage? onBeforeMessageUpdated(
    BaseMessage oldMessage,
    BaseMessage newMessage,
  ) {
    // Preserve quotedMessage/quotedMessageId from the old message when the
    // incoming update doesn't carry them (e.g. poll vote responses,
    // interactive message updates). Without this, reply-context is lost.
    if (newMessage.quotedMessage == null && oldMessage.quotedMessage != null) {
      newMessage.quotedMessage = oldMessage.quotedMessage;
    }
    if ((newMessage.quotedMessageId == 0) && oldMessage.quotedMessageId != 0) {
      newMessage.quotedMessageId = oldMessage.quotedMessageId;
    }
    return newMessage;
  }

  /// Called after a message is updated in the list.
  void onAfterMessageUpdated(
    BaseMessage oldMessage,
    BaseMessage newMessage,
    int index,
  ) {}

  /// Called before a message is removed from the list (delete).
  /// Return true to allow removal, false to block it.
  bool onBeforeMessageRemoved(BaseMessage message) => true;

  /// Called after a message is removed from the list.
  void onAfterMessageRemoved(BaseMessage message) {}

  /// Called before the entire message list is replaced (load, refresh, pagination).
  /// Return the list to use (optionally filtered/sorted), or null to block the replace.
  List<BaseMessage>? onBeforeMessagesSet(List<BaseMessage> messages) =>
      messages;

  /// Called after the message list is replaced.
  void onAfterMessagesSet(List<BaseMessage> messages) {}

  // ============================================================
  // INTERNAL MUTATION HELPERS (use interceptors)
  // ============================================================

  /// Helper: update a message at a given index with interceptor support.
  /// Used by reaction handlers, receipt handlers, etc.
  /// Returns true if the update was applied, false if blocked by interceptor.
  bool _updateMessageAtIndex(
    int index,
    BaseMessage oldMessage,
    BaseMessage newMessage,
    Emitter<MessageListState> emit,
  ) {
    final intercepted = onBeforeMessageUpdated(oldMessage, newMessage);
    if (intercepted == null) return false;

    final updatedMessages = List<BaseMessage>.from(state.messages);
    updatedMessages[index] = intercepted;
    emit(state.copyWith(messages: updatedMessages));

    if (!_operationsController.isClosed) {
      _operationsController.add(
        MessageOperation.update(oldMessage, intercepted, index),
      );
    }

    onAfterMessageUpdated(oldMessage, intercepted, index);
    return true;
  }

  // ============================================================
  // LIST BASE HOOKS
  // ============================================================
  // These hooks are called by ListBase mixin methods (addItem, removeItem, etc.)
  // and sync the ListBase items with the BLoC state and operations stream.
  // Override these in subclasses to add custom logic (sorting, filtering, validation).
  //
  // Example:
  // ```dart
  // class CustomMessageListBloc extends MessageListBloc {
  //   @override
  //   void onItemAdded(BaseMessage item, List<BaseMessage> updatedList) {
  //     // Custom logic before syncing state
  //     super.onItemAdded(item, updatedList);
  //   }
  // }
  // ```

  @override
  void onItemAdded(BaseMessage item, List<BaseMessage> updatedList) {
    _mapNeedsRebuild = true;
    if (!isClosed) {
      add(_ListMessageAdded(item, updatedList));
    }
  }

  @override
  void onItemRemoved(BaseMessage item, List<BaseMessage> updatedList) {
    _mapNeedsRebuild = true;
    _cleanupReceiptNotifiers(item);
    if (!isClosed) {
      add(_ListMessageRemoved(item, updatedList));
    }
  }

  @override
  void onItemUpdated(
    BaseMessage oldItem,
    BaseMessage newItem,
    List<BaseMessage> updatedList,
  ) {
    _mapNeedsRebuild = true;
    if (!isClosed) {
      add(_ListMessageUpdated(oldItem, newItem, updatedList));
    }
  }

  @override
  void onListCleared(List<BaseMessage> previousList) {
    _mapNeedsRebuild = true;
    _messageIndexMap.clear();
    _muidIndexMap.clear();
    if (!isClosed) {
      add(_ListMessagesCleared(previousList));
    }
  }

  @override
  void onListReplaced(
    List<BaseMessage> previousList,
    List<BaseMessage> newList,
  ) {
    _mapNeedsRebuild = true;
    if (!isClosed) {
      add(_ListMessagesReplaced(previousList, newList));
    }
  }

  // ============================================================
  // LIST BASE INTERNAL EVENT HANDLERS
  // ============================================================

  void _onListMessageAdded(
    _ListMessageAdded event,
    Emitter<MessageListState> emit,
  ) {
    final index = event.updatedList.indexOf(event.item);
    emit(
      state.copyWith(
        messages: List<BaseMessage>.from(event.updatedList),
        status: MessageListStatus.loaded,
      ),
    );
    _rebuildIndexMaps();
    if (!_operationsController.isClosed) {
      _operationsController.add(
        MessageOperation.insert(
          event.item,
          index >= 0 ? index : event.updatedList.length - 1,
        ),
      );
    }
  }

  void _onListMessageRemoved(
    _ListMessageRemoved event,
    Emitter<MessageListState> emit,
  ) {
    final newStatus = event.updatedList.isEmpty
        ? MessageListStatus.empty
        : state.status;
    emit(
      state.copyWith(
        messages: List<BaseMessage>.from(event.updatedList),
        status: newStatus,
      ),
    );
    _rebuildIndexMaps();
    if (!_operationsController.isClosed) {
      _operationsController.add(MessageOperation.remove(event.item, 0));
    }
  }

  void _onListMessageUpdated(
    _ListMessageUpdated event,
    Emitter<MessageListState> emit,
  ) {
    final index = event.updatedList.indexOf(event.newItem);
    emit(state.copyWith(messages: List<BaseMessage>.from(event.updatedList)));
    _rebuildIndexMaps();
    if (!_operationsController.isClosed && index >= 0) {
      _operationsController.add(
        MessageOperation.update(event.oldItem, event.newItem, index),
      );
    }
  }

  void _onListMessagesCleared(
    _ListMessagesCleared event,
    Emitter<MessageListState> emit,
  ) {
    emit(state.copyWith(messages: const [], status: MessageListStatus.empty));
    if (!_operationsController.isClosed) {
      _operationsController.add(
        MessageOperation.set(const [], oldMessages: event.previousList),
      );
    }
  }

  void _onListMessagesReplaced(
    _ListMessagesReplaced event,
    Emitter<MessageListState> emit,
  ) {
    final newStatus = event.newList.isEmpty
        ? MessageListStatus.empty
        : MessageListStatus.loaded;
    emit(
      state.copyWith(
        messages: List<BaseMessage>.from(event.newList),
        status: newStatus,
      ),
    );
    _rebuildIndexMaps();
    if (!_operationsController.isClosed) {
      _operationsController.add(
        MessageOperation.set(event.newList, oldMessages: event.previousList),
      );
    }
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  Future<void> close() {
    // Remove SDK listeners
    if (!disableSDKListeners) {
      CometChat.removeMessageListener(_messageListenerId);
      CometChat.removeGroupListener(_groupListenerId);
      CometChat.removeCallListener(_callListenerId);
      CometChat.removeConnectionListener(_connectionListenerId);
      CometChat.removeAIAssistantListener(_aiAssistantListenerId);
    }

    // Remove UI message events listener
    CometChatMessageEvents.removeMessagesListener(_uiMessageListenerId);

    // Remove UI group events listener
    CometChatGroupEvents.removeGroupsListener(_uiGroupListenerId);

    // Remove UI call events listener
    CometChatCallEvents.removeCallEventsListener(_uiCallListenerId);

    // Dispose all receipt notifiers (by ID)
    for (final notifier in _receiptNotifiers.values) {
      notifier.dispose();
    }
    _receiptNotifiers.clear();

    // Dispose all receipt notifiers (by muid - for inProgress messages)
    for (final notifier in _receiptNotifiersByMuid.values) {
      notifier.dispose();
    }
    _receiptNotifiersByMuid.clear();

    // Dispose all typing notifiers
    for (final notifier in _typingNotifiers.values) {
      notifier.dispose();
    }
    _typingNotifiers.clear();

    // Dispose all thread reply count notifiers
    // **Validates: Requirements 14.2, 15.4**
    for (final notifier in _threadReplyCountNotifiers.values) {
      notifier.dispose();
    }
    _threadReplyCountNotifiers.clear();

    // Close operations stream
    _operationsController.close();

    // Clear index maps
    _messageIndexMap.clear();
    _muidIndexMap.clear();

    return super.close();
  }

  // ============================================================
  // MARK AS UNREAD EVENT HANDLERS
  // ============================================================

  /// Handle MarkMessageAsUnread event
  Future<void> _onMarkMessageAsUnread(
    MarkMessageAsUnread event,
    Emitter<MessageListState> emit,
  ) async {
    final message = event.message;
    if (message.sender?.uid == _loggedInUser?.uid) return;
    if (message.parentMessageId > 0) return;

    final result = await markAsUnreadUseCase(message: message);
    result.fold((failure) {}, (conversation) {
      CometChatUIKitHelper.onConversationUpdate(conversation);
      emit(
        state.copyWith(
          unreadMessageAnchor: message,
          unreadMessageAnchorId: message.id,
          lastReadMessageId: conversation.lastReadMessageId,
          unreadCount: conversation.unreadMessageCount,
          markedAsUnreadInSession: true,
        ),
      );
    });
  }

  /// Handle LoadFromUnread event
  /// Fetches ~30 older messages (before lastReadMessageId) and ~30 newer
  /// messages (after lastReadMessageId) so the user sees context around
  /// the unread boundary.
  Future<void> _onLoadFromUnread(
    LoadFromUnread event,
    Emitter<MessageListState> emit,
  ) async {
    if (parentMessageId != null) {
      add(
        LoadMessages(
          conversationWith: event.conversationWith,
          conversationType: event.conversationType,
        ),
      );
      return;
    }

    emit(state.copyWith(status: MessageListStatus.loading));

    final convResult = await getMessagesUseCase.repository.getConversation(
      conversationWith: event.conversationWith,
      conversationType: event.conversationType,
    );

    await convResult.fold(
      (failure) async {
        add(
          LoadMessages(
            conversationWith: event.conversationWith,
            conversationType: event.conversationType,
          ),
        );
      },
      (conversation) async {
        final lastReadId = conversation.lastReadMessageId ?? 0;
        final unreadCnt = conversation.unreadMessageCount;

        if (unreadCnt <= 0 || lastReadId <= 0) {
          add(
            LoadMessages(
              conversationWith: event.conversationWith,
              conversationType: event.conversationType,
            ),
          );
          return;
        }

        // ── Fetch older messages (up to and including lastReadId) ──
        final olderBuilder = MessagesRequestBuilder()
          ..limit = 30
          ..messageId =
              lastReadId +
              1 // fetchPrevious returns messages before this ID
          ..hideReplies = hideReplies;

        if (event.conversationType == 'user') {
          olderBuilder.uid = event.conversationWith;
        } else {
          olderBuilder.guid = event.conversationWith;
        }
        if (types != null && types!.isNotEmpty) {
          olderBuilder.types = types!;
        }
        if (categories != null && categories!.isNotEmpty) {
          olderBuilder.categories = categories!;
        }

        final olderRequest = olderBuilder.build();

        // ── Fetch newer messages (after lastReadId) ──
        final newerBuilder = MessagesRequestBuilder()
          ..limit = 30
          ..messageId = lastReadId
          ..hideReplies = hideReplies;

        if (event.conversationType == 'user') {
          newerBuilder.uid = event.conversationWith;
        } else {
          newerBuilder.guid = event.conversationWith;
        }
        if (types != null && types!.isNotEmpty) {
          newerBuilder.types = types!;
        }
        if (categories != null && categories!.isNotEmpty) {
          newerBuilder.categories = categories!;
        }

        final newerRequest = newerBuilder.build();

        // Fetch older and newer messages in parallel for faster load
        final results = await Future.wait([
          loadOlderMessagesUseCase(request: olderRequest),
          loadNewerMessagesUseCase(request: newerRequest),
        ]);

        final olderResult = results[0];
        final newerResult = results[1];

        final olderMessages = olderResult.fold(
          (failure) => <BaseMessage>[],
          (messages) => messages,
        );
        final newerMessages = newerResult.fold(
          (failure) => <BaseMessage>[],
          (messages) => messages,
        );

        // Merge: older (sorted oldest-first) + newer (sorted oldest-first)
        final allMessages = <BaseMessage>[...olderMessages, ...newerMessages];

        if (allMessages.isEmpty) {
          add(
            LoadMessages(
              conversationWith: event.conversationWith,
              conversationType: event.conversationType,
            ),
          );
          return;
        }

        // Deduplicate by message ID (in case lastReadId message appears in both)
        // Also filter out action messages — they have no template and would
        // render as plain "[message]" text in the fallback content view.
        final seen = <int>{};
        final deduped = <BaseMessage>[];
        for (final msg in allMessages) {
          if (msg.category == MessageCategoryConstants.action) continue;
          if (seen.add(msg.id)) {
            deduped.add(msg);
          }
        }
        // Sort oldest-first
        deduped.sort((a, b) => a.id.compareTo(b.id));

        // Find the first unread anchor
        BaseMessage? anchor;
        for (final msg in deduped) {
          if (msg.sender?.uid == _loggedInUser?.uid) continue;
          if (msg.deletedAt != null) continue;
          if (msg.parentMessageId > 0) continue;
          if (msg.category == MessageCategoryConstants.action) continue;
          if (msg.id > lastReadId) {
            anchor = msg;
            break;
          }
        }

        // Interceptor: allow subclass to filter/transform
        final interceptedDeduped = onBeforeMessagesSet(deduped);
        if (interceptedDeduped == null || interceptedDeduped.isEmpty) return;

        _mapNeedsRebuild = true;
        for (final message in interceptedDeduped) {
          if (message.replyCount > 0) {
            initializeThreadReplyCount(message.id, message.replyCount);
          }
        }

        emit(
          state.copyWith(
            status: MessageListStatus.loaded,
            messages: interceptedDeduped,
            hasMoreOlder: olderMessages.length >= 30,
            hasMoreNewer: newerMessages.length >= 30,
            loggedInUser: _loggedInUser,
            unreadMessageAnchor: anchor,
            unreadMessageAnchorId: anchor?.id,
            lastReadMessageId: lastReadId,
            unreadCount: unreadCnt,
            conversation: conversation,
          ),
        );

        if (!_operationsController.isClosed) {
          _operationsController.add(
            MessageOperation.set(interceptedDeduped, animated: false),
          );
        }

        onAfterMessagesSet(interceptedDeduped);

        _initializeMessagesRequests(
          conversationWith: event.conversationWith,
          conversationType: event.conversationType,
          oldestMessageId: interceptedDeduped.isNotEmpty
              ? interceptedDeduped.first.id
              : null,
          newestMessageId: interceptedDeduped.isNotEmpty
              ? interceptedDeduped.last.id
              : null,
        );

        // Mark the newest message as read so the conversations list
        // clears its unread badge. The "New Messages" indicator stays
        // visible for this session via unreadMessageAnchorId in state.
        if (!disableReceipts && deduped.isNotEmpty) {
          final newest = deduped.last;
          if (newest.id > 0) {
            add(MarkMessageAsRead(newest));
          }
        }
      },
    );
  }

  /// Handle ResetUnreadState event
  Future<void> _onResetUnreadState(
    ResetUnreadState event,
    Emitter<MessageListState> emit,
  ) async {
    _skipNextUnreadDetection = true;
    emit(state.copyWithCleared(clearUnreadState: true));
  }

  /// Find the first unread message in the currently loaded list.
  BaseMessage? findFirstUnreadMessage() {
    final lastReadId = state.lastReadMessageId;
    if (lastReadId == null || lastReadId <= 0) return null;
    if (state.unreadCount <= 0) return null;

    for (final msg in state.messages) {
      if (msg.sender?.uid == _loggedInUser?.uid) continue;
      if (msg.deletedAt != null) continue;
      if (msg.parentMessageId > 0) continue;
      if (msg.category == MessageCategoryConstants.action) continue;
      if (msg.id > lastReadId) return msg;
    }
    return null;
  }
}

// ============================================================================
// AnimatedMessageListBloc - Legacy Animation Support
// ============================================================================

/// Callback type for scrolling to a specific message by ID
/// Returns true if the scroll was initiated, false if the list wasn't ready
typedef ScrollToMessageCallback =
    Future<bool> Function(int messageId, {double alignment, Duration duration});

/// Callback type for scrolling to a specific index
/// Returns true if the scroll was initiated, false if the list wasn't ready
typedef ScrollToIndexCallback =
    Future<bool> Function(int index, {double alignment, Duration duration});

/// BLoC for managing animated message list state
///
/// This BLoC manages the message list state and emits [MessageOperation] events
/// that the animated list widget consumes for animations.
///
/// Features:
/// - O(1) message lookups via index maps
/// - Operations stream for animated list updates
/// - Scroll method attachment for programmatic scrolling
/// - Support for pagination (older/newer messages)
class AnimatedMessageListBloc
    extends Bloc<MessageListEvent, AnimatedMessageListState> {
  // ============================================================
  // O(1) LOOKUP MAPS
  // ============================================================

  /// Map from message ID to index in the list (for sent messages)
  final Map<int, int> _messageIndexMap = {};

  /// Map from muid to index in the list (for pending messages)
  final Map<String, int> _muidIndexMap = {};

  // ============================================================
  // OPERATIONS STREAM
  // ============================================================

  /// Stream controller for message operations (consumed by animated list)
  final _operationsController = StreamController<MessageOperation>.broadcast();

  /// Stream of message operations for the animated list to consume
  Stream<MessageOperation> get operationsStream => _operationsController.stream;

  // ============================================================
  // SCROLL METHODS
  // ============================================================

  /// Callback for scrolling to a message by ID (attached by animated list)
  ScrollToMessageCallback? _scrollToMessage;

  /// Callback for scrolling to an index (attached by animated list)
  ScrollToIndexCallback? _scrollToIndex;

  /// Creates a new AnimatedMessageListBloc
  AnimatedMessageListBloc() : super(const AnimatedMessageListState()) {
    on<InsertMessage>(_onInsertMessage);
    on<InsertAllMessages>(_onInsertAllMessages);
    on<UpdateMessage>(_onUpdateMessage);
    on<RemoveMessage>(_onRemoveMessage);
    on<SetMessages>(_onSetMessages);
    on<SetLoadingOlder>(_onSetLoadingOlder);
    on<SetLoadingNewer>(_onSetLoadingNewer);
    on<SetHasMoreOlder>(_onSetHasMoreOlder);
    on<SetHasMoreNewer>(_onSetHasMoreNewer);
  }

  // ============================================================
  // SCROLL METHOD ATTACHMENT
  // ============================================================

  /// Attach scroll methods from the animated list widget
  void attachScrollMethods({
    required ScrollToMessageCallback scrollToMessage,
    required ScrollToIndexCallback scrollToIndex,
  }) {
    _scrollToMessage = scrollToMessage;
    _scrollToIndex = scrollToIndex;
  }

  /// Detach scroll methods (called on widget dispose)
  void detachScrollMethods() {
    _scrollToMessage = null;
    _scrollToIndex = null;
  }

  /// Scroll to a specific message by ID
  /// Returns true if the scroll was initiated, false if not ready
  Future<bool> scrollToMessage(
    int messageId, {
    double alignment = 0,
    Duration duration = const Duration(milliseconds: 0),
  }) async {
    if (_scrollToMessage != null) {
      return await _scrollToMessage!(
        messageId,
        alignment: alignment,
        duration: duration,
      );
    }
    return false;
  }

  /// Scroll to a specific index
  /// Returns true if the scroll was initiated, false if not ready
  Future<bool> scrollToIndex(
    int index, {
    double alignment = 0,
    Duration duration = const Duration(milliseconds: 250),
  }) async {
    if (_scrollToIndex != null) {
      return await _scrollToIndex!(
        index,
        alignment: alignment,
        duration: duration,
      );
    }
    return false;
  }

  // ============================================================
  // O(1) LOOKUP METHODS
  // ============================================================

  /// Rebuild the index maps from scratch
  void _rebuildIndexMaps() {
    _messageIndexMap.clear();
    _muidIndexMap.clear();
    for (int i = 0; i < state.messages.length; i++) {
      final msg = state.messages[i];
      if (msg.id > 0) {
        _messageIndexMap[msg.id] = i;
      }
      final muid = msg.muid;
      if (muid.isNotEmpty) {
        _muidIndexMap[muid] = i;
      }
    }
  }

  /// Find message index by message ID (O(1))
  int? findMessageIndex(int messageId) => _messageIndexMap[messageId];

  /// Find message index by muid (O(1))
  int? findMessageIndexByMuid(String muid) => _muidIndexMap[muid];

  /// Find a message by ID
  BaseMessage? findMessage(int messageId) {
    final index = findMessageIndex(messageId);
    if (index != null && index < state.messages.length) {
      return state.messages[index];
    }
    return null;
  }

  /// Find a message by muid
  BaseMessage? findMessageByMuid(String muid) {
    final index = findMessageIndexByMuid(muid);
    if (index != null && index < state.messages.length) {
      return state.messages[index];
    }
    return null;
  }

  // ============================================================
  // EVENT HANDLERS
  // ============================================================

  /// Handle insert single message event
  void _onInsertMessage(
    InsertMessage event,
    Emitter<AnimatedMessageListState> emit,
  ) {
    final messages = List<BaseMessage>.from(state.messages);
    final index = event.index ?? messages.length;

    messages.insert(index, event.message);

    // Emit state first, then rebuild maps
    emit(state.copyWith(messages: messages));
    _rebuildIndexMaps();

    // Emit operation for animated list
    _operationsController.add(
      MessageOperation.insert(event.message, index, animated: event.animated),
    );
  }

  /// Handle insert multiple messages event
  void _onInsertAllMessages(
    InsertAllMessages event,
    Emitter<AnimatedMessageListState> emit,
  ) {
    if (event.messages.isEmpty) return;

    final messages = List<BaseMessage>.from(state.messages);
    final index = event.index ?? messages.length;

    messages.insertAll(index, event.messages);

    // Emit state first, then rebuild maps
    emit(state.copyWith(messages: messages));
    _rebuildIndexMaps();

    // Emit operation for animated list
    _operationsController.add(
      MessageOperation.insertAll(
        event.messages,
        index,
        animated: event.animated,
      ),
    );
  }

  /// Handle update message event
  void _onUpdateMessage(
    UpdateMessage event,
    Emitter<AnimatedMessageListState> emit,
  ) {
    // Try to find by ID first, then by muid
    int? index = event.oldMessage.id > 0
        ? findMessageIndex(event.oldMessage.id)
        : null;

    final oldMuid = event.oldMessage.muid;
    if (index == null && oldMuid.isNotEmpty) {
      index = findMessageIndexByMuid(oldMuid);
    }

    if (index == null || index >= state.messages.length) {
      return;
    }

    final messages = List<BaseMessage>.from(state.messages);
    messages[index] = event.newMessage;

    // Emit state first, then rebuild maps
    emit(state.copyWith(messages: messages));
    _rebuildIndexMaps();

    // Emit operation for animated list
    _operationsController.add(
      MessageOperation.update(event.oldMessage, event.newMessage, index),
    );
  }

  /// Handle remove message event
  void _onRemoveMessage(
    RemoveMessage event,
    Emitter<AnimatedMessageListState> emit,
  ) {
    // Try to find by ID first, then by muid
    int? index = event.message.id > 0
        ? findMessageIndex(event.message.id)
        : null;

    final msgMuid = event.message.muid;
    if (index == null && msgMuid.isNotEmpty) {
      index = findMessageIndexByMuid(msgMuid);
    }

    if (index == null || index >= state.messages.length) return;

    final messages = List<BaseMessage>.from(state.messages);
    messages.removeAt(index);

    // Emit state first, then rebuild maps
    emit(state.copyWith(messages: messages));
    _rebuildIndexMaps();

    // Emit operation for animated list
    _operationsController.add(
      MessageOperation.remove(event.message, index, animated: event.animated),
    );
  }

  /// Handle set messages event (replace entire list)
  void _onSetMessages(
    SetMessages event,
    Emitter<AnimatedMessageListState> emit,
  ) {
    final oldMessages = state.messages;
    final newMessages = List<BaseMessage>.from(event.messages);

    // Update state first, then rebuild maps from the new messages
    emit(state.copyWith(messages: newMessages));

    // Rebuild index maps AFTER state is updated
    _rebuildIndexMaps();

    // Emit operation for animated list (will use diff internally)
    _operationsController.add(
      MessageOperation.set(
        newMessages,
        oldMessages: oldMessages,
        animated: event.animated,
      ),
    );
  }

  /// Handle set loading older state
  void _onSetLoadingOlder(
    SetLoadingOlder event,
    Emitter<AnimatedMessageListState> emit,
  ) {
    emit(state.copyWith(isLoadingOlder: event.isLoading));
  }

  /// Handle set loading newer state
  void _onSetLoadingNewer(
    SetLoadingNewer event,
    Emitter<AnimatedMessageListState> emit,
  ) {
    emit(state.copyWith(isLoadingNewer: event.isLoading));
  }

  /// Handle set has more older state
  void _onSetHasMoreOlder(
    SetHasMoreOlder event,
    Emitter<AnimatedMessageListState> emit,
  ) {
    emit(state.copyWith(hasMoreOlder: event.hasMore));
  }

  /// Handle set has more newer state
  void _onSetHasMoreNewer(
    SetHasMoreNewer event,
    Emitter<AnimatedMessageListState> emit,
  ) {
    emit(state.copyWith(hasMoreNewer: event.hasMore));
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  Future<void> close() {
    _operationsController.close();
    detachScrollMethods();
    _messageIndexMap.clear();
    _muidIndexMap.clear();
    return super.close();
  }
}

// ============================================================================
// SDK LISTENERS
// ============================================================================

/// Message listener for real-time message updates in message list
///
/// Handles:
/// - New messages (text, media, custom, interactive)
/// - Message edits and deletes
/// - Delivery and read receipts
/// - Typing indicators
/// - Reactions (added/removed)
class _MessageListMessageListener with MessageListener {
  final void Function(BaseMessage) onTextMessageReceivedCallback;
  final void Function(BaseMessage) onMediaMessageReceivedCallback;
  final void Function(BaseMessage) onCustomMessageReceivedCallback;
  final void Function(BaseMessage) onInteractiveMessageReceivedCallback;
  final void Function(BaseMessage) onAIAssistantMessageReceivedCallback;
  final void Function(BaseMessage) onMessageEditedCallback;

  /// Pin & Save: (message, isPinScope) — see [MessagePinSaveChanged].
  final void Function(BaseMessage, bool) onMessagePinSaveChangedCallback;
  final void Function(BaseMessage) onMessageDeletedCallback;
  final void Function(BaseMessage) onMessageModeratedCallback;
  final void Function(MessageReceipt) onMessagesDeliveredCallback;
  final void Function(MessageReceipt) onMessagesReadCallback;
  final void Function(MessageReceipt) onMessagesDeliveredToAllCallback;
  final void Function(MessageReceipt) onMessagesReadByAllCallback;
  final void Function(TypingIndicator) onTypingStartedCallback;
  final void Function(TypingIndicator) onTypingEndedCallback;
  final void Function(ReactionEvent) onMessageReactionAddedCallback;
  final void Function(ReactionEvent) onMessageReactionRemovedCallback;

  _MessageListMessageListener({
    required this.onTextMessageReceivedCallback,
    required this.onMediaMessageReceivedCallback,
    required this.onCustomMessageReceivedCallback,
    required this.onInteractiveMessageReceivedCallback,
    required this.onAIAssistantMessageReceivedCallback,
    required this.onMessageEditedCallback,
    required this.onMessagePinSaveChangedCallback,
    required this.onMessageDeletedCallback,
    required this.onMessageModeratedCallback,
    required this.onMessagesDeliveredCallback,
    required this.onMessagesReadCallback,
    required this.onMessagesDeliveredToAllCallback,
    required this.onMessagesReadByAllCallback,
    required this.onTypingStartedCallback,
    required this.onTypingEndedCallback,
    required this.onMessageReactionAddedCallback,
    required this.onMessageReactionRemovedCallback,
  });

  @override
  void onTextMessageReceived(TextMessage textMessage) {
    ccLog(
      '[MessageListener] onTextMessageReceived: id=${textMessage.id}, sender=${textMessage.sender?.uid}',
    );
    onTextMessageReceivedCallback(textMessage);
  }

  @override
  void onMediaMessageReceived(MediaMessage mediaMessage) {
    ccLog(
      '[MessageListener] onMediaMessageReceived: id=${mediaMessage.id}, type=${mediaMessage.type}, sender=${mediaMessage.sender?.uid}',
    );
    onMediaMessageReceivedCallback(mediaMessage);
  }

  @override
  void onCustomMessageReceived(CustomMessage customMessage) {
    ccLog(
      '[MessageListener] onCustomMessageReceived: id=${customMessage.id}, type=${customMessage.type}, sender=${customMessage.sender?.uid}',
    );
    onCustomMessageReceivedCallback(customMessage);
  }

  @override
  void onInteractiveMessageReceived(InteractiveMessage interactiveMessage) {
    ccLog(
      '[MessageListener] onInteractiveMessageReceived: id=${interactiveMessage.id}, type=${interactiveMessage.type}, sender=${interactiveMessage.sender?.uid}',
    );
    onInteractiveMessageReceivedCallback(interactiveMessage);
  }

  @override
  void onCardMessageReceived(CardMessage cardMessage) {
    ccLog(
      '[MessageListener] onCardMessageReceived: id=${cardMessage.id}, '
      'category=${cardMessage.category}, type=${cardMessage.type}, '
      'hasCard=${cardMessage.getCard() != null}, '
      'text=${cardMessage.getText()}',
    );
    // Route card messages through the same path as other messages
    onTextMessageReceivedCallback(cardMessage);
  }

  @override
  void onAIAssistantMessageReceived(AIAssistantMessage aiAssistantMessage) {
    ccLog(
      '[MessageListener] onAIAssistantMessageReceived: id=${aiAssistantMessage.id}, '
      'runId=${aiAssistantMessage.runId}, '
      'hasElements=${aiAssistantMessage.getElements()?.isNotEmpty ?? false}, '
      'elementsCount=${aiAssistantMessage.getElements()?.length ?? 0}',
    );
    onAIAssistantMessageReceivedCallback(aiAssistantMessage);
  }

  @override
  void onMessageEdited(BaseMessage message) {
    onMessageEditedCallback(message);
  }

  // Pin & Save events carry the full updated message (pin/save fields
  // stamped or cleared) — routing them through the edit path replaces the
  // row in place, which is exactly what the bubble indicators need.
  @override
  void onMessagePinned(BaseMessage message) {
    onMessagePinSaveChangedCallback(message, true);
  }

  @override
  void onMessageUnpinned(BaseMessage message) {
    onMessagePinSaveChangedCallback(message, true);
  }

  @override
  void onMessageSaved(BaseMessage message) {
    onMessagePinSaveChangedCallback(message, false);
  }

  @override
  void onMessageUnsaved(BaseMessage message) {
    onMessagePinSaveChangedCallback(message, false);
  }

  @override
  void onMessageDeleted(BaseMessage message) {
    onMessageDeletedCallback(message);
  }

  @override
  void onMessageModerated(BaseMessage message) {
    onMessageModeratedCallback(message);
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
  void onTypingStarted(TypingIndicator typingIndicator) {
    onTypingStartedCallback(typingIndicator);
  }

  @override
  void onTypingEnded(TypingIndicator typingIndicator) {
    onTypingEndedCallback(typingIndicator);
  }

  @override
  void onMessageReactionAdded(ReactionEvent reactionEvent) {
    onMessageReactionAddedCallback(reactionEvent);
  }

  @override
  void onMessageReactionRemoved(ReactionEvent reactionEvent) {
    onMessageReactionRemovedCallback(reactionEvent);
  }
}

/// Group listener for group events in message list
///
/// Handles group member events that generate action messages:
/// - Member joined, left, kicked, banned, unbanned
/// - Scope changes
/// - Member additions
class _MessageListGroupListener with GroupListener {
  final void Function(Action, User, Group) onGroupMemberJoinedCallback;
  final void Function(Action, User, Group) onGroupMemberLeftCallback;
  final void Function(Action, User, User, Group) onGroupMemberKickedCallback;
  final void Function(Action, User, User, Group) onGroupMemberBannedCallback;
  final void Function(Action, User, User, Group) onGroupMemberUnbannedCallback;
  final void Function(Action, User, User, String, String, Group)
  onGroupMemberScopeChangedCallback;
  final void Function(Action, User, User, Group) onMemberAddedToGroupCallback;

  _MessageListGroupListener({
    required this.onGroupMemberJoinedCallback,
    required this.onGroupMemberLeftCallback,
    required this.onGroupMemberKickedCallback,
    required this.onGroupMemberBannedCallback,
    required this.onGroupMemberUnbannedCallback,
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

/// Call listener for call events in message list
///
/// Handles call events that generate call messages:
/// - Incoming/outgoing calls
/// - Call accepted/rejected/cancelled
/// - Call ended
class _MessageListCallListener with CallListener {
  final void Function(Call) onIncomingCallReceivedCallback;
  final void Function(Call) onOutgoingCallAcceptedCallback;
  final void Function(Call) onOutgoingCallRejectedCallback;
  final void Function(Call) onIncomingCallCancelledCallback;
  final void Function(Call) onCallEndedMessageReceivedCallback;

  _MessageListCallListener({
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

/// Connection listener for connection state in message list
///
/// Handles:
/// - Connection restored (triggers refresh)
/// - Connection lost
class _MessageListConnectionListener with ConnectionListener {
  final void Function() onConnectedCallback;
  final void Function() onDisconnectedCallback;

  _MessageListConnectionListener({
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

/// AI assistant event listener for streaming events (thinking bubbles, content)
class _MessageListAIAssistantListener with AIAssistantListener {
  final void Function(AIAssistantBaseEvent) onAIAssistantEventReceivedCallback;

  _MessageListAIAssistantListener({
    required this.onAIAssistantEventReceivedCallback,
  });

  @override
  void onAIAssistantEventReceived(AIAssistantBaseEvent event) {
    onAIAssistantEventReceivedCallback(event);
  }
}

/// UI message event listener for messages sent/edited/deleted by logged-in user
///
/// Handles UI-triggered message events:
/// - ccMessageSent: When logged-in user sends a message
/// - ccMessageEdited: When logged-in user edits a message
/// - ccMessageDeleted: When logged-in user deletes a message
class _MessageListUIEventListener with CometChatMessageEventListener {
  final void Function(BaseMessage, dynamic) onCCMessageSentCallback;
  final void Function(BaseMessage, dynamic) onCCMessageEditedCallback;
  final void Function(BaseMessage, dynamic) onCCMessageDeletedCallback;
  final void Function(int, bool) onThreadSubscriptionChangedCallback;

  _MessageListUIEventListener({
    required this.onCCMessageSentCallback,
    required this.onCCMessageEditedCallback,
    required this.onCCMessageDeletedCallback,
    required this.onThreadSubscriptionChangedCallback,
  });

  @override
  void ccMessageSent(BaseMessage message, dynamic messageStatus) {
    onCCMessageSentCallback(message, messageStatus);
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
  void ccThreadSubscriptionChanged(int parentMessageId, bool subscribed) {
    onThreadSubscriptionChangedCallback(parentMessageId, subscribed);
  }
}

/// UI group event listener for group actions performed by logged-in user
///
/// SDK group listeners only fire for actions by OTHER users. When the
/// logged-in user performs actions (add/kick/ban), we rely on these
/// CometChatGroupEvents to generate action messages in the message list.
class _MessageListUIGroupEventListener with CometChatGroupEventListener {
  final void Function(List<Action>, List<User>, Group, User)
  onCCGroupMemberAddedCallback;
  final void Function(Action, User, User, Group) onCCGroupMemberKickedCallback;
  final void Function(Action, User, User, Group) onCCGroupMemberBannedCallback;

  _MessageListUIGroupEventListener({
    required this.onCCGroupMemberAddedCallback,
    required this.onCCGroupMemberKickedCallback,
    required this.onCCGroupMemberBannedCallback,
  });

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
}

/// Forwards the UI Kit's own call events to the message list bloc.
///
/// The SDK tells a device about calls other people act on, but never about
/// what this device did itself: the caller is not told about their own
/// initiate or cancel, and the callee is not told about their own decline.
/// Those only exist as UI Kit events, so without this the person who declined
/// never saw the call in their chat at all (ENG-39486). Kotlin's message list
/// listens to the same four events.
class _MessageListUICallEventListener with CometChatCallEventListener {
  final void Function(Call) onCallCallback;

  _MessageListUICallEventListener({required this.onCallCallback});

  @override
  void ccOutgoingCall(Call call) => onCallCallback(call);

  @override
  void ccCallAccepted(Call call) => onCallCallback(call);

  @override
  void ccCallRejected(Call call) => onCallCallback(call);

  @override
  void ccCallEnded(Call call) => onCallCallback(call);
}

// ============================================================================
// Internal ListBase Hook Events
// ============================================================================

class _ListMessageAdded extends MessageListEvent {
  final BaseMessage item;
  final List<BaseMessage> updatedList;
  const _ListMessageAdded(this.item, this.updatedList);
  @override
  List<Object?> get props => [item, updatedList];
}

class _ListMessageRemoved extends MessageListEvent {
  final BaseMessage item;
  final List<BaseMessage> updatedList;
  const _ListMessageRemoved(this.item, this.updatedList);
  @override
  List<Object?> get props => [item, updatedList];
}

class _ListMessageUpdated extends MessageListEvent {
  final BaseMessage oldItem;
  final BaseMessage newItem;
  final List<BaseMessage> updatedList;
  const _ListMessageUpdated(this.oldItem, this.newItem, this.updatedList);
  @override
  List<Object?> get props => [oldItem, newItem, updatedList];
}

class _ListMessagesCleared extends MessageListEvent {
  final List<BaseMessage> previousList;
  const _ListMessagesCleared(this.previousList);
  @override
  List<Object?> get props => [previousList];
}

class _ListMessagesReplaced extends MessageListEvent {
  final List<BaseMessage> previousList;
  final List<BaseMessage> newList;
  const _ListMessagesReplaced(this.previousList, this.newList);
  @override
  List<Object?> get props => [previousList, newList];
}
