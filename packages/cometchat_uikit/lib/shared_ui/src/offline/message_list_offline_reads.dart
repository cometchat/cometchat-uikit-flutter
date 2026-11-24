import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart';

import '../../../chat_ui/src/message_list/bloc/message_list_event.dart';
import '../../../chat_ui/src/message_list/bloc/message_list_state.dart';
import '../../../chat_ui/src/message_list/utils/message_operation.dart';
import '../constants/ui_kit_constants.dart' show MessageCategoryConstants;
import 'message_key.dart';
import 'message_list_seam_context.dart';
import 'offline_gate.dart';
import 'offline_list_errors.dart';
import 'offline_list_reconcile.dart';
import 'two_phase.dart';

/// Per-list view state of the offline reads, kept per bloc
/// ([MessageListSeamContext.owner]) and read by `CometChatMessageList`.
/// Internal to the kit.
class MessageListReadsView {
  /// Creates the view state of one list.
  MessageListReadsView();

  /// True while scrolling back is blocked because the device is offline past
  /// its cached history: the list shows "Connect to load more" with
  /// tap-to-retry (PR #23 §3.3, AC-4.3).
  final ValueNotifier<bool> connectToLoadMore = ValueNotifier<bool>(false);

  /// True while a newer window exists than the one shown and the user is
  /// scrolled away from the bottom: the list shows a "Jump to latest" pill.
  final ValueNotifier<bool> jumpToLatest = ValueNotifier<bool>(false);

  /// Bumped each time a window read's server page lands, so the list is
  /// connected and shows that page. The widget waits on it to request
  /// conversation starters for a chat that opened offline and empty.
  final ValueNotifier<int> serverReads = ValueNotifier<int>(0);

  /// Set by the widget: whether the list is pinned to its newest row.
  bool Function()? isAtBottom;

  /// Whether the list's error state is the offline state (D84 (3)): a window
  /// read with nothing to show failed because the device is offline. The
  /// widget shows "Connect to load messages" (no Retry) for it instead of the
  /// error view. Set with every error state a window read emits; the widget
  /// clears it when the list leaves the error state.
  bool showsOfflineState = false;

  /// Token of the latest window read (initial load, refresh, unread open,
  /// jump, newest-window refresh). A phase of an older read is dropped.
  int _windowToken = 0;

  /// The read "Connect to load more" retries: the last one that failed
  /// because the device is not connected.
  VoidCallback? _retry;

  /// Whether [_retry] reads an older or newer page (not a window): the page
  /// behind the footer, which a reconnect loads once by itself (D84 (9)).
  bool _retryIsPage = false;

  /// Newest-window refreshes in flight.
  int _refreshes = 0;

  /// Opening reads in flight: initial loads, unread opens and jumps.
  int _opens = 0;

  /// Set when a reconnect read the newest page of an empty list (D58); the
  /// next sync outcome takes it, so a PARTIAL sweep or a sync error does not
  /// read that page a second time. A resume or a cache reset clears it, so it
  /// never outlives that reconnect.
  bool _reconnectRead = false;

  /// Set when a connect arrived while a read was in flight. That read was
  /// sent before the connect and may still end not connected, so the connect
  /// is looked at again when the read ends (D58).
  bool _connectPending = false;

  /// Set when the last older-page read ended not connected with no cached
  /// row to add: the list is offline past its cached history.
  bool _olderPastCache = false;

  /// Whether scrolling to the top must not read an older page: "Connect to
  /// load more" is up and the last older read found nothing more in the
  /// cache. The footer's tap still retries ([retry]).
  bool get olderReadBlocked => connectToLoadMore.value && _olderPastCache;

  /// Retries the read that failed offline (the footer's tap). Returns false
  /// when there is none to retry.
  bool retry() {
    final r = _retry;
    if (r == null) return false;
    r();
    return true;
  }

  void _offline(VoidCallback retry, {bool page = false}) {
    _retry = retry;
    _retryIsPage = page;
    connectToLoadMore.value = true;
  }

  /// Takes the footer down for a reconnect and returns the page read behind
  /// it, if any, so the caller runs it once. Later reconnects find none.
  VoidCallback? _takePageRetry() {
    final retry = connectToLoadMore.value && _retryIsPage ? _retry : null;
    if (retry != null) {
      _retry = null;
      _retryIsPage = false;
    }
    _online();
    return retry;
  }

  /// Takes the footer down: a read is starting, or the device reconnected.
  void _online() {
    connectToLoadMore.value = false;
    _olderPastCache = false;
  }
}

/// The scroll-to-top trigger's check (ON path only): true when the list must
/// not dispatch `LoadOlderMessages` because it is offline past its cached
/// history ([MessageListReadsView.olderReadBlocked]). False with offline off.
bool skipOlderReadOnScroll(Object bloc) =>
    OfflineGate.isOn() && messageListReadsViewOf(bloc).olderReadBlocked;

final Expando<MessageListReadsView> _views = Expando<MessageListReadsView>(
  'MessageListReadsView',
);

/// The reads view state of the list owned by [owner] (its bloc).
MessageListReadsView messageListReadsViewOf(Object owner) =>
    _views[owner] ??= MessageListReadsView();

/// Error codes that mean "the network is gone", not "the server said no"
/// (what the SDK's transport and offline runtime report).
const Set<String> _notConnectedCodes = {
  'err_connection',
  'err_network_timeout',
  'error_internet_unavailable',
  'error_io_exception',
};

/// Whether [e] means the device is not connected (also the conversation
/// list's D75 mark).
bool isNotConnectedError(CometChatException e) {
  for (final s in [e.code, e.details, e.message]) {
    if (s != null && _notConnectedCodes.contains(s.toLowerCase())) return true;
  }
  return false;
}

