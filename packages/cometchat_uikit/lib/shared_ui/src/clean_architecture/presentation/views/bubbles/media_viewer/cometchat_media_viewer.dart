import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart' as vp;

import '../../../../clean_architecture.dart';
import '../../../../core/utils/platform_utils/platform_file_utils.dart'
    as platform_file;
import '../../../../core/utils/platform_utils/platform_image_utils.dart'
    as platform_image;
import '../../../../core/utils/platform_utils/web_video.dart' as web_video;
import '../../../../../logging/cometchat_log.dart';
import '../../../../core/utils/platform_utils/web_download.dart'
    as web_download;

bool _isRemote(String url) =>
    url.startsWith('http://') ||
    url.startsWith('https://') ||
    // Web object URLs over staged bytes load through the network path too.
    url.startsWith('blob:');

/// A player controller for [url] — network for http(s), local file otherwise
/// (null on web for local paths, which don't exist there).
vp.VideoPlayerController? _controllerFor(String url) {
  if (_isRemote(url)) {
    return vp.VideoPlayerController.networkUrl(Uri.parse(url));
  }
  return platform_file.videoControllerForPath(url);
}

/// A fullscreen, swipeable pager across a message's **image + video + audio**
/// attachments (files download — they are not pages here). Audio pages play
/// inline with a seek bar, elapsed/total time, and the file name.
///
/// Inputs: the image+video+audio [mediaItems] and the [startIndex] of the
/// tapped item. Opened from both the gallery bubble tiles and (later) the
/// composer tray tiles — one component, two call sites.
///
/// First-cut note: this is a self-contained pager (image page = zoomable
/// network image; video page = inline `video_player`). Folding the existing
/// `ImageViewer`/`VideoPlayer` widgets into shared page content (design Q6 → A)
/// is a follow-up; the contract here is already the final one.
class CometChatMediaViewer extends StatefulWidget {
  const CometChatMediaViewer({
    super.key,
    required this.mediaItems,
    this.startIndex = 0,
  });

  /// The message's `image/*` + `video/*` attachments, in order.
  final List<Attachment> mediaItems;

  /// Index of the item to open first.
  final int startIndex;

  /// Opens the viewer over [mediaItems] starting at [startIndex].
  static Future<void> open(
    BuildContext context,
    List<Attachment> mediaItems, {
    int startIndex = 0,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CometChatMediaViewer(
          mediaItems: mediaItems,
          startIndex: startIndex,
        ),
      ),
    );
  }

  @override
  State<CometChatMediaViewer> createState() => _CometChatMediaViewerState();
}

class _CometChatMediaViewerState extends State<CometChatMediaViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.startIndex,
  );
  late int _index = widget.startIndex;
  final FocusNode _focusNode = FocusNode(debugLabel: 'media_viewer_keys');

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (page < 0 || page >= widget.mediaItems.length) return;
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  /// ← / → page the carousel, Esc closes — standard viewer keys (web/desktop;
  /// harmless elsewhere, where no hardware keys fire).
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _goTo(_index - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _goTo(_index + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _downloading = false;

  /// Saves the currently-visible attachment — browser download on web; on
  /// native, the system "Save as" location picker (the user chooses where it
  /// lands). A confirmation snackbar shows on a successful save; a cancelled
  /// picker is silent (not an error).
  Future<void> _downloadCurrent() async {
    if (_downloading) return;
    final a = widget.mediaItems[_index];
    final url = a.fileUrl;
    if (url.isEmpty) return;
    setState(() => _downloading = true);
    bool saved = false;
    Object? failure;
    try {
      if (kIsWeb) {
        // The browser owns the rest — there's no result to report back.
        web_download.triggerBrowserDownload(url, a.fileName);
      } else {
        // false = user cancelled the picker OR the write failed. Cancel is the
        // common case, so a false result stays silent (no false-alarm error).
        saved = await platform_file.saveFileWithPicker(
          url,
          a.fileName,
          a.fileMimeType,
        );
      }
    } catch (e) {
      failure = e;
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
    if (!mounted) return;
    if (failure != null) {
      ccLog('media viewer save failed for ${a.fileName}: $failure');
      _showDownloadAlert(Translations.of(context).somethingWentWrongError);
    } else if (saved) {
      _showDownloadAlert(Translations.of(context).fileSaved);
    }
  }

  /// Tells the user where the file went (or that it failed) — the download was
  /// previously silent in both directions.
  void _showDownloadAlert(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Circular translucent prev/next arrow, vertically centered over the pager.
  Widget _navArrow({required bool forward}) {
    return Align(
      alignment: forward ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.14),
          shape: const CircleBorder(),
          child: Semantics(
            button: true,
            label: forward
                ? Translations.of(context).next
                : Translations.of(context).previous,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _goTo(forward ? _index + 1 : _index - 1),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  forward ? Icons.chevron_right : Icons.chevron_left,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.mediaItems.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / $total'),
        leading: IconButton(
          tooltip: Translations.of(context).close,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          // Always-available download (top-right), on every page including the
          // "No preview available" card — which also has its own body button,
          // so unsupported files intentionally offer both.
          IconButton(
            tooltip: Translations.of(context).download,
            icon: _downloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.file_download_outlined),
            onPressed: _downloading ? null : _downloadCurrent,
          ),
        ],
      ),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: total,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final a = widget.mediaItems[i];
                // The carousel previews ONLY image/video. On any failure/unsupported
                // page the "No preview available" card carries its own centre
                // Download button (the AppBar keeps the top-right one), so the
                // download action is threaded into every page.
                if (AttachmentUtils.isVideo(a)) {
                  return _VideoPage(
                    url: a.fileUrl,
                    onDownload: _downloadCurrent,
                    downloading: _downloading,
                  );
                }
                if (AttachmentUtils.isImage(a)) {
                  return _ImagePage(
                    url: a.fileUrl,
                    onDownload: _downloadCurrent,
                    downloading: _downloading,
                  );
                }
                // Audio, or a file whose type doesn't match the message it was
                // sent in — no inline preview; show "No preview available".
                return _UnsupportedView(
                  onDownload: _downloadCurrent,
                  downloading: _downloading,
                );
              },
            ),
            if (_index > 0) _navArrow(forward: false),
            if (_index < total - 1) _navArrow(forward: true),
          ],
        ),
      ),
    );
  }
}

