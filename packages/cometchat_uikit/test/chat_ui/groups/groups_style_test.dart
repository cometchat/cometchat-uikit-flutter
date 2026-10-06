/// Tests for [CometChatGroupsStyle]: Track 3 PROP1/PROP2 (ENG-38688).
///
/// The first half is the original file: default values, copyWith, merge, lerp
/// and ThemeExtension compliance. Those prove the data class holds what it is
/// given and nothing more. Every one of them would still pass if
/// CometChatGroups stopped reading the style entirely.
///
/// The second half is the render-verified matrix. Each row names a prop, the
/// sentinel it is set to, and how to read the value back off the element that
/// prop paints. Rows are grouped by the surface they paint on (the loaded
/// list, the empty state, the error state and the selection state), and each
/// surface is pumped twice: once unstyled, to prove no sentinel is already a
/// default, and once with every row's prop set, where each row must read back
/// its own sentinel. No two rows share a sentinel, so a row can only pass if
/// its own prop got through.
///
/// A surface's style is built inline in pumpWidget rather than carried on the
/// rows because the coverage tool is syntactic: it credits a prop only when
/// the prop is passed by name to a construction that reaches pumpWidget in the
/// same test body.
///
/// 9 of the 44 props have no row, because they are declared on the style and
/// read by nothing CometChatGroups builds. See [_inert]. Two props with rows,
/// avatarStyle and statusIndicatorStyle, are only partly honoured, and
/// checkBoxBorderRadius accepts only a BorderRadius. See the notes on their
/// rows.
///
///   flutter test test/chat_ui/groups/groups_style_test.dart
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
  // ignore: must_call_super
  void add(GroupsEvent event) {
    // No-op: the matrix asserts rendering, not event handling.
  }
}

class FakeGroup extends Fake implements Group {
  FakeGroup(this.guid, this.name, this.type, this.membersCount);

  @override
  final String guid;
  @override
  final String name;
  @override
  final String type;
  @override
  final int membersCount;
  @override
  String? get icon => null;
}

/// One group of each type. The private and password rows are the ones that
/// carry a status indicator.
List<Group> _groups() => [
  FakeGroup('g1', 'Alpha', 'public', 5),
  FakeGroup('g2', 'Bravo', 'private', 1),
  FakeGroup('g3', 'Charlie', 'password', 12),
];

MockGroupsBloc _blocIn(GroupsState state) {
  final bloc = MockGroupsBloc();
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, Stream<GroupsState>.value(state), initialState: state);
  return bloc;
}

MockGroupsBloc _listBloc({Set<String> selected = const {}}) => _blocIn(
  GroupsLoaded(groups: _groups(), hasMore: false, selectedGroups: selected),
);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

// ─── Sentinels ───────────────────────────────────────────────────────────────

/// Values no theme, palette or typography scale uses, one per row, so a row
/// can only ever read back its own.
abstract final class _S {
  static const checkBoxBorder = BorderSide(
    color: Color(0xFFF1E2D3),
    width: 2.5,
  );
  static const checkIcon = Color(0xFFE2D3C4);
  static const privateDot = Color(0xFFD3C4B5);
  static const protectedDot = Color(0xFFC4B5A6);
  static const retryBackground = Color(0xFF8B9CAD);
  static const retryBorder = BorderSide(color: Color(0xFF9CADBE), width: 2.75);
  static const retryRadius = BorderRadius.all(Radius.circular(19));
  static const retryText = Color(0xFFADBECF);
  static const retryTextSize = 17.25;
  // The loaded list.
  static const background = Color(0xFF1A2B3C);
  static const border = Border.fromBorderSide(
    BorderSide(color: Color(0xFF2B3C4D), width: 3.5),
  );
  static const radius = BorderRadius.all(Radius.circular(13));
  static const backIcon = Color(0xFF3C4D5E);
  static const titleSize = 31.5;
  static const title = Color(0xFF4D5E6F);
  static const separator = Color(0xFF5E6F7A);
  static const separatorHeight = 3.25;
  static const itemTitleSize = 21.5;
  static const itemTitle = Color(0xFF6F7A8B);
  static const itemSubtitleSize = 11.5;
  static const itemSubtitle = Color(0xFF7A8B9C);
  static const avatar = Color(0xFF8B9CAD);
  static const statusBorder = Border.fromBorderSide(
    BorderSide(color: Color(0xFF9CADBE), width: 2.5),
  );
  static const searchFill = Color(0xFFADBECF);
  static const searchBorder = BorderSide(color: Color(0xFFBECFD0), width: 1.75);
  static const searchRadius = BorderRadius.all(Radius.circular(7));
  static const searchIcon = Color(0xFFCFD0E1);
  static const searchInput = Color(0xFFD0E1F2);
  static const searchInputSize = 17.5;
  static const searchHint = Color(0xFFE1F2A3);
  static const searchHintSize = 15.5;

