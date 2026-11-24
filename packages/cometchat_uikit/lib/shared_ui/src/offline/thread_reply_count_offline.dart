import 'dart:math' as math;

import 'package:cometchat_sdk/cometchat_sdk.dart';

import 'message_list_seam_context.dart';
import 'message_send_state.dart';
import 'offline_hub_event.dart';

/// W7's seam: a thread's reply count while the user's own replies wait to be
/// sent (PR #23 README §3.9 "Thread header reply count", BEH-MUT-10).
///
/// The count shown is the parent's `replyCount` as the SDK last delivered it,
/// which already includes this device's own unsent replies (pending or
/// failed). On top of it, an own reply adds one only at its first enqueue, and
/// a discard takes one back once. A Retry never adds: the reply was counted at
/// its first enqueue, or it existed before the parent value and is part of it.
/// A reply that went through the offline send path (it has a
/// `localMessageId`) never adds at `sent` either. A fresher parent from
/// `onMessagesSynced` through the hub replaces the value; the replies already
/// seen stay in the [ThreadReplyLedger], so a later event for one of them
/// never counts it again. Used only when offline is on; the OFF path never
/// reaches this file.
abstract final class ThreadReplyCountOffline {
  static final Expando<ThreadReplyLedger> _ledgers = Expando(
    'ThreadReplyLedger',
  );

  /// The ledger of own replies counted by [owner] (a message-list bloc).
  static ThreadReplyLedger ledgerFor(Object owner) =>
      _ledgers[owner] ??= ThreadReplyLedger();

  /// Hook: [owner] (a message-list bloc) opened. Starts its ledger now, so
  /// an own reply composed before the list opened — already in the parent
  /// rows the SDK delivers — never adds on a later Retry.
  static void attach(Object owner) => ledgerFor(owner);

  /// Hook: today's "+1 on own threaded `sent`" in the main message list.
  /// Returns whether to apply it (see [ThreadReplyLedger.claimSent]).
  static bool claimSentReply(Object owner, BaseMessage reply) =>
      ledgerFor(owner).claimSent(reply);

  /// Hub collector of the main message list (inside the bloc's event loop).
  /// Applies +1 for an own reply's first enqueue and −1 when it is discarded,
  /// on the parent row shown, through the W1 seam hook
  /// [MessageListSeamContext.initializeThreadReplyCount]. The parent model's
  /// `replyCount` moves with it, as today's increment does, so a row rebuild
  /// re-seeds the same value. A thread list keeps today's count.
  static void onMessageListHubEvent(
    Object owner,
    MessageListSeamContext ctx,
    OfflineHubEvent event,
  ) {
    if (event is SessionEnded) {
      ledgerFor(owner).clear();
      return;
    }
    if (event is! SendStateEvent || ctx.parentMessageId != null) return;
    final parentId = event.message.parentMessageId;
    if (parentId <= 0) return;
    final delta = ledgerFor(owner).deltaFor(event);
    if (delta == 0) return;
    final index = ctx.findMessageIndex(parentId);
    final rows = ctx.state.messages;
    if (index == null || index < 0 || index >= rows.length) return;
    final parent = rows[index];
    final next = math.max(0, parent.replyCount + delta);
    parent.replyCount = next;
    ctx.initializeThreadReplyCount(parentId, next);
  }

  /// The thread header's reply count after [event], or null when [event] does
  /// not change it. [current] is the count shown; [ledger] is the header's.
  static int? headerCountAfter({
    required int parentMessageId,
    required int current,
    required ThreadReplyLedger ledger,
    required OfflineHubEvent event,
  }) {
    switch (event) {
      case SendStateEvent():
        if (event.message.parentMessageId != parentMessageId) return null;
        final delta = ledger.deltaFor(event);
        return delta == 0 ? null : math.max(0, current + delta);
      case MessagesUpdated():
        for (final m in event.messages) {
          if (m.id == parentMessageId) {
            // A fresher parent: every own reply composed before it is in it.
            ledger.rebase();
            return m.replyCount;
          }
        }
        return null;
      case SessionEnded():
        ledger.clear();
        return null;
      default:
        return null;
    }
  }
}

/// The own replies one surface has seen, keyed by `localMessageId` and muid
/// (either matches), against the parent value it counts from.
///
/// The parent value is the one the SDK delivered when the ledger started (or
/// was [rebase]d). Per BEH-MUT-10 it already includes every own reply that
/// was in the outbox then, so each reply adds at most once (only at a first
/// enqueue after that point) and is taken back at most once (on discard,
/// whether it was added here or was already part of the value).
class ThreadReplyLedger {
  /// Creates a ledger that counts from a parent value delivered now.
  ThreadReplyLedger() : _since = _now();

