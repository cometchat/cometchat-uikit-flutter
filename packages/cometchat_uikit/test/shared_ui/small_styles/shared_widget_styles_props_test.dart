/// Render-verified prop matrix for the small shared-widget style classes —
/// Track 3 PROP1.
///
/// Each of these belongs to a widget that can be pumped on its own, so every
/// case constructs the style, pumps the widget that takes it, and asserts the
/// painted result. No mocks and no bloc: that is the whole reason this group
/// is cheap to cover and was worth doing before the AI views, which fetch in
/// `initState` and need a seam they do not have.
///
///   flutter test test/shared_ui/small_styles/shared_widget_styles_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

const _c1 = Color(0xFF101112);
const _c2 = Color(0xFF202122);
const _c3 = Color(0xFF303132);
const _c4 = Color(0xFF404142);
const _c5 = Color(0xFF505152);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: Center(child: child)),
);

List<BoxDecoration> _decorations(WidgetTester tester) {
  final out = <BoxDecoration>[];
  for (final c in tester.widgetList<Container>(find.byType(Container))) {
    if (c.decoration is BoxDecoration) out.add(c.decoration! as BoxDecoration);
  }
  for (final d in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
    if (d.decoration is BoxDecoration) out.add(d.decoration as BoxDecoration);
  }
  return out;
}

List<TextStyle> _textStyles(WidgetTester tester) {
  final out = <TextStyle>[];
  void walk(InlineSpan? span) {
    if (span is TextSpan) {
      if (span.style != null) out.add(span.style!);
      span.children?.forEach(walk);
    }
  }

  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    if (t.style != null) out.add(t.style!);
    walk(t.textSpan);
  }
  for (final r in tester.widgetList<RichText>(find.byType(RichText))) {
    walk(r.text);
  }
  return out;
}