/// The message-list order on the ON path (BEH-READ-10): sent rows by
/// `(sentAt, id)`; un-acked rows (no server id) after them, by compose time.
@visibleForTesting
int compareMessageRows(BaseMessage a, BaseMessage b) {
  final aSent = a.id > 0, bSent = b.id > 0;
  if (aSent != bSent) return aSent ? -1 : 1;
  final ta = a.sentAt?.millisecondsSinceEpoch;
  final tb = b.sentAt?.millisecondsSinceEpoch;
  if (aSent) {
    if (ta != null && tb != null && ta != tb) return ta.compareTo(tb);
    return a.id.compareTo(b.id);
  }
  final c = (ta ?? _maxMs).compareTo(tb ?? _maxMs);
  if (c != 0) return c;
  return rowKey(a).compareTo(rowKey(b));
}

const int _maxMs = 8640000000000000;

int _updatedAtOf(BaseMessage m) {
  // An un-acked copy never replaces an acked one, whatever its timestamps.
  if (m.id <= 0) return -1;
  var t = m.updatedAt?.millisecondsSinceEpoch ?? 0;
  final edited = m.editedAt?.millisecondsSinceEpoch ?? 0;
  final deleted = m.deletedAt?.millisecondsSinceEpoch ?? 0;
  if (edited > t) t = edited;
  if (deleted > t) t = deleted;
  return t;
}

/// The reconcile configuration for merging [incoming] into [current]: keys by
/// [rowKey] with the alias map applied (G6), so an un-acked row and its acked
/// copy (same `localMessageId`, sender and conversation, or the own `muid`)
/// collapse onto one row instead of showing twice.
@visibleForTesting
ReconcileConfig<BaseMessage> messageReconcileConfig(
  List<BaseMessage> current,
  List<BaseMessage> incoming,
  String? myUid,
) {
  final index = MessageIdentityIndex(myUid: myUid);
  for (final m in current) {
    index.put(m);
  }
  final aliases = Map<BaseMessage, String>.identity();
  for (final m in incoming) {
    final hit = index.lookup(m);
    if (hit == null || identical(hit, m)) continue;
    final hitKey = rowKey(hit), key = rowKey(m);
    if (hitKey == key) continue;
    if (hit.id <= 0 && m.id > 0) {
      aliases[hit] = key; // the un-acked row shown → its incoming acked copy
    } else if (hit.id > 0 && m.id <= 0) {
      aliases[m] = hitKey; // a stale un-acked copy of a row already acked
    }
  }
  return ReconcileConfig<BaseMessage>(
    rowKey: (m) => aliases[m] ?? rowKey(m),
    hasServerId: (m) => m.id > 0,
    updatedAt: _updatedAtOf,
    compare: compareMessageRows,
    merge: keepLaterReceipts,
  );
}

/// Merges two copies of one message: [kept] keeps the later non-null
/// `deliveredAt` and `readAt` of either copy, so a later copy that carries no
/// receipts never takes a delivered or read message back to "sent". Updates
/// [kept] in place, as the live receipt handlers do.
@visibleForTesting
BaseMessage keepLaterReceipts(BaseMessage kept, BaseMessage dropped) {
  final delivered = _later(kept.deliveredAt, dropped.deliveredAt);
  if (!identical(delivered, kept.deliveredAt)) kept.deliveredAt = delivered;
  final read = _later(kept.readAt, dropped.readAt);
  if (!identical(read, kept.readAt)) kept.readAt = read;
  return kept;
}

DateTime? _later(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return b.isAfter(a) ? b : a;
}

BaseMessage? _oldestWithServerId(List<BaseMessage> rows) {
  for (final m in rows) {
    if (m.id > 0) return m;
  }
  return null;
}

BaseMessage? _newestWithServerId(List<BaseMessage> rows) {
  for (var i = rows.length - 1; i >= 0; i--) {
    if (rows[i].id > 0) return rows[i];
  }
  return null;
}

/// W2's seam: two-phase reads for the message list (main + thread), windowed
/// reconcile, open-newest-first, stable render keys (W1 §2.9, PR #23 §3.3).
///
/// Each `handle…` is called from its matching `MessageListBloc` handler, only
/// when offline is on, with a [MessageListSeamContext] bound to that handler's
/// emitter. Return `null` to fall through to today's code with no async gap;
/// return a future that completes `true` when the read was handled (the bloc
/// then returns) or `false` to fall through. A list whose datasource has no
/// two-phase reader (a custom datasource) keeps today's single-phase reads.
class MessageListOfflineReads {
  MessageListOfflineReads._();

  /// The single instance.
  static final MessageListOfflineReads instance = MessageListOfflineReads._();

  MessageListTwoPhaseDataSource? _reader(MessageListSeamContext ctx) =>
      messageListTwoPhaseFor(ctx.remoteDataSource);

  /// Hook: `_onLoadMessages`. Reads the newest page in two phases.
  Future<bool>? handleLoad(MessageListSeamContext ctx, LoadMessages event) {
    final reader = _reader(ctx);
    if (reader == null) return null;
    return _opening(ctx, () => _load(ctx, reader, event));
  }

  /// Hook: `_onLoadOlderMessages`. Reads the page before the oldest row with a
  /// server id in two phases.
  Future<bool>? handleLoadOlder(
    MessageListSeamContext ctx,
    LoadOlderMessages event,
  ) {
    final reader = _reader(ctx);
    if (reader == null) return null;
    return _loadPage(ctx, reader, older: true);
  }

  /// Hook: `_onLoadNewerMessages`. Reads the page after the newest row with a
  /// server id in two phases.
  Future<bool>? handleLoadNewer(
    MessageListSeamContext ctx,
    LoadNewerMessages event,
  ) {
    final reader = _reader(ctx);
    if (reader == null) return null;
    return _loadPage(ctx, reader, older: false);
  }

  /// Hook: `_onRefreshMessages`. Today's refresh clears the cursors and
  /// dispatches `LoadMessages`, which [handleLoad] reads in two phases with no
  /// loader over the rows shown; nothing more is needed here.
  Future<bool>? handleRefresh(
    MessageListSeamContext ctx,
    RefreshMessages event,
  ) => null;