  final List<_Entry> _entries = [];

  /// When the parent value this ledger counts from was taken.
  DateTime _since;

  /// The +1/−1 a send-state event makes:
  /// * `sending` for a reply not seen yet: +1 for a first enqueue; 0 for a
  ///   Retry of a reply composed before the parent value (it is in it);
  /// * `failed` + `discarded`: −1 once per reply (see [release]);
  /// * else 0 (a `sent`, a repeat, a transient or direct failure).
  int deltaFor(SendStateEvent event) {
    final reply = event.message;
    final lid = event.localMessageId.isNotEmpty
        ? event.localMessageId
        : reply.localMessageId;
    if (event.state == CometChatMessageSendState.sending) {
      if (!claim(reply, localMessageId: lid)) return 0;
      // A reply with an outbox row composed before the parent value was
      // taken is part of that value: this `sending` is a Retry.
      final inParent = _key(lid) != null && _composedBefore(reply) == true;
      return inParent ? 0 : 1;
    }
    final discarded =
        event.state == CometChatMessageSendState.failed &&
        event.reason == MessageFailureReason.discarded;
    if (discarded) return release(reply, localMessageId: lid) ? -1 : 0;
    return 0;
  }

  /// Whether a `sent` own reply adds one. A reply with a `localMessageId` went
  /// through the offline send path and never adds here; one without (a send
  /// outside that path) adds once, as today.
  bool claimSent(BaseMessage reply) {
    // Not recorded: the pending event may still be on its way (it is
    // delivered asynchronously), and it must still add.
    if (_key(reply.localMessageId) != null) return false;
    return claim(reply);
  }

  /// Records [reply] as seen. Returns `true` when it was not seen yet; a
  /// reply with neither key always returns `true`.
  bool claim(BaseMessage reply, {String? localMessageId}) {
    final lid = _key(localMessageId ?? reply.localMessageId);
    final muid = _key(reply.muid);
    if (lid == null && muid == null) return true;
    final existing = _find(lid, muid);
    if (existing != null) {
      existing.lid ??= lid;
      existing.muid ??= muid;
      return false;
    }
    _entries.add(_Entry(lid, muid));
    return true;
  }

  /// Marks [reply] discarded. Returns `true` when the count includes it and
  /// it was not taken back yet (the caller subtracts one): a reply seen here
  /// (added at its first enqueue, or part of the parent value), or one not
  /// seen that has an outbox row (a `localMessageId`) and was not composed
  /// after the parent value — the SDK's parent includes it (BEH-MUT-10). A
  /// repeat discard of the same reply returns `false`.
  bool release(BaseMessage reply, {String? localMessageId}) {
    final lid = _key(localMessageId ?? reply.localMessageId);
    final muid = _key(reply.muid);
    final existing = _find(lid, muid);
    if (existing != null) {
      if (existing.released) return false;
      existing.released = true;
      return true;
    }
    // Never in the outbox (no localMessageId): the parent never had it.
    if (lid == null) return false;
    _entries.add(_Entry(lid, muid)..released = true);
    return _composedBefore(reply) != false;
  }

  /// A fresher parent value replaced the count: own replies composed before
  /// now are part of it. The replies already seen stay seen.
  void rebase() => _since = _now();

  /// Forgets every reply and counts from a parent value delivered now
  /// (session end, or the header opened on a thread).
  void clear() {
    _entries.clear();
    _since = _now();
  }

  /// Whether [reply] was composed before the parent value was taken, from its
  /// `sentAt` (the compose time while unsent); null when it has none.
  bool? _composedBefore(BaseMessage reply) => reply.sentAt?.isBefore(_since);

  _Entry? _find(String? lid, String? muid) {
    for (final e in _entries) {
      if (lid != null && e.lid == lid) return e;
      if (muid != null && e.muid == muid) return e;
    }
    return null;
  }

  static String? _key(String? v) => (v == null || v.isEmpty) ? null : v;

  // Millisecond precision: an unsent reply's `sentAt` is in milliseconds.
  static DateTime _now() => DateTime.fromMillisecondsSinceEpoch(
    DateTime.now().millisecondsSinceEpoch,
  );
}

class _Entry {
  _Entry(this.lid, this.muid);
  String? lid;
  String? muid;
  bool released = false;
}
