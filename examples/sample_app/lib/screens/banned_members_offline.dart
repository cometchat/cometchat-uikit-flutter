import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/two_phase.dart';

/// The banned members screen's offline seam (W6, ENG-41129).
///
/// Snapshot list (PR #23 §3.9, BEH-SNAP-07): with offline on, each page is
/// asked once with the SDK's two-phase listener, the cached page paints at
/// once and the server page replaces it by `uid`. With offline off nothing
/// here runs.

/// Bridges one `BannedGroupMembersRequest.fetchNext(listener:)` call into a
/// [TwoPhaseResult] stream that closes after its terminal (server page or
/// error). The legacy callbacks are not passed, so each page is handled once.
Stream<TwoPhaseResult<GroupMember>> bannedMembersFetchStream(
  BannedGroupMembersRequest request,
) {
  final controller = StreamController<TwoPhaseResult<GroupMember>>();
  var closed = false;
  void terminal(TwoPhaseResult<GroupMember> event) {
    if (closed) return;
    closed = true;
    controller.add(event);
    controller.close();
  }

  controller.onListen = () {
    unawaited(
      request.fetchNext(
        onSuccess: null,
        onError: null,
        listener: _BannedFetchListenerAdapter(
          onCached: (rows) {
            if (!closed) controller.add(Cached(rows));
          },
          onServer: (rows) => terminal(Server(rows)),
          onError: (e) => terminal(PhaseError(e)),
        ),
      ),
    );
  };
  return controller.stream;
}

/// What the screen shows after one phase of a page.
typedef BannedPageView = ({
  List<GroupMember> rows,
  bool hasMore,
  bool hasError,
  bool isLoading,
});

/// One page read in two phases, applied to the screen's rows.
///
/// A next page appends its cached rows (rows already listed are skipped) and
/// the server page then replaces them by uid. A [reload] (reconnect) keeps the
/// rows on screen, skips the cached page, and the server page becomes the
/// list. Only an empty server page ends paging. An error keeps every row;
/// with none, it shows today's error view.
class BannedMembersPage {
  /// Starts a page; [reload] marks the reconnect re-read of the first page.
  BannedMembersPage({this.reload = false});

  /// Whether this is the reconnect re-read of the first page.
  final bool reload;

  final Set<String> _provisional = {};

  /// Applies [phase] to [view] and returns what the screen shows next.
  BannedPageView apply(TwoPhaseResult<GroupMember> phase, BannedPageView view) {
    switch (phase) {
      case Cached<GroupMember>(:final rows):
        if (reload && view.rows.isNotEmpty) return view;
        final seen = {for (final m in view.rows) m.uid};
        final merged = [...view.rows];
        for (final m in rows) {
          if (seen.add(m.uid)) {
            merged.add(m);
            _provisional.add(m.uid);
          }
        }
        return (
          rows: merged,
          hasMore: view.hasMore,
          hasError: false,
          isLoading: _provisional.isEmpty && view.isLoading,
        );
      case Server<GroupMember>(:final rows):
        final base = reload ? const <GroupMember>[] : view.rows;
        return (
          rows: _replacePage(base, _provisional, rows),
          hasMore: rows.isNotEmpty,
          hasError: false,
          isLoading: false,
        );
      case PhaseError<GroupMember>():
        if (view.rows.isNotEmpty) {
          return (
            rows: view.rows,
            hasMore: !reload && _provisional.isNotEmpty,
            hasError: false,
            isLoading: false,
          );
        }
        return (
          rows: view.rows,
          hasMore: view.hasMore,
          hasError: true,
          isLoading: false,
        );
    }
  }

  static List<GroupMember> _replacePage(
    List<GroupMember> current,
    Set<String> provisional,
    List<GroupMember> server,
  ) {
    final byUid = <String, GroupMember>{};
    for (final m in server) {
      byUid.putIfAbsent(m.uid, () => m);
    }
    final merged = <GroupMember>[];
    final placed = <String>{};
    for (final m in current) {
      if (!placed.add(m.uid)) continue;
      final fresh = byUid[m.uid];
      if (fresh != null) {
        merged.add(fresh);
      } else if (!provisional.contains(m.uid)) {
        merged.add(m);
      } else {
        placed.remove(m.uid);
      }
    }
    for (final m in byUid.values) {
      if (placed.add(m.uid)) merged.add(m);
    }
    return merged;
  }
}

/// Serialises the screen's offline-on page reads: one page in flight at a
/// time. A reconnect that arrives while a page is in flight queues one reload
/// (repeat reconnects collapse into it), which runs when that page finishes,
/// so the reconnect's re-read is never skipped.
class BannedPageQueue {
  bool _inFlight = false;
  bool _reloadQueued = false;

  /// Claims the slot for a page read; false while another page is in flight.
  bool tryStart() {
    if (_inFlight) return false;
    _inFlight = true;
    return true;
  }

  /// A reconnect arrived: true when its reload may start now; otherwise one
  /// reload is queued for when the in-flight page finishes.
  bool reconnect() {
    if (!_inFlight) return true;
    _reloadQueued = true;
    return false;
  }

  /// The in-flight page finished; true when a queued reload should run now.
  bool finish() {
    _inFlight = false;
    final runReload = _reloadQueued;
    _reloadQueued = false;
    return runReload;
  }
}

class _BannedFetchListenerAdapter implements BannedGroupMemberFetchListener {
  _BannedFetchListenerAdapter({
    required this.onCached,
    required this.onServer,
    required void Function(CometChatException) onError,
  }) : _onError = onError;
  final void Function(List<GroupMember>) onCached;
  final void Function(List<GroupMember>) onServer;
  final void Function(CometChatException) _onError;

  @override
  void onCachedBannedGroupMembers(List<GroupMember> members) =>
      onCached(members);

  @override
  void onServerBannedGroupMembers(List<GroupMember> members) =>
      onServer(members);

  @override
  void onError(CometChatException e) => _onError(e);
}
