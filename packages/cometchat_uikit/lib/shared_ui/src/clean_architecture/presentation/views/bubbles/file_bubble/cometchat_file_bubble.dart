import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import "../../../../clean_architecture.dart";
import '../../../../core/utils/platform_utils/web_download.dart'
    as web_download;
import 'package:intl/intl.dart';
import '../../../../../logging/cometchat_log.dart';

///[CometChatFileBubble] creates a widget that gives file bubble
///
///used by default when the category and type of [MediaMessage] is message and [MessageTypeConstants.file] respectively
/// ```dart
///       CometChatFileBubble(
///              theme: cometChatTheme,
///              fileUrl: 'file url',
///              title: 'File bubble',
///              style: const FileBubbleStyle(borderRadius: 6),
///            );
/// ```
@Deprecated(
  'Use CometChatFilesBubble instead — the multi-attachment bubble family (enableMultipleAttachments) replaces the single-attachment media bubbles.',
)
class CometChatFileBubble extends StatefulWidget {
  /// Icon for the download button, in place of the default one. It takes
  /// [CometChatFileBubbleStyle.downloadIconTint] unless it sets its own
  /// colour.
  final Icon? downloadIcon;

  const CometChatFileBubble({
    super.key,
    this.style,
    this.title,
    this.subtitle,
    this.fileUrl,
    this.fileMimeType,
    this.id,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.alignment,
    this.fileExtension,
    this.fileSize,
    this.dateTime,
    this.metadata,
    this.colorPalette,
    this.spacing,
    this.typography,
    this.downloadIcon,
  });

  ///[title] if title passed then that title is displayed instead of file name from [MediaMessage]
  final String? title;

  ///[subtitle] subtitle to displayed below title
  final String? subtitle;

  ///[fileUrl] if message message object is not passed then file url should be passed to download the file
  final String? fileUrl;

  ///[fileMimeType] file mime type to open the file if message object is not passed
  final String? fileMimeType;

  ///[style] file bubble style
  final CometChatFileBubbleStyle? style;

  ///[id] message object id to make file name unique
  final int? id;

  ///[width] width of the image bubble
  final double? width;

  ///[height] height of the image bubble
  final double? height;

  ///[padding] padding for the image bubble
  final EdgeInsetsGeometry? padding;

  ///[margin] margin for the image bubble
  final EdgeInsetsGeometry? margin;

  ///[alignment] alignment for the file bubble
  final BubbleAlignment? alignment;

  /// The extension of the file.
  final String? fileExtension;

  /// The size of the file in bytes.
  final int? fileSize;

  /// The date and time the file was sent.
  final DateTime? dateTime;

  ///[metadata] metadata of the message object
  final Map<String, dynamic>? metadata;

  /// [colorPalette] optional pre-cached color palette to avoid expensive lookups during keyboard animation
  final CometChatColorPalette? colorPalette;

  /// [spacing] optional pre-cached spacing to avoid expensive lookups during keyboard animation
  final CometChatSpacing? spacing;

  /// [typography] optional pre-cached typography to avoid expensive lookups during keyboard animation
  final CometChatTypography? typography;

  @override
  State<CometChatFileBubble> createState() => _CometChatFileBubbleState();
}

class _CometChatFileBubbleState extends State<CometChatFileBubble> {
  String? _localPath;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  Timer? _progressTimer;

  // File extension categories
  static const _documentExtensions = [
    "doc",
    "docx",
    "md",
    "odt",
    "abw",
    "dot",
    "dotx",
  ];
  static const _spreadsheetExtensions = [
    "csv",
    "xls",
    "xlsx",
    "ods",
    "tsv",
    "xlt",
    "xltx",
    "numbers",
  ];
  static const _imageExtensions = [
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
  ];
  static const _audioExtensions = [
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
  ];
  static const _videoExtensions = [
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
  ];
  static const _pdfExtensions = ["pdf", "ps", "eps", "ai"];
  static const _zipExtensions = ["zip", "rar", "7z", "tar", "gz", "bz2", "xz"];
  static const _presentationExtensions = [
    "ppt",
    "pptx",
    "odp",
    "key",
    "pps",
    "ppsx",
  ];
  static const _textExtensions = [
    "txt",
    "wps",
    "rtf",
    "tex",
    "log",
    "json",
    "xml",
    "yaml",
    "yml",
  ];

  late CometChatFileBubbleStyle _fileBubbleStyle;
  late CometChatColorPalette _colorPalette;
  late CometChatSpacing _spacing;
  late CometChatTypography _typography;
  bool _themeInitialized = false;
  Brightness? _cachedBrightness;

  @override
  void initState() {
    super.initState();
    _checkFileExists();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only initialize theme once to avoid expensive lookups during keyboard animation
    final currentBrightness = CometChatThemeHelper.getBrightness(context);
    final brightnessChanged =
        _cachedBrightness != null && _cachedBrightness != currentBrightness;
    if (!_themeInitialized || brightnessChanged) {
      _cachedBrightness = currentBrightness;
      _fileBubbleStyle =
          CometChatThemeHelper.getTheme<CometChatFileBubbleStyle>(
            context: context,
            defaultTheme: CometChatFileBubbleStyle.of,
          ).merge(widget.style);
      // Use passed values OR fallback to lookup (for standalone usage)
      _colorPalette =
          widget.colorPalette ?? CometChatThemeHelper.getColorPalette(context);
      _spacing = widget.spacing ?? CometChatThemeHelper.getSpacing(context);
      _typography =
          widget.typography ?? CometChatThemeHelper.getTypography(context);
      _themeInitialized = true;
    }
  }

