import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart';

import '../../../chat_ui/src/message_list/bloc/message_list_event.dart';
import '../../../chat_ui/src/message_list/bloc/message_list_state.dart';
import '../../../chat_ui/src/message_list/utils/message_operation.dart';
import 'message_key.dart';
import 'message_list_offline_reads.dart';
import 'message_list_seam_context.dart';
import 'message_send_state.dart';
import 'offline_hub.dart';
import 'offline_hub_event.dart';
import 'offline_notice.dart';

/// W5's seam: reconnect and sync in the message list, cache reset,
/// effective-offline transitions and message pin/save echo (W1 §2.9).
///
/// On the offline path the SDK's reconnect sweep catches the open chat up; the
/// list only listens. It makes no message fetch on reconnect or resume, except
/// one newest-window read (W2's `refreshNewestWindow`) after a PARTIAL sweep or
/// a sync error, and one for a list still empty on reconnect (D58). Every hook
/// runs only when offline is on, except [checkEffectiveOff], whose job is to
/// notice that offline went off, and the pure [isPinSaveNoOp] check (G11 has
/// no offline gate).
class MessageListOfflineSync {
  MessageListOfflineSync._();

  /// The single instance.
  static final MessageListOfflineSync instance = MessageListOfflineSync._();

  /// `source` the SDK stamps on messages delivered by the reconnect sweep
  /// (BEH-SYNC-13).
  static const String syncSource = 'SYNC';

  /// Chats read while offline in this session: conversation key → the newest
  /// message the list tried to mark read. Each gets one `markAsRead` after the
  /// next message sync.
  final Map<String, BaseMessage> _readOffline = <String, BaseMessage>{};

  /// Row keys of un-acked rows turned failed because offline went off under
  /// them (C6). In memory only: their outbox rows are gone, so Retry is a fresh
  /// send, never `retryMessage`.
  final Set<String> _directFailedKeys = <String>{};

  /// The logged-in uid the chats in [_readOffline] were read as.
  String? _readOfflineUid;

  /// Conversations that got their read receipt for a sweep: the read-offline
  /// flush and a main list's cumulative receipt each claim a conversation, so
  /// it gets one `markAsRead` whichever runs first.
  final Expando<Set<String>> _receiptsSent = Expando<Set<String>>(
    'MessageListOfflineSync.receipts',
  );

  /// The process-level hub subscription that flushes [_readOffline] after a
  /// sweep, with or without a message list mounted. Started by the first
  /// failed `markAsRead` (offline on only).
  StreamSubscription<OfflineHubEvent>? _hubSub;

  /// Whether an offline-path hook of this seam ran in this session. Until one
  /// has, no row can be an un-acked offline row, so [checkEffectiveOff] reads
  /// nothing (the OFF path stays exactly today's).
  bool _sawOn = false;

  /// Rows turned failed by [checkEffectiveOff] whose `MessagesNotSent` notice
  /// has not gone out yet (lists that run the check in the same turn add up).
  int _notSentPending = 0;

  /// Whether this switch-off already posted its `MessagesNotSent` notice. A
  /// switch-off strands every un-acked row at once (with offline off no new
  /// one is made), so a list that runs the check later turns its rows failed
  /// without a second notice. Cleared when an offline-path hook runs again.
  bool _notSentPosted = false;

  bool _markOn() {
    _notSentPosted = false;
    return _sawOn = true;
  }

  /// Test seam: replaces `CometChat.markAsRead` for the read-offline flush.
  @visibleForTesting
  void Function(BaseMessage message)? debugMarkAsRead;

  /// Test seam: observes the newest-window refresh before it runs.
  @visibleForTesting
  void Function()? debugOnRefreshNewestWindow;

  // --- Reconnect and resume (invariant 1) -----------------------------------

