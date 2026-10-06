import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import '../../../../../shared_ui/src/clean_architecture/core/result.dart';

/// Repository interface for groups data operations
/// Defines the contract for group data access
///
/// All methods return [Result<T>] type following the Either pattern
/// for functional error handling.
///
/// Requirements: 2.1, 2.3
abstract class GroupsRepository {
  /// Get groups with optional pagination and search
  ///
  /// [limit] - Maximum number of groups to fetch (default: 30)
  /// [searchKeyword] - Optional keyword to filter groups by name
  /// [joinedOnly] - If true, only return groups the user has joined
  ///
  /// Returns [Result<List<Group>>] - Success with list of groups or Failure
  ///
  /// The signature is 6.1.1's, so an app's own implementation keeps
  /// compiling. [GroupsRepositoryImpl.getGroups] also takes the
  /// `groupsRequestBuilder` from [CometChatGroups.groupsRequestBuilder].
  Future<Result<List<Group>>> getGroups({
    int limit = 30,
    String? searchKeyword,
    bool? joinedOnly,
  });

  /// Reset the internal SDK pagination cursor.
  /// Call before a fresh load or when search keyword changes.
  void resetRequest();

  /// Get a specific group by its GUID
  ///
  /// [guid] - The unique identifier of the group
  ///
  /// Returns [Result<Group>] - Success with the group or Failure if not found
  Future<Result<Group>> getGroupById(String guid);

  /// Join a group
  ///
  /// [guid] - The unique identifier of the group to join
  /// [groupType] - The type of group (public, private, password)
  /// [password] - Required for password-protected groups
  ///
  /// Returns [Result<Group>] - Success with the joined group or Failure
  Future<Result<Group>> joinGroup({
    required String guid,
    required String groupType,
    String? password,
  });

  /// Leave a group
  ///
  /// [guid] - The unique identifier of the group to leave
  ///
  /// Returns [Result<void>] - Success or Failure
  Future<Result<void>> leaveGroup(String guid);

  /// Get the currently logged-in user
  ///
  /// Returns [Result<User?>] - Success with the user (or null if not logged in) or Failure
  Future<Result<User?>> getLoggedInUser();
}
