import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart';

import '../../../chat_ui/src/conversations/bloc/conversations_event.dart';
import '../../../chat_ui/src/conversations/bloc/conversations_state.dart';
import '../../../chat_ui/src/conversations/utils/conversation_tier_ordering.dart';
import '../cometchat_ui_kit/cometchat_ui_kit.dart' show CometChatUIKit;
import 'contract_ids.dart';
import 'conversations_seam_context.dart';
import 'message_list_offline_reads.dart' show isNotConnectedError;
import 'message_send_state.dart';
import 'offline_hub_event.dart';
import 'offline_list_errors.dart';
import 'offline_list_reconcile.dart';
import 'two_phase.dart';

/// "Connect to load chats" (D84 (3)): with offline on, a first read found
/// nothing cached and the device is offline. An offline state with no Retry
/// (the app's error view shows instead if it passed one); `onError` fires
/// once with [error]; the reconnect sync page fills the list, once.
class ConversationsConnectToLoad extends ConversationsState {
  /// Creates the state.
  const ConversationsConnectToLoad(this.error);

  /// The not-connected error the read failed with.
  final CometChatException error;

  @override
  List<Object?> get props => [error];
}

/// W3's seam: conversation-list two-phase read, sync-slice reconcile,
/// pending/failed preview, conversation pin, swept self-removal (W1 §2.9,
/// PR #23 §3.7).
///
/// Hooks run only when offline is on. Hooks inside an async handler get a
/// [ConversationsSeamContext] and return `null` (fall through, no async gap)
/// or a future of `true` (handled) / `false` (fall through). Hooks outside an
/// async handler get the [ConversationsSeamHost] and return a bool; use
/// [ConversationsSeamHost.run] for work that emits.
///
/// The SDK owns the data; the list only reconciles what it is handed. Rows
/// are keyed by `conversationId` and kept in today's order ([compareRows]).
class ConversationsOffline {
  ConversationsOffline._();

  /// The single instance.
  static final ConversationsOffline instance = ConversationsOffline._();

  /// `localMessageId`s the SDK reported as removed before sending (discarded
  /// or evicted) this session. Such a preview is no longer "own unsent", so a
  /// sync page may drop its row; the SDK's row replaces it on the next read
  /// or sync either way.
  final Set<String> _removedUnsent = <String>{};

  /// Paging requests whose last load-more found nothing cached and failed on
  /// the server. Further load-mores on them wait for the next sync page, so
  /// an offline list's footer does not re-request on every rebuild. A request
  /// parked [_Parked.offline] is the marked page the next sync reads (D75).
  final Expando<_Parked> _loadMoreParked = Expando('loadMoreParked');

  /// Paging requests whose marked page the reconnect is reading (D75). A
  /// load-more or a second sync on them starts no read meanwhile.
  final Expando<bool> _reconnectReading = Expando('reconnectReading');

  /// The most pages one reconnect reads for a marked page, the marked page
  /// included (D75).
  static const int reconnectPageCap = 10;

  /// Paging requests whose first page is in flight (ENG-41552 G). The SDK
  /// answers a second read on a request that is busy with an empty server
  /// page, so a load-more asked meanwhile waits ([_loadMoreDeferred]) and
  /// runs once that page is in, instead of being lost.
  final Expando<bool> _firstPageReading = Expando('firstPageReading');

  /// Paging requests with a load-more waiting for their first page.
  final Expando<bool> _loadMoreDeferred = Expando('loadMoreDeferred');

  // ---------------------------------------------------------------------------
  // Reads (G2): two-phase, windowed reconcile.
  // ---------------------------------------------------------------------------

  /// Hook: `_onLoadConversations` (also the silent reload).
  Future<bool>? handleLoad(
    ConversationsSeamContext ctx,
    LoadConversations event,
  ) {
    final source = conversationsTwoPhaseFor(ctx.remoteDataSource);
    if (source == null) return null; // a custom datasource: today's path
    return _load(ctx, source, silent: event.silent);
  }

  /// Hook: `_onLoadMoreConversations`.
  Future<bool>? handleLoadMore(
    ConversationsSeamContext ctx,
    LoadMoreConversations event,
  ) {
    final source = conversationsTwoPhaseFor(ctx.remoteDataSource);
    final request = ctx.conversationsRequest;
    if (source == null || request == null) return null;
    return _loadMore(ctx, source, request);
  }