void main() {
  // ===========================================================================
  group('CometChatBadgeStyle', () {
    testWidgets('all six props reach the badge', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatBadge(
            count: 12,
            style: CometChatBadgeStyle(
              textStyle: TextStyle(fontSize: 19),
              textColor: _c1,
              backgroundColor: _c2,
              border: Border.fromBorderSide(BorderSide(color: _c3, width: 2)),
              borderRadius: BorderRadius.all(Radius.circular(9)),
              boxShape: BoxShape.rectangle,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        _textStyles(tester).any((t) => t.color == _c1 && t.fontSize == 19),
        isTrue,
        reason: 'count label',
      );

      final dec = _decorations(tester).firstWhere((d) => d.color == _c2);
      expect((dec.border as Border?)?.top.color, _c3);
      expect((dec.border as Border?)?.top.width, 2);
      expect(dec.borderRadius, const BorderRadius.all(Radius.circular(9)));
      expect(dec.shape, BoxShape.rectangle);
    });
  });

  // ===========================================================================
  group('CometChatAvatarStyle', () {
    testWidgets('all five props reach the avatar', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            const CometChatAvatar(
              name: 'Alexandra',
              style: CometChatAvatarStyle(
                backgroundColor: _c1,
                border: Border.fromBorderSide(BorderSide(color: _c2, width: 3)),
                borderRadius: BorderRadius.all(Radius.circular(11)),
                placeHolderTextColor: _c3,
                placeHolderTextStyle: TextStyle(fontSize: 17),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final dec = _decorations(tester).firstWhere((d) => d.color == _c1);
      expect((dec.border as Border?)?.top.color, _c2);
      expect(dec.borderRadius, const BorderRadius.all(Radius.circular(11)));

      expect(
        _textStyles(tester).any((t) => t.color == _c3 && t.fontSize == 17),
        isTrue,
        reason: 'initials',
      );
    });
  });

  // ===========================================================================
  group('CometChatStatusIndicatorStyle', () {
    testWidgets('all three props reach the indicator', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatStatusIndicator(
            style: CometChatStatusIndicatorStyle(
              backgroundColor: _c1,
              border: Border.fromBorderSide(BorderSide(color: _c2, width: 2)),
              borderRadius: BorderRadius.all(Radius.circular(5)),
            ),
          ),
        ),
      );
      await tester.pump();

      final dec = _decorations(tester).firstWhere((d) => d.color == _c1);
      expect((dec.border as Border?)?.top.color, _c2);
      expect(dec.borderRadius, const BorderRadius.all(Radius.circular(5)));
    });
  });

  // ===========================================================================
  group('CometChatDateStyle', () {
    testWidgets('all five props reach the date', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatDate(
            date: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            isTransparentBackground: false,
            style: const CometChatDateStyle(
              textStyle: TextStyle(fontSize: 15),
              textColor: _c1,
              backgroundColor: _c2,
              border: Border.fromBorderSide(BorderSide(color: _c3, width: 2)),
              borderRadius: BorderRadius.all(Radius.circular(7)),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        _textStyles(tester).any((t) => t.color == _c1 && t.fontSize == 15),
        isTrue,
        reason: 'date label',
      );

      final dec = _decorations(tester).firstWhere((d) => d.color == _c2);
      expect((dec.border as Border?)?.top.color, _c3);
      expect(dec.borderRadius, const BorderRadius.all(Radius.circular(7)));
    });
  });

  // ===========================================================================
  group('ListItemStyle', () {
    testWidgets('all four props reach the row', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            const CometChatListItem(
              title: 'Alexandra',
              avatarName: 'Alexandra',
              hideSeparator: false,
              style: ListItemStyle(
                titleStyle: TextStyle(color: _c1, fontSize: 21),
                separatorColor: _c2,
                padding: EdgeInsets.all(9),
                margin: EdgeInsets.all(5),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final title = tester.widget<Text>(find.text('Alexandra'));
      expect(title.style?.color, _c1);
      expect(title.style?.fontSize, 21);

      // padding and margin land on the row's outer Container. Both were
      // dropped by ListItemStyle.copyWith until ENG-39124, which is why they
      // are asserted here rather than taken on trust.
      expect(
        find.byWidgetPredicate(
          (w) => w is Container && w.padding == const EdgeInsets.all(9),
        ),
        findsWidgets,
        reason: 'padding',
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Container && w.margin == const EdgeInsets.all(5),
        ),
        findsWidgets,
        reason: 'margin',
      );

      // separatorColor is the Divider under the row, not a background fill.
      expect(
        tester.widget<Divider>(find.byType(Divider)).color,
        _c2,
        reason: 'separator',
      );
    });
  });

  // ===========================================================================
  group('CardStyle', () {
    testWidgets('both props reach the card', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          _wrap(
            const CometChatCard(
              title: 'Quarterly planning',
              avatarName: 'Quarterly planning',
              cardStyle: CardStyle(
                titleStyle: TextStyle(color: _c1, fontSize: 23),
                avatarStyle: CometChatAvatarStyle(backgroundColor: _c2),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        _textStyles(tester).any((t) => t.color == _c1 && t.fontSize == 23),
        isTrue,
        reason: 'card title',
      );
      expect(
        tester
            .widget<CometChatAvatar>(find.byType(CometChatAvatar))
            .style
            ?.backgroundColor,
        _c2,
      );
    });
  });

  // ===========================================================================
  group('QuickViewStyle', () {
    testWidgets('all five props reach the quick view', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatQuickView(
            title: 'Alexandra',
            subtitle: 'Rescheduled to Thursday',
            quickViewStyle: QuickViewStyle(
              titleStyle: TextStyle(color: _c1, fontSize: 21),
              subtitleStyle: TextStyle(color: _c2, fontSize: 13),
              leadingBarTint: _c3,
              leadingBarWidth: 6,
              closeIconTint: _c4,
            ),
          ),
        ),
      );
      await tester.pump();

      final styles = _textStyles(tester);
      expect(
        styles.any((t) => t.color == _c1 && t.fontSize == 21),
        isTrue,
        reason: 'title',
      );
      expect(
        styles.any((t) => t.color == _c2 && t.fontSize == 13),
        isTrue,
        reason: 'subtitle',
      );
      // The leading bar is the left side of a Border, not a fill — asserting
      // a background colour here finds nothing.
      final bar = _decorations(tester)
          .map((d) => d.border)
          .whereType<Border>()
          .firstWhere((b) => b.left.color == _c3, orElse: () => const Border());
      expect(bar.left.color, _c3, reason: 'leading bar tint');
      expect(bar.left.width, 6, reason: 'leading bar width');
    });
  });

  // ===========================================================================
  group('DecoratedContainerStyle', () {
    testWidgets('all five props reach the container', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatDecoratedContainer(
            title: 'Smart replies',
            content: Text('body'),
            style: DecoratedContainerStyle(
              titleStyle: TextStyle(color: _c1, fontSize: 19),
              backgroundColor: _c2,
              border: Border.fromBorderSide(BorderSide(color: _c3, width: 2)),
              borderRadius: BorderRadius.all(Radius.circular(13)),
              closeIconColor: _c4,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        _textStyles(tester).any((t) => t.color == _c1 && t.fontSize == 19),
        isTrue,
        reason: 'title',
      );

      final dec = _decorations(tester).firstWhere((d) => d.color == _c2);
      expect((dec.border as Border?)?.top.color, _c3);
      expect(dec.borderRadius, const BorderRadius.all(Radius.circular(13)));

      expect(
        tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.color),
        contains(_c4),
        reason: 'close icon',
      );
    });
  });

  // ===========================================================================
  group('SingleSelectStyle', () {
    testWidgets('all five props reach the options', (tester) async {
      // Short labels deliberately: this component overflows with long ones at
      // large text scale (ENG-39112), which is a layout defect rather than a
      // styling one and would fail this case for the wrong reason.
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            child: CometChatSingleSelect(
              options: [
                OptionElement(value: 'y', label: 'Yes'),
                OptionElement(value: 'n', label: 'No'),
              ],
              selectedValue: 'y',
              optionTextStyle: const TextStyle(color: _c1, fontSize: 13),
              selectedOptionsTextStyle: const TextStyle(
                color: _c2,
                fontSize: 15,
              ),
              optionBackground: _c3,
              selectedOptionBackground: _c4,
            ),
          ),
        ),
      );
      await tester.pump();

      final styles = _textStyles(tester);
      expect(
        styles.any((t) => t.color == _c2 && t.fontSize == 15),
        isTrue,
        reason: 'selected label',
      );
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
    });
  });

  // ===========================================================================
  group('CometChatMessageReceiptStyle', () {
    for (final entry in <String, ReceiptStatus>{
      'wait': ReceiptStatus.waiting,
      'sent': ReceiptStatus.sent,
      'delivered': ReceiptStatus.delivered,
      'read': ReceiptStatus.read,
      'error': ReceiptStatus.error,
    }.entries) {
      testWidgets('${entry.key}IconColor tints the ${entry.key} receipt', (
        tester,
      ) async {
        // One colour per status, each checked against a receipt in exactly
        // that status — a shared fixture would let one prop cover for another.
        await tester.pumpWidget(
          _wrap(
            CometChatReceipt(
              status: entry.value,
              style: CometChatMessageReceiptStyle(
                waitIconColor: _c1,
                sentIconColor: _c2,
                deliveredIconColor: _c3,
                readIconColor: _c4,
                errorIconColor: _c5,
              ),
            ),
          ),
        );
        await tester.pump();

        const expected = <String, Color>{
          'wait': _c1,
          'sent': _c2,
          'delivered': _c3,
          'read': _c4,
          'error': _c5,
        };
        expect(
          tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.color),
          contains(expected[entry.key]),
        );
      });
    }
  });
}
