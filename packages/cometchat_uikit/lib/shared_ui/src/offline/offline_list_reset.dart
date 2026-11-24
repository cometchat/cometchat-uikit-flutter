import 'dart:async';

import 'offline_hub.dart';
import 'offline_hub_event.dart';

/// Session end and cache reset for the lists and panels outside Conversations
/// and the message list (G8, ENG-41569). Internal: not exported.
///
/// A list subscribes with [listen]. For a current-gen [SessionEnded] or
/// [CacheReset], `onReset` runs at once in the hub listener: the list bumps
/// its own read generation there, so a read in flight stops writing, and then
/// clears its rows and request before the next frame. On a cache reset it
/// reloads once from page one, quietly over rows (D84 (5)). The hub posts the
/// reset notice and `ccOfflineCacheReset` itself, so a list posts nothing.
/// With offline off the hub publishes neither event, so nothing changes (G1).
abstract final class OfflineListReset {
  /// Subscribes to the hub. `onReset` gets the event, a [SessionEnded] or a
  /// [CacheReset] of the current gen; every other event and every event
  /// older than the hub's gen is ignored. Cancel the subscription on close.
  static StreamSubscription<OfflineHubEvent> listen({
    required bool Function() isClosed,
    required void Function(OfflineHubEvent event) onReset,
  }) {
    return OfflineHub.instance.events.listen((event) {
      if (isClosed() || isStale(event)) return;
      if (event is SessionEnded || event is CacheReset) onReset(event);
    });
  }

  /// Whether [event] belongs to an earlier session: queued before a session
  /// end but handled after it.
  static bool isStale(OfflineHubEvent event) =>
      event.gen < OfflineHub.instance.gen;
}
