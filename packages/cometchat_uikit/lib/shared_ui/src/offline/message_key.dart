import 'package:cometchat_sdk/cometchat_sdk.dart';

/// Row identity for the offline ON path (W1 §2.3, PR #23 §3.2, G6).
///
/// These helpers are used when offline is on, except [renderKey]: the message
/// list keys its rows (item key and bubble `GlobalKey`) by it whether offline
/// is on or off, so an offline flip mid-session remounts no row. Everything
/// else on the OFF path keeps today's identity (`_muidIndexMap`).
///
/// In the Flutter SDK `BaseMessage.muid` is a non-null `String` that defaults
/// to `''`; an empty muid is treated as "no muid" (the cross-SDK spec uses a
/// null check, which collapses to the empty check here).

/// A stable storage/dedupe key. A row with a server id keys on it; an un-acked
/// row keys on its `localMessageId`, falling back to its own `muid`. A row with
/// none of the three keys on its object identity, so two such rows never
/// collapse onto one key.
String rowKey(BaseMessage m) {
  if (m.id > 0) return 's:${m.id}';
  final lid = m.localMessageId;
  if (lid != null && lid.isNotEmpty) return 'l:$lid';
  if (m.muid.isNotEmpty) return 'l:m:${m.muid}';
  return 'l:o:${identityHashCode(m)}';
}

/// The render/diff key (what Flutter's bubble `GlobalKey` uses on the ON path):
/// stable from compose to ack for own messages, server id for everyone else.
///
/// Own messages key on `localMessageId` (then own `muid`, then server id) so an
/// own bubble does not remount when its ack lands. Other senders always key on
/// the server id; their muids are never used (they can collide).
String renderKey(BaseMessage m, String? myUid) {
  final senderUid = m.sender?.uid;
  final isOwn = senderUid != null && myUid != null && senderUid == myUid;
  if (!isOwn) return 's:${m.id}';
  final lid = m.localMessageId;
  if (lid != null && lid.isNotEmpty) return lid;
  if (m.muid.isNotEmpty) return 'm:${m.muid}';
  return 's:${m.id}';
}

/// One row per own render key and own muid (D-351): two own rows that share
/// either would share a bubble `GlobalKey` and the list's item key. The later
/// row folds into the earlier one, which keeps its position; a copy with a
/// server id wins over one without, and the kept copy takes the later
/// `deliveredAt` and `readAt` of both. Other senders' rows are never folded.
/// Returns [rows] itself when no two rows fold.
List<BaseMessage> collapseRepeatedOwnRows(
  List<BaseMessage> rows,
  String? myUid,
) {
  if (myUid == null) return rows;
  final firstAt = <String, int>{};
  List<BaseMessage>? out;
  for (var i = 0; i < rows.length; i++) {
    final m = rows[i];
    final keys = _ownKeys(m, myUid);
    int? at;
    for (final k in keys) {
      at ??= firstAt[k];
    }
    if (at == null) {
      final index = out?.length ?? i;
      for (final k in keys) {
        firstAt[k] = index;
      }
      out?.add(m);
      continue;
    }
    out ??= rows.sublist(0, i);
    final kept = out[at];
    final winner = kept.id <= 0 && m.id > 0 ? m : kept;
    final loser = identical(winner, m) ? kept : m;
    _keepLaterReceipts(winner, loser);
    out[at] = winner;
    for (final k in _ownKeys(winner, myUid)) {
      firstAt[k] = at;
    }
  }
  return out ?? rows;
}

List<String> _ownKeys(BaseMessage m, String myUid) {
  if (m.sender?.uid != myUid) return const [];
  final key = renderKey(m, myUid);
  return [
    if (!key.startsWith('s:')) 'r:$key',
    if (m.muid.isNotEmpty) 'm:${m.muid}',
  ];
}

