/// Layout properties of `CometChatMediaGrid`, the multi-attachment grid.
/// The layout is not a pure function, so the properties are stated over the
/// rectangles the framework actually lays out.
///
///   flutter test test/property/media_grid_layout_property_test.dart
library;

import 'dart:math';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/generators.dart';
import 'support/harness.dart';

const int _cap = 4;
const double _eps = 0.01;

class _GridCase {
  _GridCase(this.count, this.width, this.gap, this.triple);
  final int count;
  final double width;
  final double gap;
  final MediaGridTripleLayout triple;

  @override
  String toString() =>
      'count: $count, width: $width, gap: $gap, triple: ${triple.name}';
}

_GridCase _genCase(Random r) => _GridCase(
  r.chance(0.7) ? r.between(1, 6) : r.between(7, 40),
  (120 + r.nextInt(240)).toDouble(),
  r.pick([0.0, 1.0, 2.0, 4.0, 7.5]),
  // A fixed variant: `auto` resolves the hero image over the network.
  r.pick([MediaGridTripleLayout.heroTop, MediaGridTripleLayout.heroLeft]),
);

/// Documents, so every cell is the placeholder tile and nothing is fetched.
List<Attachment> _files(int n) => [
  for (var i = 0; i < n; i++)
    Attachment(
      'https://cdn.example/$i.pdf',
      '$i.pdf',
      'pdf',
      'application/pdf',
      1,
    ),
];

Future<(Rect, List<Rect>)> _layout(WidgetTester tester, _GridCase c) async {
  await pumpInApp(
    tester,
    CometChatMediaGrid(
      media: _files(c.count),
      width: c.width,
      gap: c.gap,
      style: CometChatMediaGridStyle(tripleLayout: c.triple),
    ),
  );
  final grid = find.byType(CometChatMediaGrid);
  final cells = find.descendant(
    of: grid,
    matching: find.byType(GestureDetector),
  );
  return (
    tester.getRect(grid),
    [for (final e in cells.evaluate()) tester.getRect(find.byWidget(e.widget))],
  );
}

void main() {
  testWidgets('the grid never shows more than four cells, keeps every cell '
      'inside itself, and no two cells overlap', (tester) async {
    final cases = <_GridCase>[];
    forAll(_genCase, cases.add, cases: 80);

    for (final c in cases) {
      final (grid, cells) = await _layout(tester, c);

      expect(cells, hasLength(min(c.count, _cap)), reason: '$c');
      expect(grid.width, closeTo(c.width, _eps), reason: '$c');
      for (final cell in cells) {
        expect(cell.width, greaterThan(0), reason: '$c');
        expect(cell.height, greaterThan(0), reason: '$c');
        expect(cell.left, greaterThanOrEqualTo(grid.left - _eps), reason: '$c');
        expect(cell.top, greaterThanOrEqualTo(grid.top - _eps), reason: '$c');
        expect(cell.right, lessThanOrEqualTo(grid.right + _eps), reason: '$c');
        expect(
          cell.bottom,
          lessThanOrEqualTo(grid.bottom + _eps),
          reason: '$c',
        );
      }
      for (var i = 0; i < cells.length; i++) {
        for (var j = i + 1; j < cells.length; j++) {
          final overlap = cells[i]
              .deflate(_eps)
              .overlaps(cells[j].deflate(_eps));
          expect(overlap, isFalse, reason: '$c — cells $i and $j');
          // …and neighbours are at least `gap` apart on one axis.
          final dx =
              max(cells[i].left, cells[j].left) -
              min(cells[i].right, cells[j].right);
          final dy =
              max(cells[i].top, cells[j].top) -
              min(cells[i].bottom, cells[j].bottom);
          expect(max(dx, dy), greaterThanOrEqualTo(c.gap - _eps), reason: '$c');
        }
      }
    }
  });

  testWidgets('attachments beyond the fourth are announced as "+N" on the '
      'last cell, and only then', (tester) async {
    final cases = <_GridCase>[];
    forAll(_genCase, cases.add, cases: 60);

    for (final c in cases) {
      await _layout(tester, c);
      final badge = find.textContaining(RegExp(r'^\+\d+$'));
      if (c.count > _cap) {
        expect(badge, findsOneWidget, reason: '$c');
        expect(tester.widget<Text>(badge).data, '+${c.count - _cap}');
      } else {
        expect(badge, findsNothing, reason: '$c');
      }
    }
  });

  testWidgets('the grid is square — except a pair, which is one row of two '
      'squares — and its height never shrinks as the width grows', (
    tester,
  ) async {
    final cases = <(int, double, double)>[];
    forAll(
      (r) {
        final w = (120 + r.nextInt(200)).toDouble();
        return (r.between(1, 9), w, w + r.nextInt(80));
      },
      cases.add,
      cases: 40,
    );

    for (final (count, narrow, wide) in cases) {
      final a = await _layout(
        tester,
        _GridCase(count, narrow, 2, MediaGridTripleLayout.heroTop),
      );
      final b = await _layout(
        tester,
        _GridCase(count, wide, 2, MediaGridTripleLayout.heroTop),
      );
      final reason = 'count: $count, $narrow → $wide';
      expect(
        b.$1.height,
        greaterThanOrEqualTo(a.$1.height - _eps),
        reason: reason,
      );
      if (count != 2) {
        expect(a.$1.height, closeTo(narrow, _eps), reason: reason);
      } else {
        expect(a.$1.height, closeTo((narrow - 2) / 2, _eps), reason: reason);
      }
    }
  });
}