  /// Hook: `_onRefreshConversations`. A loaded list makes no fetch: it asks
  /// the SDK for a catch-up sync, whose conversation page the list then
  /// reconciles (PR #23 §3.7). A list with nothing loaded reads again.
  Future<bool>? handleRefresh(
    ConversationsSeamContext ctx,
    RefreshConversations event,
  ) {
    final source = conversationsTwoPhaseFor(ctx.remoteDataSource);
    if (source == null) return null;
    if (ctx.state is! ConversationsLoaded) {
      return _load(ctx, source, silent: false);
    }
    _forceSync(ctx);
    return Future.value(true);
  }

  /// Hook: `_onConnectionStateUpdate`. Returns `true` to suppress today's
  /// kit-side refetch: with offline on the list consumes the SDK sweep
  /// ([ConversationSyncCompleted]) and fetches nothing itself (G7).
  bool handleReconnect(ConversationsSeamHost host) => true;

  /// Hook: the conversation update a received message drives
  /// (`_onMessageReceivedUpdate`). A message the reconnect sweep delivers
  /// ([isSwept]) adds no unread +1 (its count is already in the synced
  /// conversation) and is placed by time, never floated above newer rows.
  /// Live messages keep today's path.
  bool handleMessageReceived(
    ConversationsSeamHost host,
    Conversation conversation,
  ) {
    final message = conversation.lastMessage;
    if (message == null || !isSwept(message)) return false;
    host.run((ctx) => _applySwept(ctx, conversation));
    return true;
  }

  /// Whether [message] was delivered by the reconnect sweep.
  static bool isSwept(BaseMessage message) => message.source == 'SYNC';

  /// Hub collector, called inside the bloc's event loop for every current-gen
  /// hub event.
  Future<void> onHubEvent(
    ConversationsSeamContext ctx,
    OfflineHubEvent event,
  ) async {
    switch (event) {
      case ConversationSyncCompleted(:final conversations):
        await _onConversationSync(ctx, conversations);
      case SendStateEvent():
        _onSendState(ctx, event);
      case MessageSyncCompleted(:final messages):
        _onSweptGroupActions(ctx, messages);
      case SessionEnded():
        _removedUnsent.clear();
      case CacheReset():
        await _onCacheReset(ctx);
      case ConversationSyncFailed():
      case MessageSyncFailed():
      case MessagesUpdated():
      case MediaReady():
        // Nothing for the conversation list (the next sweep heals).
        break;
    }
  }

  /// Cache reset (G8): the bloc has cleared the list and its request, so page
  /// one is read again, once. The kit started it, so a real error over the
  /// cached rows it shows does not reach `onError` (D84 (5)). The hub posts
  /// the reset notice and `ccOfflineCacheReset`; the list posts nothing.
  Future<void> _onCacheReset(ConversationsSeamContext ctx) async {
    final source = conversationsTwoPhaseFor(ctx.remoteDataSource);
    if (source == null) {
      // A custom datasource: today's load.
      ctx.add(const LoadConversations());
      return;
    }
    await _load(ctx, source, silent: false, quiet: true);
  }

  Future<bool> _load(
    ConversationsSeamContext ctx,
    ConversationsTwoPhaseDataSource source, {
    required bool silent,
    bool quiet = false,
  }) async {
    if (!silent && ctx.state is! ConversationsLoaded) {
      ctx.emit(const ConversationsLoading());
    }
    final request = _buildRequest(ctx);
    ctx.conversationsRequest = request;
    _firstPageReading[request] = true;
    try {
      return await _readFirstPage(
        ctx,
        source,
        request,
        silent: silent,
        quiet: quiet,
      );
    } finally {
      _firstPageReading[request] = null;
      if (_loadMoreDeferred[request] == true) {
        _loadMoreDeferred[request] = null;
        // Runs through today's checks (loaded, more to read, not parked).
        if (!ctx.isStale &&
            !ctx.isClosed &&
            identical(ctx.conversationsRequest, request)) {
          ctx.add(const LoadMoreConversations());
        }
      }
    }
  }

