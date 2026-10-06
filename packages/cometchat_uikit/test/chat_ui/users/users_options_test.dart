/// Long-press options on [CometChatUsers] and [UsersList] — ENG-38688.
///
/// Android's CometChatUsers takes `setOptions` and `addOptions`, and its menu
/// is the `setOptions` list when there is one, else the `addOptions` list
/// (`buildMenuItems`). v5 Flutter had both; v6 had neither until 6.2.0. A long
/// press goes, in order, to: starting a long-press selection, then
/// `onItemLongPress`, then the menu.
///
/// Each test constructs the widget inline and asserts on what the long press
/// rendered or dispatched, so every one fails if the prop stops being read.
///
///   flutter test test/chat_ui/users/users_options_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Mocks & fakes ───────────────────────────────────────────────────────────

class _MockUsersBloc extends MockBloc<UsersEvent, UsersState>
    implements UsersBloc {
  /// Everything the component dispatched, so the selection case can assert
  /// that the long press started a selection.
  final events = <UsersEvent>[];

  final _status = <String, ValueNotifier<String>>{};

  /// UsersList reads a per-user presence notifier; MockBloc would return null
  /// into a non-nullable ValueNotifier.
  @override
  ValueNotifier<String> getStatusNotifier(String uid) => _status.putIfAbsent(
    uid,
    () => ValueNotifier<String>(UserStatusConstants.online),
  );

  @override
  // ignore: must_call_super
  void add(UsersEvent event) => events.add(event);
}

class _FakeUser extends Fake implements User {
  _FakeUser({required this.name, required this.uid});

  @override
  final String name;
  @override
  final String uid;
  @override
  String get status => UserStatusConstants.online;
  @override
  String? get avatar => null;
  @override
  String? get role => 'default';
  @override
  String? get link => null;
  @override
  bool? get blockedByMe => false;
  @override
  bool? get hasBlockedMe => false;
  @override
  DateTime? get lastActiveAt => null;
}

List<User> _users() => [
  _FakeUser(name: 'Alice', uid: 'u1'),
  _FakeUser(name: 'Bob', uid: 'u2'),
  _FakeUser(name: 'Carla', uid: 'u3'),
];

