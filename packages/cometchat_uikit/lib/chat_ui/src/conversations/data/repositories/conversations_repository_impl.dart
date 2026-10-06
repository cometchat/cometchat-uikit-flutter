import 'dart:async';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import '../../../../../shared_ui/src/clean_architecture/core/result.dart';
import '../../domain/repositories/conversations_repository.dart';
import '../datasources/conversations_remote_datasource.dart';
import '../datasources/conversations_local_datasource.dart';

/// Implementation of ConversationsRepository
/// Coordinates between remote and local data sources
class ConversationsRepositoryImpl implements ConversationsRepository {
  final ConversationsRemoteDataSource remoteDataSource;
  final ConversationsLocalDataSource localDataSource;

  const ConversationsRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Result<List<Conversation>>> getConversations({
    int limit = 30,
    String? fromId,
    ConversationsRequestBuilder? requestBuilder,
  }) async {
    try {
      // Try to fetch from remote data source
      final conversations = await remoteDataSource.getConversations(
        limit: limit,
        fromId: fromId,
        requestBuilder: requestBuilder,
      );

      // Cache the results locally
      await localDataSource.cacheConversations(conversations);

      return Success(conversations);
    } on RemoteDataSourceException catch (e) {
      // If remote fetch fails, try to return cached data
      try {
        final cachedConversations = await localDataSource
            .getCachedConversations();
        return Success(cachedConversations);
      } on LocalDataSourceException {
        // Both remote and cache failed
        return Failure(
          message: 'Failed to load conversations: ${e.message}',
          code: e.code,
          exception: e.originalException,
        );
      }
    } catch (e) {
      return Failure(
        message:
            'Unexpected error while loading conversations: ${e.toString()}',
        exception: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Result<Conversation>> getConversationById(
    String conversationId,
  ) async {
    try {
      // Try to get from cache first
      final cachedConversation = await localDataSource.getCachedConversation(
        conversationId,
      );

      if (cachedConversation != null) {
        return Success(cachedConversation);
      }

      // If not in cache, fetch from remote
      final conversation = await remoteDataSource.getConversation(
        conversationId,
      );

      // Cache it
      await localDataSource.cacheConversation(conversation);

      return Success(conversation);
    } on RemoteDataSourceException catch (e) {
      return Failure(
        message: 'Failed to get conversation: ${e.message}',
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(
        message: 'Unexpected error while getting conversation: ${e.toString()}',
        exception: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Result<void>> deleteConversation(
    String conversationId, {
    String? conversationWith,
    String? conversationType,
  }) async {
    try {
      String withId;
      String type;

      if (conversationWith != null &&
          conversationWith.isNotEmpty &&
          conversationType != null &&
          conversationType.isNotEmpty) {
        // Preferred path: the delete target comes from the Conversation
        // OBJECT (peer User.uid / Group.guid + conversationType). The id
        // string is NOT a safe source for 1:1 conversations — see below.
        withId = conversationWith;
        type = conversationType;
      } else {
        // Fallback: derive the target from the conversation id string.
        //
        // Real formats:
        //   1:1   → "{uidA}_user_{uidB}"   (BOTH participants, sorted — the
        //           peer can be on either side of the "user" token)
        //   group → "group_{guid}"
        //
        // The previous implementation always took everything AFTER the type
        // token, which for 1:1 ids returns the LOGGED-IN user's own uid
        // whenever it sorts second → the SDK then deletes "conversation with
        // myself" → ERR_CONVERSATION_NOT_ACCESSIBLE. For the two-uid form we
        // now pick the side that is NOT the logged-in user.
        final parts = conversationId.split('_');
        if (parts.length < 2) {
          return const Failure(
            message: 'Invalid conversation ID format',
            code: 'INVALID_CONVERSATION_ID',
          );
        }

        // Find the type token ('user' or 'group') in the parts
        final typeIndex = parts.indexWhere((p) => p == 'user' || p == 'group');
        if (typeIndex != -1 && typeIndex < parts.length - 1) {
          type = parts[typeIndex];
          final after = parts.sublist(typeIndex + 1).join('_');
          final before = typeIndex > 0
              ? parts.sublist(0, typeIndex).join('_')
              : '';
          final beforeIsNumericPrefix =
              before.isNotEmpty && int.tryParse(before) != null;
          if (type == 'user' && before.isNotEmpty && !beforeIsNumericPrefix) {
            // "{uidA}_user_{uidB}" — choose the participant that is not us.
            final ownUid = (await CometChat.getLoggedInUser())?.uid;
            withId = (after == ownUid && before != ownUid) ? before : after;
          } else {
            // "{number}_user_{uid}" / "user_{uid}" / "group_{guid}" forms.
            withId = after;
          }
        } else {
          // Legacy format: first part is type, rest is ID
          type = parts[0];
          withId = parts.sublist(1).join('_');
        }

        if (withId.isEmpty) {
          return const Failure(
            message:
                'Invalid conversation ID: could not extract conversationWith',
            code: 'INVALID_CONVERSATION_ID',
          );
        }
      }

      // Delete from remote
      await remoteDataSource.deleteConversation(withId, type);

      // Remove from cache
      await localDataSource.removeCachedConversation(conversationId);

      return const Success(null);
    } on RemoteDataSourceException catch (e) {
      return Failure(
        message: 'Failed to delete conversation: ${e.message}',
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(
        message:
            'Unexpected error while deleting conversation: ${e.toString()}',
        exception: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Result<Conversation>> updateConversation(
    Conversation conversation,
  ) async {
    try {
      // Update in cache
      await localDataSource.cacheConversation(conversation);

      // Note: SDK doesn't have a direct update method
      // Updates typically happen through message operations
      // For now, we just update the cache

      return Success(conversation);
    } catch (e) {
      return Failure(
        message: 'Failed to update conversation: ${e.toString()}',
        exception: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Result<User?>> getLoggedInUser() async {
    try {
      final user = await CometChat.getLoggedInUser();
      return Success(user);
    } on CometChatException catch (e) {
      return Failure(
        message: 'Failed to get logged-in user: ${e.message}',
        code: e.code,
        exception: e,
      );
    } catch (e) {
      return Failure(
        message:
            'Unexpected error while getting logged-in user: ${e.toString()}',
        exception: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Result<void>> markAsDelivered(BaseMessage message) async {
    try {
      final completer = Completer<void>();

      await CometChat.markAsDelivered(
        message,
        onSuccess: (_) {
          completer.complete();
        },
        onError: (CometChatException exception) {
          completer.completeError(exception);
        },
      );

      await completer.future;
      return const Success(null);
    } on CometChatException catch (e) {
      return Failure(
        message: 'Failed to mark message as delivered: ${e.message}',
        code: e.code,
        exception: e,
      );
    } catch (e) {
      return Failure(
        message:
            'Unexpected error while marking message as delivered: ${e.toString()}',
        exception: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Result<Conversation>> getConversation({
    required String conversationWith,
    required String conversationType,
  }) async {
    try {
      final completer = Completer<Conversation>();

      await CometChat.getConversation(
        conversationWith,
        conversationType,
        onSuccess: (Conversation conversation) {
          completer.complete(conversation);
        },
        onError: (CometChatException exception) {
          completer.completeError(exception);
        },
      );

      final conversation = await completer.future;

      // Cache it
      await localDataSource.cacheConversation(conversation);

      return Success(conversation);
    } on CometChatException catch (e) {
      return Failure(
        message: 'Failed to get conversation: ${e.message}',
        code: e.code,
        exception: e,
      );
    } catch (e) {
      return Failure(
        message: 'Unexpected error while getting conversation: ${e.toString()}',
        exception: e is Exception ? e : null,
      );
    }
  }
}
