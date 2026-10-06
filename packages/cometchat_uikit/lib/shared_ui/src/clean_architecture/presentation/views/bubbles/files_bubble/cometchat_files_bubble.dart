import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../clean_architecture.dart';
import '../../../../../logging/cometchat_log.dart';
import '../../../../core/utils/platform_utils/platform_file_utils.dart'
    as platform_file;
import '../../../../core/utils/platform_utils/web_download.dart'
    as web_download;

/// Renders a **file message** (1..N attachments) as a connected vertical stack
/// of rounded file cards — colour-coded type icon, file name, "size • TYPE"
/// meta — with a "+N more / Show less" toggle for 4+ files and the optional
/// caption below. Legacy mixed-type messages (from older clients) also render
/// here: every attachment becomes a file card.
class CometChatFilesBubble extends StatelessWidget {
  const CometChatFilesBubble({
    super.key,
    required this.message,
    required this.alignment,
    this.formatters,
    this.maxWidth = 280,
    this.style,
  });

  ///[style] customizes the file cards — see [CometChatFilesBubbleStyle].
  ///Merged over the [CometChatFilesBubbleStyle] theme extension when one is
  ///registered (widget values win).
  final CometChatFilesBubbleStyle? style;

  /// The file message whose attachments are rendered.
  final MediaMessage message;

  /// Incoming / outgoing alignment (drives card + caption colours).
  final BubbleAlignment alignment;

  /// Text formatters applied to the caption (markdown guaranteed by caller).
  final List<CometChatTextFormatter>? formatters;

  /// Upper bound on the bubble width.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final attachments = AttachmentUtils.attachmentsOf(message);
    final caption = message.caption;
    final hasCaption = caption != null && caption.trim().isNotEmpty;
    // A media message can reach us with its attachments missing while still
    // carrying a caption (the caption is parsed independently of the
    // attachments). Dropping the whole bubble there silently discarded the
    // user's text — render the caption on its own instead.
    if (attachments.isEmpty && !hasCaption) return const SizedBox.shrink();

    final resolved = CometChatThemeHelper.getTheme<CometChatFilesBubbleStyle>(
      context: context,
      defaultTheme: CometChatFilesBubbleStyle.of,
    ).merge(style);

    // 2dp inset on all sides between the bubble edge and the card stack — same
    // as every other multi-attachment bubble (images / videos / audios).
    final children = <Widget>[
      if (attachments.isNotEmpty)
        Padding(
          padding: const EdgeInsets.all(kMultiAttachmentContentInset),
          child: _FileList(
            files: attachments,
            alignment: alignment,
            style: resolved,
          ),
        ),
    ];

    if (hasCaption) {
      children.add(
        CometChatMediaCaption(
          caption: caption,
          alignment: alignment,
          formatters: formatters,
          textStyle: resolved.captionTextStyle,
        ),
      );
    }

    // Fixed width matching the media-grid bubbles (min of 72% screen and
    // [maxWidth]) so every bubble of a batch renders at the same width.
    final screenW = MediaQuery.sizeOf(context).width;
    final bubbleWidth = (screenW * 0.72) < maxWidth
        ? (screenW * 0.72)
        : maxWidth;

