import 'package:equatable/equatable.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;

/// Base class for all notification feed events.
abstract class NotificationFeedEvent extends Equatable {
  const NotificationFeedEvent();

  @override
  List<Object?> get props => [];
}

/// Load initial notification feed (categories + first page of items).
class LoadNotificationFeed extends NotificationFeedEvent {
  const LoadNotificationFeed();
}

/// Load more feed items (pagination — scroll to bottom).
class LoadMoreFeedItems extends NotificationFeedEvent {
  const LoadMoreFeedItems();
}

/// Pull-to-refresh the feed.
class RefreshFeed extends NotificationFeedEvent {
  /// Creates the event. [silent] marks the kit's own reconnect refresh: with
  /// offline on, its failure over items shown does not reach `onError`.
  const RefreshFeed({this.silent = false});

  /// True for the reconnect refresh, false for pull-to-refresh.
  final bool silent;

  @override
  List<Object?> get props => [silent];
}

/// Switch the active category filter.
/// Pass null for "All" (no category filter).
class SwitchCategory extends NotificationFeedEvent {
  final String? categoryId;

  const SwitchCategory(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

/// A new feed item was received via WebSocket.
class FeedItemReceived extends NotificationFeedEvent {
  final NotificationFeedItem feedItem;

  const FeedItemReceived(this.feedItem);

  @override
  List<Object?> get props => [feedItem];
}

/// A feed item was retracted/deleted.
class FeedItemRetracted extends NotificationFeedEvent {
  final String itemId;

  const FeedItemRetracted(this.itemId);

  @override
  List<Object?> get props => [itemId];
}

/// Mark a feed item as read (after sustained visibility).
class MarkItemAsRead extends NotificationFeedEvent {
  final NotificationFeedItem feedItem;

  const MarkItemAsRead(this.feedItem);

  @override
  List<Object?> get props => [feedItem];
}

/// Report a feed item as delivered.
class ReportDelivered extends NotificationFeedEvent {
  final NotificationFeedItem feedItem;

  const ReportDelivered(this.feedItem);

  @override
  List<Object?> get props => [feedItem];
}

/// Report a feed item as viewed (entered viewport).
class ReportViewed extends NotificationFeedEvent {
  final NotificationFeedItem feedItem;

  const ReportViewed(this.feedItem);

  @override
  List<Object?> get props => [feedItem];
}

/// Report a feed item as clicked (user tapped card or action).
class ReportClicked extends NotificationFeedEvent {
  final NotificationFeedItem feedItem;

  const ReportClicked(this.feedItem);

  @override
  List<Object?> get props => [feedItem];
}

/// Update unread counts (triggered by periodic polling).
class UpdateUnreadCounts extends NotificationFeedEvent {
  const UpdateUnreadCounts();
}

/// Connection state changed (online/offline).
class ConnectionStateChanged extends NotificationFeedEvent {
  final bool isOffline;

  const ConnectionStateChanged(this.isOffline);

  @override
  List<Object?> get props => [isOffline];
}