  /// Hook: `_handleConnected`. No kit missed-message fetch: the SDK's sweep
  /// delivers what was missed. A list still empty (opened offline, nothing
  /// cached) reads the newest page once (D58).
  bool handleConnected(MessageListSeamHost host) {
    host.run(MessageListOfflineReads.instance.readNewestIfEmpty);
    return _markOn();
  }

  /// Hook: `_onSyncMessages`. Nothing is fetched (the event is dispatched only
  /// by reconnect and resume).
  Future<bool>? handleSyncMessages(
    MessageListSeamContext ctx,
    SyncMessages event,
  ) => Future<bool>.value(_markOn());

  /// Hook: `_handleCallActivity` (a call of the open chat started or stopped
  /// ringing). A new call message reaches no message listener (BEH-SYNC-25)
  /// and the sweep does not run, so the newest page is read from the server
  /// and merged in ([MessageListOfflineReads.refreshNewestForCall]); this
  /// replaces the `SyncMessages` dispatch that brings it in with offline off.
  bool handleCallActivity(MessageListSeamHost host) {
    host.run(MessageListOfflineReads.instance.refreshNewestForCall);
    return _markOn();
  }

  /// Hook: the app-resume dispatch in `CometChatMessageList`. No foreground
  /// fetch. A reconnect read's mark that no sync outcome took is cleared, so
  /// a later PARTIAL sweep refreshes (D58).
  bool handleResume(MessageListSeamHost host) {
    host.run(MessageListOfflineReads.instance.clearReconnectRead);
    return _markOn();
  }

  // --- Messages delivered by the sweep ----------------------------------------

  /// Whether [message] was delivered by the reconnect sweep: inserted in
  /// sorted place with no sound, no notification and no per-message receipt.
  static bool isSyncDelivery(BaseMessage message) =>
      message.source == syncSource;

  /// Inserts [message] (already filtered, deduplicated and intercepted by the
  /// bloc) in sorted place — `(sentAt, id)`, un-acked rows last (BEH-READ-10) —
  /// and returns its index. Plays nothing and marks nothing read.
  int insertSorted(MessageListSeamContext ctx, BaseMessage message) {
    final rows = ctx.state.messages;
    final index = sortedIndexFor(rows, message);
    final updated = List<BaseMessage>.of(rows)..insert(index, message);
    ctx.markIndexMapsDirty();
    if (message.id > 0 && message.replyCount > 0) {
      ctx.initializeThreadReplyCount(message.id, message.replyCount);
    }
    ctx.emit(
      ctx.state.copyWith(status: MessageListStatus.loaded, messages: updated),
    );
    ctx.addOperation(MessageOperation.insert(message, index, animated: false));
    return index;
  }

