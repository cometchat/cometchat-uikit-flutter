/// The windowed reconcile shared by the message list (W2) and the conversation
/// list (W3) on the offline ON path (W1 §2.4, PR #23 §3.3).
///
/// Pure and generic over the row type `T`: the caller supplies the identity,
/// server-id presence, `updatedAt`, ordering and keep accessors. Every function
/// returns a new list; the input is never mutated.
library;

/// How one phase's rows merge into the list already shown.
class ReconcileConfig<T> {
  /// Creates a reconcile configuration.
  const ReconcileConfig({
    required this.rowKey,
    required this.hasServerId,
    required this.updatedAt,
    required this.compare,
    this.keep,
    this.merge,
  });

  /// Stable dedupe key (server id when present, else the local key). The
  /// conversation list keys by `conversationId`.
  final String Function(T row) rowKey;

  /// Whether the row carries a server id (an un-acked row does not). A row
  /// without one is never removed (BEH-READ-30).
  final bool Function(T row) hasServerId;

  /// Milliseconds-since-epoch of the row's last update; a larger value wins a
  /// same-key collision (a live edit is never reverted).
  final int Function(T row) updatedAt;

  /// The list's sort order (e.g. message `(sentAt, id)` with un-acked rows
  /// last by compose time, BEH-READ-10). The server phase's omission range is
  /// measured in this order, not by numeric id.
  final Comparator<T> compare;

  /// Rows for which this returns true are never removed as omissions (e.g. a
  /// conversation whose preview is an own unsent message, BEH-CONV-06).
  final bool Function(T row)? keep;

  /// Combines two copies of one row on a same-key collision: [kept] is the
  /// copy the `updatedAt` rule keeps, [dropped] the other. Returns the row to
  /// show (e.g. [kept] with fields only [dropped] still carries, such as a
  /// message's receipts). Null keeps [kept] as is. The list passed in is never
  /// mutated; this callback may update [kept] itself.
  final T Function(T kept, T dropped)? merge;
}

/// Outcome of a reconcile pass.
class ReconcileResult<T> {
  /// Creates a reconcile result.
  const ReconcileResult({
    required this.rows,
    required this.hasMore,
    this.dropped = false,
  });

  /// The reconciled, sorted list (a copy of the current list when [dropped]).
  final List<T> rows;

  /// Whether this direction still has more history to page. Unchanged by a
  /// cached phase; set only by a server phase (see [reconcileServer]).
  final bool hasMore;

  /// True when the phase belonged to an older list generation and was
  /// discarded unapplied.
  final bool dropped;
}

/// Upserts a **cached** phase into [current] (W1 §2.4, PR #23 §3.3).
///
/// Dropped unapplied when [opGen] differs from [listGen] (the list was cleared
/// or reset while the read was in flight). Same key keeps the newer
/// `updatedAt`. A cached phase never removes a row and **never ends history**:
/// even an empty cached page leaves `hasMore` at [currentHasMore]
/// (BEH-READ-09b).
ReconcileResult<T> reconcileCached<T>({
  required List<T> current,
  required List<T> cached,
  required bool currentHasMore,
  required int opGen,
  required int listGen,
  required ReconcileConfig<T> config,
}) {
  if (opGen != listGen) {
    return ReconcileResult(
      rows: List.of(current),
      hasMore: currentHasMore,
      dropped: true,
    );
  }
  final merged = _upsert(current, cached, config);
  return ReconcileResult(rows: merged, hasMore: currentHasMore);
}

/// Upserts a **server** phase into [current] (W1 §2.4, PR #23 §3.3).
///
/// Dropped unapplied when [opGen] differs from [listGen]. Same key keeps the
/// newer `updatedAt`. Then removes every row that has a server id, is not in
/// [server], is not kept by [ReconcileConfig.keep], and sorts between the
/// first and last [server] rows (a proven omission inside the page's range).
/// A row with **no** server id is never removed (BEH-READ-30). History ends
/// only when [server] is empty while online (BEH-READ-09b):
/// `hasMore = server.isNotEmpty`.
ReconcileResult<T> reconcileServer<T>({
  required List<T> current,
  required List<T> server,
  required bool currentHasMore,
  required int opGen,
  required int listGen,
  required ReconcileConfig<T> config,
}) {
  if (opGen != listGen) {
    return ReconcileResult(
      rows: List.of(current),
      hasMore: currentHasMore,
      dropped: true,
    );
  }
  final merged = _upsert(current, server, config);

  if (server.isNotEmpty) {
    final serverKeys = <String>{for (final r in server) config.rowKey(r)};
    var lo = server.first;
    var hi = server.first;
    for (final r in server) {
      if (config.compare(r, lo) < 0) lo = r;
      if (config.compare(r, hi) > 0) hi = r;
    }
    final keep = config.keep;
    merged.removeWhere((r) {
      if (!config.hasServerId(r)) return false; // BEH-READ-30
      if (serverKeys.contains(config.rowKey(r))) return false;
      if (keep != null && keep(r)) return false;
      return config.compare(r, lo) >= 0 && config.compare(r, hi) <= 0;
    });
  }

  merged.sort(config.compare);
  return ReconcileResult(rows: merged, hasMore: server.isNotEmpty);
}

List<T> _upsert<T>(
  List<T> current,
  List<T> incoming,
  ReconcileConfig<T> config,
) {
  final byKey = <String, T>{};
  for (final r in current) {
    byKey[config.rowKey(r)] = r;
  }
  final merge = config.merge;
  for (final r in incoming) {
    final key = config.rowKey(r);
    final existing = byKey[key];
    if (existing == null) {
      byKey[key] = r;
      continue;
    }
    final incomingWins = config.updatedAt(r) >= config.updatedAt(existing);
    final kept = incomingWins ? r : existing;
    if (merge == null || identical(r, existing)) {
      byKey[key] = kept;
    } else {
      byKey[key] = merge(kept, incomingWins ? existing : r);
    }
  }
  final out = byKey.values.toList();
  out.sort(config.compare);
  return out;
}
