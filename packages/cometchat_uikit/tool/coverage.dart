// Line coverage for the published package.
//
//   dart tool/coverage.dart report <lcov.info>... [--baseline <json>]
//                                                 [--check] [--update-baseline]
//
// Merges the lcov files each test step writes, line by line, prints a markdown
// summary and writes coverage/summary.json. With --baseline it shows the
// delta against the committed floor; --check exits 1 when this run is below it
// (ENG-38688 TEST2); --update-baseline rewrites the floor from this run.
//
// Excluded from the percentage (ENG-38688 TEST1): the translation tables and
// chat_ui/src/constants, which are pure data (~37k lines that would otherwise
// dominate the denominator), and generated code.
//
// What the denominator is. The VM reports every lib file that has executable
// code once any test loads it, and the suite already loads 649 of the 652
// such files. The ~150 files that never appear have no executable lines at
// all: export barrels, abstract interfaces, enums, constants. They are rightly
// absent, not silently untested. A helper test importing every lib file was
// tried; it added only three platform stubs no test loads, so it was dropped.
// Those stubs and the eight web-only implementations, which the VM cannot
// load at all, are the real gaps.

import 'dart:convert';
import 'dart:io';

const _summaryPath = 'coverage/summary.json';

const _excludedPrefixes = <String>[
  'lib/shared_ui/l10n/',
  'lib/chat_ui/src/constants/',
];
const _excludedSuffixes = <String>['.g.dart', '.freezed.dart'];

/// The component areas ENG-38688 reports line coverage for (TEST3).
const _areas = <String, List<String>>{
  'conversations': ['lib/chat_ui/src/conversations/'],
  'search': ['lib/chat_ui/src/search/'],
  'users': ['lib/chat_ui/src/users/'],
  'groups': ['lib/chat_ui/src/groups/'],
  'shared_ui/views': ['lib/shared_ui/src/views/'],
  'views/misc': [
    'lib/shared_ui/src/clean_architecture/presentation/views/misc/',
  ],
  'services, events, entities': [
    'lib/shared_ui/src/clean_architecture/services/',
    'lib/shared_ui/src/clean_architecture/domain/events/',
    'lib/shared_ui/src/clean_architecture/domain/entities/',
  ],
};

void main(List<String> args) {
  if (!Directory('lib').existsSync()) {
    stderr.writeln('Run this from the chat_uikit package root.');
    exit(2);
  }
  switch (args.isEmpty ? '' : args.first) {
    case 'report':
      exit(_report(args.skip(1).toList()));
    default:
      stderr.writeln(
        'usage: dart tool/coverage.dart report <lcov>... [--baseline <json>] '
        '[--check] [--update-baseline]',
      );
      exit(2);
  }
}

// ---------------------------------------------------------------------------
// report
// ---------------------------------------------------------------------------

