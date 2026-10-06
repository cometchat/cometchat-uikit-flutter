/// Render-verified prop matrix for [SearchFilterChip] — Track 3 PROP1,
/// coverage part 2 (ENG-38688).
///
/// The chip is a leaf widget, so every prop is read back from what it paints:
/// the Container's decoration and padding, the label Text, the leading Icon,
/// the gap between them, and the Semantics node around the whole chip. Each
/// row of [_cases] names the prop it covers, the configuration it pumps, and a
/// probe that reads the painted value that prop controls.
///
/// Every sentinel is a value no theme uses, so a probe can only see one if the
/// chip honoured that prop. The optional colours, borders and text styles are
/// switched off (`overrides: false`) for the colorPalette, spacing and
/// typography rows, because a fallback reaches the screen only when the
/// override in front of it is null; every other row switches them on, which
/// also shows each override winning over its fallback.
///
///   flutter test test/chat_ui/search/widget/search_filter_chip_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Sentinels ───────────────────────────────────────────────────────────────

const _label = 'Qx-label';
const _icon = Icons.pets;

// Palette fallbacks: painted only when the matching override is null.
const _paletteSelectedBg = Color(0xFF1A2B3C);
const _paletteUnselectedBg = Color(0xFF2B3C4D);
const _paletteSelectedText = Color(0xFF3C4D5E);
const _paletteUnselectedText = Color(0xFF4D5E6F);
const _paletteSelectedIcon = Color(0xFF5E6F70);
const _paletteUnselectedIcon = Color(0xFF6F7081);
const _paletteSelectedBorder = Color(0xFF708192);
const _paletteUnselectedBorder = Color(0xFF8192A3);

final _palette = CometChatColorPalette(
  secondaryButtonBackground: _paletteSelectedBg,
  background3: _paletteUnselectedBg,
  textWhite: _paletteSelectedText,
  textSecondary: _paletteUnselectedText,
  iconWhite: _paletteSelectedIcon,
  iconSecondary: _paletteUnselectedIcon,
  neutral800: _paletteSelectedBorder,
  borderLight: _paletteUnselectedBorder,
);

final _spacing = CometChatSpacing(
  padding1: 5.5,
  padding3: 13.5,
  radiusMax: 17.5,
);

const _typography = CometChatTypography(
  body: CometChatTextStyleBody(
    medium: TextStyle(
      fontSize: 15.25,
      fontWeight: FontWeight.w300,
      fontFamily: 'QxSans',
    ),
  ),
);

// Explicit overrides.
const _selectedBg = Color(0xFF9A0B1C);
const _unselectedBg = Color(0xFFAB1C2D);
const _selectedIcon = Color(0xFFBC2D3E);
const _unselectedIcon = Color(0xFFCD3E4F);
const _selectedText = Color(0xFFDE4F50);
const _unselectedText = Color(0xFFEF5061);
const _selectedBorder = Border.fromBorderSide(
  BorderSide(color: Color(0xFF10A1B2), width: 2.5),
);
const _unselectedBorder = Border.fromBorderSide(
  BorderSide(color: Color(0xFF21B2C3), width: 3.5),
);
const _radius = BorderRadius.all(Radius.circular(6.5));
const _selectedTextStyle = TextStyle(fontSize: 19.25);
const _textStyle = TextStyle(fontSize: 21.75);

// ─── Probes ──────────────────────────────────────────────────────────────────

final _chip = find.byType(SearchFilterChip);

Finder _inChip(Type type) =>
    find.descendant(of: _chip, matching: find.byType(type));

BoxDecoration _decoration(WidgetTester tester) =>
    tester.widget<Container>(_inChip(Container)).decoration! as BoxDecoration;

TextStyle _labelStyle(WidgetTester tester) =>
    tester.widget<Text>(_inChip(Text)).style!;

Color? _iconColor(WidgetTester tester) =>
    tester.widget<Icon>(_inChip(Icon)).color;

/// The label on the chip's own button node, not the one Icon adds for itself.
String? _announced(WidgetTester tester) => tester
    .widget<Semantics>(
      find.descendant(
        of: _chip,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.button ?? false),
        ),
      ),
    )
    .properties
    .label;

/// Laid-out distance from the glyph's right edge to the label's left edge.
double _glyphGap(WidgetTester tester) =>
    tester.getTopLeft(_inChip(Text)).dx - tester.getTopRight(_inChip(Icon)).dx;

class _TapLog {
  int taps = 0;
  void record() => taps++;
}

Future<void> _tapChip(WidgetTester tester) async {
  await tester.tap(_chip);
  await tester.pump();
}