  Future<bool> _readFirstPage(
    ConversationsSeamContext ctx,
    ConversationsTwoPhaseDataSource source,
    ConversationsRequest request, {
    required bool silent,
    bool quiet = false,
  }) async {
    await for (final phase in source.fetchNextTwoPhase(request)) {
      if (ctx.isStale || ctx.isClosed) return true;
      switch (phase) {
        case Cached(:final rows):
          // A cached page, even empty, never ends history or blanks the list.
          if (rows.isEmpty) continue;
          final r = reconcileCached(
            current: ctx.rows,
            cached: rows,
            currentHasMore: true,
            opGen: ctx.opGen,
            listGen: ctx.listGen,
            config: _config(ctx),
          );
          if (r.dropped) return true;
          _show(ctx, r.rows, hasMore: true);
        case Server(:final rows):
          final r = reconcileServer(
            current: ctx.rows,
            server: rows,
            currentHasMore: true,
            opGen: ctx.opGen,
            listGen: ctx.listGen,
            config: _config(ctx),
          );
          if (r.dropped) return true;
          if (r.rows.isEmpty) {
            if (ctx.rows.isNotEmpty) ctx.replaceRows(const []);
            ctx.emit(const ConversationsEmpty());
          } else {
            _show(ctx, r.rows, hasMore: r.hasMore);
          }
        case PhaseError(:final error):
          final offline = isNotConnectedError(error);
          if (ctx.rows.isNotEmpty) {
            // Rows already shown are never blanked (BEH-READ-06). Offline,
            // nothing more (D84 (2)); a real error reaches onError when the
            // user or app started the read (D84 (5)).
            final s = ctx.state;
            _show(
              ctx,
              ctx.rows,
              hasMore: s is ConversationsLoaded ? s.hasMore : true,
            );
            if (!silent && !offline && !quiet) {
              OfflineListErrors.report(ctx.owner, error);
            }
          } else if (!silent && offline) {
            // Nothing shown, offline: the offline state (D84 (3)); the
            // reconnect sync page replaces it, once (_onConversationSync).
            ctx.emit(ConversationsConnectToLoad(error));
          } else if (!silent) {
            // Nothing shown: the error view, as today (D84 (4)).
            ctx.emit(
              ConversationsError(
                message: error.message ?? 'Failed to load conversations',
              ),
            );
          }
      }
    }
    return true;
  }

  Future<bool> _loadMore(
    ConversationsSeamContext ctx,
    ConversationsTwoPhaseDataSource source,
    ConversationsRequest request,
  ) async {
    if (_firstPageReading[request] == true) {
      _loadMoreDeferred[request] = true;
      return true;
    }
    final s = ctx.state;
    if (s is! ConversationsLoaded ||
        !s.hasMore ||
        s.isLoadingMore ||
        _loadMoreParked[request] != null ||
        _reconnectReading[request] == true) {
      return true;
    }
    ctx.emit(s.copyWith(isLoadingMore: true));
    await _readNextPage(ctx, source, request);
    return true;
  }

  /// Reads [request]'s next page two-phase into the list (load-more and the
  /// reconnect read). Returns the server page, or `null` when the read
  /// stopped (stale, closed, dropped) or failed. A failure past the cache
  /// parks [request]; a not-connected one marks it for the next sync (D75).
  Future<_PageRead?> _readNextPage(
    ConversationsSeamContext ctx,
    ConversationsTwoPhaseDataSource source,
    ConversationsRequest request,
  ) async {
    var cachedRows = 0;
    _PageRead? read;
    await for (final phase in source.fetchNextTwoPhase(request)) {
      if (ctx.isStale || ctx.isClosed) return null;
      switch (phase) {
        case Cached(:final rows):
          cachedRows += rows.length;
          if (rows.isEmpty) continue;
          final r = reconcileCached(
            current: ctx.rows,
            cached: rows,
            currentHasMore: true,
            opGen: ctx.opGen,
            listGen: ctx.listGen,
            config: _config(ctx),
          );
          if (r.dropped) return null;
          _show(ctx, r.rows, hasMore: true, isLoadingMore: true);
        case Server(:final rows):
          final r = reconcileServer(
            current: ctx.rows,
            server: rows,
            currentHasMore: true,
            opGen: ctx.opGen,
            listGen: ctx.listGen,
            config: _config(ctx),
          );
          if (r.dropped) return null;
          _show(ctx, r.rows, hasMore: r.hasMore);
          read = _PageRead(rows, hasMore: r.hasMore);
        case PhaseError(:final error):
          // Keep every row shown; an error never ends history. Past the
          // cache, wait for the next sync page before paging again; offline,
          // that sync reads this page once (D75).
          if (cachedRows == 0) {
            _loadMoreParked[request] = isNotConnectedError(error)
                ? _Parked.offline
                : _Parked.failed;
          }
          _show(ctx, ctx.rows, hasMore: true);
      }
    }
    return read;
  }

