import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import '../../../../../../shared_ui/src/clean_architecture/core/result.dart';
import '../../data/repositories/group_members_repository_impl.dart';
import '../repositories/group_members_repository.dart';

/// Use case for getting group members with pagination support.
/// Handles business logic for fetching group member lists.
class GetGroupMembersUseCase {
  final GroupMembersRepository repository;

  const GetGroupMembersUseCase(this.repository);

  /// Execute the use case to get group members.
  ///
  /// [guid] - The group ID to fetch members for (required, non-empty).
  /// [limit] - Maximum number of members to fetch (default: 30, must be positive).
  /// [searchKeyword] - Optional keyword to filter members by name.
  /// [groupMembersRequestBuilder] - Optional app builder the request is built
  /// from; honoured by the kit's own repository.
  ///
  /// Returns [Result<List<GroupMember>>] containing members or failure.
  Future<Result<List<GroupMember>>> call({
    required String guid,
    int limit = 30,
    String? searchKeyword,
    GroupMembersRequestBuilder? groupMembersRequestBuilder,
  }) async {
    // Validate guid is not empty
    if (guid.isEmpty) {
      return const Failure(
        message: 'Group ID cannot be empty',
        code: 'INVALID_GUID',
      );
    }

    // Validate limit is positive
    if (limit <= 0) {
      return const Failure(
        message: 'Limit must be greater than 0',
        code: 'INVALID_LIMIT',
      );
    }

    // Delegate to repository. The builder goes only to the kit's own
    // repository: the interface keeps its 6.1.1 signature, so an app's
    // implementation does not take one.
    final repo = repository;
    if (repo is GroupMembersRepositoryImpl) {
      return await repo.getGroupMembers(
        guid: guid,
        limit: limit,
        searchKeyword: searchKeyword,
        groupMembersRequestBuilder: groupMembersRequestBuilder,
      );
    }
    return await repo.getGroupMembers(
      guid: guid,
      limit: limit,
      searchKeyword: searchKeyword,
    );
  }
}
