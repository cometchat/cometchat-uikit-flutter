import 'package:cometchat_sdk/cometchat_sdk.dart';

/// W8's seam for mention suggestions (`CometChatMentionsFormatter`).
///
/// With offline off, [fetchMentionSuggestions] makes today's call exactly.
/// With offline on:
/// - **no keyword:** two rounds (cached, then server) through the SDK's
///   two-phase users / group-members read; a non-empty cached round shows at
///   once and the server round follows. A connection failure shows what the
///   cache had (or an empty list), never an error.
/// - **keyword:** server only, as today; a connection failure gives an empty
///   list and no error, so no error toast.
abstract final class MentionsOffline {
  static const Set<String> _connectivityCodes = {
    'ERR_CONNECTION',
    'ERR_NETWORK_TIMEOUT',
  };

  static bool _isConnectivityError(CometChatException e) =>
      _connectivityCodes.contains(e.code);

  /// Fetches the next page of [request] (a `UsersRequest` or a
  /// `GroupMembersRequest`) and hands each round to [onRows]. [onError] gets
  /// the errors today's path reports.
  static Future<void> fetchMentionSuggestions({
    required dynamic request,
    required String? keyword,
    required bool offlineOn,
    required void Function(List<User> users) onRows,
    required void Function(CometChatException e) onError,
  }) async {
    final hasKeyword = keyword != null && keyword.isNotEmpty;
    if (!offlineOn ||
        hasKeyword ||
        (request is! UsersRequest && request is! GroupMembersRequest)) {
      await request.fetchNext(
        onSuccess: (users) => onRows(List<User>.from(users)),
        onError: (CometChatException e) {
          if (offlineOn && _isConnectivityError(e)) {
            onRows(const []);
          } else {
            onError(e);
          }
        },
      );
      return;
    }

    var cachedShown = false;
    void cached(List<User> users) {
      if (users.isEmpty) return;
      cachedShown = true;
      onRows(users);
    }

    void failed(CometChatException e) {
      if (!_isConnectivityError(e)) {
        onError(e);
      } else if (!cachedShown) {
        onRows(const []);
      }
    }

    if (request is UsersRequest) {
      await request.fetchNext(
        onSuccess: null,
        onError: null,
        listener: _UsersListener(cached, onRows, failed),
      );
    } else if (request is GroupMembersRequest) {
      await request.fetchNext(
        onSuccess: null,
        onError: null,
        listener: _MembersListener(cached, onRows, failed),
      );
    }
  }
}

class _UsersListener implements UserFetchListener {
  _UsersListener(this._cached, this._server, this._error);

  final void Function(List<User>) _cached;
  final void Function(List<User>) _server;
  final void Function(CometChatException) _error;

  @override
  void onCachedUsers(List<User> users) => _cached(users);

  @override
  void onServerUsers(List<User> users) => _server(users);

  @override
  void onError(CometChatException e) => _error(e);
}

class _MembersListener implements GroupMemberFetchListener {
  _MembersListener(this._cached, this._server, this._error);

  final void Function(List<User>) _cached;
  final void Function(List<User>) _server;
  final void Function(CometChatException) _error;

  @override
  void onCachedGroupMembers(List<GroupMember> members) => _cached(members);

  @override
  void onServerGroupMembers(List<GroupMember> members) => _server(members);

  @override
  void onError(CometChatException e) => _error(e);
}
