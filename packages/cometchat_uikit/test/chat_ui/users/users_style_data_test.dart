/// Data-class behaviour for [CometChatUsersStyle] — `copyWith`, `merge`,
/// `lerp` and `of`.
///
/// `users_style_props_test.dart` and `users_style_props_matrix_test.dart`
/// already pump every prop through `CometChatUsers` and read it back off the
/// painted widget, so *reaching* the screen is covered. What is not covered is
/// the style object's own plumbing: three hand-written per-field methods,
/// ~180 lines between them, where one transposed line silently drops or
/// swaps a customisation. A dropped `copyWith` field is a real and common bug
/// — the palette next door has exactly that bug in its extendedPrimary block.
///
/// Method: every field carries a number. Colours encode it in the blue
/// channel, text styles in `fontSize`, borders in `width`, radii in the corner
/// radius, and `separatorHeight` is the number itself. The start style uses
/// `n`, the end style `n + 100`, so a field wired to its neighbour reads back
/// the neighbour's number and the row fails by name. Nothing here asserts
/// merely that a constructor ran.
///
///   flutter test test/chat_ui/users/users_style_data_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Encoders ────────────────────────────────────────────────────────────────

/// A colour carrying [i] in its blue channel and nothing else.
Color _c(int i) => Color.fromARGB(0xFF, 0x10, 0x20, i);

double? _blue(Color? c) => c == null ? null : (c.toARGB32() & 0xFF).toDouble();
double? _radius(BorderRadiusGeometry? r) =>
    r == null ? null : (r as BorderRadius).topLeft.x;
double? _boxWidth(BoxBorder? b) => b?.top.width;

// ─── The field table ─────────────────────────────────────────────────────────

typedef _Row = (String name, int n, double? Function(CometChatUsersStyle));

/// Every field the style declares, with the number it carries and how to read
/// that number back.
const List<_Row> _rows = [
  ('backgroundColor', 1, _rBackgroundColor),
  ('border', 2, _rBorder),
  ('borderRadius', 3, _rBorderRadius),
  ('backIconColor', 4, _rBackIconColor),
  ('titleTextStyle', 5, _rTitleTextStyle),
  ('titleTextColor', 6, _rTitleTextColor),
  ('emptyStateTextStyle', 7, _rEmptyStateTextStyle),
  ('emptyStateTextColor', 8, _rEmptyStateTextColor),
  ('errorStateTextStyle', 9, _rErrorStateTextStyle),
  ('errorStateTextColor', 10, _rErrorStateTextColor),
  ('emptyStateSubTitleTextStyle', 11, _rEmptySubStyle),
  ('emptyStateSubTitleTextColor', 12, _rEmptySubColor),
  ('errorStateSubTitleTextStyle', 13, _rErrorSubStyle),
  ('errorStateSubTitleTextColor', 14, _rErrorSubColor),
  ('itemTitleTextStyle', 15, _rItemTitleTextStyle),
  ('itemTitleTextColor', 16, _rItemTitleTextColor),
  ('separatorColor', 17, _rSeparatorColor),
  ('separatorHeight', 18, _rSeparatorHeight),
  ('avatarStyle', 19, _rAvatarStyle),
  ('statusIndicatorStyle', 20, _rStatusIndicatorStyle),
  ('searchBackgroundColor', 21, _rSearchBackgroundColor),
  ('searchBorder', 22, _rSearchBorder),
  ('searchBorderRadius', 23, _rSearchBorderRadius),
  ('searchIconColor', 24, _rSearchIconColor),
  ('searchInputTextColor', 25, _rSearchInputTextColor),
  ('searchInputTextStyle', 26, _rSearchInputTextStyle),
  ('searchPlaceHolderTextColor', 27, _rSearchPlaceHolderTextColor),
  ('searchPlaceHolderTextStyle', 28, _rSearchPlaceHolderTextStyle),
  ('checkBoxBackgroundColor', 29, _rCheckBoxBackgroundColor),
  ('checkBoxBorder', 30, _rCheckBoxBorder),
  ('checkBoxBorderRadius', 31, _rCheckBoxBorderRadius),
  ('checkBoxCheckedBackgroundColor', 32, _rCheckBoxCheckedBackgroundColor),
  ('listItemSelectedBackgroundColor', 33, _rListItemSelectedBackgroundColor),
  ('checkboxSelectedIconColor', 34, _rCheckboxSelectedIconColor),
  ('submitIconColor', 35, _rSubmitIconColor),
  ('retryButtonBackgroundColor', 36, _rRetryButtonBackgroundColor),
  ('retryButtonBorder', 37, _rRetryButtonBorder),
  ('retryButtonBorderRadius', 38, _rRetryButtonBorderRadius),
  ('retryButtonTextColor', 39, _rRetryButtonTextColor),
  ('retryButtonTextStyle', 40, _rRetryButtonTextStyle),
  ('itemBorder', 41, _rItemBorder),
  ('stickyTitleColor', 42, _rStickyTitleColor),
  ('stickyTitleTextStyle', 43, _rStickyTitleTextStyle),
];

