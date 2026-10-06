/// The groupsRequestBuilder path after GroupsRepository and
/// GroupsRemoteDataSource went back to their 6.1.1 signatures.
///
/// The builder no longer travels through the interfaces; the use case and the
/// repository hand it on only when they hold the kit's own implementations.
/// These tests pin both halves: the kit's own chain still delivers the
/// builder, and an app's implementation written against 6.1.1 compiles and
/// is called without one.
library;

import 'package:cometchat_chat_uikit/chat_ui/src/groups/data/datasources/groups_remote_datasource.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/data/repositories/groups_repository_impl.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/domain/repositories/groups_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/groups/domain/usecases/get_groups_usecase.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import 'package:flutter_test/flutter_test.dart';

/// The kit's data source, with the SDK call replaced by a recorder.
class _RecordingRemote extends GroupsRemoteDataSourceImpl {
  GroupsRequestBuilder? receivedBuilder;
  int calls = 0;

  @override
  Future<List<Group>> getGroups({
    int limit = 30,
    String? searchKeyword,
    bool? joinedOnly,
    GroupsRequestBuilder? groupsRequestBuilder,
  }) async {
    calls++;
    receivedBuilder = groupsRequestBuilder;
    return const [];
  }
}

/// An app's own repository, written against the 6.1.1 interface: no
/// groupsRequestBuilder parameter. It has to keep compiling.
class _AppRepository implements GroupsRepository {
  int calls = 0;

  @override
  Future<Result<List<Group>>> getGroups({
    int limit = 30,
    String? searchKeyword,
    bool? joinedOnly,
  }) async {
    calls++;
    return const Success(<Group>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('the kit chain hands the builder from the use case to the data '
      'source', () async {
    final remote = _RecordingRemote();
    final useCase = GetGroupsUseCase(
      GroupsRepositoryImpl(remoteDataSource: remote),
    );
    final builder = GroupsRequestBuilder()..tags = ['chain-7Q'];

    final result = await useCase(groupsRequestBuilder: builder);

    expect(result, isA<Success<List<Group>>>());
    expect(remote.calls, 1);
    expect(identical(remote.receivedBuilder, builder), isTrue);
  });

  test('without a builder the kit chain passes none', () async {
    final remote = _RecordingRemote();
    await GetGroupsUseCase(GroupsRepositoryImpl(remoteDataSource: remote))();

    expect(remote.calls, 1);
    expect(remote.receivedBuilder, isNull);
  });

  test('an app repository written against 6.1.1 is still called', () async {
    final repo = _AppRepository();
    final result = await GetGroupsUseCase(repo)(
      groupsRequestBuilder: GroupsRequestBuilder(),
    );

    expect(result, isA<Success<List<Group>>>());
    expect(repo.calls, 1);
  });
}
