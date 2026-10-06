/// Data-class behaviour for [CometChatGroupMembersStyle] — `copyWith`,
/// `merge`, `lerp` and `of`.
///
/// `widget/group_members_style_props_test.dart` covers the props on their way
/// to the screen. This file covers the style object's own three hand-written
/// per-field methods (~380 lines), where a transposed or forgotten line
/// silently drops a customisation without any widget noticing.
///
/// Method: every field carries a number — colours in the blue channel, text
/// styles in `fontSize`, borders in `width`, radii and padding in their own
/// scalar, nested styles in their background colour. The start style uses `n`,
/// the end style `n + 100`, so a field wired to its neighbour reads back the
/// neighbour's number and the row fails by name.
///
///   flutter test test/chat_ui/group_members/group_members_style_data_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Encoders ────────────────────────────────────────────────────────────────

Color _c(int i) => Color.fromARGB(0xFF, 0x10, 0x20, i);

double? _blue(Color? c) => c == null ? null : (c.toARGB32() & 0xFF).toDouble();
double? _radius(BorderRadiusGeometry? r) =>
    r == null ? null : (r as BorderRadius).topLeft.x;
double? _boxWidth(BoxBorder? b) => b?.top.width;
double? _pad(EdgeInsetsGeometry? p) =>
    p == null ? null : (p as EdgeInsets).left;

// ─── The field table ─────────────────────────────────────────────────────────

typedef _Row = (
  String name,
  int n,
  double? Function(CometChatGroupMembersStyle),
);

const List<_Row> _rows = [
  ('titleStyle', 1, _rTitleStyle),
  ('backIconColor', 2, _rBackIconColor),
  ('searchBackground', 3, _rSearchBackground),
  ('searchBorderRadius', 4, _rSearchBorderRadius),
  ('searchIconColor', 5, _rSearchIconColor),
  ('searchPlaceholderStyle', 6, _rSearchPlaceholderStyle),
  ('searchTextStyle', 7, _rSearchTextStyle),
  ('loadingIconColor', 8, _rLoadingIconColor),
  ('emptyStateTextStyle', 9, _rEmptyStateTextStyle),
  ('emptyStateTextColor', 10, _rEmptyStateTextColor),
  ('emptyStateSubtitleTextStyle', 11, _rEmptySubStyle),
  ('emptyStateSubtitleTextColor', 12, _rEmptySubColor),
  ('errorStateTextStyle', 13, _rErrorStateTextStyle),
  ('errorStateSubtitleStyle', 14, _rErrorSubStyle),
  ('onlineStatusColor', 15, _rOnlineStatusColor),
  ('listPadding', 16, _rListPadding),
  ('backgroundColor', 17, _rBackgroundColor),
  ('border', 18, _rBorder),
  ('borderRadius', 19, _rBorderRadius),
  ('checkboxCheckedBackgroundColor', 20, _rCheckboxChecked),
  ('checkboxBackgroundColor', 21, _rCheckboxBackground),
  ('checkboxSelectedIconColor', 22, _rCheckboxSelectedIcon),
  ('checkboxBorder', 23, _rCheckboxBorder),
  ('checkboxBorderRadius', 24, _rCheckboxBorderRadius),
  ('listItemSelectedBackgroundColor', 25, _rListItemSelected),
  ('confirmDialogStyle', 26, _rConfirmDialogStyle),
  ('listItemStyle', 27, _rListItemStyle),
  ('avatarStyle', 28, _rAvatarStyle),
  ('statusIndicatorStyle', 29, _rStatusIndicatorStyle),
  ('retryButtonBackgroundColor', 30, _rRetryBackground),
  ('retryButtonTextColor', 31, _rRetryTextColor),
  ('retryButtonTextStyle', 32, _rRetryTextStyle),
  ('retryButtonBorder', 33, _rRetryBorder),
  ('retryButtonBorderRadius', 34, _rRetryBorderRadius),
  ('separatorHeight', 35, _rSeparatorHeight),
  ('separatorColor', 36, _rSeparatorColor),
  ('ownerMemberScopeBackgroundColor', 37, _rOwnerScopeBackground),
  ('moderatorMemberScopeBackgroundColor', 38, _rModeratorScopeBackground),
  ('adminMemberScopeBackgroundColor', 39, _rAdminScopeBackground),
  ('ownerMemberScopeTextColor', 40, _rOwnerScopeTextColor),
  ('moderatorMemberScopeTextColor', 41, _rModeratorScopeTextColor),
  ('adminMemberScopeTextColor', 42, _rAdminScopeTextColor),
  ('ownerMemberScopeBorder', 43, _rOwnerScopeBorder),
  ('moderatorMemberScopeBorder', 44, _rModeratorScopeBorder),
  ('adminMemberScopeBorder', 45, _rAdminScopeBorder),
  ('adminMemberScopeTextStyle', 46, _rAdminScopeTextStyle),
  ('moderatorMemberScopeTextStyle', 47, _rModeratorScopeTextStyle),
  ('ownerMemberScopeTextStyle', 48, _rOwnerScopeTextStyle),
  ('submitIconColor', 49, _rSubmitIconColor),
  ('changeScopeStyle', 50, _rChangeScopeStyle),
  ('optionsBackgroundColor', 51, _rOptionsBackground),
  ('optionsIconColor', 52, _rOptionsIconColor),
  ('optionsTextStyle', 53, _rOptionsTextStyle),
];

