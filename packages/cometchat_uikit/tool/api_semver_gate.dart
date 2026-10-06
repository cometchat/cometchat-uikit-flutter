// Fails when dart-apitool reports a breaking change against the latest release
// that tool/api/semver_waivers.txt does not accept.
//
//   dart-apitool diff --old pub://cometchat_chat_uikit/<latest> --new ./ \
//     --version-check-mode fully --no-set-exit-on-version-check-failure \
//     --report-format json --report-file-path api-diff.json
//   dart run tool/api_semver_gate.dart api-diff.json
//
// dart-apitool's own verdict cannot be the gate on its own: it has no way to
// accept a reviewed exception, so one justified change would block every
// release. This reads its report instead and fails only on what nobody has
// signed off. See tool/api/README.md.
import 'dart:convert';
import 'dart:io';

const _waiversFile = 'tool/api/semver_waivers.txt';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/api_semver_gate.dart <report.json>');
    exit(2);
  }
  final report =
      jsonDecode(File(args.single).readAsStringSync()) as Map<String, dynamic>;
  final waivers = _readWaivers();

  final changes = <_Change>[];
  void walk(Map<String, dynamic> node, String where) {
    final code = node['changeCode'] as String?;
    if (code != null) {
      changes.add(_Change(code, node['changeDescription'] as String, where));
    }
    final label = node['label'] as String?;
    final here = code == null && label != null && label != 'BREAKING CHANGES'
        ? label
        : where;
    for (final child in (node['children'] as List?) ?? const []) {
      walk(child as Map<String, dynamic>, here);
    }
  }

  // dart-apitool omits `breakingChanges` when there is nothing to report and sets
  // `noChangesDetected` instead. This used to cast the absent key straight to a Map:
  //
  //     type 'Null' is not a subtype of type 'Map<String, dynamic>' in type cast
  //     #0  main (tool/api_semver_gate.dart:43:13)
  //
  // so the gate CRASHED, with exit 255, exactly when the API was clean — the one
  // outcome it exists to confirm. An absent key is not treated as "no changes" on its
  // own, though: that would turn a crash into a gate that silently passes everything
  // if the report schema ever changes. Only the explicit flag is trusted.
  final body = report['report'];
  if (body is! Map<String, dynamic>) {
    stderr.writeln(
      'api_semver_gate: the report has no "report" object. dart-apitool wrote:\n'
      '${const JsonEncoder.withIndent('  ').convert(report)}',
    );
    exit(2);
  }
  final noChanges = body['noChangesDetected'] == true;
  final breaking = body['breakingChanges'];
  if (breaking == null && !noChanges) {
    stderr.writeln(
      'api_semver_gate: no "breakingChanges" and no "noChangesDetected" flag — the '
      'dart-apitool report schema is not what this gate expects, so it cannot tell '
      '"clean" from "unreadable". Refusing to pass. Report keys: ${body.keys.toList()}',
    );
    exit(2);
  }
  if (breaking != null) {
    walk(breaking as Map<String, dynamic>, '');
  }

  final used = <String>{};
  final blocking = <_Change>[];
  for (final change in changes) {
    if (waivers.containsKey(change.key)) {
      used.add(change.key);
    } else {
      blocking.add(change);
    }
  }
  final stale = waivers.keys.where((k) => !used.contains(k)).toList();

  final version = report['version'] as Map<String, dynamic>? ?? const {};
  final out = StringBuffer()
    ..writeln('## API semver gate')
    ..writeln()
    ..writeln(
      'Against ${version['old']} on pub.dev: ${changes.length} breaking '
      'change(s), ${changes.length - blocking.length} waived, '
      '${blocking.length} not waived. dart-apitool alone would ask for '
      '${version['needed']}.',
    );

  // Say so when there is nothing to compare against. Once a version is published,
  // the local pubspec and pub.dev's latest are the same string and the diff is the
  // package against itself — a green gate then means "nothing was compared", not
  // "nothing broke". Without this line that reads like a pass.
  if (version['old'] != null && version['old'] == version['new']) {
    out
      ..writeln()
      ..writeln(
        '> Note: ${version['new']} is already the latest on pub.dev, so this '
        'compared the package against itself and cannot detect anything. Bump '
        '`version:` in pubspec.yaml for a meaningful comparison.',
      );
  }
  if (blocking.isNotEmpty) {
    out
      ..writeln()
      ..writeln(
        'Not waived — restore the API, deprecate instead of removing, '
        'or add a reviewed line to $_waiversFile:',
      )
      ..writeln();
    for (final c in blocking) {
      out.writeln(
        '- `${c.code}` ${c.where.isEmpty ? '' : '${c.where}: '}'
        '${c.description}',
      );
    }
  }
  // TODO(human): decide whether stale waivers should FAIL this gate.
  //
  // A waiver is stale when nothing in the report matches it. Right now all five in
  // tool/api/semver_waivers.txt are stale, because 6.2.0 reached pub.dev and the
  // changes they covered are no longer "changes" — which is exactly when that file's
  // own instruction applies: "Delete a line once the release it covers is on pub.dev".
  //
  // The case for failing: a stale waiver is a loaded gun. Its key is
  // `<code>|<exact description>`, so a future real breaking change that happens to
  // produce the same description would be waived silently by a line nobody reviewed
  // for it. Failing forces the cleanup the file asks for.
  //
  // The case against: it fails the build for something that is not a regression, and
  // it fires on every release immediately after publishing — the moment the waivers
  // for that release legitimately go stale. That is a predictable red build on a
  // cadence, which tends to get ignored or bypassed.
  //
  // Read at runtime rather than declared const, so the choice can be tried in CI
  // without editing this file — and so the analyzer does not flag the branch below
  // as dead code, which this very gate's sibling lint would block on.
  //
  //   API_SEMVER_STALE_WAIVERS_BLOCK=1 dart run tool/api_semver_gate.dart <report>
  //
  // To make blocking the default, change the comparison to != '0'.
  final staleWaiversBlock =
      Platform.environment['API_SEMVER_STALE_WAIVERS_BLOCK'] == '1';

  if (stale.isNotEmpty) {
    out
      ..writeln()
      ..writeln('Waivers that matched nothing (delete them):')
      ..writeln();
    for (final k in stale) {
      out.writeln('- `$k`');
    }
  }
  stdout.write(out);
  final summary = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (summary != null && summary.isNotEmpty) {
    File(summary).writeAsStringSync(out.toString(), mode: FileMode.append);
  }
  final failing = blocking.isNotEmpty || (staleWaiversBlock && stale.isNotEmpty);
  exit(failing ? 1 : 0);
}

/// Waiver key → reason. A key is `<code>|<description>`.
Map<String, String> _readWaivers() {
  final waivers = <String, String>{};
  for (final raw in File(_waiversFile).readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split('|');
    if (parts.length < 3 || parts[2].trim().isEmpty) {
      stderr.writeln(
        '$_waiversFile: every waiver needs a code, a description '
        'and a reason: $line',
      );
      exit(2);
    }
    waivers['${parts[0].trim()}|${parts[1].trim()}'] = parts
        .sublist(2)
        .join('|');
  }
  return waivers;
}

class _Change {
  _Change(this.code, this.description, this.where);

  final String code;
  final String description;
  final String where;

  String get key => '$code|$description';
}
