import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;

import '../../../../shared_ui/src/offline/message_list_offline_reads.dart'
    show isNotConnectedError;
import '../../../../shared_ui/src/offline/two_phase.dart';
import '../data/datasources/group_members_remote_datasource.dart';
import '../data/repositories/group_members_repository_impl.dart';
import '../domain/repositories/group_members_repository.dart';
import 'group_members_state.dart';

/// The group members list's offline seam (W6, ENG-41129). Internal: not exported.
///
/// Snapshot list (PR #23 §3.9): with offline on, each page is asked once with
/// the SDK's two-phase listener, the cached page paints at once and the server
/// page replaces it by `uid`. Offline with nothing to show, the list shows an
/// offline state, never an error view (D84 (3), (7)). With offline off nothing
/// here runs.

/// "Connect to search" (D84 (7)): a search keyword is set, nothing cached
/// matched and the device is offline. A filter without a keyword (status,
/// scopes) is a plain list: "Connect to load members". An offline state, so `onError`
/// does not fire; the search runs again once on reconnect.
class GroupMembersConnectToSearch extends GroupMembersState {
  /// Creates the state.
  const GroupMembersConnectToSearch();
}

/// "Connect to load members" (D84 (3)): a plain load found nothing cached and
/// the device is offline. An offline state with no Retry (the app's error
/// view shows instead if it passed one); `onError` fires once with [error];
/// the list loads again once on reconnect.
class GroupMembersConnectToLoad extends GroupMembersState {
  /// Creates the state.
  const GroupMembersConnectToLoad(this.error);

  /// The not-connected error the load failed with.
  final CometChatException error;

  @override
  List<Object?> get props => [error];
}

/// Bridges one two-phase `GroupMembersRequest.fetchNext(listener:)` call, made
/// by [start], into a [TwoPhaseResult] stream that closes after its terminal
/// (server page or error).
Stream<TwoPhaseResult<GroupMember>> groupMemberFetchStream(
  void Function(GroupMemberFetchListener listener) start,
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
    start(
      _GroupMemberFetchListenerAdapter(
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

/// Pure helpers for the group members list's offline-on path.
abstract final class GroupMembersOffline {
  /// Reads the next page of [source]'s request in two phases.
  static Stream<TwoPhaseResult<GroupMember>> readNextPage(
    GroupMembersRemoteDataSourceImpl source, {
    required String guid,
    int limit = 30,
    String? searchKeyword,
    GroupMembersRequestBuilder? groupMembersRequestBuilder,
  }) => groupMemberFetchStream(
    (listener) => source.fetchNextTwoPhase(
      guid: guid,
      limit: limit,
      searchKeyword: searchKeyword,
      groupMembersRequestBuilder: groupMembersRequestBuilder,
      listener: listener,
    ),
  );

  /// The kit's own data source behind [repository], or `null` when the app
  /// injected its own repository or data source (today's single-phase path).
  static GroupMembersRemoteDataSourceImpl? twoPhaseSourceFor(
    GroupMembersRepository repository,
  ) {
    if (repository is! GroupMembersRepositoryImpl) return null;
    final source = repository.remoteDataSource;
    return source is GroupMembersRemoteDataSourceImpl ? source : null;
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
  /// plain list and shows "Connect to load members" (D84 (3)). A blank
  /// keyword is no keyword, as the search box treats it.
  static bool hasServerOnlyFilter(
    String? keyword,
    GroupMembersRequestBuilder? b,
  ) {
    if (keyword != null && keyword.trim().isNotEmpty) return true;
    final appKeyword = b?.searchKeyword;
    return appKeyword != null && appKeyword.trim().isNotEmpty;
  }

  /// Appends the rows of a cached page that the list does not hold yet and
  /// records their uids in [provisional], so the server page can replace them.
  static List<GroupMember> appendCached(
    List<GroupMember> current,
    List<GroupMember> cached,
    Set<String> provisional,
  ) {
    final seen = {for (final u in current) u.uid};
    final merged = [...current];
    for (final u in cached) {
      if (seen.add(u.uid)) {
        merged.add(u);
        provisional.add(u.uid);
      }
    }
    return merged;
  }

  /// Replaces a page in place by `uid`: the cached rows of that page
  /// ([provisional]) the server no longer has are dropped, rows the list holds
  /// are updated where they stand, and new rows are appended in server order.
  /// No uid appears twice.
  static List<GroupMember> replacePage(
    List<GroupMember> current,
    Set<String> provisional,
    List<GroupMember> server,
  ) {
    final byUid = <String, GroupMember>{};
    for (final u in server) {
      byUid.putIfAbsent(u.uid, () => u);
    }
    final merged = <GroupMember>[];
    final placed = <String>{};
    for (final u in current) {
      if (!placed.add(u.uid)) continue;
      final fresh = byUid[u.uid];
      if (fresh != null) {
        merged.add(fresh);
      } else if (!provisional.contains(u.uid)) {
        merged.add(u);
      } else {
        placed.remove(u.uid);
      }
    }
    for (final u in byUid.values) {
      if (placed.add(u.uid)) merged.add(u);
    }
    return merged;
  }
}

class _GroupMemberFetchListenerAdapter implements GroupMemberFetchListener {
  _GroupMemberFetchListenerAdapter({
    required this.onCached,
    required this.onServer,
    required void Function(CometChatException) onError,
  }) : _onError = onError;
  final void Function(List<GroupMember>) onCached;
  final void Function(List<GroupMember>) onServer;
  final void Function(CometChatException) _onError;

  @override
  void onCachedGroupMembers(List<GroupMember> members) => onCached(members);

  @override
  void onServerGroupMembers(List<GroupMember> members) => onServer(members);

  @override
  void onError(CometChatException e) => _onError(e);
}
