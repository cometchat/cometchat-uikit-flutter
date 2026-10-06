/// The typography role tokens — `CometChatTextStyleBody`, the headings, the
/// captions, and the button, link and title roles.
///
/// Each is the same shape: up to three weight slots (`bold`, `medium`,
/// `regular`), a `copyWith`, a `lerp`, a `merge` built on `TextStyle.merge`,
/// and a static `of(context)` that resolves the role's default type and then
/// lets a `ThemeData.extensions` entry override it. The behaviour worth
/// pinning is in `of` (the per-role default size and weight, and the override
/// direction) and in `merge`, whose `TextStyle`-level semantics differ from
/// every other UIKit style class and have a sharp edge when the receiver's
/// slot is null.
///
///   flutter test test/shared_ui/style_contracts/typography_text_style_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One typography role, type-erased so all ten fit in a single table. The
/// slot exercised is the role's first one: `bold` everywhere except `link`,
/// which only has `regular`.
class _Role {
  const _Role(
    this.name,
    this.empty,
    this.withSlot,
    this.copySlot,
    this.readSlot,
    this.merge,
    this.lerp,
    this.of,
    this.themeWith, {
    required this.size,
    required this.weight,
    this.lerpThrowsOnNullSlot = true,
  });

  final String name;
  final Object Function() empty;
  final Object Function(TextStyle slot) withSlot;
  final Object Function(Object style, TextStyle slot) copySlot;
  final TextStyle? Function(Object style) readSlot;
  final Object Function(Object style, Object? other) merge;
  final Object Function(Object style, Object? other, double t) lerp;
  final Object Function(BuildContext context) of;

  /// Builds a `ThemeData` carrying this role's extension with [slot] set —
  /// the concrete type is needed because `ThemeExtension`'s type parameter is
  /// F-bounded, so a type-erased instance cannot be put in the list.
  final ThemeData Function(TextStyle slot) themeWith;

  /// The font size `of` resolves for this role with no extension supplied.
  final double size;

  /// The weight of the slot under test.
  final FontWeight weight;

  /// Whether `lerp` throws when a slot is null on both sides — see the
  /// FINDING test below. Only the body role is written without `!`.
  final bool lerpThrowsOnNullSlot;
}

