// Regenerates the committed public API baseline at tool/api/api_baseline.txt.
//
//   dart run tool/api_baseline.dart
//
// Requires dart_apitool on PATH:
//
//   dart pub global activate dart_apitool
//
// Why this exists rather than committing dart_apitool's own output: that file
// is ~13 MB, embeds the absolute temp path the extract ran from, and is not
// reviewable in a pull request. This script folds it down to one sorted line
// per publicly reachable API element, so a removed method shows up as a
// removed line in the diff.
//
// See tool/api/README.md for the policy the baseline enforces.

import 'dart:convert';
import 'dart:io';

const _rawExtract = 'tool/api/.dart_apitool_extract.json';
const _baselineFile = 'tool/api/api_baseline.txt';

Future<void> main(List<String> args) async {
  final keepRaw = args.contains('--keep-raw');

  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Run this from the chat_uikit package root.');
    exit(2);
  }

  await Directory('tool/api').create(recursive: true);

  stdout.writeln('Extracting the public API with dart_apitool…');
  final extract = await Process.run('dart-apitool', [
    'extract',
    '--input',
    './',
    '--output',
    _rawExtract,
  ], runInShell: true);

  if (extract.exitCode != 0) {
    stderr.writeln(extract.stdout);
    stderr.writeln(extract.stderr);
    stderr.writeln(
      'dart-apitool failed. Install it with:\n'
      '  dart pub global activate dart_apitool',
    );
    exit(extract.exitCode);
  }

  final root = jsonDecode(File(_rawExtract).readAsStringSync()) as Map;
  final api = root['packageApi'] as Map;

  final lines = <String>[];
  final entryPoints = <String, int>{};

  void countEntryPoints(dynamic eps) {
    for (final ep in (eps as List?) ?? const []) {
      entryPoints[ep as String] = (entryPoints[ep] ?? 0) + 1;
    }
  }

  for (final decl in api['interfaceDeclarations'] as List) {
    final d = decl as Map;
    final name = d['name'] as String;
    countEntryPoints(d['entryPoints']);
    lines.add(
      _line('type', name, '', _supertypes(d), _flags(d), _eps(d['entryPoints'])),
    );
    for (final e in d['executableDeclarations'] as List) {
      lines.add(_executable(e as Map, owner: name));
    }
    for (final f in d['fieldDeclarations'] as List) {
      lines.add(_field(f as Map, owner: name));
    }
  }

  for (final e in api['executableDeclarations'] as List) {
    countEntryPoints((e as Map)['entryPoints']);
    lines.add(_executable(e, owner: null));
  }
  for (final f in api['fieldDeclarations'] as List) {
    countEntryPoints((f as Map)['entryPoints']);
    lines.add(_field(f, owner: null));
  }
  for (final t in api['typeAliasDeclarations'] as List) {
    final d = t as Map;
    countEntryPoints(d['entryPoints']);
    lines.add(
      _line(
        'alias',
        d['name'] as String,
        '',
        d['aliasedTypeName'] as String? ?? '',
        _flags(d),
        _eps(d['entryPoints']),
      ),
    );
  }

  lines.sort();

  // Types used in public signatures that no entry point exports. A consumer
  // can see these in an IDE but cannot import them.
  final unreachable = <String>[];
  for (final m in (root['missingEntryPoints'] as List?) ?? const []) {
    unreachable.add((m as Map)['name'] as String);
  }
  unreachable.sort();

  final sortedEntryPoints = entryPoints.keys.toList()..sort();
  final deprecated = lines.where((l) => l.contains('[deprecated]')).length;

  final out =
      StringBuffer()
        ..writeln('# ${'=' * 76}')
        ..writeln('#  cometchat_chat_uikit — public API baseline')
        ..writeln('# ${'=' * 76}')
        ..writeln('#')
        ..writeln('#  Generated. Do not hand-edit.')
        ..writeln('#    regenerate : dart run tool/api_baseline.dart')
        ..writeln('#    review     : git diff -- $_baselineFile')
        ..writeln('#')
        ..writeln(
          '#  One line per publicly reachable API element. A line that changes or',
        )
        ..writeln(
          '#  disappears is a change to a published contract — see tool/api/README.md',
        )
        ..writeln('#  for what that obliges you to do.')
        ..writeln('#')
        ..writeln('#  package        : ${api['packageName']}')
        ..writeln('#  version        : ${api['packageVersion']}')
        ..writeln('#  dart sdk floor : ${api['minSdkVersion']}')
        ..writeln('#  api elements   : ${lines.length}')
        ..writeln('#  deprecated     : $deprecated')
        ..writeln('#  entry points   : ${sortedEntryPoints.length}')
        ..writeln('#');

  // The barrels the package means as its API — a path with no `/src/` segment.
  // Everything else is reachable only because `lib/` has no top-level `src/`
  // directory, so pub treats every file under it as importable.
  final barrels = sortedEntryPoints.where((e) => !e.contains('/src/')).toList();
  final incidental = sortedEntryPoints.length - barrels.length;

  out.writeln('# --- entry points ${'-' * 60}');
  out.writeln('#');
  out.writeln('#  Declared barrels:');
  for (final ep in barrels) {
    out.writeln('#  ${entryPoints[ep].toString().padLeft(5)}  $ep');
  }
  out.writeln('#');
  out.writeln(
    '#  …and $incidental further file-level entry points. `lib/` has no top-level',
  );
  out.writeln(
    '#  `src/` directory, so pub treats every file under it as importable and the',
  );
  out.writeln(
    '#  whole tree is public whether or not a barrel names it. Narrowing that is',
  );
  out.writeln('#  a breaking change, so it is tracked, not silently fixed.');
  out.writeln('#');

  out.writeln('# --- exported in signatures but not importable ${'-' * 31}');
  out.writeln('#');
  if (unreachable.isEmpty) {
    out.writeln('#  (none)');
  } else {
    out.writeln(
      '#  These appear in public signatures but no entry point exports them,',
    );
    out.writeln(
      '#  so a consumer can see the type but cannot name it. Each one is a bug:',
    );
    out.writeln('#  export it, or take it out of the public signature.');
    out.writeln('#');
    for (final u in unreachable) {
      out.writeln('#  $u');
    }
  }
  out.writeln('#');
  out.writeln('# ${'=' * 76}');
  out.writeln();
  out.writeAll(lines, '\n');
  out.writeln();

  File(_baselineFile).writeAsStringSync(out.toString());

  if (!keepRaw) {
    final raw = File(_rawExtract);
    if (raw.existsSync()) raw.deleteSync();
  }

  stdout.writeln('Wrote $_baselineFile');
  stdout.writeln('  ${lines.length} API elements');
  stdout.writeln('  ${sortedEntryPoints.length} entry points');
  stdout.writeln('  $deprecated deprecated');
  if (unreachable.isNotEmpty) {
    stdout.writeln('  ${unreachable.length} types not reachable from any entry point');
  }
}

