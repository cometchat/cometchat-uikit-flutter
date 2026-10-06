// Generates integration_test/e2e_coverage_map.csv from the suite sources
// (ENG-38688).
//
//   dart run tool/e2e_coverage_map.dart          write the CSV
//   dart run tool/e2e_coverage_map.dart --check  fail if the CSV is stale
//
// The README has always called the CSV "the authoritative map", but it was
// never committed, so the authority was a file nobody had. Deriving it from
// the sources instead of hand-maintaining it means it cannot drift: a new
// `testWidgets('E2E-078: …')` shows up in the next run, and --check fails the
// build if someone adds one without regenerating.
//
// What each column means, and what it is derived from:
//   test_id     the ID prefix of the testWidgets description, e.g. 1TO1-001.
//               "(untagged)" when a test carries no ID.
//   sheet_tab   the ID scheme the README documents in §8 — one of
//               one_to_one, realtime, e2e, group. Derived from the prefix.
//   status      whether the test runs anywhere automatically:
//                 ci        reachable from the Android aggregator or the
//                           on-device suite, so a PR runs it
//                 local     reachable only from e2e_test.dart or a run_*.sh,
//                           so it runs when somebody runs it
//   suite_file  path relative to master_app/.

import 'dart:io';

const _outPath = 'integration_test/e2e_coverage_map.csv';

/// Entry points a CI workflow actually executes. Everything else is `local`.
/// Keep in step with `.github/workflows/pr-tests.yml` (the Android aggregator)
/// and `.github/workflows/e2e-ios.yml` (the on-device suite).
const _ciEntryPoints = [
  'integration_test/all_e2e_tests.dart',
  'integration_test/device/ui_kit_device_test.dart',
];

final _testWidgets = RegExp(
  r"""testWidgets\(\s*[`'"](.+?)[`'"]""",
  dotAll: true,
);
final _testId = RegExp(r'^((?:1TO1|E2E|GRP)-\d+|RT-[A-Z]+-\d+)');
final _import = RegExp(r"""import\s+['"]([^'"]+)['"]""");

void main(List<String> args) {
  if (!Directory('integration_test').existsSync()) {
    stderr.writeln('Run this from master_app/.');
    exit(2);
  }

  final ciFiles = <String>{};
  for (final entry in _ciEntryPoints) {
    _collectReachable(entry, ciFiles);
  }

  final rows = <List<String>>[];
  final files =
      Directory('integration_test')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('_test.dart'))
          .map((f) => f.path)
          .toList()
        ..sort();

  for (final path in files) {
    final source = File(path).readAsStringSync();
    for (final match in _testWidgets.allMatches(source)) {
      final description = match.group(1)!;
      final id = _testId.firstMatch(description)?.group(1) ?? '(untagged)';
      rows.add([
        id,
        _sheetTab(id),
        ciFiles.contains(path) ? 'ci' : 'local',
        path,
      ]);
    }
  }

  rows.sort((a, b) {
    final byFile = a[3].compareTo(b[3]);
    return byFile != 0 ? byFile : a[0].compareTo(b[0]);
  });

  final csv = StringBuffer('test_id,sheet_tab,status,suite_file\n');
  for (final row in rows) {
    csv.writeln(row.map(_escape).join(','));
  }

  final ciCount = rows.where((r) => r[2] == 'ci').length;
  if (args.contains('--check')) {
    final existing = File(_outPath);
    if (!existing.existsSync()) {
      stderr.writeln(
        '$_outPath is missing. Run: dart run tool/e2e_coverage_map.dart',
      );
      exit(1);
    }
    if (existing.readAsStringSync() != csv.toString()) {
      stderr.writeln(
        '$_outPath is stale. Run: dart run tool/e2e_coverage_map.dart',
      );
      exit(1);
    }
    stdout.writeln(
      '$_outPath is current: ${rows.length} tests, $ciCount in CI.',
    );
    return;
  }

  File(_outPath).writeAsStringSync(csv.toString());
  stdout.writeln(
    'Wrote $_outPath: ${rows.length} tests across ${files.length} files, '
    '$ciCount run in CI, ${rows.length - ciCount} local-only.',
  );
}

/// Walks the import graph from [entry], so a suite counts as CI-reachable only
/// if an entry point can actually reach it. This is what makes the `status`
/// column a fact rather than an intention.
void _collectReachable(String entry, Set<String> seen) {
  if (!seen.add(entry)) return;
  final file = File(entry);
  if (!file.existsSync()) {
    seen.remove(entry);
    return;
  }
  final dir = File(entry).parent.path;
  for (final match in _import.allMatches(file.readAsStringSync())) {
    final target = match.group(1)!;
    if (target.startsWith('package:') || target.startsWith('dart:')) continue;
    _collectReachable(_normalise('$dir/$target'), seen);
  }
}

String _normalise(String path) {
  final parts = <String>[];
  for (final segment in path.split('/')) {
    if (segment == '.' || segment.isEmpty) continue;
    if (segment == '..' && parts.isNotEmpty) {
      parts.removeLast();
      continue;
    }
    parts.add(segment);
  }
  return parts.join('/');
}

String _sheetTab(String id) {
  if (id.startsWith('1TO1-')) return 'one_to_one';
  if (id.startsWith('RT-')) return 'realtime';
  if (id.startsWith('GRP-')) return 'group';
  if (id.startsWith('E2E-')) return 'e2e';
  return 'untagged';
}

String _escape(String value) => value.contains(',') || value.contains('"')
    ? '"${value.replaceAll('"', '""')}"'
    : value;