double? _rTitleStyle(CometChatGroupMembersStyle s) => s.titleStyle?.fontSize;
double? _rBackIconColor(CometChatGroupMembersStyle s) => _blue(s.backIconColor);
double? _rSearchBackground(CometChatGroupMembersStyle s) =>
    _blue(s.searchBackground);
double? _rSearchBorderRadius(CometChatGroupMembersStyle s) =>
    _radius(s.searchBorderRadius);
double? _rSearchIconColor(CometChatGroupMembersStyle s) =>
    _blue(s.searchIconColor);
double? _rSearchPlaceholderStyle(CometChatGroupMembersStyle s) =>
    s.searchPlaceholderStyle?.fontSize;
double? _rSearchTextStyle(CometChatGroupMembersStyle s) =>
    s.searchTextStyle?.fontSize;
double? _rLoadingIconColor(CometChatGroupMembersStyle s) =>
    _blue(s.loadingIconColor);
double? _rEmptyStateTextStyle(CometChatGroupMembersStyle s) =>
    s.emptyStateTextStyle?.fontSize;
double? _rEmptyStateTextColor(CometChatGroupMembersStyle s) =>
    _blue(s.emptyStateTextColor);
double? _rEmptySubStyle(CometChatGroupMembersStyle s) =>
    s.emptyStateSubtitleTextStyle?.fontSize;
double? _rEmptySubColor(CometChatGroupMembersStyle s) =>
    _blue(s.emptyStateSubtitleTextColor);
double? _rErrorStateTextStyle(CometChatGroupMembersStyle s) =>
    s.errorStateTextStyle?.fontSize;
double? _rErrorSubStyle(CometChatGroupMembersStyle s) =>
    s.errorStateSubtitleStyle?.fontSize;
double? _rOnlineStatusColor(CometChatGroupMembersStyle s) =>
    _blue(s.onlineStatusColor);
double? _rListPadding(CometChatGroupMembersStyle s) => _pad(s.listPadding);
double? _rBackgroundColor(CometChatGroupMembersStyle s) =>
    _blue(s.backgroundColor);
double? _rBorder(CometChatGroupMembersStyle s) => _boxWidth(s.border);
double? _rBorderRadius(CometChatGroupMembersStyle s) => _radius(s.borderRadius);
double? _rCheckboxChecked(CometChatGroupMembersStyle s) =>
    _blue(s.checkboxCheckedBackgroundColor);
