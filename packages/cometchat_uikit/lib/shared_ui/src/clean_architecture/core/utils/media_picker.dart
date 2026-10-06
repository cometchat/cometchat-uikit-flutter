import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
// Android's system Photo Picker is opt-in on the Android implementation — see
// [MediaPicker._ensureAndroidPhotoPicker]. Web-safe: the package's Dart side is
// method-channel only (no dart:io), and the type check below no-ops elsewhere.
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../constants/ui_kit_constants.dart';
import 'platform_utils/platform_file_utils.dart' as platform;
import '../../../logging/cometchat_log.dart';

enum FileType { image, video, audio, any, custom }

class PickedFile {
  PickedFile({
    required this.name,
    required this.path,
    this.size,
    this.extension,
    this.fileType,
    this.bytes,
  });

  final String name;
  final String path;
  final int? size;
  final String? extension;
  final String? fileType;

  /// File bytes — populated on web where file paths aren't real filesystem paths.
  final List<int>? bytes;
}

class MediaPicker {
  static final ImagePicker _picker = ImagePicker();

  static bool _androidPhotoPickerConfigured = false;

  /// Opts the Android implementation into the system **Photo Picker**.
  ///
  /// `useAndroidPhotoPicker` defaults to `false`, which makes image_picker fall
  /// back to `ACTION_GET_CONTENT` — that opens the *Documents/Files* browser
  /// instead of the gallery, and on modern targetSdks it's the wrong affordance
  /// for picking media. The Photo Picker also needs no storage permission.
  ///
  /// Runs once; a no-op on every non-Android platform (the type check fails).
  static void _ensureAndroidPhotoPicker() {
    if (_androidPhotoPickerConfigured || kIsWeb) return;
    _androidPhotoPickerConfigured = true;
    final implementation = ImagePickerPlatform.instance;
    if (implementation is ImagePickerAndroid) {
      implementation.useAndroidPhotoPicker = true;
    }
  }

  /// Multi-select images + videos from the gallery. Each [PickedFile] carries an
  /// accurate [size] (required by the SDK's ±10% upload policy) and, on web,
  /// in-memory [bytes]. Used to stage multiple attachments into the composer tray.
  ///
  /// [limit] caps how many items the OS picker lets the user select — pass the
  /// remaining attachment slots (from the SDK's per-message max). When only one
  /// slot is left it falls back to a single-item pick, because the native
  /// multi-pickers can't express a limit of 1 (iOS requires >= 2).
  static Future<List<PickedFile>> pickMultipleMedia({int? limit}) async {
    _ensureAndroidPhotoPicker();
    final List<PickedFile> picked = [];
    try {
      final List<XFile> files;
      if (limit != null && limit <= 1) {
        final XFile? one = await _picker.pickMedia();
        files = one == null ? const [] : [one];
      } else {
        files = await _picker.pickMultipleMedia(limit: limit);
      }
      for (final f in files) {
        final name = f.name;
        final ext = name.contains('.')
            ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
            : '';
        List<int>? bytes;
        int size;
        if (kIsWeb) {
          bytes = await f.readAsBytes();
          size = bytes.length;
        } else {
          size = await f.length();
        }
        picked.add(
          PickedFile(
            name: name,
            path: f.path,
            size: size,
            extension: ext,
            fileType: _getFileType(ext),
            bytes: bytes,
          ),
        );
      }
    } catch (e, stack) {
      ccLog("Exception in pickMultipleMedia: $e");
      ccLog("$stack");
      unawaited(checkForPhotoPermission());
    }
    return picked;
  }

  static Future<PickedFile?> takePhoto() async {
    if (kIsWeb) {
      // Camera not available on web — use image picker gallery instead
      return _pickFileWeb(type: "image");
    }
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);

