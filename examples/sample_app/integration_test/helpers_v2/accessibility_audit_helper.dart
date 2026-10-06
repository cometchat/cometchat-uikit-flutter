import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_helper.dart';

/// One screen's accessibility findings, grouped by the check that raised them.
class AccessibilityFindings {
  AccessibilityFindings(this.screen);

  final String screen;

  /// Tappable semantics nodes with no label, value, hint or tooltip.
  final List<String> unlabelledTapTargets = [];

  /// Failure text from Flutter's own `labeledTapTargetGuideline`.
  final List<String> labelGuideline = [];

  /// Failure text from `androidTapTargetGuideline` / `iOSTapTargetGuideline`.
  final List<String> tapTargetSize = [];

  /// Layout overflows reported while the screen ran at the large text size.
  final List<String> largeTextOverflows = [];

  bool get isClean =>
      unlabelledTapTargets.isEmpty &&
      labelGuideline.isEmpty &&
      tapTargetSize.isEmpty &&
      largeTextOverflows.isEmpty;

  /// A report written to be acted on: every offender carries where it is on
  /// screen and the nearest labelled thing around it.
  String report() {
    final b = StringBuffer('Accessibility audit FAILED for "$screen".\n');
    void section(String title, List<String> items) {
      if (items.isEmpty) return;
      b.writeln('\n  ── $title (${items.length}) ──');
      for (final i in items) {
        b.writeln('   • $i');
      }
    }

    section(
      'Tappable nodes with no label / value / hint / tooltip',
      unlabelledTapTargets,
    );
    section('Flutter labeledTapTargetGuideline', labelGuideline);
    section('Flutter tap-target size guideline', tapTargetSize);
    section('Layout overflow at large text', largeTextOverflows);
    return b.toString();
  }
}

/// The Flutter counterpart of the iOS UI Kit's E2E accessibility audit: every
/// main screen is audited in the running app at the default text size AND at
/// the largest one.
///
/// Usage — navigate to the screen in the real app, then:
///
/// ```dart
/// await AccessibilityAudit.expectScreenAccessible(tester, 'Users list');
/// ```
///
/// This is deliberately NOT tolerant. It exists to surface unlabelled controls
/// and large-text overflows; softening it to make a screen pass defeats it.
/// `textContrastGuideline` is left out on purpose — it samples rendered pixels
/// and needs real fonts, which is too flaky on a device.
class AccessibilityAudit {
  AccessibilityAudit._();

  /// The largest text size audited. iOS's largest accessibility Dynamic Type
  /// size is ~3.1x, but 2.0 is the WCAG 1.4.4 bar (200%) and the scale the
  /// Kit's own 6.2.0 large-text work was verified at, so a failure here is a
  /// regression against a stated guarantee rather than a new ask.
  static const double largeTextScale = 2.0;

  /// Run every check on the screen currently showing and fail the test with
  /// the full list of offenders if any check found something.
  static Future<void> expectScreenAccessible(
    WidgetTester tester,
    String screen, {
    bool includeLargeText = true,
  }) async {
    final findings = await audit(
      tester,
      screen,
      includeLargeText: includeLargeText,
    );
    if (!findings.isClean) fail(findings.report());
  }

  /// Run every check and return the findings without failing.
  static Future<AccessibilityFindings> audit(
    WidgetTester tester,
    String screen, {
    bool includeLargeText = true,
  }) async {
    final findings = AccessibilityFindings(screen);

    final handle = tester.ensureSemantics();
    try {
      // The semantics tree is built lazily; give it frames to populate.
      await pumpFor(tester, const Duration(milliseconds: 800));

      findings.unlabelledTapTargets.addAll(_unlabelledTapTargets(tester));

      final labelled = await labeledTapTargetGuideline.evaluate(tester);
      if (!labelled.passed) {
        findings.labelGuideline.addAll(_lines(labelled.reason));
      }

      // 48x48 on Android, 44x44 on iOS — each platform's own minimum.
      final sizeGuideline = defaultTargetPlatform == TargetPlatform.iOS
          ? iOSTapTargetGuideline
          : androidTapTargetGuideline;
      final sized = await sizeGuideline.evaluate(tester);
      if (!sized.passed) {
        findings.tapTargetSize.addAll(_lines(sized.reason));
      }
    } finally {
      handle.dispose();
    }

    if (includeLargeText) {
      findings.largeTextOverflows.addAll(await largeTextOverflows(tester));
    }
    return findings;
  }

  // ─── a. every tappable node has a label ───────────────────────────────────