final _roles = <_Role>[
  _Role(
    'CometChatTextStyleBody',
    () => const CometChatTextStyleBody(),
    (t) => CometChatTextStyleBody(bold: t, medium: t, regular: t),
    (s, t) => (s as CometChatTextStyleBody).copyWith(bold: t),
    (s) => (s as CometChatTextStyleBody).bold,
    (s, o) => (s as CometChatTextStyleBody).merge(o as CometChatTextStyleBody?),
    (s, o, t) =>
        (s as CometChatTextStyleBody).lerp(o as CometChatTextStyleBody?, t),
    CometChatTextStyleBody.of,
    (t) => ThemeData(extensions: [CometChatTextStyleBody(bold: t)]),
    size: 14,
    weight: FontWeight.w700,
    lerpThrowsOnNullSlot: false,
  ),
  _Role(
    'CometChatTextStyleHeading1',
    () => const CometChatTextStyleHeading1(),
    (t) => CometChatTextStyleHeading1(bold: t, medium: t, regular: t),
    (s, t) => (s as CometChatTextStyleHeading1).copyWith(bold: t),
    (s) => (s as CometChatTextStyleHeading1).bold,
    (s, o) => (s as CometChatTextStyleHeading1).merge(
      o as CometChatTextStyleHeading1?,
    ),
    (s, o, t) => (s as CometChatTextStyleHeading1).lerp(
      o as CometChatTextStyleHeading1?,
      t,
    ),
    CometChatTextStyleHeading1.of,
    (t) => ThemeData(extensions: [CometChatTextStyleHeading1(bold: t)]),
    size: 24,
    weight: FontWeight.w700,
  ),
  _Role(
    'CometChatTextStyleHeading2',
    () => const CometChatTextStyleHeading2(),
    (t) => CometChatTextStyleHeading2(bold: t, medium: t, regular: t),
    (s, t) => (s as CometChatTextStyleHeading2).copyWith(bold: t),
    (s) => (s as CometChatTextStyleHeading2).bold,
    (s, o) => (s as CometChatTextStyleHeading2).merge(
      o as CometChatTextStyleHeading2?,
    ),
    (s, o, t) => (s as CometChatTextStyleHeading2).lerp(
      o as CometChatTextStyleHeading2?,
      t,
    ),
    CometChatTextStyleHeading2.of,
    (t) => ThemeData(extensions: [CometChatTextStyleHeading2(bold: t)]),
    size: 20,
    weight: FontWeight.w700,
  ),
  _Role(
    'CometChatTextStyleHeading3',
    () => const CometChatTextStyleHeading3(),
    (t) => CometChatTextStyleHeading3(bold: t, medium: t, regular: t),
    (s, t) => (s as CometChatTextStyleHeading3).copyWith(bold: t),
    (s) => (s as CometChatTextStyleHeading3).bold,
    (s, o) => (s as CometChatTextStyleHeading3).merge(
      o as CometChatTextStyleHeading3?,
    ),
    (s, o, t) => (s as CometChatTextStyleHeading3).lerp(
      o as CometChatTextStyleHeading3?,
      t,
    ),
    CometChatTextStyleHeading3.of,
    (t) => ThemeData(extensions: [CometChatTextStyleHeading3(bold: t)]),
    size: 18,
    weight: FontWeight.w700,
  ),
  _Role(
    'CometChatTextStyleHeading4',
    () => const CometChatTextStyleHeading4(),
    (t) => CometChatTextStyleHeading4(bold: t, medium: t, regular: t),
    (s, t) => (s as CometChatTextStyleHeading4).copyWith(bold: t),
    (s) => (s as CometChatTextStyleHeading4).bold,
    (s, o) => (s as CometChatTextStyleHeading4).merge(
      o as CometChatTextStyleHeading4?,
    ),
    (s, o, t) => (s as CometChatTextStyleHeading4).lerp(
      o as CometChatTextStyleHeading4?,
      t,
    ),
    CometChatTextStyleHeading4.of,
    (t) => ThemeData(extensions: [CometChatTextStyleHeading4(bold: t)]),
    size: 16,
    weight: FontWeight.w700,
  ),
  _Role(
    'CometChatTextStyleCaption1',
    () => const CometChatTextStyleCaption1(),
    (t) => CometChatTextStyleCaption1(bold: t, medium: t, regular: t),
    (s, t) => (s as CometChatTextStyleCaption1).copyWith(bold: t),
    (s) => (s as CometChatTextStyleCaption1).bold,
    (s, o) => (s as CometChatTextStyleCaption1).merge(
      o as CometChatTextStyleCaption1?,
    ),
    (s, o, t) => (s as CometChatTextStyleCaption1).lerp(
      o as CometChatTextStyleCaption1?,
      t,
    ),
    CometChatTextStyleCaption1.of,
    (t) => ThemeData(extensions: [CometChatTextStyleCaption1(bold: t)]),
    size: 12,
    weight: FontWeight.w700,
  ),
  _Role(
    'CometChatTextStyleCaption2',
    () => const CometChatTextStyleCaption2(),
    (t) => CometChatTextStyleCaption2(bold: t, medium: t, regular: t),
    (s, t) => (s as CometChatTextStyleCaption2).copyWith(bold: t),
    (s) => (s as CometChatTextStyleCaption2).bold,
    (s, o) => (s as CometChatTextStyleCaption2).merge(
      o as CometChatTextStyleCaption2?,
    ),
    (s, o, t) => (s as CometChatTextStyleCaption2).lerp(
      o as CometChatTextStyleCaption2?,
      t,
    ),
    CometChatTextStyleCaption2.of,
    (t) => ThemeData(extensions: [CometChatTextStyleCaption2(bold: t)]),
    size: 10,
    weight: FontWeight.w700,
  ),
  _Role(
    'CometChatTextStyleButton',
    () => const CometChatTextStyleButton(),
    (t) => CometChatTextStyleButton(bold: t, medium: t, regular: t),
    (s, t) => (s as CometChatTextStyleButton).copyWith(bold: t),
    (s) => (s as CometChatTextStyleButton).bold,
    (s, o) =>
        (s as CometChatTextStyleButton).merge(o as CometChatTextStyleButton?),
    (s, o, t) =>
        (s as CometChatTextStyleButton).lerp(o as CometChatTextStyleButton?, t),
    CometChatTextStyleButton.of,
    (t) => ThemeData(extensions: [CometChatTextStyleButton(bold: t)]),
    size: 14,
    weight: FontWeight.w700,
  ),
  _Role(
    'CometChatTextStyleTitle',
    () => const CometChatTextStyleTitle(),
    (t) => CometChatTextStyleTitle(bold: t, medium: t, regular: t),
    (s, t) => (s as CometChatTextStyleTitle).copyWith(bold: t),
    (s) => (s as CometChatTextStyleTitle).bold,
    (s, o) =>
        (s as CometChatTextStyleTitle).merge(o as CometChatTextStyleTitle?),
    (s, o, t) =>
        (s as CometChatTextStyleTitle).lerp(o as CometChatTextStyleTitle?, t),
    CometChatTextStyleTitle.of,
    (t) => ThemeData(extensions: [CometChatTextStyleTitle(bold: t)]),
    size: 32,
    weight: FontWeight.w700,
  ),
  _Role(
    'CometChatTextStyleLink',
    () => const CometChatTextStyleLink(),
    (t) => CometChatTextStyleLink(regular: t),
    (s, t) => (s as CometChatTextStyleLink).copyWith(regular: t),
    (s) => (s as CometChatTextStyleLink).regular,
    (s, o) => (s as CometChatTextStyleLink).merge(o as CometChatTextStyleLink?),
    (s, o, t) =>
        (s as CometChatTextStyleLink).lerp(o as CometChatTextStyleLink?, t),
    CometChatTextStyleLink.of,
    (t) => ThemeData(extensions: [CometChatTextStyleLink(regular: t)]),
    size: 14,
    weight: FontWeight.w400,
  ),
];

