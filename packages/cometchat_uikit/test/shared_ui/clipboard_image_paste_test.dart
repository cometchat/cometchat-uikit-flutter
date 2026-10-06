import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cometchat_chat_uikit/shared_ui/src/clean_architecture/core/utils/platform_utils/platform_file_utils.dart';

/// Contract test for the clipboard-image bridge: [readClipboardImage] invokes
/// `getClipboardImage` on the `cometchat_chat_uikit` channel and maps the
/// native `{bytes, mimeType}` payload into a [ClipboardImage] (or null).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('cometchat_chat_uikit');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('maps a native image payload into ClipboardImage', () async {
    final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]); // PNG magic
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getClipboardImage') {
        return <String, dynamic>{'bytes': bytes, 'mimeType': 'image/png'};
      }
      return null;
    });

    final img = await readClipboardImage();
    expect(img, isNotNull);
    expect(img!.mimeType, 'image/png');
    expect(img.bytes, bytes);
  });

  test('returns null when the clipboard holds no image', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(await readClipboardImage(), isNull);
  });

  test('returns null on empty bytes', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return <String, dynamic>{'bytes': Uint8List(0), 'mimeType': 'image/png'};
    });
    expect(await readClipboardImage(), isNull);
  });

  test('defaults mimeType to image/png when the platform omits it', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return <String, dynamic>{
        'bytes': Uint8List.fromList([1, 2, 3]),
      };
    });
    final img = await readClipboardImage();
    expect(img, isNotNull);
    expect(img!.mimeType, 'image/png');
  });

  test('swallows a platform exception and returns null', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'ERR');
    });
    expect(await readClipboardImage(), isNull);
  });
}