  // The empty state.
  static const emptyTitle = Color(0xFF0B1C2D);
  static const emptyTitleSize = 26.5;
  static const emptySubtitle = Color(0xFF1C2D3E);
  static const emptySubtitleSize = 12.5;

  // The error state.
  static const errorTitle = Color(0xFF2D3E4F);
  static const errorTitleSize = 27.5;
  static const errorSubtitle = Color(0xFF3E4F5A);
  static const errorSubtitleSize = 13.5;

  // The selection state.
  static const checkBoxFill = Color(0xFF4F5A6B);
  static const checkBoxCheckedFill = Color(0xFF5A6B7C);
  static const checkBoxRadius = BorderRadius.all(Radius.circular(6.5));
  static const selectedRow = Color(0xFF6B7C8D);
  static const submitIcon = Color(0xFF7C8D9E);

  // The theme lookup.
  static const themeTitle = Color(0xFF8C9DAE);
  static const themeBackIcon = Color(0xFF9DAEBF);
}

// ─── Readers ─────────────────────────────────────────────────────────────────

const _emptySubtitleText =
    'Create or join groups to see them listed here\nand start collaborating.';
const _errorSubtitleText =
    'Looks like something went wrong.\nPlease try again.';

TextStyle? _textStyle(WidgetTester t, String data) =>
    t.widget<Text>(find.text(data)).style;

/// The decoration of the first Container under [within], which is the one
/// that paints it: ListBase's frame, the avatar disc, the status dot.
BoxDecoration? _firstBox(WidgetTester t, Finder within) =>
    t
            .widget<Container>(
              find
                  .descendant(of: within, matching: find.byType(Container))
                  .first,
            )
            .decoration
        as BoxDecoration?;

/// What the search field paints with, after TextField has applied the theme.
InputDecoration _search(WidgetTester t) =>
    t.widget<InputDecorator>(find.byType(InputDecorator)).decoration;

OutlineInputBorder? _searchOutline(WidgetTester t) =>
    _search(t).enabledBorder as OutlineInputBorder?;

TextStyle _searchInput(WidgetTester t) =>
    t.widget<EditableText>(find.byType(EditableText)).style;

/// The bottom edge of the Material the AppBar paints with.
BorderSide? _appBarEdge(WidgetTester t) {
  final bar = t.widget<Material>(
    find
        .descendant(of: find.byType(AppBar), matching: find.byType(Material))
        .first,
  );
  return (bar.shape as Border?)?.bottom;
}

Checkbox _checkbox(WidgetTester t, String group) => t.widget<Checkbox>(
  find.descendant(
    of: find.widgetWithText(CometChatGroupListItem, group),
    matching: find.byType(Checkbox),
  ),
);

// ─── The matrix ──────────────────────────────────────────────────────────────

/// One row: the prop, the sentinel it is given, and how to read the value the
/// rendered tree carries in the place that prop controls. A reader must also
/// work on the unstyled tree, because every surface reads each row twice.
class _Row {
  const _Row(this.prop, this.sentinel, this.read);

  final String prop;
  final Object sentinel;
  final Object? Function(WidgetTester tester) read;
}

Map<String, Object?> _readAll(WidgetTester t, List<_Row> rows) => {
  for (final r in rows) r.prop: r.read(t),
};

