import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart' hide User;
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import 'package:equatable/equatable.dart';

/// Status enum for CallLogs BLoC state
enum CallLogsStatus {
  /// Initial state before any data is loaded
  initial,

  /// Loading state when fetching initial call logs
  loading,

  /// Loaded state with call log data
  loaded,

  /// Empty state when no call logs exist
  empty,

  /// Error state when fetching fails
  error,
}

/// Immutable state class for CallLogs BLoC
///
/// Uses Equatable for proper state comparison in BLoC.
/// Follows the conversations module pattern with copyWith support.
class CallLogsState extends Equatable {
  /// Current status of the call logs loading
  final CallLogsStatus status;

  /// List of call logs
  final List<CallLog> callLogs;

  /// Whether more call logs can be loaded (pagination)
  final bool hasMore;

  /// Whether currently loading more call logs
  final bool isLoadingMore;

  /// Error message when status is error
  final String? errorMessage;

  /// Why the last attempt to load the next page failed, or null. The list
  /// keeps what it has (status stays loaded) and ends with a retry row,
  /// which asks for the same page again; `CometChatCallLogs` reports it to
  /// its `onError`. Cleared when the next attempt starts.
  final String? loadMoreError;

  /// Currently logged in user
  final User? loggedInUser;

  /// Call logs grouped by date for display
  /// Key is the date string, value is list of call logs for that date
  final Map<String, List<CallLog>> groupedEntries;

  const CallLogsState({
    this.status = CallLogsStatus.initial,
    this.callLogs = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.loggedInUser,
    this.groupedEntries = const {},
    this.loadMoreError,
  });

  /// Factory constructor for initial state
  factory CallLogsState.initial() => const CallLogsState();

  @override
  List<Object?> get props => [
    status,
    callLogs,
    hasMore,
    isLoadingMore,
    errorMessage,
    loggedInUser,
    groupedEntries,
    loadMoreError,
  ];

  /// Create a copy of this state with updated fields. [clearLoadMoreError]
  /// sets [loadMoreError] back to null.
  CallLogsState copyWith({
    CallLogsStatus? status,
    List<CallLog>? callLogs,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
    User? loggedInUser,
    Map<String, List<CallLog>>? groupedEntries,
    String? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return CallLogsState(
      status: status ?? this.status,
      callLogs: callLogs ?? this.callLogs,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage ?? this.errorMessage,
      loggedInUser: loggedInUser ?? this.loggedInUser,
      groupedEntries: groupedEntries ?? this.groupedEntries,
      loadMoreError: clearLoadMoreError
          ? null
          : loadMoreError ?? this.loadMoreError,
    );
  }
}
