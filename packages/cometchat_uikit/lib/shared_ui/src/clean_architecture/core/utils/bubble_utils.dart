import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'platform_utils/platform_file_utils.dart' as platform;

class BubbleUtils {
  static final emailRegex = RegExp(
    r'^(.*?)((mailto:)?[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z][A-Z]+)',
    caseSensitive: false,
  );
  static final urlRegex = RegExp(
    r'(?:(?:https?|ftp):\/\/)?[\w/\-?=%.]+\.[\w/\-?=%.]+',
  );

  static final phoneNumberRegex = RegExp(
    r'^(\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}',
  );

  static Future<String?> downloadFile(String fileUrl, String fileName) async {
    if (kIsWeb) {
      // On web, open the file URL in a new tab for download
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return null;
    }
    return platform.downloadFileToLocal(fileUrl, fileName);
  }

  /// Resolves an already-downloaded copy of [fileName]. Pass [fileUrl] whenever
  /// it is known: the local cache is keyed per attachment, and without the URL
  /// a shared file name resolves to whichever sender's copy landed first.
  static Future<String?> isFileDownloaded(
    String fileName, {
    String? fileUrl,
  }) async {
    if (kIsWeb) return null;
    return platform.getDownloadedFilePath(fileName, fileUrl: fileUrl);
  }
}