  /// Index at which [message] belongs in [rows], which are sorted by
  /// `(sentAt, id)` with un-acked rows (no server id) last.
  @visibleForTesting
  static int sortedIndexFor(List<BaseMessage> rows, BaseMessage message) {
    if (message.id <= 0) return rows.length;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.id <= 0) return i;
      if (_compare(message, row) < 0) return i;
    }
    return rows.length;
  }

  static int _compare(BaseMessage a, BaseMessage b) {
    final at = a.sentAt?.millisecondsSinceEpoch ?? 0;
    final bt = b.sentAt?.millisecondsSinceEpoch ?? 0;
    if (at != bt) return at.compareTo(bt);
    return a.id.compareTo(b.id);
  }

  // --- Read receipts -------------------------------------------------------------

  /// Hook: a failed `markAsRead` in the message list (the error stays
  /// swallowed, as today). Remembers the chat so one `markAsRead` goes out for
  /// it after the next message sync.
  void noteMarkReadFailed(MessageListSeamContext ctx, BaseMessage message) {
    final myUid = ctx.loggedInUser?.uid;
    final key = _conversationKeyOf(message, myUid);
    if (key == null) return;
    _readOfflineUid = myUid;
    _hubSub ??= OfflineHub.instance.events.listen(_onProcessHubEvent);
    final prev = _readOffline[key];
    if (prev == null || _compare(prev, message) <= 0) {
      _readOffline[key] = message;
    }
  }

  /// Chats remembered as read while offline (test inspection).
  @visibleForTesting
  Map<String, BaseMessage> get debugReadOffline =>
      Map<String, BaseMessage>.unmodifiable(_readOffline);

  static String? _conversationKeyOf(BaseMessage m, String? myUid) {
    if (m.receiverType == CometChatReceiverType.group) {
      return 'group:${m.receiverUid}';
    }
    final sender = m.sender?.uid;
    final other = (sender != null && sender != myUid) ? sender : m.receiverUid;
    if (other.isEmpty) return null;
    return 'user:$other';
  }

  static String _openKey(MessageListSeamContext ctx) =>
      '${ctx.conversationType}:${ctx.conversationWith}';

  // --- Effective-offline transitions (C6) -------------------------------------

  /// Whether [checkEffectiveOff] can find anything: an offline-path hook ran
  /// in this session. False with offline never on, so a caller on the OFF
  /// path can skip building a context.
  bool get mayHaveStrandedRows => _sawOn;

  /// Called at the next operation the list sees (a connection event, resume
  /// or received message) while the gate reads **off**. If the list still
  /// shows un-acked offline rows (they carry a `localMessageId`; a send made
  /// with offline off never does), offline went off under them: they turn
  /// failed (direct) in place — Retry is a fresh send — and one
  /// `MessagesNotSent(n)` notice goes out through the hub's single-delivery
  /// queue, once across every mounted list. No reload. With offline never on
  /// there is no such row, so nothing changes.
  void checkEffectiveOff(MessageListSeamContext ctx) {
    if (!_sawOn) return;
    final rows = ctx.state.messages;
    var count = 0;
    for (var i = 0; i < rows.length; i++) {
      final m = rows[i];
      if (m.id > 0) continue;
      final lid = m.localMessageId;
      if (lid == null || lid.isEmpty) continue;
      if (sendStateOf(m) != CometChatMessageSendState.sending) continue;
      m.sendState = 'FAILED';
      ctx.addOperation(MessageOperation.update(m, m, i));
      count++;
      // A row both lists show (a reply in the main list) counts once.
      if (_directFailedKeys.add(rowKey(m))) _queueNotSent();
    }
    if (count == 0) return;
    ctx.emit(ctx.state.copyWith(messages: List<BaseMessage>.of(rows)));
  }

  /// Adds one row to this switch-off's `MessagesNotSent` notice, posted once
  /// after every list that runs the check in this turn has added its rows.
  void _queueNotSent() {
    if (_notSentPosted) return;
    if (_notSentPending++ > 0) return;
    Timer.run(() {
      final n = _notSentPending;
      _notSentPending = 0;
      if (n == 0 || _notSentPosted) return;
      _notSentPosted = true;
      OfflineHub.instance.postNotice(MessagesNotSent(n), whenOff: true);
    });
  }

  /// Whether [message] was turned failed by [checkEffectiveOff]: its Retry is
  /// a fresh send (no outbox row exists any more).
  bool isDirectFailure(BaseMessage message) =>
      _directFailedKeys.contains(rowKey(message));

  /// Forgets a direct failure (after its Retry or Delete).
  void clearDirectFailure(BaseMessage message) =>
      _directFailedKeys.remove(rowKey(message));

  // --- Own pin/save echo (G11, BEH-FLAG-04) -----------------------------------

  /// Whether a pin/save change for [current] is a no-op because the row
  /// already shows that state. Own actions update the row from `onSuccess`;
  /// SDK 5.1.0 also echoes them, and the echo must not re-apply.
  bool isPinSaveNoOp(
    BaseMessage current,
    BaseMessage incoming, {
    required bool isPinScope,
  }) {
    if (isPinScope) {
      return (current.pinnedAt != null) == (incoming.pinnedAt != null) &&
          current.pinnedBy == incoming.pinnedBy;
    }
    return (current.savedAt != null) == (incoming.savedAt != null);
  }

  // --- Hub collector ----------------------------------------------------------

  /// Hub collector, called inside the bloc's event loop for every current-gen
  /// hub event.
  Future<void> onHubEvent(
    MessageListSeamContext ctx,
    OfflineHubEvent event,
  ) async {
    _markOn();
    switch (event) {
      case MessageSyncCompleted():
        _onMessageSyncCompleted(ctx, event);
        final readOnReconnect = _takeReconnectRead(ctx);
        if (event.outcome == SyncOutcome.partial && !readOnReconnect) {
          await _refreshNewestWindow(ctx);
        }
      case MessageSyncFailed():
        if (!_takeReconnectRead(ctx)) await _refreshNewestWindow(ctx);
      case MessagesUpdated():
        _onMessagesUpdated(ctx, event.messages);
      case CacheReset():
        _onCacheReset(ctx);
      case SessionEnded():
        _endSession();
      default:
        // MediaReady: media bubbles re-resolve themselves
        // (`OfflineMediaSource`); the rows do not change.
        break;
    }
  }

  /// Whether the reconnect already read the newest page of this list (D58):
  /// then the sync outcome reads nothing more.
  bool _takeReconnectRead(MessageListSeamContext ctx) =>
      MessageListOfflineReads.instance.takeReconnectRead(ctx.owner);

  /// One newest-window read (W2) after a PARTIAL sweep or a sync error.
  Future<void> _refreshNewestWindow(MessageListSeamContext ctx) {
    debugOnRefreshNewestWindow?.call();
    return MessageListOfflineReads.instance.refreshNewestWindow(ctx);
  }

  /// Upserts the sweep into the open chat. Text, media, custom and
  /// interactive rows already arrived on the received callbacks tagged SYNC
  /// (BEH-SYNC-13), so only `action` and `call` rows — on no MessageListener
  /// channel (BEH-SYNC-25) — are re-dispatched; they run today's received path
  /// (filters, dedupe, a call's in-place update, a group action such as the
  /// user's own removal) with the SYNC treatment. Then one cumulative read
  /// receipt. (The header and the app route a swept self-removal through
  /// `SweptSelfRemoval`; chats read offline are flushed by
  /// [_flushReadOffline], which needs no mounted list.)
  void _onMessageSyncCompleted(
    MessageListSeamContext ctx,
    MessageSyncCompleted event,
  ) {
    for (final m in event.messages) {
      if (m.category != CometChatMessageCategory.action &&
          m.category != CometChatMessageCategory.call) {
        continue;
      }
      m.source ??= syncSource;
      ctx.add(MessageReceived(m));
    }

    // One cumulative read receipt for the newest incoming message, when the
    // list shows the newest window (the user is at the bottom).
    if (ctx.disableReceipts || ctx.state.hasMoreNewer) return;
    final myUid = ctx.loggedInUser?.uid;
    final openKey = _openKey(ctx);
    BaseMessage? newest;
    void consider(BaseMessage m) {
      if (!_isReadable(m, myUid)) return;
      final n = newest;
      if (n == null || _compare(n, m) < 0) newest = m;
    }

    ctx.state.messages.forEach(consider);
    for (final m in event.messages) {
      if (_conversationKeyOf(m, myUid) == openKey && _inThisList(ctx, m)) {
        consider(m);
      }
    }
    final target = newest;
    if (target == null) return;
    // A thread list marks its own replies; a main list shares the
    // conversation's one receipt with the read-offline flush.
    if (ctx.parentMessageId == null) {
      if (!_claimReceipt(event, openKey)) return;
      _readOffline.remove(openKey);
    }
    ctx.add(MarkMessageAsRead(target));
  }

  static bool _isReadable(BaseMessage m, String? myUid) =>
      m.id > 0 &&
      m.sender?.uid != myUid &&
      m.category != CometChatMessageCategory.action &&
      m.category != CometChatMessageCategory.call;

  bool _claimReceipt(MessageSyncCompleted event, String key) =>
      (_receiptsSent[event] ??= <String>{}).add(key);

  /// Process-level hub listener (no mounted list needed).
  void _onProcessHubEvent(OfflineHubEvent event) {
    if (event.gen < OfflineHub.instance.gen) return;
    switch (event) {
      case MessageSyncCompleted():
        // After the mounted lists have handled the sweep, so an open chat at
        // the bottom keeps its receipt on the list's own path.
        Timer.run(() => _flushReadOffline(event));
      case SessionEnded():
        _endSession();
      default:
        break;
    }
  }

  /// Chats read while offline: one `markAsRead` each after the sweep, for the
  /// newest of the remembered message and the sweep's messages in that chat.
  /// Runs whether or not a list is mounted.
  void _flushReadOffline(MessageSyncCompleted event) {
    if (event.gen < OfflineHub.instance.gen || _readOffline.isEmpty) return;
    final myUid = _readOfflineUid;
    final pending = Map<String, BaseMessage>.of(_readOffline);
    _readOffline.clear();
    pending.forEach((key, remembered) {
      // Already marked by a list for this sweep; still remembered only if
      // that receipt failed too, so keep it for the next sweep.
      if (!_claimReceipt(event, key)) {
        _readOffline[key] = remembered;
        return;
      }
      var target = remembered;
      for (final m in event.messages) {
        if (_isReadable(m, myUid) &&
            _conversationKeyOf(m, myUid) == key &&
            _compare(target, m) < 0) {
          target = m;
        }
      }
      _markAsRead(target);
    });
  }

  void _endSession() {
    _readOffline.clear();
    _readOfflineUid = null;
    _directFailedKeys.clear();
    _sawOn = false;
    _notSentPending = 0;
    _notSentPosted = false;
  }

  static bool _inThisList(MessageListSeamContext ctx, BaseMessage m) {
    final parent = ctx.parentMessageId;
    if (parent != null) return m.parentMessageId == parent;
    return m.parentMessageId == 0 || !ctx.hideReplies;
  }

  void _markAsRead(BaseMessage message) {
    final override = debugMarkAsRead;
    if (override != null) {
      override(message);
      return;
    }
    try {
      CometChat.markAsRead(message, onSuccess: (_) {}, onError: (_) {});
    } catch (_) {
      // Swallowed: offline errors from markAsRead never surface.
    }
  }

  /// Updates the rows shown with edits, deletes and reactions from
  /// `onMessagesSynced` (BEH-INV-11). Never inserts.
  void _onMessagesUpdated(
    MessageListSeamContext ctx,
    List<BaseMessage> messages,
  ) {
    for (final m in messages) {
      if (m.id <= 0 || ctx.findMessageIndex(m.id) == null) continue;
      ctx.add(m.deletedAt != null ? MessageDeleted(m) : MessageEdited(m));
    }
  }

  /// Cache reset (G8): bump the generation, clear and reload two-phase. The
  /// notice is posted once by the hub (it queues until a list attaches); the
  /// public `ccOfflineCacheReset` event is emitted by the hub.
  void _onCacheReset(MessageListSeamContext ctx) {
    MessageListOfflineReads.instance.clearReconnectRead(ctx);
    final conversationWith = ctx.conversationWith;
    final fresh = ctx.resetList();
    if (conversationWith == null) return;
    fresh.add(
      LoadMessages(
        conversationWith: conversationWith,
        conversationType: ctx.conversationType,
        parentMessageId: ctx.parentMessageId,
        types: ctx.types,
        categories: ctx.categories,
      ),
    );
  }

  /// Test-only: clears the session state.
  @visibleForTesting
  void debugReset() {
    _endSession();
    _hubSub?.cancel();
    _hubSub = null;
    debugMarkAsRead = null;
    debugOnRefreshNewestWindow = null;
  }
}
