import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared_ui/cometchat_uikit_shared.dart';
import '../../../../shared_ui/src/clean_architecture/core/constants/enums.dart'
    as core_enums;
import '../../../../shared_ui/src/offline/offline_gate.dart';
import '../../../../shared_ui/src/offline/offline_hub.dart';
import '../../../../shared_ui/src/offline/offline_hub_event.dart';
import '../../../../shared_ui/src/offline/thread_reply_count_offline.dart';
import 'threaded_header_event.dart';
import 'threaded_header_state.dart';

/// BLoC for managing threaded header state
///
/// This BLoC manages the threaded header state and handles:
/// - Initialization with parent message
/// - Reply count tracking via SDK listeners
/// - Parent message updates (edit/delete)
/// - Real-time updates via SDK and UI event listeners
///
/// The BLoC registers listeners for:
/// - SDK MessageListener: onTextMessageReceived, onMediaMessageReceived,
///   onCustomMessageReceived, onSchedulerMessageReceived, onMessageEdited,
///   onMessageDeleted
/// - UI CometChatMessageEvents: ccMessageSent, ccMessageEdited, ccMessageDeleted
class ThreadedHeaderBloc
    extends Bloc<ThreadedHeaderEvent, ThreadedHeaderState> {
  // SDK listener keys - unique per instance to prevent conflicts
  late final String _messageListenerKey;
  late final String _uiMessageListenerKey;
  late final String _uiGroupListenerKey;

  // Parent message ID for filtering incoming messages
  int? _parentMessageId;

  // Offline on only (W7): own replies counted while they wait to send, and
  // the subscriptions that feed them. Null / unused with offline off.
  final ThreadReplyLedger _replyLedger = ThreadReplyLedger();
  StreamSubscription<Object>? _offlineHubSub;

  /// Creates a ThreadedHeaderBloc.
  ThreadedHeaderBloc() : super(const ThreadedHeaderState()) {
    // Register event handlers
    on<InitializeThreadedHeader>(_onInitialize);
    on<IncrementReplyCount>(_onIncrementReplyCount);
    on<UpdateParentMessage>(_onUpdateParentMessage);
    on<UpdateThreadSubscription>(_onUpdateThreadSubscription);
    on<_OfflineReplyCountEvent>(_onOfflineReplyCount);

    // Generate unique listener keys using timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _messageListenerKey = 'threaded_header_message_$timestamp';
    _uiMessageListenerKey = 'threaded_header_ui_message_$timestamp';
    _uiGroupListenerKey = 'threaded_header_ui_group_$timestamp';
  }

  /// Initialize the threaded header with parent message and logged in user
  void _onInitialize(
    InitializeThreadedHeader event,
    Emitter<ThreadedHeaderState> emit,
  ) {
    emit(state.copyWith(status: ThreadedHeaderStatus.loading));

    final parentMessage = event.parentMessage;
    final loggedInUser = event.loggedInUser;

    // Store parent message ID for filtering
    _parentMessageId = parentMessage.id;

    // Determine user/group context based on message sender and receiver
    User? user;
    Group? group;

    if (parentMessage.sender?.uid == loggedInUser.uid) {
      // Logged in user sent the parent message
      if (parentMessage.receiver is Group) {
        group = parentMessage.receiver as Group;
      } else {
        user = parentMessage.receiver as User;
      }
    } else {
      // Someone else sent the parent message
      if (parentMessage.receiver is Group) {
        group = parentMessage.receiver as Group;
      } else {
        user = parentMessage.sender;
      }
    }

    // Register SDK listeners
    _registerSDKListeners();
    _replyLedger.clear();
    if (OfflineGate.isOn()) _watchOfflineReplyCount();

    // Emit loaded state with initial data. The subscription state IS the
    // message object's flag (stateless redesign — threadSubscribed rides
    // every fetch because the SDK always sends withThreadSubscribed=true,
    // normalised so it can never be null).
    emit(
      state.copyWith(
        status: ThreadedHeaderStatus.loaded,
        parentMessage: parentMessage,
        replyCount: parentMessage.replyCount,
        loggedInUser: loggedInUser,
        user: user,
        group: group,
        threadSubscribed: parentMessage.threadSubscribed,
      ),
    );
  }

  /// Update the thread-subscription state (optimistic flip, revert, or a
  /// change that originated elsewhere — the kit event bus keeps every
  /// surface in agreement without a refetch). The parent message object is
  /// stamped too: it is the single source the next reader consults.
  void _onUpdateThreadSubscription(
    UpdateThreadSubscription event,
    Emitter<ThreadedHeaderState> emit,
  ) {
    state.parentMessage?.threadSubscribed = event.subscribed;
    emit(state.copyWith(threadSubscribed: event.subscribed));
  }

  /// Increment the reply count by 1
  void _onIncrementReplyCount(
    IncrementReplyCount event,
    Emitter<ThreadedHeaderState> emit,
  ) {
    emit(state.copyWith(replyCount: state.replyCount + 1));
  }

  /// Offline on (W7): applies a hub event or an own `sent` reply to the reply
  /// count (PR #23 §3.9, BEH-MUT-10).
  void _onOfflineReplyCount(
    _OfflineReplyCountEvent event,
    Emitter<ThreadedHeaderState> emit,
  ) {
    final parentId = _parentMessageId;
    if (parentId == null) return;
    final source = event.source;
    int? next;
    if (source is OfflineHubEvent) {
      if (source.gen < OfflineHub.instance.gen) return;
      next = ThreadReplyCountOffline.headerCountAfter(
        parentMessageId: parentId,
        current: state.replyCount,
        ledger: _replyLedger,
        event: source,
      );
    } else if (source is BaseMessage) {
      if (_replyLedger.claimSent(source)) next = state.replyCount + 1;
    }
    if (next != null && next != state.replyCount) {
      emit(state.copyWith(replyCount: next));
    }
  }

  void _watchOfflineReplyCount() {
    _offlineHubSub ??= OfflineHub.instance.events.listen((event) {
      if (!isClosed) add(_OfflineReplyCountEvent(event));
    });
  }

  /// Update the parent message (for edit/delete)
  void _onUpdateParentMessage(
    UpdateParentMessage event,
    Emitter<ThreadedHeaderState> emit,
  ) {
    emit(state.copyWith(parentMessage: event.message));
  }

  // ============================================================
  // SDK LISTENER REGISTRATION
  // ============================================================

  /// Register all CometChat SDK listeners for real-time updates
  void _registerSDKListeners() {
    // Register SDK message listener
    CometChat.addMessageListener(
      _messageListenerKey,
      _ThreadedHeaderMessageListener(
        onTextMessageReceivedCallback: _handleMessageReceived,
        onMediaMessageReceivedCallback: _handleMessageReceived,
        onCustomMessageReceivedCallback: _handleMessageReceived,
        onInteractiveMessageReceivedCallback: _handleInteractiveMessageReceived,
        onMessageEditedCallback: _handleMessageEdited,
        onMessageDeletedCallback: _handleMessageDeleted,
      ),
    );

    // Register UI message event listener
    CometChatMessageEvents.addMessagesListener(
      _uiMessageListenerKey,
      _ThreadedHeaderUIMessageListener(
        onCCMessageSentCallback: _handleCCMessageSent,
        onCCMessageEditedCallback: _handleCCMessageEdited,
        onCCMessageDeletedCallback: _handleCCMessageDeleted,
        onSchedulerMessageReceivedCallback: _handleSchedulerMessageReceived,
        onThreadSubscriptionChangedCallback: _handleThreadSubscriptionChanged,
      ),
    );

    // Register UI group event listener (for potential group-related updates)
    CometChatGroupEvents.addGroupsListener(
      _uiGroupListenerKey,
      _ThreadedHeaderUIGroupListener(),
    );
  }

  /// Handle a thread-subscription change from the kit event bus (the SDK is
  /// stateless — every surface announces its own successful toggle here).
  void _handleThreadSubscriptionChanged(int parentMessageId, bool subscribed) {
    if (isClosed) return;
    if (parentMessageId == _parentMessageId) {
      add(UpdateThreadSubscription(subscribed));
    }
  }

  // ============================================================
  // SDK MESSAGE LISTENER CALLBACKS
  // ============================================================

  /// Handle received messages (text, media, custom)
  /// Increment reply count if parentMessageId matches
  void _handleMessageReceived(BaseMessage message) {
    if (isClosed) return;
    if (message.parentMessageId == _parentMessageId) {
      add(const IncrementReplyCount());
    }
  }

  /// Handle interactive message received (includes scheduler messages)
  /// Increment reply count if parentMessageId matches
  void _handleInteractiveMessageReceived(InteractiveMessage message) {
    if (isClosed) return;
    if (message.parentMessageId == _parentMessageId) {
      add(const IncrementReplyCount());
    }
  }

  /// Handle scheduler message received (via UI events)
  /// Increment reply count if parentMessageId matches
  void _handleSchedulerMessageReceived(SchedulerMessage message) {
    if (isClosed) return;
    if (message.parentMessageId == _parentMessageId) {
      add(const IncrementReplyCount());
    }
  }

  /// Handle message edited
  /// Update parent message if ID matches
  void _handleMessageEdited(BaseMessage message) {
    if (isClosed) return;
    if (message.id == _parentMessageId) {
      add(UpdateParentMessage(message));
    }
  }

  /// Handle message deleted
  /// Update parent message if ID matches
  void _handleMessageDeleted(BaseMessage message) {
    if (isClosed) return;
    if (message.id == _parentMessageId) {
      add(UpdateParentMessage(message));
    }
  }

  // ============================================================
  // UI EVENT LISTENER CALLBACKS
  // ============================================================

  /// Handle message sent by logged-in user
  /// Increment reply count on successful send
  void _handleCCMessageSent(
    BaseMessage message,
    core_enums.MessageStatus status,
  ) {
    if (isClosed) return;
    if (status == core_enums.MessageStatus.sent) {
      if (_offlineHubSub != null) {
        // Offline on (W7): only this thread's replies, each counted once.
        if (message.parentMessageId == _parentMessageId) {
          add(_OfflineReplyCountEvent(message));
        }
        return;
      }
      add(const IncrementReplyCount());
    }
  }

  /// Handle message edited by logged-in user
  /// Update parent message if ID matches
  void _handleCCMessageEdited(BaseMessage message, MessageEditStatus status) {
    if (isClosed) return;
    if (message.id == _parentMessageId && status == MessageEditStatus.success) {
      add(UpdateParentMessage(message));
    }
  }

  /// Handle message deleted by logged-in user
  /// Update parent message if ID matches
  void _handleCCMessageDeleted(BaseMessage message, EventStatus status) {
    if (isClosed) return;
    if (message.id == _parentMessageId) {
      add(UpdateParentMessage(message));
    }
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  Future<void> close() {
    // Remove all SDK listeners to prevent memory leaks
    CometChat.removeMessageListener(_messageListenerKey);
    CometChatMessageEvents.removeMessagesListener(_uiMessageListenerKey);
    CometChatGroupEvents.removeGroupsListener(_uiGroupListenerKey);
    _offlineHubSub?.cancel();
    return super.close();
  }
}

/// Offline on (W7): a hub event or an own `sent` reply, applied to the reply
/// count.
class _OfflineReplyCountEvent extends ThreadedHeaderEvent {
  const _OfflineReplyCountEvent(this.source);

  final Object source;

  @override
  List<Object?> get props => [source];
}

// ============================================================
// LISTENER CLASSES
// ============================================================

/// Message listener for SDK message events
///
/// Handles:
/// - Text, media, custom message received (increment reply count)
/// - Interactive message received (includes scheduler messages - increment reply count)
/// - Message edited (update parent message)
/// - Message deleted (update parent message)
class _ThreadedHeaderMessageListener with MessageListener {
  final void Function(BaseMessage) onTextMessageReceivedCallback;
  final void Function(BaseMessage) onMediaMessageReceivedCallback;
  final void Function(BaseMessage) onCustomMessageReceivedCallback;
  final void Function(InteractiveMessage) onInteractiveMessageReceivedCallback;
  final void Function(BaseMessage) onMessageEditedCallback;
  final void Function(BaseMessage) onMessageDeletedCallback;

  _ThreadedHeaderMessageListener({
    required this.onTextMessageReceivedCallback,
    required this.onMediaMessageReceivedCallback,
    required this.onCustomMessageReceivedCallback,
    required this.onInteractiveMessageReceivedCallback,
    required this.onMessageEditedCallback,
    required this.onMessageDeletedCallback,
  });

  @override
  void onTextMessageReceived(TextMessage textMessage) {
    onTextMessageReceivedCallback(textMessage);
  }

  @override
  void onMediaMessageReceived(MediaMessage mediaMessage) {
    onMediaMessageReceivedCallback(mediaMessage);
  }

  @override
  void onCustomMessageReceived(CustomMessage customMessage) {
    onCustomMessageReceivedCallback(customMessage);
  }

  @override
  void onInteractiveMessageReceived(InteractiveMessage interactiveMessage) {
    onInteractiveMessageReceivedCallback(interactiveMessage);
  }

  @override
  void onMessageEdited(BaseMessage message) {
    onMessageEditedCallback(message);
  }

  @override
  void onMessageDeleted(BaseMessage message) {
    onMessageDeletedCallback(message);
  }
}

/// UI Message event listener for CometChatMessageEvents
///
/// Handles:
/// - ccMessageSent (increment reply count on successful send)
/// - ccMessageEdited (update parent message)
/// - ccMessageDeleted (update parent message)
/// - onSchedulerMessageReceived (increment reply count)
class _ThreadedHeaderUIMessageListener with CometChatMessageEventListener {
  final void Function(BaseMessage, core_enums.MessageStatus)
  onCCMessageSentCallback;
  final void Function(BaseMessage, MessageEditStatus) onCCMessageEditedCallback;
  final void Function(BaseMessage, EventStatus) onCCMessageDeletedCallback;
  final void Function(SchedulerMessage) onSchedulerMessageReceivedCallback;
  final void Function(int, bool) onThreadSubscriptionChangedCallback;

  _ThreadedHeaderUIMessageListener({
    required this.onCCMessageSentCallback,
    required this.onCCMessageEditedCallback,
    required this.onCCMessageDeletedCallback,
    required this.onSchedulerMessageReceivedCallback,
    required this.onThreadSubscriptionChangedCallback,
  });

  @override
  void ccMessageSent(
    BaseMessage message,
    core_enums.MessageStatus messageStatus,
  ) {
    onCCMessageSentCallback(message, messageStatus);
  }

  @override
  void ccMessageEdited(BaseMessage message, MessageEditStatus status) {
    onCCMessageEditedCallback(message, status);
  }

  @override
  void ccMessageDeleted(BaseMessage message, EventStatus messageStatus) {
    onCCMessageDeletedCallback(message, messageStatus);
  }

  @override
  void onSchedulerMessageReceived(SchedulerMessage schedulerMessage) {
    onSchedulerMessageReceivedCallback(schedulerMessage);
  }

  @override
  void ccThreadSubscriptionChanged(int parentMessageId, bool subscribed) {
    onThreadSubscriptionChangedCallback(parentMessageId, subscribed);
  }
}

/// UI Group event listener for CometChatGroupEvents
///
/// Currently empty - reserved for potential group-related updates
/// that may affect the threaded header in the future.
class _ThreadedHeaderUIGroupListener with CometChatGroupEventListener {}