// ─── Matrix ──────────────────────────────────────────────────────────────────

class _ChipCase {
  const _ChipCase(
    this.prop,
    this.behaviour, {
    required this.probe,
    required this.expected,
    this.selected = false,
    this.overrides = true,
    this.withIcon = true,
    this.act,
  });

  /// The SearchFilterChip prop this row covers.
  final String prop;

  /// What the prop does, as the test name reads.
  final String behaviour;

  final bool selected;

  /// False leaves every optional colour, border and text style null, so the
  /// colorPalette, spacing and typography fallbacks are what paints.
  final bool overrides;

  final bool withIcon;

  /// Interaction to perform after the pump, before probing.
  final Future<void> Function(WidgetTester tester)? act;

  /// Reads back the rendered value the prop controls.
  final Object? Function(WidgetTester tester, _TapLog log) probe;

  final Object? expected;
}

final _cases = <_ChipCase>[
  // ── label ──
  _ChipCase(
    'label',
    'is the text the chip shows',
    probe: (t, _) => t.widget<Text>(_inChip(Text)).data,
    expected: _label,
  ),
  _ChipCase(
    'label',
    'names the button for assistive technology',
    probe: (t, _) => _announced(t),
    expected: '$_label filter',
  ),

  // ── icon ──
  _ChipCase(
    'icon',
    'is the glyph drawn before the label',
    probe: (t, _) => t.widget<Icon>(_inChip(Icon)).icon,
    expected: _icon,
  ),
  _ChipCase(
    'icon',
    'left null draws no glyph at all',
    withIcon: false,
    probe: (t, _) => _inChip(Icon).evaluate().length,
    expected: 0,
  ),

  // ── isSelected: both states, and they differ ──
  _ChipCase(
    'isSelected',
    'false paints the unselected treatment and announces no selection',
    probe: (t, _) => [
      _announced(t),
      _decoration(t).color,
      _decoration(t).border,
    ],
    expected: ['$_label filter', _unselectedBg, _unselectedBorder],
  ),
  _ChipCase(
    'isSelected',
    'true paints the selected treatment and announces it',
    selected: true,
    probe: (t, _) => [
      _announced(t),
      _decoration(t).color,
      _decoration(t).border,
    ],
    expected: ['$_label filter, selected', _selectedBg, _selectedBorder],
  ),

  // ── onTap ──
  _ChipCase(
    'onTap',
    'does not fire on build',
    probe: (_, log) => log.taps,
    expected: 0,
  ),
  _ChipCase(
    'onTap',
    'fires once for one real tap',
    act: _tapChip,
    probe: (_, log) => log.taps,
    expected: 1,
  ),

  // ── colorPalette: the fallback behind every optional colour ──
  _ChipCase(
    'colorPalette',
    'secondaryButtonBackground fills a selected chip',
    selected: true,
    overrides: false,
    probe: (t, _) => _decoration(t).color,
    expected: _paletteSelectedBg,
  ),
  _ChipCase(
    'colorPalette',
    'background3 fills an unselected chip',
    overrides: false,
    probe: (t, _) => _decoration(t).color,
    expected: _paletteUnselectedBg,
  ),
  _ChipCase(
    'colorPalette',
    'textWhite colours a selected label',
    selected: true,
    overrides: false,
    probe: (t, _) => _labelStyle(t).color,
    expected: _paletteSelectedText,
  ),
  _ChipCase(
    'colorPalette',
    'textSecondary colours an unselected label',
    overrides: false,
    probe: (t, _) => _labelStyle(t).color,
    expected: _paletteUnselectedText,
  ),
  _ChipCase(
    'colorPalette',
    'iconWhite tints a selected glyph',
    selected: true,
    overrides: false,
    probe: (t, _) => _iconColor(t),
    expected: _paletteSelectedIcon,
  ),
  _ChipCase(
    'colorPalette',
    'iconSecondary tints an unselected glyph',
    overrides: false,
    probe: (t, _) => _iconColor(t),
    expected: _paletteUnselectedIcon,
  ),
  _ChipCase(
    'colorPalette',
    'neutral800 outlines a selected chip',
    selected: true,
    overrides: false,
    probe: (t, _) => _decoration(t).border,
    expected: Border.all(color: _paletteSelectedBorder),
  ),
  _ChipCase(
    'colorPalette',
    'borderLight outlines an unselected chip',
    overrides: false,
    probe: (t, _) => _decoration(t).border,
    expected: Border.all(color: _paletteUnselectedBorder),
  ),

  // ── spacing ──
  _ChipCase(
    'spacing',
    'padding3 and padding1 pad the chip',
    probe: (t, _) => t.widget<Container>(_inChip(Container)).padding,
    expected: const EdgeInsets.symmetric(horizontal: 13.5, vertical: 5.5),
  ),
  _ChipCase(
    'spacing',
    'padding1 separates the glyph from the label',
    probe: (t, _) => _glyphGap(t),
    expected: moreOrLessEquals(5.5),
  ),
  _ChipCase(
    'spacing',
    'radiusMax rounds the chip when no borderRadius is given',
    overrides: false,
    probe: (t, _) => _decoration(t).borderRadius,
    expected: const BorderRadius.all(Radius.circular(17.5)),
  ),

  // ── typography ──
  _ChipCase(
    'typography',
    'body.medium sets the label size, weight and family',
    overrides: false,
    probe: (t, _) {
      final style = _labelStyle(t);
      return [style.fontSize, style.fontWeight, style.fontFamily];
    },
    expected: [15.25, FontWeight.w300, 'QxSans'],
  ),

  // ── explicit overrides ──
  _ChipCase(
    'selectedColor',
    'fills a selected chip over the palette',
    selected: true,
    probe: (t, _) => _decoration(t).color,
    expected: _selectedBg,
  ),
  _ChipCase(
    'unselectedColor',
    'fills an unselected chip over the palette',
    probe: (t, _) => _decoration(t).color,
    expected: _unselectedBg,
  ),
  _ChipCase(
    'selectedIconColor',
    'tints the glyph of a selected chip',
    selected: true,
    probe: (t, _) => _iconColor(t),
    expected: _selectedIcon,
  ),
  _ChipCase(
    'unselectedIconColor',
    'tints the glyph of an unselected chip',
    probe: (t, _) => _iconColor(t),
    expected: _unselectedIcon,
  ),
  _ChipCase(
    'selectedTextColor',
    'colours the label of a selected chip',
    selected: true,
    probe: (t, _) => _labelStyle(t).color,
    expected: _selectedText,
  ),
  _ChipCase(
    'unselectedTextColor',
    'colours the label of an unselected chip',
    probe: (t, _) => _labelStyle(t).color,
    expected: _unselectedText,
  ),
  _ChipCase(
    'selectedBorder',
    'outlines a selected chip',
    selected: true,
    probe: (t, _) => _decoration(t).border,
    expected: _selectedBorder,
  ),
  _ChipCase(
    'unSelectedBorder',
    'outlines an unselected chip',
    probe: (t, _) => _decoration(t).border,
    expected: _unselectedBorder,
  ),
  _ChipCase(
    'borderRadius',
    'rounds the chip in place of spacing.radiusMax',
    probe: (t, _) => _decoration(t).borderRadius,
    expected: _radius,
  ),
  _ChipCase(
    'selectedTextStyle',
    'merges into the label while selected',
    selected: true,
    probe: (t, _) => _labelStyle(t).fontSize,
    expected: 19.25,
  ),
  _ChipCase(
    'textStyle',
    'merges into the label while unselected',
    probe: (t, _) => _labelStyle(t).fontSize,
    expected: 21.75,
  ),
];