      if (image != null) {
        return PickedFile(name: image.name, path: image.path);
      } else {
        unawaited(checkForPhotoPermission());
        return null;
      }
    } catch (e, stack) {
      ccLog("Exception in takePhoto: $e");
      ccLog("$stack");
      unawaited(checkForPhotoPermission());
      return null;
    }
  }

  static Future<PickedFile?> pickAnyFile() async {
    if (kIsWeb) {
      return _pickFileWeb(type: "any");
    }
    return await _getFilesFromMethodChannel(type: "any");
  }

  static Future<PickedFile?> pickAudio() async {
    if (kIsWeb) {
      return _pickFileWeb(type: "audio");
    }
    return _getFilesFromMethodChannel(type: "audio");
  }

  /// Multi-select audio picker (native document picker with multi-selection).
  /// [limit] caps the selection to the remaining attachment slots.
  static Future<List<PickedFile>> pickMultipleAudio({int? limit}) =>
      _pickMultipleOfType("audio", limit: limit);

  /// Multi-select document/any-file picker. [limit] caps the selection to the
  /// remaining attachment slots.
  static Future<List<PickedFile>> pickMultipleAnyFiles({int? limit}) =>
      _pickMultipleOfType("any", limit: limit);

  /// Multi-select via the native `pickFile` channel — Android forwards the flag
  /// as EXTRA_ALLOW_MULTIPLE, iOS as allowsMultipleSelection; the platform side
  /// returns one entry per picked file. Web falls back to single-pick.
  ///
  /// [limit] is forwarded to the native side, where a platform picker that can
  /// express a max honours it (e.g. iOS PHPicker `selectionLimit`). It is NOT
  /// re-applied here: where the picker has no max (Android's document picker)
  /// the over-sized selection is returned in full so the caller can reject the
  /// whole batch with a toast, rather than silently staging the first [limit].
  static Future<List<PickedFile>> _pickMultipleOfType(
    String type, {
    int? limit,
  }) async {
    if (kIsWeb) {
      // Real multi-select via `<input type="file" multiple>` (image_picker
      // can't multi-select non-images on web). HTML file inputs have no
      // native max-selection count, so [limit] is NOT enforced here — the
      // full (possibly over-limit) selection is returned as-is. The caller
      // (the composer) rejects the whole batch with a toast when it exceeds
      // the remaining slots, rather than this silently keeping the first N.
      final picked = await platform.pickFilesWeb(
        accept: _webAccept(type),
        multiple: true,
      );
      return picked.map(_fromWebPicked).toList();
    }
    try {
      var result = await UIConstants.channel.invokeListMethod("pickFile", {
        "allowMultipleSelection": true,
        "withData": false,
        "type": type,
        "allowedExtensions": null,
        "limit": limit,
      });
      if (result == null) return const [];
      final files = <PickedFile>[];
      for (final entry in result) {
        final file = Map<String, dynamic>.from(entry);
        final String? path = file["path"];
        if (path == null || path.isEmpty) continue;
        final String name = file["name"];
        final extension = name.contains('.')
            ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
            : '';
        files.add(
          PickedFile(
            name: name,
            path: path,
            size: file["size"],
            extension: extension,
            fileType: _getFileType(extension),
          ),
        );
      }
      // The full selection is returned as-is, even when it exceeds [limit]:
      // pickers that can't express a max (Android's document picker) let the
      // user over-pick, and the caller (the composer) then rejects the WHOLE
      // batch with a toast. Silently returning the first N instead hid the
      // over-pick — the user asked for 2 documents with 1 slot free and got 1
      // staged and no explanation. Matches the web branch above.
      return files;
    } on PlatformException catch (e, stack) {
      ccLog("$stack");
    } catch (e) {
      rethrow;
    }
    return const [];
  }

  /// HTML `accept` string for a picker [type] — drives which formats the web
  /// file dialog offers.
  static String _webAccept(String type) {
    switch (type) {
      case "image":
        return "image/*";
      case "video":
        return "video/*";
      case "imagevideo":
        return "image/*,video/*";
      case "audio":
        return "audio/*";
      default:
        return ""; // any / custom / document — accept everything
    }
  }

  /// Converts a web-dialog [WebPickedFile] (bytes + metadata, no path) into the
  /// picker's [PickedFile].
  static PickedFile _fromWebPicked(platform.WebPickedFile w) {
    final ext = w.name.contains('.')
        ? w.name.substring(w.name.lastIndexOf('.') + 1).toLowerCase()
        : '';
    return PickedFile(
      name: w.name,
      path: '',
      size: w.size,
      extension: ext,
      fileType: _getFileType(ext),
      bytes: w.bytes,
    );
  }

  /// Web-safe file picker using image_picker (for images/videos) or
  /// falling back to XFile-based picking.
  static Future<PickedFile?> _pickFileWeb({String type = "any"}) async {
    try {
      // image_picker on web only opens an `accept="image/*"` dialog. For
      // anything else (audio, documents, combined, any) use a real
      // `<input type="file">` so those formats are actually selectable.
      if (type != "image" && type != "video") {
        final picked = await platform.pickFilesWeb(
          accept: _webAccept(type),
          multiple: false,
        );
        return picked.isEmpty ? null : _fromWebPicked(picked.first);
      }
      final XFile? file = type == "video"
          ? await _picker.pickVideo(source: ImageSource.gallery)
          : await _picker.pickImage(source: ImageSource.gallery);

      if (file != null) {
        final name = file.name;
        final ext = name.contains('.')
            ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
            : '';
        // On web, read the file bytes since file paths are blob URLs
        final bytes = await file.readAsBytes();
        return PickedFile(
          name: name,
          path: file.path,
          size: bytes.length,
          extension: ext,
          fileType: _getFileType(ext),
          bytes: bytes,
        );
      }
      return null;
    } catch (e) {
      ccLog("Web file pick failed: $e");
      return null;
    }
  }

  // static pickCustomFile() async {
  //   try {
  //     var result = await UIConstants.channel.invokeListMethod("pickFile",
  //         {"allowMultipleSelection": true, "withData": false, "type": "any"});
  //     print(result);
  //     if (result != null && result.first["path"] != null) {
  //       Map<String, dynamic> file = Map<String, dynamic>.from(result.first);
  //       return PickedFile(
  //         name: file["name"],
  //         path: file["path"],
  //         size: file["size"],
  //       );
  //     } else {
  //       return null;
  //     }
  //   } on PlatformException catch (e, stack) {
  //     debugPrint("$stack");
  //   } catch (e) {
  //     rethrow;
  //   }
  // }

  static Future<PickedFile?> pickImage() async {
    if (kIsWeb) {
      return _pickFileWeb(type: "image");
    }
    if (platform.platformIsAndroid()) {
      return _getFilesFromMethodChannel(type: "image");
    }
    return await _getFilesFromMethodChannel(
      type: platform.platformIsIOS() ? "image" : "custom",
      allowedExtensions: imageExtensions + videoExtensions,
    );
  }

  static Future<PickedFile?> pickVideo() async {
    if (kIsWeb) {
      return _pickFileWeb(type: "video");
    }
    if (platform.platformIsAndroid()) {
      return _getFilesFromMethodChannel(type: "video");
    }
    return await _getFilesFromMethodChannel(
      type: platform.platformIsIOS() ? "video" : "custom",
      allowedExtensions: imageExtensions + videoExtensions,
    );
  }

  static List<String> videoExtensions = [
    "mp4",
    "avi",
    "mov",
    "mkv",
    "flv",
    "wmv",
    "webm",
    "mpg",
    "mpeg",
    "3gp",
    "mts",
    "m2ts",
    "vob",
    "mxf",
    "f4v",
  ];
  static List<String> imageExtensions = [
    "jpg",
    "jpeg",
    "png",
    "gif",
    "bmp",
    "svg",
    "webp",
    "tiff",
    "psd",
    "heif",
    "heic",
    "icns",
    "eps",
  ];
  static List<String> audioExtensions = [
    "mp3",
    "wav",
    "ogg",
    "flac",
    "aac",
    "wma",
    "aiff",
    "m4a",
    "mid",
    "midi",
    "opus",
    "amr",
  ];
  static Future<PickedFile?> pickImageVideo() async {
    if (kIsWeb) {
      return _pickFileWeb(type: "imagevideo");
    }
    return await _getFilesFromMethodChannel(
      type: platform.platformIsIOS() ? "imagevideo" : "custom",
      allowedExtensions: imageExtensions + videoExtensions,
    );
  }

  static Future<PickedFile?> _getFilesFromMethodChannel({
    String type = "any",
    bool? allowMultipleSelection = false,
    bool? withData = false,
    List<String>? allowedExtensions,
  }) async {
    try {
      var result = await UIConstants.channel.invokeListMethod("pickFile", {
        "allowMultipleSelection": allowMultipleSelection,
        "withData": withData,
        "type": type,
        "allowedExtensions": allowedExtensions,
      });
      if (result != null && result.first["path"] != null) {
        Map<String, dynamic> file = Map<String, dynamic>.from(result.first);
        String name = file["name"];
        String extension = name
            .substring(name.lastIndexOf(".") + 1)
            .toLowerCase();
        String? fileType = _getFileType(extension);
        // Use the raw filesystem path as-is. Do NOT URL-encode it: dart:io File
        // and the SDK upload need the literal path, and encoding spaces/brackets
        // (e.g. "%20", "%5B") makes the file unreadable → PathNotFoundException.
        String path = file["path"];
        return PickedFile(
          name: name,
          path: path,
          size: file["size"],
          extension: extension,
          fileType: fileType,
        );
      } else {
        return null;
      }
    } on PlatformException catch (e, stack) {
      ccLog("$stack");
    } catch (e) {
      rethrow;
    }
    return null;
  }

  static String? _getFileType(String extension) {
    if (imageExtensions.contains(extension)) {
      return MessageTypeConstants.image;
    } else if (videoExtensions.contains(extension)) {
      return MessageTypeConstants.video;
    } else if (audioExtensions.contains(extension)) {
      return MessageTypeConstants.audio;
    } else {
      return null;
    }
  }

  static Future<void> checkForPhotoPermission() async {
    if (kIsWeb) return; // Browser handles permissions natively
    final bool granted = await UIConstants.channel.invokeMethod(
      "checkCameraPermission",
    );
    if (!granted) {
      ccLog("Camera permission not granted");
    }
  }
}
