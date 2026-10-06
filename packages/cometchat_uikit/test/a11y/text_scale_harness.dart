// Harness for the 200% text-scale pass (A11Y3).
//
// WCAG 2.1 AA (1.4.4 Resize Text) requires content to stay usable at 200% text
// size. On iOS and Android that is a system setting the user controls, so it
// arrives as a `textScaler` on MediaQuery and the Kit has no say in it.
//
// There are two ways a layout fails that, and they look nothing alike:
//
//   * **Overflow** — a fixed-height row cannot grow, and Flutter paints the
//     yellow-and-black stripes and reports "RenderFlex overflowed by N pixels".
//     Loud, and the easy one to find.
//   * **Truncation** — a `Text` with `maxLines` and an ellipsis silently drops
//     the rest of the string. No error, no stripes; the user just cannot read
//     the sender's name any more. In a dense chat list this is the failure that
//     actually happens, and a harness that only watches for overflow reports a
//     clean bill of health while it is happening.
//
// This collects both, and gates on both. Truncation counts only when the scale
// *caused* it: text already clipped at 1.0x is a layout decision rather than an
// accessibility regression, so it is subtracted out and reported separately as
// `clippedAtDefaultScale` — informational, because someone should know that a
// string is unreadable for every user, but not this ticket's to fix.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

/// The scales worth checking. 2.0 is the WCAG threshold; 1.3 catches layouts
/// that break well before it, which is the more common failure.
const List<double> kTextScales = <double>[1.0, 1.3, 2.0];

/// Viewports in logical pixels. The narrow one is a small phone, where a
/// scaled layout runs out of room first.
const Map<String, Size> kViewports = <String, Size>{
  'narrow (320x568)': Size(320, 568),
  'typical (412x915)': Size(412, 915),
};

enum FindingKind {
  /// A render box could not fit its children.
  overflow,

  /// A `Text` lost content to `maxLines` that it kept at 1.0x.
  truncation,

  /// A `Text` that is already clipped with no scaling at all. Not a text-scale
  /// failure and not gated here, but worth knowing about — it means the string
  /// is unreadable for every user, not just those who scaled their type up.
  clippedAtDefaultScale,

  /// A box that already overflows with no scaling at all. Same reasoning as
  /// [clippedAtDefaultScale]: reported, not gated. Scaling did not cause it.
  overflowAtDefaultScale,
}

/// One thing wrong at increased text scale.
class Finding {
  const Finding({
    required this.kind,
    required this.surface,
    required this.viewport,
    required this.scale,
    required this.detail,
  });

  final FindingKind kind;
  final String surface;
  final String viewport;
  final double scale;

  /// Pixels overflowed, or the text that got cut off.
  final String detail;

  /// Stable identity for the known-findings allowlist. Deliberately excludes
  /// the pixel count so that a layout tweak changing the amount does not make
  /// a known finding look new.
  String get key => '${kind.name} | $surface | $viewport | ${scale}x';

  @override
  String toString() => '$key | $detail';
}

/// Wraps [child] in a Material app whose text scale is [scale].
///
/// The [MediaQuery] goes in through `MaterialApp.builder` so that it sits
/// *below* the one `WidgetsApp` installs from the view — wrapping from outside
/// would be silently overridden.
Widget wrapAtTextScale(Widget child, double scale) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: Translations.localizationsDelegates,
    supportedLocales: const <Locale>[Locale('en')],
    builder: (BuildContext context, Widget? inner) {
      return MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: inner!,
      );
    },
    home: Scaffold(body: child),
  );
}

final RegExp _overflowPixels = RegExp(r'overflowed by ([\d.]+) pixels');

String _quote(String text) =>
    '"${text.length > 60 ? '${text.substring(0, 60)}…' : text}"';

/// Every `Text` in the tree that lost content to `maxLines`, by its full string.
Set<String> _truncatedTexts(WidgetTester tester) {
  final Set<String> truncated = <String>{};
  for (final RenderObject object in tester.allRenderObjects) {
    if (object is RenderParagraph && object.didExceedMaxLines) {
      final String text = object.text.toPlainText().trim();
      if (text.isNotEmpty) truncated.add(text);
    }
  }
  return truncated;
}

/// Pumps [builder]'s widget at every viewport and scale, and returns what
/// broke.
///
/// Overflow errors are intercepted rather than thrown, so one bad surface does
/// not hide the ones after it. Any other Flutter error is passed through to the
/// normal handler and still fails the test.
Future<List<Finding>> collectFindings(
  WidgetTester tester, {
  required String surface,
  required Widget Function() builder,
}) async {
  final List<Finding> found = <Finding>[];

  for (final MapEntry<String, Size> viewport in kViewports.entries) {
    // What already fails at 1.0x, so scale-caused breakage can be told apart
    // from a layout that never fitted in the first place.
    Set<String> baselineTruncation = <String>{};
    Set<String> baselineOverflow = <String>{};

    for (final double scale in kTextScales) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = viewport.value;
      addTearDown(tester.view.reset);

      final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
      final List<String> captured = <String>[];
      FlutterError.onError = (FlutterErrorDetails details) {
        final String text = details.exceptionAsString();
        if (text.contains('overflowed')) {
          captured.add(text.split('\n').first.trim());
        } else {
          previous?.call(details);
        }
      };

      Set<String> truncated;
      try {
        await tester.pumpWidget(wrapAtTextScale(builder(), scale));
        await tester.pump(const Duration(milliseconds: 100));
        truncated = _truncatedTexts(tester);
      } finally {
        FlutterError.onError = previous;
      }

      if (scale == 1.0) {
        baselineTruncation = truncated;
        for (final String text in truncated) {
          found.add(
            Finding(
              kind: FindingKind.clippedAtDefaultScale,
              surface: surface,
              viewport: viewport.key,
              scale: scale,
              detail: _quote(text),
            ),
          );
        }
      } else {
        for (final String text in truncated.difference(baselineTruncation)) {
          found.add(
            Finding(
              kind: FindingKind.truncation,
              surface: surface,
              viewport: viewport.key,
              scale: scale,
              detail: _quote(text),
            ),
          );
        }
      }

      // Deduplicate: a repeating list reports the same overflow per item. Key
      // on the direction rather than the pixel count, so growing an existing
      // 1.0x overflow is still recognised as the same pre-existing one.
      final Map<String, String> overflows = <String, String>{};
      for (final String message in captured.toSet()) {
        final Match? match = _overflowPixels.firstMatch(message);
        final String direction = message.contains('on the bottom')
            ? 'bottom'
            : message.contains('on the right')
            ? 'right'
            : 'other';
        overflows[direction] = match == null
            ? message
            : '${match.group(1)}px — ${message.split('overflowed').last.trim()}';
      }

      if (scale == 1.0) {
        baselineOverflow = overflows.keys.toSet();
      }
      for (final MapEntry<String, String> o in overflows.entries) {
        final bool preExisting =
            scale == 1.0 || baselineOverflow.contains(o.key);
        found.add(
          Finding(
            kind: preExisting
                ? FindingKind.overflowAtDefaultScale
                : FindingKind.overflow,
            surface: surface,
            viewport: viewport.key,
            scale: scale,
            detail: o.value,
          ),
        );
      }
    }
  }

  return found;
}
