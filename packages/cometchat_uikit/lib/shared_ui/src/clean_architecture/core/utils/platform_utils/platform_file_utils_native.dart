import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'clipboard_image.dart';
import 'web_picked_file.dart';
import '../download_cache_key.dart';
import '../../../../logging/cometchat_log.dart';

/// Native (mobile/desktop) implementation of platform file utilities.

const MethodChannel _uikitChannel = MethodChannel('cometchat_chat_uikit');

/// Web-only file dialog. Native uses the platform `pickFile` channel instead,
/// so this returns empty.
Future<List<WebPickedFile>> pickFilesWeb({
  required String accept,
  required bool multiple,
}) async => const [];

/// Reads a file off the system clipboard via the native UIKit plugin
/// (Android `ClipboardManager` / iOS `UIPasteboard`) — image, video, audio or
/// document. Flutter's own [Clipboard] is text-only, so file paste has to go
/// through the platform channel. Returns the raw bytes + MIME type + filename,
/// or null when the clipboard holds no file.
Future<ClipboardImage?> readClipboardImage() async {
  try {
    final res = await _uikitChannel.invokeMapMethod<String, dynamic>(
      'getClipboardImage',
    );
    if (res == null) return null;
    final bytes = res['bytes'];
    if (bytes is! Uint8List || bytes.isEmpty) return null;
    final mime = res['mimeType'];
    final name = res['fileName'];
    return ClipboardImage(
      bytes,
      mime is String ? mime : 'image/png',
      name is String ? name : null,
    );
  } catch (e) {
    ccLog('readClipboardImage failed: $e');
    return null;
  }
}

bool isLocalFileAvailable(String path) {
  final decodedPath = Uri.decodeFull(path);
  return decodedPath.isNotEmpty && File(decodedPath).existsSync();
}

/// Size in bytes of a local file (0 if it can't be read). Used to recover the
/// size when a platform file picker doesn't report it (e.g. iOS document picker).
/// Object URLs are a web concept — no preview URL can be built from bytes here.
String? objectUrlFromBytes(List<int> bytes, String mimeType) => null;

/// No-op off web ([objectUrlFromBytes] never returns a URL here).
void revokeObjectUrl(String url) {}

int fileSizeOf(String path) {
  try {
    return File(Uri.decodeFull(path)).lengthSync();
  } catch (_) {
    return 0;
  }
}

/// Creates a [VideoPlayerController] for a LOCAL file path (native only — web
/// returns null since local paths don't exist there). Used by the media viewer
/// to preview staged, not-yet-uploaded files.
VideoPlayerController? videoControllerForPath(String path) {
  try {
    return VideoPlayerController.file(File(Uri.decodeFull(path)));
  } catch (_) {
    return null;
  }
}

/// Probes a local media file for its playback duration using [video_player]
/// (the same backend the audio bubble uses for native audio/video). Returns
/// null if the file can't be opened or has no measurable duration.
/// Reads the playback duration of a media [source] — a local file path OR an
/// http(s) URL — using [video_player]. Returns null if it can't be opened or
/// has no measurable duration.
Future<Duration?> probeMediaDuration(String source) async {
  VideoPlayerController? controller;
  try {
    final isUrl = source.startsWith('http://') || source.startsWith('https://');
    controller = isUrl
        ? VideoPlayerController.networkUrl(Uri.parse(source))
        : VideoPlayerController.file(File(Uri.decodeFull(source)));
    await controller.initialize();
    final d = controller.value.duration;
    return d > Duration.zero ? d : null;
  } catch (_) {
    return null;
  } finally {
    await controller?.dispose();
  }
}

bool platformIsIOS() => Platform.isIOS;

bool platformIsAndroid() => Platform.isAndroid;

String _fileDownloadPath = "";

/// Where a downloaded file is written.
///
/// * iOS — the app's **documents** directory. The temp directory used to be the
///   target, but iOS purges it whenever it likes, so "downloads" silently
///   vanished; documents persists and is exportable through the Files app when
///   the host app sets `UIFileSharingEnabled` +
///   `LSSupportsOpeningDocumentsInPlace`.
/// * Android — app-scoped external storage. This is the staging copy only: the
///   file is then published to the public Downloads collection via MediaStore
///   (see [_exportToPublicDownloads]), which is the only permission-free way to
///   reach a user-visible folder on Android 10+.
Future<void> _setDownloadFilePath() async {
  if (Platform.isIOS) {
    _fileDownloadPath = (await getApplicationDocumentsDirectory()).path;
  } else {
    // Null on a device with no external storage — fall back to documents
    // rather than throwing on the `!`.
    final dir =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    _fileDownloadPath = dir.path;
  }
}

/// The directory a given attachment's cached copy lives in — the download root
/// plus its per-attachment bucket (see [DownloadCacheKey]). Falls back to the
/// flat root when no URL is known, which is the pre-bucket layout.
String _cacheDirFor(String? fileUrl) {
  final bucket = fileUrl == null ? '' : DownloadCacheKey.bucketFor(fileUrl);
  return bucket.isEmpty ? _fileDownloadPath : "$_fileDownloadPath/$bucket";
}

