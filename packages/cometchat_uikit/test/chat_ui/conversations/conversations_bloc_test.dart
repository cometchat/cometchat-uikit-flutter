import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/bloc/conversations_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_conversations_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/delete_conversation_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_conversation_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/mark_as_delivered_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/load_more_conversations_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/repositories/conversations_repository.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockConversationsRepository extends Mock
    implements ConversationsRepository {}

class FakeConversation extends Fake implements Conversation {
  // Pin Conversation fields — read by the trailing view's pin glyph.
  @override
  DateTime? get pinnedAt => null;

  @override
  String? get pinnedBy => null;
  final String _id;
  FakeConversation(this._id);

  @override
  String? get conversationId => _id;

  // Delete-target resolution (ENG fix for ERR_CONVERSATION_NOT_ACCESSIBLE):
  // the bloc reads conversationWith/conversationType off the object.
  @override
  AppEntity get conversationWith => FakeUser();

  @override
  String get conversationType => 'user';
}

class FakeUser extends Fake implements User {
  @override
  String get uid => 'test_user';
}

class FakeBaseMessage extends Fake implements BaseMessage {
  @override
  int get id => 1;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ConversationsBloc _makeBloc(MockConversationsRepository repo) {
  return ConversationsBloc(
    getConversationsUseCase: GetConversationsUseCase(repo),
    loadMoreConversationsUseCase: LoadMoreConversationsUseCase(repo),
    deleteConversationUseCase: DeleteConversationUseCase(repo),
    getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
    getConversationUseCase: GetConversationUseCase(repo),
    markAsDeliveredUseCase: MarkAsDeliveredUseCase(repo),
    disableSDKListeners:
        true, // prevent real SDK listener registration in tests
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeConversation(''));
    registerFallbackValue(FakeUser());
    registerFallbackValue(FakeBaseMessage());
  });

  group('ConversationsBloc', () {
    late MockConversationsRepository repo;

    setUp(() {
      repo = MockConversationsRepository();
      // Default stubs
      when(
        () => repo.getLoggedInUser(),
      ).thenAnswer((_) async => Success(FakeUser()));
      when(
        () => repo.getConversations(limit: any(named: 'limit')),
      ).thenAnswer((_) async => const Success([]));
    });

    // -----------------------------------------------------------------------
    // Initial state
    // -----------------------------------------------------------------------

    test('initial state is ConversationsInitial', () {
      final bloc = _makeBloc(repo);
      expect(bloc.state, isA<ConversationsInitial>());
      bloc.close();
    });

    // -----------------------------------------------------------------------
    // LoadConversations
    // -----------------------------------------------------------------------

    blocTest<ConversationsBloc, ConversationsState>(
      'emits [Loading, Empty] when no conversations returned',
      build: () {
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => const Success([]));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadConversations()),
      expect: () => [isA<ConversationsLoading>(), isA<ConversationsEmpty>()],
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'emits [Loading, Loaded] when conversations returned',
      build: () {
        final convs = [FakeConversation('conv_1'), FakeConversation('conv_2')];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadConversations()),
      expect: () => [isA<ConversationsLoading>(), isA<ConversationsLoaded>()],
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.conversations.length, 2);
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'emits [Loading, Error] when repository fails',
      build: () {
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer(
          (_) async => const Failure(message: 'Network error', code: 'NET_ERR'),
        );
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadConversations()),
      expect: () => [isA<ConversationsLoading>(), isA<ConversationsError>()],
    );

    // -----------------------------------------------------------------------
    // DeleteConversation
    // -----------------------------------------------------------------------

    blocTest<ConversationsBloc, ConversationsState>(
      'removes conversation from loaded list on delete',
      build: () {
        final convs = [
          FakeConversation('user_uid1'),
          FakeConversation('user_uid2'),
        ];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        when(
          () => repo.deleteConversation(
            any(),
            conversationWith: any(named: 'conversationWith'),
            conversationType: any(named: 'conversationType'),
          ),
        ).thenAnswer((_) async => const Success(null));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const DeleteConversation('user_uid1'));
      },
      expect: () => [
        isA<ConversationsLoading>(),
        isA<ConversationsLoaded>(),
        isA<ConversationsLoaded>(),
      ],
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.conversations.length, 1);
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'DeleteConversation calls repository with correct conversation ID',
      build: () {
        final convs = [
          FakeConversation('user_abc'),
          FakeConversation('user_xyz'),
        ];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        when(
          () => repo.deleteConversation(
            any(),
            conversationWith: any(named: 'conversationWith'),
            conversationType: any(named: 'conversationType'),
          ),
        ).thenAnswer((_) async => const Success(null));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const DeleteConversation('user_abc'));
        await Future.delayed(const Duration(milliseconds: 50));
      },
      verify: (bloc) {
        // The SDK delete target must come from the Conversation OBJECT
        // (peer uid + type), not from parsing the conversation id — parsing
        // picks the logged-in user's own uid whenever it sorts second in
        // "{uidA}_user_{uidB}" (ERR_CONVERSATION_NOT_ACCESSIBLE).
        verify(
          () => repo.deleteConversation(
            'user_abc',
            conversationWith: 'test_user',
            conversationType: 'user',
          ),
        ).called(1);
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'DeleteConversation keeps conversation in list when SDK delete fails',
      build: () {
        final convs = [
          FakeConversation('user_keep'),
          FakeConversation('user_other'),
        ];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        when(
          () => repo.deleteConversation(
            any(),
            conversationWith: any(named: 'conversationWith'),
            conversationType: any(named: 'conversationType'),
          ),
        ).thenAnswer((_) async => const Failure(message: 'Network error'));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const DeleteConversation('user_keep'));
        await Future.delayed(const Duration(milliseconds: 50));
      },
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        // Conversation should still be in the list since delete failed
        final ids = state.conversations.map((c) => c.conversationId).toList();
        expect(ids, contains('user_keep'));
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'DeleteConversation on last remaining conversation transitions to Empty',
      build: () {
        final convs = [FakeConversation('only_one')];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        when(
          () => repo.deleteConversation(
            any(),
            conversationWith: any(named: 'conversationWith'),
            conversationType: any(named: 'conversationType'),
          ),
        ).thenAnswer((_) async => const Success(null));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const DeleteConversation('only_one'));
        await Future.delayed(const Duration(milliseconds: 50));
      },
      verify: (bloc) {
        final s = bloc.state;
        if (s is ConversationsLoaded) {
          expect(s.conversations, isEmpty);
        } else {
          expect(s, isA<ConversationsEmpty>());
        }
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'DeleteConversation with non-existent ID is a no-op',
      build: () {
        final convs = [
          FakeConversation('existing_1'),
          FakeConversation('existing_2'),
        ];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        when(
          () => repo.deleteConversation(
            any(),
            conversationWith: any(named: 'conversationWith'),
            conversationType: any(named: 'conversationType'),
          ),
        ).thenAnswer((_) async => const Success(null));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const DeleteConversation('non_existent_id'));
        await Future.delayed(const Duration(milliseconds: 50));
      },
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.conversations.length, 2);
      },
    );

    // -----------------------------------------------------------------------
    // SetActiveConversation
    // -----------------------------------------------------------------------

    blocTest<ConversationsBloc, ConversationsState>(
      'updates activeConversationId in loaded state',
      build: () {
        final convs = [FakeConversation('conv_1')];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const SetActiveConversation('conv_1'));
      },
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.activeConversationId, 'conv_1');
      },
    );

    // -----------------------------------------------------------------------
    // RemoveConversation (no SDK call)
    // -----------------------------------------------------------------------

    blocTest<ConversationsBloc, ConversationsState>(
      'removes conversation without calling SDK delete',
      build: () {
        final convs = [FakeConversation('conv_1'), FakeConversation('conv_2')];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const RemoveConversation('conv_1'));
      },
      verify: (bloc) {
        verifyNever(
          () => repo.deleteConversation(
            any(),
            conversationWith: any(named: 'conversationWith'),
            conversationType: any(named: 'conversationType'),
          ),
        );
        final state = bloc.state as ConversationsLoaded;
        expect(state.conversations.length, 1);
      },
    );

    // -----------------------------------------------------------------------
    // Regression: removing the only conversation transitions to Empty state.
    // Discovered by PBT (ENG-34976) — single-element IndexedList edge case.
    // -----------------------------------------------------------------------

    blocTest<ConversationsBloc, ConversationsState>(
      'RemoveConversation on last remaining conversation transitions to Empty',
      build: () {
        final convs = [FakeConversation('only_conv')];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const RemoveConversation('only_conv'));
        await Future.delayed(const Duration(milliseconds: 20));
      },
      verify: (bloc) {
        // Either Empty, or Loaded with 0 items — both are acceptable, but the
        // property test caught that it is not necessarily Loaded.
        final s = bloc.state;
        if (s is ConversationsLoaded) {
          expect(s.conversations, isEmpty);
        } else {
          expect(s, isA<ConversationsEmpty>());
        }
      },
    );

    // -----------------------------------------------------------------------
    // LoadMoreConversations
    // -----------------------------------------------------------------------
    //
    // Positive append-on-load-more is exercised via the LoadMoreConversationsUseCase
    // unit tests (see conversations_use_cases_test.dart). Here we only verify the
    // bloc's guard conditions — that load-more is a no-op when the state cannot
    // accept more.

    blocTest<ConversationsBloc, ConversationsState>(
      'ignores LoadMoreConversations when not loaded',
      build: () => _makeBloc(repo),
      act: (bloc) => bloc.add(const LoadMoreConversations()),
      expect: () => <ConversationsState>[],
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'ignores LoadMoreConversations when hasMore is false',
      build: () {
        final initial = [FakeConversation('c1')];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(initial));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const LoadMoreConversations());
        await Future.delayed(const Duration(milliseconds: 50));
      },
      verify: (bloc) {
        // paged repo call (with fromId) should never have been issued —
        // ignoring the initial non-paged LoadConversations call
        verifyNever(
          () => repo.getConversations(
            limit: any(named: 'limit'),
            fromId: any(named: 'fromId', that: isNotNull),
          ),
        );
        final state = bloc.state as ConversationsLoaded;
        expect(state.conversations.length, 1);
      },
    );

    // -----------------------------------------------------------------------
    // UpdateConversation
    // -----------------------------------------------------------------------

    blocTest<ConversationsBloc, ConversationsState>(
      'updates existing conversation in place',
      build: () {
        final convs = [FakeConversation('c1'), FakeConversation('c2')];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(
          UpdateConversation(
            conversationId: 'c1',
            updatedConversation: FakeConversation('c1'),
          ),
        );
      },
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.conversations.length, 2);
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'adds conversation when UpdateConversation target does not exist',
      build: () {
        final convs = [FakeConversation('c1')];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(
          UpdateConversation(
            conversationId: 'c_new',
            updatedConversation: FakeConversation('c_new'),
          ),
        );
      },
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.conversations.length, 2);
      },
    );

    // -----------------------------------------------------------------------
    // Selection events
    // -----------------------------------------------------------------------

    blocTest<ConversationsBloc, ConversationsState>(
      'toggles selection on/off and clears selection',
      build: () {
        final convs = [FakeConversation('c1'), FakeConversation('c2')];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const ToggleConversationSelection('c1'));
        bloc.add(const ToggleConversationSelection('c2'));
        bloc.add(const ToggleConversationSelection('c1')); // toggle off
      },
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.selectedConversations, {'c2'});
      },
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'ClearConversationSelection empties the selection set',
      build: () {
        final convs = [FakeConversation('c1')];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const ToggleConversationSelection('c1'));
        bloc.add(const ClearConversationSelection());
      },
      verify: (bloc) {
        final state = bloc.state as ConversationsLoaded;
        expect(state.selectedConversations, isEmpty);
      },
    );

    // -----------------------------------------------------------------------
    // RefreshConversations — silently reloads (no loading state)
    // -----------------------------------------------------------------------

    blocTest<ConversationsBloc, ConversationsState>(
      'RefreshConversations reloads without emitting Loading',
      build: () {
        final convs = [FakeConversation('c1')];
        when(
          () => repo.getConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) async => Success(convs));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadConversations());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const RefreshConversations());
        await Future.delayed(const Duration(milliseconds: 50));
      },
      verify: (bloc) {
        expect(bloc.state, isA<ConversationsLoaded>());
      },
    );

    // -----------------------------------------------------------------------
    // Typing notifiers (non-BLoC state, but exposed by the bloc)
    // -----------------------------------------------------------------------

    test('getTypingNotifier returns the same notifier for the same id', () {
      final bloc = _makeBloc(repo);
      final a = bloc.getTypingNotifier('c1');
      final b = bloc.getTypingNotifier('c1');
      expect(identical(a, b), isTrue);
      expect(a.value, isEmpty);
      bloc.close();
    });

    test('getTypingIndicators returns empty list for unknown id', () {
      final bloc = _makeBloc(repo);
      expect(bloc.getTypingIndicators('does_not_exist'), isEmpty);
      bloc.close();
    });
  });
}