double? _rCheckboxBackground(CometChatGroupMembersStyle s) =>
    _blue(s.checkboxBackgroundColor);
double? _rCheckboxSelectedIcon(CometChatGroupMembersStyle s) =>
    _blue(s.checkboxSelectedIconColor);
double? _rCheckboxBorder(CometChatGroupMembersStyle s) =>
    s.checkboxBorder?.width;
double? _rCheckboxBorderRadius(CometChatGroupMembersStyle s) =>
    _radius(s.checkboxBorderRadius);
double? _rListItemSelected(CometChatGroupMembersStyle s) =>
    _blue(s.listItemSelectedBackgroundColor);
double? _rConfirmDialogStyle(CometChatGroupMembersStyle s) =>
    _blue(s.confirmDialogStyle?.backgroundColor);
double? _rListItemStyle(CometChatGroupMembersStyle s) =>
    _blue(s.listItemStyle?.background);
double? _rAvatarStyle(CometChatGroupMembersStyle s) =>
    _blue(s.avatarStyle?.backgroundColor);
double? _rStatusIndicatorStyle(CometChatGroupMembersStyle s) =>
    _blue(s.statusIndicatorStyle?.backgroundColor);
double? _rRetryBackground(CometChatGroupMembersStyle s) =>
    _blue(s.retryButtonBackgroundColor);
double? _rRetryTextColor(CometChatGroupMembersStyle s) =>
    _blue(s.retryButtonTextColor);
double? _rRetryTextStyle(CometChatGroupMembersStyle s) =>
    s.retryButtonTextStyle?.fontSize;
double? _rRetryBorder(CometChatGroupMembersStyle s) =>
    s.retryButtonBorder?.width;
double? _rRetryBorderRadius(CometChatGroupMembersStyle s) =>
    _radius(s.retryButtonBorderRadius);
double? _rSeparatorHeight(CometChatGroupMembersStyle s) => s.separatorHeight;
double? _rSeparatorColor(CometChatGroupMembersStyle s) =>
    _blue(s.separatorColor);
double? _rOwnerScopeBackground(CometChatGroupMembersStyle s) =>
    _blue(s.ownerMemberScopeBackgroundColor);
double? _rModeratorScopeBackground(CometChatGroupMembersStyle s) =>
    _blue(s.moderatorMemberScopeBackgroundColor);
double? _rAdminScopeBackground(CometChatGroupMembersStyle s) =>
    _blue(s.adminMemberScopeBackgroundColor);
double? _rOwnerScopeTextColor(CometChatGroupMembersStyle s) =>
    _blue(s.ownerMemberScopeTextColor);
double? _rModeratorScopeTextColor(CometChatGroupMembersStyle s) =>
    _blue(s.moderatorMemberScopeTextColor);
double? _rAdminScopeTextColor(CometChatGroupMembersStyle s) =>
    _blue(s.adminMemberScopeTextColor);
double? _rOwnerScopeBorder(CometChatGroupMembersStyle s) =>
    _boxWidth(s.ownerMemberScopeBorder);
double? _rModeratorScopeBorder(CometChatGroupMembersStyle s) =>
    _boxWidth(s.moderatorMemberScopeBorder);
double? _rAdminScopeBorder(CometChatGroupMembersStyle s) =>
    _boxWidth(s.adminMemberScopeBorder);
double? _rAdminScopeTextStyle(CometChatGroupMembersStyle s) =>
    s.adminMemberScopeTextStyle?.fontSize;
double? _rModeratorScopeTextStyle(CometChatGroupMembersStyle s) =>
    s.moderatorMemberScopeTextStyle?.fontSize;
double? _rOwnerScopeTextStyle(CometChatGroupMembersStyle s) =>
    s.ownerMemberScopeTextStyle?.fontSize;
