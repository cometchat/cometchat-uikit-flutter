/// Data-class behaviour for [CometChatSearchStyle] — `copyWith`, `merge`,
/// `lerp` and `of`.
///
/// `search_style_props_test.dart` covers the props on their way to the screen.
/// This file covers the style object's own three hand-written per-field
/// methods (~300 lines), where a transposed or forgotten line silently drops a
/// customisation without any widget noticing.
///
/// Method: every field carries a number — colours in the blue channel, text
/// styles in `fontSize`, borders in `width`, radii in the corner radius,
/// nested styles in their own background colour. The start style uses `n`, the
/// end style `n + 100`, so a field wired to its neighbour reads back the
/// neighbour's number and the row fails by name.
///
///   flutter test test/chat_ui/search/search_style_data_test.dart
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

// ─── The field table ─────────────────────────────────────────────────────────

typedef _Row = (String name, int n, double? Function(CometChatSearchStyle));

const List<_Row> _rows = [
  ('backgroundColor', 1, _rBackground),
  ('searchBackgroundColor', 2, _rSearchBackground),
  ('searchTextColor', 3, _rSearchTextColor),
  ('searchTextStyle', 4, _rSearchTextStyle),
  ('searchPlaceHolderTextColor', 5, _rSearchPlaceholderColor),
  ('searchPlaceHolderTextStyle', 6, _rSearchPlaceholderStyle),
  ('searchBorder', 7, _rSearchBorder),
  ('searchBorderRadius', 8, _rSearchBorderRadius),
  ('searchBackIconColor', 9, _rSearchBackIcon),
  ('searchClearIconColor', 10, _rSearchClearIcon),
  ('searchFilterChipBackgroundColor', 11, _rChipBackground),
  ('searchFilterChipSelectedBackgroundColor', 12, _rChipSelectedBackground),
  ('searchFilterChipTextColor', 13, _rChipTextColor),
  ('searchFilterChipSelectedTextColor', 14, _rChipSelectedTextColor),
  ('searchFilterChipTextStyle', 15, _rChipTextStyle),
  ('searchFilterChipSelectedTextStyle', 16, _rChipSelectedTextStyle),
  ('searchFilterChipBorder', 17, _rChipBorder),
  ('searchFilterChipSelectedBorder', 18, _rChipSelectedBorder),
  ('searchFilterChipBorderRadius', 19, _rChipBorderRadius),
  ('searchFilterIconColor', 20, _rFilterIcon),
  ('searchFilterSelectedIconColor', 21, _rFilterSelectedIcon),
  ('sectionHeaderTextColor', 22, _rSectionHeaderColor),
  ('sectionHeaderTextStyle', 23, _rSectionHeaderStyle),
  ('searchConversationTitleTextColor', 24, _rConvTitleColor),
  ('searchConversationTitleTextStyle', 25, _rConvTitleStyle),
  ('searchConversationSubtitleTextColor', 26, _rConvSubtitleColor),
  ('searchConversationSubtitleTextStyle', 27, _rConvSubtitleStyle),
  ('searchConversationItemBackgroundColor', 28, _rConvItemBackground),
  ('searchMessageSenderTextColor', 29, _rSenderColor),
  ('searchMessageSenderTextStyle', 30, _rSenderStyle),
  ('searchMessagePreviewTextColor', 31, _rPreviewColor),
  ('searchMessagePreviewTextStyle', 32, _rPreviewStyle),
  ('searchMessageDateTextColor', 33, _rDateColor),
  ('searchMessageDateTextStyle', 34, _rDateTextStyle),
  ('emptyStateTextColor', 35, _rEmptyColor),
  ('emptyStateTextStyle', 36, _rEmptyStyle),
  ('emptyStateSubTitleTextColor', 37, _rEmptySubColor),
  ('emptyStateSubTitleTextStyle', 38, _rEmptySubStyle),
  ('errorStateTextColor', 39, _rErrorColor),
  ('errorStateTextStyle', 40, _rErrorStyle),
  ('errorStateSubTitleTextColor', 41, _rErrorSubColor),
  ('errorStateSubTitleTextStyle', 42, _rErrorSubStyle),
  ('seeMoreTextColor', 43, _rSeeMoreColor),
  ('seeMoreTextStyle', 44, _rSeeMoreStyle),
  ('avatarStyle', 45, _rAvatarStyle),
  ('statusIndicatorStyle', 46, _rStatusIndicatorStyle),
  ('badgeStyle', 47, _rBadgeStyle),
  ('receiptStyle', 48, _rReceiptStyle),
  ('dateStyle', 49, _rDateStyle),
];

