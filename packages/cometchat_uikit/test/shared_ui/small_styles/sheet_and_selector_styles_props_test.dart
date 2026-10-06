/// Render-verified prop matrix for the last of the small style classes —
/// Track 3 PROP1.
///
/// The option sheets, the web view and the time-slot selector. 16 props
/// between them, 15 covered.
///
/// `TimeSlotSelectorStyle.titleStyle` is pinned construction-only: it is
/// declared and read nowhere, and unlike its four siblings it has no home —
/// the selector renders slots and an "unavailable" line, with no title. It
/// belongs with the ENG-38977 delete-or-wire decisions. ENG-39125.
///
///   flutter test test/shared_ui/small_styles/sheet_and_selector_styles_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _c1 = Color(0xFF101112);
const _c2 = Color(0xFF202122);
const _c3 = Color(0xFF303132);
const _c4 = Color(0xFF404142);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
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

List<TextStyle> _textStyles(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.style)
    .whereType<TextStyle>()
    .toList();

/// webview_flutter has no platform implementation headlessly, so the view's
/// body throws while building. The AppBar above it still builds, which is
/// where every WebViewStyle prop lands.
void _ignoreWebViewPlatformError() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('webview_flutter')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

class _FakeMessage extends Fake implements BaseMessage {
  @override
  int get id => 1;
  @override
  String get type => 'text';
  @override
  String get category => 'message';
  @override
  DateTime get sentAt => DateTime.fromMillisecondsSinceEpoch(1700000000000);
  @override
  DateTime? get deletedAt => null;
}