  /// Hook: `_onLoadFromUnread`. Opens newest first (G2): the newest page in two
  /// phases, then the unread anchor with the SDK's anchored read when it lies
  /// outside that page; the gap loads on scroll as today.
  Future<bool>? handleLoadFromUnread(
    MessageListSeamContext ctx,
    LoadFromUnread event,
  ) {
    // A thread has no unread anchor: today's code dispatches LoadMessages.
    if (ctx.parentMessageId != null) return null;
    final reader = _reader(ctx);
    if (reader == null) return null;
    return _opening(ctx, () => _loadFromUnread(ctx, reader, event));
  }

  /// Hook: `_onJumpToMessage`. Shows the page around the target with the
  /// SDK's anchored reads (BEH-READ-29), keeping the rows without a server id
  /// (BEH-READ-30); only an empty online server page ends newer history
  /// (BEH-READ-09b).
  Future<bool>? handleJumpToMessage(
    MessageListSeamContext ctx,
    JumpToMessage event,
  ) {
    final reader = _reader(ctx);
    if (reader == null) return null;
    return _opening(ctx, () => _jumpToMessage(ctx, reader, event));
  }

  /// Runs an opening read, counted so a reconnect never reads over it (D58).
  Future<bool> _opening(
    MessageListSeamContext ctx,
    Future<bool> Function() read,
  ) async {
    final view = messageListReadsViewOf(ctx.owner);
    view._opens++;
    try {
      return await read();
    } finally {
      view._opens--;
      _replayConnect(ctx.owner);
    }
  }

  /// Refreshes the newest window of the open chat (a fresh two-phase initial
  /// read with no anchor). When the server page overlaps the rows shown it
  /// merges in place; otherwise the list resets to that window if it is pinned
  /// to the bottom, or keeps its place and shows a "Jump to latest" pill.
  /// Called by W5's sync seam after a PARTIAL sweep or a sync error.
  Future<void> refreshNewestWindow(MessageListSeamContext ctx) async {
    final reader = _reader(ctx);
    if (reader == null || ctx.conversationWith == null) return;
    final request = ctx.newMessagesRequestBuilder().build();
    final owner = ctx.owner;
    final view = messageListReadsViewOf(owner);
    view._refreshes++;
    try {
      await _readWindow(
        ctx,
        reader.fetchPreviousTwoPhase(request),
        refreshNewest: true,
        retry: () => messageListSeamHostOf(owner)?.run(refreshNewestWindow),
      );
    } finally {
      view._refreshes--;
      _replayConnect(owner);
    }
  }

  /// Reads the newest page from the server for a call activity of the open
  /// chat: a call message reaches no message listener (BEH-SYNC-25), and the
  /// cache cannot hold one the server just wrote. The page merges like
  /// [refreshNewestWindow]'s (by message id, rows without a server id kept),
  /// so a call already shown is updated, never added twice. The cached phase
  /// is not applied, and a failed read changes nothing (no "Connect to load
  /// more"): offline, the call cannot be known. An opening read or a jump in
  /// flight is left alone (it is not superseded).
  Future<void> refreshNewestForCall(MessageListSeamContext ctx) async {
    final reader = _reader(ctx);
    if (reader == null || ctx.conversationWith == null) return;
    final owner = ctx.owner;
    final view = messageListReadsViewOf(owner);
    if (view._opens > 0) return;
    final request = ctx.newMessagesRequestBuilder().build();
    view._refreshes++;
    try {
      await _readWindow(
        ctx,
        reader.fetchPreviousTwoPhase(request),
        refreshNewest: true,
        serverOnly: true,
        retry: () => messageListSeamHostOf(owner)?.run(refreshNewestWindow),
      );
    } finally {
      view._refreshes--;
      _replayConnect(owner);
    }
  }

  /// On reconnect, a list that is still empty because its last read ended
  /// not connected (opened offline, nothing cached: the offline state, D84)
  /// reads the newest page once with [refreshNewestWindow] (D58). A list with
  /// rows reads no window (the SDK's sweep catches it up); its "Connect to
  /// load more" footer comes down and the older or newer page behind it is
  /// read once (D84 (9)). Nothing is read over a loader. A connect while a read is in
  /// flight (an opening read, a jump or a newest-window refresh) lets it
  /// finish, then is looked at once more when it ends: that read was sent
  /// before the connect and may still have ended not connected.
  Future<void> readNewestIfEmpty(MessageListSeamContext ctx) async {
    final view = messageListReadsViewOf(ctx.owner);
    if (view._opens > 0 || view._refreshes > 0) {
      view._connectPending = true;
      return;
    }
    view._reconnectRead = false;
    await _readAfterConnect(ctx);
  }

  /// The body of [readNewestIfEmpty], also run for a connect that arrived
  /// while a read was in flight, once that read ends. It leaves the mark of
  /// a reconnect read that already ran alone.
  Future<void> _readAfterConnect(MessageListSeamContext ctx) async {
    final view = messageListReadsViewOf(ctx.owner);
    if (view._opens > 0 || view._refreshes > 0) {
      view._connectPending = true;
      return;
    }
    view._connectPending = false;
    if (_reader(ctx) == null) return;
    if (ctx.state.messages.isNotEmpty) {
      view._takePageRetry()?.call();
      return;
    }
    if (ctx.conversationWith == null) return;
    if (!view.connectToLoadMore.value) return;
    if (ctx.state.status == MessageListStatus.loading) return;
    view._reconnectRead = true;
    await refreshNewestWindow(ctx);
  }

  /// Runs a connect that arrived during a read once no read is in flight.
  void _replayConnect(Object owner) {
    final view = messageListReadsViewOf(owner);
    if (!view._connectPending || view._opens > 0 || view._refreshes > 0) {
      return;
    }
    view._connectPending = false;
    messageListSeamHostOf(owner)?.run(_readAfterConnect);
  }