double? _rBackground(CometChatSearchStyle s) => _blue(s.backgroundColor);
double? _rSearchBackground(CometChatSearchStyle s) =>
    _blue(s.searchBackgroundColor);
double? _rSearchTextColor(CometChatSearchStyle s) => _blue(s.searchTextColor);
double? _rSearchTextStyle(CometChatSearchStyle s) =>
    s.searchTextStyle?.fontSize;
double? _rSearchPlaceholderColor(CometChatSearchStyle s) =>
    _blue(s.searchPlaceHolderTextColor);
double? _rSearchPlaceholderStyle(CometChatSearchStyle s) =>
    s.searchPlaceHolderTextStyle?.fontSize;
double? _rSearchBorder(CometChatSearchStyle s) => s.searchBorder?.width;
double? _rSearchBorderRadius(CometChatSearchStyle s) =>
    _radius(s.searchBorderRadius);
double? _rSearchBackIcon(CometChatSearchStyle s) =>
    _blue(s.searchBackIconColor);
double? _rSearchClearIcon(CometChatSearchStyle s) =>
    _blue(s.searchClearIconColor);
double? _rChipBackground(CometChatSearchStyle s) =>
    _blue(s.searchFilterChipBackgroundColor);
double? _rChipSelectedBackground(CometChatSearchStyle s) =>
    _blue(s.searchFilterChipSelectedBackgroundColor);
double? _rChipTextColor(CometChatSearchStyle s) =>
    _blue(s.searchFilterChipTextColor);
double? _rChipSelectedTextColor(CometChatSearchStyle s) =>
    _blue(s.searchFilterChipSelectedTextColor);
double? _rChipTextStyle(CometChatSearchStyle s) =>
    s.searchFilterChipTextStyle?.fontSize;
double? _rChipSelectedTextStyle(CometChatSearchStyle s) =>
    s.searchFilterChipSelectedTextStyle?.fontSize;
double? _rChipBorder(CometChatSearchStyle s) =>
    _boxWidth(s.searchFilterChipBorder);
double? _rChipSelectedBorder(CometChatSearchStyle s) =>
    _boxWidth(s.searchFilterChipSelectedBorder);
double? _rChipBorderRadius(CometChatSearchStyle s) =>
    _radius(s.searchFilterChipBorderRadius);
double? _rFilterIcon(CometChatSearchStyle s) => _blue(s.searchFilterIconColor);
double? _rFilterSelectedIcon(CometChatSearchStyle s) =>
    _blue(s.searchFilterSelectedIconColor);
double? _rSectionHeaderColor(CometChatSearchStyle s) =>
    _blue(s.sectionHeaderTextColor);
double? _rSectionHeaderStyle(CometChatSearchStyle s) =>
    s.sectionHeaderTextStyle?.fontSize;
double? _rConvTitleColor(CometChatSearchStyle s) =>
    _blue(s.searchConversationTitleTextColor);
double? _rConvTitleStyle(CometChatSearchStyle s) =>
    s.searchConversationTitleTextStyle?.fontSize;
double? _rConvSubtitleColor(CometChatSearchStyle s) =>
    _blue(s.searchConversationSubtitleTextColor);
