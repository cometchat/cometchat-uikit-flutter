/// What the native file utilities do on a host with no `path_provider`
/// implementation — which is every desktop host, and every VM test that has
/// not installed the fake from `test/helpers/fake_path_provider.dart`.
///
/// This lives in its own file on purpose: the download root is cached in a
/// file-level variable the first time it resolves, so once any test in a suite
/// has installed a working provider the unresolved path can never be observed
/// again in that isolate.
///
///   flutter test test/shared_ui/utils/platform_file_utils_no_plugin_test.dart
library;

import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/utils/platform_utils/platform_file_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // FINDING: `_setDownloadFilePath` is written as
  //
  //     final dir = await getExternalStorageDirectory()
  //         ?? await getApplicationDocumentsDirectory();
  //
  // with a comment saying the `??` covers "a device with no external
  // storage". It does not: path_provider's `getExternalStorageDirectory`
  // throws `MissingPlatformDirectoryException` (or `UnsupportedError` off
  // Android) rather than returning null, so the documents fallback is dead
  // code and the whole function throws. Every caller catches, so downloading
  // an attachment on a desktop host silently does nothing and the file is
  // reported as "not downloaded" forever.
  //
  // Both tests below pass today and would keep passing after a fix — they
  // pin the *contract* (never throw at the caller, report nothing cached).
  // The dead `??` is named here so the gap is not mistaken for coverage.

  test('downloadFileToLocal reports failure rather than throwing', () async {
    // The root cannot be resolved, so this never reaches the network.
    expect(
      await downloadFileToLocal(
        'https://media.example.test/a/photo.png',
        'photo.png',
      ),
      isNull,
    );
  });

  test('getDownloadedFilePath answers "not downloaded"', () async {
    expect(await getDownloadedFilePath('photo.png'), isNull);
    expect(
      await getDownloadedFilePath(
        'photo.png',
        fileUrl: 'https://media.example.test/a/photo.png',
      ),
      isNull,
    );
  });

  test('the failure is repeatable — nothing is half-cached on the way', () {
    // A first failed attempt must not leave the root set to something
    // unusable, which would change the answer on the second call.
    return downloadFileToLocal('https://x/a.png', 'a.png').then((first) async {
      expect(first, isNull);
      expect(await downloadFileToLocal('https://x/a.png', 'a.png'), isNull);
      expect(await getDownloadedFilePath('a.png'), isNull);
    });
  });
}
