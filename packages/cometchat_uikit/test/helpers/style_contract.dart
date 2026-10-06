/// Table-driven contract checks for the UIKit style / theme-token classes.
///
/// Every one of those classes is the same shape: a bag of nullable fields plus
/// `copyWith`, `merge` and `lerp`. The bugs they actually have are mechanical —
/// a `copyWith` that forgets to thread a field through, a `merge` that drops a
/// field so an integrator's explicit value is silently ignored, a `lerp` that
/// interpolates the wrong field into a slot. This helper pins exactly that:
///
///  * `copyWith(x: v)` sets `x` to `v` and changes nothing else,
///  * every field survives `copyWith` when they are all set together,
///  * `copyWith()` with no arguments is a faithful copy,
///  * `merge(null)` returns the receiver itself,
///  * `merge(other)` gives every non-null field of `other` precedence, and a
///    null field of `other` leaves the receiver's value alone,
///  * `lerp(other, t)` with a non-matching `other` returns the receiver, and at
///    `t == 0` / `t == 1` every value-typed field reads back the endpoint value
///    it came from (so a cross-wired slot fails).
///
/// Each field is described once, in a table, by its `copyWith` parameter and
/// its getter. Two distinct values per field make a dropped, cross-wired or
/// precedence-inverted field detectable.
library;

import 'package:flutter_test/flutter_test.dart';

/// One field of style class [S], wired to its `copyWith` parameter and getter.
abstract class StyleField<S> {
  String get name;

  Object? get valueA;

  Object? get valueB;

  /// Whether the field's type has value equality and is interpolated to the
  /// exact endpoint value at `t == 0` / `t == 1`. Nested style objects are
  /// rebuilt by their own `lerp` and compare by identity, so they are excluded
  /// from the endpoint assertions (they are still exercised).
  bool get lerpsByValue;

  S withA(S style);

  S withB(S style);

  Object? read(S style);
}

/// Concrete [StyleField] for a field of type [T] on style class [S].
class Fld<S, T extends Object> implements StyleField<S> {
  const Fld(
    this.name,
    this.valueA,
    this.valueB,
    this._with,
    this._read, {
    this.lerpsByValue = true,
  });

  @override
  final String name;

  @override
  final T valueA;

  @override
  final T valueB;

  @override
  final bool lerpsByValue;

  final S Function(S style, T value) _with;
  final T? Function(S style) _read;

  @override
  S withA(S style) => _with(style, valueA);

  @override
  S withB(S style) => _with(style, valueB);

  @override
  Object? read(S style) => _read(style);
}

/// Runs the whole contract for [fields] of style class [S].
///
/// [empty] is the default-constructed style. [copyWithNothing] must call
/// `copyWith()` with no arguments. [merge] and [lerp] are optional because a
/// handful of the classes do not declare them.
void expectStyleContract<S extends Object>({
  required String label,
  required S empty,
  required List<StyleField<S>> fields,
  required S Function(S style) copyWithNothing,
  S Function(S style, S? other)? merge,
  S Function(S style, S? other, double t)? lerp,
  bool lerpNullReturnsSelf = true,
  bool mergeNullReturnsSelf = true,
}) {
  expect(fields, isNotEmpty, reason: '$label: no fields described');

  // Distinct values per field, so nothing can pass by coincidence.
  final seenA = <Object?>{};
  for (final f in fields) {
    expect(
      f.valueA,
      isNot(equals(f.valueB)),
      reason: '$label.${f.name}: the two probe values must differ',
    );
    expect(
      seenA.add(f.valueA),
      isTrue,
      reason: '$label.${f.name}: probe value is shared with another field',
    );
  }

  // 1. copyWith(x: v) sets x and touches nothing else.
  for (final f in fields) {
    final applied = f.withA(empty);
    expect(
      f.read(applied),
      f.valueA,
      reason: '$label.copyWith(${f.name}:) did not set ${f.name}',
    );
    for (final g in fields) {
      if (identical(g, f)) continue;
      expect(
        g.read(applied),
        g.read(empty),
        reason: '$label.copyWith(${f.name}:) also changed ${g.name}',
      );
    }
  }

  // 2. All fields survive together, and copyWith() with no arguments copies
  //    every one of them.
  final a = fields.fold<S>(empty, (s, f) => f.withA(s));
  final b = fields.fold<S>(empty, (s, f) => f.withB(s));
  for (final f in fields) {
    expect(
      f.read(a),
      f.valueA,
      reason: '$label.copyWith dropped ${f.name} when every field was set',
    );
    expect(
      f.read(b),
      f.valueB,
      reason: '$label.copyWith dropped ${f.name} when every field was set',
    );
  }
  final copy = copyWithNothing(a);
  for (final f in fields) {
    expect(
      f.read(copy),
      f.valueA,
      reason: '$label.copyWith() with no arguments lost ${f.name}',
    );
  }

  // 3. merge precedence: the argument wins where it is non-null, the receiver
  //    survives where it is null.
  if (merge != null) {
    final mergedNull = merge(a, null);
    if (mergeNullReturnsSelf) {
      expect(
        identical(mergedNull, a),
        isTrue,
        reason: '$label.merge(null) must return the receiver',
      );
    } else {
      // A few classes rebuild instead of short-circuiting; the values still
      // have to survive.
      for (final f in fields) {
        expect(
          f.read(mergedNull),
          f.valueA,
          reason: '$label.merge(null) lost ${f.name}',
        );
      }
    }
    final ab = merge(a, b);
    for (final f in fields) {
      expect(
        f.read(ab),
        f.valueB,
        reason: '$label.merge dropped ${f.name}: the explicit style lost',
      );
    }
    final aOverEmpty = merge(a, empty);
    for (final f in fields) {
      final fallback = f.read(empty);
      expect(
        f.read(aOverEmpty),
        fallback ?? f.valueA,
        reason: '$label.merge let a null ${f.name} clobber the receiver',
      );
    }
    final emptyUnderA = merge(empty, a);
    for (final f in fields) {
      expect(
        f.read(emptyUnderA),
        f.valueA,
        reason: '$label.merge dropped ${f.name} onto a default style',
      );
    }
  }

  // 4. lerp: a non-matching `other` returns the receiver, and the endpoints
  //    read back the value they came from.
  if (lerp != null) {
    // Not every class guards `other is! S` — the ones that instead fade
    // towards null, or throw, are pinned individually in
    // `style_lerp_findings_test.dart`.
    if (lerpNullReturnsSelf) {
      expect(
        identical(lerp(a, null, 0.5), a),
        isTrue,
        reason: '$label.lerp(null, t) must return the receiver',
      );
    }
    final at0 = lerp(a, b, 0.0);
    final at1 = lerp(a, b, 1.0);
    for (final f in fields) {
      if (!f.lerpsByValue) continue;
      expect(
        f.read(at0),
        f.valueA,
        reason: '$label.lerp(t: 0) did not keep ${f.name}',
      );
      expect(
        f.read(at1),
        f.valueB,
        reason: '$label.lerp(t: 1) did not reach ${f.name}',
      );
    }
  }
}
