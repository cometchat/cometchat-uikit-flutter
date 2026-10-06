import 'dart:async';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;

/// Exception thrown when remote data source operations fail.
class NotificationFeedRemoteException implements Exception {
  final String message;
  final String? code;
  final Exception? originalException;

  const NotificationFeedRemoteException({
    required this.message,
    this.code,
    this.originalException,
  });

  @override
  String toString() =>
      'NotificationFeedRemoteException(message: $message, code: $code)';
}

/// Abstract interface for notification feed remote data source.
/// Handles all interactions with CometChat SDK for notification feed.
abstract class NotificationFeedRemoteDataSource {
  /// Fetch notification feed items using the provided request.
  Future<List<NotificationFeedItem>> fetchFeedItems(
    NotificationFeedRequest request,
  );

  /// Fetch notification categories using the provided request.
  Future<List<NotificationCategory>> fetchCategories(
    NotificationCategoriesRequest request,
  );

  /// Mark a notification feed item as delivered.
  Future<void> markAsDelivered(NotificationFeedItem feedItem);

  /// Mark a notification feed item as read.
  Future<void> markAsRead(NotificationFeedItem feedItem);

  /// Report engagement for a notification feed item.
  Future<void> reportEngagement(
    NotificationFeedItem feedItem,
    String interactionString,
  );

  /// Get the total unread count for the notification feed.
  Future<int> getUnreadCount();

  /// Fetch a single notification feed item by its ID.
  Future<NotificationFeedItem> getItem(String id);
}

/// Implementation of [NotificationFeedRemoteDataSource] using CometChat SDK.
class NotificationFeedRemoteDataSourceImpl
    implements NotificationFeedRemoteDataSource {
  @override
  Future<List<NotificationFeedItem>> fetchFeedItems(
    NotificationFeedRequest request,
  ) async {
    try {
      final completer = Completer<List<NotificationFeedItem>>();

      unawaited(
        request.fetchNext(
          onSuccess: (List<NotificationFeedItem> feedItems) {
            if (!completer.isCompleted) {
              completer.complete(feedItems);
            }
          },
          onError: (CometChatException exception) {
            if (!completer.isCompleted) {
              completer.completeError(
                NotificationFeedRemoteException(
                  message: exception.message ?? 'Failed to fetch feed items',
                  code: exception.code,
                  originalException: exception,
                ),
              );
            }
          },
        ),
      );

      return await completer.future;
    } on NotificationFeedRemoteException {
      rethrow;
    } catch (e) {
      throw NotificationFeedRemoteException(
        message: 'Unexpected error while fetching feed items: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<List<NotificationCategory>> fetchCategories(
    NotificationCategoriesRequest request,
  ) async {
    try {
      final completer = Completer<List<NotificationCategory>>();

      unawaited(
        request.fetchNext(
          onSuccess: (List<NotificationCategory> categories) {
            if (!completer.isCompleted) {
              completer.complete(categories);
            }
          },
          onError: (CometChatException exception) {
            if (!completer.isCompleted) {
              completer.completeError(
                NotificationFeedRemoteException(
                  message: exception.message ?? 'Failed to fetch categories',
                  code: exception.code,
                  originalException: exception,
                ),
              );
            }
          },
        ),
      );

      return await completer.future;
    } on NotificationFeedRemoteException {
      rethrow;
    } catch (e) {
      throw NotificationFeedRemoteException(
        message: 'Unexpected error while fetching categories: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<void> markAsDelivered(NotificationFeedItem feedItem) async {
    try {
      final completer = Completer<void>();

      unawaited(
        CometChat.markFeedItemAsDelivered(
          feedItem,
          onSuccess: (dynamic result) {
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
          onError: (CometChatException exception) {
            if (!completer.isCompleted) {
              completer.completeError(
                NotificationFeedRemoteException(
                  message:
                      exception.message ??
                      'Failed to mark feed item as delivered',
                  code: exception.code,
                  originalException: exception,
                ),
              );
            }
          },
        ),
      );

      return await completer.future;
    } on NotificationFeedRemoteException {
      rethrow;
    } catch (e) {
      throw NotificationFeedRemoteException(
        message: 'Unexpected error while marking as delivered: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<void> markAsRead(NotificationFeedItem feedItem) async {
    try {
      final completer = Completer<void>();

      unawaited(
        CometChat.markFeedItemAsRead(
          feedItem,
          onSuccess: (dynamic result) {
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
          onError: (CometChatException exception) {
            if (!completer.isCompleted) {
              completer.completeError(
                NotificationFeedRemoteException(
                  message:
                      exception.message ?? 'Failed to mark feed item as read',
                  code: exception.code,
                  originalException: exception,
                ),
              );
            }
          },
        ),
      );

      return await completer.future;
    } on NotificationFeedRemoteException {
      rethrow;
    } catch (e) {
      throw NotificationFeedRemoteException(
        message: 'Unexpected error while marking as read: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<void> reportEngagement(
    NotificationFeedItem feedItem,
    String interactionString,
  ) async {
    try {
      final completer = Completer<void>();

      unawaited(
        CometChat.reportFeedEngagement(
          feedItem,
          interactionString,
          onSuccess: (dynamic result) {
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
          onError: (CometChatException exception) {
            if (!completer.isCompleted) {
              completer.completeError(
                NotificationFeedRemoteException(
                  message:
                      exception.message ?? 'Failed to report feed engagement',
                  code: exception.code,
                  originalException: exception,
                ),
              );
            }
          },
        ),
      );

      return await completer.future;
    } on NotificationFeedRemoteException {
      rethrow;
    } catch (e) {
      throw NotificationFeedRemoteException(
        message: 'Unexpected error while reporting engagement: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      final completer = Completer<int>();

      unawaited(
        CometChat.getNotificationFeedUnreadCount(
          onSuccess: (int count) {
            if (!completer.isCompleted) {
              completer.complete(count);
            }
          },
          onError: (CometChatException exception) {
            if (!completer.isCompleted) {
              completer.completeError(
                NotificationFeedRemoteException(
                  message: exception.message ?? 'Failed to get unread count',
                  code: exception.code,
                  originalException: exception,
                ),
              );
            }
          },
        ),
      );

      return await completer.future;
    } on NotificationFeedRemoteException {
      rethrow;
    } catch (e) {
      throw NotificationFeedRemoteException(
        message: 'Unexpected error while getting unread count: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<NotificationFeedItem> getItem(String id) async {
    try {
      final completer = Completer<NotificationFeedItem>();

      unawaited(
        CometChat.getNotificationFeedItem(
          id,
          onSuccess: (NotificationFeedItem feedItem) {
            if (!completer.isCompleted) {
              completer.complete(feedItem);
            }
          },
          onError: (CometChatException exception) {
            if (!completer.isCompleted) {
              completer.completeError(
                NotificationFeedRemoteException(
                  message: exception.message ?? 'Failed to get feed item',
                  code: exception.code,
                  originalException: exception,
                ),
              );
            }
          },
        ),
      );

      return await completer.future;
    } on NotificationFeedRemoteException {
      rethrow;
    } catch (e) {
      throw NotificationFeedRemoteException(
        message: 'Unexpected error while getting feed item: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }
}