  /// D75: reads [request]'s marked page once on reconnect, without a scroll.
  /// While that page brings no chat not already shown it reads the next one;
  /// it stops at the first new chat, at the end of the list, after
  /// [reconnectPageCap] pages, on a failure (a not-connected one marks the
  /// page again for the next reconnect), or once the list is reloaded,
  /// disposed or its session ends.
  Future<void> _readMarkedPage(
    ConversationsSeamContext ctx,
    ConversationsTwoPhaseDataSource source,
    ConversationsRequest request,
  ) async {
    if (_reconnectReading[request] == true) return;
    _reconnectReading[request] = true;
    try {
      for (var page = 0; page < reconnectPageCap; page++) {
        if (ctx.isStale ||
            ctx.isClosed ||
            !identical(ctx.conversationsRequest, request)) {
          return;
        }
        final s = ctx.state;
        if (s is! ConversationsLoaded || !s.hasMore) return;
        final shown = {for (final c in ctx.rows) c.conversationId};
        ctx.emit(s.copyWith(isLoadingMore: true));
        final read = await _readNextPage(ctx, source, request);
        if (read == null || !read.hasMore) return;
        if (read.rows.any((c) => !shown.contains(c.conversationId))) return;
      }
    } finally {
      _reconnectReading[request] = null;
    }
  }

  /// Today's request shape (the remote datasource copies the same fields),
  /// paged by the list's page size.
  ConversationsRequest _buildRequest(ConversationsSeamContext ctx) {
    final builder = ConversationsRequestBuilder();
    final source = ctx.requestBuilder;
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
    builder.limit = ctx.pageSize;
    return builder.build();
  }

  void _show(
    ConversationsSeamContext ctx,
    List<Conversation> rows, {
    required bool hasMore,
    bool isLoadingMore = false,
  }) {
    final shown = List<Conversation>.of(rows);
    ctx.replaceRows(shown);
    final s = ctx.state;
    ctx.emit(
      s is ConversationsLoaded
          ? s.copyWith(
              conversations: shown,
              hasMore: hasMore,
              isLoadingMore: isLoadingMore,
            )
          : ConversationsLoaded(
              conversations: shown,
              hasMore: hasMore,
              isLoadingMore: isLoadingMore,
            ),
    );
  }

  void _forceSync(ConversationsSeamContext ctx) {
    try {
      unawaited(
        CometChat.forceSyncNow(
          callback: _ForceSync(
            onError: (e) {
              // Offline not running after all: today's refresh. In progress
              // or cooldown: the running or deferred sweep delivers the page.
              if (e.code == OfflineSyncError.disabled) {
                ctx.add(const LoadConversations(silent: true));
              }
            },
          ),
        ).catchError((Object _) {}),
      );
    } catch (_) {
      // A refresh never surfaces a sync request failure.
    }
  }

  // ---------------------------------------------------------------------------
  // Reconnect (G7): reconcile the slice the sync page covers.
  // ---------------------------------------------------------------------------