double? _rSubmitIconColor(CometChatGroupMembersStyle s) =>
    _blue(s.submitIconColor);
double? _rChangeScopeStyle(CometChatGroupMembersStyle s) =>
    _blue(s.changeScopeStyle?.backgroundColor);
double? _rOptionsBackground(CometChatGroupMembersStyle s) =>
    _blue(s.optionsBackgroundColor);
double? _rOptionsIconColor(CometChatGroupMembersStyle s) =>
    _blue(s.optionsIconColor);
double? _rOptionsTextStyle(CometChatGroupMembersStyle s) =>
    s.optionsTextStyle?.fontSize;

// ─── Style builders ──────────────────────────────────────────────────────────

CometChatGroupMembersStyle _style(int offset) {
  double d(int n) => (n + offset).toDouble();
  Color c(int n) => _c(n + offset);
  TextStyle t(int n) => TextStyle(fontSize: d(n));

  return CometChatGroupMembersStyle(
    titleStyle: t(1),
    backIconColor: c(2),
    searchBackground: c(3),
    searchBorderRadius: BorderRadius.circular(d(4)),
    searchIconColor: c(5),
    searchPlaceholderStyle: t(6),
    searchTextStyle: t(7),
    loadingIconColor: c(8),
    emptyStateTextStyle: t(9),
    emptyStateTextColor: c(10),
    emptyStateSubtitleTextStyle: t(11),
    emptyStateSubtitleTextColor: c(12),
    errorStateTextStyle: t(13),
    errorStateSubtitleStyle: t(14),
    onlineStatusColor: c(15),
    listPadding: EdgeInsets.all(d(16)),
    backgroundColor: c(17),
    border: Border.all(width: d(18)),
    borderRadius: BorderRadius.circular(d(19)),
    checkboxCheckedBackgroundColor: c(20),
    checkboxBackgroundColor: c(21),
    checkboxSelectedIconColor: c(22),
    checkboxBorder: BorderSide(width: d(23)),
    checkboxBorderRadius: BorderRadius.circular(d(24)),
    listItemSelectedBackgroundColor: c(25),
    confirmDialogStyle: CometChatConfirmDialogStyle(backgroundColor: c(26)),
    listItemStyle: ListItemStyle(background: c(27)),
    avatarStyle: CometChatAvatarStyle(backgroundColor: c(28)),
    statusIndicatorStyle: CometChatStatusIndicatorStyle(backgroundColor: c(29)),
    retryButtonBackgroundColor: c(30),
    retryButtonTextColor: c(31),
    retryButtonTextStyle: t(32),
    retryButtonBorder: BorderSide(width: d(33)),
    retryButtonBorderRadius: BorderRadius.circular(d(34)),
    separatorHeight: d(35),
    separatorColor: c(36),
    ownerMemberScopeBackgroundColor: c(37),
    moderatorMemberScopeBackgroundColor: c(38),
    adminMemberScopeBackgroundColor: c(39),
    ownerMemberScopeTextColor: c(40),
    moderatorMemberScopeTextColor: c(41),
    adminMemberScopeTextColor: c(42),
    ownerMemberScopeBorder: Border.all(width: d(43)),
    moderatorMemberScopeBorder: Border.all(width: d(44)),
    adminMemberScopeBorder: Border.all(width: d(45)),
    adminMemberScopeTextStyle: t(46),
    moderatorMemberScopeTextStyle: t(47),
    ownerMemberScopeTextStyle: t(48),
    submitIconColor: c(49),
    changeScopeStyle: CometChatChangeScopeStyle(backgroundColor: c(50)),
    optionsBackgroundColor: c(51),
    optionsIconColor: c(52),
    optionsTextStyle: t(53),
  );
}

