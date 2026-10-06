import 'dart:async';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import '../../../../../../shared_ui/src/clean_architecture/core/result.dart';

/// Remote data source for AI Assistant Chat History.
/// Wraps CometChat SDK calls for message fetching and deletion.
abstract class AIAssistantChatHistoryRemoteDataSource {
  Future<Result<List<BaseMessage>>> fetchMessages(MessagesRequest request);
  Future<Result<BaseMessage>> deleteMessage(int messageId);
  Future<Result<User?>> getLoggedInUser();
  Future<Result<Conversation?>> getConversation(
    String conversationWith,
    String conversationType,
  );
}

/// Implementation of [AIAssistantChatHistoryRemoteDataSource] using CometChat SDK.
class AIAssistantChatHistoryRemoteDataSourceImpl
    implements AIAssistantChatHistoryRemoteDataSource {
  @override
  Future<Result<List<BaseMessage>>> fetchMessages(
    MessagesRequest request,
  ) async {
    final completer = Completer<Result<List<BaseMessage>>>();
    unawaited(
      request.fetchPrevious(
        onSuccess: (List<BaseMessage> list) {
          completer.complete(Success(list));
        },
        onError: (CometChatException e) {
          completer.complete(
            Failure(
              message: e.message ?? 'Failed to fetch messages',
              code: e.code,
            ),
          );
        },
      ),
    );
    return completer.future;
  }

  @override
  Future<Result<BaseMessage>> deleteMessage(int messageId) async {
    final completer = Completer<Result<BaseMessage>>();
    unawaited(
      CometChat.deleteMessage(
        messageId,
        onSuccess: (BaseMessage updatedMessage) {
          completer.complete(Success(updatedMessage));
        },
        onError: (CometChatException e) {
          completer.complete(
            Failure(
              message: e.message ?? 'Failed to delete message',
              code: e.code,
            ),
          );
        },
      ),
    );
    return completer.future;
  }

  @override
  Future<Result<User?>> getLoggedInUser() async {
    try {
      final user = await CometChat.getLoggedInUser();
      return Success(user);
    } on CometChatException catch (e) {
      return Failure(
        message: e.message ?? 'Failed to get logged in user',
        code: e.code,
      );
    } catch (e) {
      return Failure(message: e.toString());
    }
  }

  @override
  Future<Result<Conversation?>> getConversation(
    String conversationWith,
    String conversationType,
  ) async {
    final completer = Completer<Result<Conversation?>>();
    unawaited(
      CometChat.getConversation(
        conversationWith,
        conversationType,
        onSuccess: (Conversation conversation) {
          completer.complete(Success(conversation));
        },
        onError: (CometChatException e) {
          completer.complete(
            Failure(
              message: e.message ?? 'Failed to get conversation',
              code: e.code,
            ),
          );
        },
      ),
    );
    return completer.future;
  }
}