void _keepLaterReceipts(BaseMessage kept, BaseMessage dropped) {
  final d = dropped.deliveredAt, r = dropped.readAt;
  if (d != null && (kept.deliveredAt == null || d.isAfter(kept.deliveredAt!))) {
    kept.deliveredAt = d;
  }
  if (r != null && (kept.readAt == null || r.isAfter(kept.readAt!))) {
    kept.readAt = r;
  }
}

/// Null-safe identity lookup for the ON path (W1 §2.3, G6).
///
/// Holds the rows currently shown and resolves an inbound message to an
/// existing row by, in order: its server id; then its `localMessageId`, but
/// **only** against rows that have no server id, the same sender and the same
/// conversation; then the owner's own `muid`, under the same restriction. An
/// alias map `localMessageId → serverId` is filled when a row acquires an id
/// (on ack) and cleared on a `gen` change, so a late event carrying either
/// identity lands on the same row.
///
/// Two null/empty identities never match, and another sender's muid is never a
/// key.
class MessageIdentityIndex {
  /// Creates an index; [myUid] identifies own messages (own muids are keys).
  MessageIdentityIndex({String? myUid}) : _myUid = myUid;

  final String? _myUid;

  /// serverId → row.
  final Map<int, BaseMessage> _byServerId = {};

  /// localMessageId → row (only rows without a server id).
  final Map<String, BaseMessage> _byLocalId = {};

  /// own muid → row (only rows without a server id).
  final Map<String, BaseMessage> _byMuid = {};

  /// localMessageId → serverId, filled on ack so a late event matches.
  final Map<String, int> _aliasToServerId = {};

  bool _isOwn(BaseMessage m) {
    final s = m.sender?.uid;
    return s != null && _myUid != null && s == _myUid;
  }

  bool _sameConversation(BaseMessage a, BaseMessage b) {
    final ca = a.conversationId, cb = b.conversationId;
    if (ca != null && cb != null) return ca == cb;
    // Fall back to receiver identity when conversationId is not stamped yet.
    return a.receiverUid == b.receiverUid && a.receiverType == b.receiverType;
  }

  bool _sameSender(BaseMessage a, BaseMessage b) {
    final sa = a.sender?.uid, sb = b.sender?.uid;
    return sa != null && sb != null && sa == sb;
  }

  /// Registers [m] in the index. Call on every row the list holds.
  void put(BaseMessage m) {
    if (m.id > 0) {
      _byServerId[m.id] = m;
      final lid = m.localMessageId;
      if (lid != null && lid.isNotEmpty) {
        _aliasToServerId[lid] = m.id;
        _byLocalId.remove(lid);
      }
      if (m.muid.isNotEmpty) _byMuid.remove(m.muid);
      return;
    }
    final lid = m.localMessageId;
    if (lid != null && lid.isNotEmpty) _byLocalId[lid] = m;
    if (_isOwn(m) && m.muid.isNotEmpty) _byMuid[m.muid] = m;
  }

  /// Resolves [incoming] to the row it updates, or null if it is new.
  BaseMessage? lookup(BaseMessage incoming) {
    if (incoming.id > 0) {
      final hit = _byServerId[incoming.id];
      if (hit != null) return hit;
    }
    final lid = incoming.localMessageId;
    if (lid != null && lid.isNotEmpty) {
      final aliased = _aliasToServerId[lid];
      if (aliased != null) {
        final hit = _byServerId[aliased];
        if (hit != null) return hit;
      }
      final hit = _byLocalId[lid];
      if (hit != null &&
          hit.id <= 0 &&
          _sameSender(hit, incoming) &&
          _sameConversation(hit, incoming)) {
        return hit;
      }
    }
    if (_isOwn(incoming) && incoming.muid.isNotEmpty) {
      final hit = _byMuid[incoming.muid];
      if (hit != null &&
          hit.id <= 0 &&
          _sameSender(hit, incoming) &&
          _sameConversation(hit, incoming)) {
        return hit;
      }
    }
    return null;
  }

  /// Clears everything (a `gen` change / session end).
  void clear() {
    _byServerId.clear();
    _byLocalId.clear();
    _byMuid.clear();
    _aliasToServerId.clear();
  }
}
