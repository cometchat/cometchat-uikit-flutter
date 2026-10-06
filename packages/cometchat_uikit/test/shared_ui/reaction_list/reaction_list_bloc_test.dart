/// [ReactionListBloc] — the state machine behind the reaction sheet.
///
/// `reaction_list_props_test.dart` drives the widget off a mocked bloc; this
/// file drives the real bloc. The seam is the injectable
/// `reactionsRequestBuilder`: a fake builder hands back a fake
/// [ReactionsRequest] whose `fetchPrevious` answers from a script, so the
/// whole fetch/merge/paginate path runs with no SDK.
///
/// `RemoveOwnReaction` is only half-testable: its optimistic state update is
/// pinned here, but the `CometChat.removeReaction` call that follows is a
/// static SDK call and is left to fail silently in-process (its `onSuccess` /
/// `onError` arms are therefore uncovered).
///
///   flutter test test/shared_ui/reaction_list/reaction_list_bloc_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
// The SDK exports none of these; `SdkRegistry` is the seam that lets
// `CometChat.removeReaction` resolve to a fake in a VM test. Same approach as
// test/helpers/golden_fake_sdk.dart.
// ignore: implementation_imports
import 'package:cometchat_sdk/src/bootstrap/sdk_registry.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/client/sdk_client.dart' as sdk;
// ignore: implementation_imports
import 'package:cometchat_sdk/src/domain/repositories/messages/reaction_repository.dart'
    as sdk;
import 'package:flutter_test/flutter_test.dart';

/// One scripted answer for a `fetchPrevious` call.
typedef FetchAnswer =
    void Function(
      void Function(List<Reaction>) onSuccess,
      void Function(CometChatException) onError,
    );

FetchAnswer page(List<Reaction> reactions) =>
    (onSuccess, _) => onSuccess(reactions);

FetchAnswer fails(CometChatException e) =>
    (_, onError) => onError(e);

class FakeRequest extends Fake implements ReactionsRequest {
  FakeRequest(this.label, this.script);

  /// Which reaction key this request was built for — 'all', or an emoji.
  final String label;

  /// Consumed one entry per `fetchPrevious`; the last entry repeats.
  final List<FetchAnswer> script;

  int calls = 0;

  @override
  Future<List<Reaction>> fetchPrevious({
    required Function(List<Reaction> message)? onSuccess,
    required Function(CometChatException excep)? onError,
  }) async {
    final answer = script[calls < script.length ? calls : script.length - 1];
    calls++;
    answer((list) => onSuccess!(list), (exception) => onError!(exception));
    return const [];
  }
}

/// Stands in for the SDK builder. The bloc mutates `messageId` / `reaction`
/// on it and then calls `build()`, so the fake records both.
class FakeBuilder extends Fake implements ReactionsRequestBuilder {
  FakeBuilder(this.scripts);

  /// Keyed by the reaction the request is for ('all' for the unfiltered one).
  final Map<String, List<FetchAnswer>> scripts;

  @override
  int messageId = -1;

  @override
  String? reaction;

  final List<FakeRequest> built = [];

  @override
  ReactionsRequest build() {
    final label = reaction ?? ReactionConstants.allReactions;
    final request = FakeRequest(label, scripts[label] ?? [page(const [])]);
    built.add(request);
    // The bloc reuses one builder object, so clear the filter it just set;
    // otherwise the next unfiltered build would inherit this emoji.
    reaction = null;
    return request;
  }

  FakeRequest requestFor(String label) =>
      built.lastWhere((r) => r.label == label);
}

/// What the fake SDK's `removeReaction` does. Set per test.
late Future<BaseMessage> Function(String messageId, String reaction)
onRemoveReaction;

class _FakeReactionRepository extends Fake implements sdk.ReactionRepository {
  @override
  Future<BaseMessage> removeReaction(String messageId, String reaction) =>
      onRemoveReaction(messageId, reaction);
}