/// Zoomable image page.
class _ImagePage extends StatelessWidget {
  const _ImagePage({
    required this.url,
    required this.onDownload,
    required this.downloading,
  });
  final String url;
  final VoidCallback onDownload;
  final bool downloading;

  @override
  Widget build(BuildContext context) {
    Widget noPreview() =>
        _UnsupportedView(onDownload: onDownload, downloading: downloading);
    final Widget image = _isRemote(url)
        ? Image.network(
            url,
            fit: BoxFit.contain,
            // <img> fallback keeps CanvasKit rendering CDN media that lacks
            // CORS headers.
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            // Covers the pre-first-chunk waiting phase where loadingBuilder
            // gets null progress and would paint blank.
            frameBuilder: (context, child, frame, wasSync) {
              if (wasSync || frame != null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (context, error, stackTrace) => noPreview(),
          )
        // Local path — a staged (not yet uploaded) file previewed from the tray.
        : platform_image.buildFileImage(
            url,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => noPreview(),
          );
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(child: image),
    );
  }
}

/// Inline video page (tap to play / pause).
class _VideoPage extends StatefulWidget {
  const _VideoPage({
    required this.url,
    required this.onDownload,
    required this.downloading,
  });
  final String url;
  final VoidCallback onDownload;
  final bool downloading;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

/// Height reserved at the bottom of the video for the seek bar + timestamps, so
/// the centred play/pause affordance is laid out ABOVE them instead of on top.
const double _kVideoControlsBarHeight = 46;

/// How long the controls linger after playback starts before fading out.
const Duration _kControlsAutoHideDelay = Duration(milliseconds: 2500);

class _VideoPageState extends State<_VideoPage> {
  vp.VideoPlayerController? _controller;
  bool _ready = false;
  bool _error = false;

  /// Controls (play/pause + seek bar) visibility. They auto-hide while playing
  /// so the pause icon doesn't sit permanently over the video, and always stay
  /// up while paused or once playback ends.
  bool _controlsVisible = true;
  Timer? _hideTimer;

  /// On web, a native `<video controls>` element (see [web_video]); null on
  /// native, where `video_player` is used instead.
  Widget? _webVideo;

