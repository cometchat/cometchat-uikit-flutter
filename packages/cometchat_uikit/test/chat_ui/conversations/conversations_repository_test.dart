import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/conversations/data/datasources/conversations_remote_datasource.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/data/datasources/conversations_local_datasource.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/conversations/data/repositories/conversations_repository_impl.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockRemoteDataSource extends Mock
    implements ConversationsRemoteDataSource {}

class MockLocalDataSource extends Mock
    implements ConversationsLocalDataSource {}

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
}

class FakeBaseMessage extends Fake implements BaseMessage {
  @override
  int get id => 1;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockRemoteDataSource remote;
  late MockLocalDataSource local;
  late ConversationsRepositoryImpl repo;

  setUpAll(() {
    registerFallbackValue(FakeConversation(''));
    registerFallbackValue(FakeBaseMessage());
  });

  setUp(() {
    remote = MockRemoteDataSource();
    local = MockLocalDataSource();
    repo = ConversationsRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: local,
    );
  });

  // =========================================================================
  // getConversations
  // =========================================================================

  group('getConversations', () {
    test('returns success with conversations from remote', () async {
      final conversations = [
        FakeConversation('conv_1'),
        FakeConversation('conv_2'),
      ];
      when(
        () => remote.getConversations(limit: any(named: 'limit')),
      ).thenAnswer((_) async => conversations);
      when(() => local.cacheConversations(any())).thenAnswer((_) async {});

      final result = await repo.getConversations();

      expect(result.isSuccess, isTrue);
      result.onSuccess((data) => expect(data.length, 2));
    });

    test('caches conversations after successful remote fetch', () async {
      final conversations = [FakeConversation('conv_1')];
      when(
        () => remote.getConversations(limit: any(named: 'limit')),
      ).thenAnswer((_) async => conversations);
      when(() => local.cacheConversations(any())).thenAnswer((_) async {});

      await repo.getConversations();

      verify(() => local.cacheConversations(conversations)).called(1);
    });

    test('falls back to cache when remote fails', () async {
      final cached = [FakeConversation('cached_conv')];
      when(
        () => remote.getConversations(limit: any(named: 'limit')),
      ).thenThrow(const RemoteDataSourceException(message: 'Network error'));
      when(
        () => local.getCachedConversations(),
      ).thenAnswer((_) async => cached);

      final result = await repo.getConversations();

      expect(result.isSuccess, isTrue);
      result.onSuccess((data) => expect(data.length, 1));
    });

    test('returns failure when both remote and cache fail', () async {
      when(
        () => remote.getConversations(limit: any(named: 'limit')),
      ).thenThrow(const RemoteDataSourceException(message: 'Network error'));
      when(
        () => local.getCachedConversations(),
      ).thenThrow(const LocalDataSourceException(message: 'Cache miss'));

      final result = await repo.getConversations();

      expect(result.isFailure, isTrue);
    });
  });

  // =========================================================================
  // deleteConversation
  // =========================================================================

  group('deleteConversation', () {
    test('returns failure for invalid conversation ID format', () async {
      // ID without underscore separator
      final result = await repo.deleteConversation('invalidformat');
      expect(result.isFailure, isTrue);
      result.onFailure((f) => expect(f.code, 'INVALID_CONVERSATION_ID'));
    });

    test('parses user conversation ID and calls remote', () async {
      when(
        () => remote.deleteConversation(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => local.removeCachedConversation(any()),
      ).thenAnswer((_) async {});

      final result = await repo.deleteConversation('user_uid123');

      expect(result.isSuccess, isTrue);
      verify(() => remote.deleteConversation('uid123', 'user')).called(1);
    });

    test('parses group conversation ID and calls remote', () async {
      when(
        () => remote.deleteConversation(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => local.removeCachedConversation(any()),
      ).thenAnswer((_) async {});

      final result = await repo.deleteConversation('group_guid456');

      expect(result.isSuccess, isTrue);
      verify(() => remote.deleteConversation('guid456', 'group')).called(1);
    });

    test('parses SDK-format conversation ID with numeric prefix', () async {
      when(
        () => remote.deleteConversation(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => local.removeCachedConversation(any()),
      ).thenAnswer((_) async {});

      // SDK returns IDs like "1_user_cometchat-uid-1"
      final result = await repo.deleteConversation('1_user_cometchat-uid-1');

      expect(result.isSuccess, isTrue);
      verify(
        () => remote.deleteConversation('cometchat-uid-1', 'user'),
      ).called(1);
    });

    test(
      'parses SDK-format group conversation ID with numeric prefix',
      () async {
        when(
          () => remote.deleteConversation(any(), any()),
        ).thenAnswer((_) async {});
        when(
          () => local.removeCachedConversation(any()),
        ).thenAnswer((_) async {});

        // SDK returns IDs like "2_group_my-group-guid"
        final result = await repo.deleteConversation('2_group_my-group-guid');

        expect(result.isSuccess, isTrue);
        verify(
          () => remote.deleteConversation('my-group-guid', 'group'),
        ).called(1);
      },
    );

    test('removes from cache after successful delete', () async {
      when(
        () => remote.deleteConversation(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => local.removeCachedConversation(any()),
      ).thenAnswer((_) async {});

      await repo.deleteConversation('user_uid123');

      verify(() => local.removeCachedConversation('user_uid123')).called(1);
    });

    test('returns failure when remote delete throws', () async {
      when(() => remote.deleteConversation(any(), any())).thenThrow(
        const RemoteDataSourceException(
          message: 'Delete failed',
          code: 'DEL_ERR',
        ),
      );

      final result = await repo.deleteConversation('user_uid123');

      expect(result.isFailure, isTrue);
    });
  });

  // =========================================================================
  // updateConversation
  // =========================================================================

  group('updateConversation', () {
    test('returns success and caches updated conversation', () async {
      final conv = FakeConversation('conv_1');
      when(() => local.cacheConversation(any())).thenAnswer((_) async {});

      final result = await repo.updateConversation(conv);

      expect(result.isSuccess, isTrue);
      verify(() => local.cacheConversation(conv)).called(1);
    });
  });

  // =========================================================================
  // getConversationById
  // =========================================================================

  group('getConversationById', () {
    test('returns cached conversation when present', () async {
      final cached = FakeConversation('conv_1');
      when(
        () => local.getCachedConversation('conv_1'),
      ).thenAnswer((_) async => cached);

      final result = await repo.getConversationById('conv_1');

      expect(result.isSuccess, isTrue);
      verifyNever(() => remote.getConversation(any()));
    });

    test('falls back to remote when cache miss', () async {
      final remoteConv = FakeConversation('conv_1');
      when(
        () => local.getCachedConversation('conv_1'),
      ).thenAnswer((_) async => null);
      when(
        () => remote.getConversation('conv_1'),
      ).thenAnswer((_) async => remoteConv);
      when(() => local.cacheConversation(any())).thenAnswer((_) async {});

      final result = await repo.getConversationById('conv_1');

      expect(result.isSuccess, isTrue);
      verify(() => remote.getConversation('conv_1')).called(1);
      verify(() => local.cacheConversation(remoteConv)).called(1);
    });

    test('returns failure when remote throws', () async {
      when(
        () => local.getCachedConversation(any()),
      ).thenAnswer((_) async => null);
      when(() => remote.getConversation(any())).thenThrow(
        const RemoteDataSourceException(message: 'Not found', code: 'NF'),
      );

      final result = await repo.getConversationById('conv_1');

      expect(result.isFailure, isTrue);
    });
  });
}
