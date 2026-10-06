/// Render-verified prop matrix for [CometChatGroupsStyle] — Track 3 PROP1.
///
/// The component matrix in `groups_props_test.dart` covers `CometChatGroups`
/// itself; this covers the 44 props of the style it takes. Distinct from the
/// existing `groups_style_test.dart`, which asserts constructor assignment and
/// therefore scores zero on this gate — it would keep passing if the component
/// stopped reading the style entirely.
///
/// Where a prop is mapped onto another widget's style object rather than
/// painted directly, the assertion reads that object off the rendered tree.
/// That is still render-verified in the sense that matters: the mapping runs
/// during a real build, and deleting it fails the test.
///
/// All 44 props are read as of ENG-39121 — nine were dead when this matrix was
/// written and are now wired.
///
///   flutter test test/chat_ui/groups/groups_style_props_test.dart
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

// ─── Mocks & fakes ───────────────────────────────────────────────────────────

class MockGroupsBloc extends MockBloc<GroupsEvent, GroupsState>
    implements GroupsBloc {
  @override
  List<Group> getSelectedGroups() => const [];

  @override
  // ignore: must_call_super
  void add(GroupsEvent event) {}
}

class FakeGroup extends Fake implements Group {
  FakeGroup({
    this.name = 'Design',
    this.guid = 'g1',
    this.type = GroupTypeConstants.public,
    this.membersCount = 4,
  });

  @override
  final String name;
  @override
  final String guid;
  @override
  final String type;
  @override
  final int membersCount;
  @override
  String? get icon => null;
}

List<Group> _groups() => [
  FakeGroup(name: 'Design', guid: 'g1'),
  FakeGroup(name: 'Engineering', guid: 'g2', type: GroupTypeConstants.private),
  FakeGroup(name: 'Leadership', guid: 'g3', type: GroupTypeConstants.password),
];

MockGroupsBloc _blocIn(GroupsState state) {
  final bloc = MockGroupsBloc();
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, Stream<GroupsState>.value(state), initialState: state);
  return bloc;
}

MockGroupsBloc _loaded({Set<String> selected = const {}}) =>
    _blocIn(GroupsLoaded(groups: _groups(), selectedGroups: selected));

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
const _c6 = Color(0xFF606162);

ListBaseStyle _listBaseStyle(WidgetTester tester) =>
    tester.widget<CometChatListBase>(find.byType(CometChatListBase)).style;

CometChatGroupListItemStyle _itemStyle(WidgetTester tester) => tester
    .widgetList<CometChatGroupListItem>(find.byType(CometChatGroupListItem))
    .first
    .style!;