  /// Walks the live semantics tree and returns one line per node that a
  /// screen reader can activate but cannot name.
  ///
  /// Stricter than `labeledTapTargetGuideline` in one way and looser in
  /// another: text fields are NOT skipped (an unnamed field is a finding), and
  /// a node is accepted if ANY of label, value, hint or tooltip is set, since
  /// each of those is announced.
  static List<String> _unlabelledTapTargets(WidgetTester tester) {
    final offenders = <String>[];

    void visit(SemanticsNode node, List<String> ancestorLabels) {
      final data = node.getSemanticsData();
      final ownName = _firstNonEmpty([data.label, data.tooltip, data.value]);

      final skip =
          node.isMergedIntoParent ||
          node.isInvisible ||
          data.flagsCollection.isHidden;
      final tappable =
          data.hasAction(SemanticsAction.tap) ||
          data.hasAction(SemanticsAction.longPress);
      final named =
          data.label.trim().isNotEmpty ||
          data.value.trim().isNotEmpty ||
          data.hint.trim().isNotEmpty ||
          data.tooltip.trim().isNotEmpty;

      if (!skip && tappable && !named) {
        final actions = [
          if (data.hasAction(SemanticsAction.tap)) 'tap',
          if (data.hasAction(SemanticsAction.longPress)) 'longPress',
        ].join('+');
        final inside = _descendantLabels(node);
        offenders.add(
          'node#${node.id} [$actions] at ${_fmt(_globalRect(node))} — '
          'nearest labelled ancestor: '
          '${ancestorLabels.isEmpty ? '(none)' : '"${ancestorLabels.last}"'}'
          '${inside.isEmpty ? '' : '; labelled descendants: ${inside.take(3).map((l) => '"$l"').join(', ')}'}',
        );
      }

      final next = ownName == null
          ? ancestorLabels
          : [...ancestorLabels, ownName];
      node.visitChildren((child) {
        visit(child, next);
        return true;
      });
    }

    for (final RenderView view in tester.binding.renderViews) {
      final root = view.owner?.semanticsOwner?.rootSemanticsNode;
      if (root == null) {
        fail(
          'The semantics tree is empty — tester.ensureSemantics() did not '
          'take effect, so the audit has nothing to inspect.',
        );
      }
      visit(root, const []);
    }
    return offenders;
  }

  static List<String> _descendantLabels(SemanticsNode node) {
    final out = <String>[];
    void walk(SemanticsNode n) {
      n.visitChildren((child) {
        final label = child.getSemanticsData().label.trim();
        if (label.isNotEmpty) out.add(_oneLine(label));
        walk(child);
        return true;
      });
    }

    walk(node);
    return out;
  }

  /// The node's rect in logical screen coordinates. Each node's `transform`
  /// maps it into its parent; the root's maps logical to physical pixels, so
  /// it is left out.
  static Rect _globalRect(SemanticsNode node) {
    var matrix = Matrix4.identity();
    SemanticsNode? current = node;
    while (current != null && current.parent != null) {
      final t = current.transform;
      if (t != null) matrix = t.multiplied(matrix);
      current = current.parent;
    }
    return MatrixUtils.transformRect(matrix, node.rect);
  }

  // ─── c. large text: no layout overflow ────────────────────────────────────

  /// Re-runs the current screen at [scale] and returns every layout overflow
  /// it reported.
  ///
  /// `RenderFlex` and friends report an overflow through
  /// `FlutterError.reportError`, so the handler is swapped for the duration of
  /// the pump, anything that is not an overflow is forwarded to the binding's
  /// own handler untouched, and the handler and the text scale are both
  /// restored whatever happens.
  static Future<List<String>> largeTextOverflows(
    WidgetTester tester, {
    double scale = largeTextScale,
    Duration settle = const Duration(seconds: 3),
  }) async {
    var assertsOn = false;
    assert(() {
      assertsOn = true;
      return true;
    }());
    if (!assertsOn) {
      // Overflow is only detected and reported by debug-mode asserts. A
      // profile/release run would "pass" by being blind.
      fail(
        'Large-text overflow detection needs a debug build (asserts on); '
        'run the accessibility suite with plain `flutter test`, not '
        '--profile / --release.',
      );
    }

    final overflows = <String>[];
    final original = FlutterError.onError;
    addTearDown(() {
      FlutterError.onError = original;
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    FlutterError.onError = (FlutterErrorDetails details) {
      final summary = details.exceptionAsString();
      if (summary.contains('overflowed')) {
        overflows.add(_describeOverflow(details));
        return;
      }
      original?.call(details);
    };

    try {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await pumpFor(tester, settle);

      // Prove the override reached the app: a screen that ignores the system
      // text size would otherwise "pass" without ever being tested.
      final probe = find.byType(Navigator);
      if (probe.evaluate().isEmpty) {
        fail('No Navigator on screen to read the text scale from.');
      }
      final applied =
          MediaQuery.textScalerOf(tester.element(probe.first)).scale(10) / 10;
      if ((applied - scale).abs() > 0.01) {
        fail(
          'Asked for text scale $scale but the app is running at '
          '$applied — the override did not reach MediaQuery, so large text '
          'was not actually exercised.',
        );
      }
    } finally {
      FlutterError.onError = original;
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await pumpFor(tester, const Duration(milliseconds: 800));
    }
    return overflows;
  }

  static String _describeOverflow(FlutterErrorDetails details) {
    final lines = details.toString().split('\n');
    final keep = <String>[_oneLine(details.exceptionAsString())];
    for (var i = 0; i < lines.length; i++) {
      // "The relevant error-causing widget was:" is followed by the widget and
      // its source location — the only part that says WHICH row overflowed.
      if (lines[i].contains('error-causing widget')) {
        for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
          final l = lines[j].trim();
          if (l.isNotEmpty) keep.add(l);
        }
        break;
      }
    }
    return keep.join(' | ');
  }

  // ─── formatting ───────────────────────────────────────────────────────────

  static String? _firstNonEmpty(List<String> candidates) {
    for (final c in candidates) {
      if (c.trim().isNotEmpty) return _oneLine(c);
    }
    return null;
  }

  static List<String> _lines(String? reason) => (reason ?? '')
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  static String _oneLine(String s) {
    final flat = s.replaceAll('\n', ' ⏎ ').trim();
    return flat.length <= 80 ? flat : '${flat.substring(0, 77)}…';
  }

  static String _fmt(Rect r) =>
      'Rect(${r.left.toStringAsFixed(0)}, '
      '${r.top.toStringAsFixed(0)}, ${r.width.toStringAsFixed(0)}x'
      '${r.height.toStringAsFixed(0)})';
}
