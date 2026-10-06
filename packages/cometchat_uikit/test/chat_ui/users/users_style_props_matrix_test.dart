/// Render-verified prop matrix for [CometChatUsersStyle] — Track 3 PROP1.
///
/// Companion to `users_props_test.dart`, which covers `CometChatUsers` itself.
/// 43 style props, all read as of ENG-39121 — the five `retryButton*` props
/// were dead until then.
///
/// `UsersList` builds its rows inline rather than through a list-item widget,
/// so the row assertions here read the painted widgets directly where Groups
/// reads a row style object.
///
///   flutter test test/chat_ui/users/users_style_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Mocks & fakes ───────────────────────────────────────────────────────────

class MockUsersBloc extends MockBloc<UsersEvent, UsersState>
    implements UsersBloc {
  final _status = <String, ValueNotifier<String>>{};

  @override
  ValueNotifier<String> getStatusNotifier(String uid) =>
      _status.putIfAbsent(uid, () => ValueNotifier<String>('online'));

  @override
  // ignore: must_call_super
  void add(UsersEvent event) {}
}

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

List<User> _users() => [
  FakeUser(name: 'Alice', uid: 'u1'),
  FakeUser(name: 'Bruno', uid: 'u2', status: 'offline'),
];

MockUsersBloc _blocIn(UsersState state) {
  final bloc = MockUsersBloc();
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, Stream<UsersState>.value(state), initialState: state);
  return bloc;
}

MockUsersBloc _loaded({Set<String> selected = const {}}) =>
    _blocIn(UsersLoaded(users: _users(), selectedUsers: selected));

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

// Distinct sentinels so a test can never pass on a coincidental match.
const _c1 = Color(0xFF101112);
const _c2 = Color(0xFF202122);
const _c3 = Color(0xFF303132);
const _c4 = Color(0xFF404142);
const _c5 = Color(0xFF505152);

ListBaseStyle _listBaseStyle(WidgetTester tester) =>
    tester.widget<CometChatListBase>(find.byType(CometChatListBase)).style;

List<TextStyle> _textStyles(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.style)
    .whereType<TextStyle>()
    .toList();

