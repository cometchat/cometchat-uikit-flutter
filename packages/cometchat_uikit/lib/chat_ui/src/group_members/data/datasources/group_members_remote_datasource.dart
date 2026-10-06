import 'dart:async';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import '../../../../../shared_ui/src/constants/ui_kit_constants.dart';
import '../../../../../shared_ui/src/logging/cometchat_log.dart';

/// Exception thrown when remote data source operations fail.
class GroupMembersRemoteDataSourceException implements Exception {
  final String message;
  final String? code;
  final Exception? originalException;

  const GroupMembersRemoteDataSourceException({
    required this.message,
    this.code,
    this.originalException,
  });

  @override
  String toString() =>
      'GroupMembersRemoteDataSourceException(message: $message, code: $code)';
}

/// Abstract interface for group members remote data source.
/// Handles all interactions with CometChat SDK for group member operations.
abstract class GroupMembersRemoteDataSource {
  /// Get group members with pagination.
  ///
  /// [guid] - The group ID to fetch members for.
  /// [limit] - Maximum number of members to fetch.
  /// [searchKeyword] - Optional keyword to filter members by name.
  Future<List<GroupMember>> getGroupMembers({
    required String guid,
    int limit = 30,
    String? searchKeyword,
  });

  /// Kick a member from the group.
  ///
  /// [guid] - The group ID.
  /// [uid] - The user ID of the member to kick.
  Future<void> kickGroupMember({required String guid, required String uid});

  /// Ban a member from the group.
  ///
  /// [guid] - The group ID.
  /// [uid] - The user ID of the member to ban.
  Future<void> banGroupMember({required String guid, required String uid});

  /// Update member scope (role) within the group.
  ///
  /// [guid] - The group ID.
  /// [uid] - The user ID of the member.
  /// [scope] - The new scope ('admin', 'moderator', 'participant').
  Future<void> updateMemberScope({
    required String guid,
    required String uid,
    required String scope,
  });

  /// Get the currently logged-in user.
  Future<User?> getLoggedInUser();

  /// Get conversation for the group.
  ///
  /// [guid] - The group ID.
  Future<Conversation?> getConversation(String guid);

  /// Reset the data source state (clears pagination).
  void reset();
}

/// Implementation of GroupMembersRemoteDataSource using CometChat SDK.
class GroupMembersRemoteDataSourceImpl implements GroupMembersRemoteDataSource {
  /// Current request instance for pagination support.
  GroupMembersRequest? _currentRequest;

  /// Current group ID for request management.
  String? _currentGuid;

  /// Current search keyword for request management.
  String? _currentSearchKeyword;

  /// The app builder [_currentRequest] was built from, if any.
  GroupMembersRequestBuilder? _currentRequestBuilder;

