import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, test, group, setUp, setUpAll, tearDown, tearDownAll;
import 'package:mocktail/mocktail.dart' hide any;
import 'package:mocktail/mocktail.dart' as mt;

import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/repositories/conversations_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/delete_conversation_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_conversation_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_conversations_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/load_more_conversations_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/mark_as_delivered_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/utils/debouncer.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/utils/preview_cache.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';

import 'generators/conversation_generators.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _MockConversationsRepository extends Mock
    implements ConversationsRepository {}

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'pbt_user';
}

ConversationsBloc _makeBloc(
  _MockConversationsRepository repo, {
  List<Conversation> initial = const [],
}) {
  when(
    () => repo.getLoggedInUser(),
  ).thenAnswer((_) async => Success(_FakeUser()));
  when(
    () => repo.getConversations(limit: mt.any(named: 'limit')),
  ).thenAnswer((_) async => Success(initial));
  when(
    () => repo.deleteConversation(
      mt.any(),
      conversationWith: mt.any(named: 'conversationWith'),
      conversationType: mt.any(named: 'conversationType'),
    ),
  ).thenAnswer((_) async => const Success(null));

  return ConversationsBloc(
    getConversationsUseCase: GetConversationsUseCase(repo),
    loadMoreConversationsUseCase: LoadMoreConversationsUseCase(repo),
    deleteConversationUseCase: DeleteConversationUseCase(repo),
    getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
    getConversationUseCase: GetConversationUseCase(repo),
    markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
    disableSDKListeners: true,
  );
}

Future<ConversationsLoaded> _loadedWith(List<Conversation> convs) async {
  final repo = _MockConversationsRepository();
  final bloc = _makeBloc(repo, initial: convs);
  bloc.add(const LoadConversations());
  await Future<void>.delayed(const Duration(milliseconds: 80));
  final state = bloc.state;
  await bloc.close();
  return state as ConversationsLoaded;
}

// ---------------------------------------------------------------------------
// Property: Selection toggle is self-inverse
// toggle(x) ∘ toggle(x) == noop
// ---------------------------------------------------------------------------

Future<void> _propSelectionToggleIdempotent(IndexedList il) async {
  final repo = _MockConversationsRepository();
  final bloc = _makeBloc(repo, initial: il.list);

  bloc.add(const LoadConversations());
  await Future<void>.delayed(const Duration(milliseconds: 80));

  final before = Set<String>.from(
    (bloc.state as ConversationsLoaded).selectedConversations,
  );

  bloc.add(ToggleConversationSelection(il.selectedId));
  bloc.add(ToggleConversationSelection(il.selectedId));
  await Future<void>.delayed(const Duration(milliseconds: 20));

  final after = (bloc.state as ConversationsLoaded).selectedConversations;

  expect(
    after,
    equals(before),
    reason:
        'toggle twice on ${il.selectedId} should leave selection unchanged. '
        'Before=$before After=$after',
  );

  await bloc.close();
}

// ---------------------------------------------------------------------------
// Property: RemoveConversation removes exactly the target and preserves
// the relative order of the remaining conversations.
// ---------------------------------------------------------------------------

Future<void> _propRemovePreservesRemainder(IndexedList il) async {
  final repo = _MockConversationsRepository();
  final bloc = _makeBloc(repo, initial: il.list);

  bloc.add(const LoadConversations());
  await Future<void>.delayed(const Duration(milliseconds: 80));

  bloc.add(RemoveConversation(il.selectedId));
  await Future<void>.delayed(const Duration(milliseconds: 20));

  final expected = [
    for (var i = 0; i < il.list.length; i++)
      if (i != il.index) il.list[i],
  ];
  final expectedIds = expected.map((c) => c.conversationId).toList();

  final state = bloc.state;
  final List<String?> afterIds;
  if (state is ConversationsLoaded) {
    afterIds = state.conversations.map((c) => c.conversationId).toList();
  } else if (state is ConversationsEmpty) {
    // Removing the last remaining conversation is allowed to transition to
    // the Empty state; afterIds is effectively [].
    afterIds = const [];
  } else {
    fail('Unexpected state after RemoveConversation: $state');
  }

  expect(
    afterIds,
    equals(expectedIds),
    reason:
        'RemoveConversation(${il.selectedId}) should produce $expectedIds '
        'but got $afterIds',
  );

  await bloc.close();
}