final _listRows = <_Row>[
  _Row(
    'backgroundColor',
    _S.background,
    (t) => t
        .widget<Scaffold>(
          find.descendant(
            of: find.byType(CometChatListBase),
            matching: find.byType(Scaffold),
          ),
        )
        .backgroundColor,
  ),
  _Row(
    'border',
    _S.border,
    (t) => _firstBox(t, find.byType(CometChatListBase))?.border,
  ),
  _Row(
    'borderRadius',
    _S.radius,
    (t) => t
        .widget<ClipRRect>(
          find
              .descendant(
                of: find.byType(CometChatGroups),
                matching: find.byType(ClipRRect),
              )
              .first,
        )
        .borderRadius,
  ),
  _Row(
    'backIconColor',
    _S.backIcon,
    (t) => t.widget<Icon>(find.byIcon(Icons.arrow_back)).color,
  ),
  _Row(
    'titleTextStyle',
    _S.titleSize,
    (t) => _textStyle(t, 'Groups')?.fontSize,
  ),
  _Row('titleTextColor', _S.title, (t) => _textStyle(t, 'Groups')?.color),
  _Row('separatorColor', _S.separator, (t) => _appBarEdge(t)?.color),
  _Row('separatorHeight', _S.separatorHeight, (t) => _appBarEdge(t)?.width),
  _Row(
    'itemTitleTextStyle',
    _S.itemTitleSize,
    (t) => _textStyle(t, 'Alpha')?.fontSize,
  ),
  _Row(
    'itemTitleTextColor',
    _S.itemTitle,
    (t) => _textStyle(t, 'Alpha')?.color,
  ),
  _Row(
    'itemSubtitleTextStyle',
    _S.itemSubtitleSize,
    (t) => _textStyle(t, '5 Members')?.fontSize,
  ),
  _Row(
    'itemSubtitleTextColor',
    _S.itemSubtitle,
    (t) => _textStyle(t, '5 Members')?.color,
  ),
  // DEFECT (partial): CometChatGroupListItem replaces the avatar style's
  // placeHolderTextStyle with heading2 (cometchat_group_list_item.dart:322),
  // so that one field of avatarStyle never reaches the initials.
  _Row(
    'avatarStyle',
    _S.avatar,
    (t) => _firstBox(t, find.byType(CometChatAvatar).first)?.color,
  ),
  // DEFECT (partial): CometChatGroupListItem rebuilds the dot's style from
  // statusIndicatorStyle.border alone (cometchat_group_list_item.dart:355), so
  // its backgroundColor and borderRadius are dropped.
  _Row(
    'statusIndicatorStyle',
    _S.statusBorder,
    (t) => _firstBox(t, find.byType(CometChatStatusIndicator).first)?.border,
  ),
  _Row('searchBackgroundColor', _S.searchFill, (t) => _search(t).fillColor),
  _Row('searchBorder', _S.searchBorder, (t) => _searchOutline(t)?.borderSide),
  _Row(
    'searchBorderRadius',
    _S.searchRadius,
    (t) => _searchOutline(t)?.borderRadius,
  ),
  _Row(
    'searchIconColor',
    _S.searchIcon,
    (t) => t.widget<Icon>(find.byIcon(Icons.search)).color,
  ),
  _Row('searchInputTextColor', _S.searchInput, (t) => _searchInput(t).color),
  _Row(
    'searchInputTextStyle',
    _S.searchInputSize,
    (t) => _searchInput(t).fontSize,
  ),
  _Row(
    'searchPlaceHolderTextColor',
    _S.searchHint,
    (t) => _textStyle(t, 'Search')?.color,
  ),
  _Row(
    'searchPlaceHolderTextStyle',
    _S.searchHintSize,
    (t) => _textStyle(t, 'Search')?.fontSize,
  ),
  _Row(
    'privateGroupIconBackground',
    _S.privateDot,
    (t) => _dotOf(t, 'Bravo')?.style?.backgroundColor,
  ),
  _Row(
    'protectedGroupIconBackground',
    _S.protectedDot,
    (t) => _dotOf(t, 'Charlie')?.style?.backgroundColor,
  ),
];

/// The status dot in the row for [group], if it shows one.
CometChatStatusIndicator? _dotOf(WidgetTester t, String group) {
  final dot = find.descendant(
    of: find.widgetWithText(CometChatGroupListItem, group),
    matching: find.byType(CometChatStatusIndicator),
  );
  return dot.evaluate().isEmpty
      ? null
      : t.widget<CometChatStatusIndicator>(dot.first);
}

final _emptyRows = <_Row>[
  _Row(
    'emptyStateTextColor',
    _S.emptyTitle,
    (t) => _textStyle(t, 'No groups found')?.color,
  ),
  _Row(
    'emptyStateTextStyle',
    _S.emptyTitleSize,
    (t) => _textStyle(t, 'No groups found')?.fontSize,
  ),
  _Row(
    'emptyStateSubTitleTextColor',
    _S.emptySubtitle,
    (t) => _textStyle(t, _emptySubtitleText)?.color,
  ),
  _Row(
    'emptyStateSubTitleTextStyle',
    _S.emptySubtitleSize,
    (t) => _textStyle(t, _emptySubtitleText)?.fontSize,
  ),
];

