import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import '../../../../../shared_ui/src/clean_architecture/core/result.dart';
import '../../domain/repositories/group_members_repository.dart';
import '../datasources/group_members_remote_datasource.dart';

/// Implementation of GroupMembersRepository.
/// Coordinates data operations through the remote data source.
class GroupMembersRepositoryImpl implements GroupMembersRepository {
  final GroupMembersRemoteDataSource remoteDataSource;

  const GroupMembersRepositoryImpl({required this.remoteDataSource});

  /// [groupMembersRequestBuilder] is the app's own builder, passed on to the
  /// kit's data source, which builds the request from it.
  @override
  Future<Result<List<GroupMember>>> getGroupMembers({
    required String guid,
    int limit = 30,
    String? searchKeyword,
    GroupMembersRequestBuilder? groupMembersRequestBuilder,
  }) async {
    try {
      // The builder goes only to the kit's own data source: the interface
      // keeps its 6.1.1 signature, so an app's implementation does not
      // take one.
      final source = remoteDataSource;
      final members = source is GroupMembersRemoteDataSourceImpl
          ? await source.getGroupMembers(
              guid: guid,
              limit: limit,
              searchKeyword: searchKeyword,
              groupMembersRequestBuilder: groupMembersRequestBuilder,
            )
          : await source.getGroupMembers(
              guid: guid,
              limit: limit,
              searchKeyword: searchKeyword,
            );
      return Success(members);
    } on GroupMembersRemoteDataSourceException catch (e) {
      return Failure(
        message: e.message,
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(
        message:
            'Unexpected error while fetching group members: ${e.toString()}',
        exception: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Result<void>> kickGroupMember({
    required String guid,
    required String uid,
  }) async {
    try {
      await remoteDataSource.kickGroupMember(guid: guid, uid: uid);
      return const Success(null);
    } on GroupMembersRemoteDataSourceException catch (e) {
      return Failure(
        message: e.message,
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(
        message: 'Unexpected error while kicking group member: ${e.toString()}',
        exception: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Result<void>> banGroupMember({
    required String guid,
    required String uid,
  }) async {
    try {
      await remoteDataSource.banGroupMember(guid: guid, uid: uid);
      return const Success(null);
    } on GroupMembersRemoteDataSourceException catch (e) {
      return Failure(
        message: e.message,
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(
        message: 'Unexpected error while banning group member: ${e.toString()}',
        exception: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Result<void>> updateMemberScope({
    required String guid,
    required String uid,
    required String scope,
  }) async {
    try {
      await remoteDataSource.updateMemberScope(
        guid: guid,
        uid: uid,
        scope: scope,
      );
      return const Success(null);
    } on GroupMembersRemoteDataSourceException catch (e) {
      return Failure(
        message: e.message,
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(
        message:
            'Unexpected error while updating member scope: ${e.toString()}',
        exception: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Result<User?>> getLoggedInUser() async {
    try {
      final user = await remoteDataSource.getLoggedInUser();
      return Success(user);
    } on GroupMembersRemoteDataSourceException catch (e) {
      return Failure(
        message: e.message,
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(
        message:
            'Unexpected error while getting logged in user: ${e.toString()}',
        exception: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<Result<Conversation?>> getConversation(String guid) async {
    try {
      final conversation = await remoteDataSource.getConversation(guid);
      return Success(conversation);
    } on GroupMembersRemoteDataSourceException catch (e) {
      return Failure(
        message: e.message,
        code: e.code,
        exception: e.originalException,
      );
    } catch (e) {
      return Failure(
        message: 'Unexpected error while getting conversation: ${e.toString()}',
        exception: e is Exception ? e : null,
      );
    }
  }

  @override
  void resetPagination() {
    remoteDataSource.reset();
  }
}