  /// Clears the mark [readNewestIfEmpty] left, unless that read is still in
  /// flight. Called on resume and cache reset, so a mark whose reconnect
  /// brought no sync outcome never swallows a later refresh.
  void clearReconnectRead(MessageListSeamContext ctx) {
    final view = messageListReadsViewOf(ctx.owner);
    if (view._refreshes == 0) view._reconnectRead = false;
  }

  /// Takes the mark [readNewestIfEmpty] left: true when this reconnect
  /// already read the newest page, so the sync outcome's refresh is skipped.
  bool takeReconnectRead(Object owner) {
    final view = messageListReadsViewOf(owner);
    final read = view._reconnectRead;
    view._reconnectRead = false;
    return read;
  }

  // ---------------------------------------------------------------------------

  Future<bool> _load(
    MessageListSeamContext ctx,
    MessageListTwoPhaseDataSource reader,
    LoadMessages event,
  ) async {
    // Today's initial request, with the event's overrides.
    final builder = ctx.newMessagesRequestBuilder();
    if (event.conversationType == 'user') {
      builder.uid = event.conversationWith;
      builder.guid = null;
    } else {
      builder.guid = event.conversationWith;
      builder.uid = null;
    }
    final parentId = event.parentMessageId ?? ctx.parentMessageId;
    if (parentId != null) {
      builder.parentMessageId = parentId;
      builder.withParent = ctx.withParent;
    }
    final t = event.types ?? ctx.types;
    if (t != null && t.isNotEmpty) builder.types = t;
    final c = event.categories ?? ctx.categories;
    if (c != null && c.isNotEmpty) builder.categories = c;

    final view = messageListReadsViewOf(ctx.owner);
    final outcome = await _readWindow(
      ctx,
      reader.fetchPreviousTwoPhase(builder.build()),
      retry: () => ctx.add(event),
    );
    final token = outcome.token;
    if (!outcome.applied || !_live(ctx)) return true;

    // As today: unread anchor before mark-as-read, so the counts are pre-read.
    if (ctx.consumeSkipNextUnreadDetection()) {
      // The user sent or reset the unread state: no anchor this time.
    } else if (ctx.state.status == MessageListStatus.loaded &&
        ctx.loggedInUser != null &&
        parentId == null &&
        ctx.state.unreadMessageAnchorId == null) {
      await _placeUnreadAnchor(
        ctx,
        event.conversationWith,
        event.conversationType,
      );
    }
    if (!_live(ctx) || token != view._windowToken) return true;
    if (outcome.serverOk) _markNewestRead(ctx);
    return true;
  }

  Future<bool> _loadFromUnread(
    MessageListSeamContext ctx,
    MessageListTwoPhaseDataSource reader,
    LoadFromUnread event,
  ) async {
    final view = messageListReadsViewOf(ctx.owner);
    // 1. The newest page, two-phase (G2: newest first).
    final outcome = await _readWindow(
      ctx,
      reader.fetchPreviousTwoPhase(ctx.newMessagesRequestBuilder().build()),
      retry: () => ctx.add(event),
    );
    final token = outcome.token;
    if (!outcome.applied || !_live(ctx)) return true;
    ctx.consumeSkipNextUnreadDetection();

    // 2. The unread boundary. Offline, the cached conversation answers (D60).
    final (conv, fromCache) = await _unreadConversation(
      ctx,
      event.conversationWith,
      event.conversationType,
    );
    if (!_live(ctx) || token != view._windowToken) return true;
    final lastReadId = conv?.lastReadMessageId ?? 0;
    final unreadCnt = conv?.unreadMessageCount ?? 0;
    if (conv == null || lastReadId <= 0 || unreadCnt <= 0) {
      if (outcome.serverOk) _markNewestRead(ctx);
      return true;
    }

    // 3. Jump to it with the SDK's anchored read unless the newest page
    // already reaches back to it.
    final oldest = _oldestWithServerId(ctx.state.messages);
    final inWindow =
        !ctx.state.hasMoreOlder || (oldest != null && oldest.id <= lastReadId);
    if (!inWindow) {
      // Null when a newer window read replaced the rows mid-read.
      final next = await _jumpToUnread(
        ctx,
        reader,
        lastReadId,
        token,
        () => ctx.add(event),
      );
      if (next == null || !_live(ctx)) return true;
      // Offline with the target not cached (D60): stay on the newest cached
      // page, with no anchor to scroll to.
      if (fromCache && next == token) return true;
    }
    final anchor = _firstUnread(ctx, ctx.state.messages, lastReadId);
    ctx.emit(
      ctx.state.copyWith(
        unreadMessageAnchor: anchor,
        unreadMessageAnchorId: anchor?.id,
        lastReadMessageId: lastReadId,
        unreadCount: unreadCnt,
        conversation: conv,
      ),
    );
    if (anchor != null) ctx.notifyListChanged();
    if (outcome.serverOk) _markNewestRead(ctx);
    return true;
  }

  /// The conversation that places the unread boundary, and whether it came
  /// from the cache. Read in two phases where the datasource supports it: the
  /// server's answers as today; offline (a not-connected server phase) the
  /// cached conversation answers instead (D60). Otherwise today's repository
  /// read.
  Future<(Conversation?, bool)> _unreadConversation(
    MessageListSeamContext ctx,
    String conversationWith,
    String conversationType,
  ) async {
    final source = conversationTwoPhaseFor(ctx.remoteDataSource);
    if (source == null) {
      final result = await ctx.repository.getConversation(
        conversationWith: conversationWith,
        conversationType: conversationType,
      );
      Conversation? conversation;
      result.fold((_) {}, (c) => conversation = c);
      return (conversation, false);
    }
    Conversation? cached;
    await for (final phase in source.getConversationTwoPhase(
      conversationWith: conversationWith,
      conversationType: conversationType,
    )) {
      switch (phase) {
        case Cached<Conversation>(:final rows):
          if (rows.isNotEmpty) cached = rows.first;
        case Server<Conversation>(:final rows):
          return (rows.isEmpty ? null : rows.first, false);
        case PhaseError<Conversation>(:final error):
          final c = cached;
          if (c != null && isNotConnectedError(error)) return (c, true);
          return (null, false);
      }
    }
    return (null, false);
  }