void main() {
  group('SearchFilterChip prop matrix', () {
    for (final c in _cases) {
      testWidgets('${c.prop} ${c.behaviour}', (tester) async {
        final log = _TapLog();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SearchFilterChip(
                  label: _label,
                  icon: c.withIcon ? _icon : null,
                  isSelected: c.selected,
                  onTap: log.record,
                  colorPalette: _palette,
                  spacing: _spacing,
                  typography: _typography,
                  selectedColor: c.overrides ? _selectedBg : null,
                  unselectedColor: c.overrides ? _unselectedBg : null,
                  selectedIconColor: c.overrides ? _selectedIcon : null,
                  unselectedIconColor: c.overrides ? _unselectedIcon : null,
                  selectedTextColor: c.overrides ? _selectedText : null,
                  unselectedTextColor: c.overrides ? _unselectedText : null,
                  selectedBorder: c.overrides ? _selectedBorder : null,
                  unSelectedBorder: c.overrides ? _unselectedBorder : null,
                  borderRadius: c.overrides ? _radius : null,
                  selectedTextStyle: c.overrides ? _selectedTextStyle : null,
                  textStyle: c.overrides ? _textStyle : null,
                ),
              ),
            ),
          ),
        );
        await c.act?.call(tester);

        expect(c.probe(tester, log), c.expected, reason: c.prop);
      });
    }
  });
}