  Future<void> _onConversationSync(
    ConversationsSeamContext ctx,
    List<Conversation> page,
  ) async {
    final s = ctx.state;
    // A first read in flight delivers its own server page.
    if (s is ConversationsInitial || s is ConversationsLoading) return;
    // Back online: paging may resume, and a page marked offline is read once
    // below (D75). A reconnect read in flight owns its request's mark, and a
    // sync page this list does not apply leaves the mark for the next one.
    final cursor = ctx.conversationsRequest;
    final marked = cursor != null && _loadMoreParked[cursor] == _Parked.offline;
    final reading = cursor != null && _reconnectReading[cursor] == true;
    void resumePaging() {
      if (cursor != null && !reading) _loadMoreParked[cursor] = null;
    }

    if (isFiltered(ctx.requestBuilder)) {
      // A filtered list cannot reconcile against the plain sync page: it
      // re-runs its own request two-phase, once (PR #23 §3.7). That read
      // replaces the request, so its marked page goes with it.
      resumePaging();
      final source = conversationsTwoPhaseFor(ctx.remoteDataSource);
      if (source != null) {
        await _load(ctx, source, silent: true);
      } else {
        ctx.add(const LoadConversations(silent: true));
      }
      return;
    }
    final r = reconcileServer(
      current: ctx.rows,
      server: page,
      currentHasMore: true,
      opGen: ctx.opGen,
      listGen: ctx.listGen,
      config: _config(ctx),
    );
    if (r.dropped) return;
    if (r.rows.isEmpty) {
      if (ctx.rows.isNotEmpty) ctx.replaceRows(const []);
      ctx.emit(const ConversationsEmpty());
      return;
    }
    resumePaging();
    // Not a pagination page: the request cursor and hasMore stay as they are.
    // A reconnect read still loading its page keeps the footer spinner.
    _show(
      ctx,
      r.rows,
      hasMore: s is ConversationsLoaded && s.hasMore,
      isLoadingMore: reading && s is ConversationsLoaded && s.isLoadingMore,
    );
    if (!marked) return; // nothing marked: no list fetch (G7)
    final source = conversationsTwoPhaseFor(ctx.remoteDataSource);
    if (source != null) await _readMarkedPage(ctx, source, cursor);
  }

  /// Whether [builder] narrows the list (type, tags, unread, pinned-by,
  /// keyword, blocked users), so the plain sync page does not describe it.
  static bool isFiltered(ConversationsRequestBuilder? builder) {
    if (builder == null) return false;
    bool has(List<String>? l) => l != null && l.isNotEmpty;
    bool hasText(String? t) => t != null && t.isNotEmpty;
    return hasText(builder.conversationType) ||
        has(builder.tags) ||
        has(builder.userTags) ||
        has(builder.groupTags) ||
        builder.unread == true ||
        builder.includeBlockedUsers == true ||
        hasText(builder.pinnedBy) ||
        hasText(builder.searchKeyword);
  }

  // ---------------------------------------------------------------------------
  // Pending / failed preview (G3, BEH-CONV-01, BEH-SEND-30).
  // ---------------------------------------------------------------------------

  void _onSendState(ConversationsSeamContext ctx, SendStateEvent event) {
    final reason = event.reason;
    if (reason == MessageFailureReason.discarded ||
        reason == MessageFailureReason.queueOverflow) {
      // Gone from the outbox: the SDK's row replaces it on the next read or
      // sync.
      if (event.localMessageId.isNotEmpty) {
        _removedUnsent.add(event.localMessageId);
      }
      return;
    }
    final s = ctx.state;
    // A list showing "Connect to load chats" holds no row either, like an
    // empty one: an own send still adds its pending preview.
    if (s is! ConversationsLoaded &&
        s is! ConversationsEmpty &&
        s is! ConversationsConnectToLoad) {
      return;
    }
    final message = event.message;
    final cid = message.conversationId;
    if (cid == null || cid.isEmpty) return;
    final rows = List<Conversation>.of(ctx.rows);
    final index = rows.indexWhere((c) => c.conversationId == cid);

    if (event.state == CometChatMessageSendState.sent) {
      // The ack: refresh the preview in place when it shows this message.
      if (index < 0) return;
      final row = rows[index];
      final preview = row.lastMessage;
      if (preview == null || !_sameMessage(preview, message)) return;
      rows[index] = row.copyWith(lastMessage: message);
      ctx.replaceRows(rows);
      return;
    }

    Conversation updated;
    if (index >= 0) {
      final row = rows[index];
      final preview = row.lastMessage;
      if (preview != null &&
          !_sameMessage(preview, message) &&
          _ms(preview.sentAt) > _ms(message.sentAt)) {
        return; // never replace a newer preview with an older one
      }
      updated = row.copyWith(lastMessage: message);
      rows.removeAt(index);
    } else {
      // Create-if-absent (BEH-CONV-01), only where the plain list shows it.
      final peer = message.receiver;
      if (isFiltered(ctx.requestBuilder) || peer == null) return;
      updated = Conversation(
        conversationId: cid,
        conversationType: message.receiverType,
        conversationWith: peer,
        lastMessage: message,
      );
    }
    // To the top of its own tier (a pinned row stays on the shelf).
    rows.insert(
      ConversationTierOrdering.tierTopIndex(
        ConversationTierOrdering.tierOf(updated),
        rows,
      ),
      updated,
    );
    ctx.replaceRows(rows);
  }

