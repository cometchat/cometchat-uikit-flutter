/// Data-class behaviour for [CometChatColorPalette] — `copyWith`, `lerp` and
/// `of`.
///
/// `theme_extension_props_test.dart` already proves every property supplied
/// through `ThemeData.extensions` reaches the widgets that paint with it.
/// What it cannot see is whether the palette's own transforms keep each
/// property in its own slot: `lerp` is 140 lines of hand-written per-field
/// wiring, and `copyWith` another 80. A single transposed line there recolours
/// the whole kit during a theme animation, and nothing else in the suite would
/// notice.
///
/// Method: every colour is encoded as a distinct value in one channel
/// (`_a(i)` / `_b(i)` differ by 100 in blue and nowhere else) and read back
/// through that channel. A field wired to its neighbour reads back the
/// neighbour's number and the row fails by name.
///
///   flutter test test/shared_ui/theme/color_palette_data_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Start colour for field [i]: only the blue channel carries the index.
Color _a(int i) => Color.fromARGB(0xFF, 0x10, 0x20, i);

/// End colour for field [i], 100 blue steps away from [_a].
Color _b(int i) => Color.fromARGB(0xFF, 0x10, 0x20, i + 100);

/// The blue channel back out of a colour, as an integer 0-255.
int? _blue(Color? c) => c == null ? null : c.toARGB32() & 0xFF;

/// One field of the palette: its name, its index, and how to read it.
typedef _Row = (String name, int index, Color? Function(CometChatColorPalette));

/// Every `Color` field the palette declares, in declaration order.
const List<_Row> _rows = [
  ('primary', 1, _getPrimary),
  ('extendedPrimary50', 2, _getEp50),
  ('extendedPrimary100', 3, _getEp100),
  ('extendedPrimary200', 4, _getEp200),
  ('extendedPrimary300', 5, _getEp300),
  ('extendedPrimary400', 6, _getEp400),
  ('extendedPrimary500', 7, _getEp500),
  ('extendedPrimary600', 8, _getEp600),
  ('extendedPrimary700', 9, _getEp700),
  ('extendedPrimary800', 10, _getEp800),
  ('extendedPrimary900', 11, _getEp900),
  ('neutral50', 12, _getN50),
  ('neutral100', 13, _getN100),
  ('neutral200', 14, _getN200),
  ('neutral300', 15, _getN300),
  ('neutral400', 16, _getN400),
  ('neutral500', 17, _getN500),
  ('neutral600', 18, _getN600),
  ('neutral700', 19, _getN700),
  ('neutral800', 20, _getN800),
  ('neutral900', 21, _getN900),
  ('info', 22, _getInfo),
  ('warning', 23, _getWarning),
  ('error', 24, _getError),
  ('success', 25, _getSuccess),
  ('error100', 26, _getError100),
  ('background1', 27, _getBg1),
  ('background2', 28, _getBg2),
  ('background3', 29, _getBg3),
  ('background4', 30, _getBg4),
  ('textPrimary', 31, _getTextPrimary),
  ('textSecondary', 32, _getTextSecondary),
  ('textTertiary', 33, _getTextTertiary),
  ('textDisabled', 34, _getTextDisabled),
  ('textWhite', 35, _getTextWhite),
  ('textHighlight', 36, _getTextHighlight),
  ('borderLight', 37, _getBorderLight),
  ('borderDefault', 38, _getBorderDefault),
  ('borderDark', 39, _getBorderDark),
  ('borderHighlight', 40, _getBorderHighlight),
  ('iconPrimary', 41, _getIconPrimary),
  ('iconSecondary', 42, _getIconSecondary),
  ('iconTertiary', 43, _getIconTertiary),
  ('iconWhite', 44, _getIconWhite),
  ('iconHighlight', 45, _getIconHighlight),
  ('shimmerBackground', 46, _getShimmerBackground),
  ('buttonBackground', 47, _getButtonBackground),
  ('secondaryButtonBackground', 48, _getSecondaryButtonBackground),
  ('buttonIconColor', 49, _getButtonIconColor),
  ('buttonText', 50, _getButtonText),
  ('secondaryButtonIcon', 51, _getSecondaryButtonIcon),
  ('secondaryButtonText', 52, _getSecondaryButtonText),
  ('white', 53, _getWhite),
  ('transparent', 54, _getTransparent),
  ('black', 55, _getBlack),
  ('messageSeen', 56, _getMessageSeen),
];

