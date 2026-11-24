import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;

import '../../../../shared_ui/src/offline/message_list_offline_reads.dart'
    show isNotConnectedError;
import '../../../../shared_ui/src/offline/two_phase.dart';
import '../data/datasources/groups_remote_datasource.dart';
import '../data/repositories/groups_repository_impl.dart';
import '../domain/repositories/groups_repository.dart';
import 'groups_state.dart';

/// The groups list's offline seam (W6, ENG-41129). Internal: not exported.
///
/// Snapshot list (PR #23 §3.9): with offline on, each page is asked once with
/// the SDK's two-phase listener, the cached page paints at once and the server
/// page replaces it by `guid`. Offline with nothing to show, the list shows an
/// offline state, never an error view (D84 (3), (7)). With offline off nothing
/// here runs.

/// "Connect to search" (D84 (7)): a search keyword is set, nothing cached
/// matched and the device is offline. A filter without a keyword (type,
/// joined-only, tags) is a plain list: "Connect to load groups". An offline state, so `onError` does not
/// fire; the search runs again once on reconnect.
class GroupsConnectToSearch extends GroupsState {
  /// Creates the state.
  const GroupsConnectToSearch();
}

/// "Connect to load groups" (D84 (3)): a plain load found nothing cached and
/// the device is offline. An offline state with no Retry and no "create or
/// join" prompt (the app's error view shows instead if it passed one);
/// `onError` fires once with [error]; the list loads again once on reconnect.
class GroupsConnectToLoad extends GroupsState {
  /// Creates the state.
  const GroupsConnectToLoad(this.error);

  /// The not-connected error the load failed with.
  final CometChatException error;

  @override
  List<Object?> get props => [error];
}

/// Bridges one two-phase `GroupsRequest.fetchNext(listener:)` call, made by
/// [start], into a [TwoPhaseResult] stream that closes after its terminal
/// (server page or error).
Stream<TwoPhaseResult<Group>> groupFetchStream(
  void Function(GroupFetchListener listener) start,
) {
  final controller = StreamController<TwoPhaseResult<Group>>();
  var closed = false;
  void terminal(TwoPhaseResult<Group> event) {
    if (closed) return;
    closed = true;
    controller.add(event);
    controller.close();
  }

  controller.onListen = () {
    start(
      _GroupFetchListenerAdapter(
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

/// Pure helpers for the groups list's offline-on path.
abstract final class GroupsOffline {
  /// Reads the next page of [source]'s request in two phases.
  static Stream<TwoPhaseResult<Group>> readNextPage(
    GroupsRemoteDataSourceImpl source, {
    int limit = 30,
    String? searchKeyword,
    bool? joinedOnly,
    GroupsRequestBuilder? groupsRequestBuilder,
  }) => groupFetchStream(
    (listener) => source.fetchNextTwoPhase(
      limit: limit,
      searchKeyword: searchKeyword,
      joinedOnly: joinedOnly,
      groupsRequestBuilder: groupsRequestBuilder,
      listener: listener,
    ),
  );

  /// The kit's own data source behind [repository], or `null` when the app
  /// injected its own repository or data source (today's single-phase path).
  static GroupsRemoteDataSourceImpl? twoPhaseSourceFor(
    GroupsRepository repository,
  ) {
    if (repository is! GroupsRepositoryImpl) return null;
    final source = repository.remoteDataSource;
    return source is GroupsRemoteDataSourceImpl ? source : null;
  }

  /// Whether [e] means the device could not reach the server (the
  /// not-connected error of D84): never an error view or `onError` over rows.
  /// The kit's one classification, [isNotConnectedError]; `ERR_NETWORK` (the
  /// SDK's catch-all for an unexpected failure) is a real error.
  static bool isConnectivityError(CometChatException e) =>
      isNotConnectedError(e);

  /// Whether the read is a keyword search: a non-blank keyword, the search
  /// box's or the app builder's. Offline with nothing cached, it shows
  /// "Connect to search" (D84 (7)); any other read, filtered or not, is a
  /// plain list and shows "Connect to load groups" (D84 (3)). A blank
  /// keyword is no keyword, as the search box treats it.
  static bool hasServerOnlyFilter(String? keyword, GroupsRequestBuilder? b) {
    if (keyword != null && keyword.trim().isNotEmpty) return true;
    final appKeyword = b?.searchKeyword;
    return appKeyword != null && appKeyword.trim().isNotEmpty;
  }

  /// Appends the rows of a cached page that the list does not hold yet and
  /// records their guids in [provisional], so the server page can replace them.
  static List<Group> appendCached(
    List<Group> current,
    List<Group> cached,
    Set<String> provisional,
  ) {
    final seen = {for (final g in current) g.guid};
    final merged = [...current];
    for (final g in cached) {
      if (seen.add(g.guid)) {
        merged.add(g);
        provisional.add(g.guid);
      }
    }
    return merged;
  }

  /// Replaces a page in place by `guid`: the cached rows of that page
  /// ([provisional]) the server no longer has are dropped, rows the list holds
  /// are updated where they stand, and new rows are appended in server order.
  /// No guid appears twice.
  static List<Group> replacePage(
    List<Group> current,
    Set<String> provisional,
    List<Group> server,
  ) {
    final byGuid = <String, Group>{};
    for (final g in server) {
      byGuid.putIfAbsent(g.guid, () => g);
    }
    final merged = <Group>[];
    final placed = <String>{};
    for (final g in current) {
      if (!placed.add(g.guid)) continue;
      final fresh = byGuid[g.guid];
      if (fresh != null) {
        merged.add(fresh);
      } else if (!provisional.contains(g.guid)) {
        merged.add(g);
      } else {
        placed.remove(g.guid);
      }
    }
    for (final g in byGuid.values) {
      if (placed.add(g.guid)) merged.add(g);
    }
    return merged;
  }

  static final Expando<bool> _serverReplaced = Expando<bool>(
    'groupsServerReplace',
  );

  /// Tags the list instance an offline-on server page produced, so the list
  /// view rebuilds even when the row count is unchanged.
  static void markServerReplace(List<Group> list) =>
      _serverReplaced[list] = true;

  /// Whether [current] is a server replacement the view has not drawn yet.
  /// Only lists tagged by [markServerReplace] qualify, so with offline off the
  /// view's rebuild rule is unchanged.
  static bool needsRebuild(List<Group> previous, List<Group> current) =>
      !identical(previous, current) && (_serverReplaced[current] ?? false);
}

class _GroupFetchListenerAdapter implements GroupFetchListener {
  _GroupFetchListenerAdapter({
    required this.onCached,
    required this.onServer,
    required void Function(CometChatException) onError,
  }) : _onError = onError;
  final void Function(List<Group>) onCached;
  final void Function(List<Group>) onServer;
  final void Function(CometChatException) _onError;

  @override
  void onCachedGroups(List<Group> groups) => onCached(groups);

  @override
  void onServerGroups(List<Group> groups) => onServer(groups);

  @override
  void onError(CometChatException e) => _onError(e);
}