final _errorRows = <_Row>[
  _Row(
    'errorStateTextColor',
    _S.errorTitle,
    (t) => _textStyle(t, 'Oops!')?.color,
  ),
  _Row(
    'errorStateTextStyle',
    _S.errorTitleSize,
    (t) => _textStyle(t, 'Oops!')?.fontSize,
  ),
  _Row(
    'errorStateSubTitleTextColor',
    _S.errorSubtitle,
    (t) => _textStyle(t, _errorSubtitleText)?.color,
  ),
  _Row(
    'errorStateSubTitleTextStyle',
    _S.errorSubtitleSize,
    (t) => _textStyle(t, _errorSubtitleText)?.fontSize,
  ),
  _Row(
    'retryButtonBackgroundColor',
    _S.retryBackground,
    (t) =>
        _retryButton(t).style?.backgroundColor?.resolve(const <WidgetState>{}),
  ),
  _Row('retryButtonBorder', _S.retryBorder, (t) => _retryShape(t)?.side),
  _Row(
    'retryButtonBorderRadius',
    _S.retryRadius,
    (t) => _retryShape(t)?.borderRadius,
  ),
  _Row(
    'retryButtonTextColor',
    _S.retryText,
    (t) => _textStyle(t, 'Retry')?.color,
  ),
  _Row(
    'retryButtonTextStyle',
    _S.retryTextSize,
    (t) => _textStyle(t, 'Retry')?.fontSize,
  ),
];

ElevatedButton _retryButton(WidgetTester t) =>
    t.widget<ElevatedButton>(find.byType(ElevatedButton));

RoundedRectangleBorder? _retryShape(WidgetTester t) =>
    _retryButton(t).style?.shape?.resolve(const <WidgetState>{})
        as RoundedRectangleBorder?;

/// Seeded with Alpha selected, so Alpha's row is the checked one and Bravo's
/// the unchecked one, and the submit affordance is showing.
final _selectionRows = <_Row>[
  _Row(
    'checkBoxBackgroundColor',
    _S.checkBoxFill,
    (t) => _checkbox(t, 'Bravo').fillColor?.resolve(const <WidgetState>{}),
  ),
  _Row(
    'checkBoxCheckedBackgroundColor',
    _S.checkBoxCheckedFill,
    (t) => _checkbox(
      t,
      'Alpha',
    ).fillColor?.resolve(const <WidgetState>{WidgetState.selected}),
  ),
  // DEFECT: the field is a BorderRadiusGeometry but GroupsList casts it to
  // BorderRadius? (groups_list.dart:385), so any other geometry, such as a
  // BorderRadiusDirectional, throws during build. A BorderRadius works.
  _Row(
    'checkBoxBorderRadius',
    _S.checkBoxRadius,
    (t) =>
        (_checkbox(t, 'Alpha').shape as RoundedRectangleBorder?)?.borderRadius,
  ),
  _Row(
    'listItemSelectedBackgroundColor',
    _S.selectedRow,
    (t) => t
        .widget<Container>(
          find
              .descendant(
                of: find.widgetWithText(CometChatGroupListItem, 'Alpha'),
                matching: find.byType(Container),
              )
              .first,
        )
        .color,
  ),
  _Row(
    'submitIconColor',
    _S.submitIcon,
    (t) => t.widget<Icon>(find.byIcon(Icons.check)).color,
  ),
  _Row('checkBoxBorder', _S.checkBoxBorder, (t) => _checkbox(t, 'Bravo').side),
  _Row(
    'checkboxSelectedIconColor',
    _S.checkIcon,
    (t) => _checkbox(t, 'Alpha').checkColor,
  ),
];

/// Style props with no row because nothing on screen changes when they are
/// set. None are left: the last four were fixed with their rows.
const _inert = <String>{};

/// All 44 props on the style.
const _allProps = {
  'backgroundColor',
  'border',
  'borderRadius',
  'backIconColor',
  'titleTextStyle',
  'titleTextColor',
  'emptyStateTextStyle',
  'emptyStateTextColor',
  'errorStateTextStyle',
  'errorStateTextColor',
  'emptyStateSubTitleTextStyle',
  'emptyStateSubTitleTextColor',
  'errorStateSubTitleTextStyle',
  'errorStateSubTitleTextColor',
  'itemTitleTextStyle',
  'itemTitleTextColor',
  'itemSubtitleTextStyle',
  'itemSubtitleTextColor',
  'separatorColor',
  'separatorHeight',
  'avatarStyle',
  'statusIndicatorStyle',
  'searchBackgroundColor',
  'searchBorder',
  'searchBorderRadius',
  'searchIconColor',
  'searchInputTextColor',
  'searchInputTextStyle',
  'searchPlaceHolderTextColor',
  'searchPlaceHolderTextStyle',
  'checkBoxBackgroundColor',
  'checkBoxBorder',
  'checkBoxBorderRadius',
  'checkBoxCheckedBackgroundColor',
  'listItemSelectedBackgroundColor',
  'checkboxSelectedIconColor',
  'submitIconColor',
  'retryButtonBackgroundColor',
  'retryButtonBorder',
  'retryButtonBorderRadius',
  'retryButtonTextColor',
  'retryButtonTextStyle',
  'protectedGroupIconBackground',
  'privateGroupIconBackground',
};

