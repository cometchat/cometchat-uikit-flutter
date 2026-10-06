import 'dart:async';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;

/// Exception thrown when remote data source operations fail.
class MessageListRemoteDataSourceException implements Exception {
  final String message;
  final String? code;
  final Exception? originalException;

  const MessageListRemoteDataSourceException({
    required this.message,
    this.code,
    this.originalException,
  });

  @override
  String toString() =>
      'MessageListRemoteDataSourceException(message: $message, code: $code)';
}

/// Result class containing both the MessagesRequest and fetched messages.
class GetMessagesResult {
  final MessagesRequest request;
  final List<BaseMessage> messages;

  const GetMessagesResult({required this.request, required this.messages});
}

/// Abstract interface for message list remote data source.
abstract class MessageListRemoteDataSource {
  Future<GetMessagesResult> getMessages({
    required String conversationWith,
    required String conversationType,
    int limit = 30,
    int? parentMessageId,
    List<String>? types,
    List<String>? categories,
    bool hideReplies = true,
    bool withParent = true,
  });

  Future<List<BaseMessage>> fetchPreviousMessages({
    required MessagesRequest request,
  });

  Future<List<BaseMessage>> fetchNextMessages({
    required MessagesRequest request,
  });

  Future<void> markAsRead(BaseMessage message);
  Future<void> markAsDelivered(BaseMessage message);
  Future<User?> getLoggedInUser();

  Future<Conversation> getConversation({
    required String conversationWith,
    required String conversationType,
  });

  Future<Conversation> markMessageAsUnread(BaseMessage message);
}