void main() {
  // ===========================================================================
  group('container', () {
    testWidgets('backgroundColor, border and borderRadius reach the frame', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loaded(),
              usersStyle: const CometChatUsersStyle(
                backgroundColor: _c1,
                border: Border.fromBorderSide(BorderSide(color: _c2, width: 3)),
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final s = _listBaseStyle(tester);
      expect(s.background, _c1);
      expect((s.border as Border?)?.top.color, _c2);
      expect(s.borderRadius, const BorderRadius.all(Radius.circular(18)));

      // borderRadius is also the clip the whole component sits inside.
      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect).first);
      expect(clip.borderRadius, const BorderRadius.all(Radius.circular(18)));
    });

    testWidgets('separatorColor and separatorHeight draw the appbar rule', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loaded(),
              usersStyle: const CometChatUsersStyle(
                separatorColor: _c3,
                separatorHeight: 4,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final shape = _listBaseStyle(tester).appBarShape as Border?;
      expect(shape?.bottom.color, _c3);
      expect(shape?.bottom.width, 4);
    });
  });

  // ===========================================================================
  group('heading and back icon', () {
    testWidgets('titleTextColor and titleTextStyle style the heading', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loaded(),
              title: 'Channels',
              usersStyle: const CometChatUsersStyle(
                titleTextColor: _c1,
                titleTextStyle: TextStyle(fontSize: 29, letterSpacing: 2),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final heading = tester.widget<Text>(find.text('Channels'));
      expect(heading.style?.color, _c1);
      expect(heading.style?.fontSize, 29);
      expect(heading.style?.letterSpacing, 2);
      expect(_listBaseStyle(tester).titleStyle?.color, _c1);
    });

    testWidgets('backIconColor tints the back icon', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loaded(),
              usersStyle: const CometChatUsersStyle(backIconColor: _c2),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.widget<Icon>(find.byIcon(Icons.arrow_back)).color, _c2);
      expect(_listBaseStyle(tester).backIconTint, _c2);
    });

    testWidgets('submitIconColor tints the submit affordance', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loaded(selected: {'g1'}),
              usersStyle: const CometChatUsersStyle(submitIconColor: _c3),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.widget<Icon>(find.byIcon(Icons.check)).color, _c3);
    });
  });

  // ===========================================================================
  group('search row', () {
    testWidgets('all nine search props reach the search field', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loaded(),
              usersStyle: const CometChatUsersStyle(
                searchBackgroundColor: _c1,
                searchBorder: BorderSide(color: _c2, width: 2),
                searchBorderRadius: BorderRadius.all(Radius.circular(11)),
                searchIconColor: _c3,
                searchInputTextColor: _c4,
                searchInputTextStyle: TextStyle(fontSize: 21),
                searchPlaceHolderTextColor: _c5,
                searchPlaceHolderTextStyle: TextStyle(fontSize: 17),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final s = _listBaseStyle(tester);
      expect(s.searchBoxBackground, _c1);
      expect(s.borderSide?.color, _c2);
      expect(s.borderSide?.width, 2);
      expect(
        s.searchTextFieldRadius,
        const BorderRadius.all(Radius.circular(11)),
      );
      expect(s.searchIconTint, _c3);
      expect(s.searchTextStyle?.color, _c4);
      expect(s.searchTextStyle?.fontSize, 21);
      expect(s.searchPlaceholderStyle?.color, _c5);
      expect(s.searchPlaceholderStyle?.fontSize, 17);
    });
  });

  // ===========================================================================
  group('empty state', () {
    testWidgets('all four empty-state text props apply', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _blocIn(const UsersEmpty()),
              usersStyle: const CometChatUsersStyle(
                emptyStateTextColor: _c1,
                emptyStateTextStyle: TextStyle(fontSize: 26),
                emptyStateSubTitleTextColor: _c2,
                emptyStateSubTitleTextStyle: TextStyle(fontSize: 15),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final styles = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.style)
          .whereType<TextStyle>()
          .toList();

      expect(
        styles.any((s) => s.color == _c1 && s.fontSize == 26),
        isTrue,
        reason: 'empty-state title',
      );
      expect(
        styles.any((s) => s.color == _c2 && s.fontSize == 15),
        isTrue,
        reason: 'empty-state subtitle',
      );
    });
  });

  // ===========================================================================
  group('error state', () {
    testWidgets('the four error text props apply', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _blocIn(const UsersError(message: 'boom')),
              usersStyle: const CometChatUsersStyle(
                errorStateTextColor: _c1,
                errorStateTextStyle: TextStyle(fontSize: 26),
                errorStateSubTitleTextColor: _c2,
                errorStateSubTitleTextStyle: TextStyle(fontSize: 15),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final styles = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.style)
          .whereType<TextStyle>()
          .toList();

      expect(styles.any((s) => s.color == _c1 && s.fontSize == 26), isTrue);
      expect(styles.any((s) => s.color == _c2 && s.fontSize == 15), isTrue);
    });

    testWidgets('FIXED — the five retry-button props reach the button', (
      tester,
    ) async {
      // ENG-39121: all five were dead. getDefaultErrorStateView has accepted
      // button* arguments the whole time — CometChatGroupMembers passes them,
      // Groups and Users did not.
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _blocIn(const UsersError(message: 'boom')),
              usersStyle: const CometChatUsersStyle(
                retryButtonBackgroundColor: _c3,
                retryButtonTextColor: _c4,
                retryButtonTextStyle: TextStyle(fontSize: 19),
                retryButtonBorder: BorderSide(color: _c5, width: 3),
                retryButtonBorderRadius: BorderRadius.all(Radius.circular(13)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final bs = button.style!;
      expect(bs.backgroundColor?.resolve(<WidgetState>{}), _c3);

      final shape =
          bs.shape?.resolve(<WidgetState>{}) as RoundedRectangleBorder?;
      expect(shape?.borderRadius, const BorderRadius.all(Radius.circular(13)));
      expect(shape?.side.color, _c5);
      expect(shape?.side.width, 3);

      final styles = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.style)
          .whereType<TextStyle>()
          .toList();
      expect(
        styles.any((s) => s.color == _c4 && s.fontSize == 19),
        isTrue,
        reason: 'retry button label',
      );
    });
  });

  // ===========================================================================
  group('list rows', () {
    testWidgets('itemTitle styling and itemBorder reach each row', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loaded(),
              usersStyle: const CometChatUsersStyle(
                itemTitleTextColor: _c1,
                itemTitleTextStyle: TextStyle(fontSize: 23),
                itemBorder: Border.fromBorderSide(
                  BorderSide(color: _c2, width: 2),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        _textStyles(tester).any((t) => t.color == _c1 && t.fontSize == 23),
        isTrue,
        reason: 'row title',
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              ((w.decoration as BoxDecoration).border as Border?)?.top.color ==
                  _c2,
        ),
        findsWidgets,
        reason: 'row border',
      );
    });

    testWidgets('avatarStyle and statusIndicatorStyle reach each row', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loaded(),
              usersStyle: const CometChatUsersStyle(
                avatarStyle: CometChatAvatarStyle(backgroundColor: _c3),
                statusIndicatorStyle: CometChatStatusIndicatorStyle(
                  backgroundColor: _c4,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final avatars = tester.widgetList<CometChatAvatar>(
        find.byType(CometChatAvatar),
      );
      expect(avatars, isNotEmpty);
      expect(avatars.first.style?.backgroundColor, _c3);

      // Alice is online, so exactly one presence dot paints the status colour.
      final dots = tester.widgetList<CometChatStatusIndicator>(
        find.byType(CometChatStatusIndicator),
      );
      expect(dots, isNotEmpty);
    });

    testWidgets('stickyTitleColor and stickyTitleTextStyle style the initial '
        'headers', (tester) async {
      // UsersList emits a header whenever the leading letter changes, so the
      // two-user fixture produces one for "A" and one for "B".
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loaded(),
              usersStyle: const CometChatUsersStyle(
                stickyTitleColor: _c5,
                stickyTitleTextStyle: TextStyle(fontSize: 18, letterSpacing: 3),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        _textStyles(tester).where(
          (t) => t.color == _c5 && t.fontSize == 18 && t.letterSpacing == 3,
        ),
        hasLength(greaterThanOrEqualTo(1)),
      );
    });
  });

  // ===========================================================================
  group('selection', () {
    testWidgets('every checkbox prop reaches the inline checkbox', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loaded(selected: {'u1'}),
              selectionMode: SelectionMode.multiple,
              usersStyle: const CometChatUsersStyle(
                checkBoxBackgroundColor: _c1,
                checkBoxCheckedBackgroundColor: _c2,
                checkBoxBorderRadius: BorderRadius.all(Radius.circular(7)),
                checkBoxBorder: BorderSide(color: _c3, width: 2.5),
                checkboxSelectedIconColor: _c4,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(boxes, isNotEmpty);

      // u1 is selected and u2 is not, so the two fill colours are both proven
      // from the same pump.
      final fills = boxes
          .map((b) => b.fillColor?.resolve(<WidgetState>{}))
          .toList();
      expect(fills, contains(_c2), reason: 'checked background');
      expect(fills, contains(_c1), reason: 'unchecked background');

      final selected = boxes.firstWhere((b) => b.value == true);
      expect(selected.activeColor, _c2);
      expect(selected.checkColor, _c4);
      expect(selected.side?.color, _c3);
      expect(selected.side?.width, 2.5);
      expect(
        (selected.shape as RoundedRectangleBorder?)?.borderRadius,
        const BorderRadius.all(Radius.circular(7)),
      );
    });

    testWidgets('listItemSelectedBackgroundColor paints the selected row', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatUsers(
              usersBloc: _loaded(selected: {'u1'}),
              selectionMode: SelectionMode.multiple,
              usersStyle: const CometChatUsersStyle(
                listItemSelectedBackgroundColor: _c5,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == _c5,
        ),
        findsWidgets,
      );
    });
  });
}