Color? _getPrimary(CometChatColorPalette p) => p.primary;
Color? _getEp50(CometChatColorPalette p) => p.extendedPrimary50;
Color? _getEp100(CometChatColorPalette p) => p.extendedPrimary100;
Color? _getEp200(CometChatColorPalette p) => p.extendedPrimary200;
Color? _getEp300(CometChatColorPalette p) => p.extendedPrimary300;
Color? _getEp400(CometChatColorPalette p) => p.extendedPrimary400;
Color? _getEp500(CometChatColorPalette p) => p.extendedPrimary500;
Color? _getEp600(CometChatColorPalette p) => p.extendedPrimary600;
Color? _getEp700(CometChatColorPalette p) => p.extendedPrimary700;
Color? _getEp800(CometChatColorPalette p) => p.extendedPrimary800;
Color? _getEp900(CometChatColorPalette p) => p.extendedPrimary900;
Color? _getN50(CometChatColorPalette p) => p.neutral50;
Color? _getN100(CometChatColorPalette p) => p.neutral100;
Color? _getN200(CometChatColorPalette p) => p.neutral200;
Color? _getN300(CometChatColorPalette p) => p.neutral300;
Color? _getN400(CometChatColorPalette p) => p.neutral400;
Color? _getN500(CometChatColorPalette p) => p.neutral500;
Color? _getN600(CometChatColorPalette p) => p.neutral600;
Color? _getN700(CometChatColorPalette p) => p.neutral700;
Color? _getN800(CometChatColorPalette p) => p.neutral800;
Color? _getN900(CometChatColorPalette p) => p.neutral900;
Color? _getInfo(CometChatColorPalette p) => p.info;
Color? _getWarning(CometChatColorPalette p) => p.warning;
Color? _getError(CometChatColorPalette p) => p.error;
Color? _getSuccess(CometChatColorPalette p) => p.success;
Color? _getError100(CometChatColorPalette p) => p.error100;
Color? _getBg1(CometChatColorPalette p) => p.background1;
Color? _getBg2(CometChatColorPalette p) => p.background2;
Color? _getBg3(CometChatColorPalette p) => p.background3;
Color? _getBg4(CometChatColorPalette p) => p.background4;
Color? _getTextPrimary(CometChatColorPalette p) => p.textPrimary;
Color? _getTextSecondary(CometChatColorPalette p) => p.textSecondary;
Color? _getTextTertiary(CometChatColorPalette p) => p.textTertiary;
Color? _getTextDisabled(CometChatColorPalette p) => p.textDisabled;
Color? _getTextWhite(CometChatColorPalette p) => p.textWhite;
Color? _getTextHighlight(CometChatColorPalette p) => p.textHighlight;
Color? _getBorderLight(CometChatColorPalette p) => p.borderLight;
Color? _getBorderDefault(CometChatColorPalette p) => p.borderDefault;
Color? _getBorderDark(CometChatColorPalette p) => p.borderDark;
Color? _getBorderHighlight(CometChatColorPalette p) => p.borderHighlight;
Color? _getIconPrimary(CometChatColorPalette p) => p.iconPrimary;
Color? _getIconSecondary(CometChatColorPalette p) => p.iconSecondary;
Color? _getIconTertiary(CometChatColorPalette p) => p.iconTertiary;
Color? _getIconWhite(CometChatColorPalette p) => p.iconWhite;
Color? _getIconHighlight(CometChatColorPalette p) => p.iconHighlight;
Color? _getShimmerBackground(CometChatColorPalette p) => p.shimmerBackground;
Color? _getButtonBackground(CometChatColorPalette p) => p.buttonBackground;
Color? _getSecondaryButtonBackground(CometChatColorPalette p) =>
    p.secondaryButtonBackground;
Color? _getButtonIconColor(CometChatColorPalette p) => p.buttonIconColor;
Color? _getButtonText(CometChatColorPalette p) => p.buttonText;
Color? _getSecondaryButtonIcon(CometChatColorPalette p) =>
    p.secondaryButtonIcon;
Color? _getSecondaryButtonText(CometChatColorPalette p) =>
    p.secondaryButtonText;
Color? _getWhite(CometChatColorPalette p) => p.white;
Color? _getTransparent(CometChatColorPalette p) => p.transparent;
Color? _getBlack(CometChatColorPalette p) => p.black;
Color? _getMessageSeen(CometChatColorPalette p) => p.messageSeen;