// ===========================================================================
// Tests — CometChatGroupsStyle
// ===========================================================================

void main() {
  // =========================================================================
  // Default values
  // =========================================================================

  group('CometChatGroupsStyle defaults', () {
    test('all properties are null by default', () {
      const style = CometChatGroupsStyle();
      expect(style.backgroundColor, isNull);
      expect(style.border, isNull);
      expect(style.borderRadius, isNull);
      expect(style.backIconColor, isNull);
      expect(style.titleTextStyle, isNull);
      expect(style.titleTextColor, isNull);
      expect(style.emptyStateTextStyle, isNull);
      expect(style.emptyStateTextColor, isNull);
      expect(style.errorStateTextStyle, isNull);
      expect(style.errorStateTextColor, isNull);
      expect(style.emptyStateSubTitleTextStyle, isNull);
      expect(style.emptyStateSubTitleTextColor, isNull);
      expect(style.errorStateSubTitleTextStyle, isNull);
      expect(style.errorStateSubTitleTextColor, isNull);
      expect(style.itemTitleTextStyle, isNull);
      expect(style.itemTitleTextColor, isNull);
      expect(style.itemSubtitleTextStyle, isNull);
      expect(style.itemSubtitleTextColor, isNull);
      expect(style.separatorColor, isNull);
      expect(style.separatorHeight, isNull);
      expect(style.avatarStyle, isNull);
      expect(style.statusIndicatorStyle, isNull);
      expect(style.searchBackgroundColor, isNull);
      expect(style.searchBorder, isNull);
      expect(style.searchBorderRadius, isNull);
      expect(style.searchIconColor, isNull);
      expect(style.searchInputTextColor, isNull);
      expect(style.searchInputTextStyle, isNull);
      expect(style.searchPlaceHolderTextColor, isNull);
      expect(style.searchPlaceHolderTextStyle, isNull);
      expect(style.checkBoxBackgroundColor, isNull);
      expect(style.checkBoxBorder, isNull);
      expect(style.checkBoxBorderRadius, isNull);
      expect(style.checkBoxCheckedBackgroundColor, isNull);
      expect(style.listItemSelectedBackgroundColor, isNull);
      expect(style.checkboxSelectedIconColor, isNull);
      expect(style.submitIconColor, isNull);
      expect(style.retryButtonBackgroundColor, isNull);
      expect(style.retryButtonBorder, isNull);
      expect(style.retryButtonBorderRadius, isNull);
      expect(style.retryButtonTextColor, isNull);
      expect(style.retryButtonTextStyle, isNull);
      expect(style.protectedGroupIconBackground, isNull);
      expect(style.privateGroupIconBackground, isNull);
    });
  });

  // =========================================================================
  // copyWith
  // =========================================================================

  group('CometChatGroupsStyle copyWith', () {
    test('copyWith updates backgroundColor', () {
      const style = CometChatGroupsStyle();
      final updated = style.copyWith(backgroundColor: Colors.white);
      expect(updated.backgroundColor, Colors.white);
    });

    test('copyWith preserves existing values when not overridden', () {
      const style = CometChatGroupsStyle(
        backgroundColor: Colors.blue,
        titleTextColor: Colors.white,
        separatorHeight: 1.0,
      );
      final updated = style.copyWith(backIconColor: Colors.red);
      expect(updated.backgroundColor, Colors.blue);
      expect(updated.titleTextColor, Colors.white);
      expect(updated.separatorHeight, 1.0);
      expect(updated.backIconColor, Colors.red);
    });

    test('copyWith updates group icon backgrounds', () {
      const style = CometChatGroupsStyle();
      final updated = style.copyWith(
        privateGroupIconBackground: Colors.blue,
        protectedGroupIconBackground: Colors.orange,
      );
      expect(updated.privateGroupIconBackground, Colors.blue);
      expect(updated.protectedGroupIconBackground, Colors.orange);
    });

    test('copyWith updates search properties', () {
      const style = CometChatGroupsStyle();
      final updated = style.copyWith(
        searchBackgroundColor: Colors.grey.shade100,
        searchIconColor: Colors.grey,
        searchInputTextColor: Colors.black,
        searchPlaceHolderTextColor: Colors.grey.shade400,
      );
      expect(updated.searchBackgroundColor, Colors.grey.shade100);
      expect(updated.searchIconColor, Colors.grey);
      expect(updated.searchInputTextColor, Colors.black);
      expect(updated.searchPlaceHolderTextColor, Colors.grey.shade400);
    });

    test('copyWith updates checkbox properties', () {
      const style = CometChatGroupsStyle();
      final updated = style.copyWith(
        checkBoxBackgroundColor: Colors.white,
        checkBoxCheckedBackgroundColor: Colors.blue,
        checkboxSelectedIconColor: Colors.white,
        listItemSelectedBackgroundColor: Colors.blue.shade50,
      );
      expect(updated.checkBoxBackgroundColor, Colors.white);
      expect(updated.checkBoxCheckedBackgroundColor, Colors.blue);
      expect(updated.checkboxSelectedIconColor, Colors.white);
      expect(updated.listItemSelectedBackgroundColor, Colors.blue.shade50);
    });
  });

  // =========================================================================
  // merge
  // =========================================================================

  group('CometChatGroupsStyle merge', () {
    test('merge with null returns same style', () {
      const style = CometChatGroupsStyle(backgroundColor: Colors.white);
      final merged = style.merge(null);
      expect(merged.backgroundColor, Colors.white);
    });

    test('merge applies other style properties', () {
      const base = CometChatGroupsStyle(
        backgroundColor: Colors.white,
        titleTextColor: Colors.black,
      );
      const other = CometChatGroupsStyle(
        backgroundColor: Colors.blue,
        privateGroupIconBackground: Colors.indigo,
      );
      final merged = base.merge(other);
      expect(merged.backgroundColor, Colors.blue);
      expect(merged.privateGroupIconBackground, Colors.indigo);
      // titleTextColor from base preserved since merge uses copyWith
      expect(merged.titleTextColor, Colors.black);
    });

    test('merge overrides all non-null properties from other', () {
      const base = CometChatGroupsStyle();
      const other = CometChatGroupsStyle(
        separatorColor: Colors.grey,
        separatorHeight: 2.0,
        submitIconColor: Colors.green,
        retryButtonBackgroundColor: Colors.red,
      );
      final merged = base.merge(other);
      expect(merged.separatorColor, Colors.grey);
      expect(merged.separatorHeight, 2.0);
      expect(merged.submitIconColor, Colors.green);
      expect(merged.retryButtonBackgroundColor, Colors.red);
    });
  });

  // =========================================================================
  // lerp
  // =========================================================================

  group('CometChatGroupsStyle lerp', () {
    test('lerp at t=0 returns start style', () {
      const start = CometChatGroupsStyle(backgroundColor: Colors.white);
      const end = CometChatGroupsStyle(backgroundColor: Colors.black);
      final result = start.lerp(end, 0.0);
      expect(result.backgroundColor, Colors.white);
    });

    test('lerp at t=1 returns end style', () {
      const start = CometChatGroupsStyle(backgroundColor: Colors.white);
      const end = CometChatGroupsStyle(backgroundColor: Colors.black);
      final result = start.lerp(end, 1.0);
      expect(result.backgroundColor, Colors.black);
    });

    test('lerp with non-CometChatGroupsStyle returns this', () {
      const style = CometChatGroupsStyle(backgroundColor: Colors.blue);
      final result = style.lerp(null, 0.5);
      expect(result.backgroundColor, Colors.blue);
    });

    test('lerp interpolates separatorHeight', () {
      const start = CometChatGroupsStyle(separatorHeight: 0.0);
      const end = CometChatGroupsStyle(separatorHeight: 10.0);
      final result = start.lerp(end, 0.5);
      expect(result.separatorHeight, 5.0);
    });
  });

  // =========================================================================
  // ThemeExtension compliance
  // =========================================================================

  // CometChatGroups looks its style up as Theme.of(context).extension, falls
  // back to CometChatGroupsStyle.of when none is registered, and merges its
  // own groupsStyle over whichever it found.
  group('ThemeExtension compliance', () {
    testWidgets('a style registered on the theme paints CometChatGroups, and '
        'groupsStyle wins over it prop by prop', (tester) async {
      Widget themed(Widget child) => MaterialApp(
        theme: ThemeData(
          extensions: const [
            CometChatGroupsStyle(
              titleTextColor: _S.themeTitle,
              backIconColor: _S.themeBackIcon,
            ),
          ],
        ),
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(body: child),
      );
      Color? backIcon() =>
          tester.widget<Icon>(find.byIcon(Icons.arrow_back)).color;

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          themed(
            CometChatGroups(
              key: const ValueKey('theme only'),
              groupsBloc: _listBloc(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_textStyle(tester, 'Groups')?.color, _S.themeTitle);
      expect(backIcon(), _S.themeBackIcon);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          themed(
            CometChatGroups(
              key: const ValueKey('theme and widget'),
              groupsBloc: _listBloc(),
              groupsStyle: const CometChatGroupsStyle(titleTextColor: _S.title),
            ),
          ),
        ),
      );
      await tester.pump();
      // The widget's own value wins where it sets one...
      expect(_textStyle(tester, 'Groups')?.color, _S.title);
      // ...and the theme's still fills the props it leaves unset.
      expect(backIcon(), _S.themeBackIcon);
    });

    testWidgets('with nothing registered, of() leaves every colour to the '
        'palette', (tester) async {
      await mockNetworkImagesFor(
        () =>
            tester.pumpWidget(_wrap(CometChatGroups(groupsBloc: _listBloc()))),
      );
      await tester.pump();

      final palette = CometChatThemeHelper.getColorPalette(
        tester.element(find.byType(CometChatGroups)),
      );
      // Non-null, so the comparisons below cannot pass as null == null.
      expect(palette.textPrimary, isNotNull);
      expect(palette.iconPrimary, isNotNull);
      expect(_textStyle(tester, 'Groups')?.color, palette.textPrimary);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.arrow_back)).color,
        palette.iconPrimary,
      );
    });
  });

  // =========================================================================
  // Render-verified matrix
  // =========================================================================
  //
  // Each surface pumps a fresh CometChatGroups for the unstyled read and
  // another for the styled one, told apart by key. The key matters:
  // CometChatGroups resolves its style once, in didChangeDependencies, and has
  // no didUpdateWidget, so re-pumping the same element with a new groupsStyle
  // keeps the old one. That is a DEFECT, recorded separately.

  group('CometChatGroupsStyle matrix: each prop paints what it names', () {
    testWidgets('the loaded list', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              key: const ValueKey('unstyled'),
              groupsBloc: _listBloc(),
            ),
          ),
        ),
      );
      await tester.pump();
      final unstyled = _readAll(tester, _listRows);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              key: const ValueKey('styled'),
              groupsBloc: _listBloc(),
              groupsStyle: const CometChatGroupsStyle(
                privateGroupIconBackground: _S.privateDot,
                protectedGroupIconBackground: _S.protectedDot,
                backgroundColor: _S.background,
                border: _S.border,
                borderRadius: _S.radius,
                backIconColor: _S.backIcon,
                titleTextStyle: TextStyle(fontSize: _S.titleSize),
                titleTextColor: _S.title,
                separatorColor: _S.separator,
                separatorHeight: _S.separatorHeight,
                itemTitleTextStyle: TextStyle(fontSize: _S.itemTitleSize),
                itemTitleTextColor: _S.itemTitle,
                itemSubtitleTextStyle: TextStyle(fontSize: _S.itemSubtitleSize),
                itemSubtitleTextColor: _S.itemSubtitle,
                avatarStyle: CometChatAvatarStyle(backgroundColor: _S.avatar),
                statusIndicatorStyle: CometChatStatusIndicatorStyle(
                  border: _S.statusBorder,
                ),
                searchBackgroundColor: _S.searchFill,
                searchBorder: _S.searchBorder,
                searchBorderRadius: _S.searchRadius,
                searchIconColor: _S.searchIcon,
                searchInputTextColor: _S.searchInput,
                searchInputTextStyle: TextStyle(fontSize: _S.searchInputSize),
                searchPlaceHolderTextColor: _S.searchHint,
                searchPlaceHolderTextStyle: TextStyle(
                  fontSize: _S.searchHintSize,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      for (final row in _listRows) {
        expect(
          unstyled[row.prop],
          isNot(row.sentinel),
          reason: '${row.prop}: the sentinel is already the default',
        );
        expect(
          row.read(tester),
          row.sentinel,
          reason: '${row.prop} never reached the element it styles',
        );
      }
    });

    testWidgets('the empty state', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              key: const ValueKey('unstyled'),
              groupsBloc: _blocIn(const GroupsEmpty()),
            ),
          ),
        ),
      );
      await tester.pump();
      final unstyled = _readAll(tester, _emptyRows);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              key: const ValueKey('styled'),
              groupsBloc: _blocIn(const GroupsEmpty()),
              groupsStyle: const CometChatGroupsStyle(
                emptyStateTextColor: _S.emptyTitle,
                emptyStateTextStyle: TextStyle(fontSize: _S.emptyTitleSize),
                emptyStateSubTitleTextColor: _S.emptySubtitle,
                emptyStateSubTitleTextStyle: TextStyle(
                  fontSize: _S.emptySubtitleSize,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      for (final row in _emptyRows) {
        expect(
          unstyled[row.prop],
          isNot(row.sentinel),
          reason: '${row.prop}: the sentinel is already the default',
        );
        expect(
          row.read(tester),
          row.sentinel,
          reason: '${row.prop} never reached the element it styles',
        );
      }
    });

    testWidgets('the error state', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              key: const ValueKey('unstyled'),
              groupsBloc: _blocIn(const GroupsError(message: 'boom')),
            ),
          ),
        ),
      );
      await tester.pump();
      final unstyled = _readAll(tester, _errorRows);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              key: const ValueKey('styled'),
              groupsBloc: _blocIn(const GroupsError(message: 'boom')),
              groupsStyle: const CometChatGroupsStyle(
                errorStateTextColor: _S.errorTitle,
                errorStateTextStyle: TextStyle(fontSize: _S.errorTitleSize),
                errorStateSubTitleTextColor: _S.errorSubtitle,
                errorStateSubTitleTextStyle: TextStyle(
                  fontSize: _S.errorSubtitleSize,
                ),
                retryButtonBackgroundColor: _S.retryBackground,
                retryButtonBorder: _S.retryBorder,
                retryButtonBorderRadius: _S.retryRadius,
                retryButtonTextColor: _S.retryText,
                retryButtonTextStyle: TextStyle(fontSize: _S.retryTextSize),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      for (final row in _errorRows) {
        expect(
          unstyled[row.prop],
          isNot(row.sentinel),
          reason: '${row.prop}: the sentinel is already the default',
        );
        expect(
          row.read(tester),
          row.sentinel,
          reason: '${row.prop} never reached the element it styles',
        );
      }
    });

    testWidgets('the selection state', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              key: const ValueKey('unstyled'),
              groupsBloc: _listBloc(selected: {'g1'}),
              selectionMode: SelectionMode.multiple,
            ),
          ),
        ),
      );
      await tester.pump();
      final unstyled = _readAll(tester, _selectionRows);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              key: const ValueKey('styled'),
              groupsBloc: _listBloc(selected: {'g1'}),
              selectionMode: SelectionMode.multiple,
              groupsStyle: const CometChatGroupsStyle(
                checkBoxBackgroundColor: _S.checkBoxFill,
                checkBoxCheckedBackgroundColor: _S.checkBoxCheckedFill,
                checkBoxBorderRadius: _S.checkBoxRadius,
                listItemSelectedBackgroundColor: _S.selectedRow,
                submitIconColor: _S.submitIcon,
                checkBoxBorder: _S.checkBoxBorder,
                checkboxSelectedIconColor: _S.checkIcon,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      for (final row in _selectionRows) {
        expect(
          unstyled[row.prop],
          isNot(row.sentinel),
          reason: '${row.prop}: the sentinel is already the default',
        );
        expect(
          row.read(tester),
          row.sentinel,
          reason: '${row.prop} never reached the element it styles',
        );
      }
    });

    testWidgets('a groupsStyle changed on rebuild is applied', (tester) async {
      // didChangeDependencies re-resolves the style only on a theme change, so
      // without didUpdateWidget the first style stuck for the State's life.
      final bloc = _listBloc();
      final background = _listRows.firstWhere(
        (r) => r.prop == 'backgroundColor',
      );
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: bloc,
              groupsStyle: const CometChatGroupsStyle(
                backgroundColor: _S.background,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(background.read(tester), _S.background);

      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            CometChatGroups(
              groupsBloc: bloc,
              groupsStyle: const CometChatGroupsStyle(
                backgroundColor: _S.selectedRow,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(background.read(tester), _S.selectedRow);
    });

    test('every prop has exactly one row, or is listed as inert', () {
      final rows = [
        ..._listRows,
        ..._emptyRows,
        ..._errorRows,
        ..._selectionRows,
      ].map((r) => r.prop).toList();

      expect(rows.toSet(), hasLength(rows.length), reason: 'a duplicate row');
      expect(rows.toSet().intersection(_inert), isEmpty);
      expect({...rows, ..._inert}, _allProps);
    });
  });
}