String _line(
  String kind,
  String owner,
  String member,
  String detail,
  String flags,
  String eps,
) {
  final qualified = member.isEmpty ? owner : '$owner.$member';
  final buf = StringBuffer('[$kind] $qualified');
  if (detail.isNotEmpty) buf.write(' : $detail');
  if (flags.isNotEmpty) buf.write(' $flags');
  if (eps.isNotEmpty) buf.write('  @ $eps');
  return buf.toString();
}

String _executable(Map e, {required String? owner}) {
  final name = e['name'] as String;
  final type = e['type'] as String; // method | constructor | function
  final kind =
      type == 'constructor'
          ? 'ctor'
          : (owner == null ? 'func' : 'meth');
  final params = _params(e['parameters'] as List?);
  final generics = _generics(e['typeParameterNames'] as List?);
  final returns = e['returnTypeName'] as String? ?? '';
  final signature = '$name$generics($params)';
  return _line(
    kind,
    owner ?? signature,
    owner == null ? '' : signature,
    returns,
    _flags(e, isStatic: e['isStatic'] == true),
    owner == null ? _eps(e['entryPoints']) : '',
  );
}

String _field(Map f, {required String? owner}) {
  final access = [
    if (f['isReadable'] == true) 'get',
    if (f['isWriteable'] == true) 'set',
  ].join('/');
  return _line(
    'fld',
    owner ?? f['name'] as String,
    owner == null ? '' : f['name'] as String,
    f['typeName'] as String? ?? '',
    [
      if (access.isNotEmpty) '[$access]',
      _flags(f, isStatic: f['isStatic'] == true),
    ].where((s) => s.isNotEmpty).join(' '),
    owner == null ? _eps(f['entryPoints']) : '',
  );
}

String _params(List? params) {
  if (params == null || params.isEmpty) return '';
  final positional = <String>[];
  final optional = <String>[];
  final named = <String>[];
  for (final p in params) {
    final m = p as Map;
    final text =
        '${m['typeName']} ${m['name']}'
        '${m['isDeprecated'] == true ? ' @deprecated' : ''}';
    if (m['isNamed'] == true) {
      named.add(m['isRequired'] == true ? 'required $text' : text);
    } else if (m['isRequired'] == true) {
      positional.add(text);
    } else {
      optional.add(text);
    }
  }
  return [
    ...positional,
    if (optional.isNotEmpty) '[${optional.join(', ')}]',
    if (named.isNotEmpty) '{${named.join(', ')}}',
  ].join(', ');
}

String _generics(List? names) =>
    (names == null || names.isEmpty) ? '' : '<${names.join(', ')}>';

String _supertypes(Map d) {
  final supers = ((d['superTypeNames'] as List?) ?? const []).cast<String>();
  final generics = _generics(d['typeParameterNames'] as List?);
  final extendsPart = supers.isEmpty ? '' : supers.join(', ');
  return generics.isEmpty ? extendsPart : '$generics $extendsPart'.trim();
}

String _flags(Map d, {bool isStatic = false}) => [
  if (isStatic) '[static]',
  if (d['isSealed'] == true) '[sealed]',
  if (d['isExperimental'] == true) '[experimental]',
  if (d['isDeprecated'] == true) '[deprecated]',
].join(' ');

String _eps(dynamic eps) {
  final list = ((eps as List?) ?? const []).cast<String>().toList()..sort();
  return list.join(', ');
}