double? _rBackgroundColor(CometChatUsersStyle s) => _blue(s.backgroundColor);
double? _rBorder(CometChatUsersStyle s) => _boxWidth(s.border);
double? _rBorderRadius(CometChatUsersStyle s) => _radius(s.borderRadius);
double? _rBackIconColor(CometChatUsersStyle s) => _blue(s.backIconColor);
double? _rTitleTextStyle(CometChatUsersStyle s) => s.titleTextStyle?.fontSize;
double? _rTitleTextColor(CometChatUsersStyle s) => _blue(s.titleTextColor);
double? _rEmptyStateTextStyle(CometChatUsersStyle s) =>
    s.emptyStateTextStyle?.fontSize;
double? _rEmptyStateTextColor(CometChatUsersStyle s) =>
    _blue(s.emptyStateTextColor);
double? _rErrorStateTextStyle(CometChatUsersStyle s) =>
    s.errorStateTextStyle?.fontSize;
double? _rErrorStateTextColor(CometChatUsersStyle s) =>
    _blue(s.errorStateTextColor);
double? _rEmptySubStyle(CometChatUsersStyle s) =>
    s.emptyStateSubTitleTextStyle?.fontSize;
double? _rEmptySubColor(CometChatUsersStyle s) =>
    _blue(s.emptyStateSubTitleTextColor);
double? _rErrorSubStyle(CometChatUsersStyle s) =>
    s.errorStateSubTitleTextStyle?.fontSize;
double? _rErrorSubColor(CometChatUsersStyle s) =>
    _blue(s.errorStateSubTitleTextColor);
double? _rItemTitleTextStyle(CometChatUsersStyle s) =>
    s.itemTitleTextStyle?.fontSize;
double? _rItemTitleTextColor(CometChatUsersStyle s) =>
    _blue(s.itemTitleTextColor);
double? _rSeparatorColor(CometChatUsersStyle s) => _blue(s.separatorColor);
double? _rSeparatorHeight(CometChatUsersStyle s) => s.separatorHeight;
double? _rAvatarStyle(CometChatUsersStyle s) =>
    _blue(s.avatarStyle?.backgroundColor);
double? _rStatusIndicatorStyle(CometChatUsersStyle s) =>
    _blue(s.statusIndicatorStyle?.backgroundColor);
double? _rSearchBackgroundColor(CometChatUsersStyle s) =>
    _blue(s.searchBackgroundColor);
double? _rSearchBorder(CometChatUsersStyle s) => s.searchBorder?.width;
double? _rSearchBorderRadius(CometChatUsersStyle s) =>
    _radius(s.searchBorderRadius);
double? _rSearchIconColor(CometChatUsersStyle s) => _blue(s.searchIconColor);
double? _rSearchInputTextColor(CometChatUsersStyle s) =>
    _blue(s.searchInputTextColor);
double? _rSearchInputTextStyle(CometChatUsersStyle s) =>
    s.searchInputTextStyle?.fontSize;
double? _rSearchPlaceHolderTextColor(CometChatUsersStyle s) =>
    _blue(s.searchPlaceHolderTextColor);
double? _rSearchPlaceHolderTextStyle(CometChatUsersStyle s) =>
    s.searchPlaceHolderTextStyle?.fontSize;