class _FakeSdkClient extends Fake implements sdk.SdkClient {
  @override
  final sdk.ReactionRepository reactions = _FakeReactionRepository();

  @override
  Future<void> dispose() async {}
}

/// Records what the kit event bus is told about an edited message.
class _EditRecorder with CometChatMessageEventListener {
  final List<BaseMessage> edited = [];

  @override
  void ccMessageEdited(BaseMessage message, MessageEditStatus status) {
    edited.add(message);
  }
}

TextMessage message({List<ReactionCount> reactions = const []}) => TextMessage(
  id: 7,
  text: 'hi',
  sender: User(uid: 'u1', name: 'Alice'),
  receiverUid: 'u2',
  type: MessageTypeConstants.text,
  receiverType: ReceiverTypeConstants.user,
)..reactions = reactions;

Reaction reaction(String emoji, String uid, {String? id}) => Reaction(
  id: id ?? '$uid-$emoji',
  messageId: 7,
  reaction: emoji,
  uid: uid,
  reactedAt: 1700000000,
  reactedBy: User(uid: uid, name: 'User $uid'),
);

void main() {
  const all = ReactionConstants.allReactions;

  ReactionListBloc makeBloc(
    Map<String, List<FetchAnswer>> scripts, {
    String selected = all,
    FakeBuilder? builder,
  }) => ReactionListBloc(
    messageId: 7,
    reactionsRequestBuilder: builder ?? FakeBuilder(scripts),
    initialSelectedReaction: selected,
  );

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  // =========================================================================
  // Loaded-state computed properties
  // =========================================================================

  group('ReactionListLoaded', () {
    final loaded = ReactionListLoaded(
      messageReactions: {
        '👍': [reaction('👍', 'u1'), reaction('👍', 'u2')],
        '🎉': [reaction('🎉', 'u3')],
      },
      selectedReaction: all,
      totalReactions: 3,
      canFetchMore: true,
    );

    test('reactionData flattens every bucket when "all" is selected', () {
      expect(loaded.reactionData.map((r) => r.uid), ['u1', 'u2', 'u3']);
    });

    test('reactionData narrows to the selected emoji', () {
      final selected = loaded.copyWith(selectedReaction: '🎉');
      expect(selected.reactionData.map((r) => r.uid), ['u3']);
    });

    test('reactionData is empty for an emoji nobody used', () {
      expect(loaded.copyWith(selectedReaction: '🤷').reactionData, isEmpty);
    });

    test('getReactionCount counts a bucket, and falls back to the total', () {
      expect(loaded.getReactionCount('👍'), 2);
      expect(loaded.getReactionCount('🎉'), 1);
      expect(
        loaded.getReactionCount(all),
        3,
        reason: '"all" is not a bucket, so it falls through to totalReactions',
      );
    });

    test('isEmpty tracks the bucket map, not the total', () {
      expect(loaded.isEmpty, isFalse);
      expect(
        const ReactionListLoaded(
          messageReactions: {},
          selectedReaction: all,
          totalReactions: 0,
          canFetchMore: false,
        ).isEmpty,
        isTrue,
      );
    });

    test('copyWith replaces only what it is given', () {
      expect(loaded.copyWith(), loaded);
      expect(loaded.copyWith(totalReactions: 9).totalReactions, 9);
      expect(
        loaded.copyWith(totalReactions: 9).messageReactions,
        loaded.messageReactions,
      );
      expect(loaded.copyWith(canFetchMore: false).canFetchMore, isFalse);
      expect(loaded.copyWith(selectedReaction: '👍').selectedReaction, '👍');
    });

    test('states compare on their fields', () {
      expect(
        const ReactionListLoading(messageReactions: {}, selectedReaction: all),
        const ReactionListLoading(messageReactions: {}, selectedReaction: all),
      );
      expect(
        const ReactionListLoading(messageReactions: {}, selectedReaction: all),
        isNot(
          equals(
            const ReactionListLoading(
              messageReactions: {},
              selectedReaction: '👍',
            ),
          ),
        ),
      );
      // Two const literals are the same object, so that comparison never
      // reaches `props`; a separately allocated one does.
      // ignore: prefer_const_constructors
      final fresh = ReactionListInitial();
      expect(identical(fresh, const ReactionListInitial()), isFalse);
      expect(fresh, const ReactionListInitial());
      expect(fresh.props, isEmpty);

      final error = CometChatException('E', 'boom', 'boom');
      expect(
        ReactionListError(
          error: error,
          messageReactions: const {},
          selectedReaction: all,
        ),
        ReactionListError(
          error: error,
          messageReactions: const {},
          selectedReaction: all,
        ),
      );
    });
  });

  // =========================================================================
  // Event props
  // =========================================================================

  group('event props', () {
    test('valued events compare on their payload', () {
      expect(const FetchReactions(), const FetchReactions(reaction: all));
      expect(
        const FetchReactions(reaction: '👍'),
        isNot(equals(const FetchReactions())),
      );
      expect(
        const UpdateSelectedReaction('👍'),
        const UpdateSelectedReaction('👍'),
      );
      expect(
        const UpdateSelectedReaction('👍'),
        isNot(equals(const UpdateSelectedReaction('🎉'))),
      );

      final r = reaction('👍', 'u1');
      expect(RemoveOwnReaction(r), RemoveOwnReaction(r));
      expect(ReactionAdded(r), ReactionAdded(r));
      expect(
        ReactionAdded(r),
        isNot(equals(ReactionAdded(reaction('👍', 'u2')))),
      );
      expect(
        ReactionRemoved(r),
        isNot(equals(ReactionAdded(r))),
        reason: 'added and removed must never compare equal',
      );
      // ignore: prefer_const_constructors
      expect(InitializeReactionList(), const InitializeReactionList());
    });
  });

  // =========================================================================
  // Initialize / fetch
  // =========================================================================

  group('InitializeReactionList', () {
    test('goes loading then loaded, bucketing reactions by emoji', () async {
      final builder = FakeBuilder({
        all: [
          page([
            reaction('👍', 'u1'),
            reaction('👍', 'u2'),
            reaction('🎉', 'u3'),
          ]),
        ],
      });
      final bloc = makeBloc(const {}, builder: builder);

      final seen = <ReactionListState>[];
      final sub = bloc.stream.listen(seen.add);

      bloc.add(const InitializeReactionList());
      await settle();

      expect(seen.first, isA<ReactionListLoading>());
      expect(bloc.state, isA<ReactionListLoaded>());

      final loaded = bloc.state as ReactionListLoaded;
      expect(loaded.messageReactions.keys, ['👍', '🎉']);
      expect(loaded.messageReactions['👍']!.map((r) => r.uid), ['u1', 'u2']);
      expect(loaded.totalReactions, 3);
      expect(loaded.selectedReaction, all);
      expect(loaded.canFetchMore, isTrue);

      // The builder was pointed at this message.
      expect(builder.messageId, 7);

      await sub.cancel();
      await bloc.close();
    });

    test('an empty first page lands on an empty loaded state', () async {
      final bloc = makeBloc({
        all: [page(const [])],
      });

      bloc.add(const InitializeReactionList());
      await settle();

      final loaded = bloc.state as ReactionListLoaded;
      expect(loaded.isEmpty, isTrue);
      expect(loaded.totalReactions, 0);
      expect(
        loaded.canFetchMore,
        isFalse,
        reason: 'an empty page means the cursor is exhausted',
      );
      await bloc.close();
    });

    test(
      'a failing fetch keeps the exception and the reactions so far',
      () async {
        final boom = CometChatException('ERR_X', 'boom', 'boom');
        final bloc = makeBloc({
          all: [fails(boom)],
        });

        bloc.add(const InitializeReactionList());
        await settle();

        final error = bloc.state as ReactionListError;
        expect(error.error, same(boom));
        expect(error.messageReactions, isEmpty);
        expect(error.selectedReaction, all);
        await bloc.close();
      },
    );

    test('an initial emoji selection fetches that bucket too', () async {
      final builder = FakeBuilder({
        all: [
          page([reaction('👍', 'u1'), reaction('🎉', 'u3')]),
        ],
        '👍': [
          page([reaction('👍', 'u2')]),
        ],
      });
      final bloc = makeBloc(const {}, selected: '👍', builder: builder);

      bloc.add(const InitializeReactionList());
      await settle();

      final loaded = bloc.state as ReactionListLoaded;
      expect(loaded.selectedReaction, '👍');
      expect(
        loaded.messageReactions['👍']!.map((r) => r.uid),
        ['u1', 'u2'],
        reason: 'the filtered page merges into the bucket the "all" page built',
      );
      expect(loaded.totalReactions, 3);
      expect(builder.requestFor('👍').calls, 1);
      await bloc.close();
    });
  });

  group('FetchReactions', () {
    test('a second page appends and skips reactors already listed', () async {
      final builder = FakeBuilder({
        all: [
          page([reaction('👍', 'u1')]),
          page([
            reaction('👍', 'u1'), // same reactor — must not duplicate
            reaction('👍', 'u2'),
          ]),
        ],
      });
      final bloc = makeBloc(const {}, builder: builder);

      bloc.add(const InitializeReactionList());
      await settle();
      expect((bloc.state as ReactionListLoaded).totalReactions, 1);

      bloc.add(const FetchReactions());
      await settle();

      final loaded = bloc.state as ReactionListLoaded;
      expect(loaded.messageReactions['👍']!.map((r) => r.uid), ['u1', 'u2']);
      expect(loaded.totalReactions, 2);
      expect(builder.requestFor(all).calls, 2);
      await bloc.close();
    });

    test(
      'an empty follow-up page ends pagination without losing rows',
      () async {
        final bloc = makeBloc({
          all: [
            page([reaction('👍', 'u1')]),
            page(const []),
          ],
        });

        bloc.add(const InitializeReactionList());
        await settle();
        bloc.add(const FetchReactions());
        await settle();

        final loaded = bloc.state as ReactionListLoaded;
        expect(loaded.canFetchMore, isFalse);
        expect(loaded.totalReactions, 1, reason: 'the first page is kept');
        expect(loaded.messageReactions['👍'], hasLength(1));
        await bloc.close();
      },
    );

    test('a retry after an error starts from an empty list again', () async {
      final boom = CometChatException('ERR_X', 'boom', 'boom');
      final bloc = makeBloc({
        all: [
          fails(boom),
          page([reaction('👍', 'u1')]),
        ],
      });

      bloc.add(const InitializeReactionList());
      await settle();
      expect(bloc.state, isA<ReactionListError>());

      // The error state carries neither reactions nor a total, so the retry
      // has to fall back to an empty map and the initial tab.
      bloc.add(const FetchReactions());
      await settle();

      final loaded = bloc.state as ReactionListLoaded;
      expect(loaded.messageReactions['👍']!.map((r) => r.uid), ['u1']);
      expect(loaded.totalReactions, 1);
      expect(loaded.selectedReaction, all);
      await bloc.close();
    });

    test('a fetch for a reaction with no request is a no-op', () async {
      final bloc = makeBloc({
        all: [
          page([reaction('👍', 'u1')]),
        ],
      });

      bloc.add(const InitializeReactionList());
      await settle();
      final before = bloc.state;

      // No UpdateSelectedReaction came first, so no request exists for 🎉.
      bloc.add(const FetchReactions(reaction: '🎉'));
      await settle();

      expect(bloc.state, same(before));
      await bloc.close();
    });
  });

  // =========================================================================
  // Tab selection
  // =========================================================================

  group('UpdateSelectedReaction', () {
    test('switches the tab and builds a request for it on first use', () async {
      final builder = FakeBuilder({
        all: [
          page([reaction('👍', 'u1'), reaction('🎉', 'u3')]),
        ],
        '🎉': [
          page([reaction('🎉', 'u4')]),
        ],
      });
      final bloc = makeBloc(const {}, builder: builder);

      bloc.add(const InitializeReactionList());
      await settle();
      expect(builder.built.map((r) => r.label), [all]);

      bloc.add(const UpdateSelectedReaction('🎉'));
      await settle();

      expect((bloc.state as ReactionListLoaded).selectedReaction, '🎉');
      expect(builder.built.map((r) => r.label), [all, '🎉']);
      expect(
        (bloc.state as ReactionListLoaded).reactionData.map((r) => r.uid),
        ['u3'],
        reason: 'the tab shows what is already bucketed, before any fetch',
      );

      // Selecting it again must not rebuild the request.
      bloc.add(const UpdateSelectedReaction('🎉'));
      await settle();
      expect(builder.built.map((r) => r.label), [all, '🎉']);

      // ...and the newly created request is now fetchable.
      bloc.add(const FetchReactions(reaction: '🎉'));
      await settle();
      expect(
        (bloc.state as ReactionListLoaded).messageReactions['🎉']!.map(
          (r) => r.uid,
        ),
        ['u3', 'u4'],
      );
      await bloc.close();
    });

    test('is inert before anything has loaded', () async {
      final bloc = makeBloc(const {});

      bloc.add(const UpdateSelectedReaction('🎉'));
      await settle();

      expect(bloc.state, const ReactionListInitial());
      await bloc.close();
    });
  });

  // =========================================================================
  // Realtime add / remove
  // =========================================================================

  group('realtime updates', () {
    Future<ReactionListBloc> loaded(List<Reaction> seed) async {
      final bloc = makeBloc({
        all: [page(seed)],
      });
      bloc.add(const InitializeReactionList());
      await settle();
      return bloc;
    }

    test('ReactionAdded creates a bucket for a brand-new emoji', () async {
      final bloc = await loaded([reaction('👍', 'u1')]);

      bloc.add(ReactionAdded(reaction('🎉', 'u2')));
      await settle();

      final state = bloc.state as ReactionListLoaded;
      expect(state.messageReactions.keys, ['👍', '🎉']);
      expect(state.totalReactions, 2);
      await bloc.close();
    });

    test('ReactionAdded appends a new reactor to an existing bucket', () async {
      final bloc = await loaded([reaction('👍', 'u1')]);

      bloc.add(ReactionAdded(reaction('👍', 'u2')));
      await settle();

      final state = bloc.state as ReactionListLoaded;
      expect(state.messageReactions['👍']!.map((r) => r.uid), ['u1', 'u2']);
      expect(state.totalReactions, 2);
      await bloc.close();
    });

    test('ReactionAdded from the same reactor twice is idempotent', () async {
      final bloc = await loaded([reaction('👍', 'u1')]);

      bloc.add(ReactionAdded(reaction('👍', 'u1', id: 'different-id')));
      await settle();

      final state = bloc.state as ReactionListLoaded;
      expect(state.messageReactions['👍'], hasLength(1));
      expect(state.totalReactions, 1);
      await bloc.close();
    });

    test(
      'ReactionRemoved drops the reactor and decrements the total',
      () async {
        final bloc = await loaded([reaction('👍', 'u1'), reaction('👍', 'u2')]);

        bloc.add(ReactionRemoved(reaction('👍', 'u1')));
        await settle();

        final state = bloc.state as ReactionListLoaded;
        expect(state.messageReactions['👍']!.map((r) => r.uid), ['u2']);
        expect(state.totalReactions, 1);
        expect(
          state.selectedReaction,
          all,
          reason: 'the bucket still exists, so the tab is untouched',
        );
        await bloc.close();
      },
    );

    test(
      'removing the last reactor drops the bucket and resets the tab',
      () async {
        final builder = FakeBuilder({
          all: [
            page([reaction('👍', 'u1'), reaction('🎉', 'u2')]),
          ],
          '👍': [page(const [])],
        });
        final bloc = makeBloc(const {}, builder: builder);
        bloc.add(const InitializeReactionList());
        await settle();
        bloc.add(const UpdateSelectedReaction('👍'));
        await settle();
        expect((bloc.state as ReactionListLoaded).selectedReaction, '👍');

        bloc.add(ReactionRemoved(reaction('👍', 'u1')));
        await settle();

        final state = bloc.state as ReactionListLoaded;
        expect(state.messageReactions.keys, ['🎉']);
        expect(
          state.selectedReaction,
          all,
          reason: 'the selected tab no longer exists, so it must fall back',
        );
        expect(state.totalReactions, 1);
        await bloc.close();
      },
    );

    test('a removal for an emoji nobody used changes only the total', () async {
      final bloc = await loaded([reaction('👍', 'u1')]);

      bloc.add(ReactionRemoved(reaction('🤷', 'u9')));
      await settle();

      final state = bloc.state as ReactionListLoaded;
      expect(state.messageReactions.keys, ['👍']);
      // FINDING: a removal for an unknown emoji still decrements the total,
      // so a stale realtime event can drive `totalReactions` below the number
      // of reactions actually held. Pinning the current behaviour.
      expect(state.totalReactions, 0);
      await bloc.close();
    });

    test('add and remove are inert before anything has loaded', () async {
      final bloc = makeBloc(const {});

      bloc.add(ReactionAdded(reaction('👍', 'u1')));
      bloc.add(ReactionRemoved(reaction('👍', 'u1')));
      await settle();

      expect(bloc.state, const ReactionListInitial());
      await bloc.close();
    });
  });

  // =========================================================================
  // The kit event-bus listener
  // =========================================================================

  group('the message-event listener', () {
    test('reaction events on the bus reach the bloc', () async {
      final before = CometChatMessageEvents.messagesListener.length;
      final bloc = makeBloc({
        all: [
          page([reaction('👍', 'u1')]),
        ],
      });
      expect(
        CometChatMessageEvents.messagesListener.length,
        before + 1,
        reason: 'the bloc registers itself on construction',
      );

      bloc.add(const InitializeReactionList());
      await settle();

      CometChatMessageEvents.onMessageReactionAdded(
        ReactionEvent(reaction: reaction('🎉', 'u2')),
      );
      await settle();
      expect((bloc.state as ReactionListLoaded).messageReactions.keys, [
        '👍',
        '🎉',
      ]);

      CometChatMessageEvents.onMessageReactionRemoved(
        ReactionEvent(reaction: reaction('🎉', 'u2')),
      );
      await settle();
      expect((bloc.state as ReactionListLoaded).messageReactions.keys, ['👍']);

      await bloc.close();
      expect(
        CometChatMessageEvents.messagesListener.length,
        before,
        reason: 'close() must deregister, or the bloc leaks',
      );
    });

    test('a reaction event carrying no reaction is dropped', () async {
      final bloc = makeBloc({
        all: [
          page([reaction('👍', 'u1')]),
        ],
      });
      bloc.add(const InitializeReactionList());
      await settle();
      final before = bloc.state;

      CometChatMessageEvents.onMessageReactionAdded(ReactionEvent());
      CometChatMessageEvents.onMessageReactionRemoved(ReactionEvent());
      await settle();

      expect(bloc.state, same(before));
      await bloc.close();
    });
  });

  // =========================================================================
  // RemoveOwnReaction — optimistic half only
  // =========================================================================

  group('RemoveOwnReaction', () {
    setUp(() async {
      await sdk.SdkRegistry.clear();
      sdk.SdkRegistry.register(_FakeSdkClient());
      onRemoveReaction = (_, _) async => message();
    });

    tearDown(() => sdk.SdkRegistry.clear());

    /// A loaded bloc over [seed], optionally carrying a [messageObject].
    Future<ReactionListBloc> loaded(
      List<Reaction> seed, {
      BaseMessage? messageObject,
    }) async {
      final bloc = ReactionListBloc(
        messageId: 7,
        reactionsRequestBuilder: FakeBuilder({
          all: [page(seed)],
        }),
        messageObject: messageObject,
      );
      bloc.add(const InitializeReactionList());
      await settle();
      return bloc;
    }

    test('is inert before anything has loaded', () async {
      final bloc = makeBloc(const {});

      bloc.add(RemoveOwnReaction(reaction('👍', 'u1')));
      await settle();

      expect(bloc.state, const ReactionListInitial());
      await bloc.close();
    });

    test('drops my row and decrements the total', () async {
      final mine = reaction('👍', 'u1');
      final bloc = await loaded([mine, reaction('👍', 'u2')]);

      bloc.add(RemoveOwnReaction(mine));
      await settle();

      final state = bloc.state as ReactionListLoaded;
      expect(state.messageReactions['👍']!.map((r) => r.uid), ['u2']);
      expect(state.totalReactions, 1);
      await bloc.close();
    });

    test(
      'removing the last reactor drops the bucket and resets the tab',
      () async {
        final mine = reaction('👍', 'u1');
        final builder = FakeBuilder({
          all: [
            page([mine, reaction('🎉', 'u2')]),
          ],
          '👍': [page(const [])],
        });
        final bloc = ReactionListBloc(
          messageId: 7,
          reactionsRequestBuilder: builder,
        );
        bloc.add(const InitializeReactionList());
        await settle();
        bloc.add(const UpdateSelectedReaction('👍'));
        await settle();

        bloc.add(RemoveOwnReaction(mine));
        await settle();

        final state = bloc.state as ReactionListLoaded;
        expect(state.messageReactions.keys, ['🎉']);
        expect(state.selectedReaction, all);
        await bloc.close();
      },
    );

    test(
      'a success announces the updated message on the kit event bus',
      () async {
        final updated = message(
          reactions: [ReactionCount(reaction: '🎉', count: 1)],
        );
        onRemoveReaction = (_, _) async => updated;

        final recorder = _EditRecorder();
        CometChatMessageEvents.addMessagesListener('edit_recorder', recorder);
        addTearDown(
          () => CometChatMessageEvents.removeMessagesListener('edit_recorder'),
        );

        final mine = reaction('👍', 'u1');
        final carrier = message();
        final bloc = await loaded([mine], messageObject: carrier);

        bloc.add(RemoveOwnReaction(mine));
        await settle();

        expect(recorder.edited, [same(carrier)]);
        expect(
          carrier.reactions.map((r) => r.reaction),
          ['🎉'],
          reason:
              'the carrier is restamped with the reactions the SDK returned',
        );
        await bloc.close();
      },
    );

    test('a success with no messageObject announces nothing', () async {
      final recorder = _EditRecorder();
      CometChatMessageEvents.addMessagesListener('edit_recorder2', recorder);
      addTearDown(
        () => CometChatMessageEvents.removeMessagesListener('edit_recorder2'),
      );

      final mine = reaction('👍', 'u1');
      final bloc = await loaded([mine]);

      bloc.add(RemoveOwnReaction(mine));
      await settle();

      expect(recorder.edited, isEmpty);
      expect((bloc.state as ReactionListLoaded).isEmpty, isTrue);
      await bloc.close();
    });

    test('a failure puts my reaction back', () async {
      onRemoveReaction = (_, _) async => throw Exception('server said no');

      final mine = reaction('👍', 'u1');
      final bloc = await loaded([mine, reaction('👍', 'u2')]);

      bloc.add(RemoveOwnReaction(mine));
      await settle();

      final state = bloc.state as ReactionListLoaded;
      expect(state.messageReactions['👍']!.map((r) => r.uid), [
        'u2',
        'u1',
      ], reason: 'the optimistic removal is undone when the call fails');
      expect(state.totalReactions, 2);
      await bloc.close();
    });
  });
}
