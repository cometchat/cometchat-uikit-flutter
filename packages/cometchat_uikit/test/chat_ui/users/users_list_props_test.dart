/// Render-verified prop matrix for [UsersList] — Track 3 PROP1 (ENG-38688,
/// coverage part 2).
///
/// UsersList is the list body [CometChatUsers] hands its bloc, style and theme
/// to. It is exported, so each row here constructs it directly with one prop
/// set to a sentinel, then asserts what the list rendered — a row, a Text, a
/// decoration, a Checkbox — or, for the bloc and the callbacks, what a real
/// build, tap or long-press sent to them.
///
/// The five required inputs (usersBloc, style, colorPalette, spacing,
/// typography) appear on every construction, so each one also has a row of
/// its own with its own sentinel. The shared base values below are chosen to
/// differ from every sentinel, so a row cannot pass by falling back to them.
///
/// Flags are asserted in both states, and the two states must differ.
///
///   flutter test test/chat_ui/users/users_list_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Mocks & fakes ───────────────────────────────────────────────────────────

class _MockUsersBloc extends MockBloc<UsersEvent, UsersState>
    implements UsersBloc {
  /// Every event the list sends, so rows can assert what reached the bloc.
  final events = <UsersEvent>[];

  final _status = <String, ValueNotifier<String>>{};

  /// UsersList reads a per-user presence notifier. MockBloc would return null
  /// into a non-nullable ValueNotifier, so real ones are supplied. Everyone is
  /// online, so every row carries a presence dot unless something hides it.
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

// ─── Fixtures ────────────────────────────────────────────────────────────────

/// Each name starts a new initial, so each row gets its own sticky title.
List<User> _users() => [
  _FakeUser(name: 'Alice', uid: 'u1'),
  _FakeUser(name: 'Bob', uid: 'u2'),
  _FakeUser(name: 'Carla', uid: 'u3'),
];

_MockUsersBloc _bloc(UsersState state) {
  final bloc = _MockUsersBloc();
  whenListen(bloc, Stream<UsersState>.value(state), initialState: state);
  return bloc;
}

/// `hasMore` is false so no load-more spinner row is appended.
_MockUsersBloc _loaded({Set<String> selected = const {}}) => _bloc(
  UsersLoaded(users: _users(), hasMore: false, selectedUsers: selected),
);

/// Base theme inputs. None of these values is reused as a sentinel.
final _palette = CometChatColorPalette(
  primary: const Color(0xFF131313),
  success: const Color(0xFF141414),
  background1: const Color(0xFF151515),
  background4: const Color(0xFF161616),
  iconHighlight: const Color(0xFF171717),
  borderDefault: const Color(0xFF181818),
  textPrimary: const Color(0xFF111111),
  textSecondary: const Color(0xFF121212),
  white: const Color(0xFFFEFEFE),
  transparent: const Color(0x00000000),
);

final _spacing = CometChatSpacing(
  padding1: 4,
  padding2: 8,
  padding3: 12,
  padding4: 16,
  padding5: 20,
  radius1: 4,
  radius2: 8,
);

const _typography = CometChatTypography(
  heading4: CometChatTextStyleHeading4(medium: TextStyle(fontSize: 16)),
);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

// ─── Probes ──────────────────────────────────────────────────────────────────

Translations _l10n(WidgetTester tester) =>
    Translations.of(tester.element(find.byType(UsersList)));

TextStyle? _styleOf(WidgetTester tester, Finder text) =>
    tester.widget<Text>(text).style;

/// CometChatListItem keys its row Container with the user's uid.
Finder _row(String uid) => find.byKey(ValueKey<String>(uid));

/// The first decorated Container inside [owner].
BoxDecoration _decorationIn(WidgetTester tester, Finder owner) => tester
    .widgetList<Container>(
      find.descendant(of: owner, matching: find.byType(Container)),
    )
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .first;

void main() {
  // ===========================================================================
  group('required inputs', () {
    testWidgets('usersBloc: its loaded state supplies the rows, and the next '
        'page is requested from it', (tester) async {
      final bloc = _bloc(
        UsersLoaded(
          users: [
            _FakeUser(name: 'Quillon', uid: 'q7'),
            _FakeUser(name: 'Zephyrine', uid: 'z9'),
          ],
        ),
      );
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: bloc,
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Quillon'), findsOneWidget);
      expect(find.text('Zephyrine'), findsOneWidget);
      // hasMore defaults to true, so the tail row asks this bloc for more.
      expect(bloc.events, contains(const LoadMoreUsers()));
    });

    testWidgets('usersBloc: Retry in its error state dispatches RefreshUsers', (
      tester,
    ) async {
      final bloc = _bloc(const UsersError(message: 'boom'));
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: bloc,
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
          ),
        ),
      );
      await tester.pump();
      expect(bloc.events, isNot(contains(const RefreshUsers())));

      await tester.tap(find.text(_l10n(tester).retry));
      await tester.pump();

      expect(bloc.events, contains(const RefreshUsers()));
    });

    testWidgets('style reaches the rows it styles', (tester) async {
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(
              stickyTitleColor: Color(0xFF1A2B3C),
            ),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
          ),
        ),
      );
      await tester.pump();

      expect(_styleOf(tester, find.text('A'))?.color, const Color(0xFF1A2B3C));
    });

    testWidgets('colorPalette supplies the unstyled title colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: CometChatColorPalette(
              textPrimary: const Color(0xFF2B3C4D),
            ),
            spacing: _spacing,
            typography: _typography,
          ),
        ),
      );
      await tester.pump();

      expect(
        _styleOf(tester, find.text('Alice'))?.color,
        const Color(0xFF2B3C4D),
      );
    });

    testWidgets('spacing pads each row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: CometChatSpacing(padding2: 5, padding4: 37),
            typography: _typography,
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<Container>(_row('u1')).padding,
        const EdgeInsets.fromLTRB(37, 5, 37, 5),
      );
    });

    testWidgets('typography sizes each name', (tester) async {
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: const CometChatTypography(
              heading4: CometChatTextStyleHeading4(
                medium: TextStyle(fontSize: 23.5),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_styleOf(tester, find.text('Alice'))?.fontSize, 23.5);
    });
  });

  // ===========================================================================
  group('scrolling', () {
    testWidgets('scrollController drives the list', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final many = [
        _FakeUser(name: 'Alice', uid: 'u1'),
        for (var i = 0; i < 30; i++) _FakeUser(name: 'Member $i', uid: 'm$i'),
      ];

      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _bloc(UsersLoaded(users: many, hasMore: false)),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            scrollController: controller,
          ),
        ),
      );
      await tester.pump();

      // A short jump keeps the first row on stage, where find.text sees it.
      expect(controller.hasClients, isTrue);
      final before = tester.getTopLeft(find.text('Alice')).dy;
      controller.jumpTo(20);
      await tester.pump();
      expect(tester.getTopLeft(find.text('Alice')).dy, before - 20);
    });
  });

  // ===========================================================================
  group('state views', () {
    testWidgets('loadingStateView replaces the shimmer', (tester) async {
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _bloc(const UsersLoading()),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CometChatShimmerEffect), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _bloc(const UsersLoading()),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            loadingStateView: (context) =>
                const SizedBox(key: Key('loading-sentinel')),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('loading-sentinel')), findsOneWidget);
      expect(find.byType(CometChatShimmerEffect), findsNothing);
    });

    testWidgets('emptyStateView replaces the empty state', (tester) async {
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _bloc(const UsersEmpty()),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            emptyStateView: (context) =>
                const SizedBox(key: Key('empty-sentinel')),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('empty-sentinel')), findsOneWidget);
      expect(find.text(_l10n(tester).usersUnavailable), findsNothing);
    });

    testWidgets('errorStateView replaces the error state', (tester) async {
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _bloc(const UsersError(message: 'boom')),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            errorStateView: (context) =>
                const SizedBox(key: Key('error-sentinel')),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('error-sentinel')), findsOneWidget);
      expect(find.text(_l10n(tester).retry), findsNothing);
    });
  });

  // ===========================================================================
  group('row slots', () {
    testWidgets('listItemView replaces each row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            listItemView: (user) => Text('row-${user.uid}'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('row-u1'), findsOneWidget);
      expect(find.text('row-u3'), findsOneWidget);
      expect(find.byType(CometChatListItem), findsNothing);
    });

    testWidgets('subtitleView renders inside its own row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            subtitleView: (context, user) => Text('sub-${user.uid}'),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(of: _row('u2'), matching: find.text('sub-u2')),
        findsOneWidget,
      );
    });

    testWidgets('trailingView renders inside its own row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            trailingView: (context, user) => Text('trail-${user.uid}'),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(of: _row('u3'), matching: find.text('trail-u3')),
        findsOneWidget,
      );
    });

    testWidgets('leadingView replaces the avatar', (tester) async {
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            leadingView: (context, user) => Text('lead-${user.uid}'),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(of: _row('u1'), matching: find.text('lead-u1')),
        findsOneWidget,
      );
      expect(find.byType(CometChatAvatar), findsNothing);
    });

    testWidgets('titleView replaces the name', (tester) async {
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            titleView: (context, user) => Text('title-${user.uid}'),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(of: _row('u1'), matching: find.text('title-u1')),
        findsOneWidget,
      );
      expect(find.text('Alice'), findsNothing);
    });

    testWidgets('avatarStyle reaches each avatar', (tester) async {
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            avatarStyle: const CometChatAvatarStyle(
              backgroundColor: Color(0xFF3C4D5E),
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFF4D5E6F), width: 2),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final avatar = _decorationIn(tester, find.byType(CometChatAvatar).first);
      expect(avatar.color, const Color(0xFF3C4D5E));
      expect(
        avatar.border,
        const Border.fromBorderSide(
          BorderSide(color: Color(0xFF4D5E6F), width: 2),
        ),
      );
    });

    testWidgets('statusIndicatorStyle reaches each presence dot', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            statusIndicatorStyle: const CometChatStatusIndicatorStyle(
              backgroundColor: Color(0xFF5E6F70),
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFF6F7081), width: 1.5),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final dot = _decorationIn(
        tester,
        find.byType(CometChatStatusIndicator).first,
      );
      expect(dot.color, const Color(0xFF5E6F70));
      expect(
        dot.border,
        const Border.fromBorderSide(
          BorderSide(color: Color(0xFF6F7081), width: 1.5),
        ),
      );
    });
  });

  // ===========================================================================
  group('flags', () {
    testWidgets('usersStatusVisibility false hides the presence dots', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
          ),
        ),
      );
      await tester.pump();
      final byDefault = find.byType(CometChatStatusIndicator).evaluate().length;

      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            usersStatusVisibility: false,
          ),
        ),
      );
      await tester.pump();
      final hidden = find.byType(CometChatStatusIndicator).evaluate().length;

      expect(byDefault, 3);
      expect(hidden, 0);
    });

    testWidgets('stickyHeaderVisibility true drops the inline initials', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
          ),
        ),
      );
      await tester.pump();
      final byDefault = [
        'A',
        'B',
        'C',
      ].where((i) => find.text(i).evaluate().isNotEmpty).length;

      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            stickyHeaderVisibility: true,
          ),
        ),
      );
      await tester.pump();
      final sticky = [
        'A',
        'B',
        'C',
      ].where((i) => find.text(i).evaluate().isNotEmpty).length;

      expect(byDefault, 3);
      expect(sticky, 0);
    });

    testWidgets('selectionMode multiple adds a checkbox to every row', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
          ),
        ),
      );
      await tester.pump();
      final byDefault = find.byType(Checkbox).evaluate().length;

      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            selectionMode: SelectionMode.multiple,
          ),
        ),
      );
      await tester.pump();
      final selecting = find.byType(Checkbox).evaluate().length;

      expect(byDefault, 0);
      expect(selecting, 3);
    });
  });

  // ===========================================================================
  group('interaction', () {
    testWidgets('onItemTap fires with the tapped user', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            onItemTap: (context, user) => tapped.add(user.uid),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Bob'));
      await tester.pump();
      expect(tapped, ['u2']);
    });

    testWidgets('onItemLongPress fires with the pressed user', (tester) async {
      final pressed = <String>[];
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: _loaded(),
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            onItemLongPress: (context, user) => pressed.add(user.uid),
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.text('Carla'));
      await tester.pump();
      expect(pressed, ['u3']);
    });

    testWidgets('activateSelection onClick turns a tap into a toggle', (
      tester,
    ) async {
      final tapped = <String>[];
      final plain = _loaded();
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: plain,
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            onItemTap: (context, user) => tapped.add(user.uid),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Alice'));
      await tester.pump();

      final selecting = _loaded();
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: selecting,
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            activateSelection: ActivateSelection.onClick,
            onItemTap: (context, user) => tapped.add(user.uid),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Alice'));
      await tester.pump();

      // Default: the tap reached onItemTap and toggled nothing.
      expect(plain.events.whereType<ToggleUserSelection>(), isEmpty);
      // onClick: the tap toggled u1 and did not reach onItemTap.
      expect(selecting.events, contains(const ToggleUserSelection('u1')));
      expect(tapped, ['u1']);
    });

    testWidgets('activateSelection onLongClick turns a long-press into a '
        'toggle', (tester) async {
      final pressed = <String>[];
      final plain = _loaded();
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: plain,
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            onItemLongPress: (context, user) => pressed.add(user.uid),
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.text('Bob'));
      await tester.pump();

      final selecting = _loaded();
      await tester.pumpWidget(
        _wrap(
          UsersList(
            usersBloc: selecting,
            style: const CometChatUsersStyle(),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
            activateSelection: ActivateSelection.onLongClick,
            onItemLongPress: (context, user) => pressed.add(user.uid),
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.text('Bob'));
      await tester.pump();

      expect(plain.events.whereType<ToggleUserSelection>(), isEmpty);
      expect(selecting.events, contains(const ToggleUserSelection('u2')));
      expect(pressed, ['u2']);
    });
  });
}