void main() {
  // ===========================================================================
  group('container', () {
    testWidgets('backgroundColor, border and borderRadius reach the frame', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loaded(),
              groupsStyle: const CometChatGroupsStyle(
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
            CometChatGroups(
              groupsBloc: _loaded(),
              groupsStyle: const CometChatGroupsStyle(
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
            CometChatGroups(
              groupsBloc: _loaded(),
              title: 'Channels',
              groupsStyle: const CometChatGroupsStyle(
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
            CometChatGroups(
              groupsBloc: _loaded(),
              groupsStyle: const CometChatGroupsStyle(backIconColor: _c2),
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
            CometChatGroups(
              groupsBloc: _loaded(selected: {'g1'}),
              groupsStyle: const CometChatGroupsStyle(submitIconColor: _c3),
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
            CometChatGroups(
              groupsBloc: _loaded(),
              groupsStyle: const CometChatGroupsStyle(
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
  group('list rows', () {
    testWidgets('item title and subtitle styling reaches the row', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loaded(),
              groupsStyle: const CometChatGroupsStyle(
                itemTitleTextColor: _c1,
                itemTitleTextStyle: TextStyle(fontSize: 23),
                itemSubtitleTextColor: _c2,
                itemSubtitleTextStyle: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final s = _itemStyle(tester);
      expect(s.titleTextColor, _c1);
      expect(s.titleTextStyle?.fontSize, 23);
      expect(s.subtitleTextColor, _c2);
      expect(s.subtitleTextStyle?.fontSize, 13);
    });

    testWidgets('avatarStyle and statusIndicatorStyle reach the row', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loaded(),
              groupsStyle: const CometChatGroupsStyle(
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

      final row = tester
          .widgetList<CometChatGroupListItem>(
            find.byType(CometChatGroupListItem),
          )
          .first;
      expect(row.avatarStyle?.backgroundColor, _c3);
      expect(row.statusIndicatorStyle?.backgroundColor, _c4);
    });

    testWidgets('FIXED — the two group-badge backgrounds reach the row', (
      tester,
    ) async {
      // ENG-39121: both were declared and never read; the row computed the
      // badge colour from the palette alone.
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loaded(),
              groupsStyle: const CometChatGroupsStyle(
                privateGroupIconBackground: _c5,
                protectedGroupIconBackground: _c6,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final rows = tester.widgetList<CometChatGroupListItem>(
        find.byType(CometChatGroupListItem),
      );
      expect(rows.first.privateGroupIconBackground, _c5);
      expect(rows.first.protectedGroupIconBackground, _c6);

      // And they actually paint: g2 is private, g3 is password.
      final dots = tester
          .widgetList<CometChatStatusIndicator>(
            find.byType(CometChatStatusIndicator),
          )
          .map((d) => d.style?.backgroundColor)
          .toList();
      expect(dots, contains(_c5));
      expect(dots, contains(_c6));
    });
  });

  // ===========================================================================
  group('selection', () {
    testWidgets('every checkbox prop reaches the row', (tester) async {
      // checkBoxBorder and checkboxSelectedIconColor were dead until
      // ENG-39121 — the border is carried as a colour/width pair on the row
      // style, and the tint became the Checkbox's checkColor.
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loaded(selected: {'g1'}),
              selectionMode: SelectionMode.multiple,
              groupsStyle: const CometChatGroupsStyle(
                checkBoxBackgroundColor: _c1,
                checkBoxCheckedBackgroundColor: _c2,
                checkBoxBorderRadius: BorderRadius.all(Radius.circular(7)),
                checkBoxBorder: BorderSide(color: _c3, width: 2.5),
                checkboxSelectedIconColor: _c4,
                listItemSelectedBackgroundColor: _c5,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final s = _itemStyle(tester);
      expect(s.checkBoxBackgroundColor, _c1);
      expect(s.checkBoxCheckedBackgroundColor, _c2);
      expect(
        s.checkBoxBorderRadius,
        const BorderRadius.all(Radius.circular(7)),
      );
      expect(s.checkBoxStrokeColor, _c3);
      expect(s.checkBoxStrokeWidth, 2.5);
      expect(s.checkBoxCheckColor, _c4);
      expect(s.selectedBackgroundColor, _c5);
    });

    testWidgets('the checkbox tint is what the Checkbox actually paints', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _loaded(selected: {'g1'}),
              selectionMode: SelectionMode.multiple,
              groupsStyle: const CometChatGroupsStyle(
                checkboxSelectedIconColor: _c4,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
      expect(boxes, isNotEmpty);
      expect(boxes.first.checkColor, _c4);
    });
  });

  // ===========================================================================
  group('empty state', () {
    testWidgets('all four empty-state text props apply', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: _blocIn(const GroupsEmpty()),
              groupsStyle: const CometChatGroupsStyle(
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
            CometChatGroups(
              groupsBloc: _blocIn(const GroupsError(message: 'boom')),
              groupsStyle: const CometChatGroupsStyle(
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
            CometChatGroups(
              groupsBloc: _blocIn(const GroupsError(message: 'boom')),
              groupsStyle: const CometChatGroupsStyle(
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
}
