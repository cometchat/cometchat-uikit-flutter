/// Render-verified style matrix for [CometChatUsersStyle] — Track 3 PROP1
/// (ENG-38688, coverage part 2).
///
/// `users_props_test.dart` already renders eight of the 43 props (the heading,
/// the back icon, the container and the search text). This file covers the
/// other 35, one row per prop: pump [CometChatUsers] with that prop set to a
/// sentinel no theme uses, find the widget that actually paints it, and compare.
/// Every assertion reads the painter — the Checkbox, the row's Container, a
/// Text, the AppBar's shape — never the style object, so each one fails if the
/// component stops reading the prop.
///
/// Rows are grouped by the child that paints them:
///
///   search row, frame, separator ... CometChatListBase, via ListBaseStyle
///   submit icon ..................... CometChatUsers' selection action
///   checkboxes, selected row ........ UsersList
///   title, border, avatar, dot ...... CometChatListItem, via UsersList
///   initials ........................ SectionSeparator, via UsersList
///   empty and error states .......... UsersList / UIStateUtils
///
/// Five props have no row: retryButtonBackgroundColor, retryButtonBorder,
/// retryButtonBorderRadius, retryButtonTextColor and retryButtonTextStyle.
/// `UsersList._buildErrorState` (users_list.dart:179-189) hands
/// `UIStateUtils.getDefaultErrorStateView` the four error-text props and none
/// of the button ones, although that helper accepts all five. They are
/// recorded as defects rather than covered by a test written around them.
///
///   flutter test test/chat_ui/users/users_style_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Mocks & fakes ───────────────────────────────────────────────────────────

