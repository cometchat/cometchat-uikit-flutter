/// Golden pins for [CometChatUsers]: its rows and the three state views.
///
/// The real screen is rendered (app bar, search box, sticky headers, rows),
/// held in a fixed state through its `usersBloc` seam. Avatars have no URL, so
/// they fall back to initials and nothing touches the network.
///
///   flutter test test/chat_ui/users/goldens/                  # verify
///   flutter test test/chat_ui/users/goldens/ --update-goldens # rebake
library;

import 'package:alchemist/alchemist.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

import '../../../helpers/golden_config.dart';
import '../../../helpers/golden_harness.dart';

class _MockUsersBloc extends MockBloc<UsersEvent, UsersState>
    implements UsersBloc {
  _MockUsersBloc(this._users);

  final List<User> _users;
  final _status = <String, ValueNotifier<String>>{};

  /// The row reads presence from a per-user notifier, not from `user.status`.
  /// MockBloc would return null into a non-nullable ValueNotifier, so real
  /// ones are supplied, seeded from the fixture.
  @override
  ValueNotifier<String> getStatusNotifier(String uid) => _status.putIfAbsent(
    uid,
    () => ValueNotifier<String>(
      _users
              .where((u) => u.uid == uid)
              .map((u) => u.status)
              .whereType<String>()
              .firstOrNull ??
          UserStatusConstants.offline,
    ),
  );

  @override
  // ignore: must_call_super
  void add(UsersEvent event) {}
}

List<User> _users() => [
  User(uid: 'u-aisha', name: 'Aisha Khan', status: 'online'),
  User(uid: 'u-andre', name: 'Andre Lima', status: 'offline'),
  User(uid: 'u-bianca', name: 'Bianca Rossi', status: 'online'),
  User(uid: 'u-chen', name: 'Chen Wei', status: 'offline'),
  User(uid: 'u-dmitri', name: 'Dmitri Volkov', status: 'online'),
];

_MockUsersBloc _bloc(UsersState state) {
  final bloc = _MockUsersBloc(state is UsersLoaded ? state.users : const []);
  whenListen(bloc, Stream<UsersState>.value(state), initialState: state);
  return bloc;
}

const _listSize = Size(375, 520);
const _stateSize = Size(375, 520);

void main() {
  AlchemistConfig.runWithConfig(
    config: goldenConfig(),
    run: () {
      lightDarkGolden(
        'users list, online and offline rows under sticky headers',
        fileName: 'users_list_loaded',
        size: _listSize,
        builder: () => CometChatUsers(
          usersBloc: _bloc(UsersLoaded(users: _users(), hasMore: false)),
        ),
      );

      lightDarkGolden(
        'users list in multi-select, two rows checked',
        fileName: 'users_list_selection',
        size: _listSize,
        builder: () => CometChatUsers(
          selectionMode: SelectionMode.multiple,
          activateSelection: ActivateSelection.onClick,
          usersBloc: _bloc(
            UsersLoaded(
              users: _users(),
              hasMore: false,
              selectedUsers: const {'u-aisha', 'u-chen'},
            ),
          ),
        ),
      );

      lightDarkGolden(
        'users empty state',
        fileName: 'users_state_empty',
        size: _stateSize,
        builder: () => CometChatUsers(usersBloc: _bloc(const UsersEmpty())),
      );

      lightDarkGolden(
        'users error state',
        fileName: 'users_state_error',
        size: _stateSize,
        builder: () => CometChatUsers(
          usersBloc: _bloc(const UsersError(message: 'Something went wrong')),
        ),
      );

      // The loading (shimmer) state has no golden on purpose. The shimmer is an
      // animation, so the frame that gets rasterised depends on where its
      // controller happens to be: baked on macOS these passed locally and
      // failed on CI's Linux runner, in all five list components. A golden of
      // an animating gradient pins timing, not layout. The loading views keep
      // their widget-test coverage instead (ENG-38688).
    },
  );
}