// ---------------------------------------------------------------------------
// Property: ClearConversationSelection empties the selection regardless of
// what was previously selected.
// ---------------------------------------------------------------------------

Future<void> _propClearSelectionAlwaysEmpty(List<Conversation> convs) async {
  // Need non-empty unique list.
  if (convs.isEmpty) return;
  final ids = <String>{};
  final unique = <Conversation>[];
  for (final c in convs) {
    final id = c.conversationId;
    if (id != null && ids.add(id)) unique.add(c);
  }
  if (unique.isEmpty) return;

  final repo = _MockConversationsRepository();
  final bloc = _makeBloc(repo, initial: unique);
  bloc.add(const LoadConversations());
  await Future<void>.delayed(const Duration(milliseconds: 80));

  for (final c in unique) {
    bloc.add(ToggleConversationSelection(c.conversationId!));
  }
  bloc.add(const ClearConversationSelection());
  await Future<void>.delayed(const Duration(milliseconds: 20));

  final selected = (bloc.state as ConversationsLoaded).selectedConversations;
  expect(
    selected,
    isEmpty,
    reason: 'ClearConversationSelection should empty selection, got $selected',
  );

  await bloc.close();
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUser());
  });

  // -------------------------------------------------------------------------
  // PreviewCache — pure invariants
  // -------------------------------------------------------------------------

  group('PreviewCache — properties', () {
    Glados2(
      any.intInRange(1, 20),
      any.listWithLengthInRange(0, 40, any.letterOrDigits),
    ).test('size is always <= maxCacheSize after any sequence of puts', (
      maxSize,
      keys,
    ) {
      final cache = PreviewCache(maxCacheSize: maxSize);
      for (final k in keys) {
        cache.put(k, CachedPreview(formattedText: k));
      }
      expect(cache.size, lessThanOrEqualTo(maxSize));
    });

    Glados2(
      any.intInRange(1, 10),
      any.listWithLengthInRange(0, 30, any.letterOrDigits),
    ).test(
      'put/get round-trip for the most recent key always returns the same preview',
      (maxSize, keys) {
        if (keys.isEmpty) return;
        // Dedup to avoid ambiguous "most recent" when the same key appears twice
        // — we want to assert that a freshly-put key is retrievable.
        final cache = PreviewCache(maxCacheSize: maxSize);
        for (final k in keys) {
          cache.put(k, CachedPreview(formattedText: k));
        }
        final lastKey = keys.last;
        if (lastKey.isEmpty) return; // empty keys are used in some fallbacks
        final got = cache.get(lastKey);
        expect(
          got,
          isNotNull,
          reason: 'Just-put key $lastKey should be retrievable',
        );
        expect(got!.formattedText, equals(lastKey));
      },
    );

    Glados2(
      any.listWithLengthInRange(1, 20, any.letterOrDigits),
      any.positiveInt,
    ).test('remove(k) + get(k) returns null for any prior state', (keys, _) {
      final cache = PreviewCache();
      for (final k in keys) {
        cache.put(k, CachedPreview(formattedText: k));
      }
      final target = keys.last;
      cache.remove(target);
      // If target also appeared earlier and was evicted between, cache.get
      // legitimately returns null. Either way, post-remove get(target) is null.
      expect(cache.get(target), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // CachedPreview — expiry monotonicity
  // -------------------------------------------------------------------------

  group('CachedPreview — properties', () {
    Glados2(
      any.positiveInt,
      any.positiveInt,
    ).test('isExpired is monotone in elapsed time relative to TTL', (
      ttlMillis,
      elapsedMillis,
    ) {
      // Build a preview whose cachedAt is "elapsedMillis ago" with ttlMillis TTL.
      final ttl = Duration(milliseconds: ttlMillis.clamp(1, 3600 * 1000));
      final cachedAt = DateTime.now().subtract(
        Duration(milliseconds: elapsedMillis.clamp(0, 3600 * 1000)),
      );
      final preview = CachedPreview(
        formattedText: 'p',
        cachedAt: cachedAt,
        ttl: ttl,
      );

      // isExpired must be true iff now - cachedAt > ttl
      final expected = DateTime.now().difference(cachedAt) > ttl;
      expect(preview.isExpired, equals(expected));
    });
  });

  // -------------------------------------------------------------------------
  // Debouncer — coalescing
  // -------------------------------------------------------------------------

  group('Debouncer — properties', () {
    Glados(any.intInRange(2, 20)).test(
      'N rapid calls within duration coalesce into exactly 1 callback',
      (n) async {
        final d = Debouncer(duration: const Duration(milliseconds: 40));
        var called = 0;

        for (var i = 0; i < n; i++) {
          d.call(() => called++);
          // zero gap — rely on microtask queue
        }

        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(
          called,
          1,
          reason: 'N=$n rapid calls should coalesce to 1, got $called',
        );
        d.dispose();
      },
    );
  });

  // -------------------------------------------------------------------------
  // LoadMoreConversationsUseCase — dedup by id is order-independent
  // -------------------------------------------------------------------------

  group('LoadMoreConversationsUseCase — properties', () {
    Glados2(
      distinctConversationsGen(maxLength: 10),
      distinctConversationsGen(maxLength: 10),
    ).test('dedup result never contains ids already in currentConversations', (
      current,
      incoming,
    ) async {
      if (current.isEmpty) return; // from-id pagination requires non-empty
      final repo = _MockConversationsRepository();
      when(
        () => repo.getConversations(
          limit: mt.any(named: 'limit'),
          fromId: mt.any(named: 'fromId'),
        ),
      ).thenAnswer((_) async => Success(incoming));

      final useCase = LoadMoreConversationsUseCase(repo);
      final result = await useCase(
        fromId: current.last.conversationId!,
        currentConversations: current,
      );

      expect(result.isSuccess, isTrue);
      result.onSuccess((data) {
        final currentIds = current.map((c) => c.conversationId).toSet();
        for (final c in data) {
          expect(
            currentIds.contains(c.conversationId),
            isFalse,
            reason:
                'Dedup returned ${c.conversationId} which is already in current',
          );
        }
      });
    });
  });

  // -------------------------------------------------------------------------
  // ConversationsBloc — public-API properties
  // Each run spins up a real bloc + async event dispatch, so we use a reduced
  // numRuns (30 instead of default 100) to keep CI wall-clock reasonable.
  // -------------------------------------------------------------------------

  group('ConversationsBloc — properties', () {
    final fast = ExploreConfig(numRuns: 30);

    Glados(indexedListGen(maxLength: 8), fast).test(
      'ToggleConversationSelection is self-inverse',
      (il) async {
        await _propSelectionToggleIdempotent(il);
      },
    );

    Glados(indexedListGen(maxLength: 8), fast).test(
      'RemoveConversation removes target and preserves remainder order',
      (il) async {
        await _propRemovePreservesRemainder(il);
      },
    );

    Glados(distinctConversationsGen(maxLength: 8), fast).test(
      'ClearConversationSelection always produces an empty selection set',
      (convs) async {
        await _propClearSelectionAlwaysEmpty(convs);
      },
    );

    // Sanity: _loadedWith helper is exercised at least once (keeps it used
    // and provides an early failure signal if the scaffolding regresses).
    test(
      'loaded-with helper produces ConversationsLoaded or ConversationsEmpty',
      () async {
        final state = await _loadedWith([FakeConversation('x1')]);
        expect(state.conversations.length, 1);
      },
    );
  });
}