  /// Replaces the newest window with the page around [lastReadId] (the SDK's
  /// anchored read, BEH-READ-29), as today's unread open does. When neither
  /// side answers (offline, nothing cached there), the newest window stays.
  ///
  /// Returns the window token to carry on under: a fresh one when the jump
  /// window was shown (so pages of the newest window still in flight stop
  /// writing), [token] when nothing changed, and null when a newer window read
  /// (a refresh, a newest-window refresh) started meanwhile — its rows win.
  Future<int?> _jumpToUnread(
    MessageListSeamContext ctx,
    MessageListTwoPhaseDataSource reader,
    int lastReadId,
    int token,
    VoidCallback retry,
  ) async {
    final view = messageListReadsViewOf(ctx.owner);
    final (older, newer) = await _around(ctx, reader, lastReadId);
    if (!_live(ctx) || token != view._windowToken) return null;
    if (older.notConnected || newer.notConnected) view._offline(retry);
    if (older.rows == null && newer.rows == null) return token;
    final seen = <int>{};
    final window = <BaseMessage>[];
    for (final m in [...?older.rows, ...?newer.rows]) {
      // As today's unread open: action rows have no template in this view.
      if (m.category == MessageCategoryConstants.action) continue;
      if (m.id > 0 && !seen.add(m.id)) continue;
      window.add(m);
    }
    if (window.isEmpty) return token;
    final next = ++view._windowToken;
    // Rows without a server id (own unsent) stay (BEH-READ-30).
    final rows = [...window, ...ctx.state.messages.where((m) => m.id <= 0)]
      ..sort(compareMessageRows);
    _show(
      ctx,
      rows,
      hasMoreOlder: older.hasMore ?? true,
      // The gap up to the newest page loads on scroll, as today.
      hasMoreNewer: true,
    );
    _initCursors(ctx);
    return next;
  }

  /// The ON-path jump to a message: the page around [JumpToMessage.messageId]
  /// with the SDK's anchored reads, shown as today's jump shows it (a reset the
  /// widget then scrolls to the target). Unlike today's `[target, ...newer]`
  /// it keeps the rows without a server id (BEH-READ-30), and newer history is
  /// ended only by an empty online server page (BEH-READ-09b).
  Future<bool> _jumpToMessage(
    MessageListSeamContext ctx,
    MessageListTwoPhaseDataSource reader,
    JumpToMessage event,
  ) async {
    if (ctx.conversationWith == null) return true;
    final view = messageListReadsViewOf(ctx.owner);
    final token = ++view._windowToken;
    view._online();
    view.jumpToLatest.value = false;
    ctx.resolveLoggedInUser();
    final targetId = event.messageId;
    final (older, newer) = await _around(ctx, reader, targetId);
    if (!_live(ctx) || token != view._windowToken) return true;
    if (older.notConnected || newer.notConnected) {
      view._offline(() => ctx.add(event));
    }
    final seen = <int>{};
    final window = <BaseMessage>[];
    for (final m in [...?older.rows, ...?newer.rows]) {
      if (m.id > 0 && !seen.add(m.id)) continue;
      window.add(m);
    }
    if (!window.any((m) => m.id == targetId)) {
      // Opened at the message offline and the device does not have it (D60):
      // show the newest cached page instead of nothing, with no error.
      if (ctx.state.messages.isEmpty &&
          (older.notConnected || newer.notConnected)) {
        await _readWindow(
          ctx,
          reader.fetchPreviousTwoPhase(ctx.newMessagesRequestBuilder().build()),
          retry: () => ctx.add(event),
        );
      }
      // Otherwise neither the server nor the device has the target: the rows
      // stay, as today's jump leaves them when the target cannot be fetched.
      return true;
    }
    final rows = [...window, ...ctx.state.messages.where((m) => m.id <= 0)]
      ..sort(compareMessageRows);
    if (!_show(
      ctx,
      rows,
      hasMoreOlder: older.hasMore ?? true,
      hasMoreNewer: newer.hasMore ?? true,
      reset: true,
    )) {
      return true;
    }
    _initCursors(ctx);
    // As today: mark the newest row shown as read, once the server answered.
    if (older.hasMore != null || newer.hasMore != null) _markNewestRead(ctx);
    return true;
  }

  /// The SDK's anchored reads around message [id] (BEH-READ-29): the page up
  /// to and including it, and the page after it.
  Future<(_PageResult, _PageResult)> _around(
    MessageListSeamContext ctx,
    MessageListTwoPhaseDataSource reader,
    int id,
  ) async {
    // fetchPrevious returns rows before its id: +1 keeps row [id] itself.
    final older = (ctx.newMessagesRequestBuilder()..messageId = id + 1).build();
    final newer = (ctx.newMessagesRequestBuilder()..messageId = id).build();
    final results = await Future.wait([
      _finalPage(reader.fetchPreviousTwoPhase(older)),
      _finalPage(reader.fetchNextTwoPhase(newer)),
    ]);
    return (results[0], results[1]);
  }

