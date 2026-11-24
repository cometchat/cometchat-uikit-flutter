/// W8 (ENG-41131): mention suggestions. No keyword → two rounds; keyword →
/// server only; offline with a keyword → empty, no error (so no toast).
library;

import 'package:cometchat_chat_uikit/shared_ui/src/offline/mentions_offline.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

final _offline = CometChatException('ERR_CONNECTION', 'offline', 'offline');
final _a = User(uid: 'a', name: 'A');
final _b = User(uid: 'b', name: 'B');

/// A users request whose rounds are scripted.
class _FakeUsersRequest extends Fake implements UsersRequest {
  _FakeUsersRequest({this.cached, this.server, this.error});

  final List<User>? cached;
  final List<User>? server;
  final CometChatException? error;
  final List<String> calls = [];

  @override
  Future<List<User>> fetchNext({
    required Function(List<User> userList)? onSuccess,
    required Function(CometChatException excep)? onError,
    UserFetchListener? listener,
  }) async {
    calls.add(listener == null ? 'legacy' : 'twoPhase');
    if (listener != null) {
      if (cached != null) listener.onCachedUsers(cached!);
      if (server != null) listener.onServerUsers(server!);
      if (error != null) listener.onError(error!);
    } else if (error != null) {
      onError?.call(error!);
    } else {
      onSuccess?.call(server ?? const []);
    }
    return server ?? const [];
  }
}

void main() {
  Future<(List<List<String>>, List<CometChatException>)> fetch(
    _FakeUsersRequest request, {
    String? keyword,
    required bool offlineOn,
  }) async {
    final rounds = <List<String>>[];
    final errors = <CometChatException>[];
    await MentionsOffline.fetchMentionSuggestions(
      request: request,
      keyword: keyword,
      offlineOn: offlineOn,
      onRows: (users) => rounds.add(users.map((u) => u.uid).toList()),
      onError: errors.add,
    );
    return (rounds, errors);
  }

  test('ON, no keyword: two rounds, cached then server', () async {
    final r = _FakeUsersRequest(cached: [_a], server: [_a, _b]);
    final (rounds, errors) = await fetch(r, offlineOn: true);
    expect(r.calls, ['twoPhase']);
    expect(rounds, [
      ['a'],
      ['a', 'b'],
    ]);
    expect(errors, isEmpty);
  });

  test('ON, no keyword, offline: the cached round stays, no error', () async {
    final r = _FakeUsersRequest(cached: [_a], error: _offline);
    final (rounds, errors) = await fetch(r, offlineOn: true);
    expect(rounds, [
      ['a'],
    ]);
    expect(errors, isEmpty);
  });

  test(
    'ON, no keyword, offline with an empty cache: one empty round',
    () async {
      final r = _FakeUsersRequest(cached: const [], error: _offline);
      final (rounds, errors) = await fetch(r, offlineOn: true);
      expect(rounds, [<String>[]]);
      expect(errors, isEmpty);
    },
  );

  test('ON, keyword: server only; offline → empty list, no error', () async {
    final r = _FakeUsersRequest(error: _offline);
    final (rounds, errors) = await fetch(r, keyword: 'al', offlineOn: true);
    expect(r.calls, ['legacy']);
    expect(rounds, [<String>[]]);
    expect(errors, isEmpty);
  });

  test('ON, keyword: a server error that is not offline is reported', () async {
    final err = CometChatException('ERR_X', 'x', 'x');
    final r = _FakeUsersRequest(error: err);
    final (rounds, errors) = await fetch(r, keyword: 'al', offlineOn: true);
    expect(rounds, isEmpty);
    expect(errors, [err]);
  });

  test('OFF: today\'s single call, errors reported as today', () async {
    final r = _FakeUsersRequest(error: _offline);
    final (rounds, errors) = await fetch(r, offlineOn: false);
    expect(r.calls, ['legacy']);
    expect(rounds, isEmpty);
    expect(errors, [_offline]);

    final ok = _FakeUsersRequest(server: [_b]);
    final (okRounds, _) = await fetch(ok, offlineOn: false);
    expect(ok.calls, ['legacy']);
    expect(okRounds, [
      ['b'],
    ]);
  });
}