double? _rCheckBoxBackgroundColor(CometChatUsersStyle s) =>
    _blue(s.checkBoxBackgroundColor);
double? _rCheckBoxBorder(CometChatUsersStyle s) => s.checkBoxBorder?.width;
double? _rCheckBoxBorderRadius(CometChatUsersStyle s) =>
    _radius(s.checkBoxBorderRadius);
double? _rCheckBoxCheckedBackgroundColor(CometChatUsersStyle s) =>
    _blue(s.checkBoxCheckedBackgroundColor);
double? _rListItemSelectedBackgroundColor(CometChatUsersStyle s) =>
    _blue(s.listItemSelectedBackgroundColor);
double? _rCheckboxSelectedIconColor(CometChatUsersStyle s) =>
    _blue(s.checkboxSelectedIconColor);
double? _rSubmitIconColor(CometChatUsersStyle s) => _blue(s.submitIconColor);
double? _rRetryButtonBackgroundColor(CometChatUsersStyle s) =>
    _blue(s.retryButtonBackgroundColor);
double? _rRetryButtonBorder(CometChatUsersStyle s) =>
    s.retryButtonBorder?.width;
double? _rRetryButtonBorderRadius(CometChatUsersStyle s) =>
    _radius(s.retryButtonBorderRadius);
double? _rRetryButtonTextColor(CometChatUsersStyle s) =>
    _blue(s.retryButtonTextColor);
double? _rRetryButtonTextStyle(CometChatUsersStyle s) =>
    s.retryButtonTextStyle?.fontSize;
double? _rItemBorder(CometChatUsersStyle s) => _boxWidth(s.itemBorder);
double? _rStickyTitleColor(CometChatUsersStyle s) => _blue(s.stickyTitleColor);
double? _rStickyTitleTextStyle(CometChatUsersStyle s) =>
    s.stickyTitleTextStyle?.fontSize;

// ─── Style builders ──────────────────────────────────────────────────────────

/// A style whose every field carries `n + offset`.
CometChatUsersStyle _style(int offset) {
  double d(int n) => (n + offset).toDouble();
  Color c(int n) => _c(n + offset);
  TextStyle t(int n) => TextStyle(fontSize: d(n));

  return CometChatUsersStyle(
    backgroundColor: c(1),
    border: Border.all(width: d(2)),
    borderRadius: BorderRadius.circular(d(3)),
    backIconColor: c(4),
    titleTextStyle: t(5),
    titleTextColor: c(6),
    emptyStateTextStyle: t(7),
    emptyStateTextColor: c(8),
    errorStateTextStyle: t(9),
    errorStateTextColor: c(10),
    emptyStateSubTitleTextStyle: t(11),
    emptyStateSubTitleTextColor: c(12),
    errorStateSubTitleTextStyle: t(13),
    errorStateSubTitleTextColor: c(14),
    itemTitleTextStyle: t(15),
    itemTitleTextColor: c(16),
    separatorColor: c(17),
    separatorHeight: d(18),
    avatarStyle: CometChatAvatarStyle(backgroundColor: c(19)),
    statusIndicatorStyle: CometChatStatusIndicatorStyle(backgroundColor: c(20)),
    searchBackgroundColor: c(21),
    searchBorder: BorderSide(width: d(22)),
    searchBorderRadius: BorderRadius.circular(d(23)),
    searchIconColor: c(24),
    searchInputTextColor: c(25),
    searchInputTextStyle: t(26),
    searchPlaceHolderTextColor: c(27),
    searchPlaceHolderTextStyle: t(28),
    checkBoxBackgroundColor: c(29),
    checkBoxBorder: BorderSide(width: d(30)),
    checkBoxBorderRadius: BorderRadius.circular(d(31)),
    checkBoxCheckedBackgroundColor: c(32),
    listItemSelectedBackgroundColor: c(33),
    checkboxSelectedIconColor: c(34),
    submitIconColor: c(35),
    retryButtonBackgroundColor: c(36),
    retryButtonBorder: BorderSide(width: d(37)),
    retryButtonBorderRadius: BorderRadius.circular(d(38)),
    retryButtonTextColor: c(39),
    retryButtonTextStyle: t(40),
    itemBorder: Border.all(width: d(41)),
    stickyTitleColor: c(42),
    stickyTitleTextStyle: t(43),
  );
}