  /// Reads one window (the newest page) in two phases and applies it
  /// (PR #23 §3.3).
  ///
  /// The server page merges into the rows shown only when it overlaps them
  /// (BEH-READ-07); otherwise the window starts again from the rows without a
  /// server id, so no gap is left between stale cached rows and the newest
  /// page. A plain window read over a non-newest window (a jump) always
  /// starts again. A [refreshNewest] read that does not overlap resets only
  /// when the list is pinned to the bottom, else offers "Jump to latest".
  ///
  /// The rows are always diffed in place (never today's append operation,
  /// whose scroll restore moves the viewport), so the widget can hold the
  /// first visible row where it is (PR #23 §3.3). A not-connected failure
  /// shows "Connect to load more"; its tap runs [retry]. A [serverOnly] read
  /// applies the server page alone: its cached page and its failure change
  /// nothing.
  Future<_WindowOutcome> _readWindow(
    MessageListSeamContext ctx,
    Stream<TwoPhaseResult<BaseMessage>> stream, {
    required VoidCallback retry,
    bool refreshNewest = false,
    bool serverOnly = false,
  }) async {
    final view = messageListReadsViewOf(ctx.owner);
    final token = ++view._windowToken;
    if (!serverOnly) view._online();
    ctx.resolveLoggedInUser();
    final dropped = _WindowOutcome(token, serverOk: false, applied: false);

    // A plain window read over a non-newest window (a jump) resets.
    var reset = !refreshNewest && ctx.state.hasMoreNewer;
    if (!refreshNewest) view.jumpToLatest.value = false;
    if (ctx.state.messages.isEmpty && !refreshNewest) {
      ctx.emit(ctx.state.copyWith(status: MessageListStatus.loading));
    }

    var serverOk = false;
    var applied = false;
    await for (final phase in stream) {
      if (!_live(ctx) || token != view._windowToken) return dropped;
      switch (phase) {
        case Cached<BaseMessage>(:final rows):
          // An empty cached page changes nothing: the server answers next.
          if (rows.isEmpty || serverOnly) break;
          // A refresh never resets on a cached page alone.
          if (refreshNewest && !_overlaps(ctx.state.messages, rows)) break;
          final current = _baseRows(ctx, reset);
          final r = reconcileCached(
            current: current,
            cached: rows,
            currentHasMore: ctx.state.hasMoreOlder,
            opGen: ctx.opGen,
            listGen: ctx.listGen,
            config: messageReconcileConfig(current, rows, _myUid(ctx)),
          );
          if (r.dropped) return dropped;
          if (_show(
            ctx,
            r.rows,
            hasMoreNewer: reset ? false : null,
            inPlace: true,
          )) {
            reset = false;
            applied = true;
          }
        case Server<BaseMessage>(:final rows):
          serverOk = true;
          if (serverOnly) view._online();
          if (rows.isNotEmpty &&
              ctx.state.messages.isNotEmpty &&
              !_overlaps(ctx.state.messages, rows)) {
            if (refreshNewest) {
              // Pinned = at the bottom of the newest window. After a jump
              // (more newer rows exist) the bottom of the list is not the
              // newest row, so a reset would lose the user's place.
              final pinned =
                  !ctx.state.hasMoreNewer && (view.isAtBottom?.call() ?? true);
              if (!pinned) {
                // Keep the user's place; a newer window is available.
                view.jumpToLatest.value = true;
                ctx.emit(ctx.state.copyWith(hasMoreNewer: true));
                return _WindowOutcome(token, serverOk: true, applied: true);
              }
            }
            // The newest page does not reach the rows shown (an open over
            // cached rows the device fell behind on): merging would leave a
            // gap between them that never loads (BEH-READ-07). Start the
            // window from the rows without a server id instead.
            reset = true;
          }
          final current = _baseRows(ctx, reset);
          final r = reconcileServer(
            current: current,
            server: rows,
            currentHasMore: ctx.state.hasMoreOlder,
            opGen: ctx.opGen,
            listGen: ctx.listGen,
            config: messageReconcileConfig(current, rows, _myUid(ctx)),
          );
          if (r.dropped) return dropped;
          // The newest page is now merged in: nothing newer to page.
          if (_show(
            ctx,
            r.rows,
            hasMoreOlder: r.hasMore,
            hasMoreNewer: false,
            isFinal: true,
            inPlace: true,
          )) {
            applied = true;
            view.jumpToLatest.value = false;
          }
          _initCursors(ctx);
          view.serverReads.value++;
        case PhaseError<BaseMessage>(:final error):
          if (serverOnly) break;
          // A background refresh never turns the list into an error state.
          if (!refreshNewest) _onWindowError(ctx, error);
          // Offline: "Connect to load more" with tap-to-retry (PR #23 §3.3).
          if (isNotConnectedError(error)) view._offline(retry);
          if (ctx.state.messages.isNotEmpty) {
            applied = true;
            _initCursors(ctx);
          }
      }
    }
    return _WindowOutcome(token, serverOk: serverOk, applied: applied);
  }

  List<BaseMessage> _baseRows(MessageListSeamContext ctx, bool reset) => reset
      ? ctx.state.messages.where((m) => m.id <= 0).toList()
      : ctx.state.messages;

  void _onWindowError(MessageListSeamContext ctx, CometChatException error) {
    final offline = isNotConnectedError(error);
    if (ctx.state.messages.isNotEmpty) {
      // Never blank rows already shown (BEH-READ-06). Offline, nothing more
      // (D84 (2)); a real error reaches onError (D84 (5): a window read is
      // an open or a jump, which the user or app started).
      ctx.emit(
        ctx.state.copyWithCleared(
          status: MessageListStatus.loaded,
          clearErrorMessage: offline,
          errorMessage: offline ? null : error.message,
        ),
      );
      if (!offline) OfflineListErrors.report(ctx.owner, error);
      return;
    }
    // Nothing shown. Offline, the error state is the offline state, "Connect
    // to load messages" with no Retry, and onError fires once (D84 (3)); the
    // caller raises "Connect to load more" as well, so the list reads the
    // newest page once on reconnect (D58) and that page replaces it. Any
    // other error is today's error state, with its retry (D84 (4)).
    messageListReadsViewOf(ctx.owner).showsOfflineState = offline;
    ctx.emit(
      ctx.state.copyWith(
        status: MessageListStatus.error,
        errorMessage: error.message ?? error.code,
      ),
    );
  }