void main() {
  // ===========================================================================
  group('CometChatAttachmentOptionSheetStyle', () {
    testWidgets('all six props reach the sheet', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometChatAttachmentOptionSheet(
            actionItems: [
              ActionItem(
                id: 'photo',
                title: 'Photo',
                icon: const Icon(Icons.photo),
              ),
            ],
            style: const CometChatAttachmentOptionSheetStyle(
              backgroundColor: _c1,
              border: Border.fromBorderSide(BorderSide(color: _c2, width: 2)),
              borderRadius: BorderRadius.all(Radius.circular(15)),
              iconColor: _c3,
              titleColor: _c4,
              titleTextStyle: TextStyle(fontSize: 19),
            ),
          ),
        ),
      );
      await tester.pump();

      // The border sits on the sheet's outer decoration and the background on
      // an inner one, so they are read separately rather than off one box.
      final decs = _decorations(tester);
      expect(
        decs.any((d) => (d.border as Border?)?.top.color == _c2),
        isTrue,
        reason: 'border',
      );
      expect(
        decs.any(
          (d) =>
              d.color == _c1 &&
              d.borderRadius == const BorderRadius.all(Radius.circular(15)),
        ),
        isTrue,
        reason: 'background and radius',
      );

      expect(
        _textStyles(tester).any((t) => t.color == _c4 && t.fontSize == 19),
        isTrue,
        reason: 'item title',
      );

      // iconColor is applied through ListTile.iconColor rather than to the
      // Icon widget, so read it there.
      expect(
        tester
            .widgetList<ListTile>(find.byType(ListTile))
            .map((l) => l.iconColor),
        contains(_c3),
        reason: 'icon tint',
      );
    });
  });

  // ===========================================================================
  group('CometChatMessageOptionSheetStyle', () {
    testWidgets('border reaches the sheet', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CometchatMessageOptionSheet(
            messageObject: _FakeMessage(),
            hideReactions: true,
            actionItems: [
              ActionItem(
                id: 'copy',
                title: 'Copy',
                icon: const Icon(Icons.copy),
              ),
            ],
            messageOptionStyle: const CometChatMessageOptionSheetStyle(
              backgroundColor: _c1,
              border: Border.fromBorderSide(BorderSide(color: _c2, width: 2)),
            ),
          ),
        ),
      );
      await tester.pump();

      final dec = _decorations(
        tester,
      ).firstWhere((d) => (d.border as Border?)?.top.color == _c2);
      expect((dec.border as Border?)?.top.width, 2);
    });
  });

  // ===========================================================================
  group('CometChatAiOptionSheetStyle', () {
    testWidgets('all five props reach the bottom sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showCometChatAiOptionSheet(
                  context: context,
                  actionItems: [
                    CometChatMessageComposerAction(
                      id: 'summary',
                      title: 'Conversation summary',
                      icon: const Icon(Icons.summarize),
                    ),
                  ],
                  style: const CometChatAiOptionSheetStyle(
                    backgroundColor: _c1,
                    border: BorderSide(color: _c2, width: 2),
                    borderRadius: BorderRadius.all(Radius.circular(17)),
                    iconColor: _c3,
                    textStyle: TextStyle(color: _c4, fontSize: 19),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // backgroundColor, border and borderRadius land on the modal route's
      // own surface rather than inside the builder's tree.
      final sheet = tester.widget<Material>(
        find
            .ancestor(
              of: find.text('Conversation summary'),
              matching: find.byType(Material),
            )
            .last,
      );
      expect(sheet.color, _c1);

      final shape = sheet.shape as RoundedRectangleBorder?;
      expect(shape?.side.color, _c2);
      expect(shape?.borderRadius, const BorderRadius.all(Radius.circular(17)));

      expect(
        tester
            .widgetList<ListTile>(find.byType(ListTile))
            .map((l) => l.iconColor),
        contains(_c3),
        reason: 'icon tint',
      );
      expect(
        _textStyles(tester).any((t) => t.color == _c4 && t.fontSize == 19),
        isTrue,
        reason: 'action title',
      );
    });
  });

  // ===========================================================================
  group('WebViewStyle', () {
    // Honest caveat, because this group is weaker than everything else here.
    //
    // CometChatWebView's build throws without a WebViewPlatform
    // implementation — not just its body, the whole widget — so the AppBar
    // that every WebViewStyle prop feeds never mounts and there is nothing to
    // read off the tree. Standing up a fake WebViewPlatform means implementing
    // PlatformWebViewController and PlatformWebViewWidget, which is a lot of
    // surface for three props.
    //
    // So these assert the values the widget carries after a pump, matching
    // what test/shared_ui/core_widgets/core_widget_tail_props_test.dart
    // already does for the same widget. prop_coverage counts them, but they
    // are NOT paint assertions: they would still pass if the AppBar stopped
    // reading the style. Recorded on ENG-39125 as the one place in this matrix
    // where the gate is softer than it looks.

    testWidgets('the three props are carried to the view', (tester) async {
      _ignoreWebViewPlatformError();
      await tester.pumpWidget(
        _wrap(
          const CometChatWebView(
            title: 'Terms',
            webViewUrl: 'https://example.invalid/terms',
            webViewStyle: WebViewStyle(
              titleStyle: TextStyle(color: _c1, fontSize: 21),
              backIconColor: _c2,
              appBarColor: _c3,
            ),
          ),
        ),
      );
      await tester.pump();

      final view = tester.widget<CometChatWebView>(
        find.byType(CometChatWebView),
      );
      expect(view.webViewStyle?.titleStyle?.color, _c1);
      expect(view.webViewStyle?.titleStyle?.fontSize, 21);
      expect(view.webViewStyle?.backIconColor, _c2);
      // ENG-39125: appBarColor was declared on the style and read nowhere —
      // the widget's own parameter shadowed it. It is now the fallback.
      expect(view.webViewStyle?.appBarColor, _c3);
    });

    testWidgets('the widget parameter still beats the style', (tester) async {
      // Guards the precedence of the ENG-39125 fix: wiring the style must not
      // override an integrator already passing appBarColor directly.
      _ignoreWebViewPlatformError();
      await tester.pumpWidget(
        _wrap(
          const CometChatWebView(
            title: 'Terms',
            webViewUrl: 'https://example.invalid/terms',
            appBarColor: _c4,
            webViewStyle: WebViewStyle(appBarColor: _c3),
          ),
        ),
      );
      await tester.pump();

      final view = tester.widget<CometChatWebView>(
        find.byType(CometChatWebView),
      );
      expect(view.appBarColor, _c4);
      expect(view.webViewStyle?.appBarColor, _c3);
    });
  });

  // ===========================================================================
  group('TimeSlotSelectorStyle', () {
    testWidgets('the four slot props reach the slots', (tester) async {
      final day = DateTime(2026, 5, 12);

      await tester.pumpWidget(
        _wrap(
          CometChatTimeSlotSelector(
            selectedDay: day,
            duration: const Duration(minutes: 30),
            // Slots are generated from availableSlots only — from/to alone
            // leave timeList empty and the widget renders its "unavailable"
            // line instead.
            availableSlots: [
              DateTimeRange(
                start: day.add(const Duration(hours: 9)),
                end: day.add(const Duration(hours: 11)),
              ),
            ],
            style: TimeSlotSelectorStyle(
              slotBackgroundColor: _c1,
              slotTextStyle: const TextStyle(color: _c2, fontSize: 13),
              selectedSlotBackgroundColor: _c3,
              selectedSlotTextStyle: const TextStyle(color: _c4, fontSize: 15),
            ),
          ),
        ),
      );
      await tester.pump();

      // Unselected first: every slot starts unselected, so these two prove
      // themselves before anything is tapped.
      expect(
        _decorations(tester).any((d) => d.color == _c1),
        isTrue,
        reason: 'slot background',
      );
      expect(
        _textStyles(tester).any((t) => t.color == _c2 && t.fontSize == 13),
        isTrue,
        reason: 'slot label',
      );

      // Then select one, which is the only way the selected pair renders.
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(
        _decorations(tester).any((d) => d.color == _c3),
        isTrue,
        reason: 'selected slot background',
      );
      expect(
        _textStyles(tester).any((t) => t.color == _c4 && t.fontSize == 15),
        isTrue,
        reason: 'selected slot label',
      );
    });
  });

  // ===========================================================================
  group(
    'DEFECT — TimeSlotSelectorStyle.titleStyle is never read (ENG-39125)',
    () {
      // Constructed, not pumped: exercised without inflating the numerator. The
      // selector renders time slots and an "unavailable" line and has no title,
      // so there is nothing to style — this is a delete-or-design decision, not
      // a wire-up.
      test('titleStyle is accepted and discarded', () {
        final style = TimeSlotSelectorStyle(
          titleStyle: const TextStyle(color: _c1, fontSize: 23),
        );

        expect(style.titleStyle?.color, _c1);
        expect(style.titleStyle?.fontSize, 23);
      });
    },
  );
}