/// A palette whose every colour is [f] of that field's index.
CometChatColorPalette _palette(Color Function(int) f, {Gradient? shimmer}) =>
    CometChatColorPalette(
      primary: f(1),
      extendedPrimary50: f(2),
      extendedPrimary100: f(3),
      extendedPrimary200: f(4),
      extendedPrimary300: f(5),
      extendedPrimary400: f(6),
      extendedPrimary500: f(7),
      extendedPrimary600: f(8),
      extendedPrimary700: f(9),
      extendedPrimary800: f(10),
      extendedPrimary900: f(11),
      neutral50: f(12),
      neutral100: f(13),
      neutral200: f(14),
      neutral300: f(15),
      neutral400: f(16),
      neutral500: f(17),
      neutral600: f(18),
      neutral700: f(19),
      neutral800: f(20),
      neutral900: f(21),
      info: f(22),
      warning: f(23),
      error: f(24),
      success: f(25),
      error100: f(26),
      background1: f(27),
      background2: f(28),
      background3: f(29),
      background4: f(30),
      textPrimary: f(31),
      textSecondary: f(32),
      textTertiary: f(33),
      textDisabled: f(34),
      textWhite: f(35),
      textHighlight: f(36),
      borderLight: f(37),
      borderDefault: f(38),
      borderDark: f(39),
      borderHighlight: f(40),
      iconPrimary: f(41),
      iconSecondary: f(42),
      iconTertiary: f(43),
      iconWhite: f(44),
      iconHighlight: f(45),
      shimmerBackground: f(46),
      buttonBackground: f(47),
      secondaryButtonBackground: f(48),
      buttonIconColor: f(49),
      buttonText: f(50),
      secondaryButtonIcon: f(51),
      secondaryButtonText: f(52),
      white: f(53),
      transparent: f(54),
      black: f(55),
      messageSeen: f(56),
      shimmerGradient: shimmer,
    );

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // Constructor
  // ═══════════════════════════════════════════════════════════════════════════

  group('constructor', () {
    test('every field lands in its own slot', () {
      final p = _palette(_a);
      for (final (name, index, read) in _rows) {
        expect(_blue(read(p)), index, reason: name);
      }
    });

    test('white, transparent, black and messageSeen have defaults', () {
      final p = CometChatColorPalette();
      expect(p.white, Colors.white);
      expect(p.transparent, Colors.transparent);
      expect(p.black, Colors.black);
      expect(p.messageSeen, const Color(0XFF56E8A7));
      // Nothing semantic is defaulted — the theme helper supplies those.
      expect(p.primary, isNull);
      expect(p.background1, isNull);
      expect(p.textPrimary, isNull);
      expect(p.shimmerGradient, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // lerp — the 140-line hand-wired method
  // ═══════════════════════════════════════════════════════════════════════════

  group('lerp', () {
    final start = _palette(_a);
    final end = _palette(_b);

    test('t = 0 reproduces the start palette, field for field', () {
      final r = start.lerp(end, 0.0);
      for (final (name, index, read) in _rows) {
        expect(_blue(read(r)), index, reason: '$name at t=0');
      }
    });

    test('t = 1 reproduces the end palette, field for field', () {
      final r = start.lerp(end, 1.0);
      for (final (name, index, read) in _rows) {
        expect(_blue(read(r)), index + 100, reason: '$name at t=1');
      }
    });

    test('t = 0.5 lands halfway on every field', () {
      final r = start.lerp(end, 0.5);
      for (final (name, index, read) in _rows) {
        expect(_blue(read(r)), index + 50, reason: '$name at t=0.5');
      }
    });

    test('the shimmer gradient is interpolated too', () {
      final withGradient = _palette(
        _a,
        shimmer: const LinearGradient(colors: [Color(0xFF000000), _a2]),
      );
      final other = _palette(
        _b,
        shimmer: const LinearGradient(colors: [Color(0xFF000000), _b2]),
      );

      final mid = withGradient.lerp(other, 0.5).shimmerGradient;

      expect(mid, isA<LinearGradient>());
      expect(_blue((mid! as LinearGradient).colors.last), 51);
    });

    test('a non-palette extension leaves the palette untouched', () {
      final p = _palette(_a);
      // The `other is! CometChatColorPalette` guard: a theme carrying a
      // different extension type must not blank the palette out.
      expect(identical(p.lerp(null, 0.5), p), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // copyWith
  // ═══════════════════════════════════════════════════════════════════════════

  group('copyWith', () {
    test('with no arguments preserves every field', () {
      final p = _palette(_a);
      final copy = p.copyWith();
      for (final (name, index, read) in _rows) {
        expect(_blue(read(copy)), index, reason: name);
      }
    });

    test('a named colour replaces only its own slot', () {
      // Checked on fields outside the extendedPrimary block, which is wired
      // differently — see the FINDING below.
      final p = _palette(_a);
      final copy = p.copyWith(
        textPrimary: _b(31),
        borderDark: _b(39),
        iconWhite: _b(44),
      );
      for (final (name, index, read) in _rows) {
        final expected = const {31, 39, 44}.contains(index)
            ? index + 100
            : index;
        expect(_blue(read(copy)), expected, reason: name);
      }
    });

    test('alertColor is the parameter that sets messageSeen', () {
      // copyWith exposes no `messageSeen` parameter; `alertColor` writes that
      // field instead. Surprising, but it is the only way to change it and
      // callers rely on it.
      final p = _palette(_a);
      expect(_blue(p.copyWith(alertColor: _b(56)).messageSeen), 156);
    });

    // FINDING: the extendedPrimary block of `copyWith` is shifted by one slot.
    // Every shade from 200 up is fed the *previous* shade's parameter:
    //
    //   extendedPrimary200: extendedPrimary100 ?? this.extendedPrimary200,
    //   extendedPrimary300: extendedPrimary200 ?? this.extendedPrimary300,
    //   ...
    //   extendedPrimary900: extendedPrimary800 ?? this.extendedPrimary900,
    //
    // So only `extendedPrimary50` and `extendedPrimary100` do what their name
    // says. `extendedPrimary100` writes 100 *and* 200; `extendedPrimary200`
    // through `extendedPrimary800` each write the shade one step below the one
    // named, leaving the named one untouched; and `extendedPrimary900` is read
    // by nothing at all, so that shade cannot be changed through copyWith.
    // Current behaviour is pinned here rather than fixed; lib/ is untouched.
    group('FINDING: the extendedPrimary parameters are shifted by one', () {
      test('setting extendedPrimary100 also overwrites extendedPrimary200', () {
        final copy = _palette(_a).copyWith(extendedPrimary100: _b(3));
        expect(_blue(copy.extendedPrimary100), 103);
        // Should still be 4 — the shade the caller never mentioned.
        expect(_blue(copy.extendedPrimary200), 103);
      });

      test('setting extendedPrimary800 changes extendedPrimary900 instead', () {
        final copy = _palette(_a).copyWith(extendedPrimary800: _b(10));
        // The shade the caller asked for is unchanged …
        expect(_blue(copy.extendedPrimary800), 10);
        // … and the one below it took the new colour.
        expect(_blue(copy.extendedPrimary900), 110);
      });

      test('extendedPrimary900 cannot be set through copyWith', () {
        final copy = _palette(_a).copyWith(extendedPrimary900: _b(11));
        // The argument is dropped on the floor: the original survives.
        expect(_blue(copy.extendedPrimary900), 11);
      });

      test('extendedPrimary50 and 100 are the only unshifted shades', () {
        final copy = _palette(
          _a,
        ).copyWith(extendedPrimary50: _b(2), extendedPrimary300: _b(5));
        expect(_blue(copy.extendedPrimary50), 102);
        expect(_blue(copy.extendedPrimary100), 3);
        // extendedPrimary300's argument lands on 400 instead of 300.
        expect(_blue(copy.extendedPrimary300), 5);
        expect(_blue(copy.extendedPrimary400), 105);
      });
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // of
  // ═══════════════════════════════════════════════════════════════════════════

  test('of() ignores its context and returns the bare defaults', () {
    // `of` predates CometChatThemeHelper and does not read the theme; every
    // call site that needs the themed palette must go through the helper.
    final p = CometChatColorPalette.of(null);
    expect(p.primary, isNull);
    expect(p.white, Colors.white);
    expect(p.messageSeen, const Color(0XFF56E8A7));
  });
}

const Color _a2 = Color.fromARGB(0xFF, 0x10, 0x20, 1);
const Color _b2 = Color.fromARGB(0xFF, 0x10, 0x20, 101);