  /// Reads one older or newer page in two phases (PR #23 §3.3).
  Future<bool> _loadPage(
    MessageListSeamContext ctx,
    MessageListTwoPhaseDataSource reader, {
    required bool older,
  }) async {
    final state = ctx.state;
    final view = messageListReadsViewOf(ctx.owner);
    if (older) {
      if (!state.hasMoreOlder || state.isLoadingOlder) return true;
    } else if (!state.hasMoreNewer || state.isLoadingNewer) {
      // As today: emit to unblock a listener waiting on the newer load.
      ctx.emit(state.copyWith(isLoadingNewer: false));
      return true;
    }
    if (ctx.conversationWith == null) return false;
    // Cursors anchor on the edge row WITH a server id (never an unsent row).
    final rows = state.messages;
    final edge = older ? _oldestWithServerId(rows) : _newestWithServerId(rows);
    if (!older && edge == null) {
      // fetchNext needs a cursor and no row has a server id to give one (the
      // SDK rejects the request): nothing to page. History is not ended.
      ctx.emit(state.copyWith(isLoadingNewer: false));
      return true;
    }
    final builder = ctx.newMessagesRequestBuilder();
    if (edge != null) builder.messageId = edge.id;
    final request = builder.build();
    if (older) {
      ctx.olderRequest = request;
    } else {
      ctx.newerRequest = request;
    }
    view._online();
    final token = view._windowToken;
    ctx.emit(
      older
          ? state.copyWith(isLoadingOlder: true)
          : state.copyWith(isLoadingNewer: true),
    );

    MessageListState loaded(MessageListState s, {String? error}) => older
        ? s.copyWith(isLoadingOlder: false, errorMessage: error)
        : s.copyWith(isLoadingNewer: false, errorMessage: error);

    final stream = older
        ? reader.fetchPreviousTwoPhase(request)
        : reader.fetchNextTwoPhase(request);
    var cachedRowsAdded = false;
    await for (final phase in stream) {
      if (!_live(ctx)) return true;
      if (token != view._windowToken) {
        // A window read replaced the rows: drop this page, drop its loader.
        ctx.emit(loaded(ctx.state));
        return true;
      }
      final current = ctx.state.messages;
      final currentHasMore = older
          ? ctx.state.hasMoreOlder
          : ctx.state.hasMoreNewer;
      switch (phase) {
        case Cached<BaseMessage>(:final rows):
          if (rows.isEmpty) break; // a cached page never ends history
          final r = reconcileCached(
            current: current,
            cached: rows,
            currentHasMore: currentHasMore,
            opGen: ctx.opGen,
            listGen: ctx.listGen,
            config: messageReconcileConfig(current, rows, _myUid(ctx)),
          );
          if (r.dropped) return true;
          if (r.rows.length > current.length) cachedRowsAdded = true;
          _show(ctx, r.rows);
        case Server<BaseMessage>(:final rows):
          final r = reconcileServer(
            current: current,
            server: rows,
            currentHasMore: currentHasMore,
            opGen: ctx.opGen,
            listGen: ctx.listGen,
            config: messageReconcileConfig(current, rows, _myUid(ctx)),
          );
          if (r.dropped) return true;
          final shown = _show(
            ctx,
            r.rows,
            hasMoreOlder: older ? r.hasMore : null,
            hasMoreNewer: older ? null : r.hasMore,
            isLoadingOlder: older ? false : null,
            isLoadingNewer: older ? null : false,
          );
          if (!shown) ctx.emit(loaded(ctx.state));
        case PhaseError<BaseMessage>(:final error):
          final offline = isNotConnectedError(error);
          // Offline past the cache: "Connect to load more" with tap-to-retry;
          // history is not ended (BEH-READ-09b, AC-4.3).
          if (offline) {
            view._offline(
              () => ctx.add(
                older ? const LoadOlderMessages() : const LoadNewerMessages(),
              ),
              page: true,
            );
            // Nothing more in the cache this way: scrolling to the top reads
            // nothing until the footer's tap or a reconnect.
            if (older && !cachedRowsAdded) view._olderPastCache = true;
          }
          ctx.emit(loaded(ctx.state, error: offline ? null : error.message));
      }
    }
    // A stream that closed without a terminal must not leave a loader up.
    if (_live(ctx) &&
        (older ? ctx.state.isLoadingOlder : ctx.state.isLoadingNewer)) {
      ctx.emit(loaded(ctx.state));
    }
    return true;
  }

  /// Shows [rows] as today's paths do: integrator hooks, index maps, thread
  /// reply counts, state and one row operation — today's paging operation by
  /// default, an in-place diff when [inPlace], a reset (as today's jump) when
  /// [reset]. Returns false when the integrator skipped the set.
  bool _show(
    MessageListSeamContext ctx,
    List<BaseMessage> rows, {
    bool? hasMoreOlder,
    bool? hasMoreNewer,
    bool? isLoadingOlder,
    bool? isLoadingNewer,
    bool isFinal = false,
    bool inPlace = false,
    bool reset = false,
  }) {
    final old = ctx.state.messages;
    final shown = ctx.onBeforeMessagesSet(
      collapseRepeatedOwnRows(rows, _myUid(ctx)),
    );
    if (shown == null) return false;
    ctx.markIndexMapsDirty();
    for (final m in shown) {
      if (m.id > 0 && m.replyCount > 0) {
        ctx.initializeThreadReplyCount(m.id, m.replyCount);
      }
    }
    final MessageListStatus status;
    if (shown.isNotEmpty) {
      status = MessageListStatus.loaded;
    } else if (isFinal) {
      status = MessageListStatus.empty;
    } else {
      status = ctx.state.status;
    }
    ctx.emit(
      ctx.state.copyWithCleared(
        status: status,
        // Rows or the empty state are shown: no stale error rides along.
        clearErrorMessage:
            status == MessageListStatus.loaded ||
            status == MessageListStatus.empty,
        messages: shown,
        hasMoreOlder: hasMoreOlder,
        hasMoreNewer: hasMoreNewer,
        isLoadingOlder: isLoadingOlder,
        isLoadingNewer: isLoadingNewer,
        loggedInUser: ctx.loggedInUser,
      ),
    );
    ctx.addOperation(
      reset
          ? MessageOperation.set(shown, animated: false)
          : inPlace
          ? MessageOperation.set(shown, oldMessages: old, animated: true)
          : messageRowsOperation(old, shown),
    );
    ctx.onAfterMessagesSet(shown);
    return true;
  }

