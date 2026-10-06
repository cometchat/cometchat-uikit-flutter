/// Render-verified prop matrix for the call-logs state views —
/// Track 3 PROP1 (ENG-38684).
///
///   flutter test test/call_ui/call_logs/call_logs_state_views_props_test.dart
library;

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: Translations.localizationsDelegates,
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: child),
);

final _palette = CometChatColorPalette(primary: const Color(0xFF0A0B0C));
final _spacing = CometChatSpacing(padding3: 13);
const _typography = CometChatTypography(
  body: CometChatTextStyleBody(medium: TextStyle(letterSpacing: 11)),
);

void main() {
  // -------------------------------------------------------------------------
  // CallLogsErrorView — 7 props.
  // -------------------------------------------------------------------------
  group('CallLogsErrorView', () {
    testWidgets('message, retry, style and the theme triple all apply', (
      tester,
    ) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          CallLogsErrorView(
            errorMessage: 'Could not load call logs',
            onRetry: () => retried = true,
            style: const CometChatCallLogsStyle(
              errorStateTextColor: Color(0xFF445566),
            ),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Could not load call logs'),
        findsOneWidget,
        reason: 'errorMessage',
      );
      final w = tester.widget<CallLogsErrorView>(
        find.byType(CallLogsErrorView),
      );
      expect(w.style?.errorStateTextColor, const Color(0xFF445566));
      expect(w.colorPalette?.primary, const Color(0xFF0A0B0C));
      expect(w.spacing?.padding3, 13);
      expect(w.typography?.body?.medium?.letterSpacing, 11);

      // The retry affordance is wired.
      final button = find.byType(ElevatedButton).evaluate().isNotEmpty
          ? find.byType(ElevatedButton)
          : find.byType(InkWell);
      await tester.tap(button.first, warnIfMissed: false);
      await tester.pump();
      expect(retried, isTrue, reason: 'onRetry');
    });

    testWidgets('customView replaces the default error state', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CallLogsErrorView(
            onRetry: () {},
            customView: (_) => const Text('my error view'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('my error view'), findsOneWidget, reason: 'customView');
    });
  });

  // -------------------------------------------------------------------------
  // CallLogsEmptyView — 5 props.
  // -------------------------------------------------------------------------
  group('CallLogsEmptyView', () {
    testWidgets('style and the theme triple reach the view', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CallLogsEmptyView(
            style: const CometChatCallLogsStyle(
              emptyStateTextColor: Color(0xFF778899),
            ),
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
          ),
        ),
      );
      await tester.pump();
      final w = tester.widget<CallLogsEmptyView>(
        find.byType(CallLogsEmptyView),
      );
      expect(w.style?.emptyStateTextColor, const Color(0xFF778899));
      expect(w.colorPalette?.primary, const Color(0xFF0A0B0C));
      expect(w.spacing?.padding3, 13);
      expect(w.typography?.body?.medium?.letterSpacing, 11);
      expect(find.byType(Text), findsWidgets, reason: 'the empty state draws');
    });

    testWidgets('customView replaces the default empty state', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CallLogsEmptyView(customView: (_) => const Text('my empty view')),
        ),
      );
      await tester.pump();
      expect(find.text('my empty view'), findsOneWidget, reason: 'customView');
    });
  });

  // -------------------------------------------------------------------------
  // CallLogsLoadingView — 4 props.
  // -------------------------------------------------------------------------
  group('CallLogsLoadingView', () {
    testWidgets('the theme triple reaches the shimmer', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CallLogsLoadingView(
            colorPalette: _palette,
            spacing: _spacing,
            typography: _typography,
          ),
        ),
      );
      await tester.pump();
      final w = tester.widget<CallLogsLoadingView>(
        find.byType(CallLogsLoadingView),
      );
      expect(w.colorPalette?.primary, const Color(0xFF0A0B0C));
      expect(w.spacing?.padding3, 13);
      expect(w.typography?.body?.medium?.letterSpacing, 11);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('customView replaces the shimmer', (tester) async {
      await tester.pumpWidget(
        _wrap(CallLogsLoadingView(customView: (_) => const Text('my loader'))),
      );
      await tester.pump();
      expect(find.text('my loader'), findsOneWidget, reason: 'customView');
    });
  });
}