/// `hasMore` is false so no load-more row is appended.
_MockUsersBloc _loaded({Set<String> selected = const {}}) {
  final state = UsersLoaded(
    users: _users(),
    hasMore: false,
    selectedUsers: selected,
  );
  final bloc = _MockUsersBloc();
  whenListen(bloc, Stream<UsersState>.value(state), initialState: state);
  return bloc;
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

/// Long-presses [row] and lets the menu's entrance animation finish.
Future<void> _longPress(WidgetTester tester, String row) async {
  await tester.longPress(find.text(row));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Taps [option] in the open menu and lets it close.
Future<void> _choose(WidgetTester tester, String option) async {
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
}

final _menuEntries = find.byType(CustomPopupMenuItem<CometChatOption>);

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('CometChatUsers', () {
    testWidgets('setOptions: a long press opens its menu on that user and '
        'runs the chosen option once', (tester) async {
      final bloc = _loaded();
      final built = <Object>[];
      final chosen = <String>[];
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: bloc,
              setOptions: (user, usersBloc, context) {
                built.add([user.uid, identical(usersBloc, bloc)]);
                return [
                  CometChatOption(
                    id: 'mute',
                    title: 'Mute ${user.name}',
                    onClick: () => chosen.add(user.uid),
                  ),
                ];
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Mute Bob'), findsNothing);

      await _longPress(tester, 'Bob');
      expect(built, [
        ['u2', true],
      ]);
      expect(find.text('Mute Bob'), findsOneWidget);

      await _choose(tester, 'Mute Bob');
      expect(chosen, ['u2']);
      expect(find.text('Mute Bob'), findsNothing);
    });

    testWidgets('addOptions: on its own a long press opens its menu', (
      tester,
    ) async {
      final chosen = <String>[];
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loaded(),
              addOptions: (user, usersBloc, context) => [
                CometChatOption(
                  id: 'star',
                  title: 'Star ${user.name}',
                  onClick: () => chosen.add(user.uid),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Star Carla'), findsNothing);

      await _longPress(tester, 'Carla');
      expect(find.text('Star Carla'), findsOneWidget);

      await _choose(tester, 'Star Carla');
      expect(chosen, ['u3']);
    });

    testWidgets('setOptions wins over addOptions, as on Android', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loaded(),
              setOptions: (user, usersBloc, context) => [
                CometChatOption(id: 'set', title: 'SET-5Z'),
              ],
              addOptions: (user, usersBloc, context) => [
                CometChatOption(id: 'added', title: 'ADDED-5Z'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      await _longPress(tester, 'Alice');
      expect(find.text('SET-5Z'), findsOneWidget);
      expect(find.text('ADDED-5Z'), findsNothing);
      expect(_menuEntries, findsOneWidget);
    });

    testWidgets('onItemLongPress takes the long press ahead of the menu', (
      tester,
    ) async {
      final pressed = <String>[];
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loaded(),
              onItemLongPress: (context, user) => pressed.add(user.uid),
              setOptions: (user, usersBloc, context) => [
                CometChatOption(id: 'set', title: 'SET-5Z'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      await _longPress(tester, 'Bob');
      expect(pressed, ['u2']);
      expect(find.text('SET-5Z'), findsNothing);
    });

    testWidgets('a long-press selection starts ahead of the menu, and the '
        'menu opens once a selection is running', (tester) async {
      final idle = _loaded();
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: idle,
              selectionMode: SelectionMode.multiple,
              activateSelection: ActivateSelection.onLongClick,
              setOptions: (user, usersBloc, context) => [
                CometChatOption(id: 'set', title: 'SET-5Z'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      await _longPress(tester, 'Alice');
      expect(idle.events.whereType<ToggleUserSelection>(), [
        const ToggleUserSelection('u1'),
      ]);
      expect(find.text('SET-5Z'), findsNothing);

      // With a selection already running, the long press is not a selection
      // start, so it falls through to the menu.
      final selecting = _loaded(selected: {'u2'});
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              key: const ValueKey('selecting'),
              usersBloc: selecting,
              selectionMode: SelectionMode.multiple,
              activateSelection: ActivateSelection.onLongClick,
              setOptions: (user, usersBloc, context) => [
                CometChatOption(id: 'set', title: 'SET-5Z'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      await _longPress(tester, 'Alice');
      expect(selecting.events.whereType<ToggleUserSelection>(), isEmpty);
      expect(find.text('SET-5Z'), findsOneWidget);
    });

    testWidgets('setOptions returning null or nothing opens no menu', (
      tester,
    ) async {
      final built = <String>[];
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loaded(),
              setOptions: (user, usersBloc, context) {
                built.add(user.uid);
                return user.uid == 'u1' ? null : const [];
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await _longPress(tester, 'Alice');
      await _longPress(tester, 'Bob');
      expect(built, ['u1', 'u2']);
      expect(_menuEntries, findsNothing);
    });
  });

  group('UsersList', () {
    testWidgets('options: a long press opens its menu over that user and runs '
        'the chosen option', (tester) async {
      final built = <String>[];
      final chosen = <String>[];
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: CometChatColorPalette(),
            spacing: CometChatSpacing(),
            typography: const CometChatTypography(),
            options: (context, user) {
              built.add(user.uid);
              return [
                CometChatOption(
                  id: 'mute',
                  title: 'Mute ${user.name}',
                  onClick: () => chosen.add(user.uid),
                ),
              ];
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Mute Carla'), findsNothing);

      await _longPress(tester, 'Carla');
      expect(built, ['u3']);
      expect(find.text('Mute Carla'), findsOneWidget);
      // Anchored on the pressed row, not the top of the screen: the menu
      // starts below the first row.
      expect(
        tester.getTopLeft(find.text('Mute Carla')).dy,
        greaterThan(tester.getBottomLeft(find.text('Alice')).dy),
      );

      await _choose(tester, 'Mute Carla');
      expect(chosen, ['u3']);
      expect(find.text('Mute Carla'), findsNothing);
    });

    testWidgets('options: an empty list opens no menu, and onItemLongPress '
        'takes the press ahead of it', (tester) async {
      final pressed = <String>[];
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: CometChatColorPalette(),
            spacing: CometChatSpacing(),
            typography: const CometChatTypography(),
            options: (context, user) => const [],
          ),
        ),
      );
      await tester.pump();
      await _longPress(tester, 'Alice');
      expect(_menuEntries, findsNothing);

      await tester.pumpWidget(
        _wrap(
          UsersList(
            key: const ValueKey('with-callback'),
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: CometChatColorPalette(),
            spacing: CometChatSpacing(),
            typography: const CometChatTypography(),
            onItemLongPress: (context, user) => pressed.add(user.uid),
            options: (context, user) => [
              CometChatOption(id: 'mute', title: 'Mute ${user.name}'),
            ],
          ),
        ),
      );
      await tester.pump();
      await _longPress(tester, 'Bob');
      expect(pressed, ['u2']);
      expect(find.text('Mute Bob'), findsNothing);
    });
  });
}