CometChatGroupMembersStyle _copyEverything(
  CometChatGroupMembersStyle onto,
  int offset,
) {
  double d(int n) => (n + offset).toDouble();
  Color c(int n) => _c(n + offset);
  TextStyle t(int n) => TextStyle(fontSize: d(n));

  return onto.copyWith(
    titleStyle: t(1),
    backIconColor: c(2),
    searchBackground: c(3),
    searchBorderRadius: BorderRadius.circular(d(4)),
    searchIconColor: c(5),
    searchPlaceholderStyle: t(6),
    searchTextStyle: t(7),
    loadingIconColor: c(8),
    emptyStateTextStyle: t(9),
    emptyStateTextColor: c(10),
    emptyStateSubtitleTextStyle: t(11),
    emptyStateSubtitleTextColor: c(12),
    errorStateTextStyle: t(13),
    errorStateSubtitleStyle: t(14),
    onlineStatusColor: c(15),
    listPadding: EdgeInsets.all(d(16)),
    backgroundColor: c(17),
    border: Border.all(width: d(18)),
    borderRadius: BorderRadius.circular(d(19)),
    checkboxCheckedBackgroundColor: c(20),
    checkboxBackgroundColor: c(21),
    checkboxSelectedIconColor: c(22),
    checkboxBorder: BorderSide(width: d(23)),
    checkboxBorderRadius: BorderRadius.circular(d(24)),
    listItemSelectedBackgroundColor: c(25),
    confirmDialogStyle: CometChatConfirmDialogStyle(backgroundColor: c(26)),
    listItemStyle: ListItemStyle(background: c(27)),
    avatarStyle: CometChatAvatarStyle(backgroundColor: c(28)),
    statusIndicatorStyle: CometChatStatusIndicatorStyle(backgroundColor: c(29)),
    retryButtonBackgroundColor: c(30),
    retryButtonTextColor: c(31),
    retryButtonTextStyle: t(32),
    retryButtonBorder: BorderSide(width: d(33)),
    retryButtonBorderRadius: BorderRadius.circular(d(34)),
    separatorHeight: d(35),
    separatorColor: c(36),
    ownerMemberScopeBackgroundColor: c(37),
    moderatorMemberScopeBackgroundColor: c(38),
    adminMemberScopeBackgroundColor: c(39),
    ownerMemberScopeTextColor: c(40),
    moderatorMemberScopeTextColor: c(41),
    adminMemberScopeTextColor: c(42),
    ownerMemberScopeBorder: Border.all(width: d(43)),
    moderatorMemberScopeBorder: Border.all(width: d(44)),
    adminMemberScopeBorder: Border.all(width: d(45)),
    adminMemberScopeTextStyle: t(46),
    moderatorMemberScopeTextStyle: t(47),
    ownerMemberScopeTextStyle: t(48),
    submitIconColor: c(49),
    changeScopeStyle: CometChatChangeScopeStyle(backgroundColor: c(50)),
    optionsBackgroundColor: c(51),
    optionsIconColor: c(52),
    optionsTextStyle: t(53),
  );
}

