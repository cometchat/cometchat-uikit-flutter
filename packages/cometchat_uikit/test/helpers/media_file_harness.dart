/// Real local media files for the attachment bubbles and the composer tray.
///
/// The image bubble, the image viewer and the attachment tile all branch on
/// `File(path).existsSync()` before they decide between a local image, a
/// network image and a placeholder. Faking that would fake away the branch, so
/// these tests write real bytes into a per-test temporary directory instead.
///
/// The picture is an uncompressed 32-bit BMP for the same reason
/// `golden_message_harness.dart` uses one: no zlib or CRC to get right, and
/// Flutter's codec decodes it like any other image.
library;

import 'dart:io';
import 'dart:typed_data';

/// A temp directory that is removed when the test ends.
///
/// Call from `setUp`; pair with [disposeMediaTempDir] in `tearDown`.
Directory createMediaTempDir() =>
    Directory.systemTemp.createTempSync('cc_media_test');

/// Removes [dir] and everything under it, ignoring a directory that a test
/// already cleaned up itself.
void disposeMediaTempDir(Directory dir) {
  if (dir.existsSync()) dir.deleteSync(recursive: true);
}

/// Writes a decodable [width]×[height] picture at `<dir>/<name>` and returns
/// its path.
String writeImageFile(
  Directory dir,
  String name, {
  int width = 8,
  int height = 6,
  int rgb = 0x3A7BD5,
}) {
  final file = File('${dir.path}/$name')
    ..writeAsBytesSync(solidBmp(width: width, height: height, rgb: rgb));
  return file.path;
}

/// Writes [bytes] at `<dir>/<name>` and returns its path — for the cases that
/// only need the file to exist (a video, an audio clip, a document).
String writeRawFile(Directory dir, String name, List<int> bytes) {
  final file = File('${dir.path}/$name')..writeAsBytesSync(bytes);
  return file.path;
}

/// An uncompressed 32-bit BMP filled with [rgb].
Uint8List solidBmp({int width = 8, int height = 6, int rgb = 0x3A7BD5}) {
  const headerSize = 54;
  final pixelBytes = width * height * 4;
  final data = ByteData(headerSize + pixelBytes)
    ..setUint8(0, 0x42) // 'B'
    ..setUint8(1, 0x4D) // 'M'
    ..setUint32(2, headerSize + pixelBytes, Endian.little)
    ..setUint32(10, headerSize, Endian.little)
    ..setUint32(14, 40, Endian.little) // BITMAPINFOHEADER
    ..setInt32(18, width, Endian.little)
    ..setInt32(22, height, Endian.little)
    ..setUint16(26, 1, Endian.little)
    ..setUint16(28, 32, Endian.little)
    ..setUint32(34, pixelBytes, Endian.little)
    ..setInt32(38, 2835, Endian.little)
    ..setInt32(42, 2835, Endian.little);
  for (var i = 0; i < width * height; i++) {
    final o = headerSize + i * 4;
    data
      ..setUint8(o, rgb & 0xFF)
      ..setUint8(o + 1, (rgb >> 8) & 0xFF)
      ..setUint8(o + 2, (rgb >> 16) & 0xFF)
      ..setUint8(o + 3, 0xFF);
  }
  return data.buffer.asUint8List();
}