    return SizedBox(
      width: bubbleWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Vertical stack of file cards. With 4+ entries, shows the first 3 plus a
/// "+N more" / "Show less" toggle.
class _FileList extends StatefulWidget {
  const _FileList({required this.files, required this.alignment, this.style});

  final List<Attachment> files;
  final BubbleAlignment alignment;
  final CometChatFilesBubbleStyle? style;

  @override
  State<_FileList> createState() => _FileListState();
}

class _FileListState extends State<_FileList> {
  bool _expanded = false;

  /// Every document card is individually and fully rounded (separated by
  /// [CometChatFilesBubbleStyle.cardSpacing]), so each reads as its own tile.
  BorderRadius _cardRadius(int i, int count) {
    return BorderRadius.circular(
      widget.style?.cardBorderRadius ?? kMultiAttachmentCardRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final files = widget.files;
    final collapsible = files.length >= 4;
    final visible = (collapsible && !_expanded) ? files.sublist(0, 3) : files;
    final colors = CometChatThemeHelper.getColorPalette(context);
    final sent = widget.alignment == BubbleAlignment.right;
    // Contrast against the bubble background (white on the primary-coloured
    // outgoing bubble, dark on the neutral incoming bubble).
    final actionColor = sent
        ? Colors.white
        : (colors.textPrimary ?? Colors.black87);

    final cards = <Widget>[];
    for (var i = 0; i < visible.length; i++) {
      cards.add(
        _FileCard(
          attachment: visible[i],
          alignment: widget.alignment,
          borderRadius: _cardRadius(i, visible.length),
          style: widget.style,
          // A lone file reads as the message itself — no card tint inside the
          // bubble. The tint only earns its keep separating stacked cards.
          standalone: files.length == 1,
        ),
      );
      if (i != visible.length - 1) {
        cards.add(SizedBox(height: widget.style?.cardSpacing ?? 2));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...cards,
        if (collapsible)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: sent
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _expanded
                            ? Translations.of(context).fileListShowLess
                            : Translations.of(context).fileListShowMore
                                  .replaceAll('{count}', '${files.length - 3}'),
                        style: TextStyle(
                          color: actionColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ).merge(widget.style?.toggleTextStyle),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: actionColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A rounded file card: colour-coded type icon, file name, "size • TYPE" meta.
/// Tapping downloads (if needed) and opens the file — same mechanism as the
/// deprecated CometChatFileBubble (download util + `open_file` channel).
class _FileCard extends StatefulWidget {
  const _FileCard({
    this.style,
    required this.attachment,
    required this.alignment,
    required this.borderRadius,
    this.standalone = false,
  });

  final Attachment attachment;
  final BubbleAlignment alignment;

  /// True when this is the message's only file — the card fill goes fully
  /// transparent so the card reads as the whole message.
  final bool standalone;

  /// Per-position corner rounding so a stack of cards reads as one connected
  /// block (outer corners rounded, shared edges square).
  final BorderRadius borderRadius;
  final CometChatFilesBubbleStyle? style;

  @override
  State<_FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<_FileCard> {
  bool _busy = false;
  String? _localPath;

  Attachment get a => widget.attachment;
  bool get _sent => widget.alignment == BubbleAlignment.right;

  /// The trailing ↓ (Save as) is always available — it opens the location
  /// picker, which the user can invoke any number of times regardless of
  /// whether a copy is already cached.
  bool get _showDownload => true;

  @override
  void initState() {
    super.initState();
    _restoreDownloaded();
  }

  /// Restores an earlier download so the card hides the ↓ right away.
  Future<void> _restoreDownloaded() async {
    if (kIsWeb) return;
    final p = await platform_file.getDownloadedFilePath(
      a.fileName,
      fileUrl: a.fileUrl,
    );
    if (p == null || !mounted) return;
    setState(() => _localPath = p);
  }

  /// Trailing ↓: fetch the file without opening it. Web hands the URL to the
  /// browser's downloader; native caches it locally (spinner in the icon box).
  Future<void> _onDownloadTap() async {
    if (_busy) return;
    final url = a.fileUrl;
    if (url.isEmpty) return;
    if (kIsWeb) {
      web_download.triggerBrowserDownload(url, a.fileName);
      return;
    }
    setState(() => _busy = true);
    try {
      // Native: open the system "Save as" location picker so the user chooses
      // where the file lands (reusing the cached copy when one exists).
      await platform_file.saveFileWithPicker(
        url,
        a.fileName,
        a.fileMimeType,
        localPath: _localPath,
      );
    } catch (e) {
      ccLog('[files bubble] download failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _ext() {
    final n = a.fileName;
    final e = n.contains('.') ? n.split('.').last : a.fileExtension;
    return e.toLowerCase();
  }

  String _fmtSize(int b) {
    if (b >= 1 << 20) return '${(b / (1 << 20)).toStringAsFixed(1)} MB';
    if (b >= 1 << 10) return '${(b / (1 << 10)).round()} KB';
    return '$b B';
  }

  Future<void> _openTap() async {
    if (_busy) return;
    final url = a.fileUrl;
    if (url.isEmpty) return;
    if (kIsWeb) {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    setState(() => _busy = true);
    try {
      // Resolve a REAL, openable app-local path. `downloadFile` returns the
      // MediaStore "Downloads/<name>" display string on Android (not openable),
      // so after downloading we read back the actual cached path — otherwise
      // open_file fails until the row is rebuilt and _restoreDownloaded runs.
      var path = _localPath;
      if (path == null || !platform_file.fileExistsSync(path)) {
        await BubbleUtils.downloadFile(url, a.fileName);
        path = await platform_file.getDownloadedFilePath(
          a.fileName,
          fileUrl: a.fileUrl,
        );
        _localPath = path;
      }
      if (path != null) {
        const channel = MethodChannel('cometchat_chat_uikit');
        await channel.invokeMethod('open_file', {
          'file_path': path,
          'file_type': a.fileMimeType,
        });
      }
    } catch (e) {
      ccLog('[files bubble] open failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = CometChatThemeHelper.getColorPalette(context);
    final typography = CometChatThemeHelper.getTypography(context);

    final cardBg =
        widget.style?.backgroundColor ??
        (widget.standalone
            ? Colors.transparent
            : _sent
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.black.withValues(alpha: 0.04));
    final nameColor = _sent
        ? Colors.white
        : (colors.neutral900 ?? Colors.black);
    final metaColor = _sent
        ? Colors.white.withValues(alpha: 0.6)
        : (colors.textSecondary ?? Colors.black54);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openTap,
        borderRadius: widget.borderRadius,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: widget.borderRadius,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: widget.style?.iconPlateColor != null
                    ? BoxDecoration(
                        color: widget.style!.iconPlateColor,
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: Center(
                  child: _busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.style?.downloadIconTint ?? nameColor,
                            ),
                          ),
                        )
                      : attachmentSvgIcon(
                          fileName: a.fileName,
                          extension: _ext(),
                          mimeType: a.fileMimeType,
                          size: 34,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.fileName,
                      maxLines: scaledMaxLines(context),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: nameColor,
                        fontFamily: typography.body?.regular?.fontFamily,
                      ).merge(widget.style?.titleTextStyle),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_fmtSize(a.fileSize ?? 0)} • ${_ext().toUpperCase()}',
                      maxLines: scaledMaxLines(context),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: metaColor,
                      ).merge(widget.style?.subtitleTextStyle),
                    ),
                  ],
                ),
              ),
              // Download-only affordance while the file isn't on the device
              // (reference design) — card tap still downloads-and-opens.
              if (_showDownload && !_busy) ...[
                const SizedBox(width: 6),
                Semantics(
                  button: true,
                  label: Translations.of(context).download,
                  child: GestureDetector(
                    onTap: _onDownloadTap,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      // The UIKit's own download glyph — same asset the legacy
                      // file bubble ships (reference design).
                      child: Image.asset(
                        AssetConstants.download,
                        excludeFromSemantics: true,
                        height: 22,
                        width: 22,
                        package: UIConstants.packageName,
                        color:
                            widget.style?.downloadIconTint ??
                            (_sent
                                ? Colors.white
                                : (colors.primary ?? Colors.blue)),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