  @override
  void didUpdateWidget(CometChatFileBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update style if it changed
    if (widget.style != oldWidget.style) {
      _fileBubbleStyle =
          CometChatThemeHelper.getTheme<CometChatFileBubbleStyle>(
            context: context,
            defaultTheme: CometChatFileBubbleStyle.of,
          ).merge(widget.style);
    }
    // Update cached theme values if they changed
    if (widget.colorPalette != oldWidget.colorPalette &&
        widget.colorPalette != null) {
      _colorPalette = widget.colorPalette!;
    }
    if (widget.spacing != oldWidget.spacing && widget.spacing != null) {
      _spacing = widget.spacing!;
    }
    if (widget.typography != oldWidget.typography &&
        widget.typography != null) {
      _typography = widget.typography!;
    }
  }

  Future<void> _checkFileExists() async {
    final localPath = FileUtils.getLocalFilePath(widget.metadata) ?? '';
    final decodedPath = Uri.decodeFull(localPath);

    if (FileUtils.isLocalFileAvailable(decodedPath)) {
      setState(() => _localPath = decodedPath);
    } else {
      final fileName = _getFileName();
      final path = await BubbleUtils.isFileDownloaded(
        fileName,
        fileUrl: widget.fileUrl,
      );
      if (path != null && mounted) {
        setState(() => _localPath = path);
      }
    }
  }

  String _getFileName() {
    return widget.title ??
        'file_${widget.id ?? DateTime.now().millisecondsSinceEpoch}';
  }

  bool get _fileExists => _localPath != null && _localPath!.isNotEmpty;

