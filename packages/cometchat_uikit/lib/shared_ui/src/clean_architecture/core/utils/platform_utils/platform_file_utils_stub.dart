/// Stub implementation — should never be reached at runtime.
/// Exists only to satisfy the conditional import contract.
library;

import 'package:video_player/video_player.dart';

import 'clipboard_image.dart';
import 'web_picked_file.dart';

/// Web-only file dialog. Stub → empty (native uses the platform channel).
Future<List<WebPickedFile>> pickFilesWeb({
  required String accept,
  required bool multiple,
}) async => const [];

/// Reads an image off the system clipboard. Stub → null.
Future<ClipboardImage?> readClipboardImage() async => null;

bool isLocalFileAvailable(String path) => false;

bool platformIsIOS() => false;

bool platformIsAndroid() => false;

Future<String?> downloadFileToLocal(String fileUrl, String fileName) async {
  return null;
}

Future<String?> getDownloadedFilePath(
  String fileName, {
  String? fileUrl,
}) async {
  return null;
}

/// No-op on unsupported platforms — the "Save as" picker is native-only (web
/// call sites use the browser download instead).
Future<bool> saveFileWithPicker(
  String url,
  String fileName,
  String mimeType, {
  String? localPath,
}) async => false;

bool fileExistsSync(String path) => false;

Future<String?> writeBytesToTempFile(List<int> bytes, String fileName) async {
  return null;
}

/// Probes a local media file for its playback duration. Stub → null.
Future<Duration?> probeMediaDuration(String path) async => null;

/// Size in bytes of a local file. Stub → 0.
/// Object URLs are a web concept — no preview URL can be built from bytes here.
String? objectUrlFromBytes(List<int> bytes, String mimeType) => null;

/// No-op off web ([objectUrlFromBytes] never returns a URL here).
void revokeObjectUrl(String url) {}

int fileSizeOf(String path) => 0;

/// Local-file video controller. Stub → null.
VideoPlayerController? videoControllerForPath(String path) => null;
