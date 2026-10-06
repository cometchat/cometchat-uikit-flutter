import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/repositories/conversations_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_conversations_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/load_more_conversations_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/delete_conversation_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/get_conversation_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/domain/usecases/mark_as_delivered_usecase.dart';
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
  final String? _id;
  FakeConversation([this._id]);

  @override
  String? get conversationId => _id;
}

class FakeUser extends Fake implements User {
  @override
  String get uid => 'fake_user';
}

class FakeBaseMessage extends Fake implements BaseMessage {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeConversation());
    registerFallbackValue(FakeBaseMessage());
  });

  // =========================================================================
  // GetConversationsUseCase
  // =========================================================================

  group('GetConversationsUseCase', () {
    late MockConversationsRepository repo;
    late GetConversationsUseCase useCase;

    setUp(() {
      repo = MockConversationsRepository();
      useCase = GetConversationsUseCase(repo);
    });

    test('returns failure when limit is 0', () async {
      final result = await useCase(limit: 0);
      expect(result.isFailure, isTrue);
      result.onFailure((f) => expect(f.code, 'INVALID_LIMIT'));
    });

    test('returns failure when limit is negative', () async {
      final result = await useCase(limit: -5);
      expect(result.isFailure, isTrue);
    });

    test('returns failure when limit exceeds 100', () async {
      final result = await useCase(limit: 101);
      expect(result.isFailure, isTrue);
      result.onFailure((f) => expect(f.code, 'LIMIT_TOO_HIGH'));
    });

    test('delegates to repository with default limit', () async {
      when(
        () => repo.getConversations(limit: any(named: 'limit')),
      ).thenAnswer((_) async => const Success([]));

      final result = await useCase();
      expect(result.isSuccess, isTrue);
      verify(() => repo.getConversations(limit: 30)).called(1);
    });

    test('passes custom limit to repository', () async {
      when(
        () => repo.getConversations(limit: any(named: 'limit')),
      ).thenAnswer((_) async => const Success([]));

      await useCase(limit: 50);
      verify(() => repo.getConversations(limit: 50)).called(1);
    });

    test('passes fromId to repository', () async {
      when(
        () => repo.getConversations(
          limit: any(named: 'limit'),
          fromId: any(named: 'fromId'),
        ),
      ).thenAnswer((_) async => const Success([]));

      await useCase(limit: 10, fromId: 'conv_123');
      verify(
        () => repo.getConversations(limit: 10, fromId: 'conv_123'),
      ).called(1);
    });

    test('propagates repository failure', () async {
      when(() => repo.getConversations(limit: any(named: 'limit'))).thenAnswer(
        (_) async => const Failure(message: 'Network error', code: 'NET_ERR'),
      );

      final result = await useCase();
      expect(result.isFailure, isTrue);
      result.onFailure((f) => expect(f.message, 'Network error'));
    });

    test('accepts limit of exactly 100', () async {
      when(
        () => repo.getConversations(limit: any(named: 'limit')),
      ).thenAnswer((_) async => const Success([]));

      final result = await useCase(limit: 100);
      expect(result.isSuccess, isTrue);
    });
  });

  // =========================================================================
  // DeleteConversationUseCase
  // =========================================================================

  group('DeleteConversationUseCase', () {
    late MockConversationsRepository repo;
    late DeleteConversationUseCase useCase;

    setUp(() {
      repo = MockConversationsRepository();
      useCase = DeleteConversationUseCase(repo);
    });

    test('returns failure for empty conversation ID', () async {
      final result = await useCase('');
      expect(result.isFailure, isTrue);
      result.onFailure((f) => expect(f.code, 'INVALID_CONVERSATION_ID'));
    });

    test('delegates to repository with valid ID', () async {
      when(
        () => repo.deleteConversation(
          any(),
          conversationWith: any(named: 'conversationWith'),
          conversationType: any(named: 'conversationType'),
        ),
      ).thenAnswer((_) async => const Success(null));

      final result = await useCase('user_abc');
      expect(result.isSuccess, isTrue);
      verify(
        () => repo.deleteConversation(
          'user_abc',
          conversationWith: any(named: 'conversationWith'),
          conversationType: any(named: 'conversationType'),
        ),
      ).called(1);
    });

    test('propagates repository failure', () async {
      when(
        () => repo.deleteConversation(
          any(),
          conversationWith: any(named: 'conversationWith'),
          conversationType: any(named: 'conversationType'),
        ),
      ).thenAnswer(
        (_) async => const Failure(message: 'Delete failed', code: 'DEL_ERR'),
      );

      final result = await useCase('user_abc');
      expect(result.isFailure, isTrue);
      result.onFailure((f) => expect(f.code, 'DEL_ERR'));
    });

    test('does not call repository for empty ID', () async {
      await useCase('');
      verifyNever(
        () => repo.deleteConversation(
          any(),
          conversationWith: any(named: 'conversationWith'),
          conversationType: any(named: 'conversationType'),
        ),
      );
    });
  });

  // =========================================================================
  // LoadMoreConversationsUseCase
  // =========================================================================

  group('LoadMoreConversationsUseCase', () {
    late MockConversationsRepository repo;
    late LoadMoreConversationsUseCase useCase;

    setUp(() {
      repo = MockConversationsRepository();
      useCase = LoadMoreConversationsUseCase(repo);
    });

    test('returns failure when limit is 0', () async {
      final result = await useCase(limit: 0, fromId: 'conv_1');
      expect(result.isFailure, isTrue);
      result.onFailure((f) => expect(f.code, 'INVALID_LIMIT'));
      verifyNever(
        () => repo.getConversations(
          limit: any(named: 'limit'),
          fromId: any(named: 'fromId'),
        ),
      );
    });

    test('returns failure when limit is negative', () async {
      final result = await useCase(limit: -1, fromId: 'conv_1');
      expect(result.isFailure, isTrue);
    });

    test('returns failure when limit exceeds 100', () async {
      final result = await useCase(limit: 500, fromId: 'conv_1');
      expect(result.isFailure, isTrue);
      result.onFailure((f) => expect(f.code, 'LIMIT_TOO_HIGH'));
    });

    test('returns failure when fromId is empty', () async {
      final result = await useCase(fromId: '');
      expect(result.isFailure, isTrue);
      result.onFailure((f) => expect(f.code, 'MISSING_FROM_ID'));
    });

    test('delegates to repository with fromId and default limit', () async {
      when(
        () => repo.getConversations(
          limit: any(named: 'limit'),
          fromId: any(named: 'fromId'),
        ),
      ).thenAnswer((_) async => const Success([]));

      final result = await useCase(fromId: 'conv_42');

      expect(result.isSuccess, isTrue);
      verify(
        () => repo.getConversations(limit: 30, fromId: 'conv_42'),
      ).called(1);
    });

    test('deduplicates new conversations against current list', () async {
      final List<Conversation> current = [
        FakeConversation('conv_1'),
        FakeConversation('conv_2'),
      ];
      final List<Conversation> incoming = [
        FakeConversation('conv_2'), // duplicate
        FakeConversation('conv_3'), // new
      ];
      when(
        () => repo.getConversations(
          limit: any(named: 'limit'),
          fromId: any(named: 'fromId'),
        ),
      ).thenAnswer((_) async => Success(incoming));

      final result = await useCase(
        fromId: 'conv_2',
        currentConversations: current,
      );

      expect(result.isSuccess, isTrue);
      result.onSuccess((data) {
        expect(data.length, 1);
        expect(data.first.conversationId, 'conv_3');
      });
    });

    test('returns full new list when currentConversations is null', () async {
      final List<Conversation> incoming = [
        FakeConversation('conv_3'),
        FakeConversation('conv_4'),
      ];
      when(
        () => repo.getConversations(
          limit: any(named: 'limit'),
          fromId: any(named: 'fromId'),
        ),
      ).thenAnswer((_) async => Success(incoming));

      final result = await useCase(fromId: 'conv_2');

      expect(result.isSuccess, isTrue);
      result.onSuccess((data) => expect(data.length, 2));
    });

    test('propagates repository failure', () async {
      when(
        () => repo.getConversations(
          limit: any(named: 'limit'),
          fromId: any(named: 'fromId'),
        ),
      ).thenAnswer(
        (_) async => const Failure(message: 'Network error', code: 'NET_ERR'),
      );

      final result = await useCase(fromId: 'conv_1');
      expect(result.isFailure, isTrue);
    });
  });

  // =========================================================================
  // GetLoggedInUserUseCase
  // =========================================================================

  group('GetLoggedInUserUseCase', () {
    late MockConversationsRepository repo;
    late GetLoggedInUserUseCase useCase;

    setUp(() {
      repo = MockConversationsRepository();
      useCase = GetLoggedInUserUseCase(repo);
    });

    test('returns user from repository', () async {
      final user = FakeUser();
      when(() => repo.getLoggedInUser()).thenAnswer((_) async => Success(user));

      final result = await useCase();

      expect(result.isSuccess, isTrue);
      result.onSuccess((data) => expect(data, user));
    });

    test('returns success with null when no user is logged in', () async {
      when(
        () => repo.getLoggedInUser(),
      ).thenAnswer((_) async => const Success<User?>(null));

      final result = await useCase();

      expect(result.isSuccess, isTrue);
      result.onSuccess((data) => expect(data, isNull));
    });

    test('propagates repository failure', () async {
      when(
        () => repo.getLoggedInUser(),
      ).thenAnswer((_) async => const Failure(message: 'Not authenticated'));

      final result = await useCase();
      expect(result.isFailure, isTrue);
    });
  });

  // =========================================================================
  // GetConversationUseCase
  // =========================================================================

  group('GetConversationUseCase', () {
    late MockConversationsRepository repo;
    late GetConversationUseCase useCase;

    setUp(() {
      repo = MockConversationsRepository();
      useCase = GetConversationUseCase(repo);
    });

    test('returns failure for empty conversationWith', () async {
      final result = await useCase(
        conversationWith: '',
        conversationType: 'user',
      );
      expect(result.isFailure, isTrue);
      result.onFailure((f) => expect(f.code, 'INVALID_CONVERSATION_ID'));
    });

    test('returns failure for invalid conversationType', () async {
      final result = await useCase(
        conversationWith: 'uid1',
        conversationType: 'channel', // not 'user' or 'group'
      );
      expect(result.isFailure, isTrue);
      result.onFailure((f) => expect(f.code, 'INVALID_CONVERSATION_TYPE'));
    });

    test('accepts user conversation type', () async {
      when(
        () => repo.getConversation(
          conversationWith: any(named: 'conversationWith'),
          conversationType: any(named: 'conversationType'),
        ),
      ).thenAnswer((_) async => Success(FakeConversation('user_uid1')));

      final result = await useCase(
        conversationWith: 'uid1',
        conversationType: 'user',
      );
      expect(result.isSuccess, isTrue);
      verify(
        () => repo.getConversation(
          conversationWith: 'uid1',
          conversationType: 'user',
        ),
      ).called(1);
    });

    test('accepts group conversation type', () async {
      when(
        () => repo.getConversation(
          conversationWith: any(named: 'conversationWith'),
          conversationType: any(named: 'conversationType'),
        ),
      ).thenAnswer((_) async => Success(FakeConversation('group_guid1')));

      final result = await useCase(
        conversationWith: 'guid1',
        conversationType: 'group',
      );
      expect(result.isSuccess, isTrue);
    });

    test('propagates repository failure', () async {
      when(
        () => repo.getConversation(
          conversationWith: any(named: 'conversationWith'),
          conversationType: any(named: 'conversationType'),
        ),
      ).thenAnswer(
        (_) async => const Failure(message: 'Not found', code: 'NF'),
      );

      final result = await useCase(
        conversationWith: 'uid1',
        conversationType: 'user',
      );
      expect(result.isFailure, isTrue);
    });
  });

  // =========================================================================
  // MarkAsDeliveredUseCase
  // =========================================================================

  group('MarkAsDeliveredUseCase', () {
    late MockConversationsRepository repo;
    late MarkAsDeliveredUseCase useCase;

    setUp(() {
      repo = MockConversationsRepository();
      useCase = MarkAsDeliveredUseCase(repo);
    });

    test('returns failure for zero message ID', () async {
      final result = await useCase(FakeBaseMessageWithId(0));
      expect(result.isFailure, isTrue);
      result.onFailure((f) => expect(f.code, 'INVALID_MESSAGE_ID'));
      verifyNever(() => repo.markAsDelivered(any()));
    });

    test('delegates to repository for valid message', () async {
      when(
        () => repo.markAsDelivered(any()),
      ).thenAnswer((_) async => const Success(null));

      final result = await useCase(FakeBaseMessageWithId(42));

      expect(result.isSuccess, isTrue);
      verify(() => repo.markAsDelivered(any())).called(1);
    });

    test('propagates repository failure', () async {
      when(
        () => repo.markAsDelivered(any()),
      ).thenAnswer((_) async => const Failure(message: 'Network error'));

      final result = await useCase(FakeBaseMessageWithId(42));
      expect(result.isFailure, isTrue);
    });
  });
}

/// Fake with configurable id for MarkAsDelivered tests
class FakeBaseMessageWithId extends Fake implements BaseMessage {
  final int _id;
  FakeBaseMessageWithId(this._id);

  @override
  int get id => _id;
}
