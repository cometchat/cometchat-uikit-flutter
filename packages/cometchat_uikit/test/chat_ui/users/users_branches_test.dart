/// The [CometChatUsers] and [CometChatGroups] branches the prop matrices do
/// not reach: the events the search box and the selection chrome dispatch, and
/// the path a screen takes when no bloc is injected.
///
/// The matrices pin what renders; this pins what each affordance *does*.
/// Searching and clearing a selection are the two gestures whose failure is
/// completely silent — the box still types and the arrow still draws.
///
///   flutter test test/chat_ui/users/users_branches_test.dart
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Mocks & fakes ───────────────────────────────────────────────────────────

/// Unlike the prop matrix's mock, `add` is left alone so dispatched events can
/// be verified.
class MockUsersBloc extends MockBloc<UsersEvent, UsersState>
    implements UsersBloc {
  final _status = <String, ValueNotifier<String>>{};

  @override
  ValueNotifier<String> getStatusNotifier(String uid) =>
      _status.putIfAbsent(uid, () => ValueNotifier<String>('online'));
}

class MockGroupsBloc extends MockBloc<GroupsEvent, GroupsState>
    implements GroupsBloc {}

class FakeUser extends Fake implements User {
  FakeUser({this.name = 'Alice', this.uid = 'u1', this.status = 'online'});

  @override
  final String name;
  @override
  final String uid;
  @override
  final String status;
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

class FakeGroup extends Fake implements Group {
  FakeGroup({this.name = 'Dev Team', this.guid = 'g1', this.type = 'public'});

  @override
  final String name;
  @override
  final String guid;
  @override
  final String type;
  @override
  String? get icon => null;
  @override
  int get membersCount => 4;
  @override
  bool get hasJoined => true;
}

List<User> _users() => [
  FakeUser(name: 'Alice', uid: 'u1'),
  FakeUser(name: 'Bob', uid: 'u2', status: 'offline'),
];

MockUsersBloc _usersBloc({Set<String> selected = const {}}) {
  final bloc = MockUsersBloc();
  final state = UsersLoaded(users: _users(), selectedUsers: selected);
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, Stream<UsersState>.value(state), initialState: state);
  return bloc;
}

MockGroupsBloc _groupsBloc({Set<String> selected = const {}}) {
  final bloc = MockGroupsBloc();
  final state = GroupsLoaded(
    groups: [
      FakeGroup(),
      FakeGroup(name: 'Design', guid: 'g2'),
    ],
    selectedGroups: selected,
  );
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, Stream<GroupsState>.value(state), initialState: state);
  return bloc;
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

Future<void> _pump(WidgetTester tester, Widget child) =>
    mockNetworkImagesFor(() async {
      await tester.pumpWidget(child);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

void main() {
  setUpAll(() {
    registerFallbackValue(const LoadUsers());
    registerFallbackValue(const LoadGroups());
  });

  // =========================================================================
  group('CometChatUsers', () {
    testWidgets('typing in the search box dispatches SearchUsers', (
      tester,
    ) async {
      final bloc = _usersBloc();

      await _pump(tester, _wrap(CometChatUsers(usersBloc: bloc)));
      await tester.enterText(find.byType(TextField), 'ali');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final captured = verify(
        () => bloc.add(captureAny(that: isA<SearchUsers>())),
      ).captured;
      expect((captured.last as SearchUsers).keyword, 'ali');
    });

    testWidgets('the clear-selection arrow dispatches ClearUserSelection', (
      tester,
    ) async {
      final bloc = _usersBloc(selected: const {'u1'});

      await _pump(
        tester,
        _wrap(
          CometChatUsers(
            usersBloc: bloc,
            selectionMode: SelectionMode.multiple,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      verify(() => bloc.add(any(that: isA<ClearUserSelection>()))).called(1);
    });

    testWidgets('the submit control reports the selected users', (
      tester,
    ) async {
      List<User>? submitted;

      await _pump(
        tester,
        _wrap(
          CometChatUsers(
            usersBloc: _usersBloc(selected: const {'u2'}),
            selectionMode: SelectionMode.multiple,
            onSelection: (users, _) => submitted = users,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      expect(submitted?.map((u) => u.uid), ['u2']);
    });

    testWidgets('with no selection there is no submit control', (tester) async {
      await _pump(
        tester,
        _wrap(
          CometChatUsers(
            usersBloc: _usersBloc(),
            selectionMode: SelectionMode.multiple,
            onSelection: (_, _) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('without an injected bloc the screen builds its own', (
      tester,
    ) async {
      // This is the path every integrator who does not inject a bloc takes:
      // the service locator is set up and the screen owns the bloc it closes
      // on dispose.
      await runZonedGuarded(() async {
        await _pump(tester, _wrap(const CometChatUsers()));
      }, (_, _) {});
      while (tester.takeException() != null) {}

      expect(find.byType(CometChatUsers), findsOneWidget);

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      await tester.pump();
      while (tester.takeException() != null) {}

      expect(find.byType(CometChatUsers), findsNothing);
    });
  });

  // =========================================================================
  group('CometChatGroups', () {
    testWidgets('typing in the search box dispatches SearchGroups', (
      tester,
    ) async {
      final bloc = _groupsBloc();

      await _pump(tester, _wrap(CometChatGroups(groupsBloc: bloc)));
      await tester.enterText(find.byType(TextField), 'dev');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final captured = verify(
        () => bloc.add(captureAny(that: isA<SearchGroups>())),
      ).captured;
      expect((captured.last as SearchGroups).keyword, 'dev');
    });

    testWidgets('the clear-selection arrow dispatches ClearGroupSelection', (
      tester,
    ) async {
      final bloc = _groupsBloc(selected: const {'g1'});

      await _pump(
        tester,
        _wrap(
          CometChatGroups(
            groupsBloc: bloc,
            selectionMode: SelectionMode.multiple,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      verify(() => bloc.add(any(that: isA<ClearGroupSelection>()))).called(1);
    });

    testWidgets('without an injected bloc the screen builds its own', (
      tester,
    ) async {
      // The internally-built bloc reaches the SDK immediately; with none
      // initialised the data source raises into the zone. The screen must
      // still mount and tear down.
      await runZonedGuarded(() async {
        await _pump(tester, _wrap(const CometChatGroups()));
      }, (_, _) {});
      while (tester.takeException() != null) {}

      expect(find.byType(CometChatGroups), findsOneWidget);

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      await tester.pump();
      while (tester.takeException() != null) {}

      expect(find.byType(CometChatGroups), findsNothing);
    });
  });
}
