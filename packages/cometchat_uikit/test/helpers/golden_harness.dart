/// Shared harness for the light + dark component goldens.
///
/// Every golden built on this renders the real Kit widget twice, once under
/// `ThemeData.light()` and once under `ThemeData.dark()`, side by side in one
/// PNG. Each scenario gets its own `MaterialApp`, so the widget under test has
/// the ancestors it has in an app: Navigator, Overlay, ScaffoldMessenger,
/// Directionality, Material, the Kit's localizations and a real MediaQuery
/// size (several Kit widgets size themselves off `MediaQuery.sizeOf`).
library;

import 'package:alchemist/alchemist.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One themed scenario: [child] on the Kit's `background1` for [brightness].
Widget goldenThemed({
  required Brightness brightness,
  required Size size,
  required Widget child,
  AlignmentGeometry alignment = Alignment.topCenter,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size, platformBrightness: brightness),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.dark
          ? ThemeData.dark()
          : ThemeData.light(),
      localizationsDelegates: Translations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: CometChatThemeHelper.getColorPalette(
            context,
          ).background1,
          body: Align(alignment: alignment, child: child),
        ),
      ),
    ),
  );
}

/// The phone the scenarios pretend to run on. Kit widgets read this through
/// `MediaQuery.sizeOf`: the avatar derives its initials size from it and the
/// bubbles their maximum width, so it has to be a real screen and not the
/// (often much smaller) scenario box.
const Size goldenScreen = Size(375, 812);

/// Loads every asset image in the tree, then pumps.
///
/// The Kit's icons are `Image.asset`s, and an asset resolves on a real async
/// turn that a bare `pump` never reaches, so without this they are missing
/// from the picture. With [settle] false a fixed number of frames is pumped
/// instead of settling, for widgets that animate forever (shimmer, marquee,
/// ringing avatars).
PumpAction loadImagesThenPump({bool settle = true, int frames = 3}) {
  return (WidgetTester tester) async {
    Future<void> pump() async {
      if (settle) {
        await tester.pumpAndSettle();
        return;
      }
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await pump();
    await tester.runAsync(() async {
      final pending = <Future<void>>[];
      for (final element in find.byType(Image).evaluate()) {
        pending.add(precacheImage((element.widget as Image).image, element));
      }
      await Future.wait(pending);
    });
    await pump();
  };
}

/// A golden with a `light` and a `dark` scenario of the same widget.
///
/// [builder] is called once per theme so the two scenarios never share a
/// widget instance, a bloc or a controller. Pass `settle: false` for widgets
/// that never stop animating.
void lightDarkGolden(
  String description, {
  required String fileName,
  required Size size,
  required Widget Function() builder,
  Size screen = goldenScreen,
  AlignmentGeometry alignment = Alignment.topCenter,
  bool settle = true,
  Future<void> Function(WidgetTester tester)? interact,
  Duration? drain,
}) {
  goldenTest(
    description,
    fileName: fileName,
    pumpBeforeTest: loadImagesThenPump(settle: settle),
    // [interact] drives the widgets into the state to capture (alchemist does
    // not pump after it, so it pumps itself). [drain] then runs the clock
    // forward once the picture is taken, for widgets that leave timers
    // pending (typing debounce, snack bars) which would fail the test.
    whilePerforming: (tester) async {
      await interact?.call(tester);
      return () async {
        if (drain != null) await tester.pump(drain);
      };
    },
    builder: () => GoldenTestGroup(
      scenarioConstraints: BoxConstraints.tightFor(
        width: size.width,
        height: size.height,
      ),
      children: [
        for (final brightness in Brightness.values.reversed)
          GoldenTestScenario(
            name: brightness.name,
            child: goldenThemed(
              brightness: brightness,
              size: screen,
              alignment: alignment,
              child: builder(),
            ),
          ),
      ],
    ),
  );
}