  /// The send state a conversation preview renders with offline on: `null`
  /// unless the preview is the logged-in user's own unsent message (then the
  /// row keeps today's receipt). Derived from `status` on every build
  /// (BEH-SEND-30).
  static CometChatMessageSendState? previewSendState(
    Conversation conversation,
  ) {
    final message = conversation.lastMessage;
    if (message == null) return null;
    final me = CometChatUIKit.loggedInUser?.uid;
    if (me == null || message.sender?.uid != me) return null;
    final state = sendStateOf(message);
    return state == CometChatMessageSendState.sent ? null : state;
  }

  // ---------------------------------------------------------------------------
  // Swept messages and swept self-removal (G7, B2).
  // ---------------------------------------------------------------------------

  void _applySwept(ConversationsSeamContext ctx, Conversation incoming) {
    if (ctx.state is! ConversationsLoaded) return;
    final message = incoming.lastMessage;
    if (message == null) return;
    final rows = List<Conversation>.of(ctx.rows);
    final index = rows.indexWhere(
      (c) => c.conversationId == incoming.conversationId,
    );
    Conversation updated;
    if (index >= 0) {
      final row = rows[index];
      final preview = row.lastMessage;
      final newer =
          preview == null ||
          _sameMessage(preview, message) ||
          _ms(message.sentAt) >= _ms(preview.sentAt);
      if (!newer) return;
      // Unread stays the synced row's: no +1 for a swept message.
      updated = row.copyWith(lastMessage: message);
      rows.removeAt(index);
    } else {
      updated = incoming;
    }
    var at = 0;
    while (at < rows.length && compareRows(rows[at], updated) <= 0) {
      at++;
    }
    rows.insert(at, updated);
    ctx.replaceRows(rows);
  }

  void _onSweptGroupActions(
    ConversationsSeamContext ctx,
    List<BaseMessage> messages,
  ) {
    if (ctx.state is! ConversationsLoaded) return;
    final me = _myUid(ctx);
    if (me == null) return;
    // In sweep order: a later re-join cancels an earlier removal.
    final removed = <String>{};
    for (final m in messages) {
      if (m is! Action) continue;
      final on = m.actionOn;
      if (on is! User || on.uid != me) continue;
      final group = m.actionFor;
      final guid = group is Group ? group.guid : m.receiverUid;
      switch (m.action) {
        case 'kicked':
        case 'banned':
        case 'left':
          removed.add(guid);
        case 'joined':
        case 'added':
          removed.remove(guid);
      }
    }
    if (removed.isEmpty) return;
    final rows = ctx.rows;
    final kept = rows.where((c) {
      final w = c.conversationWith;
      return !(c.conversationType == 'group' &&
          w is Group &&
          removed.contains(w.guid));
    }).toList();
    // Exactly as the live self kick/ban/leave: the group row is dropped.
    if (kept.length != rows.length) ctx.replaceRows(kept);
  }

  // ---------------------------------------------------------------------------
  // Conversation pin (G11, BEH-CPIN-09).
  // ---------------------------------------------------------------------------

  /// Hook: `_onConversationPinUpdate` (a pin event from the SDK listener).
  /// Matches the row by (type, with); an event that already matches the
  /// row's pin state is a no-op. Returns `true` when handled.
  bool handlePinUpdate(
    ConversationsSeamContext ctx,
    Conversation incoming, {
    required bool pinned,
  }) {
    if (ctx.state is! ConversationsLoaded) return false;
    final peer = _withId(incoming);
    if (peer == null) return false;
    // A 1:1 event whose peer is the logged-in user is ignored.
    final me = _myUid(ctx);
    if (incoming.conversationType == 'user' &&
        me != null &&
        _asciiEquals(peer, me)) {
      return true;
    }
    final index = _indexByWith(ctx.rows, incoming.conversationType, peer);
    if (index < 0) return false; // not shown: today's path
    if (_pinStateMatches(ctx.rows[index], incoming, pinned: pinned)) {
      return true;
    }
    _applyPin(ctx, index, incoming, pinned: pinned);
    return true;
  }