/// The same values, handed to `copyWith` one parameter at a time.
CometChatUsersStyle _copyEverything(CometChatUsersStyle onto, int offset) {
  double d(int n) => (n + offset).toDouble();
  Color c(int n) => _c(n + offset);
  TextStyle t(int n) => TextStyle(fontSize: d(n));

  return onto.copyWith(
    backgroundColor: c(1),
    border: Border.all(width: d(2)),
    borderRadius: BorderRadius.circular(d(3)),
    backIconColor: c(4),
    titleTextStyle: t(5),
    titleTextColor: c(6),
    emptyStateTextStyle: t(7),
    emptyStateTextColor: c(8),
    errorStateTextStyle: t(9),
    errorStateTextColor: c(10),
    // Note the parameter spelling: `Subtitle`, where the field is `SubTitle`.
    emptyStateSubtitleTextStyle: t(11),
    emptyStateSubtitleTextColor: c(12),
    errorStateSubTitleTextStyle: t(13),
    errorStateSubTitleTextColor: c(14),
    itemTitleTextStyle: t(15),
    itemTitleTextColor: c(16),
    separatorColor: c(17),
    separatorHeight: d(18),
    avatarStyle: CometChatAvatarStyle(backgroundColor: c(19)),
    statusIndicatorStyle: CometChatStatusIndicatorStyle(backgroundColor: c(20)),
    searchBackgroundColor: c(21),
    searchBorder: BorderSide(width: d(22)),
    searchBorderRadius: BorderRadius.circular(d(23)),
    searchIconColor: c(24),
    searchInputTextColor: c(25),
    searchInputTextStyle: t(26),
    searchPlaceHolderTextColor: c(27),
    searchPlaceHolderTextStyle: t(28),
    checkBoxBackgroundColor: c(29),
    checkBoxBorder: BorderSide(width: d(30)),
    checkBoxBorderRadius: BorderRadius.circular(d(31)),
    checkBoxCheckedBackgroundColor: c(32),
    listItemSelectedBackgroundColor: c(33),
    checkboxSelectedIconColor: c(34),
    submitIconColor: c(35),
    retryButtonBackgroundColor: c(36),
    retryButtonBorder: BorderSide(width: d(37)),
    retryButtonBorderRadius: BorderRadius.circular(d(38)),
    retryButtonTextColor: c(39),
    retryButtonTextStyle: t(40),
    itemBorder: Border.all(width: d(41)),
    stickyTitleColor: c(42),
    stickyTitleTextStyle: t(43),
  );
}

