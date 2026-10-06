import 'package:equatable/equatable.dart';

import '../../domain/entities/message_entity.dart';
import '../../core/result.dart';

/// Base state class for all message list states
/// Base of the message-list state family.
///
/// Named `MessageListStateBase` rather than `MessageListState` because the
/// chat_ui message-list bloc declares a concrete class by the latter name and
/// the barrel exports that one. Before the rename this base was reachable from
/// neither published barrel, so `MessageListSearchResults` had a supertype no
/// consumer could write — `state is MessageListState` was always false and
/// `MessageListState s = searchResults;` did not compile. ENG-39100.
abstract class MessageListStateBase extends Equatable {
  const MessageListStateBase();

  @override
  List<Object?> get props => [];
}

/// Initial state - before any operation
class MessageListInitial extends MessageListStateBase {
  const MessageListInitial();
}

/// Loading state - while fetching data
class MessageListLoading extends MessageListStateBase {
  final List<MessageEntity>? cachedMessages;

  const MessageListLoading({this.cachedMessages});

  @override
  List<Object?> get props => [cachedMessages];
}

/// Success state - data loaded successfully
class MessageListSuccess extends MessageListStateBase {
  final List<MessageEntity> messages;
  final bool hasMoreData;
  final int totalCount;

  const MessageListSuccess({
    required this.messages,
    this.hasMoreData = true,
    this.totalCount = 0,
  });

  @override
  List<Object?> get props => [messages, hasMoreData, totalCount];

  /// Create a copy with updated messages
  MessageListSuccess copyWith({
    List<MessageEntity>? messages,
    bool? hasMoreData,
    int? totalCount,
  }) {
    return MessageListSuccess(
      messages: messages ?? this.messages,
      hasMoreData: hasMoreData ?? this.hasMoreData,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

/// Error state - operation failed
class MessageListError extends MessageListStateBase {
  final Failure failure;
  final List<MessageEntity>? cachedMessages;

  const MessageListError({required this.failure, this.cachedMessages});

  @override
  List<Object?> get props => [failure, cachedMessages];

  /// Get error message for display
  String get errorMessage => failure.message;

  /// Check if error is recoverable
  bool get isRecoverable => !['INVALID_PARAMS'].contains(failure.code);
}

/// Empty state - no messages found
class MessageListEmpty extends MessageListStateBase {
  const MessageListEmpty();
}

/// Pagination state - loading more messages
class MessageListLoadingMore extends MessageListStateBase {
  final List<MessageEntity> currentMessages;

  const MessageListLoadingMore({required this.currentMessages});

  @override
  List<Object?> get props => [currentMessages];
}

/// Search state - searching for messages
class MessageListSearching extends MessageListStateBase {
  final String query;
  final List<MessageEntity>? previousMessages;

  const MessageListSearching({required this.query, this.previousMessages});

  @override
  List<Object?> get props => [query, previousMessages];
}

/// Search results state
class MessageListSearchResults extends MessageListStateBase {
  final List<MessageEntity> searchResults;
  final String query;
  final bool isEmpty;

  const MessageListSearchResults({
    required this.searchResults,
    required this.query,
    required this.isEmpty,
  });

  @override
  List<Object?> get props => [searchResults, query, isEmpty];
}

/// Message sending state
class MessageListSending extends MessageListStateBase {
  final List<MessageEntity> currentMessages;
  final String tempMessageText;

  const MessageListSending({
    required this.currentMessages,
    required this.tempMessageText,
  });

  @override
  List<Object?> get props => [currentMessages, tempMessageText];
}

/// Message sent state
class MessageListMessageSent extends MessageListStateBase {
  final List<MessageEntity> messages;
  final MessageEntity newMessage;

  const MessageListMessageSent({
    required this.messages,
    required this.newMessage,
  });

  @override
  List<Object?> get props => [messages, newMessage];
}

/// Message deleted state
class MessageListMessageDeleted extends MessageListStateBase {
  final List<MessageEntity> messages;
  final String deletedMessageId;

  const MessageListMessageDeleted({
    required this.messages,
    required this.deletedMessageId,
  });

  @override
  List<Object?> get props => [messages, deletedMessageId];
}

/// State for unread count
abstract class UnreadCountState extends Equatable {
  const UnreadCountState();

  @override
  List<Object?> get props => [];
}

class UnreadCountInitial extends UnreadCountState {
  const UnreadCountInitial();
}

class UnreadCountLoading extends UnreadCountState {
  const UnreadCountLoading();
}

class UnreadCountSuccess extends UnreadCountState {
  final int count;

  const UnreadCountSuccess(this.count);

  @override
  List<Object?> get props => [count];
}

class UnreadCountError extends UnreadCountState {
  final String message;

  const UnreadCountError(this.message);

  @override
  List<Object?> get props => [message];
}
