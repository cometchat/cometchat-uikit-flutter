/// Render-verified prop matrix for the shared message-list widgets —
/// Track 3 PROP1/PROP2 (ENG-38961).
///
///   flutter test test/shared_ui/message_list_widgets_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: Stack(children: [child])),
);

void main() {
  // -------------------------------------------------------------------------
  // ScrollToBottomButton — 12 props.
  // -------------------------------------------------------------------------
  group('ScrollToBottomButton', () {
    testWidgets('every property reaches the rendered button', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ScrollToBottomButton(
              animation: const AlwaysStoppedAnimation<double>(1),
              onPressed: () => pressed = true,
              backgroundColor: const Color(0xFF123456),
              iconColor: const Color(0xFF654321),
              icon: Icons.arrow_downward,
              size: 52,
              elevation: 9,
              bottom: 33,
              right: 44,
              unreadCount: 7,
              badgeColor: const Color(0xFFAA0011),
              badgeTextColor: const Color(0xFF00BB22),
            ),
          ),
        ),
      );
      await tester.pump();

      // Position: bottom / right.
      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      expect(positioned.bottom, 33, reason: 'bottom');
      expect(positioned.right, 44, reason: 'right');

      // Surface: size, elevation, backgroundColor.
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(ScrollToBottomButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.elevation, 9, reason: 'elevation');
      expect(
        material.color,
        const Color(0xFF123456),
        reason: 'backgroundColor',
      );

      final sized = tester.widgetList<SizedBox>(
        find.descendant(
          of: find.byType(ScrollToBottomButton),
          matching: find.byType(SizedBox),
        ),
      );
      expect(
        sized.any((s) => s.width == 52 && s.height == 52),
        isTrue,
        reason: 'size',
      );

      // Icon: icon + iconColor, sized relative to `size`.
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.arrow_downward, reason: 'icon');
      expect(icon.color, const Color(0xFF654321), reason: 'iconColor');
      expect(icon.size, 52 * 0.6, reason: 'size drives the icon');

      // Badge: unreadCount, badgeColor, badgeTextColor.
      expect(find.text('7'), findsOneWidget, reason: 'unreadCount');
      expect(
        tester.widget<Text>(find.text('7')).style?.color,
        const Color(0xFF00BB22),
        reason: 'badgeTextColor',
      );
      expect(
        tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .any((d) => d.color == const Color(0xFFAA0011)),
        isTrue,
        reason: 'badgeColor',
      );

      // onPressed + animation (a zero animation would hide the button).
      await tester.tap(find.byType(Icon), warnIfMissed: false);
      await tester.pump();
      expect(pressed, isTrue, reason: 'onPressed');
    });

    testWidgets('a zero animation collapses the button', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ScrollToBottomButton(
            animation: const AlwaysStoppedAnimation<double>(0),
            onPressed: () {},
          ),
        ),
      );
      await tester.pump();
      final transitions = tester.widgetList<ScaleTransition>(
        find.byType(ScaleTransition),
      );
      expect(
        transitions.isEmpty || transitions.first.scale.value == 0,
        isTrue,
        reason: 'animation',
      );
    });
  });

  // -------------------------------------------------------------------------
  // CometChatNewMessageIndicatorStyle — 4 props, via its indicator.
  // -------------------------------------------------------------------------
  group('CometChatNewMessageIndicatorStyle', () {
    testWidgets('divider, text colour, text style and background all apply', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CometChatNewMessageIndicator(
            text: 'New messages',
            style: CometChatNewMessageIndicatorStyle(
              dividerColor: Color(0xFF445566),
              textColor: Color(0xFF778811),
              textStyle: TextStyle(fontSize: 23),
              backgroundColor: Color(0xFF991122),
            ),
          ),
        ),
      );
      await tester.pump();

      final label = tester.widget<Text>(find.text('New messages'));
      expect(label.style?.fontSize, 23, reason: 'textStyle');
      expect(label.style?.color, const Color(0xFF778811), reason: 'textColor');

      expect(
        tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.color)
            .contains(const Color(0xFF991122)),
        isTrue,
        reason: 'backgroundColor',
      );
      expect(
        tester
            .widgetList<Divider>(find.byType(Divider))
            .every((d) => d.color == const Color(0xFF445566)),
        isTrue,
        reason: 'dividerColor',
      );
    });
  });
}