double? _rConvSubtitleStyle(CometChatSearchStyle s) =>
    s.searchConversationSubtitleTextStyle?.fontSize;
double? _rConvItemBackground(CometChatSearchStyle s) =>
    _blue(s.searchConversationItemBackgroundColor);
double? _rSenderColor(CometChatSearchStyle s) =>
    _blue(s.searchMessageSenderTextColor);
double? _rSenderStyle(CometChatSearchStyle s) =>
    s.searchMessageSenderTextStyle?.fontSize;
double? _rPreviewColor(CometChatSearchStyle s) =>
    _blue(s.searchMessagePreviewTextColor);
double? _rPreviewStyle(CometChatSearchStyle s) =>
    s.searchMessagePreviewTextStyle?.fontSize;
double? _rDateColor(CometChatSearchStyle s) =>
    _blue(s.searchMessageDateTextColor);
double? _rDateTextStyle(CometChatSearchStyle s) =>
    s.searchMessageDateTextStyle?.fontSize;
double? _rEmptyColor(CometChatSearchStyle s) => _blue(s.emptyStateTextColor);
double? _rEmptyStyle(CometChatSearchStyle s) => s.emptyStateTextStyle?.fontSize;
double? _rEmptySubColor(CometChatSearchStyle s) =>
    _blue(s.emptyStateSubTitleTextColor);
double? _rEmptySubStyle(CometChatSearchStyle s) =>
    s.emptyStateSubTitleTextStyle?.fontSize;
double? _rErrorColor(CometChatSearchStyle s) => _blue(s.errorStateTextColor);
double? _rErrorStyle(CometChatSearchStyle s) => s.errorStateTextStyle?.fontSize;
double? _rErrorSubColor(CometChatSearchStyle s) =>
    _blue(s.errorStateSubTitleTextColor);
double? _rErrorSubStyle(CometChatSearchStyle s) =>
    s.errorStateSubTitleTextStyle?.fontSize;
double? _rSeeMoreColor(CometChatSearchStyle s) => _blue(s.seeMoreTextColor);
double? _rSeeMoreStyle(CometChatSearchStyle s) => s.seeMoreTextStyle?.fontSize;
double? _rAvatarStyle(CometChatSearchStyle s) =>
    _blue(s.avatarStyle?.backgroundColor);
double? _rStatusIndicatorStyle(CometChatSearchStyle s) =>
    _blue(s.statusIndicatorStyle?.backgroundColor);
double? _rBadgeStyle(CometChatSearchStyle s) =>
    _blue(s.badgeStyle?.backgroundColor);
double? _rReceiptStyle(CometChatSearchStyle s) =>
    _blue(s.receiptStyle?.waitIconColor);
double? _rDateStyle(CometChatSearchStyle s) =>
    _blue(s.dateStyle?.backgroundColor);

// ─── Style builders ──────────────────────────────────────────────────────────

