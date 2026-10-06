import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart' as vp;

import '../../../../clean_architecture.dart';
import '../../../../../logging/cometchat_log.dart';
import '../../../../core/utils/platform_utils/platform_file_utils.dart'
    as platform_file;
import '../../../../core/utils/platform_utils/web_download.dart'
    as web_download;

/// Renders an **audio message** (1..N audio attachments, NOT voice notes) as a
/// stack of inline player rows — audio icon, play/pause, flat seek slider,
/// duration and file name (WhatsApp-style) — with the optional caption below.
///
/// Voice notes (audio messages whose `metadata['audioType'] == 'voice_note'`)
/// render via [CometChatVoiceNoteBubble] instead.
class CometChatAudiosBubble extends StatelessWidget {
  const CometChatAudiosBubble({
    super.key,
    required this.message,
    required this.alignment,
    this.formatters,
    this.maxWidth = 280,
    this.style,
  });

  /// The audio message whose attachments are rendered.
  final MediaMessage message;

  /// Incoming / outgoing alignment (drives row + caption colours).
  final BubbleAlignment alignment;

  /// Text formatters applied to the caption (markdown guaranteed by caller).
  final List<CometChatTextFormatter>? formatters;

  /// Upper bound on the bubble width.
  final double maxWidth;

  ///[style] customizes the player rows — see [CometChatAudiosBubbleStyle].
  ///Merged over the [CometChatAudiosBubbleStyle] theme extension when one is
  ///registered (widget values win).
  final CometChatAudiosBubbleStyle? style;

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

    final resolved = CometChatThemeHelper.getTheme<CometChatAudiosBubbleStyle>(
      context: context,
      defaultTheme: CometChatAudiosBubbleStyle.of,
    ).merge(style);
    final rowRadius = resolved.rowBorderRadius ?? kMultiAttachmentCardRadius;

    // Per-attachment durations (ms) stamped by the sender (ENG-37180), aligned
    // with the attachments order. Lets each row show its duration up front
    // instead of the file size; absent (null / short) for messages sent before
    // this shipped, where the row falls back to size until played.
    final durationsRaw = message.metadata?['audioDurationsMs'];
    final durationsMs = durationsRaw is List ? durationsRaw : const [];

