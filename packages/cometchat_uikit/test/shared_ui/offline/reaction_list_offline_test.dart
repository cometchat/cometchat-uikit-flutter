// W7 (ENG-41130): the reactions list reads in two rounds when offline is on
// (PR #23 README §3.9). Cached page at once, then the server page in its place;
// "load more" never repeats a reaction; a server error after cached rows keeps
// them with no error. Offline off keeps today's `fetchPrevious` read.

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/reaction_list_offline.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/two_phase.dart';
import 'package:cometchat_chat_uikit/src/chat_sdk_listeners.dart';
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

/// One scripted two-phase read per call; the last entry repeats.
List<List<TwoPhaseResult<Reaction>>> _script = [];
int _reads = 0;

Stream<TwoPhaseResult<Reaction>> _scripted(ReactionsRequest _) {
  final read = _script[_reads < _script.length ? _reads : _script.length - 1];
  _reads++;
  return Stream.fromIterable(read);
}

final _offline = CometChatException(
  'ERROR_NOT_CONNECTED',
  'offline',
  'offline',
);

void main() {
  late _Builder builder;
  ReactionListBloc? bloc;

  ReactionListBloc make() =>
      bloc = ReactionListBloc(messageId: 7, reactionsRequestBuilder: builder);

  setUp(() {
    builder = _Builder();
    _reads = 0;
    ReactionListOffline.debugFetchOverride = _scripted;
  });

  tearDown(() async {
    await bloc?.close();
    bloc = null;
    ReactionListOffline.debugFetchOverride = null;
    CometChat.debugSetOfflineEnabledOverride(null);
  });

  List<String> shown(ReactionListState s) => s is ReactionListLoaded
      ? [for (final r in s.reactionData) '${r.reaction}${r.uid}']
      : const [];

  test('merge appends only reactions not already shown', () {
    final before = {
      '👍': [_r(1, '👍', 'a')],
    };
    final merged = ReactionListOffline.merge(before, [
      _r(1, '👍', 'a'),
      _r(2, '👍', 'b'),
      _r(3, '❤️', 'a'),
    ]);
    expect(merged['👍']!.map((r) => r.uid), ['a', 'b']);
    expect(merged['❤️']!.map((r) => r.uid), ['a']);
    expect(before['👍']!.length, 1, reason: 'input untouched');
    expect(ReactionListOffline.total(merged), 3);
  });

  test('ON: cached page at once, then the server page in its place', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    _script = [
      [
        Cached([_r(1, '👍', 'a'), _r(9, '😂', 'z')]),
        Server([_r(1, '👍', 'a'), _r(2, '👍', 'b')]),
      ],
    ];
    final bloc = make();
    final states = <ReactionListState>[];
    final sub = bloc.stream.listen(states.add);
    bloc.add(const InitializeReactionList());
    await pumpEventQueue();
    await sub.cancel();

    final loaded = states.whereType<ReactionListLoaded>().toList();
    expect(shown(loaded.first), ['👍a', '😂z']);
    expect(shown(loaded.last), ['👍a', '👍b'], reason: 'server replaces');
    expect((loaded.last).totalReactions, 2);
    expect(loaded.last.canFetchMore, isTrue);
    expect(builder.built.single.previousCalls, 0);
  });

  test('ON: load more never repeats; an empty server page ends it', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    _script = [
      [
        const Cached([]),
        Server([_r(1, '👍', 'a'), _r(2, '👍', 'b')]),
      ],
      // Re-delivery past the last page.
      [
        Cached([_r(2, '👍', 'b')]),
        Server([_r(2, '👍', 'b'), _r(3, '❤️', 'c')]),
      ],
      [const Cached([]), const Server([])],
    ];
    final bloc = make();
    bloc.add(const InitializeReactionList());
    await pumpEventQueue();
    bloc.add(const FetchReactions());
    await pumpEventQueue();
    expect(shown(bloc.state), ['👍a', '👍b', '❤️c']);
    expect((bloc.state as ReactionListLoaded).canFetchMore, isTrue);

    bloc.add(const FetchReactions());
    await pumpEventQueue();
    expect(shown(bloc.state), ['👍a', '👍b', '❤️c']);
    expect((bloc.state as ReactionListLoaded).canFetchMore, isFalse);
  });

  test('ON: a server error after cached rows keeps them, no error', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    _script = [
      [
        Cached([_r(1, '👍', 'a')]),
        PhaseError(_offline),
      ],
    ];
    final bloc = make();
    bloc.add(const InitializeReactionList());
    await pumpEventQueue();
    expect(bloc.state, isA<ReactionListLoaded>());
    expect(shown(bloc.state), ['👍a']);
  });

  test('ON: an error with nothing shown is today\'s error', () async {
    CometChat.debugSetOfflineEnabledOverride(true);
    _script = [
      [const Cached([]), PhaseError(_offline)],
    ];
    final bloc = make();
    bloc.add(const InitializeReactionList());
    await pumpEventQueue();
    expect(bloc.state, isA<ReactionListError>());
  });

  test('OFF: today\'s fetchPrevious read, no two-phase read', () async {
    CometChat.debugSetOfflineEnabledOverride(false);
    _script = [
      [
        Cached([_r(5, '🔥', 'x')]),
        Server([_r(5, '🔥', 'x')]),
      ],
    ];
    final bloc = make();
    bloc.add(const InitializeReactionList());
    await pumpEventQueue();
    expect(_reads, 0);
    expect(builder.built.single.previousCalls, 1);
    expect(shown(bloc.state), ['👍a']);
  });

  group('D83 reconnect', () {
    final listeners = <String, ConnectionListener>{};

    setUp(() {
      listeners.clear();
      ChatSdkListeners.debugAddConnectionListener = (id, l) =>
          listeners[id] = l;
      ChatSdkListeners.debugRemoveConnectionListener = listeners.remove;
    });

    tearDown(ChatSdkListeners.debugReset);

    test('ON: an empty server page shows the empty view', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      _script = [
        [const Cached([]), const Server([])],
      ];
      final bloc = make();
      bloc.add(const InitializeReactionList());
      await pumpEventQueue();
      expect(bloc.state, isA<ReactionListLoaded>());
      expect((bloc.state as ReactionListLoaded).isEmpty, isTrue);
    });

    test('ON: the offline error view reads again once on reconnect', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      _script = [
        [PhaseError(CometChatException('ERR_CONNECTION', 'x', 'x'))],
        [
          Server([_r(1, '👍', 'a')]),
        ],
      ];
      final bloc = make();
      bloc.add(const InitializeReactionList());
      await pumpEventQueue();
      expect(bloc.state, isA<ReactionListError>());

      listeners.values.single.onConnected();
      await pumpEventQueue();
      listeners.values.single.onConnected();
      await pumpEventQueue();
      expect(_reads, 2);
      expect(shown(bloc.state), ['👍a']);
      await bloc.close();
      expect(listeners, isEmpty);
    });

    test('ON: a server error (not offline) is not read again', () async {
      CometChat.debugSetOfflineEnabledOverride(true);
      _script = [
        [PhaseError(CometChatException('ERR_TOO_MANY_REQUESTS', 'x', 'x'))],
      ];
      final bloc = make();
      bloc.add(const InitializeReactionList());
      await pumpEventQueue();
      expect(bloc.state, isA<ReactionListError>());
      listeners.values.single.onConnected();
      await pumpEventQueue();
      expect(_reads, 1);
    });

    test('OFF: no connection listener, as today', () async {
      CometChat.debugSetOfflineEnabledOverride(false);
      make();
      expect(listeners, isEmpty);
    });
  });
}
