import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;

import '../../../../shared_ui/src/offline/message_list_offline_reads.dart'
    show isNotConnectedError;
import '../../../../shared_ui/src/offline/two_phase.dart';
import '../data/datasources/users_remote_datasource.dart';
import '../data/repositories/users_repository_impl.dart';
import '../domain/usecases/get_users_usecase.dart';
import 'users_state.dart';

/// The users list's offline seam (W6, ENG-41129). Internal: not exported.
///
/// Snapshot list (PR #23 §3.9): with offline on, each page is asked once with
/// the SDK's two-phase listener, the cached page paints at once and the server
/// page replaces it by `uid`. Offline with nothing to show, the list shows an
/// offline state, never an error view (D84 (3), (7)). With offline off nothing
/// here runs.

/// "Connect to search" (D84 (7)): a search keyword is set, nothing cached
/// matched and the device is offline. A filter without a keyword (presence,
/// roles, tags) is a plain list: "Connect to load users". An offline state, so `onError`
/// does not fire; the search runs again once on reconnect.
class UsersConnectToSearch extends UsersState {
  /// Creates the state.
  const UsersConnectToSearch();
}

/// "Connect to load users" (D84 (3)): a plain load found nothing cached and
/// the device is offline. An offline state with no Retry (the app's error
/// view shows instead if it passed one); `onError` fires once with [error];
/// the list loads again once on reconnect.
class UsersConnectToLoad extends UsersState {
  /// Creates the state.
  const UsersConnectToLoad(this.error);

  /// The not-connected error the load failed with.
  final CometChatException error;

  @override
  List<Object?> get props => [error];
}

/// Bridges one two-phase `UsersRequest.fetchNext(listener:)` call, made by
/// [start], into a [TwoPhaseResult] stream that closes after its terminal
/// (server page or error).
Stream<TwoPhaseResult<User>> userFetchStream(
  void Function(UserFetchListener listener) start,
) {
  final controller = StreamController<TwoPhaseResult<User>>();
  var closed = false;
  void terminal(TwoPhaseResult<User> event) {
    if (closed) return;
    closed = true;
    controller.add(event);
    controller.close();
  }

  controller.onListen = () {
    start(
      _UserFetchListenerAdapter(
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

/// Pure helpers for the users list's offline-on path.
abstract final class UsersOffline {
  /// Reads the next page of [source]'s request in two phases.
  static Stream<TwoPhaseResult<User>> readNextPage(
    UsersRemoteDataSourceImpl source, {
    int limit = 30,
    String? searchKeyword,
    UsersRequestBuilder? usersRequestBuilder,
  }) => userFetchStream(
    (listener) => source.fetchNextTwoPhase(
      limit: limit,
      searchKeyword: searchKeyword,
      usersRequestBuilder: usersRequestBuilder,
      listener: listener,
    ),
  );

  /// The kit's own data source behind [useCase], or `null` when the app
  /// injected its own repository or data source (today's single-phase path).
  static UsersRemoteDataSourceImpl? twoPhaseSourceFor(GetUsersUseCase useCase) {
    final repository = useCase.repository;
    if (repository is! UsersRepositoryImpl) return null;
    final source = repository.remoteDataSource;
    return source is UsersRemoteDataSourceImpl ? source : null;
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
  /// plain list and shows "Connect to load users" (D84 (3)). A blank keyword
  /// is no keyword, as the search box treats it.
  static bool hasServerOnlyFilter(String? keyword, UsersRequestBuilder? b) {
    if (keyword != null && keyword.trim().isNotEmpty) return true;
    final appKeyword = b?.searchKeyword;
    return appKeyword != null && appKeyword.trim().isNotEmpty;
  }

  /// Appends the rows of a cached page that the list does not hold yet and
  /// records their uids in [provisional], so the server page can replace them.
  static List<User> appendCached(
    List<User> current,
    List<User> cached,
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
  static List<User> replacePage(
    List<User> current,
    Set<String> provisional,
    List<User> server,
  ) {
    final byUid = <String, User>{};
    for (final u in server) {
      byUid.putIfAbsent(u.uid, () => u);
    }
    final merged = <User>[];
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

  static final Expando<bool> _serverReplaced = Expando<bool>(
    'usersServerReplace',
  );

  /// Tags the list instance an offline-on server page produced, so the list
  /// view rebuilds even when the row count is unchanged.
  static void markServerReplace(List<User> list) =>
      _serverReplaced[list] = true;

  /// Whether [current] is a server replacement the view has not drawn yet.
  /// Only lists tagged by [markServerReplace] qualify, so with offline off the
  /// view's rebuild rule is unchanged.
  static bool needsRebuild(List<User> previous, List<User> current) =>
      !identical(previous, current) && (_serverReplaced[current] ?? false);
}

class _UserFetchListenerAdapter implements UserFetchListener {
  _UserFetchListenerAdapter({
    required this.onCached,
    required this.onServer,
    required void Function(CometChatException) onError,
  }) : _onError = onError;
  final void Function(List<User>) onCached;
  final void Function(List<User>) onServer;
  final void Function(CometChatException) _onError;

  @override
  void onCachedUsers(List<User> users) => onCached(users);

  @override
  void onServerUsers(List<User> users) => onServer(users);

  @override
  void onError(CometChatException e) => _onError(e);
}
