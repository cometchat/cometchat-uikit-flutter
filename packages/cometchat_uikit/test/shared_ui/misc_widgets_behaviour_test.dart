/// Behaviour of the shared `misc/` views that their prop matrix cannot reach.
///
/// `misc_widgets_props_test.dart` drives [CometChatSingleSelect] with two
/// options, which is the Row layout. Three or more options take a completely
/// separate Column branch that had never run — and that branch quietly drops
/// the styling props, which is pinned here.
///
///   flutter test test/shared_ui/misc_widgets_behaviour_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _c1 = Color(0xFF111213);
const _c2 = Color(0xFF212223);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

List<OptionElement> _options(int n) => [
  for (var i = 0; i < n; i++)
    OptionElement(value: 'v$i', label: 'Option ${i + 1}'),
];

void main() {
  group('CometChatSingleSelect with three or more options', () {
    testWidgets('stacks the options instead of laying them out in a row', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            child: CometChatSingleSelect(options: _options(3)),
          ),
        ),
      );
      await tester.pump();

      final first = tester.getTopLeft(find.text('Option 1'));
      final second = tester.getTopLeft(find.text('Option 2'));
      final third = tester.getTopLeft(find.text('Option 3'));

      expect(
        second.dy,
        greaterThan(first.dy),
        reason: 'stacked, not side by side',
      );
      expect(third.dy, greaterThan(second.dy));
      expect(second.dx, first.dx);
    });

    testWidgets('selecting an option reports its value and restyles the row', (
      tester,
    ) async {
      String? chosen;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            child: CometChatSingleSelect(
              options: _options(3),
              onChanged: (v) => chosen = v,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<Text>(find.text('Option 3')).style?.fontWeight,
        FontWeight.normal,
      );

      await tester.tap(find.text('Option 3'));
      await tester.pump();

      expect(chosen, 'v2', reason: 'the value, not the label');
      expect(
        tester.widget<Text>(find.text('Option 3')).style?.fontWeight,
        FontWeight.bold,
        reason: 'the selected row takes the built-in selected style',
      );
    });

    testWidgets('an option selected up front renders selected without a tap', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            child: CometChatSingleSelect(
              options: _options(3),
              selectedValue: 'v1',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<Text>(find.text('Option 2')).style?.fontWeight,
        FontWeight.bold,
      );
    });

    testWidgets('with no onChanged a tap still moves the selection', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            child: CometChatSingleSelect(options: _options(3)),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Option 1'));
      await tester.pump();

      expect(
        tester.widget<Text>(find.text('Option 1')).style?.fontWeight,
        FontWeight.bold,
      );
    });

    // FINDING: the Column branch constructs `CometChatSingleSelectButton` with
    // only `selected`, `label` and `onSelected` — `selectedOptionsTextStyle`,
    // `optionTextStyle`, `selectedOptionBackground` and `optionBackground` are
    // all dropped. The Row branch (fewer than three options) forwards them. So
    // the same widget honours its styling props or ignores them depending on
    // how many options it was given. This pins the current behaviour.
    testWidgets('the styling props are dropped once there are three options', (
      tester,
    ) async {
      Widget select(int n) => _wrap(
        SizedBox(
          width: 400,
          child: CometChatSingleSelect(
            options: _options(n),
            selectedValue: 'v0',
            selectedOptionsTextStyle: const TextStyle(color: _c1, fontSize: 31),
            optionTextStyle: const TextStyle(color: _c2, fontSize: 17),
            selectedOptionBackground: _c1,
            optionBackground: _c2,
          ),
        ),
      );

      await tester.pumpWidget(select(2));
      await tester.pump();
      expect(
        tester.widget<Text>(find.text('Option 1')).style?.fontSize,
        31,
        reason: 'two options — the Row branch forwards the style',
      );

      await tester.pumpWidget(select(3));
      await tester.pump();
      expect(
        tester.widget<Text>(find.text('Option 1')).style?.fontSize,
        isNull,
        reason: 'three options — the Column branch drops it',
      );
      expect(
        tester.widget<Text>(find.text('Option 1')).style?.color,
        Colors.white,
        reason: 'it falls back to the built-in selected style',
      );
    });

    testWidgets('the decoration still wraps the stacked options', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            child: CometChatSingleSelect(
              options: _options(4),
              decoration: const BoxDecoration(color: _c1),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color == _c1,
        ),
        findsOneWidget,
      );
      expect(find.byType(CometChatSingleSelectButton), findsNWidgets(4));
    });
  });

  group('CometChatQuickView', () {
    testWidgets('the subtitle is omitted when none is given', (tester) async {
      await tester.pumpWidget(
        // Built without `const` on purpose: the const form is folded at compile
        // time, so the constructor body never runs.
        _wrap(CometChatQuickView(title: 'Alexandra', quickViewStyle: null)),
      );
      await tester.pump();

      expect(find.text('Alexandra'), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('with no style the panel is white behind a transparent bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CometChatQuickView(title: 'Alexandra', subtitle: 'later')),
      );
      await tester.pump();

      final inner = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.color == Colors.white);
      expect((inner.border! as Border).left.color, Colors.transparent);
      expect((inner.border! as Border).left.width, 4.0);
      expect(find.text('later'), findsOneWidget);
    });
  });
}