class _MockUsersBloc extends MockBloc<UsersEvent, UsersState>
    implements UsersBloc {
  final _status = <String, ValueNotifier<String>>{};

  /// UsersList reads a per-user presence notifier. MockBloc would return null
  /// into a non-nullable ValueNotifier, so real ones are supplied. Everyone is
  /// online, so every row carries a presence dot.
  @override
  ValueNotifier<String> getStatusNotifier(String uid) => _status.putIfAbsent(
    uid,
    () => ValueNotifier<String>(UserStatusConstants.online),
  );

  @override
  // ignore: must_call_super
  void add(UsersEvent event) {
    // No-op: these rows assert rendering, not event handling.
  }
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

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

// ─── Probes: each returns what a painter was actually handed ─────────────────

Translations _l10n(WidgetTester tester) =>
    Translations.of(tester.element(find.byType(UsersList)));

TextStyle? _styleOf(WidgetTester tester, Finder text) =>
    tester.widget<Text>(text).style;

InputDecoration _searchDecoration(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).decoration!;

OutlineInputBorder _searchOutline(WidgetTester tester) =>
    _searchDecoration(tester).enabledBorder! as OutlineInputBorder;

/// CometChatListBase draws the separator under the app bar as its shape.
BorderSide _appBarBottom(WidgetTester tester) =>
    (tester.widget<AppBar>(find.byType(AppBar)).shape! as Border).bottom;

Checkbox _checkbox(WidgetTester tester, {required bool checked}) => tester
    .widgetList<Checkbox>(find.byType(Checkbox))
    .firstWhere((c) => c.value == checked);

/// CometChatListItem keys its row Container with the user's uid.
BoxDecoration _rowDecoration(WidgetTester tester, String uid) =>
    tester.widget<Container>(find.byKey(ValueKey<String>(uid))).decoration!
        as BoxDecoration;

/// The first decorated Container inside [owner].
BoxDecoration _decorationIn(WidgetTester tester, Finder owner) => tester
    .widgetList<Container>(
      find.descendant(of: owner, matching: find.byType(Container)),
    )
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .first;

Iterable<BoxBorder?> _allBorders(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .map((d) => d.border);

void main() {
  // ===========================================================================
  group('search row — painted by CometChatListBase', () {
    testWidgets('searchBackgroundColor fills the search field', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(),
            usersStyle: const CometChatUsersStyle(
              searchBackgroundColor: Color(0xFF1A2B3C),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_searchDecoration(tester).fillColor, const Color(0xFF1A2B3C));
    });

    testWidgets('searchBorder outlines the search field', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(),
            usersStyle: const CometChatUsersStyle(
              searchBorder: BorderSide(color: Color(0xFF2B3C4D), width: 2.5),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        _searchOutline(tester).borderSide,
        const BorderSide(color: Color(0xFF2B3C4D), width: 2.5),
      );
    });

    testWidgets('searchBorderRadius rounds the search field', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(),
            usersStyle: const CometChatUsersStyle(
              searchBorderRadius: BorderRadius.all(Radius.circular(9)),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        _searchOutline(tester).borderRadius,
        const BorderRadius.all(Radius.circular(9)),
      );
    });

    testWidgets('searchIconColor tints the magnifier', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(),
            usersStyle: const CometChatUsersStyle(
              searchIconColor: Color(0xFF3C4D5E),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<Icon>(find.byIcon(Icons.search)).color,
        const Color(0xFF3C4D5E),
      );
    });

    testWidgets('searchPlaceHolderTextStyle styles the rendered hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(),
            searchPlaceholder: 'Find someone',
            usersStyle: const CometChatUsersStyle(
              searchPlaceHolderTextStyle: TextStyle(fontSize: 17.5),
            ),
          ),
        ),
      );
      await tester.pump();

      final hint = find.descendant(
        of: find.byType(TextField),
        matching: find.text('Find someone'),
      );
      expect(_styleOf(tester, hint)?.fontSize, 17.5);
    });
  });

  // ===========================================================================
  group('frame — painted by CometChatListBase', () {
    testWidgets('border outlines the component container', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(),
            usersStyle: const CometChatUsersStyle(
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFF4D5E6F), width: 3),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        _allBorders(tester),
        contains(
          const Border.fromBorderSide(
            BorderSide(color: Color(0xFF4D5E6F), width: 3),
          ),
        ),
      );
    });

    testWidgets('separatorColor colours the rule under the app bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(),
            usersStyle: const CometChatUsersStyle(
              separatorColor: Color(0xFF5E6F70),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_appBarBottom(tester).color, const Color(0xFF5E6F70));
    });

    testWidgets('separatorHeight sets the rule thickness', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(),
            usersStyle: const CometChatUsersStyle(separatorHeight: 3.5),
          ),
        ),
      );
      await tester.pump();

      expect(_appBarBottom(tester).width, 3.5);
    });
  });

  // ===========================================================================
  group('selection — submit action, checkboxes and the selected row', () {
    testWidgets('submitIconColor tints the default submit check', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(selected: {'u1'}),
            selectionMode: SelectionMode.multiple,
            usersStyle: const CometChatUsersStyle(
              submitIconColor: Color(0xFF6F7081),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<Icon>(find.byIcon(Icons.check)).color,
        const Color(0xFF6F7081),
      );
    });

    testWidgets('checkBoxBackgroundColor fills an unchecked box', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(),
            selectionMode: SelectionMode.multiple,
            usersStyle: const CometChatUsersStyle(
              checkBoxBackgroundColor: Color(0xFF708192),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = _checkbox(tester, checked: false);
      expect(box.fillColor?.resolve(<WidgetState>{}), const Color(0xFF708192));
    });

    testWidgets('checkBoxBorder outlines an unchecked box', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(),
            selectionMode: SelectionMode.multiple,
            usersStyle: const CometChatUsersStyle(
              checkBoxBorder: BorderSide(color: Color(0xFF8192A3), width: 2.5),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        _checkbox(tester, checked: false).side,
        const BorderSide(color: Color(0xFF8192A3), width: 2.5),
      );
    });

    testWidgets('checkBoxBorderRadius rounds the box', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(),
            selectionMode: SelectionMode.multiple,
            usersStyle: const CometChatUsersStyle(
              checkBoxBorderRadius: BorderRadius.all(Radius.circular(7)),
            ),
          ),
        ),
      );
      await tester.pump();

      final shape =
          _checkbox(tester, checked: false).shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, const BorderRadius.all(Radius.circular(7)));
    });

    testWidgets('checkBoxCheckedBackgroundColor fills a checked box', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(selected: {'u1'}),
            selectionMode: SelectionMode.multiple,
            usersStyle: const CometChatUsersStyle(
              checkBoxCheckedBackgroundColor: Color(0xFF92A3B4),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = _checkbox(tester, checked: true);
      expect(
        box.fillColor?.resolve(<WidgetState>{WidgetState.selected}),
        const Color(0xFF92A3B4),
      );
      expect(box.activeColor, const Color(0xFF92A3B4));
    });

    testWidgets('checkboxSelectedIconColor colours the tick', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(selected: {'u1'}),
            selectionMode: SelectionMode.multiple,
            usersStyle: const CometChatUsersStyle(
              checkboxSelectedIconColor: Color(0xFFA3B4C5),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        _checkbox(tester, checked: true).checkColor,
        const Color(0xFFA3B4C5),
      );
    });

    testWidgets('listItemSelectedBackgroundColor paints only selected rows', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(selected: {'u1'}),
            usersStyle: const CometChatUsersStyle(
              listItemSelectedBackgroundColor: Color(0xFFB4C5D6),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_rowDecoration(tester, 'u1').color, const Color(0xFFB4C5D6));
      expect(
        _rowDecoration(tester, 'u2').color,
        isNot(const Color(0xFFB4C5D6)),
      );
    });
  });

  // ===========================================================================
  group('rows — painted by CometChatListItem', () {
    testWidgets('itemTitleTextColor colours each name', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(),
            usersStyle: const CometChatUsersStyle(
              itemTitleTextColor: Color(0xFFC5D6E7),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        _styleOf(tester, find.text('Alice'))?.color,
        const Color(0xFFC5D6E7),
      );
    });

    testWidgets('itemTitleTextStyle styles each name', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(),
            usersStyle: const CometChatUsersStyle(
              itemTitleTextStyle: TextStyle(fontSize: 22.5),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_styleOf(tester, find.text('Alice'))?.fontSize, 22.5);
    });

    testWidgets('itemBorder outlines each row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(),
            usersStyle: const CometChatUsersStyle(
              itemBorder: Border.fromBorderSide(
                BorderSide(color: Color(0xFFD6E7F8), width: 2),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        _rowDecoration(tester, 'u1').border,
        const Border.fromBorderSide(
          BorderSide(color: Color(0xFFD6E7F8), width: 2),
        ),
      );
    });

    testWidgets('avatarStyle reaches the row avatar', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(),
            usersStyle: const CometChatUsersStyle(
              avatarStyle: CometChatAvatarStyle(
                backgroundColor: Color(0xFFE7F809),
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFF0A1B2C), width: 2),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final avatar = _decorationIn(tester, find.byType(CometChatAvatar).first);
      expect(avatar.color, const Color(0xFFE7F809));
      expect(
        avatar.border,
        const Border.fromBorderSide(
          BorderSide(color: Color(0xFF0A1B2C), width: 2),
        ),
      );
    });

    testWidgets('statusIndicatorStyle reaches the presence dot', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(),
            usersStyle: const CometChatUsersStyle(
              statusIndicatorStyle: CometChatStatusIndicatorStyle(
                backgroundColor: Color(0xFF1B2C3D),
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFF2C3D4E), width: 1.5),
                ),
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
      expect(dot.color, const Color(0xFF1B2C3D));
      expect(
        dot.border,
        const Border.fromBorderSide(
          BorderSide(color: Color(0xFF2C3D4E), width: 1.5),
        ),
      );
    });
  });

  // ===========================================================================
  group('initials — painted by SectionSeparator', () {
    testWidgets('stickyTitleColor colours the initial', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(),
            usersStyle: const CometChatUsersStyle(
              stickyTitleColor: Color(0xFF3D4E5F),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_styleOf(tester, find.text('A'))?.color, const Color(0xFF3D4E5F));
    });

    testWidgets('stickyTitleTextStyle styles the initial', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _loaded(),
            usersStyle: const CometChatUsersStyle(
              stickyTitleTextStyle: TextStyle(fontSize: 19.5),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_styleOf(tester, find.text('A'))?.fontSize, 19.5);
    });
  });

  // ===========================================================================
  group('empty state — painted by UsersList', () {
    testWidgets('emptyStateTextColor colours the empty title', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _bloc(const UsersEmpty()),
            usersStyle: const CometChatUsersStyle(
              emptyStateTextColor: Color(0xFF4E5F60),
            ),
          ),
        ),
      );
      await tester.pump();

      final title = find.text(_l10n(tester).usersUnavailable);
      expect(_styleOf(tester, title)?.color, const Color(0xFF4E5F60));
    });

    testWidgets('emptyStateTextStyle styles the empty title', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _bloc(const UsersEmpty()),
            usersStyle: const CometChatUsersStyle(
              emptyStateTextStyle: TextStyle(fontSize: 24.5),
            ),
          ),
        ),
      );
      await tester.pump();

      final title = find.text(_l10n(tester).usersUnavailable);
      expect(_styleOf(tester, title)?.fontSize, 24.5);
    });

    testWidgets('emptyStateSubTitleTextColor colours the empty subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _bloc(const UsersEmpty()),
            usersStyle: const CometChatUsersStyle(
              emptyStateSubTitleTextColor: Color(0xFF5F6071),
            ),
          ),
        ),
      );
      await tester.pump();

      final subtitle = find.text(_l10n(tester).addContactsToStartConversations);
      expect(_styleOf(tester, subtitle)?.color, const Color(0xFF5F6071));
    });

    testWidgets('emptyStateSubTitleTextStyle styles the empty subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _bloc(const UsersEmpty()),
            usersStyle: const CometChatUsersStyle(
              emptyStateSubTitleTextStyle: TextStyle(fontSize: 13.5),
            ),
          ),
        ),
      );
      await tester.pump();

      final subtitle = find.text(_l10n(tester).addContactsToStartConversations);
      expect(_styleOf(tester, subtitle)?.fontSize, 13.5);
    });
  });

  // ===========================================================================
  group('error state — painted by UIStateUtils via UsersList', () {
    testWidgets('errorStateTextColor colours the error title', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _bloc(const UsersError(message: 'boom')),
            usersStyle: const CometChatUsersStyle(
              errorStateTextColor: Color(0xFF607182),
            ),
          ),
        ),
      );
      await tester.pump();

      final title = find.text(_l10n(tester).oops);
      expect(_styleOf(tester, title)?.color, const Color(0xFF607182));
    });

    testWidgets('errorStateTextStyle styles the error title', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _bloc(const UsersError(message: 'boom')),
            usersStyle: const CometChatUsersStyle(
              errorStateTextStyle: TextStyle(fontSize: 26.5),
            ),
          ),
        ),
      );
      await tester.pump();

      final title = find.text(_l10n(tester).oops);
      expect(_styleOf(tester, title)?.fontSize, 26.5);
    });

    testWidgets('errorStateSubTitleTextColor colours the error subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _bloc(const UsersError(message: 'boom')),
            usersStyle: const CometChatUsersStyle(
              errorStateSubTitleTextColor: Color(0xFF718293),
            ),
          ),
        ),
      );
      await tester.pump();

      final subtitle = find.textContaining(
        _l10n(tester).looksLikeSomethingWrong,
      );
      expect(_styleOf(tester, subtitle)?.color, const Color(0xFF718293));
    });

    testWidgets('errorStateSubTitleTextStyle styles the error subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _bloc(const UsersError(message: 'boom')),
            usersStyle: const CometChatUsersStyle(
              errorStateSubTitleTextStyle: TextStyle(fontSize: 11.5),
            ),
          ),
        ),
      );
      await tester.pump();

      final subtitle = find.textContaining(
        _l10n(tester).looksLikeSomethingWrong,
      );
      expect(_styleOf(tester, subtitle)?.fontSize, 11.5);
    });

    testWidgets('retryButtonBackgroundColor fills the retry button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _bloc(const UsersError(message: 'boom')),
            usersStyle: const CometChatUsersStyle(
              retryButtonBackgroundColor: Color(0xFF1A2B3C),
            ),
          ),
        ),
      );
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(
        button.style?.backgroundColor?.resolve(<WidgetState>{}),
        const Color(0xFF1A2B3C),
      );
    });

    testWidgets('retryButtonBorder outlines the retry button', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _bloc(const UsersError(message: 'boom')),
            usersStyle: const CometChatUsersStyle(
              retryButtonBorder: BorderSide(color: Color(0xFF2B3C4D), width: 3),
            ),
          ),
        ),
      );
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final shape =
          button.style?.shape?.resolve(<WidgetState>{})
              as RoundedRectangleBorder?;
      expect(shape?.side, const BorderSide(color: Color(0xFF2B3C4D), width: 3));
    });

    testWidgets('retryButtonBorderRadius rounds the retry button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _bloc(const UsersError(message: 'boom')),
            usersStyle: const CometChatUsersStyle(
              retryButtonBorderRadius: BorderRadius.all(Radius.circular(17)),
            ),
          ),
        ),
      );
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final shape =
          button.style?.shape?.resolve(<WidgetState>{})
              as RoundedRectangleBorder?;
      expect(shape?.borderRadius, const BorderRadius.all(Radius.circular(17)));
    });

    testWidgets('retryButtonTextColor colours the retry label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _bloc(const UsersError(message: 'boom')),
            usersStyle: const CometChatUsersStyle(
              retryButtonTextColor: Color(0xFF3C4D5E),
            ),
          ),
        ),
      );
      await tester.pump();

      final label = find.text(_l10n(tester).retry);
      expect(_styleOf(tester, label)?.color, const Color(0xFF3C4D5E));
    });

    testWidgets('retryButtonTextStyle styles the retry label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatUsers(
            usersBloc: _bloc(const UsersError(message: 'boom')),
            usersStyle: const CometChatUsersStyle(
              retryButtonTextStyle: TextStyle(fontSize: 19.5),
            ),
          ),
        ),
      );
      await tester.pump();

      final label = find.text(_l10n(tester).retry);
      expect(_styleOf(tester, label)?.fontSize, 19.5);
    });
  });
}
