import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;

import 'clipboard_image.dart';
import 'web_picked_file.dart';
import '../../../../logging/cometchat_log.dart';

/// Web implementation of platform file utilities.
///
/// On web there is no local filesystem access, so file operations
/// either return false/null or use alternative web-safe approaches.
/// Uses `package:web` + `dart:js_interop` (WASM-compatible).

/// Opens the browser's native file dialog and returns the chosen files as
/// in-memory [WebPickedFile]s. [accept] is an HTML `accept` string
/// (e.g. `image/*`, `audio/*`, `image/*,video/*`, or `''` for any); [multiple]
/// enables multi-select. Resolves to an empty list if the dialog is dismissed.
///
/// This replaces image_picker on web (which only opens `accept="image/*"`,
/// single-select) so documents/audio and multi-select actually work — using a
/// plain `<input type="file">`, no extra package.
Future<List<WebPickedFile>> pickFilesWeb({
  required String accept,
  required bool multiple,
}) {
  final completer = Completer<List<WebPickedFile>>();
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = accept
    ..multiple = multiple;

  void complete(List<WebPickedFile> files) {
    if (!completer.isCompleted) completer.complete(files);
  }

  input.addEventListener(
    'change',
    (web.Event _) {
      final list = input.files;
      if (list == null || list.length == 0) {
        complete(const []);
        return;
      }
      final files = <web.File>[];
      for (var i = 0; i < list.length; i++) {
        final f = list.item(i);
        if (f != null) files.add(f);
      }
      Future.wait(files.map(_readWebFile)).then((results) {
        complete(results.whereType<WebPickedFile>().toList());
      });
    }.toJS,
  );

  // A dismissed dialog fires no 'change' event. When focus returns to the
  // window, give any pending 'change' a moment to win, then resolve empty so
  // the awaiting picker call doesn't hang forever.
  late final web.EventListener onFocus;
  onFocus = (web.Event _) {
    web.window.removeEventListener('focus', onFocus);
    Timer(const Duration(milliseconds: 400), () => complete(const []));
  }.toJS;
  web.window.addEventListener('focus', onFocus);

  input.click();
  return completer.future;
}

Future<WebPickedFile?> _readWebFile(web.File file) {
  final completer = Completer<WebPickedFile?>();
  final reader = web.FileReader();
  reader.addEventListener(
    'loadend',
    (web.Event _) {
      final result = reader.result;
      if (result != null && result.isA<JSArrayBuffer>()) {
        final bytes = (result as JSArrayBuffer).toDart.asUint8List();
        completer.complete(
          WebPickedFile(
            name: file.name,
            bytes: bytes,
            size: bytes.length,
            mimeType: file.type,
          ),
        );
      } else {
        completer.complete(null);
      }
    }.toJS,
  );
  reader.addEventListener(
    'error',
    (web.Event _) {
      completer.complete(null);
    }.toJS,
  );
  reader.readAsArrayBuffer(file);
  return completer.future;
}

/// Reads an image off the system clipboard. Web paste is handled separately
/// (browser clipboard API) in a later phase — returns null here for now so the
/// composer falls back to text paste.
Future<ClipboardImage?> readClipboardImage() async => null;

bool isLocalFileAvailable(String path) => false;

/// Reads the playback duration of a media [source] (an http(s) or `blob:` URL)
/// via a hidden HTML5 `<video>` element and its `loadedmetadata` event. A plain
/// video element reads cross-origin metadata without the CORS requirement
/// `video_player`'s web plugin imposes. Returns null on error/timeout.
Future<Duration?> probeMediaDuration(String source) async {
  if (source.isEmpty) return null;
  final completer = Completer<Duration?>();
  final video = web.document.createElement('video') as web.HTMLVideoElement
    ..preload = 'metadata'
    ..muted = true
    ..src = source;
  late final web.EventListener onMeta;
  late final web.EventListener onError;
  Timer? timeout;
  void finish(Duration? d) {
    if (completer.isCompleted) return;
    video.removeEventListener('loadedmetadata', onMeta);
    video.removeEventListener('error', onError);
    timeout?.cancel();
    video.removeAttribute('src');
    completer.complete(d);
  }

  onMeta = (web.Event _) {
    final secs = video.duration;
    finish(
      secs.isFinite && secs > 0
          ? Duration(milliseconds: (secs * 1000).round())
          : null,
    );
  }.toJS;
  onError = (web.Event _) {
    finish(null);
  }.toJS;
  video.addEventListener('loadedmetadata', onMeta);
  video.addEventListener('error', onError);
  timeout = Timer(const Duration(seconds: 8), () => finish(null));
  return completer.future;
}

/// Wraps in-memory [bytes] in a browser object URL (`blob:…`) so bytes-staged
/// web files (picker / paste / drop) get an instant local preview and playback
/// source before the upload finishes — web's equivalent of a local file path.
/// Callers own the URL and should [revokeObjectUrl] it when the tile goes away.
String? objectUrlFromBytes(List<int> bytes, String mimeType) {
  try {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final blob = web.Blob(
      [data.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    return web.URL.createObjectURL(blob);
  } catch (_) {
    return null;
  }
}

/// Releases an object URL created by [objectUrlFromBytes]; no-op otherwise.
void revokeObjectUrl(String url) {
  if (!url.startsWith('blob:')) return;
  try {
    web.URL.revokeObjectURL(url);
  } catch (_) {}
}

/// On web the size comes from the bytes, not a path. Returns 0.
int fileSizeOf(String path) => 0;

bool platformIsIOS() => false;

bool platformIsAndroid() => false;

Future<String?> downloadFileToLocal(String fileUrl, String fileName) async {
  // On web, we cannot download to a local filesystem.
  // The caller should use url_launcher or an anchor download instead.
  ccLog('[Web] downloadFileToLocal not supported — use URL directly');
  return null;
}

Future<String?> getDownloadedFilePath(
  String fileName, {
  String? fileUrl,
}) async {
  // No local filesystem on web
  return null;
}

/// No-op on web — the native "Save as" picker doesn't apply. Web download call
/// sites branch on `kIsWeb` and use the browser download (`triggerBrowserDownload`)
/// instead, which is where the browser's own save prompt lives.
Future<bool> saveFileWithPicker(
  String url,
  String fileName,
  String mimeType, {
  String? localPath,
}) async => false;

bool fileExistsSync(String path) => false;

Future<String?> writeBytesToTempFile(List<int> bytes, String fileName) async {
  // Not supported on web — keyboard content insertion is already guarded
  return null;
}

/// Local paths don't exist on web (picked files are bytes). Returns null.
VideoPlayerController? videoControllerForPath(String path) => null;