  @override
  void initState() {
    super.initState();
    // Web: use a native <video> element (video_player's web plugin can't load
    // cross-origin CDN videos). It carries its own controls.
    _webVideo = web_video.buildWebVideoPlayer(widget.url);
    if (_webVideo != null) return;

    final c = _controllerFor(widget.url);
    if (c == null) {
      _error = true;
      return;
    }
    _controller = c;
    c.addListener(_onPlaybackChanged);
    c
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() => _error = true);
        });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.removeListener(_onPlaybackChanged);
    _controller?.dispose();
    super.dispose();
  }

  /// Brings the controls back when playback stops on its own (end of video),
  /// otherwise the user would be left with a hidden, un-restartable player.
  void _onPlaybackChanged() {
    final c = _controller;
    if (c == null || !mounted) return;
    if (!c.value.isPlaying && !_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = true);
    }
  }

  /// Schedules the fade-out — only while actually playing; a paused player
  /// keeps its controls up.
  void _restartHideTimer() {
    _hideTimer?.cancel();
    final c = _controller;
    if (c == null || !c.value.isPlaying) return;
    _hideTimer = Timer(_kControlsAutoHideDelay, () {
      if (!mounted) return;
      setState(() => _controlsVisible = false);
    });
  }

  /// Tapping the video surface reveals or dismisses the controls (it does not
  /// toggle playback — that's the button's job).
  void _toggleControls() {
    if (!_ready) return;
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _restartHideTimer();
  }

  void _toggle() {
    final c = _controller;
    if (c == null || !_ready) return;
    // play()/pause() are async and mutate the controller, which notifies its
    // listeners — driving them from inside setState was pointless.
    if (c.value.isPlaying) {
      c.pause();
      _hideTimer?.cancel();
      setState(() => _controlsVisible = true);
    } else {
      c.play();
      setState(() => _controlsVisible = true);
      _restartHideTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_webVideo != null) return Center(child: _webVideo);
    if (_error) {
      return _UnsupportedView(
        onDownload: widget.onDownload,
        downloading: widget.downloading,
      );
    }
    final c = _controller;
    if (!_ready || c == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return GestureDetector(
      onTap: _toggleControls,
      child: Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              vp.VideoPlayer(c),
              // Live controls — center play/pause affordance and a bottom
              // scrubbable seek bar with elapsed/total time. They fade out
              // while playing so nothing sits permanently over the video.
              ValueListenableBuilder<vp.VideoPlayerValue>(
                valueListenable: c,
                builder: (context, value, _) {
                  return AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_controlsVisible,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Center play/pause tap target, centred in the area ABOVE
                          // the seek bar so the two can't collide on short videos.
                          Positioned.fill(
                            bottom: _kVideoControlsBarHeight,
                            child: Center(
                              child: Semantics(
                                button: true,
                                label: value.isPlaying
                                    ? Translations.of(context).pause
                                    : Translations.of(context).play,
                                child: GestureDetector(
                                  onTap: _toggle,
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: const BoxDecoration(
                                      color: Colors.black45,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      value.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Bottom seek bar + time.
                          Positioned(
                            left: 10,
                            right: 10,
                            bottom: 10,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                vp.VideoProgressIndicator(
                                  c,
                                  allowScrubbing: true,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  colors: const vp.VideoProgressColors(
                                    playedColor: Colors.white,
                                    bufferedColor: Colors.white38,
                                    backgroundColor: Colors.white24,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _fmtDuration(value.position),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      _fmtDuration(value.duration),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formats a [Duration] as `m:ss` (or `h:mm:ss`), for media controls.
String _fmtDuration(Duration d) {
  final neg = d.isNegative;
  d = d.abs();
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final body = h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  return neg ? '-$body' : body;
}

/// The fullscreen "No preview available" state — a doc-slash glyph, title,
/// subtitle, and a centre Download button — shown when a page can't be
/// previewed: a type mismatch (a file sent as the wrong message type) or an
/// image/video that failed to render/play.
///
/// The viewer intentionally offers **two** download affordances on this screen:
/// this centre button, plus the AppBar's always-visible top-right one.
class _UnsupportedView extends StatelessWidget {
  const _UnsupportedView({required this.onDownload, this.downloading = false});

  /// Invoked by the centre Download button.
  final VoidCallback onDownload;

  /// Renders the button's spinner + disables it while a download is running.
  final bool downloading;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final colors = CometChatThemeHelper.getColorPalette(context);
    final accent = colors.primary ?? const Color(0xFF6852D6);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                kAttachmentUnsupportedIconAsset,
                package: kAttachmentIconPackage,
                width: 40,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              t.noPreviewAvailable,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t.fileTypeNotSupportedForPreview,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: downloading ? null : onDownload,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: accent.withValues(alpha: 0.6),
                disabledForegroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: downloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.file_download_outlined, size: 20),
              label: Text(
                t.download,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
