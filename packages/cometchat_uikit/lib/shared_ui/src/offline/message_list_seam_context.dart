import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart';

import '../../../chat_ui/src/message_list/bloc/message_list_bloc.dart'
    show MessageReceiptStatus;
import '../../../chat_ui/src/message_list/bloc/message_list_event.dart';
import '../../../chat_ui/src/message_list/bloc/message_list_state.dart';
import '../../../chat_ui/src/message_list/data/datasources/message_list_remote_datasource.dart';
import '../../../chat_ui/src/message_list/domain/repositories/message_list_repository.dart';
import '../../../chat_ui/src/message_list/utils/message_operation.dart';
import 'offline_notice.dart';

/// What a message-list seam (W2 reads, W4 sends, W5 sync) may read and do
/// without editing `MessageListBloc` (W1 §2.9). Internal to the kit.
///
/// A context is bound to the emitter of the bloc handler that created it and to
/// the list generation at that moment: once the list is cleared or reset
/// ([isStale]), [emit] and [addOperation] drop silently, so a read in flight
/// across a session end cannot repaint the old user's rows (§2.7).
abstract interface class MessageListSeamContext {
  /// The bloc's current state.
  MessageListState get state;

  /// Emits through the running handler's emitter; dropped when [isStale] or
  /// the handler has completed.
  void emit(MessageListState state);

  /// Pushes a row operation to the animated list; dropped when [isStale].
  void addOperation(MessageOperation operation);

  /// Dispatches an event to the bloc.
  void add(MessageListEvent event);

  /// Shows a notice on this list (unless the widget hides notices).
  void postNotice(OfflineNotice notice);

  /// The list generation this context was created under.
  int get opGen;

  /// The list's current generation.
  int get listGen;

  /// Whether the list generation moved on since this context was created.
  bool get isStale;

  /// Whether the bloc is closed.
  bool get isClosed;

  /// An identity token for the list (the bloc), for per-list seam state kept
  /// in an `Expando` that the widget reads by its bloc. Never cast it.
  Object get owner;

  /// The user of a one-to-one chat, else null.
  User? get user;

  /// The group of a group chat, else null.
  Group? get group;

  /// The thread parent id when the list shows a thread.
  int? get parentMessageId;

  /// The logged-in user the list was loaded for.
  User? get loggedInUser;

  /// Server id → row index for the rows shown.
  Map<int, int> get messageIndexMap;

  /// muid → row index for the rows shown.
  Map<String, int> get muidIndexMap;

  /// Older-page cursor (scroll up).
  MessagesRequest? get olderRequest;
  set olderRequest(MessagesRequest? request);

  /// Newer-page cursor (scroll down).
  MessagesRequest? get newerRequest;
  set newerRequest(MessagesRequest? request);

  /// The datasource behind the list when the kit's standard repository is in
  /// use (pass to `messageListTwoPhaseFor`), else null.
  MessageListRemoteDataSource? get remoteDataSource;

  /// The repository behind the list (standard or integrator-supplied), e.g.
  /// for `getConversation` when placing the unread anchor.
  MessageListRepository get repository;

  // --- Integrator hooks and row bookkeeping ----------------------------------
  // A seam that replaces or merges the rows shown does what today's paths do:
  // run [onBeforeMessagesSet] (null = skip the set), mark the index maps dirty,
  // seed thread reply counts, emit + push the operation, then run
  // [onAfterMessagesSet].

  /// Runs the integrator's `MessageListBloc.onBeforeMessagesSet` override;
  /// returns the rows to show, or null to skip the set.
  List<BaseMessage>? onBeforeMessagesSet(List<BaseMessage> messages);

  /// Runs the integrator's `MessageListBloc.onAfterMessagesSet` override.
  void onAfterMessagesSet(List<BaseMessage> messages);

  /// Marks the id/muid index maps stale after the rows shown changed (insert,
  /// remove, reorder, replace); the next [findMessageIndex] or
  /// [findMessageIndexByMuid] rebuilds them from the state.
  void markIndexMapsDirty();

  /// Row index of the message with server [messageId], rebuilding the index
  /// maps first when dirty.
  int? findMessageIndex(int messageId);

  /// Row index of the message with [muid], rebuilding the index maps first
  /// when dirty.
  int? findMessageIndexByMuid(String muid);

  /// Seeds the reply-count notifier of a thread parent, as today's loads do
  /// for every loaded row with `replyCount > 0`.
  void initializeThreadReplyCount(int parentMessageId, int replyCount);

  /// The receipt notifier of [message] (by id, else muid; migrates muid → id).
  ValueNotifier<MessageReceiptStatus> receiptNotifierFor(BaseMessage message);

  /// Asks the animated list to rebuild every row (e.g. the unread marker).
  void notifyListChanged();

  /// Asks the animated list to rebuild the row of [messageId].
  void notifyMessageChanged(int messageId);

  // --- Request configuration (a read with no triggering event) --------------

  /// The uid or guid of the open chat.
  String? get conversationWith;

  /// `'user'` or `'group'`.
  String get conversationType;

  /// The list's message type filter.
  List<String>? get types;

  /// The list's message category filter.
  List<String>? get categories;

  /// Whether thread replies are hidden from the main list.
  bool get hideReplies;

  /// Whether a thread read includes its parent message.
  bool get withParent;

  /// Whether the list sends no read/delivery receipts.
  bool get disableReceipts;

  /// A request builder for this list seeded exactly as today's initial read
  /// (uid/guid, thread parent + `withParent`, types, categories,
  /// `hideReplies`, [limit]) with no anchor; the caller adds `messageId` or a
  /// timestamp if it needs one.
  MessagesRequestBuilder newMessagesRequestBuilder({int limit = 30});

  /// Rebuilds [olderRequest] and [newerRequest] as today's loads do, anchored
  /// on [oldestMessageId] / [newestMessageId] (pass ids of rows with a server
  /// id; null or ≤ 0 means unanchored).
  void initializeCursors({int? oldestMessageId, int? newestMessageId});

  /// The logged-in user, cached on the bloc the first time (as today's
  /// initial load does).
  User? resolveLoggedInUser();

  /// Returns and clears the bloc's "skip the next unread-anchor detection"
  /// flag (set after the user sends or resets the unread state).
  bool consumeSkipNextUnreadDetection();

  /// Bumps the list generation and clears the rows, index maps and cursors
  /// (as a session end does), so every read in flight stops writing. Returns
  /// a context bound to the new generation; this one is stale from now on.
  /// Call it from a hub collector or a [MessageListSeamHost.run] body, not
  /// from inside a read hook.
  MessageListSeamContext resetList();
}

/// Gives a seam a way into the bloc from outside a handler (app resume, a
/// hub collector that needs a later emit): [run] queues [body] on the bloc's
/// event loop with a context bound to a live emitter.
abstract interface class MessageListSeamHost {
  /// Queues [body] on the bloc's event loop with a context bound to a live emitter.
  void run(FutureOr<void> Function(MessageListSeamContext ctx) body);

  /// Whether the bloc is closed.
  bool get isClosed;
}

final Expando<MessageListSeamHost> _hosts = Expando('MessageListSeamHost');

/// Registers [host] for [bloc]. Called by the bloc at construction.
void registerMessageListSeamHost(Object bloc, MessageListSeamHost host) =>
    _hosts[bloc] = host;

/// The seam host of [bloc], or null (e.g. a test double).
MessageListSeamHost? messageListSeamHostOf(Object bloc) => _hosts[bloc];