  /// [groupMembersRequestBuilder], when given, is the app's own builder: the
  /// request is built from it, so its limit, scopes, status and search keyword
  /// apply, with [guid] and a non-empty [searchKeyword] on top. See
  /// [_buildFromAppBuilder]. Without it the request is built from a fresh
  /// builder, as before.
  @override
  Future<List<GroupMember>> getGroupMembers({
    required String guid,
    int limit = 30,
    String? searchKeyword,
    GroupMembersRequestBuilder? groupMembersRequestBuilder,
  }) async {
    try {
      // Check if we need to create a new request
      // (different guid, different search keyword, different app builder,
      // or no existing request)
      final needsNewRequest =
          _currentRequest == null ||
          _currentGuid != guid ||
          _currentSearchKeyword != searchKeyword ||
          !identical(_currentRequestBuilder, groupMembersRequestBuilder);

      if (needsNewRequest) {
        if (groupMembersRequestBuilder != null) {
          _currentRequest = _buildFromAppBuilder(
            groupMembersRequestBuilder,
            guid: guid,
            limit: limit,
            searchKeyword: searchKeyword,
          );
        } else {
          // Create a new request builder
          final requestBuilder = GroupMembersRequestBuilder(guid)
            ..limit = limit;

          if (searchKeyword != null && searchKeyword.isNotEmpty) {
            requestBuilder.searchKeyword = searchKeyword;
          }

          // Build the request
          _currentRequest = requestBuilder.build();
        }
        _currentGuid = guid;
        _currentSearchKeyword = searchKeyword;
        _currentRequestBuilder = groupMembersRequestBuilder;
      }

      // Create a completer to convert callback-based API to Future
      final completer = Completer<List<GroupMember>>();

      // Fetch group members
      unawaited(
        _currentRequest!.fetchNext(
          onSuccess: (List<GroupMember> members) {
            if (!completer.isCompleted) {
              completer.complete(members);
            }
          },
          onError: (CometChatException exception) {
            if (!completer.isCompleted) {
              completer.completeError(
                GroupMembersRemoteDataSourceException(
                  message: exception.message ?? 'Failed to fetch group members',
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
      throw GroupMembersRemoteDataSourceException(
        message: e.message ?? 'Failed to fetch group members',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      if (e is GroupMembersRemoteDataSourceException) rethrow;
      throw GroupMembersRemoteDataSourceException(
        message:
            'Unexpected error while fetching group members: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  /// Builds the request from the app's own [builder], with the list's group
  /// and the search box's keyword on top, then puts the builder back as it
  /// was.
  ///
  /// The builder is the app's object and outlives this request, so its fields
  /// are set only for the synchronous `build()`, which copies them into the
  /// request, and restored in `finally` — a cleared search's keyword must not
  /// filter later loads. It cannot be copied instead: its page is private.
  ///
  /// [guid] wins over the builder's own: the list shows, and its kick, ban and
  /// scope actions act on, the widget's group, so members of any other group
  /// must not load into it. A mismatch is logged in debug builds. The app's
  /// limit wins over [limit], which fills in only when the app set none. The
  /// builder's scopes and status are the app's and are not touched.
  GroupMembersRequest _buildFromAppBuilder(
    GroupMembersRequestBuilder builder, {
    required String guid,
    required int limit,
    String? searchKeyword,
  }) {
    final appGuid = builder.guid;
    final appLimit = builder.limit;
    final appSearchKeyword = builder.searchKeyword;
    if (appGuid != guid) {
      ccLog(
        'CometChatGroupMembers: groupMembersRequestBuilder is for group '
        '"$appGuid", but the list shows group "$guid"; loading "$guid" with '
        "the builder's other settings.",
      );
    }
    try {
      builder
        ..guid = guid
        ..limit = appLimit ?? limit;
      if (searchKeyword != null && searchKeyword.isNotEmpty) {
        builder.searchKeyword = searchKeyword;
      }
      return builder.build();
    } finally {
      builder
        ..guid = appGuid
        ..limit = appLimit
        ..searchKeyword = appSearchKeyword;
    }
  }

  @override
  Future<void> kickGroupMember({
    required String guid,
    required String uid,
  }) async {
    try {
      final completer = Completer<void>();

      await CometChat.kickGroupMember(
        guid: guid,
        uid: uid,
        onSuccess: (String result) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (CometChatException exception) {
          if (!completer.isCompleted) {
            completer.completeError(
              GroupMembersRemoteDataSourceException(
                message: exception.message ?? 'Failed to kick group member',
                code: exception.code,
                originalException: exception,
              ),
            );
          }
        },
      );

      return await completer.future;
    } on CometChatException catch (e) {
      throw GroupMembersRemoteDataSourceException(
        message: e.message ?? 'Failed to kick group member',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      if (e is GroupMembersRemoteDataSourceException) rethrow;
      throw GroupMembersRemoteDataSourceException(
        message: 'Unexpected error while kicking group member: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<void> banGroupMember({
    required String guid,
    required String uid,
  }) async {
    try {
      final completer = Completer<void>();

      await CometChat.banGroupMember(
        guid: guid,
        uid: uid,
        onSuccess: (String result) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (CometChatException exception) {
          if (!completer.isCompleted) {
            completer.completeError(
              GroupMembersRemoteDataSourceException(
                message: exception.message ?? 'Failed to ban group member',
                code: exception.code,
                originalException: exception,
              ),
            );
          }
        },
      );

      return await completer.future;
    } on CometChatException catch (e) {
      throw GroupMembersRemoteDataSourceException(
        message: e.message ?? 'Failed to ban group member',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      if (e is GroupMembersRemoteDataSourceException) rethrow;
      throw GroupMembersRemoteDataSourceException(
        message: 'Unexpected error while banning group member: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<void> updateMemberScope({
    required String guid,
    required String uid,
    required String scope,
  }) async {
    try {
      final completer = Completer<void>();

      await CometChat.updateGroupMemberScope(
        guid: guid,
        uid: uid,
        scope: scope,
        onSuccess: (String result) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (CometChatException exception) {
          if (!completer.isCompleted) {
            completer.completeError(
              GroupMembersRemoteDataSourceException(
                message: exception.message ?? 'Failed to update member scope',
                code: exception.code,
                originalException: exception,
              ),
            );
          }
        },
      );

      return await completer.future;
    } on CometChatException catch (e) {
      throw GroupMembersRemoteDataSourceException(
        message: e.message ?? 'Failed to update member scope',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      if (e is GroupMembersRemoteDataSourceException) rethrow;
      throw GroupMembersRemoteDataSourceException(
        message:
            'Unexpected error while updating member scope: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<User?> getLoggedInUser() async {
    try {
      final completer = Completer<User?>();

      await CometChat.getLoggedInUser(
        onSuccess: (User user) {
          if (!completer.isCompleted) {
            completer.complete(user);
          }
        },
        onError: (CometChatException exception) {
          if (!completer.isCompleted) {
            completer.completeError(
              GroupMembersRemoteDataSourceException(
                message: exception.message ?? 'Failed to get logged in user',
                code: exception.code,
                originalException: exception,
              ),
            );
          }
        },
      );

      return await completer.future;
    } on CometChatException catch (e) {
      throw GroupMembersRemoteDataSourceException(
        message: e.message ?? 'Failed to get logged in user',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      if (e is GroupMembersRemoteDataSourceException) rethrow;
      throw GroupMembersRemoteDataSourceException(
        message:
            'Unexpected error while getting logged in user: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Conversation?> getConversation(String guid) async {
    try {
      final completer = Completer<Conversation?>();

      await CometChat.getConversation(
        guid,
        ReceiverTypeConstants.group,
        onSuccess: (Conversation conversation) {
          if (!completer.isCompleted) {
            completer.complete(conversation);
          }
        },
        onError: (CometChatException exception) {
          if (!completer.isCompleted) {
            // Return null for conversation not found instead of throwing
            // This is expected behavior when no conversation exists yet
            completer.complete(null);
          }
        },
      );

      return await completer.future;
    } on CometChatException catch (e) {
      throw GroupMembersRemoteDataSourceException(
        message: e.message ?? 'Failed to get conversation',
        code: e.code,
        originalException: e,
      );
    } catch (e) {
      if (e is GroupMembersRemoteDataSourceException) rethrow;
      throw GroupMembersRemoteDataSourceException(
        message: 'Unexpected error while getting conversation: ${e.toString()}',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  void reset() {
    _currentRequest = null;
    _currentGuid = null;
    _currentSearchKeyword = null;
    _currentRequestBuilder = null;
  }
}
