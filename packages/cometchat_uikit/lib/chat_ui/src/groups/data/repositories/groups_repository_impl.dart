import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import '../../../../../shared_ui/src/clean_architecture/core/result.dart';
import '../../domain/repositories/groups_repository.dart';
import '../datasources/groups_remote_datasource.dart';

/// Implementation of GroupsRepository
/// Coordinates between remote data source and domain layer
///
/// Uses the Result pattern for all returns, mapping SDK exceptions
/// to Failure results with error message and code.
///
/// Requirements: 2.2, 2.3, 2.5
class GroupsRepositoryImpl implements GroupsRepository {
  final GroupsRemoteDataSource remoteDataSource;

  const GroupsRepositoryImpl({required this.remoteDataSource});

  @override
  void resetRequest() {
    remoteDataSource.resetRequest();
  }

  @override
  Future<Result<List<Group>>> getGroups({
    int limit = 30,
    String? searchKeyword,
    bool? joinedOnly,
    GroupsRequestBuilder? groupsRequestBuilder,
  }) async {
    try {
      // The builder goes only to the kit's own data source: the interface
      // keeps its 6.1.1 signature, so an app's implementation does not
      // take one.
      final source = remoteDataSource;
      final groups = source is GroupsRemoteDataSourceImpl
          ? await source.getGroups(
              limit: limit,
              searchKeyword: searchKeyword,
              joinedOnly: joinedOnly,
              groupsRequestBuilder: groupsRequestBuilder,
            )
          : await source.getGroups(
              limit: limit,
              searchKeyword: searchKeyword,
              joinedOnly: joinedOnly,
            );

      return Success(groups);
    } on GroupsRemoteDataSourceException catch (e) {
      return Failure(
        message: 'Failed to load groups: ${e.message}',
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(
        message: 'Unexpected error while loading groups: ${e.toString()}',
        exception: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Result<Group>> getGroupById(String guid) async {
    try {
      final group = await remoteDataSource.getGroupById(guid);
      return Success(group);
    } on GroupsRemoteDataSourceException catch (e) {
      return Failure(
        message: 'Failed to get group: ${e.message}',
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(
        message: 'Unexpected error while getting group: ${e.toString()}',
        exception: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Result<Group>> joinGroup({
    required String guid,
    required String groupType,
    String? password,
  }) async {
    try {
      final group = await remoteDataSource.joinGroup(
        guid: guid,
        groupType: groupType,
        password: password,
      );
      return Success(group);
    } on GroupsRemoteDataSourceException catch (e) {
      return Failure(
        message: 'Failed to join group: ${e.message}',
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(
        message: 'Unexpected error while joining group: ${e.toString()}',
        exception: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Result<void>> leaveGroup(String guid) async {
    try {
      await remoteDataSource.leaveGroup(guid);
      return const Success(null);
    } on GroupsRemoteDataSourceException catch (e) {
      return Failure(
        message: 'Failed to leave group: ${e.message}',
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(
        message: 'Unexpected error while leaving group: ${e.toString()}',
        exception: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Result<User?>> getLoggedInUser() async {
    try {
      final user = await remoteDataSource.getLoggedInUser();
      return Success(user);
    } on GroupsRemoteDataSourceException catch (e) {
      return Failure(
        message: 'Failed to get logged-in user: ${e.message}',
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(
        message:
            'Unexpected error while getting logged-in user: ${e.toString()}',
        exception: e is Exception ? e : null,
      );
    }
  }
}