  /// Applies the logged-in user's own pin/unpin from its `onSuccess` (G11):
  /// correct whether or not the SDK also fires the listener, because a
  /// listener event that already applied it makes this a no-op.
  void applyOwnPin(Object bloc, Conversation updated, {required bool pinned}) {
    final host = conversationsSeamHostOf(bloc);
    if (host == null) return;
    host.run((ctx) {
      if (ctx.state is! ConversationsLoaded) return;
      final peer = _withId(updated);
      if (peer == null) return;
      final index = _indexByWith(ctx.rows, updated.conversationType, peer);
      if (index < 0) return;
      if (_pinStateMatches(ctx.rows[index], updated, pinned: pinned)) return;
      _applyPin(ctx, index, updated, pinned: pinned);
    });
  }

  bool _pinStateMatches(
    Conversation row,
    Conversation incoming, {
    required bool pinned,
  }) {
    if (!pinned) return row.pinnedAt == null;
    return row.pinnedAt != null &&
        row.pinnedBy == incoming.pinnedBy &&
        (incoming.pinnedAt == null ||
            _ms(row.pinnedAt) == _ms(incoming.pinnedAt));
  }

  /// Today's placement (`_onConversationPinUpdate`): pin → top of its tier;
  /// unpin → its activity slot in the unpinned region, dropped when that slot
  /// is past the loaded window and more pages exist.
  void _applyPin(
    ConversationsSeamContext ctx,
    int index,
    Conversation incoming, {
    required bool pinned,
  }) {
    final rows = List<Conversation>.of(ctx.rows);
    final row = rows.removeAt(index).copyWith();
    if (pinned) {
      row.pinnedAt = incoming.pinnedAt ?? DateTime.now();
      row.pinnedBy = incoming.pinnedBy;
      rows.insert(
        ConversationTierOrdering.tierTopIndex(
          ConversationTierOrdering.tierOf(row),
          rows,
        ),
        row,
      );
      ctx.replaceRows(rows);
      return;
    }
    row.pinnedAt = null;
    row.pinnedBy = null;
    final updatedAt = row.updatedAt;
    var at = ConversationTierOrdering.tierTopIndex(
      ConversationTierOrdering.normalTier,
      rows,
    );
    var found = updatedAt == null;
    while (updatedAt != null && at < rows.length) {
      final other = rows[at].updatedAt;
      if (other == null || other.isBefore(updatedAt)) {
        found = true;
        break;
      }
      at++;
    }
    final s = ctx.state;
    if (at >= rows.length && !found && s is ConversationsLoaded && s.hasMore) {
      ctx.replaceRows(rows); // pagination restores it in place
      return;
    }
    rows.insert(at.clamp(0, rows.length), row);
    ctx.replaceRows(rows);
  }

  // ---------------------------------------------------------------------------
  // State-contract identifier (PR #23 TEST-PLAN §3.3).
  // ---------------------------------------------------------------------------

  /// The `cc-conversation-row` identifier carrying `with`, `previewState`,
  /// `unread`, `pinned` and `index`. Never message text.
  static String conversationRowId(Conversation conversation, int index) {
    try {
      final previewState = switch (previewSendState(conversation)) {
        CometChatMessageSendState.sending => 'sending',
        CometChatMessageSendState.failed => 'failed',
        _ => conversation.lastMessage == null ? 'none' : 'sent',
      };
      final pinned = conversation.pinnedAt != null;
      return '${ContractIds.conversationRow}'
          '|with=${_withId(conversation) ?? ''}'
          '|previewState=$previewState'
          '|unread=${conversation.unreadMessageCount}'
          '|pinned=$pinned'
          '|index=$index';
    } catch (_) {
      // A partial Conversation/BaseMessage implementation (an integrator's
      // subclass or a test double) never breaks the row over an identifier.
      return '${ContractIds.conversationRow}|index=$index';
    }
  }

  // ---------------------------------------------------------------------------
  // Reconcile configuration.
  // ---------------------------------------------------------------------------