/// Reads a role token out of a real `Theme`, so `of` goes through the same
/// lookup an integrator's widget does.
Future<Object> _resolve(
  WidgetTester tester,
  _Role role,
  ThemeData theme,
) async {
  late Object resolved;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) {
          resolved = role.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return resolved;
}

void main() {
  group('CometChatTypography', () {
    testWidgets('of() collects every role at its own default type', (
      tester,
    ) async {
      late CometChatTypography typography;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              typography = CometChatTypography.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // One assertion per slot, so a role wired into the wrong slot fails.
      expect(typography.heading1?.bold?.fontSize, 24);
      expect(typography.heading2?.bold?.fontSize, 20);
      expect(typography.heading3?.bold?.fontSize, 18);
      expect(typography.heading4?.bold?.fontSize, 16);
      expect(typography.body?.bold?.fontSize, 14);
      expect(typography.caption1?.bold?.fontSize, 12);
      expect(typography.caption2?.bold?.fontSize, 10);
      expect(typography.button?.bold?.fontSize, 14);
      expect(typography.title?.bold?.fontSize, 32);
      expect(typography.link?.regular?.fontSize, 14);
      expect(typography.link?.regular?.fontWeight, FontWeight.w400);
      // The medium/regular weights come from the same role default.
      expect(typography.body?.medium?.fontWeight, FontWeight.w500);
      expect(typography.body?.regular?.fontWeight, FontWeight.w400);
    });

    test('copyWith and merge give the argument precedence per role', () {
      const supplied = CometChatTypography(
        body: CometChatTextStyleBody(bold: TextStyle(fontSize: 31)),
      );
      const base = CometChatTypography(
        title: CometChatTextStyleTitle(bold: TextStyle(fontSize: 41)),
      );

      final merged = base.merge(supplied);
      expect(merged.body?.bold?.fontSize, 31);
      expect(merged.title?.bold?.fontSize, 41); // untouched role survives
      expect(identical(base.merge(null), base), isTrue);
      expect(base.copyWith().title?.bold?.fontSize, 41);
    });

    test('FINDING lerp throws when a role token leaves a slot unset', () {
      // FINDING: `CometChatTypography.lerp` forwards into each role's lerp,
      // and all of them but `body` assert non-null on `TextStyle.lerp`. So
      // lerping two typographies that carry a default-constructed role — what
      // `CometChatTypography()` with any role set gives you — throws.
      expect(
        () => const CometChatTypography(heading1: CometChatTextStyleHeading1())
            .lerp(
              const CometChatTypography(heading1: CometChatTextStyleHeading1()),
              0.5,
            ),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('typography role tokens', () {
    for (final role in _roles) {
      test('${role.name}: copyWith and lerp carry the slot', () {
        const one = TextStyle(fontSize: 30, color: Color(0xFF112233));
        const two = TextStyle(fontSize: 40, color: Color(0xFF445566));

        expect(role.readSlot(role.copySlot(role.withSlot(one), two)), two);
        // A copyWith that passes nothing for the slot keeps the old value.
        expect(role.readSlot(role.copySlot(role.empty(), one)), one);

        final a = role.withSlot(one);
        final b = role.withSlot(two);
        expect(role.readSlot(role.lerp(a, b, 0.0)), one);
        expect(role.readSlot(role.lerp(a, b, 1.0)), two);
        expect(role.readSlot(role.lerp(a, b, 0.5))?.fontSize, 35);
        // A non-matching `other` leaves the receiver alone.
        expect(identical(role.lerp(a, null, 0.5), a), isTrue);
      });

      test('${role.name}: merge layers the argument over the receiver', () {
        const base = TextStyle(fontSize: 30, color: Color(0xFF112233));
        const over = TextStyle(color: Color(0xFF445566));
        final merged = role.merge(role.withSlot(base), role.withSlot(over));

        // TextStyle-level merge: the argument's colour wins, and the
        // receiver's size survives because the argument does not set one.
        expect(role.readSlot(merged)?.color, const Color(0xFF445566));
        expect(role.readSlot(merged)?.fontSize, 30);

        final receiver = role.withSlot(base);
        expect(identical(role.merge(receiver, null), receiver), isTrue);
      });

      test(
        '${role.name}: FINDING merge onto an empty token drops the argument',
        () {
          // FINDING: merge is written as `slot?.merge(other.slot)`, so when
          // the *receiver's* slot is null the argument is discarded instead of
          // adopted — `CometChatTextStyleBody().merge(mine)` returns an empty
          // token and the caller's type vanishes. Every other UIKit style
          // class gives the argument precedence over a null receiver field.
          // Pinned, not fixed.
          const mine = TextStyle(fontSize: 30, color: Color(0xFF112233));
          final ontoEmpty = role.merge(role.empty(), role.withSlot(mine));
          expect(role.readSlot(ontoEmpty), isNull);
        },
      );

      test('${role.name}: lerp across a null slot', () {
        // FINDING: every role but `body` writes its lerp as
        // `TextStyle.lerp(slot, other.slot, t)!`, and `TextStyle.lerp` returns
        // null when both sides are null. So lerping two tokens that leave a
        // weight unset — the default-constructed token included — throws a
        // TypeError. `ThemeData.lerp` calls this on every theme animation, and
        // `CometChatTypography.lerp` forwards into it. Pinned, not fixed.
        final empty = role.empty();
        if (role.lerpThrowsOnNullSlot) {
          expect(
            () => role.lerp(empty, role.empty(), 0.5),
            throwsA(isA<TypeError>()),
          );
        } else {
          expect(role.readSlot(role.lerp(empty, role.empty(), 0.5)), isNull);
        }
      });

      testWidgets('${role.name}: of() resolves the role default', (
        tester,
      ) async {
        final resolved = await _resolve(tester, role, ThemeData());
        final slot = role.readSlot(resolved);
        expect(slot?.fontSize, role.size);
        expect(slot?.fontWeight, role.weight);
      });

      testWidgets('${role.name}: of() lets a theme extension override it', (
        tester,
      ) async {
        final resolved = await _resolve(
          tester,
          role,
          role.themeWith(
            const TextStyle(color: Color(0xFFAB12CD), letterSpacing: 3),
          ),
        );
        final slot = role.readSlot(resolved);
        // The supplied properties win …
        expect(slot?.color, const Color(0xFFAB12CD));
        expect(slot?.letterSpacing, 3);
        // … and the role's own size and weight survive underneath, because
        // the resolution is `default.merge(supplied)`.
        expect(slot?.fontSize, role.size);
        expect(slot?.fontWeight, role.weight);
      });
    }
  });
}
