/// ENG-39510: the Flutter UI Kit localizes through `Translations` and exports
/// no `CometChatLocalize`, the class every other UI Kit family (React,
/// Angular, iOS, Android) localizes through. Code written against the
/// cross-platform `CometChatLocalize` API therefore does not compile, and
/// `Translations` carries no `@Deprecated` pointer to its replacement.
///
/// Acceptance criteria (ticket):
///   * `CometChatLocalize` is exported from `cometchat_chat_uikit`.
///   * `Translations` is marked `@Deprecated` with a pointer to
///     `CometChatLocalize`, and keeps working.
///
/// A test that names `CometChatLocalize` directly would not compile today, so
/// these tests read the package's public export graph from source instead:
/// they follow every `export` directive (honouring `show`/`hide`) from the
/// public barrel and look for the declaration.
///
///   flutter test test/shared_ui/l10n/regression/eng_39510_regression_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _barrel = 'lib/cometchat_chat_uikit.dart';
const String _packagePrefix = 'package:cometchat_chat_uikit/';

/// Strips `//` and `/* */` comments, so commented-out code and doc samples
/// are not mistaken for declarations or directives.
String _stripComments(String source) {
  return source
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//[^\n]*'), '');
}

/// Resolves [uri] as written in [fromFile] to a path under `lib/`, or null
/// when it points at another package or the Dart SDK.
String? _resolve(String fromFile, String uri) {
  if (uri.startsWith(_packagePrefix)) {
    return 'lib/${uri.substring(_packagePrefix.length)}';
  }
  if (uri.contains(':')) return null;
  return File(fromFile).parent.uri.resolve(uri).toFilePath();
}

final RegExp _exportDirective = RegExp(
  r'''\bexport\s+['"]([^'"]+)['"]([^;]*);''',
);
final RegExp _partDirective = RegExp(r'''\bpart\s+['"]([^'"]+)['"]\s*;''');

Set<String> _names(String combinatorBody) => combinatorBody
    .split(',')
    .map((String n) => n.trim())
    .where((String n) => n.isNotEmpty)
    .toSet();

/// Whether [file] declares a top-level type called [name], in itself or in
/// one of its `part` files.
bool _declares(String file, String name) {
  final String source = _stripComments(File(file).readAsStringSync());
  final RegExp declaration = RegExp(
    r'^\s*(?:@\w+(?:\([^)]*\))?\s*)*'
    r'(?:(?:abstract|base|final|interface|sealed|mixin)\s+)*'
    '(?:class|mixin|enum|typedef|extension\\s+type)\\s+$name\\b',
    multiLine: true,
  );
  if (declaration.hasMatch(source)) return true;
  for (final RegExpMatch part in _partDirective.allMatches(source)) {
    final String? path = _resolve(file, part.group(1)!);
    if (path != null && File(path).existsSync() && _declares(path, name)) {
      return true;
    }
  }
  return false;
}

/// The library file under `lib/` that makes [name] reachable from [file]
/// through its export graph, or null when nothing does.
String? _exportingFile(String file, String name, [Set<String>? seen]) {
  final Set<String> visited = seen ?? <String>{};
  final String normalized = File(file).absolute.uri.normalizePath().path;
  if (!visited.add(normalized)) return null;
  if (!File(file).existsSync()) return null;
  if (_declares(file, name)) return file;

  final String source = _stripComments(File(file).readAsStringSync());
  for (final RegExpMatch export in _exportDirective.allMatches(source)) {
    final String? target = _resolve(file, export.group(1)!);
    if (target == null) continue;
    final String combinators = export.group(2)!;
    final RegExpMatch? show = RegExp(
      r'\bshow\b([^;]*?)(?:\bhide\b|$)',
    ).firstMatch(combinators);
    final RegExpMatch? hide = RegExp(
      r'\bhide\b([^;]*?)(?:\bshow\b|$)',
    ).firstMatch(combinators);
    if (show != null && !_names(show.group(1)!).contains(name)) continue;
    if (hide != null && _names(hide.group(1)!).contains(name)) continue;
    final String? found = _exportingFile(target, name, visited);
    if (found != null) return found;
  }
  return null;
}

/// The annotations and doc comments written directly above the declaration
/// of class [name] in [file].
String _headerOf(String file, String name) {
  final String source = File(file).readAsStringSync();
  final RegExpMatch? declaration = RegExp(
    r'^(?:(?:abstract|base|final|interface|sealed)\s+)*class\s+'
    '$name\\b',
    multiLine: true,
  ).firstMatch(source);
  if (declaration == null) return '';
  final String before = _stripComments(source.substring(0, declaration.start));
  final int lastStatementEnd = before.lastIndexOf(RegExp(r'[;}]'));
  return before.substring(lastStatementEnd + 1);
}

void main() {
  test('CometChatLocalize is exported from package:cometchat_chat_uikit', () {
    expect(File(_barrel).existsSync(), isTrue, reason: 'run from chat_uikit');
    expect(
      _exportingFile(_barrel, 'CometChatLocalize'),
      isNotNull,
      reason:
          'ENG-39510: no CometChatLocalize class is reachable from '
          '$_barrel, so code written against the cross-platform '
          'CometChatLocalize localization API does not compile against '
          'cometchat_chat_uikit',
    );
  });

  test('Translations is still exported and is @Deprecated with a pointer to '
      'CometChatLocalize', () {
    final String? translationsFile = _exportingFile(_barrel, 'Translations');
    expect(
      translationsFile,
      isNotNull,
      reason: 'Translations must keep working for one major after deprecation',
    );

    final String header = _headerOf(translationsFile!, 'Translations');
    final RegExpMatch? deprecated = RegExp(
      r'@Deprecated\s*\(([\s\S]*?)\)\s*$',
      multiLine: true,
    ).firstMatch(header);
    expect(
      deprecated,
      isNotNull,
      reason:
          'ENG-39510: Translations ($translationsFile) carries no '
          '@Deprecated annotation pointing integrators to CometChatLocalize',
    );
    expect(
      deprecated!.group(1),
      contains('CometChatLocalize'),
      reason:
          'ENG-39510: the @Deprecated message on Translations must name '
          'CometChatLocalize as its replacement',
    );
  });
}