    // 2dp inset on all sides between the bubble edge and the rows — same as
    // every other multi-attachment bubble (images / videos / files).
    final children = <Widget>[
      if (attachments.isNotEmpty)
        Padding(
          padding: const EdgeInsets.all(kMultiAttachmentContentInset),
          child: _AudioList(
            attachments: attachments,
            durationsMs: durationsMs,
            // Only for a single attachment: metadata['localPath'] is one path
            // and there is no way to say which row it belongs to otherwise.
            // (Multi-attachment sends stamp no local path at all today.)
            stampedLocalPath: attachments.length == 1
                ? FileUtils.getLocalFilePath(message.metadata)
                : null,
            alignment: alignment,
            rowRadius: rowRadius,
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

/// The audio rows with a "+N more / Show less" collapse for 4+ audios —
/// mirrors [CometChatFilesBubble]'s multi-document list so a stack of audio
/// files reads the same way a stack of documents does.
class _AudioList extends StatefulWidget {
  const _AudioList({
    required this.attachments,
    required this.durationsMs,
    this.stampedLocalPath,
    required this.alignment,
    required this.rowRadius,
    this.style,
  });

  final List<Attachment> attachments;

  /// Sender-stamped per-attachment durations (ms), aligned with [attachments];
  /// an entry may be null/absent (older messages).
  final List<dynamic> durationsMs;

  /// A copy of the file already on this device, when the message carries
  /// exactly one attachment. See [_AudioRowState._restoreDownloaded].
  final String? stampedLocalPath;
  final BubbleAlignment alignment;
  final double rowRadius;
  final CometChatAudiosBubbleStyle? style;

  @override
  State<_AudioList> createState() => _AudioListState();
}

class _AudioListState extends State<_AudioList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final audios = widget.attachments;
    final collapsible = audios.length >= 4;
    final visible = (collapsible && !_expanded) ? audios.sublist(0, 3) : audios;
    final colors = CometChatThemeHelper.getColorPalette(context);
    final sent = widget.alignment == BubbleAlignment.right;
    final actionColor = sent
        ? Colors.white
        : (colors.textPrimary ?? Colors.black87);
    final rowSpacing = widget.style?.rowSpacing ?? 2;

    final rows = <Widget>[];
    for (var i = 0; i < visible.length; i++) {
      if (i > 0) rows.add(SizedBox(height: rowSpacing));
      // `visible` preserves the leading order of `audios`, so loop index i is
      // the attachment index — aligned with the durations list.
      final durMs = i < widget.durationsMs.length
          ? widget.durationsMs[i]
          : null;
      rows.add(
        _AudioRow(
          attachment: visible[i],
          initialDurationMs: durMs is int ? durMs : null,
          stampedLocalPath: widget.stampedLocalPath,
          alignment: widget.alignment,
          borderRadius: BorderRadius.circular(widget.rowRadius),
          style: widget.style,
          // A lone audio reads as the message itself — no row tint inside the
          // bubble; the tint only separates stacked rows.
          standalone: audios.length == 1,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...rows,
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
                            : Translations.of(
                                context,
                              ).fileListShowMore.replaceAll(
                                '{count}',
                                '${audios.length - 3}',
                              ),
                        style: TextStyle(
                          color: actionColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
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

/// One inline audio player row: play/pause circle, file name, flat seek
/// slider with a "pos/total" clock below, and a trailing download button
/// while the file isn't cached locally (reference mobile design). The player
/// (video_player — the same backend the voice-note bubble uses on native) is
/// initialized lazily on first play so N rows don't open N connections;
/// tapping play on an undownloaded row downloads, initializes and plays.
class _AudioRow extends StatefulWidget {
  const _AudioRow({
    required this.attachment,
    required this.alignment,
    required this.borderRadius,
    this.initialDurationMs,
    this.stampedLocalPath,
    this.style,
    this.standalone = false,
  });

  final CometChatAudiosBubbleStyle? style;

  final Attachment attachment;

  /// A copy of this file already on the device, stamped by the composer when
  /// the message was sent. Null unless the message has a single attachment.
  final String? stampedLocalPath;

  /// Sender-stamped duration (ms) for this row, shown in the clock before the
  /// file is loaded (ENG-37180). Null for older messages — the row then shows
  /// the file size until the player initializes on first play.
  final int? initialDurationMs;

  final BubbleAlignment alignment;

  /// True when this is the message's only audio — the row fill goes fully
  /// transparent so the row reads as the whole message.
  final bool standalone;

  /// Per-position corner rounding so a stack of rows reads as one connected
  /// block (outer corners rounded, shared edges square) — matches
  /// [CometChatFilesBubble]'s card stack.
  final BorderRadius borderRadius;

  @override
  State<_AudioRow> createState() => _AudioRowState();
}

/// Shared fixed height for every card inside an audios message — the player
/// row and the "unsupported audio" file-card fallback — so a message that mixes
/// the two reads as a uniform stack (they were previously uneven: the player's
/// name+slider+clock column ran taller than the single-line file card).
const double _kAudioRowHeight = 56;

class _AudioRowState extends State<_AudioRow> {
  vp.VideoPlayerController? _controller;
  bool _busy = false; // downloading or initializing
  bool _error = false;
  String? _localPath;

  // Coordinates with every other audio player in the app (voice notes, other
  // rows in this same message, staged tray tiles) via the shared broadcast
  // stream so only one plays at a time.
  late final int _tag = widget.attachment.fileUrl.hashCode;
  StreamSubscription<AudioBubbleEvents>? _eventSub;

  bool get _sent => widget.alignment == BubbleAlignment.right;

  /// Downloaded (native) — or web, where audio streams without a download step.
  bool get _downloaded => kIsWeb || _localPath != null;

  /// The attachment isn't actually audio (its real mime/extension is something
  /// else) — a **type mismatch**: it was sent in an audio message but the file
  /// is, say, a PDF. We never try to play it; it renders as a file card.
  bool get _isMismatch => !AttachmentUtils.isAudio(widget.attachment);

  /// Render this row as a plain **file card** (type icon + file name +
  /// Download/open) instead of a player — ONLY on a type mismatch (the file
  /// isn't audio at all). A genuine audio that merely *failed to play* keeps its
  /// player row and surfaces a retryable error on the leading button: flipping a
  /// real audio into a "document" card on a transient init failure was jarring
  /// (it would toggle between playing and a file card across taps).
  bool get _showAsFile => _isMismatch;

  /// The trailing ↓ (Save as) is always available — it opens the location
  /// picker, which the user can invoke repeatedly regardless of cache state.
  bool get _showDownload => true;

  @override
  void initState() {
    super.initState();
    _restoreDownloaded();
    _eventSub = AudioBubbleStream().stream.listen((event) {
      if (event.id != _tag && event.action == AudioBubbleActions.pausePlayer) {
        _controller?.pause();
      }
    });
  }

  /// Points the row at a copy already on the device so it shows play +
  /// duration right away, instead of waiting for a download.
  ///
  /// Two places to look, and the order matters. The composer stamps
  /// `metadata['localPath']` on anything it sends, so on the *sender's* device
  /// the file is already there — every other bubble reads it (image, video,
  /// file, voice note), and this one used to not, which made the sender fetch
  /// their own upload back from the CDN before it would play. A signed url
  /// that isn't servable yet then left the row on a sticky error while the
  /// receiver, whose download had populated the cache, played fine
  /// (ENG-39489). Failing that, fall back to the download cache.
  Future<void> _restoreDownloaded() async {
    if (kIsWeb) return;

    // A mismatched (non-audio) file renders as a file card — never initialise
    // a player for it, even if a copy is already on the device.
    if (_isMismatch) return;

    final stamped = widget.stampedLocalPath;
    if (stamped != null &&
        stamped.isNotEmpty &&
        FileUtils.isLocalFileAvailable(stamped)) {
      if (!mounted) return;
      _localPath = stamped;
      await _initController();
      return;
    }

    final p = await platform_file.getDownloadedFilePath(
      widget.attachment.fileName,
      fileUrl: widget.attachment.fileUrl,
    );
    if (p == null || !mounted || _isMismatch) return;
    _localPath = p;
    await _initController();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  /// Creates + initializes the (paused) player so the duration is known.
  ///
  /// A previous FAILED attempt leaves a non-initialized controller behind; only
  /// an *initialized* controller short-circuits here, so a retry rebuilds it
  /// rather than being blocked. Without this, a freshly-uploaded url that wasn't
  /// fetchable on the first tap could only be played by leaving and re-entering
  /// the chat (which disposed the dead controller).
  Future<void> _initController({int attempt = 0}) async {
    if (_controller != null && _controller!.value.isInitialized) return;
    await _disposeController();

    final c = kIsWeb
        ? vp.VideoPlayerController.networkUrl(
            Uri.parse(widget.attachment.fileUrl),
          )
        : platform_file.videoControllerForPath(_localPath!);
    if (c == null) {
      if (mounted) setState(() => _error = true);
      return;
    }
    _controller = c;
    c.addListener(_onTick);
    try {
      // Bound the init so a not-yet-fetchable signed url can't pin the spinner.
      await c.initialize().timeout(const Duration(seconds: 10));
      if (mounted) setState(() {});
    } catch (_) {
      // Drop the dead controller so the next attempt starts clean.
      await _disposeController();
      // A just-uploaded url can be briefly un-fetchable; retry once after a
      // short delay before surfacing the error, so the user doesn't have to tap
      // again (or leave the chat) for it to play.
      if (attempt == 0 && mounted) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        return _initController(attempt: 1);
      }
      if (mounted) setState(() => _error = true);
    }
  }

  /// Tears down the current player (if any) so a fresh one can be built. Used
  /// before re-initialising after a failed attempt.
  Future<void> _disposeController() async {
    final c = _controller;
    _controller = null;
    if (c != null) {
      c.removeListener(_onTick);
      await c.dispose();
    }
  }

  /// Fetches the file to the local cache (no playback). Shared by the play
  /// path (download → init → play) and the trailing download-only button.
  Future<bool> _download({int attempt = 0}) async {
    setState(() => _busy = true);
    try {
      final path = await BubbleUtils.downloadFile(
        widget.attachment.fileUrl,
        widget.attachment.fileName,
      );
      if (path == null) {
        // A url handed back by a send that has only just completed can be
        // briefly unservable. Retry once before surfacing the error, the same
        // way [_initController] does — otherwise the first play of your own
        // upload lands on a sticky error icon and the user has to tap again.
        if (attempt == 0 && mounted) {
          await Future<void>.delayed(const Duration(seconds: 1));
          if (!mounted) return false;
          return await _download(attempt: 1);
        }
        if (mounted) setState(() => _error = true);
        return false;
      }
      _localPath = path;
      // Mismatched files are saved but never played (they render as a file
      // card); only initialise a player for genuine audio.
      if (!_isMismatch) await _initController();
      return !_error;
    } catch (_) {
      if (attempt == 0 && mounted) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted) return false;
        return await _download(attempt: 1);
      }
      if (mounted) setState(() => _error = true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Trailing ↓ button: save the file. On web this hands the URL to the
  /// browser's downloader; on native it opens the system "Save as" location
  /// picker (the user chooses where it lands), reusing the cached copy when one
  /// exists to avoid a re-download.
  Future<void> _onDownloadTap() async {
    if (_busy) return;
    if (kIsWeb) {
      web_download.triggerBrowserDownload(
        widget.attachment.fileUrl,
        widget.attachment.fileName,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await platform_file.saveFileWithPicker(
        widget.attachment.fileUrl,
        widget.attachment.fileName,
        widget.attachment.fileMimeType,
        localPath: _localPath,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Tells every other audio player in the app to pause before this row
  /// starts playing — only one plays at a time.
  void _broadcastPause() {
    AudioBubbleStream().controller.sink.add(
      AudioBubbleEvents(id: _tag, action: AudioBubbleActions.pausePlayer),
    );
  }

  /// Leading button is always play/pause: an undownloaded row downloads,
  /// initializes and starts playing in one tap (reference design).
  Future<void> _onLeadingTap() async {
    if (_busy) return;
    if (_error) {
      // Retry from scratch.
      setState(() => _error = false);
    }

    if (!_downloaded) {
      final ok = await _download();
      if (ok && mounted && _controller != null) {
        _broadcastPause();
        await _controller!.play();
      }
      return;
    }

    // Downloaded (or web): ensure the player exists, then toggle.
    if (_controller == null || !_controller!.value.isInitialized) {
      setState(() => _busy = true);
      await _initController();
      if (mounted) setState(() => _busy = false);
      if (_error || _controller == null) return;
      _broadcastPause();
      await _controller!.play();
      return;
    }
    final c = _controller!;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      _broadcastPause();
      await c.play();
    }
  }

  /// Reference clock format: zero-padded minutes and seconds ("00:32").
  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _fmtSize(int b) {
    if (b >= 1 << 20) return '${(b / (1 << 20)).toStringAsFixed(1)} MB';
    if (b >= 1 << 10) return '${(b / (1 << 10)).round()} KB';
    return '$b B';
  }

  /// Lower-cased extension from the file name (falling back to `fileExtension`).
  String _ext() {
    final n = widget.attachment.fileName;
    final e = n.contains('.')
        ? n.split('.').last
        : widget.attachment.fileExtension;
    return e.toLowerCase();
  }

  /// Tapping the file-card fallback opens the file: native downloads it (if not
  /// already local) and hands it to the OS "open with" chooser via the plugin's
  /// `open_file` channel; web opens the URL in a new tab. Mirrors the files
  /// bubble's open behaviour so documents/unsupported files in an audio message
  /// are openable, not just downloadable.
  Future<void> _openFileCardTap() async {
    if (_busy) return;
    final url = widget.attachment.fileUrl;
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
      // Resolve a REAL, openable app-local path (downloadFile returns the
      // MediaStore "Downloads/<name>" display string on Android, not openable).
      var path = _localPath;
      if (path == null || !platform_file.fileExistsSync(path)) {
        await BubbleUtils.downloadFile(url, widget.attachment.fileName);
        path = await platform_file.getDownloadedFilePath(
          widget.attachment.fileName,
          fileUrl: widget.attachment.fileUrl,
        );
        _localPath = path;
      }
      if (path != null) {
        const channel = MethodChannel('cometchat_chat_uikit');
        await channel.invokeMethod('open_file', {
          'file_path': path,
          'file_type': widget.attachment.fileMimeType,
        });
      }
    } catch (e) {
      ccLog('[audios bubble] open failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The "unsupported audio" fallback: a plain file card — the file's type icon,
  /// its name, and a Download button. Tapping the card opens the file (see
  /// [_openFileCardTap]). No player, no MIME, no size (per design). Shown on a
  /// type mismatch ([_showAsFile]).
  Widget _buildFileCard(BuildContext context) {
    final colors = CometChatThemeHelper.getColorPalette(context);
    final style = widget.style;
    final rowBg =
        style?.rowBackgroundColor ??
        (widget.standalone
            ? Colors.transparent
            : _sent
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.black.withValues(alpha: 0.04));
    final mainColor = _sent
        ? Colors.white
        : (colors.neutral900 ?? Colors.black);
    final downloadColor = _sent
        ? Colors.white
        : (colors.iconSecondary ?? Colors.black54);

    return GestureDetector(
      onTap: _busy ? null : _openFileCardTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        // maxFactor 2.0 rather than the 1.5 default: the row stacks a name,
        // a slider and a clock, so it needs the full scale to stay uncropped.
        height: scaledDimension(context, _kAudioRowHeight, maxFactor: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: rowBg,
          borderRadius: widget.borderRadius,
        ),
        child: Row(
          children: [
            attachmentSvgIcon(
              fileName: widget.attachment.fileName,
              extension: _ext(),
              mimeType: widget.attachment.fileMimeType,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.attachment.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: mainColor,
                ).merge(style?.nameTextStyle),
              ),
            ),
            if (_showDownload)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: Translations.of(context).download,
                icon: _busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            downloadColor,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.file_download_outlined,
                        color: downloadColor,
                        size: 22,
                      ),
                onPressed: _busy ? null : _onDownloadTap,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showAsFile) return _buildFileCard(context);
    final colors = CometChatThemeHelper.getColorPalette(context);
    final value = _controller?.value;
    final ready = value?.isInitialized ?? false;
    final playing = value?.isPlaying ?? false;
    final dur = ready ? value!.duration : Duration.zero;
    final pos = ready ? value!.position : Duration.zero;
    final maxMs = dur.inMilliseconds.toDouble();
    final posMs = pos.inMilliseconds.toDouble().clamp(
      0.0,
      maxMs <= 0 ? 0.0 : maxMs,
    );

    // Clock under the slider: "pos/dur" once the player is initialized;
    // otherwise the sender-stamped duration up front (ENG-37180) — falling back
    // to the file size (older messages with no stamped duration), then a
    // placeholder once downloaded but not yet initialized.
    final String clock;
    if (ready) {
      clock = '${_fmt(pos)}/${_fmt(dur)}';
    } else if (widget.initialDurationMs != null &&
        widget.initialDurationMs! > 0) {
      clock =
          '00:00/${_fmt(Duration(milliseconds: widget.initialDurationMs!))}';
    } else if (!_downloaded) {
      clock = _fmtSize(widget.attachment.fileSize ?? 0);
    } else {
      clock = '--:--';
    }

    // Leading circle is always play/pause (download happens transparently on
    // first play); errors surface on it as a retryable indicator.
    final IconData leadingIcon;
    if (_error) {
      leadingIcon = Icons.error_outline;
    } else if (playing) {
      leadingIcon = Icons.pause;
    } else {
      leadingIcon = Icons.play_arrow_rounded;
    }

    final style = widget.style;
    final rowBg =
        style?.rowBackgroundColor ??
        (widget.standalone
            ? Colors.transparent
            : _sent
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.black.withValues(alpha: 0.04));
    final mainColor = _sent
        ? Colors.white
        : (colors.neutral900 ?? Colors.black);
    final subColor = _sent
        ? Colors.white.withValues(alpha: 0.6)
        : (colors.textSecondary ?? Colors.black54);
    final accent =
        style?.playIconBackgroundColor ??
        (_sent ? Colors.white : (colors.primary ?? Colors.blue));

    return Container(
      // maxFactor 2.0 rather than the 1.5 default: the row stacks a name,
      // a slider and a clock, so it needs the full scale to stay uncropped.
      height: scaledDimension(context, _kAudioRowHeight, maxFactor: 2.0),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: widget.borderRadius,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _onLeadingTap,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: accent,
              child: _busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _sent
                              ? (colors.primary ?? Colors.blue)
                              : Colors.white,
                        ),
                      ),
                    )
                  : Icon(
                      leadingIcon,
                      color:
                          style?.playIconColor ??
                          (_sent
                              ? (colors.primary ?? Colors.blue)
                              : Colors.white),
                      size: 22,
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
                  widget.attachment.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: mainColor,
                  ).merge(style?.nameTextStyle),
                ),
                SizedBox(
                  height: 20,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 10,
                      ),
                      padding: EdgeInsets.zero,
                      thumbColor: style?.sliderThumbColor,
                    ),
                    child: Slider(
                      value: posMs,
                      max: maxMs <= 0 ? 1.0 : maxMs,
                      activeColor: style?.sliderActiveColor ?? accent,
                      inactiveColor:
                          style?.sliderInactiveColor ??
                          subColor.withValues(alpha: 0.35),
                      onChanged: ready
                          ? (v) => _controller?.seekTo(
                              Duration(milliseconds: v.round()),
                            )
                          : null,
                    ),
                  ),
                ),
                Text(
                  clock,
                  style: TextStyle(
                    fontSize: 10,
                    color: subColor,
                  ).merge(style?.durationTextStyle),
                ),
              ],
            ),
          ),
          // Download-only affordance while the file isn't on the device
          // (native cache / web browser download).
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
                    color: style?.downloadIconColor ?? accent,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