  ReconcileConfig<Conversation> _config(ConversationsSeamContext ctx) {
    final me = _myUid(ctx);
    return ReconcileConfig<Conversation>(
      rowKey: _key,
      hasServerId: (_) => true,
      // The SDK's row always replaces an own-unsent preview: it already
      // carries the unsent message (BEH-CONV-01/06), and after a discard it is
      // the reverted row.
      updatedAt: (c) =>
          _ownUnsentPreview(c, me, countRemoved: true) ? -1 : _activity(c),
      compare: compareRows,
      keep: (c) => _ownUnsentPreview(c, me),
    );
  }

  /// Today's order: system pins, own pins (newest pin first), then the rest
  /// by last activity, newest first.
  static int compareRows(Conversation a, Conversation b) {
    final ta = ConversationTierOrdering.tierOf(a);
    final tb = ConversationTierOrdering.tierOf(b);
    if (ta != tb) return ta.compareTo(tb);
    if (ta != ConversationTierOrdering.normalTier) {
      final byPin = _ms(b.pinnedAt).compareTo(_ms(a.pinnedAt));
      if (byPin != 0) return byPin;
    }
    final byActivity = _activity(b).compareTo(_activity(a));
    if (byActivity != 0) return byActivity;
    return _key(a).compareTo(_key(b));
  }

  /// Whether the row's preview is the logged-in user's own message that has
  /// not been sent (BEH-CONV-06): a sync page never removes such a row. One
  /// the SDK removed (discarded, evicted) counts only with [countRemoved].
  bool _ownUnsentPreview(
    Conversation c,
    String? me, {
    bool countRemoved = false,
  }) {
    final m = c.lastMessage;
    if (m == null || me == null || m.sender?.uid != me) return false;
    final lid = m.localMessageId;
    if (!countRemoved && lid != null && _removedUnsent.contains(lid)) {
      return false;
    }
    return m.id <= 0 || sendStateOf(m) != CometChatMessageSendState.sent;
  }

  static int _activity(Conversation c) {
    final updatedAt = _ms(c.updatedAt);
    final sentAt = _ms(c.lastMessage?.sentAt);
    return sentAt > updatedAt ? sentAt : updatedAt;
  }

  static String _key(Conversation c) =>
      c.conversationId ?? '${c.conversationType}_${_withId(c) ?? ''}';

  static int _ms(DateTime? t) => t?.millisecondsSinceEpoch ?? 0;

  static String? _withId(Conversation c) {
    final w = c.conversationWith;
    if (w is User) return w.uid;
    if (w is Group) return w.guid;
    return null;
  }

  static int _indexByWith(List<Conversation> rows, String type, String peer) {
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.conversationType != type) continue;
      final id = _withId(row);
      if (id != null && _asciiEquals(id, peer)) return i;
    }
    return -1;
  }

  /// ASCII case-insensitive equality (BEH-CPIN-09); never a locale fold.
  static bool _asciiEquals(String a, String b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      var x = a.codeUnitAt(i);
      var y = b.codeUnitAt(i);
      if (x >= 0x41 && x <= 0x5A) x += 0x20;
      if (y >= 0x41 && y <= 0x5A) y += 0x20;
      if (x != y) return false;
    }
    return true;
  }

  static bool _sameMessage(BaseMessage a, BaseMessage b) {
    if (a.id > 0 && a.id == b.id) return true;
    final la = a.localMessageId;
    if (la != null && la.isNotEmpty && la == b.localMessageId) return true;
    return a.muid.isNotEmpty && a.muid == b.muid;
  }

  String? _myUid(ConversationsSeamContext ctx) =>
      ctx.loggedInUser?.uid ?? CometChatUIKit.loggedInUser?.uid;

  /// Test-only: forgets the discarded/evicted messages of this session.
  void debugReset() => _removedUnsent.clear();
}

class _ForceSync extends ForceSyncListener {
  _ForceSync({required this.onError});

  final void Function(CometChatException e) onError;

  @override
  void onForceSyncError(CometChatException error) => onError(error);
}

/// Why load-more on a paging request waits for the next sync page.
enum _Parked {
  /// The read failed past the cache for a reason other than the network.
  failed,

  /// The read failed not-connected past the cache: the page is marked, and
  /// the next sync reads it once (D75).
  offline,
}

/// A server page one paging read applied.
class _PageRead {
  const _PageRead(this.rows, {required this.hasMore});

  /// The server page as received.
  final List<Conversation> rows;

  /// Whether the list may page further after it.
  final bool hasMore;
}