Future<String?> downloadFileToLocal(String fileUrl, String fileName) async {
  File? partial;
  try {
    if (_fileDownloadPath.isEmpty) {
      await _setDownloadFilePath();
    }
    if (_fileDownloadPath.isEmpty) return null;

    final dir = Directory(_cacheDirFor(fileUrl));
    await dir.create(recursive: true);
    String filePath = "${dir.path}/$fileName";
    final request = await HttpClient().getUrl(Uri.parse(fileUrl));
    final response = await request.close();

    // Check the status BEFORE writing. Media URLs are signed and time-limited,
    // so an expired link 403s — piping regardless wrote the error body into
    // e.g. "photo.png" and reported success, leaving a corrupt file behind.
    if (response.statusCode != HttpStatus.ok) {
      ccLog('File download failed: HTTP ${response.statusCode} for $fileName');
      await response.drain<void>();
      return null;
    }

    partial = File(filePath);
    await response.pipe(partial.openWrite());
    ccLog("Download path $filePath");

    // Hand the file to the platform so it lands somewhere the user can
    // actually find it (Android: MediaStore Downloads; iOS: no-op — see
    // _setDownloadFilePath). A failure here is not fatal: the app-local copy
    // still exists and drives the "already downloaded" checks.
    final exported = await _exportToPublicDownloads(filePath, fileName);
    return exported ?? filePath;
  } catch (e) {
    ccLog("File download failed: $e");
    // Don't leave a truncated file behind — it would make the row/tile look
    // downloaded and later fail to play or open.
    try {
      if (partial != null && await partial.exists()) await partial.delete();
    } catch (_) {}
    return null;
  }
}

/// Publishes an already-downloaded file to the user-visible Downloads
/// collection via the plugin (Android MediaStore). Returns the public path when
/// the platform reports one, else null (iOS and any failure).
Future<String?> _exportToPublicDownloads(
  String filePath,
  String fileName,
) async {
  if (!Platform.isAndroid) return null;
  try {
    final saved = await _uikitChannel.invokeMethod<String>('saveToDownloads', {
      'path': filePath,
      'fileName': fileName,
    });
    return (saved != null && saved.isNotEmpty) ? saved : null;
  } catch (e) {
    ccLog('saveToDownloads failed (keeping app-local copy): $e');
    return null;
  }
}

/// Presents the OS "Save as" location picker (Android SAF
/// `ACTION_CREATE_DOCUMENT` / iOS `UIDocumentPicker` export) and writes the
/// file to the location the user chooses — the "ask where to download"
/// behaviour. The plugin downloads [url] (or copies [localPath] when a cached
/// copy already exists, avoiding a re-download) into the picked destination.
/// Returns true when the user chose a location and the write succeeded, false
/// on cancel or failure.
Future<bool> saveFileWithPicker(
  String url,
  String fileName,
  String mimeType, {
  String? localPath,
}) async {
  try {
    final saved = await _uikitChannel
        .invokeMethod<String>('saveFileWithPicker', {
          'url': url,
          'fileName': fileName,
          'mimeType': mimeType,
          if (localPath != null && localPath.isNotEmpty) 'path': localPath,
        });
    return saved != null && saved.isNotEmpty;
  } catch (e) {
    ccLog('saveFileWithPicker failed: $e');
    return false;
  }
}

/// The local path of an already-downloaded [fileName], or null.
///
/// [fileUrl] identifies *which* attachment is being asked about — without it,
/// a name like `invoice.pdf` is ambiguous across senders and this would hand
/// back somebody else's file. Always pass it when the URL is known; callers
/// that omit it fall back to the pre-bucket flat layout, which is only correct
/// when the name is already unique (the legacy bubbles prefix the message id).
///
/// Files cached before bucketing existed live at the old flat path and are not
/// returned here — they re-download once, which is the safe direction to fail.
Future<String?> getDownloadedFilePath(
  String fileName, {
  String? fileUrl,
}) async {
  try {
    if (_fileDownloadPath.isEmpty) {
      await _setDownloadFilePath();
    }
    String filePath = "${_cacheDirFor(fileUrl)}/$fileName";
    if (File(filePath).existsSync()) {
      return filePath;
    }
    return null;
  } catch (e) {
    // getExternalStorageDirectory is Android-only — desktop/test hosts land
    // here; "not downloaded yet" is the right answer everywhere it throws.
    ccLog("getDownloadedFilePath failed: $e");
    return null;
  }
}

bool fileExistsSync(String path) {
  return File(path).existsSync();
}

/// Write bytes to a temporary file and return the path.
Future<String?> writeBytesToTempFile(List<int> bytes, String fileName) async {
  try {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (e) {
    ccLog("writeBytesToTempFile failed: $e");
    return null;
  }
}
