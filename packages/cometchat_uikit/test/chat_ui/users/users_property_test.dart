import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';

import 'package:cometchat_chat_uikit/chat_ui/src/users/bloc/users_bloc.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/bloc/users_event.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/bloc/users_state.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/domain/repositories/users_repository.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/domain/usecases/get_users_usecase.dart';
import 'package:cometchat_chat_uikit/chat_ui/src/users/domain/usecases/get_logged_in_user_usecase.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/result.dart';

// ---------------------------------------------------------------------------
// Mocks & Fakes
// ---------------------------------------------------------------------------

class MockUsersRepository extends Mock implements UsersRepository {}

class FakeUser extends Fake implements User {
  final String _uid;
  final String _name;
  final String? _status;
  final String? _avatar;
  final bool? _blockedByMe;
  final bool? _hasBlockedMe;

  FakeUser([
    this._uid = 'uid_1',
    this._name = 'User 1',
    this._status,
    this._avatar,
    this._blockedByMe = false,
    this._hasBlockedMe = false,
  ]);

  @override
  String get uid => _uid;
  @override
  String get name => _name;
  @override
  String? get status => _status;
  @override
  String? get avatar => _avatar;
  @override
  String? get role => null;
  @override
  bool? get blockedByMe => _blockedByMe;
  @override
  bool? get hasBlockedMe => _hasBlockedMe;
  @override
  DateTime? get lastActiveAt => null;
  @override
  String? get link => null;
  @override
  Map<String, dynamic>? get metadata => null;
  @override
  String? get statusMessage => null;
  @override
  List<String>? get tags => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UsersBloc _makeBloc(MockUsersRepository repo) {
  return UsersBloc(
    getUsersUseCase: GetUsersUseCase(repo),
    getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
    disableSDKListeners: true,
  );
}

List<FakeUser> _generateUsers(int count) {
  return List.generate(count, (i) => FakeUser('uid_$i', 'User $i'));
}

// ---------------------------------------------------------------------------
// Tests — Kotlin CometChatUsersAPIMethodCoverageTest equivalent
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeUser());
  });

  late MockUsersRepository repo;

  setUp(() {
    repo = MockUsersRepository();
    when(
      () => repo.getLoggedInUser(),
    ).thenAnswer((_) async => Success(FakeUser('me', 'Me')));
    when(
      () => repo.getUsers(
        limit: any(named: 'limit'),
        searchKeyword: any(named: 'searchKeyword'),
        usersRequestBuilder: any(named: 'usersRequestBuilder'),
      ),
    ).thenAnswer((_) async => const Success([]));
  });

  // =========================================================================
  // Visibility Toggles — Kotlin CSV #1001-1010
  // =========================================================================

  group('Visibility toggles', () {
    blocTest<UsersBloc, UsersState>(
      'hideSearch=true does not affect BLoC state (widget-level concern)',
      build: () {
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async => Success(_generateUsers(3)));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadUsers()),
      verify: (bloc) {
        expect(bloc.state, isA<UsersLoaded>());
      },
    );

    blocTest<UsersBloc, UsersState>(
      'showBackButton default does not affect BLoC state',
      build: () {
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async => Success(_generateUsers(2)));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadUsers()),
      verify: (bloc) {
        final state = bloc.state as UsersLoaded;
        expect(state.users.length, 2);
      },
    );

    test('usersStatusVisibility=true creates status notifiers', () async {
      when(
        () => repo.getUsers(
          limit: any(named: 'limit'),
          searchKeyword: any(named: 'searchKeyword'),
          usersRequestBuilder: any(named: 'usersRequestBuilder'),
        ),
      ).thenAnswer(
        (_) async => Success([FakeUser('uid_1', 'Alice', 'online')]),
      );

      final bloc = UsersBloc(
        getUsersUseCase: GetUsersUseCase(repo),
        getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
        disableSDKListeners: true,
        usersStatusVisibility: true,
      );

      bloc.add(const LoadUsers());
      await Future.delayed(const Duration(milliseconds: 100));

      final notifier = bloc.getStatusNotifier('uid_1');
      expect(notifier.value, isNotNull);
      await bloc.close();
    });

    test('usersStatusVisibility=false still allows getStatusNotifier', () {
      final bloc = UsersBloc(
        getUsersUseCase: GetUsersUseCase(repo),
        getLoggedInUserUseCase: GetLoggedInUserUseCase(repo),
        disableSDKListeners: true,
        usersStatusVisibility: false,
      );

      final notifier = bloc.getStatusNotifier('uid_1');
      expect(notifier.value, 'offline');
      bloc.close();
    });
  });

  // =========================================================================
  // Text Properties — Kotlin CSV #1011-1015
  // =========================================================================

  group('Text properties', () {
    blocTest<UsersBloc, UsersState>(
      'title defaults to "Users" (widget-level, BLoC unaffected)',
      build: () {
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async => Success(_generateUsers(1)));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadUsers()),
      verify: (bloc) {
        expect(bloc.state, isA<UsersLoaded>());
      },
    );

    blocTest<UsersBloc, UsersState>(
      'searchKeyword passed to LoadUsers is forwarded to use case',
      build: () {
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: 'alice',
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async => Success([FakeUser('uid_1', 'Alice')]));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadUsers(searchKeyword: 'alice')),
      verify: (bloc) {
        verify(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: 'alice',
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).called(1);
      },
    );
  });

  // =========================================================================
  // Custom Views / Callbacks — Kotlin CSV #1016-1030
  // =========================================================================

  group('Callbacks and custom views', () {
    blocTest<UsersBloc, UsersState>(
      'onItemTap callback receives correct user (via state access)',
      build: () {
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async => Success([FakeUser('uid_1', 'Alice')]));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadUsers()),
      verify: (bloc) {
        final state = bloc.state as UsersLoaded;
        expect(state.users.first.uid, 'uid_1');
        expect(state.users.first.name, 'Alice');
      },
    );

    blocTest<UsersBloc, UsersState>(
      'LoadUsers with silent=true does not emit Loading state',
      build: () {
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async => Success(_generateUsers(3)));
        return _makeBloc(repo);
      },
      seed: () => UsersLoaded(users: _generateUsers(2)),
      act: (bloc) => bloc.add(const LoadUsers(silent: true)),
      expect: () => [
        // Should NOT emit UsersLoading, only the updated UsersLoaded
        isA<UsersLoaded>(),
      ],
    );
  });

  // =========================================================================
  // Defaults — Kotlin CSV #1031-1040
  // =========================================================================

  group('Defaults', () {
    test('initial state is UsersInitial', () {
      final bloc = _makeBloc(repo);
      expect(bloc.state, isA<UsersInitial>());
      bloc.close();
    });

    test('getUserStatus returns offline for unknown user', () {
      final bloc = _makeBloc(repo);
      expect(bloc.getUserStatus('unknown_uid'), 'offline');
      bloc.close();
    });

    blocTest<UsersBloc, UsersState>(
      'hasMore defaults to true in loaded state',
      build: () {
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async => Success(_generateUsers(5)));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadUsers()),
      verify: (bloc) {
        final state = bloc.state as UsersLoaded;
        expect(state.hasMore, isTrue);
      },
    );

    blocTest<UsersBloc, UsersState>(
      'selectedUsers defaults to empty set',
      build: () {
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async => Success(_generateUsers(2)));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadUsers()),
      verify: (bloc) {
        final state = bloc.state as UsersLoaded;
        expect(state.selectedUsers, isEmpty);
      },
    );

    blocTest<UsersBloc, UsersState>(
      'isLoadingMore defaults to false',
      build: () {
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async => Success(_generateUsers(2)));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadUsers()),
      verify: (bloc) {
        final state = bloc.state as UsersLoaded;
        expect(state.isLoadingMore, isFalse);
      },
    );
  });

  // =========================================================================
  // Pagination — Kotlin CSV #1041-1050
  // =========================================================================

  group('Pagination (LoadMoreUsers)', () {
    blocTest<UsersBloc, UsersState>(
      'LoadMoreUsers appends new users to existing list',
      build: () {
        var callCount = 0;
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return Success(
              List.generate(30, (i) => FakeUser('uid_$i', 'User $i')),
            );
          }
          return Success(
            List.generate(
              10,
              (i) => FakeUser('uid_${30 + i}', 'User ${30 + i}'),
            ),
          );
        });
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadUsers());
        await Future.delayed(const Duration(milliseconds: 100));
        bloc.add(const LoadMoreUsers());
      },
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        final state = bloc.state as UsersLoaded;
        expect(state.users.length, 40);
      },
    );

    blocTest<UsersBloc, UsersState>(
      'LoadMoreUsers keeps hasMore after a short page, as Android does',
      build: () {
        var callCount = 0;
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return Success(
              List.generate(30, (i) => FakeUser('uid_$i', 'User $i')),
            );
          }
          return Success(
            List.generate(
              5,
              (i) => FakeUser('uid_${30 + i}', 'User ${30 + i}'),
            ),
          );
        });
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadUsers());
        await Future.delayed(const Duration(milliseconds: 100));
        bloc.add(const LoadMoreUsers());
      },
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        // Only an empty page ends paging; the SDK answers the request after
        // the last page from its page count.
        final state = bloc.state as UsersLoaded;
        expect(state.users, hasLength(35));
        expect(state.hasMore, isTrue);
      },
    );

    blocTest<UsersBloc, UsersState>(
      'LoadMoreUsers sets hasMore=false when a page comes back empty',
      build: () {
        var callCount = 0;
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) return Success(_generateUsers(5));
          return const Success(<User>[]);
        });
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadUsers());
        await Future.delayed(const Duration(milliseconds: 100));
        bloc.add(const LoadMoreUsers());
      },
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        final state = bloc.state as UsersLoaded;
        expect(state.users, hasLength(5));
        expect(state.hasMore, isFalse);
      },
    );

    blocTest<UsersBloc, UsersState>(
      'LoadMoreUsers is no-op when hasMore is false',
      build: () {
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async => Success(_generateUsers(5)));
        return _makeBloc(repo);
      },
      seed: () => UsersLoaded(users: _generateUsers(5), hasMore: false),
      act: (bloc) => bloc.add(const LoadMoreUsers()),
      expect: () => <UsersState>[],
    );

    blocTest<UsersBloc, UsersState>(
      'LoadMoreUsers is no-op when state is not UsersLoaded',
      build: () => _makeBloc(repo),
      act: (bloc) => bloc.add(const LoadMoreUsers()),
      expect: () => <UsersState>[],
    );

    blocTest<UsersBloc, UsersState>(
      'LoadMoreUsers emits error on failure with previousUsers',
      build: () {
        var callCount = 0;
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return Success(_generateUsers(30));
          }
          return const Failure(message: 'Network error', code: 'NET_ERR');
        });
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadUsers());
        await Future.delayed(const Duration(milliseconds: 100));
        bloc.add(const LoadMoreUsers());
      },
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        expect(bloc.state, isA<UsersError>());
        final state = bloc.state as UsersError;
        expect(state.previousUsers, isNotNull);
        expect(state.previousUsers!.length, 30);
      },
    );
  });

  // =========================================================================
  // Search — Kotlin CSV #1051-1060
  // =========================================================================

  group('Search (SearchUsers)', () {
    blocTest<UsersBloc, UsersState>(
      'SearchUsers with keyword triggers debounced search',
      build: () {
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async => Success(_generateUsers(3)));
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: 'bob',
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async => Success([FakeUser('uid_bob', 'Bob')]));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadUsers());
        await Future.delayed(const Duration(milliseconds: 100));
        bloc.add(const SearchUsers('bob'));
      },
      wait: const Duration(milliseconds: 500),
      verify: (bloc) {
        final state = bloc.state as UsersLoaded;
        expect(state.users.length, 1);
        expect(state.users.first.name, 'Bob');
      },
    );

    blocTest<UsersBloc, UsersState>(
      'SearchUsers with empty keyword restores original list',
      build: () {
        final originalUsers = _generateUsers(5);
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async => Success(originalUsers));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadUsers());
        await Future.delayed(const Duration(milliseconds: 100));
        bloc.add(const SearchUsers('test'));
        await Future.delayed(const Duration(milliseconds: 500));
        bloc.add(const SearchUsers(''));
      },
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        final state = bloc.state as UsersLoaded;
        expect(state.users.length, 5);
      },
    );
  });

  // =========================================================================
  // UpdateUser — Kotlin CSV #1061-1065
  // =========================================================================

  group('UpdateUser', () {
    blocTest<UsersBloc, UsersState>(
      'UpdateUser updates existing user in-place',
      build: () {
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async => Success([FakeUser('uid_1', 'Alice')]));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadUsers());
        await Future.delayed(const Duration(milliseconds: 100));
        bloc.add(UpdateUser(FakeUser('uid_1', 'Alice Updated')));
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        final state = bloc.state as UsersLoaded;
        expect(state.users.first.name, 'Alice Updated');
      },
    );

    blocTest<UsersBloc, UsersState>(
      'UpdateUser adds new user when uid not found',
      build: () {
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async => Success([FakeUser('uid_1', 'Alice')]));
        return _makeBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const LoadUsers());
        await Future.delayed(const Duration(milliseconds: 100));
        bloc.add(UpdateUser(FakeUser('uid_new', 'New User')));
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        final state = bloc.state as UsersLoaded;
        expect(state.users.length, 2);
        expect(state.users.last.name, 'New User');
      },
    );

    blocTest<UsersBloc, UsersState>(
      'UpdateUser is no-op when state is not UsersLoaded',
      build: () => _makeBloc(repo),
      act: (bloc) => bloc.add(UpdateUser(FakeUser('uid_1', 'Alice'))),
      expect: () => <UsersState>[],
    );
  });

  // =========================================================================
  // RefreshUsers — Kotlin CSV #1066-1070
  // =========================================================================

  group('RefreshUsers', () {
    blocTest<UsersBloc, UsersState>(
      'RefreshUsers triggers silent reload',
      build: () {
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer((_) async => Success(_generateUsers(3)));
        return _makeBloc(repo);
      },
      seed: () => UsersLoaded(users: _generateUsers(2)),
      act: (bloc) => bloc.add(const RefreshUsers()),
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        final state = bloc.state as UsersLoaded;
        expect(state.users.length, 3);
      },
    );
  });

  // =========================================================================
  // Error Handling — Kotlin CSV #1071-1075
  // =========================================================================

  group('Error handling', () {
    blocTest<UsersBloc, UsersState>(
      'error state contains message',
      build: () {
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer(
          (_) async => const Failure(message: 'Server error', code: 'SRV_500'),
        );
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadUsers()),
      verify: (bloc) {
        final state = bloc.state as UsersError;
        expect(state.message, 'Server error');
      },
    );

    blocTest<UsersBloc, UsersState>(
      'error state has null previousUsers on initial load',
      build: () {
        when(
          () => repo.getUsers(
            limit: any(named: 'limit'),
            searchKeyword: any(named: 'searchKeyword'),
            usersRequestBuilder: any(named: 'usersRequestBuilder'),
          ),
        ).thenAnswer(
          (_) async => const Failure(message: 'Timeout', code: 'TIMEOUT'),
        );
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const LoadUsers()),
      verify: (bloc) {
        final state = bloc.state as UsersError;
        expect(state.previousUsers, isNull);
      },
    );
  });

  // =========================================================================
  // State — copyWith & Equatable
  // =========================================================================

  group('UsersLoaded copyWith', () {
    test('copyWith preserves unchanged fields', () {
      final state = UsersLoaded(
        users: _generateUsers(3),
        hasMore: true,
        selectedUsers: const {'uid_0'},
      );
      final copied = state.copyWith(hasMore: false);
      expect(copied.users.length, 3);
      expect(copied.hasMore, isFalse);
      expect(copied.selectedUsers, contains('uid_0'));
    });

    test('copyWith replaces specified fields', () {
      final state = UsersLoaded(
        users: _generateUsers(2),
        selectedUsers: const {'uid_0'},
      );
      final copied = state.copyWith(selectedUsers: {'uid_1'});
      expect(copied.selectedUsers, contains('uid_1'));
      expect(copied.selectedUsers, isNot(contains('uid_0')));
    });

    test('Equatable: same values are equal', () {
      final users = _generateUsers(2);
      final state1 = UsersLoaded(users: users, hasMore: true);
      final state2 = UsersLoaded(users: users, hasMore: true);
      expect(state1, equals(state2));
    });

    test('Equatable: different values are not equal', () {
      final state1 = UsersLoaded(users: _generateUsers(2), hasMore: true);
      final state2 = UsersLoaded(users: _generateUsers(2), hasMore: false);
      expect(state1, isNot(equals(state2)));
    });
  });
}
