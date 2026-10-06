/// Behaviour pins for [SliverSpacing] — the sliver that keeps the bottom of
/// the message list clear of the composer, the safe area and the keyboard.
///
/// The only observable output is the bottom padding it emits, so every test
/// here reads that padding back off the [SliverPadding] it builds and drives
/// the inputs the widget actually listens to: the composer notifier, the
/// scroll controller, and real `viewInsets` changes on the test view (which is
/// what fires `didChangeMetrics`).
///
///   flutter test test/shared_ui/animated_message_list/sliver_spacing_test.dart
library;

import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Device pixel ratio used by every test — the widget divides the raw
/// `viewInsets.bottom` by it, so keeping it at 1 makes the arithmetic literal.
const double _dpr = 1.0;

/// Tall enough content below the spacing sliver that the list can be scrolled.
Widget _filler() => const SliverToBoxAdapter(child: SizedBox(height: 2000));

/// `skipOffstage: false` throughout: one test parks the list under another
/// route, where the sliver is still built but no longer onstage.
double _bottomPadding(WidgetTester tester) => tester
    .widget<SliverPadding>(
      find.descendant(
        of: find.byType(SliverSpacing, skipOffstage: false),
        matching: find.byType(SliverPadding, skipOffstage: false),
        skipOffstage: false,
      ),
    )
    .padding
    .resolve(TextDirection.ltr)
    .bottom;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Mounts [spacing] inside a scroll view. [safeAreaBottom] becomes the
  /// MediaQuery bottom padding the widget snapshots in
  /// `didChangeDependencies`.
  Future<void> pumpSpacing(
    WidgetTester tester,
    SliverSpacing spacing, {
    ScrollController? controller,
    double safeAreaBottom = 0,
    List<Widget> overlayRoutes = const [],
  }) async {
    tester.view.devicePixelRatio = _dpr;
    tester.view.viewInsets = const FakeViewPadding();
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Translations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(padding: EdgeInsets.only(bottom: safeAreaBottom)),
          child: child!,
        ),
        home: Scaffold(
          body: CustomScrollView(
            controller: controller,
            slivers: [spacing, _filler()],
          ),
        ),
      ),
    );
    await tester.pump();
    for (final route in overlayRoutes) {
      // Cover the spacing's route so `ModalRoute.isCurrent` goes false.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => route)));
      await tester.pumpAndSettle();
    }
  }

  /// Raises the keyboard to [logical] logical pixels and lets the 250ms
  /// height animation finish.
  Future<void> setKeyboard(WidgetTester tester, double logical) async {
    tester.view.viewInsets = FakeViewPadding(bottom: logical * _dpr);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('resting height', () {
    testWidgets('is the bottom padding plus the fixed composer height', (
      tester,
    ) async {
      await pumpSpacing(
        tester,
        const SliverSpacing(bottomPadding: 12, composerHeight: 60),
      );

      expect(_bottomPadding(tester), 72);
    });

    testWidgets('prefers the notifier over the fixed composer height, and '
        'tracks it', (tester) async {
      final notifier = ComposerHeightNotifier();
      addTearDown(notifier.dispose);

      await pumpSpacing(
        tester,
        SliverSpacing(
          bottomPadding: 10,
          composerHeight: 999,
          composerHeightNotifier: notifier,
        ),
      );
      // The notifier starts at 0, so the fixed height is ignored entirely.
      expect(_bottomPadding(tester), 10);

      notifier.setHeight(48);
      await tester.pump();
      expect(_bottomPadding(tester), 58);

      // A no-op set must not move the padding.
      notifier.setHeight(48);
      await tester.pump();
      expect(_bottomPadding(tester), 58);
    });

    testWidgets('adds the safe area only when asked to handle it', (
      tester,
    ) async {
      await pumpSpacing(
        tester,
        const SliverSpacing(composerHeight: 20, handleSafeArea: true),
        safeAreaBottom: 34,
      );
      expect(_bottomPadding(tester), 54);

      await pumpSpacing(
        tester,
        const SliverSpacing(composerHeight: 20),
        safeAreaBottom: 34,
      );
      expect(_bottomPadding(tester), 20);
    });
  });

  group('the keyboard', () {
    testWidgets('pushes the list up by its height and reports the delta', (
      tester,
    ) async {
      final deltas = <double>[];
      await pumpSpacing(
        tester,
        SliverSpacing(composerHeight: 50, onKeyboardHeightChanged: deltas.add),
      );
      expect(_bottomPadding(tester), 50);

      await setKeyboard(tester, 300);

      expect(_bottomPadding(tester), 350);
      expect(deltas, [300]);
    });

    testWidgets('animates between the old and the new height rather than '
        'jumping', (tester) async {
      await pumpSpacing(tester, const SliverSpacing(composerHeight: 50));

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final mid = _bottomPadding(tester);
      expect(mid, greaterThan(50));
      expect(mid, lessThan(350));

      await tester.pump(const Duration(milliseconds: 300));
      expect(_bottomPadding(tester), 350);
    });

    testWidgets('closing reports a negative delta and returns to rest', (
      tester,
    ) async {
      final deltas = <double>[];
      await pumpSpacing(
        tester,
        SliverSpacing(composerHeight: 50, onKeyboardHeightChanged: deltas.add),
      );

      await setKeyboard(tester, 300);
      await setKeyboard(tester, 0);

      expect(deltas, [300, -300]);
      expect(_bottomPadding(tester), 50);
    });

    testWidgets('is measured net of the safe area the view already reserves', (
      tester,
    ) async {
      await pumpSpacing(
        tester,
        const SliverSpacing(composerHeight: 50, handleSafeArea: true),
        safeAreaBottom: 34,
      );
      expect(_bottomPadding(tester), 84);

      await setKeyboard(tester, 300);

      // 300 raw - 34 of already-reserved safe area = 266 of real keyboard,
      // and the safe area drops out once the keyboard covers it.
      expect(_bottomPadding(tester), 50 + 266);
    });

    testWidgets('is ignored entirely when includeKeyboardHeight is false', (
      tester,
    ) async {
      final deltas = <double>[];
      await pumpSpacing(
        tester,
        SliverSpacing(
          composerHeight: 50,
          includeKeyboardHeight: false,
          onKeyboardHeightChanged: deltas.add,
        ),
      );

      await setKeyboard(tester, 300);

      expect(_bottomPadding(tester), 50);
      expect(deltas, isEmpty);
    });

    testWidgets('leaves the list alone while a route is stacked on top', (
      tester,
    ) async {
      await pumpSpacing(
        tester,
        const SliverSpacing(composerHeight: 50),
        overlayRoutes: const [Scaffold(body: Text('viewer'))],
      );
      expect(find.text('viewer'), findsOneWidget);

      await setKeyboard(tester, 300);

      // The spacing's own route is not current, so the stale inset from the
      // overlaying route must not reach it.
      expect(_bottomPadding(tester), 50);
    });
  });

  group('holding position when the user has scrolled up', () {
    testWidgets('a list scrolled away from the bottom does not move, and no '
        'delta is reported', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final deltas = <double>[];

      await pumpSpacing(
        tester,
        SliverSpacing(
          composerHeight: 50,
          scrollController: controller,
          onKeyboardHeightChanged: deltas.add,
        ),
        controller: controller,
      );

      controller.jumpTo(400); // well past the 50px default threshold
      await tester.pump();

      await setKeyboard(tester, 300);

      expect(_bottomPadding(tester), 50);
      expect(deltas, isEmpty);
    });

    testWidgets('a held list ignores even a composer that grows under the '
        'keyboard', (tester) async {
      final controller = ScrollController();
      final notifier = ComposerHeightNotifier();
      addTearDown(controller.dispose);
      addTearDown(notifier.dispose);

      await pumpSpacing(
        tester,
        SliverSpacing(
          bottomPadding: 10,
          composerHeightNotifier: notifier,
          scrollController: controller,
        ),
        controller: controller,
      );
      notifier.setHeight(40);
      await tester.pump();
      expect(_bottomPadding(tester), 50);

      controller.jumpTo(400);
      await tester.pump();
      await setKeyboard(tester, 300);

      // The composer growing is what forces a rebuild here; the held list
      // must still report the height it had before the keyboard opened.
      notifier.setHeight(90);
      await tester.pump();
      expect(_bottomPadding(tester), 50);
    });

    testWidgets('a list within the threshold still gets pushed', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await pumpSpacing(
        tester,
        SliverSpacing(
          composerHeight: 50,
          scrollController: controller,
          atBottomThreshold: 120,
        ),
        controller: controller,
      );

      controller.jumpTo(100); // inside the widened threshold
      await tester.pump();

      await setKeyboard(tester, 300);

      expect(_bottomPadding(tester), 350);
    });

    testWidgets('the held list snaps back once the keyboard is dismissed', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await pumpSpacing(
        tester,
        SliverSpacing(composerHeight: 50, scrollController: controller),
        controller: controller,
      );

      controller.jumpTo(400);
      await tester.pump();
      await setKeyboard(tester, 300);
      expect(_bottomPadding(tester), 50);

      // Closing rearms "push the list" for the next time, even though the
      // user is still scrolled up.
      await setKeyboard(tester, 0);
      controller.jumpTo(400);
      await tester.pump();
      await setKeyboard(tester, 300);
      expect(_bottomPadding(tester), 50);

      // ...and from the bottom it pushes again.
      await setKeyboard(tester, 0);
      controller.jumpTo(0);
      await tester.pump();
      await setKeyboard(tester, 300);
      expect(_bottomPadding(tester), 350);
    });
  });

  group('reconfiguration', () {
    testWidgets('swapping the composer notifier moves the listener across', (
      tester,
    ) async {
      final first = ComposerHeightNotifier();
      final second = ComposerHeightNotifier();
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      Future<void> pumpWith(ComposerHeightNotifier n) => pumpSpacing(
        tester,
        SliverSpacing(composerHeightNotifier: n, bottomPadding: 5),
      );

      await pumpWith(first);
      first.setHeight(40);
      await tester.pump();
      expect(_bottomPadding(tester), 45);

      await pumpWith(second);
      // The cached height survives the swap until the new notifier speaks —
      // the widget reads notifiers only through their notifications, never
      // their current value.
      expect(_bottomPadding(tester), 45);

      second.setHeight(90);
      await tester.pump();
      expect(_bottomPadding(tester), 95);

      // The old notifier must no longer be able to move this sliver.
      first.setHeight(1000);
      await tester.pump();
      expect(_bottomPadding(tester), 95);
    });

    testWidgets('turning keyboard handling off drops the keyboard height it '
        'had already accumulated', (tester) async {
      await pumpSpacing(tester, const SliverSpacing(composerHeight: 50));
      await setKeyboard(tester, 300);
      expect(_bottomPadding(tester), 350);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Translations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                const SliverSpacing(
                  composerHeight: 50,
                  includeKeyboardHeight: false,
                ),
                _filler(),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_bottomPadding(tester), 50);
    });

    testWidgets('turning keyboard handling back on re-subscribes to metrics', (
      tester,
    ) async {
      Future<void> pumpWith({required bool include}) => pumpSpacing(
        tester,
        SliverSpacing(composerHeight: 50, includeKeyboardHeight: include),
      );

      await pumpWith(include: false);
      await setKeyboard(tester, 300);
      expect(_bottomPadding(tester), 50);

      await pumpWith(include: true);
      // Re-registering alone changes nothing; the next metrics change does.
      expect(_bottomPadding(tester), 50);

      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_bottomPadding(tester), 250);
    });

    testWidgets('swapping the scroll controller re-points the at-bottom '
        'check', (tester) async {
      final first = ScrollController();
      final second = ScrollController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      Future<void> pumpWith(ScrollController c) => pumpSpacing(
        tester,
        SliverSpacing(composerHeight: 50, scrollController: c),
        controller: c,
      );

      // First controller sits at the bottom: the keyboard would push.
      await pumpWith(first);
      await pumpWith(second);

      // Scrolling the NEW controller must now be what the sliver reads.
      second.jumpTo(400);
      await tester.pump();

      await setKeyboard(tester, 300);
      expect(_bottomPadding(tester), 50);
    });
  });
}