  Future<void> _handleDownload({bool openAfterDownload = false}) async {
    if (widget.fileUrl == null || _isDownloading) return;

    // On web: download button triggers actual file download,
    // file tap (openAfterDownload=true) opens in new tab
    if (kIsWeb) {
      if (openAfterDownload) {
        // Open file in new tab for viewing
        unawaited(_openFile());
      } else {
        // Trigger actual browser download using HTML anchor with download attribute
        final fileName = _getFileName();
        web_download.triggerBrowserDownload(widget.fileUrl!, fileName);
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    // Animate indeterminate progress while downloading
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        // Cap at 0.9 — the last 10% completes when download finishes
        _downloadProgress = (_downloadProgress + 0.05).clamp(0.0, 0.9);
      });
    });

    try {
      final path = await BubbleUtils.downloadFile(
        widget.fileUrl!,
        _getFileName(),
      );

      _progressTimer?.cancel();

      if (path != null && mounted) {
        setState(() {
          _downloadProgress = 1.0;
          _localPath = path;
          _isDownloading = false;
        });
        if (openAfterDownload) {
          unawaited(_openFile());
        }
      } else if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
    } catch (e) {
      _progressTimer?.cancel();
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
      ccLog('Download failed: $e');
    }
  }

  Future<void> _openFile() async {
    // On web, open the file URL in a new tab for viewing
    if (kIsWeb) {
      final fileUrl = widget.fileUrl;
      if (fileUrl != null && fileUrl.isNotEmpty) {
        final uri = Uri.parse(fileUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      return;
    }

    if (_localPath == null) return;

    ccLog(
      '[FileBubble] _openFile called - localPath: $_localPath, fileMimeType: ${widget.fileMimeType}, fileExtension: ${widget.fileExtension}, title: ${widget.title}',
    );

    const channel = MethodChannel('cometchat_chat_uikit');
    try {
      final result = await channel.invokeMethod('open_file', {
        'file_path': _localPath,
        'file_type': widget.fileMimeType,
      });
      ccLog('[FileBubble] open_file result: $result');
    } catch (e) {
      ccLog('[FileBubble] Could not open file: $e');
    }
  }

  String? _getFileExtension() {
    final fileUrl = widget.fileUrl ?? '';
    if (fileUrl.isEmpty) return null;
    // Strip query string / fragment so signed URLs (e.g.
    // "report.pdf?token=...") still yield the right extension.
    final clean = fileUrl.split('?').first.split('#').first;
    final decodedUrl = Uri.decodeFull(clean);
    final fileName = decodedUrl.split('/').last;
    if (!fileName.contains('.')) return null;
    return fileName.split('.').last.toLowerCase();
  }

  String _getFileIcon() {
    final ext = widget.fileExtension ?? _getFileExtension();
    if (ext == null) return AssetConstants.fileUnknown;

    if (_documentExtensions.contains(ext)) return AssetConstants.fileDoc;
    if (_spreadsheetExtensions.contains(ext)) {
      return AssetConstants.fileSpreadsheet;
    }
    if (_imageExtensions.contains(ext)) return AssetConstants.fileImage;
    if (_audioExtensions.contains(ext)) return AssetConstants.fileAudio;
    if (_videoExtensions.contains(ext)) return AssetConstants.fileVideo;
    if (_pdfExtensions.contains(ext)) return AssetConstants.filePdf;
    if (_zipExtensions.contains(ext)) return AssetConstants.fileZip;
    if (_presentationExtensions.contains(ext)) {
      return AssetConstants.filePresentation;
    }
    if (_textExtensions.contains(ext)) return AssetConstants.fileText;

    return AssetConstants.fileUnknown;
  }

  String _formatFileSize(int size, {String unit = 'B'}) {
    if (size > 1024) {
      final nextUnit = unit == 'B'
          ? 'KB'
          : unit == 'KB'
          ? 'MB'
          : unit == 'MB'
          ? 'GB'
          : 'TB';
      if (nextUnit == 'TB' && unit == 'GB') return "$size $unit";
      return _formatFileSize(size ~/ 1024, unit: nextUnit);
    }
    return "$size $unit";
  }

  String _formatDate(DateTime? date) {
    return DateFormat('d MMM, yyyy').format(date ?? DateTime.now());
  }

  String _getDefaultSubtitle() {
    final ext = (widget.fileExtension ?? _getFileExtension() ?? "")
        .toUpperCase();
    return "${_formatDate(widget.dateTime)} • ${_formatFileSize(widget.fileSize ?? 0)} • $ext";
  }

  Color? _getTitleColor() {
    return _fileBubbleStyle.titleColor ??
        _fileBubbleStyle.titleTextStyle?.color ??
        (widget.alignment == BubbleAlignment.right
            ? _colorPalette.white
            : _colorPalette.neutral900);
  }

  Color? _getSubtitleColor() {
    return _fileBubbleStyle.subtitleColor ??
        _fileBubbleStyle.subtitleTextStyle?.color ??
        (widget.alignment == BubbleAlignment.right
            ? _colorPalette.white
            : _colorPalette.neutral600);
  }

  Color? _getDownloadIconColor() {
    return _fileBubbleStyle.downloadIconTint ??
        (widget.alignment == BubbleAlignment.right
            ? _colorPalette.white
            : _colorPalette.primary);
  }

  Widget _buildTrailingAction() {
    final showDownloadButton = !_fileExists && widget.fileUrl != null;

    if (!showDownloadButton) {
      // Reserve the same space so the bubble doesn't change size
      return const SizedBox(width: 40, height: 40);
    }

    return GestureDetector(
      onTap: _isDownloading ? null : _handleDownload,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isDownloading)
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  value: _downloadProgress,
                  backgroundColor: _colorPalette.extendedPrimary200,
                  color: _colorPalette.primary,
                  strokeWidth: 2.5,
                ),
              ),
            if (!_isDownloading && widget.downloadIcon != null)
              IconTheme.merge(
                data: IconThemeData(color: _getDownloadIconColor(), size: 24),
                child: widget.downloadIcon!,
              )
            else
              Image.asset(
                _isDownloading ? AssetConstants.close : AssetConstants.download,
                height: _isDownloading ? 15 : 24,
                width: _isDownloading ? 15 : 24,
                package: UIConstants.packageName,
                color: _getDownloadIconColor(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _fileExists
          ? _openFile
          : (widget.fileUrl != null
                ? () => _handleDownload(openAfterDownload: true)
                : null),
      child: Container(
        height: widget.height,
        width: widget.width ?? 265,
        margin: widget.margin,
        padding:
            widget.padding ??
            EdgeInsets.fromLTRB(
              _spacing.padding1 ?? 0,
              _spacing.padding2 ?? 0,
              0,
              _spacing.padding2 ?? 0,
            ),
        decoration: BoxDecoration(
          color: _fileBubbleStyle.backgroundColor ?? _colorPalette.transparent,
          border: _fileBubbleStyle.border,
          borderRadius:
              _fileBubbleStyle.borderRadius ??
              BorderRadius.circular(_spacing.radius3 ?? 0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              _getFileIcon(),
              height: 32,
              package: UIConstants.packageName,
            ),
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: _spacing.margin2 ?? 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title ?? Translations.of(context).file,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(
                                fontSize: _typography.body?.medium?.fontSize,
                                fontWeight:
                                    _typography.body?.medium?.fontWeight,
                                color: _getTitleColor(),
                              )
                              .merge(_fileBubbleStyle.titleTextStyle)
                              .copyWith(color: _getTitleColor()),
                    ),
                    Text(
                      widget.subtitle ?? _getDefaultSubtitle(),
                      style:
                          TextStyle(
                                fontSize:
                                    _typography.caption2?.regular?.fontSize,
                                fontWeight:
                                    _typography.caption2?.regular?.fontWeight,
                                color: _getSubtitleColor(),
                              )
                              .merge(_fileBubbleStyle.subtitleTextStyle)
                              .copyWith(color: _getSubtitleColor()),
                    ),
                  ],
                ),
              ),
            ),
            _buildTrailingAction(),
          ],
        ),
      ),
    );
  }
}
