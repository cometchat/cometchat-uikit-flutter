import 'dart:io';

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:cometchat_chat_uikit/shared_ui/src/offline/offline_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => CometChat.debugSetOfflineEnabledOverride(null));

  test('isOn reflects the SDK override true/false/null', () {
    CometChat.debugSetOfflineEnabledOverride(true);
    expect(OfflineGate.isOn(), isTrue);

    CometChat.debugSetOfflineEnabledOverride(false);
    expect(OfflineGate.isOn(), isFalse);

    CometChat.debugSetOfflineEnabledOverride(null);
    expect(OfflineGate.isOn(), isFalse); // default when offline is not running
  });

  test('a throwing SDK read is treated as off', () {
    expect(OfflineGate.readSafely(() => throw StateError('boom')), isFalse);
    expect(OfflineGate.readSafely(() => true), isTrue);
  });

  test('isOfflineEnabled has exactly one call site in chat_uikit/lib and '
      'master_app/lib', () {
    final roots = [Directory('lib'), Directory('../master_app/lib')];
    final sites = <String>[];
    for (final root in roots.where((d) => d.existsSync())) {
      for (final f in root.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trimLeft();
          if (line.startsWith('//')) continue; // comments and doc comments
          if (line.contains('isOfflineEnabled')) {
            sites.add('${f.path}:${i + 1}');
          }
        }
      }
    }
    expect(sites, hasLength(1), reason: sites.join('\n'));
    expect(sites.single, contains('offline_gate.dart'));
  });
}
