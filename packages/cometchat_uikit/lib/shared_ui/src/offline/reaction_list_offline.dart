import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'two_phase.dart';

/// W7's seam: the reactions list read in two rounds when offline is on
/// (PR #23 README §3.9 "Reactions list, notification feed").
///
/// The SDK replays a recorded page only on `ReactionsRequest.fetchNext`
/// ([ReactionFetchListener.onCachedReactions]); `fetchPrevious` has no cached
/// phase, so the ON path reads forward. Each fetch shows the cached page at
/// once, then replaces it with the server page; a page appends only reactions
/// not already shown, so a re-delivery past the last page never repeats a row.
abstract final class ReactionListOffline {
  /// Test seam: replaces the SDK read. Null in production.
  @visibleForTesting
  static Stream<TwoPhaseResult<Reaction>> Function(ReactionsRequest request)?
  debugFetchOverride;

  /// One two-phase read of [request]: zero or one [Cached], then one [Server]
  /// or [PhaseError]; the stream closes after its terminal.
  static Stream<TwoPhaseResult<Reaction>> fetch(ReactionsRequest request) {
    final override = debugFetchOverride;
    if (override != null) return override(request);
    final controller = StreamController<TwoPhaseResult<Reaction>>();
    var closed = false;
    void terminal(TwoPhaseResult<Reaction> event) {
      if (closed) return;
      closed = true;
      controller.add(event);
      controller.close();
    }

    controller.onListen = () {
      request.fetchNext(
        onSuccess: null,
        onError: null,
        listener: _ReactionListener(
          onCached: (rows) {
            if (!closed) controller.add(Cached(rows));
          },
          onServer: (rows) => terminal(Server(rows)),
          onError: (e) => terminal(PhaseError(e)),
        ),
      );
    };
    return controller.stream;
  }

  /// [before] plus the reactions of [page] not already in it, grouped by
  /// emoji, in page order. Identity is (emoji, reacting user), as the list
  /// keys rows today. Returns a new map; [before] is not changed.
  static Map<String, List<Reaction>> merge(
    Map<String, List<Reaction>> before,
    List<Reaction> page,
  ) {
    final merged = <String, List<Reaction>>{
      for (final e in before.entries) e.key: List.of(e.value),
    };
    for (final r in page) {
      final emoji = r.reaction;
      if (emoji == null) continue;
      final rows = merged.putIfAbsent(emoji, () => []);
      final uid = r.reactedBy?.uid ?? r.uid;
      final shown = rows.any((e) => (e.reactedBy?.uid ?? e.uid) == uid);
      if (!shown) rows.add(r);
    }
    merged.removeWhere((_, rows) => rows.isEmpty);
    return merged;
  }

  /// The number of reactions in [reactions].
  static int total(Map<String, List<Reaction>> reactions) =>
      reactions.values.fold(0, (sum, rows) => sum + rows.length);
}

class _ReactionListener implements ReactionFetchListener {
  _ReactionListener({
    required this.onCached,
    required this.onServer,
    required void Function(CometChatException) onError,
  }) : _onError = onError;

  final void Function(List<Reaction>) onCached;
  final void Function(List<Reaction>) onServer;
  final void Function(CometChatException) _onError;

  @override
  void onCachedReactions(List<Reaction> reactions) => onCached(reactions);

  @override
  void onServerReactions(List<Reaction> reactions) => onServer(reactions);

  @override
  void onError(CometChatException e) => _onError(e);
}