/// Implementation of [MessageListRemoteDataSource] using CometChat SDK.
class MessageListRemoteDataSourceImpl implements MessageListRemoteDataSource {
  @override
  Future<GetMessagesResult> getMessages({
    required String conversationWith,
    required String conversationType,
    int limit = 30,
    int? parentMessageId,
    List<String>? types,
    List<String>? categories,
    bool hideReplies = true,
    bool withParent = true,
  }) async {
    try {
      final requestBuilder = MessagesRequestBuilder()..limit = limit;

      if (conversationType == 'user') {
        requestBuilder.uid = conversationWith;
      } else {
        requestBuilder.guid = conversationWith;
      }

      if (parentMessageId != null) {
        requestBuilder.parentMessageId = parentMessageId;
        requestBuilder.withParent = withParent;
      }

      if (types != null && types.isNotEmpty) {
        requestBuilder.types = types;
      }

      if (categories != null && categories.isNotEmpty) {
        requestBuilder.categories = categories;
      }

      requestBuilder.hideReplies = hideReplies;

      final request = requestBuilder.build();
      final messages = await _fetchPrevious(request);

      return GetMessagesResult(request: request, messages: messages);
    } on CometChatException catch (e) {
      throw MessageListRemoteDataSourceException(
        message: e.message ?? 'Failed to fetch messages',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      if (e is MessageListRemoteDataSourceException) rethrow;
      throw MessageListRemoteDataSourceException(
        message: 'Unexpected error while fetching messages: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<List<BaseMessage>> fetchPreviousMessages({
    required MessagesRequest request,
  }) async {
    try {
      return await _fetchPrevious(request);
    } on CometChatException catch (e) {
      throw MessageListRemoteDataSourceException(
        message: e.message ?? 'Failed to fetch previous messages',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      if (e is MessageListRemoteDataSourceException) rethrow;
      throw MessageListRemoteDataSourceException(
        message:
            'Unexpected error while fetching previous messages: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<List<BaseMessage>> fetchNextMessages({
    required MessagesRequest request,
  }) async {
    try {
      return await _fetchNext(request);
    } on CometChatException catch (e) {
      throw MessageListRemoteDataSourceException(
        message: e.message ?? 'Failed to fetch next messages',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      if (e is MessageListRemoteDataSourceException) rethrow;
      throw MessageListRemoteDataSourceException(
        message:
            'Unexpected error while fetching next messages: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<void> markAsRead(BaseMessage message) async {
    try {
      final completer = Completer<void>();
      await CometChat.markAsRead(
        message,
        onSuccess: (dynamic result) {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (CometChatException exception) {
          if (!completer.isCompleted) {
            completer.completeError(
              MessageListRemoteDataSourceException(
                message: exception.message ?? 'Failed to mark message as read',
                code: exception.code,
                originalException: exception,
              ),
            );
          }
        },
      );
      return await completer.future;
    } on CometChatException catch (e) {
      throw MessageListRemoteDataSourceException(
        message: e.message ?? 'Failed to mark message as read',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      if (e is MessageListRemoteDataSourceException) rethrow;
      throw MessageListRemoteDataSourceException(
        message:
            'Unexpected error while marking message as read: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<void> markAsDelivered(BaseMessage message) async {
    try {
      final completer = Completer<void>();
      await CometChat.markAsDelivered(
        message,
        onSuccess: (String result) {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (CometChatException exception) {
          if (!completer.isCompleted) {
            completer.completeError(
              MessageListRemoteDataSourceException(
                message:
                    exception.message ?? 'Failed to mark message as delivered',
                code: exception.code,
                originalException: exception,
              ),
            );
          }
        },
      );
      return await completer.future;
    } on CometChatException catch (e) {
      throw MessageListRemoteDataSourceException(
        message: e.message ?? 'Failed to mark message as delivered',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      if (e is MessageListRemoteDataSourceException) rethrow;
      throw MessageListRemoteDataSourceException(
        message:
            'Unexpected error while marking message as delivered: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<User?> getLoggedInUser() async {
    try {
      return await CometChat.getLoggedInUser();
    } on CometChatException catch (e) {
      throw MessageListRemoteDataSourceException(
        message: e.message ?? 'Failed to get logged in user',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      throw MessageListRemoteDataSourceException(
        message:
            'Unexpected error while getting logged in user: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Conversation> getConversation({
    required String conversationWith,
    required String conversationType,
  }) async {
    try {
      final completer = Completer<Conversation>();
      await CometChat.getConversation(
        conversationWith,
        conversationType,
        onSuccess: (Conversation conversation) {
          if (!completer.isCompleted) completer.complete(conversation);
        },
        onError: (CometChatException exception) {
          if (!completer.isCompleted) {
            completer.completeError(
              MessageListRemoteDataSourceException(
                message: exception.message ?? 'Failed to get conversation',
                code: exception.code,
                originalException: exception,
              ),
            );
          }
        },
      );
      return await completer.future;
    } on CometChatException catch (e) {
      throw MessageListRemoteDataSourceException(
        message: e.message ?? 'Failed to get conversation',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      if (e is MessageListRemoteDataSourceException) rethrow;
      throw MessageListRemoteDataSourceException(
        message: 'Unexpected error while getting conversation: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Conversation> markMessageAsUnread(BaseMessage message) async {
    try {
      final completer = Completer<Conversation>();
      await CometChat.markMessageAsUnread(
        message,
        onSuccess: (Conversation conversation) {
          if (!completer.isCompleted) completer.complete(conversation);
        },
        onError: (CometChatException exception) {
          if (!completer.isCompleted) {
            completer.completeError(
              MessageListRemoteDataSourceException(
                message:
                    exception.message ?? 'Failed to mark message as unread',
                code: exception.code,
                originalException: exception,
              ),
            );
          }
        },
      );
      return await completer.future;
    } on CometChatException catch (e) {
      throw MessageListRemoteDataSourceException(
        message: e.message ?? 'Failed to mark message as unread',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      if (e is MessageListRemoteDataSourceException) rethrow;
      throw MessageListRemoteDataSourceException(
        message:
            'Unexpected error while marking message as unread: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  Future<List<BaseMessage>> _fetchPrevious(MessagesRequest request) async {
    final completer = Completer<List<BaseMessage>>();
    unawaited(
      request.fetchPrevious(
        onSuccess: (List<BaseMessage> messages) {
          if (!completer.isCompleted) completer.complete(messages);
        },
        onError: (CometChatException exception) {
          if (!completer.isCompleted) {
            completer.completeError(
              MessageListRemoteDataSourceException(
                message:
                    exception.message ?? 'Failed to fetch previous messages',
                code: exception.code,
                originalException: exception,
              ),
            );
          }
        },
      ),
    );
    return await completer.future;
  }

  Future<List<BaseMessage>> _fetchNext(MessagesRequest request) async {
    final completer = Completer<List<BaseMessage>>();
    unawaited(
      request.fetchNext(
        onSuccess: (List<BaseMessage> messages) {
          if (!completer.isCompleted) completer.complete(messages);
        },
        onError: (CometChatException exception) {
          if (!completer.isCompleted) {
            completer.completeError(
              MessageListRemoteDataSourceException(
                message: exception.message ?? 'Failed to fetch next messages',
                code: exception.code,
                originalException: exception,
              ),
            );
          }
        },
      ),
    );
    return await completer.future;
  }
}