void main() {
  final start = _style(0);
  final end = _style(100);

  // ═══════════════════════════════════════════════════════════════════════════
  // The table itself
  // ═══════════════════════════════════════════════════════════════════════════

  test('the field table covers every field the style declares', () {
    // Guards the table against drift: a field added to the style but not to
    // _rows would be silently untested by everything below.
    expect(_rows.length, 43);
    expect(_rows.map((r) => r.$2).toSet().length, 43, reason: 'unique numbers');
    for (final (name, n, read) in _rows) {
      expect(read(start), n.toDouble(), reason: '$name is mis-numbered');
      expect(read(end), (n + 100).toDouble(), reason: '$name is mis-numbered');
    }
  });

  test('a default style holds nothing', () {
    const s = CometChatUsersStyle();
    for (final (name, _, read) in _rows) {
      expect(read(s), isNull, reason: name);
    }
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // copyWith
  // ═══════════════════════════════════════════════════════════════════════════

  group('copyWith', () {
    test('with no arguments carries every field through', () {
      // The classic copyWith bug: a field the author forgot to forward comes
      // back null here.
      final copy = start.copyWith();
      for (final (name, n, read) in _rows) {
        expect(read(copy), n.toDouble(), reason: '$name was dropped');
      }
    });

    test('every parameter writes its own field and no other', () {
      // Each parameter is given the `end` value; if any parameter is wired to
      // the wrong field, two rows disagree at once.
      final copy = _copyEverything(start, 100);
      for (final (name, n, read) in _rows) {
        expect(read(copy), (n + 100).toDouble(), reason: name);
      }
    });

    test('a single parameter leaves its neighbours alone', () {
      final copy = start.copyWith(separatorColor: _c(117));
      for (final (name, n, read) in _rows) {
        expect(
          read(copy),
          n == 17 ? 117.0 : n.toDouble(),
          reason: '$name changed',
        );
      }
    });

    test('an omitted parameter keeps the receiver value', () {
      final copy = end.copyWith(backgroundColor: _c(1));
      expect(_rBackgroundColor(copy), 1);
      expect(_rBackIconColor(copy), 104);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // merge
  // ═══════════════════════════════════════════════════════════════════════════

  group('merge', () {
    test('null leaves the receiver identical', () {
      expect(identical(start.merge(null), start), isTrue);
    });

    test('every field of the other style wins', () {
      // merge is how a component-level style is layered over the themed one,
      // so a field missing from merge means that customisation never lands.
      final merged = start.merge(end);
      for (final (name, n, read) in _rows) {
        expect(
          read(merged),
          (n + 100).toDouble(),
          reason: '$name did not survive merge',
        );
      }
    });

    test('an empty other style changes nothing', () {
      final merged = start.merge(const CometChatUsersStyle());
      for (final (name, n, read) in _rows) {
        expect(read(merged), n.toDouble(), reason: '$name was blanked');
      }
    });

    test('merge is per-field, not all-or-nothing', () {
      final merged = start.merge(
        const CometChatUsersStyle(separatorHeight: 999),
      );
      expect(_rSeparatorHeight(merged), 999);
      expect(_rSeparatorColor(merged), 17);
      expect(_rBackgroundColor(merged), 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // lerp
  // ═══════════════════════════════════════════════════════════════════════════

  group('lerp', () {
    test('t = 0 reproduces the start style, field for field', () {
      final r = start.lerp(end, 0.0);
      for (final (name, n, read) in _rows) {
        expect(read(r), n.toDouble(), reason: '$name at t=0');
      }
    });

    test('t = 1 reproduces the end style, field for field', () {
      final r = start.lerp(end, 1.0);
      for (final (name, n, read) in _rows) {
        expect(read(r), (n + 100).toDouble(), reason: '$name at t=1');
      }
    });

    test('t = 0.5 lands halfway on every field', () {
      final r = start.lerp(end, 0.5);
      for (final (name, n, read) in _rows) {
        expect(read(r), (n + 50).toDouble(), reason: '$name at t=0.5');
      }
    });

    test('a foreign extension leaves the style untouched', () {
      expect(identical(start.lerp(null, 0.5), start), isTrue);
    });

    test('the border-ish fields survive a lerp from an empty style', () {
      // searchBorder, checkBoxBorder, retryButtonBorder and itemBorder all
      // substitute a default when either side is null, so a half-populated
      // theme animation still produces a paintable border rather than
      // throwing.
      final r = const CometChatUsersStyle().lerp(end, 1.0);
      expect(r.searchBorder?.width, 122);
      expect(r.checkBoxBorder?.width, 130);
      expect(r.retryButtonBorder?.width, 137);
      expect(_boxWidth(r.itemBorder), 141);
      // The nested styles do not: they are reached through `?.` on the
      // receiver, so a null receiver drops the other side entirely.
      expect(r.avatarStyle, isNull);
      expect(r.statusIndicatorStyle, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // of
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('of() ignores its context and returns the bare defaults', (
    tester,
  ) async {
    // `of` predates CometChatThemeHelper: it does not read the theme, so a
    // style registered as a ThemeExtension is NOT what it returns. Components
    // resolve the themed style through the helper instead.
    late CometChatUsersStyle resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: <ThemeExtension<dynamic>>[start]),
        home: Builder(
          builder: (context) {
            resolved = CometChatUsersStyle.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(resolved.backgroundColor, isNull);
    expect(
      Theme.of(
        tester.element(find.byType(SizedBox)),
      ).extension<CometChatUsersStyle>()?.backgroundColor,
      _c(1),
    );
  });
}
