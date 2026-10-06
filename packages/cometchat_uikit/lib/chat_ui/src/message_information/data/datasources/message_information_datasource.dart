import 'dart:async';

import '../../../../../cometchat_chat_uikit.dart';

/// Exception thrown when message information data source operations fail
class MessageInformationDataSourceException implements Exception {
  final String message;
  final String? code;
  final Exception? originalException;

  const MessageInformationDataSourceException({
    required this.message,
    this.code,
    this.originalException,
  });

  @override
  String toString() =>
      'MessageInformationDataSourceException(message: $message, code: $code)';
}

/// Abstract interface for message information data source
/// Handles interactions with CometChat SDK for message receipt operations
abstract class MessageInformationDataSource {
  /// Fetch message receipts for a given message ID
  ///
  /// Returns a list of [MessageReceipt] containing delivery and read
  /// timestamps for each recipient of the message.
  ///
  /// Throws [MessageInformationDataSourceException] if the SDK call fails.
  Future<List<MessageReceipt>> fetchMessageReceipts(int messageId);
}

/// Implementation of MessageInformationDataSource using CometChat SDK
class MessageInformationDataSourceImpl implements MessageInformationDataSource {
  @override
  Future<List<MessageReceipt>> fetchMessageReceipts(int messageId) async {
    final completer = Completer<List<MessageReceipt>>();
    unawaited(
      CometChat.getMessageReceipts(
        messageId,
        onSuccess: (receipts) => completer.complete(receipts),
        onError: (error) => completer.completeError(
          MessageInformationDataSourceException(
            message: error.message ?? 'Failed to fetch message receipts',
            code: error.code,
            originalException: error,
          ),
        ),
      ),
    );
    return completer.future;
  }
}
