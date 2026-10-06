import 'dart:async';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;

/// Exception thrown when remote data source operations fail
class UsersRemoteDataSourceException implements Exception {
  final String message;
  final String? code;
  final Exception? originalException;

  const UsersRemoteDataSourceException({
    required this.message,
    this.code,
    this.originalException,
  });

  @override
  String toString() =>
      'UsersRemoteDataSourceException(message: $message, code: $code)';
}

/// Abstract interface for users remote data source
/// Handles all interactions with CometChat SDK
abstract class UsersRemoteDataSource {
  /// Get users with optional pagination and search.
  /// On the first call (or after [resetRequest]) a new SDK request is built;
  /// subsequent calls reuse the same request so the SDK cursor advances.
  Future<List<User>> getUsers({
    int limit = 30,
    String? searchKeyword,
    UsersRequestBuilder? usersRequestBuilder,
  });

  /// Reset the internal SDK request so the next [getUsers] call starts fresh.
  /// Call this when doing a fresh load or when the search keyword changes.
  void resetRequest();

  /// Get a specific user by UID
  Future<User> getUser(String uid);

  /// Block a user
  Future<void> blockUser(String uid);

  /// Unblock a user
  Future<void> unblockUser(String uid);
}

/// Implementation of UsersRemoteDataSource using CometChat SDK
class UsersRemoteDataSourceImpl implements UsersRemoteDataSource {
  UsersRequest? _currentRequest;

  @override
  void resetRequest() {
    _currentRequest = null;
  }

  @override
  Future<List<User>> getUsers({
    int limit = 30,
    String? searchKeyword,
    UsersRequestBuilder? usersRequestBuilder,
  }) async {
    try {
      // Build a new request only if we don't have one yet (first call or after reset)
      if (_currentRequest == null) {
        if (usersRequestBuilder != null) {
          _currentRequest = _buildFromAppBuilder(
            usersRequestBuilder,
            searchKeyword: searchKeyword,
          );
        } else {
          final requestBuilder = UsersRequestBuilder()..limit = limit;

          if (searchKeyword != null && searchKeyword.isNotEmpty) {
            requestBuilder.searchKeyword = searchKeyword;
          }

          _currentRequest = requestBuilder.build();
        }
      }

      final completer = Completer<List<User>>();

      unawaited(
        _currentRequest!.fetchNext(
          onSuccess: (List<User> users) {
            if (!completer.isCompleted) {
              completer.complete(users);
            }
          },
          onError: (CometChatException exception) {
            if (!completer.isCompleted) {
              completer.completeError(
                UsersRemoteDataSourceException(
                  message: exception.message ?? 'Failed to fetch users',
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
      throw UsersRemoteDataSourceException(
        message: e.message ?? 'Failed to fetch users',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      throw UsersRemoteDataSourceException(
        message: 'Unexpected error while fetching users: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  /// Builds the request from the app's own [builder], with the search box's
  /// keyword on top, then puts the builder's keyword back.
  ///
  /// The builder is the app's object and outlives this request: writing into
  /// it and leaving the values there overwrote the app's limit with the kit's
  /// page size, and left a cleared search's keyword filtering every later
  /// load. It cannot be copied instead — its page is private — so the keyword
  /// is set only for the synchronous `build()`, which copies it into the
  /// request, and restored in `finally`. The builder's limit is its own and
  /// is not touched.
  UsersRequest _buildFromAppBuilder(
    UsersRequestBuilder builder, {
    String? searchKeyword,
  }) {
    final appSearchKeyword = builder.searchKeyword;
    try {
      if (searchKeyword != null && searchKeyword.isNotEmpty) {
        builder.searchKeyword = searchKeyword;
      }
      return builder.build();
    } finally {
      builder.searchKeyword = appSearchKeyword;
    }
  }

  @override
  Future<User> getUser(String uid) async {
    try {
      final completer = Completer<User>();

      await CometChat.getUser(
        uid,
        onSuccess: (User user) {
          completer.complete(user);
        },
        onError: (CometChatException exception) {
          completer.completeError(
            UsersRemoteDataSourceException(
              message: exception.message ?? 'Failed to get user',
              code: exception.code,
              originalException: exception,
            ),
          );
        },
      );

      return await completer.future;
    } on CometChatException catch (e) {
      throw UsersRemoteDataSourceException(
        message: e.message ?? 'Failed to get user',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      throw UsersRemoteDataSourceException(
        message: 'Unexpected error while getting user: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<void> blockUser(String uid) async {
    try {
      final completer = Completer<void>();

      await CometChat.blockUser(
        [uid],
        onSuccess: (Map<String, dynamic> result) {
          completer.complete();
        },
        onError: (CometChatException exception) {
          completer.completeError(
            UsersRemoteDataSourceException(
              message: exception.message ?? 'Failed to block user',
              code: exception.code,
              originalException: exception,
            ),
          );
        },
      );

      return await completer.future;
    } on CometChatException catch (e) {
      throw UsersRemoteDataSourceException(
        message: e.message ?? 'Failed to block user',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      throw UsersRemoteDataSourceException(
        message: 'Unexpected error while blocking user: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<void> unblockUser(String uid) async {
    try {
      final completer = Completer<void>();

      await CometChat.unblockUser(
        [uid],
        onSuccess: (Map<String, dynamic> result) {
          completer.complete();
        },
        onError: (CometChatException exception) {
          completer.completeError(
            UsersRemoteDataSourceException(
              message: exception.message ?? 'Failed to unblock user',
              code: exception.code,
              originalException: exception,
            ),
          );
        },
      );

      return await completer.future;
    } on CometChatException catch (e) {
      throw UsersRemoteDataSourceException(
        message: e.message ?? 'Failed to unblock user',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      throw UsersRemoteDataSourceException(
        message: 'Unexpected error while unblocking user: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }
}