int _report(List<String> args) {
  String? baselinePath;
  var check = false;
  var update = false;
  final inputs = <String>[];
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--baseline':
        baselinePath = args[++i];
      case '--check':
        check = true;
      case '--update-baseline':
        update = true;
      default:
        inputs.add(args[i]);
    }
  }
  if (inputs.isEmpty) {
    stderr.writeln('report: give at least one lcov file');
    return 2;
  }

  final hits = _mergeLcov(inputs);
  final counted = {
    for (final e in hits.entries)
      if (!_isExcluded(e.key)) e.key: e.value,
  };
  final (lh, lf) = _totals(counted.values);
  final pct = _pct(lh, lf);

  final libFiles = _dartFilesUnder('lib').where((f) => !_isExcluded(f)).toSet();
  final noData = libFiles.difference(counted.keys.toSet());

  final b = StringBuffer()
    ..writeln('### Line coverage')
    ..writeln()
    ..writeln(
      '**${pct.toStringAsFixed(2)}%** ($lh of $lf lines), excluding the '
      'translation tables, `chat_ui/src/constants` and generated code.',
    );

  Map<String, dynamic>? baseline;
  if (baselinePath != null && File(baselinePath).existsSync()) {
    baseline =
        jsonDecode(File(baselinePath).readAsStringSync())
            as Map<String, dynamic>;
    final floor = (baseline['percent'] as num).toDouble();
    final delta = pct - floor;
    b
      ..writeln()
      ..writeln(
        'Against the committed floor of ${floor.toStringAsFixed(2)}%: '
        '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)} points.',
      );
  }

  b
    ..writeln()
    ..writeln('| Area | Covered | Lines | % |')
    ..writeln('|---|---:|---:|---:|');
  for (final area in _areas.entries) {
    final inArea = counted.entries
        .where((e) => area.value.any(e.key.startsWith))
        .map((e) => e.value);
    final (alh, alf) = _totals(inArea);
    b.writeln(
      '| ${area.key} | $alh | $alf | ${_pct(alh, alf).toStringAsFixed(1)} |',
    );
  }
  if (noData.isNotEmpty) {
    b
      ..writeln()
      ..writeln(
        '${noData.length} lib files have no coverage data and are not counted: '
        'mostly files with no executable lines (export barrels, abstract '
        'interfaces, enums, constants), plus code no VM test loads (the '
        'web-only implementations and a few platform stubs).',
      );
  }
  stdout.write(b);

  Directory('coverage').createSync(recursive: true);
  File(_summaryPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'percent': double.parse(pct.toStringAsFixed(2)),
      'covered': lh,
      'lines': lf,
    }),
  );

  if (update && baselinePath != null) {
    File(baselinePath).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'percent': double.parse(pct.toStringAsFixed(2)), 'covered': lh, 'lines': lf})}\n',
    );
    stdout.writeln(
      '\nfloor updated to ${pct.toStringAsFixed(2)}% in $baselinePath',
    );
  }

  if (check && baseline != null) {
    final floor = (baseline['percent'] as num).toDouble();
    if (double.parse(pct.toStringAsFixed(2)) < floor) {
      stderr.writeln(
        '\nLine coverage fell to ${pct.toStringAsFixed(2)}%, below the floor '
        'of ${floor.toStringAsFixed(2)}% in $baselinePath.',
      );
      return 1;
    }
  }
  return 0;
}

/// file -> line -> hit count, summed across every input file.
Map<String, Map<int, int>> _mergeLcov(List<String> paths) {
  final cwd = '${Directory.current.path}/';
  final out = <String, Map<int, int>>{};
  for (final path in paths) {
    if (!File(path).existsSync()) {
      stderr.writeln('report: no such lcov file: $path');
      exit(2);
    }
    Map<int, int>? current;
    for (final line in File(path).readAsLinesSync()) {
      if (line.startsWith('SF:')) {
        var file = line.substring(3);
        if (file.startsWith(cwd)) file = file.substring(cwd.length);
        current = file.startsWith('lib/')
            ? out.putIfAbsent(file, () => {})
            : null;
      } else if (line.startsWith('DA:') && current != null) {
        final parts = line.substring(3).split(',');
        final lineNo = int.parse(parts[0]);
        current[lineNo] = (current[lineNo] ?? 0) + int.parse(parts[1]);
      } else if (line == 'end_of_record') {
        current = null;
      }
    }
  }
  return out;
}

(int, int) _totals(Iterable<Map<int, int>> files) {
  var lh = 0;
  var lf = 0;
  for (final f in files) {
    lf += f.length;
    lh += f.values.where((h) => h > 0).length;
  }
  return (lh, lf);
}

double _pct(int covered, int total) => total == 0 ? 0 : 100 * covered / total;

bool _isExcluded(String path) =>
    _excludedPrefixes.any(path.startsWith) ||
    _excludedSuffixes.any(path.endsWith);

// ---------------------------------------------------------------------------
// paths
// ---------------------------------------------------------------------------

Iterable<String> _dartFilesUnder(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return const <String>[];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path)
      .where((p) => p.endsWith('.dart'))
      .map(_normalize);
}

String _normalize(String path) {
  final segments = <String>[];
  for (final segment in path.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isNotEmpty && segments.last != '..') {
        segments.removeLast();
      } else {
        segments.add('..');
      }
    } else {
      segments.add(segment);
    }
  }
  return segments.join('/');
}