  void _initCursors(MessageListSeamContext ctx) {
    final rows = ctx.state.messages;
    ctx.initializeCursors(
      oldestMessageId: _oldestWithServerId(rows)?.id,
      newestMessageId: _newestWithServerId(rows)?.id,
    );
  }

  Future<void> _placeUnreadAnchor(
    MessageListSeamContext ctx,
    String conversationWith,
    String conversationType,
  ) async {
    final result = await ctx.repository.getConversation(
      conversationWith: conversationWith,
      conversationType: conversationType,
    );
    if (!_live(ctx)) return;
    result.fold((_) {}, (conversation) {
      final lastReadId = conversation.lastReadMessageId ?? 0;
      final unreadCnt = conversation.unreadMessageCount;
      if (lastReadId <= 0 || unreadCnt <= 0) return;
      final anchor = _firstUnread(ctx, ctx.state.messages, lastReadId);
      if (anchor == null) return;
      ctx.emit(
        ctx.state.copyWith(
          unreadMessageAnchor: anchor,
          unreadMessageAnchorId: anchor.id,
          lastReadMessageId: lastReadId,
          unreadCount: unreadCnt,
          conversation: conversation,
        ),
      );
      ctx.notifyListChanged();
    });
  }

  BaseMessage? _firstUnread(
    MessageListSeamContext ctx,
    List<BaseMessage> rows,
    int lastReadId,
  ) {
    final me = _myUid(ctx);
    for (final m in rows) {
      if (m.id <= 0) continue;
      if (m.sender?.uid == me) continue;
      if (m.deletedAt != null) continue;
      if (m.parentMessageId > 0) continue;
      if (m.category == MessageCategoryConstants.action) continue;
      if (m.id > lastReadId) return m;
    }
    return null;
  }

  void _markNewestRead(MessageListSeamContext ctx) {
    if (ctx.disableReceipts || ctx.loggedInUser == null) return;
    final newest = _newestWithServerId(ctx.state.messages);
    if (newest != null) ctx.add(MarkMessageAsRead(newest));
  }

  /// Whether [page] (the newest page) overlaps the rows [shown]: a shared row,
  /// or the newest row shown reaching into the page's range.
  bool _overlaps(List<BaseMessage> shown, List<BaseMessage> page) {
    if (shown.isEmpty) return true;
    if (page.isEmpty) return false;
    final ids = <int>{
      for (final m in shown)
        if (m.id > 0) m.id,
    };
    for (final m in page) {
      if (m.id > 0 && ids.contains(m.id)) return true;
    }
    final newest = _newestWithServerId(shown);
    final pageOldest = _oldestWithServerId([...page]..sort(compareMessageRows));
    if (newest == null || pageOldest == null) return false;
    return compareMessageRows(newest, pageOldest) >= 0;
  }

  String? _myUid(MessageListSeamContext ctx) =>
      ctx.loggedInUser?.uid ?? ctx.resolveLoggedInUser()?.uid;

  bool _live(MessageListSeamContext ctx) => !ctx.isClosed && !ctx.isStale;
}

/// One row operation from [old] to [now]: a prepend or append when the rows
/// shown stay in place (today's paging operations), else an in-place diff —
/// never a reset of the list over rows already shown.
@visibleForTesting
MessageOperation messageRowsOperation(
  List<BaseMessage> old,
  List<BaseMessage> now,
) {
  if (old.isNotEmpty && now.length > old.length) {
    final added = now.length - old.length;
    if (_sameRows(old, now, offset: added)) {
      return MessageOperation.insertAll(
        now.sublist(0, added),
        0,
        animated: false,
      );
    }
    if (_sameRows(old, now, offset: 0)) {
      return MessageOperation.insertAll(
        now.sublist(old.length),
        old.length,
        animated: false,
      );
    }
  }
  return MessageOperation.set(now, oldMessages: old, animated: true);
}

bool _sameRows(
  List<BaseMessage> old,
  List<BaseMessage> now, {
  required int offset,
}) {
  for (var i = 0; i < old.length; i++) {
    if (!identical(old[i], now[i + offset])) return false;
  }
  return true;
}

/// The outcome of one window read.
class _WindowOutcome {
  const _WindowOutcome(
    this.token, {
    required this.serverOk,
    required this.applied,
  });

  /// The window token the read ran under.
  final int token;

  /// The server phase answered.
  final bool serverOk;

  /// Rows were shown (the read was not dropped as stale or superseded).
  final bool applied;
}

/// The last phase of one side of an anchored jump: the server rows, else
/// (offline) the cached rows; `rows == null` when neither answered.
class _PageResult {
  const _PageResult(this.rows, this.hasMore, {this.notConnected = false});
  final List<BaseMessage>? rows;

  /// Set only by an online server page: whether it was non-empty.
  final bool? hasMore;

  /// The server side failed because the device is not connected.
  final bool notConnected;
}

Future<_PageResult> _finalPage(Stream<TwoPhaseResult<BaseMessage>> s) async {
  List<BaseMessage>? cached;
  await for (final phase in s) {
    switch (phase) {
      case Cached<BaseMessage>(:final rows):
        cached = rows;
      case Server<BaseMessage>(:final rows):
        return _PageResult(rows, rows.isNotEmpty);
      case PhaseError<BaseMessage>(:final error):
        return _PageResult(
          cached == null || cached.isEmpty ? null : cached,
          null,
          notConnected: isNotConnectedError(error),
        );
    }
  }
  return _PageResult(cached == null || cached.isEmpty ? null : cached, null);
}
