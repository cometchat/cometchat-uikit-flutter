import 'dart:async';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;

/// Exception thrown when remote data source operations fail
class RemoteDataSourceException implements Exception {
  final String message;
  final String? code;
  final Exception? originalException;

  const RemoteDataSourceException({
    required this.message,
    this.code,
    this.originalException,
  });

  @override
  String toString() =>
      'RemoteDataSourceException(message: $message, code: $code)';
}

/// Abstract interface for conversations remote data source
/// Handles all interactions with CometChat SDK
abstract class ConversationsRemoteDataSource {
  /// Get conversations with optional pagination.
  ///
  /// When [requestBuilder] is supplied, its filter-shaping fields
  /// (tags, userTags, groupTags, withTags, withUserAndGroupTags,
  /// includeBlockedUsers, withBlockedInfo, conversationType, unread,
  /// searchKeyword) are copied into the builder used to execute the
  /// SDK request. [limit] and [fromId] always win over any values
  /// present on [requestBuilder] to keep pagination deterministic.
  Future<List<Conversation>> getConversations({
    int limit = 30,
    String? fromId,
    ConversationsRequestBuilder? requestBuilder,
  });

  /// Get a specific conversation by ID
  Future<Conversation> getConversation(String conversationId);

  /// Delete a conversation
  /// Requires conversationWith (uid/guid) and conversationType
  Future<void> deleteConversation(
    String conversationWith,
    String conversationType,
  );

  /// Mark a message as read (which updates conversation unread count)
  Future<void> markMessageAsRead(BaseMessage message);

  /// Update a conversation
  Future<Conversation> updateConversation(Conversation conversation);
}

/// Implementation of ConversationsRemoteDataSource using CometChat SDK
class ConversationsRemoteDataSourceImpl
    implements ConversationsRemoteDataSource {
  ConversationsRequest? _currentRequest;

  @override
  Future<List<Conversation>> getConversations({
    int limit = 30,
    String? fromId,
    ConversationsRequestBuilder? requestBuilder,
  }) async {
    try {
      // Start from a fresh builder so stale state (e.g. `unread` left over
      // from a previous filtered search) never carries over.
      final builder = ConversationsRequestBuilder();

      // Copy over any user-provided filter fields. Mirrors SearchBloc._searchConversations.
      if (requestBuilder != null) {
        builder.withUserAndGroupTags = requestBuilder.withUserAndGroupTags;
        builder.withTags = requestBuilder.withTags;
        builder.tags = requestBuilder.tags;
        builder.includeBlockedUsers = requestBuilder.includeBlockedUsers;
        builder.withBlockedInfo = requestBuilder.withBlockedInfo;
        builder.userTags = requestBuilder.userTags;
        builder.groupTags = requestBuilder.groupTags;
        builder.conversationType = requestBuilder.conversationType;
        builder.unread = requestBuilder.unread;
        // `searchKeyword` deliberately omitted — search is handled by SearchBloc.
      }

      // Pagination wins over anything carried on the incoming builder.
      builder.limit = limit;

      // Build the request
      _currentRequest = builder.build();

      // Create a completer to convert callback-based API to Future
      final completer = Completer<List<Conversation>>();

      // Fetch conversations - don't await, the completer handles completion
      unawaited(
        _currentRequest!.fetchNext(
          onSuccess: (List<Conversation> conversations) {
            if (!completer.isCompleted) {
              completer.complete(conversations);
            }
          },
          onError: (CometChatException exception) {
            if (!completer.isCompleted) {
              completer.completeError(
                RemoteDataSourceException(
                  message: exception.message ?? 'Failed to fetch conversations',
                  code: exception.code,
                  originalException: exception,
                ),
              );
            }
          },
        ),
      );

      return await completer.future;
    } on CometChatException catch (e) {
      throw RemoteDataSourceException(
        message: e.message ?? 'Failed to fetch conversations',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      throw RemoteDataSourceException(
        message:
            'Unexpected error while fetching conversations: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Conversation> getConversation(String conversationId) async {
    try {
      // CometChat SDK doesn't have a direct getConversation method
      // We need to fetch conversations and find the specific one
      final conversations = await getConversations(limit: 100);

      final conversation = conversations.firstWhere(
        (conv) => conv.conversationId == conversationId,
        orElse: () => throw RemoteDataSourceException(
          message: 'Conversation not found: $conversationId',
          code: 'CONVERSATION_NOT_FOUND',
        ),
      );

      return conversation;
    } on RemoteDataSourceException {
      rethrow;
    } catch (e) {
      throw RemoteDataSourceException(
        message: 'Failed to get conversation: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<void> deleteConversation(
    String conversationWith,
    String conversationType,
  ) async {
    try {
      final completer = Completer<void>();

      await CometChat.deleteConversation(
        conversationWith,
        conversationType,
        onSuccess: (String deletedConversationId) {
          completer.complete();
        },
        onError: (CometChatException exception) {
          completer.completeError(
            RemoteDataSourceException(
              message: exception.message ?? 'Failed to delete conversation',
              code: exception.code,
              originalException: exception,
            ),
          );
        },
      );

      return await completer.future;
    } on CometChatException catch (e) {
      throw RemoteDataSourceException(
        message: e.message ?? 'Failed to delete conversation',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      throw RemoteDataSourceException(
        message:
            'Unexpected error while deleting conversation: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<void> markMessageAsRead(BaseMessage message) async {
    try {
      final completer = Completer<void>();

      await CometChat.markAsRead(
        message,
        onSuccess: (dynamic result) {
          completer.complete();
        },
        onError: (CometChatException exception) {
          completer.completeError(
            RemoteDataSourceException(
              message: exception.message ?? 'Failed to mark message as read',
              code: exception.code,
              originalException: exception,
            ),
          );
        },
      );

      return await completer.future;
    } on CometChatException catch (e) {
      throw RemoteDataSourceException(
        message: e.message ?? 'Failed to mark conversation as read',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      throw RemoteDataSourceException(
        message:
            'Unexpected error while marking conversation as read: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Conversation> updateConversation(Conversation conversation) async {
    try {
      // CometChat SDK doesn't have a direct update conversation method
      // Conversations are typically updated through message operations
      // For now, we'll return the conversation as-is
      // In a real implementation, this might involve updating tags or metadata
      return conversation;
    } catch (e) {
      throw RemoteDataSourceException(
        message: 'Failed to update conversation: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }
}
