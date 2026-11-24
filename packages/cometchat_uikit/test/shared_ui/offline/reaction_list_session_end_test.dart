/// Reaction list on session end and cache reset (G8, ENG-41569).
///
/// With offline on the list reads through `ReactionListOffline` (scripted
/// here); offline off it reads through a fake request. The hub is driven the
/// way a logout produces it: offline on during the session, the SDK then
/// reports offline off, and only then do the logout signals arrive.
///
///   flutter test test/shared_ui/offline/reaction_list_session_end_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_hub.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/reaction_list_offline.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/two_phase.dart';
import 'package:flutter_test/flutter_test.dart';

Reaction _r(int id, String emoji, String uid) => Reaction(
  id: "$id",
  messageId: 7,
  reaction: emoji,
  uid: uid,
  reactedBy: User(uid: uid, name: uid),
  reactedAt: id * 1000,
);

class _Request extends Fake implements ReactionsRequest {
  int previousCalls = 0;

  @override
  Future<List<Reaction>> fetchPrevious({
    required Function(List<Reaction> message)? onSuccess,
    required Function(CometChatException excep)? onError,
    ReactionFetchListener? listener,
  }) async {
    previousCalls++;
    onSuccess?.call([_r(1, '👍', 'a')]);
    return const [];
  }
}

class _Builder extends Fake implements ReactionsRequestBuilder {
  final List<_Request> built = [];

  @override
  int messageId = -1;

  @override
  String? reaction;

  @override
  ReactionsRequest build() {
    final r = _Request();
    built.add(r);
    reaction = null;
    return r;
  }
}

/// Each two-phase read answers with the next scripted stream.
final _answers = <Stream<TwoPhaseResult<Reaction>>>[];
int _reads = 0;

Stream<TwoPhaseResult<Reaction>> _phases(List<TwoPhaseResult<Reaction>> e) =>
    Stream.fromIterable(e);

final _hub = OfflineHub.instance;

void _logout() {
  CometChat.debugSetOfflineEnabledOverride(false);
  _hub.onKitLogout();
  _hub.debugLogout();
}

void _cacheReset() =>
    _hub.debugCacheReset(OfflineCacheResetReason.encryptionChanged, 0);

List<String> _shown(ReactionListState s) => s is ReactionListLoaded
    ? [for (final r in s.reactionData) '${r.reaction}${r.uid}']
    : const [];

void main() {
  late _Builder builder;

  ReactionListBloc make() {
    final bloc = ReactionListBloc(
      messageId: 7,
      reactionsRequestBuilder: builder,
    );
    addTearDown(bloc.close);
    return bloc;
  }

  setUp(() {
    builder = _Builder();
    _reads = 0;
    _answers.clear();
    ReactionListOffline.debugFetchOverride = (_) {
      _reads++;
      return _answers.removeAt(0);
    };
    _hub.debugReset();
    CometChat.debugSetOfflineEnabledOverride(true);
    _hub.debugLoginSuccess('alice'); // offline on during this session
  });

  tearDown(() {
    ReactionListOffline.debugFetchOverride = null;
    CometChat.debugSetOfflineEnabledOverride(null);
  });

  test('sessionEnded clears rows and resets paging', () async {
    _answers.add(
      _phases([
        Server([_r(1, '👍', 'a')]),
      ]),
    );
    final bloc = make()..add(const InitializeReactionList());
    await pumpEventQueue();
    expect(_shown(bloc.state), ['👍a']);

    _logout();
    await pumpEventQueue();

    expect(bloc.state, isA<ReactionListInitial>());
    // Paging is closed: the cleared requests read nothing more.
    bloc.add(const FetchReactions());
    await pumpEventQueue();
    expect(_reads, 1);

    // The next user's load reads page one from a fresh request.
    CometChat.debugSetOfflineEnabledOverride(true);
    _hub.debugLoginSuccess('bob');
    _answers.add(
      _phases([
        Server([_r(2, '❤️', 'b')]),
      ]),
    );
    bloc.add(const InitializeReactionList());
    await pumpEventQueue();
    expect(builder.built, hasLength(2));
    expect(_shown(bloc.state), ['❤️b']);
  });

  test('sessionEnded drops the result of a read in flight', () async {
    final pending = StreamController<TwoPhaseResult<Reaction>>();
    _answers.add(pending.stream);
    final bloc = make()..add(const InitializeReactionList());
    await pumpEventQueue();

    _logout();
    await pumpEventQueue();
    pending.add(Server([_r(1, '👍', 'a')]));
    await pending.close();
    await pumpEventQueue();

    expect(bloc.state, isA<ReactionListInitial>());
  });

  test('stale event is ignored', () async {
    _answers.add(
      _phases([
        Server([_r(1, '👍', 'a')]),
      ]),
    );
    final bloc = make()..add(const InitializeReactionList());
    await pumpEventQueue();

    // Published, then the session ends before it is delivered: it belongs to
    // the old session, so it must not reload.
    _cacheReset();
    _logout();
    await pumpEventQueue();

    expect(_reads, 1);
    expect(bloc.state, isA<ReactionListInitial>());
  });

  test('cacheReset clears then reloads once', () async {
    _answers
      ..add(
        _phases([
          Server([_r(1, '👍', 'a')]),
        ]),
      )
      ..add(
        _phases([
          Server([_r(2, '❤️', 'b')]),
        ]),
      );
    final bloc = make()..add(const InitializeReactionList());
    await pumpEventQueue();
    final states = <ReactionListState>[];
    final sub = bloc.stream.listen(states.add);
    addTearDown(sub.cancel);

    _cacheReset();
    await pumpEventQueue();

    expect(states.first, isA<ReactionListInitial>());
    expect(_reads, 2);
    expect(_shown(bloc.state), ['❤️b']);
  });

  test('cacheReset reload failure over rows is quiet', () async {
    _answers
      ..add(
        _phases([
          Server([_r(1, '👍', 'a')]),
        ]),
      )
      ..add(
        _phases([
          Cached([_r(3, '🔥', 'c')]),
          PhaseError(CometChatException('ERR_INTERNAL_SERVER', 'x', 'x')),
        ]),
      );
    final bloc = make()..add(const InitializeReactionList());
    await pumpEventQueue();
    final states = <ReactionListState>[];
    final sub = bloc.stream.listen(states.add);
    addTearDown(sub.cancel);

    _cacheReset();
    await pumpEventQueue();

    expect(_shown(bloc.state), ['🔥c']);
    expect(states.whereType<ReactionListError>(), isEmpty);
  });

  test('offline off: no change', () async {
    _hub.debugReset();
    CometChat.debugSetOfflineEnabledOverride(false);
    _hub.debugLoginSuccess('alice');
    final bloc = make()..add(const InitializeReactionList());
    await pumpEventQueue();
    expect(_shown(bloc.state), ['👍a']);

    _cacheReset();
    _hub.onKitLogout();
    _hub.debugLogout();
    await pumpEventQueue();

    expect(_shown(bloc.state), ['👍a']);
    expect(builder.built.single.previousCalls, 1);
  });

  test('close cancels the hub subscription', () async {
    final bloc = make();
    expect(_hub.debugHasListeners, isTrue);
    await bloc.close();
    expect(_hub.debugHasListeners, isFalse);
  });
}