CometChatSearchStyle _style(int offset) {
  double d(int n) => (n + offset).toDouble();
  Color c(int n) => _c(n + offset);
  TextStyle t(int n) => TextStyle(fontSize: d(n));

  return CometChatSearchStyle(
    backgroundColor: c(1),
    searchBackgroundColor: c(2),
    searchTextColor: c(3),
    searchTextStyle: t(4),
    searchPlaceHolderTextColor: c(5),
    searchPlaceHolderTextStyle: t(6),
    searchBorder: BorderSide(width: d(7)),
    searchBorderRadius: BorderRadius.circular(d(8)),
    searchBackIconColor: c(9),
    searchClearIconColor: c(10),
    searchFilterChipBackgroundColor: c(11),
    searchFilterChipSelectedBackgroundColor: c(12),
    searchFilterChipTextColor: c(13),
    searchFilterChipSelectedTextColor: c(14),
    searchFilterChipTextStyle: t(15),
    searchFilterChipSelectedTextStyle: t(16),
    searchFilterChipBorder: Border.all(width: d(17)),
    searchFilterChipSelectedBorder: Border.all(width: d(18)),
    searchFilterChipBorderRadius: BorderRadius.circular(d(19)),
    searchFilterIconColor: c(20),
    searchFilterSelectedIconColor: c(21),
    sectionHeaderTextColor: c(22),
    sectionHeaderTextStyle: t(23),
    searchConversationTitleTextColor: c(24),
    searchConversationTitleTextStyle: t(25),
    searchConversationSubtitleTextColor: c(26),
    searchConversationSubtitleTextStyle: t(27),
    searchConversationItemBackgroundColor: c(28),
    searchMessageSenderTextColor: c(29),
    searchMessageSenderTextStyle: t(30),
    searchMessagePreviewTextColor: c(31),
    searchMessagePreviewTextStyle: t(32),
    searchMessageDateTextColor: c(33),
    searchMessageDateTextStyle: t(34),
    emptyStateTextColor: c(35),
    emptyStateTextStyle: t(36),
    emptyStateSubTitleTextColor: c(37),
    emptyStateSubTitleTextStyle: t(38),
    errorStateTextColor: c(39),
    errorStateTextStyle: t(40),
    errorStateSubTitleTextColor: c(41),
    errorStateSubTitleTextStyle: t(42),
    seeMoreTextColor: c(43),
    seeMoreTextStyle: t(44),
    avatarStyle: CometChatAvatarStyle(backgroundColor: c(45)),
    statusIndicatorStyle: CometChatStatusIndicatorStyle(backgroundColor: c(46)),
    badgeStyle: CometChatBadgeStyle(backgroundColor: c(47)),
    receiptStyle: CometChatMessageReceiptStyle(waitIconColor: c(48)),
    dateStyle: CometChatDateStyle(backgroundColor: c(49)),
  );
}

CometChatSearchStyle _copyEverything(CometChatSearchStyle onto, int offset) {
  double d(int n) => (n + offset).toDouble();
  Color c(int n) => _c(n + offset);
  TextStyle t(int n) => TextStyle(fontSize: d(n));

  return onto.copyWith(
    backgroundColor: c(1),
    searchBackgroundColor: c(2),
    searchTextColor: c(3),
    searchTextStyle: t(4),
    searchPlaceHolderTextColor: c(5),
    searchPlaceHolderTextStyle: t(6),
    searchBorder: BorderSide(width: d(7)),
    searchBorderRadius: BorderRadius.circular(d(8)),
    searchBackIconColor: c(9),
    searchClearIconColor: c(10),
    searchFilterChipBackgroundColor: c(11),
    searchFilterChipSelectedBackgroundColor: c(12),
    searchFilterChipTextColor: c(13),
    searchFilterChipSelectedTextColor: c(14),
    searchFilterChipTextStyle: t(15),
    searchFilterChipSelectedTextStyle: t(16),
    searchFilterChipBorder: Border.all(width: d(17)),
    searchFilterChipSelectedBorder: Border.all(width: d(18)),
    searchFilterChipBorderRadius: BorderRadius.circular(d(19)),
    searchFilterIconColor: c(20),
    searchFilterSelectedIconColor: c(21),
    sectionHeaderTextColor: c(22),
    sectionHeaderTextStyle: t(23),
    searchConversationTitleTextColor: c(24),
    searchConversationTitleTextStyle: t(25),
    searchConversationSubtitleTextColor: c(26),
    searchConversationSubtitleTextStyle: t(27),
    searchConversationItemBackgroundColor: c(28),
    searchMessageSenderTextColor: c(29),
    searchMessageSenderTextStyle: t(30),
    searchMessagePreviewTextColor: c(31),
    searchMessagePreviewTextStyle: t(32),
    searchMessageDateTextColor: c(33),
    searchMessageDateTextStyle: t(34),
    emptyStateTextColor: c(35),
    emptyStateTextStyle: t(36),
    emptyStateSubTitleTextColor: c(37),
    emptyStateSubTitleTextStyle: t(38),
    errorStateTextColor: c(39),
    errorStateTextStyle: t(40),
    errorStateSubTitleTextColor: c(41),
    errorStateSubTitleTextStyle: t(42),
    seeMoreTextColor: c(43),
    seeMoreTextStyle: t(44),
    avatarStyle: CometChatAvatarStyle(backgroundColor: c(45)),
    statusIndicatorStyle: CometChatStatusIndicatorStyle(backgroundColor: c(46)),
    badgeStyle: CometChatBadgeStyle(backgroundColor: c(47)),
    receiptStyle: CometChatMessageReceiptStyle(waitIconColor: c(48)),
    dateStyle: CometChatDateStyle(backgroundColor: c(49)),
  );
}

