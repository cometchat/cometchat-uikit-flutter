// Reports Dart files under lib/ that nothing can reach.
//
//   dart run tool/dead_code.dart            # human-readable report
//   dart run tool/dead_code.dart --json     # machine-readable
//   dart run tool/dead_code.dart --check    # exit 1 if anything is unreachable
//
// A file is reachable if the import/export/part graph reaches it from one of
// the three published entry points, or from any file under test/. Everything
// else ships to pub.dev, gets analysed and documented, and can never run.
//
// Why this exists: in September 2026 this found 239 unreachable files —
// 30,017 lines, 14.4% of the package. Most were pre-migration duplicates the
// clean-architecture move left behind, and bug fixes were still being applied
// to them: a mentions crash fix landed in an unreachable copy in July. The
// analyser cannot see this. `flutter analyze` reports zero unused-code
// warnings here, because cross-file deadness in a library is invisible to it —
// every file is a legitimate entry point as far as the analyser is concerned.
// Only an import-graph walk finds it.
//
// One subtlety this handles and hand-rolled versions get wrong. 106 files in
// this package import through a path that overshoots the package root, e.g.
// from lib/chat_ui/src/message_composer/widgets/:
//
//     import '../../../../../shared_ui/src/rich_text_formatting/...';
//
// That is five levels up from a directory four below lib/. Dart clamps the
// excess and resolves it inside lib/ anyway, so the import works. Naive path
// arithmetic lets it escape lib/, silently drops the edge, and reports
// reachable files as dead. Resolution below re-anchors at lib/ when a relative
// URI escapes it.
//
// Reachable is not the same as used. This finds what cannot possibly run; it
// does not find code that is wired up but never called. `repository_impl.dart`
// is reachable from the barrel and its repositories have no consumers at all —
// that class of dead code needs a different tool.

import 'dart:convert';
import 'dart:io';

const _entryPoints = <String>[
  'lib/cometchat_chat_uikit.dart',
  'lib/cometchat_calls_uikit.dart',
  'lib/cometchat_chat_uikit_web.dart',
];

const _packagePrefix = 'package:cometchat_chat_uikit/';

final _directive = RegExp(r'\b(?:import|export|part)\b[^;]*;', dotAll: true);
final _quoted = RegExp("""['"]([^'"]+)['"]""");
final _lineComment = RegExp(r'^\s*//.*$', multiLine: true);

void main(List<String> args) {
  final json = args.contains('--json');
  final check = args.contains('--check');

  if (!Directory('lib').existsSync()) {
    stderr.writeln('Run this from the chat_uikit package root.');
    exit(2);
  }

  final libFiles = _dartFilesUnder('lib').toSet();
  final reachable = _walk([
    ..._entryPoints.where((p) => File(p).existsSync()),
    ..._dartFilesUnder('test'),
  ]);

  final dead = libFiles.difference(reachable).toList()..sort();
  final deadLines = dead.fold<int>(0, (sum, f) => sum + _lineCount(f));
  final totalLines = libFiles.fold<int>(0, (sum, f) => sum + _lineCount(f));

  if (json) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'libFiles': libFiles.length,
        'libLines': totalLines,
        'reachable': reachable.intersection(libFiles).length,
        'unreachable': dead.length,
        'unreachableLines': deadLines,
        'files': dead,
      }),
    );
  } else {
    stdout.writeln('lib files      : ${libFiles.length} ($totalLines lines)');
    stdout.writeln(
      'reachable      : ${reachable.intersection(libFiles).length}',
    );
    stdout.writeln('unreachable    : ${dead.length} ($deadLines lines)');
    if (dead.isNotEmpty) {
      stdout.writeln('');
      for (final f in dead) {
        stdout.writeln('  $f');
      }
    }
  }

  if (check && dead.isNotEmpty) exit(1);
}

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

Set<String> _walk(Iterable<String> roots) {
  final seen = <String>{};
  final queue = <String>[];

  for (final r in roots) {
    final n = _normalize(r);
    if (File(n).existsSync() && seen.add(n)) queue.add(n);
  }

  while (queue.isNotEmpty) {
    for (final target in _dependenciesOf(queue.removeLast())) {
      if (File(target).existsSync() && seen.add(target)) queue.add(target);
    }
  }
  return seen;
}

Iterable<String> _dependenciesOf(String path) {
  String source;
  try {
    source = File(path).readAsStringSync();
  } on FileSystemException {
    return const <String>[];
  }
  // Strip line comments so commented-out imports and doc examples do not
  // resurrect files that nothing really references.
  source = source.replaceAll(_lineComment, '');

  final out = <String>[];
  for (final directive in _directive.allMatches(source)) {
    for (final uri in _quoted.allMatches(directive.group(0)!)) {
      final raw = uri.group(1)!;
      if (!raw.endsWith('.dart')) continue;
      if (raw.startsWith('dart:')) continue;

      if (raw.startsWith(_packagePrefix)) {
        out.add(_normalize('lib/${raw.substring(_packagePrefix.length)}'));
      } else if (raw.startsWith('package:')) {
        continue; // another package
      } else {
        out.add(_resolveRelative(_dirname(path), raw));
      }
    }
  }
  return out;
}

/// Resolves [uri] against [fromDir], re-anchoring at lib/ when the relative
/// path climbs above the package root. See the header for why that matters.
String _resolveRelative(String fromDir, String uri) {
  final direct = _normalize('$fromDir/$uri');
  if (File(direct).existsSync()) return direct;

  final withoutClimb = uri.replaceFirst(RegExp(r'^(?:\.\./)+'), '');
  final clamped = _normalize('lib/$withoutClimb');
  return File(clamped).existsSync() ? clamped : direct;
}

String _dirname(String path) {
  final i = path.lastIndexOf('/');
  return i < 0 ? '.' : path.substring(0, i);
}

/// Collapses '.' and '..' segments and strips any leading './'.
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

int _lineCount(String path) {
  try {
    return File(path).readAsLinesSync().length;
  } on FileSystemException {
    return 0;
  }
}