void main() {
  final start = _style(0);
  final end = _style(100);

  test('the field table covers every field the style declares', () {
    expect(_rows.length, 53);
    expect(_rows.map((r) => r.$2).toSet().length, 53, reason: 'unique numbers');
    for (final (name, n, read) in _rows) {
      expect(read(start), n.toDouble(), reason: '$name is mis-numbered');
      expect(read(end), (n + 100).toDouble(), reason: '$name is mis-numbered');
    }
  });

  test('a default style holds nothing', () {
    const s = CometChatGroupMembersStyle();
    for (final (name, _, read) in _rows) {
      expect(read(s), isNull, reason: name);
    }
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // copyWith
  // ═══════════════════════════════════════════════════════════════════════════

  group('copyWith', () {
    test('with no arguments carries every field through', () {
      final copy = start.copyWith();
      for (final (name, n, read) in _rows) {
        expect(read(copy), n.toDouble(), reason: '$name was dropped');
      }
    });

    test('every parameter writes its own field and no other', () {
      final copy = _copyEverything(start, 100);
      for (final (name, n, read) in _rows) {
        expect(read(copy), (n + 100).toDouble(), reason: name);
      }
    });

    test('a single parameter leaves its neighbours alone', () {
      // The three member-scope blocks are the easiest place in this style to
      // cross owner/moderator/admin wires, so the probe lands in the middle
      // of one.
      final copy = start.copyWith(moderatorMemberScopeTextColor: _c(141));
      for (final (name, n, read) in _rows) {
        expect(
          read(copy),
          n == 41 ? 141.0 : n.toDouble(),
          reason: '$name changed',
        );
      }
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
      final merged = start.merge(const CometChatGroupMembersStyle());
      for (final (name, n, read) in _rows) {
        expect(read(merged), n.toDouble(), reason: '$name was blanked');
      }
    });

    test('merge is per-field, not all-or-nothing', () {
      final merged = start.merge(
        const CometChatGroupMembersStyle(separatorHeight: 999),
      );
      expect(_rSeparatorHeight(merged), 999);
      expect(_rSeparatorColor(merged), 36);
      expect(_rTitleStyle(merged), 1);
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

    test('a null other leaves the style untouched', () {
      expect(identical(start.lerp(null, 0.5), start), isTrue);
    });

    test(
      'lerping from an empty style keeps the borders but drops the nested styles',
      () {
        // checkboxBorder, retryButtonBorder and the three member-scope borders
        // substitute a default when either side is null, so they still arrive.
        final r = const CometChatGroupMembersStyle().lerp(end, 1.0);
        expect(_rCheckboxBorder(r), 123);
        expect(_rRetryBorder(r), 133);
        expect(_rOwnerScopeBorder(r), 143);
        expect(_rModeratorScopeBorder(r), 144);
        expect(_rAdminScopeBorder(r), 145);
        // confirmDialogStyle, changeScopeStyle, avatarStyle and
        // statusIndicatorStyle are reached through `?.` on the receiver only,
        // with no `?? other` fallback, so animating in from a theme that does
        // not set them ends with them still unset. Search's equivalent lerp does
        // carry the fallback; this one does not.
        expect(r.confirmDialogStyle, isNull);
        expect(r.changeScopeStyle, isNull);
        expect(r.avatarStyle, isNull);
        expect(r.statusIndicatorStyle, isNull);
      },
    );

    test(
      'listItemStyle is rebuilt rather than carried, so it is never null',
      () {
        // lerp always constructs a ListItemStyle from five interpolated
        // sub-fields. A style that had none before lerping comes out with an
        // empty-but-present one.
        final r = const CometChatGroupMembersStyle().lerp(
          const CometChatGroupMembersStyle(),
          0.5,
        );
        expect(r.listItemStyle, isNotNull);
        expect(r.listItemStyle?.background, isNull);
        // Only those five sub-fields survive: anything else on the source
        // ListItemStyle is dropped by the rebuild.
        final withPadding = CometChatGroupMembersStyle(
          listItemStyle: const ListItemStyle(
            background: Color(0xFF102030),
            padding: EdgeInsets.all(8),
          ),
        );
        final lerped = withPadding.lerp(withPadding, 0.0);
        expect(lerped.listItemStyle?.background, const Color(0xFF102030));
        expect(lerped.listItemStyle?.padding, isNull);
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // of
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('of() ignores its context and returns the bare defaults', (
    tester,
  ) async {
    late CometChatGroupMembersStyle resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: <ThemeExtension<dynamic>>[start]),
        home: Builder(
          builder: (context) {
            resolved = CometChatGroupMembersStyle.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(resolved.backgroundColor, isNull);
    expect(
      Theme.of(
        tester.element(find.byType(SizedBox)),
      ).extension<CometChatGroupMembersStyle>()?.backgroundColor,
      _c(17),
    );
  });
}