void main() {
  final start = _style(0);
  final end = _style(100);

  test('the field table covers every field the style declares', () {
    expect(_rows.length, 49);
    expect(_rows.map((r) => r.$2).toSet().length, 49, reason: 'unique numbers');
    for (final (name, n, read) in _rows) {
      expect(read(start), n.toDouble(), reason: '$name is mis-numbered');
      expect(read(end), (n + 100).toDouble(), reason: '$name is mis-numbered');
    }
  });

  test('a default style holds nothing', () {
    const s = CometChatSearchStyle();
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
      final copy = start.copyWith(searchFilterChipTextColor: _c(113));
      for (final (name, n, read) in _rows) {
        expect(
          read(copy),
          n == 13 ? 113.0 : n.toDouble(),
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
      final merged = start.merge(const CometChatSearchStyle());
      for (final (name, n, read) in _rows) {
        expect(read(merged), n.toDouble(), reason: '$name was blanked');
      }
    });

    test('merge is per-field, not all-or-nothing', () {
      final merged = start.merge(
        CometChatSearchStyle(seeMoreTextColor: _c(200)),
      );
      expect(_rSeeMoreColor(merged), 200);
      expect(_rSeeMoreStyle(merged), 44);
      expect(_rBackground(merged), 1);
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

    test('the nested styles fall back to the other side when unset', () {
      // Unlike Users, Search's nested styles carry an `?? other.x` fallback,
      // so animating in from a theme that has no avatar/badge/date style still
      // ends on the target's nested styles rather than dropping them.
      final r = const CometChatSearchStyle().lerp(end, 1.0);
      expect(_rAvatarStyle(r), 145);
      expect(_rStatusIndicatorStyle(r), 146);
      expect(_rBadgeStyle(r), 147);
      expect(_rReceiptStyle(r), 148);
      expect(_rDateStyle(r), 149);
    });

    test(
      'searchBorder substitutes BorderSide.none when either side is unset',
      () {
        final r = const CometChatSearchStyle().lerp(end, 1.0);
        expect(r.searchBorder?.width, 107);
        // The chip borders need no fallback: BoxBorder.lerp scales the non-null
        // side from nothing, so they arrive at the target width too.
        expect(_rChipBorder(r), 117);
        expect(_rChipSelectedBorder(r), 118);
        // Halfway there they are half as thick, i.e. genuinely animated in.
        final half = const CometChatSearchStyle().lerp(end, 0.5);
        expect(_rChipBorder(half), 58.5);
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // of
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('of() ignores its context and returns the bare defaults', (
    tester,
  ) async {
    late CometChatSearchStyle resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: <ThemeExtension<dynamic>>[start]),
        home: Builder(
          builder: (context) {
            resolved = CometChatSearchStyle.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(resolved.backgroundColor, isNull);
    expect(
      Theme.of(
        tester.element(find.byType(SizedBox)),
      ).extension<CometChatSearchStyle>()?.backgroundColor,
      _c(1),
    );
  });
}
