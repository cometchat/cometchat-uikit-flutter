// The analyzer gate package-checks runs (ENG-38687 CI1, ENG-38688 LINT1).
//
//   dart tool/analyze_gate.dart           fail on any diagnostic in lib/ or test/,
//                                         except backlog rules, whose counts may
//                                         only fall
//   dart tool/analyze_gate.dart --update  lower tool/lint_backlog.json to today's
//                                         counts, and drop rules that reached zero
//
// test/ is gated too (ENG-38688). It was not, and five analyzer warnings —
// an @override on a non-overriding getter, three ?. on non-nullable receivers
// and an unused local — reached review in the new prop tests because of it.
// The unused local was the one that mattered: it collected the colours a
// widget tree actually painted and never asserted on them, so a "render
// verified" test would have passed with no render at all.
//
// The two scopes carry separate backlogs and are counted separately, so a
// burn-down in one cannot pay for a regression in the other.
//
// The backlog counts are calibrated to the toolchain package-checks pins
// (FLUTTER_VERSION, tracking pub.dev), NOT to the package's declared floor.
// They differ: on Dart 3.10.x, `dart analyze` reports
// deprecated_member_use_from_same_package for uses inside the deprecated
// declaration itself — 29 in lib/ and 11 in test/ — and Dart 3.11+ reports
// none of them. So running this gate on Flutter 3.38.9 shows ~40 blocking
// infos that CI never sees. That is the floor being noisier than CI, not a
// regression; check against the pinned toolchain before acting on it.
//
// Why not plain `dart analyze --fatal-infos`. LINT1 turns on
// public_member_api_docs and avoid_dynamic_calls, which between them had over
// 4,500 findings on a 185k-line package when they were enabled. Neither can be
// cleared in one change, and a fatal gate would either stay red or force the
// rules back off. So each backlog rule has a committed count that may never
// rise: new code must comply, old code burns down, and a rule whose count
// reaches zero leaves the backlog and is fatal like everything else (the
// promotion LINT3 asks for). Every other diagnostic, info included, fails.
//
// pana never sees these rules. It passes a package's `linter: rules:` through
// only when they are written as a map (`rule: true`); ours is a list. See
// analysis_options.yaml.

import 'dart:convert';
import 'dart:io';

const _backlogPath = 'tool/lint_backlog.json';

/// Analysed independently, each against its own backlog.
const _scopes = ['lib/', 'test/'];

void main(List<String> args) {
  final update = args.contains('--update');
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Run this from the chat_uikit package root.');
    exit(2);
  }

  final backlog = _readBacklog();
  final countsByScope = <String, Map<String, int>>{};
  final blocking = <String>[];
  var failed = false;

  for (final scope in _scopes) {
    final result = Process.runSync('dart', [
      'analyze',
      '--format=machine',
      scope,
    ]);
    final lines = const LineSplitter().convert('${result.stdout}');
    final scopeBacklog = backlog[scope]!;
    final counts = {for (final rule in scopeBacklog.keys) rule: 0};
    var parsed = 0;
    for (final line in lines) {
      final p = line.split('|');
      if (p.length < 8) continue;
      parsed++;
      final severity = p[0];
      final code = p[2].toLowerCase();
      if (severity == 'INFO' && scopeBacklog.containsKey(code)) {
        counts[code] = counts[code]! + 1;
        continue;
      }
      final file = p[3].replaceFirst('${Directory.current.path}/', '');
      blocking.add(
        '${severity.toLowerCase()} • $file:${p[4]}:${p[5]} • '
        '${p.sublist(7).join('|')} • $code',
      );
    }

    // `dart analyze` exits non-zero whenever it reports anything, so its exit
    // code alone means nothing here — but it producing no diagnostics while
    // failing does.
    if (parsed == 0 && result.exitCode != 0) {
      stderr
        ..writeln(
          'dart analyze failed on $scope without reporting diagnostics:',
        )
        ..writeln(result.stderr);
      exit(2);
    }
    countsByScope[scope] = counts;
  }

  for (final scope in _scopes) {
    final scopeBacklog = backlog[scope]!;
    final counts = countsByScope[scope]!;
    stdout.writeln('Backlog rules in $scope (may only fall):');
    if (scopeBacklog.isEmpty) {
      stdout.writeln('  (none — every diagnostic here is fatal)');
      continue;
    }
    for (final rule in scopeBacklog.keys) {
      final now = counts[rule]!;
      final allowed = scopeBacklog[rule]!;
      final String verdict;
      if (now > allowed) {
        failed = true;
        verdict = 'ABOVE the backlog of $allowed — new code must comply';
      } else if (now < allowed) {
        verdict = 'below the backlog of $allowed — lower it with --update';
      } else {
        verdict = 'at the backlog';
      }
      stdout.writeln(
        '  ${rule.padRight(40)} ${now.toString().padLeft(5)}  $verdict',
      );
    }
  }

  failed = failed || blocking.isNotEmpty;

  if (blocking.isNotEmpty) {
    stdout.writeln('\n${blocking.length} blocking diagnostic(s):');
    for (final b in blocking.take(50)) {
      stdout.writeln('  $b');
    }
    if (blocking.length > 50) {
      stdout.writeln('  … and ${blocking.length - 50} more');
    }
  } else {
    stdout.writeln('\nNo blocking diagnostics.');
  }

  if (update) {
    final lowered = <String, Map<String, int>>{};
    final promoted = <String>[];
    for (final scope in _scopes) {
      final scopeBacklog = backlog[scope]!;
      final counts = countsByScope[scope]!;
      lowered[scope] = {
        for (final rule in scopeBacklog.keys)
          if (counts[rule]! > 0)
            rule: counts[rule]! < scopeBacklog[rule]!
                ? counts[rule]!
                : scopeBacklog[rule]!,
      };
      promoted.addAll(
        scopeBacklog.keys
            .where((r) => !lowered[scope]!.containsKey(r))
            .map((r) => '$scope$r'),
      );
    }
    File(_backlogPath).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(lowered)}\n',
    );
    stdout.writeln('\nWrote $_backlogPath.');
    if (promoted.isNotEmpty) {
      stdout.writeln('Reached zero and now fatal: ${promoted.join(', ')}');
    }
  }

  exit(failed ? 1 : 0);
}

/// The backlog is keyed by scope, then by rule:
/// `{"lib/": {"avoid_dynamic_calls": 188}, "test/": {...}}`.
Map<String, Map<String, int>> _readBacklog() {
  final file = File(_backlogPath);
  if (!file.existsSync()) return {for (final s in _scopes) s: <String, int>{}};
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final scope in _scopes)
      scope: ((decoded[scope] as Map<String, dynamic>?) ?? const {}).map(
        (k, v) => MapEntry(k, v as int),
      ),
  };
}
