import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../clean_architecture.dart';
import '../../../../core/utils/platform_utils/platform_image_utils.dart'
    as platform_image;
import '../../../../../offline/offline_hub_event.dart';
import '../../../../../offline/offline_media.dart';

/// Shared corner radius for every "card" inside a multi-attachment bubble —
/// grid cells (images/videos), audio rows, and file cards. Kept as one
/// constant so the curve of an image tile matches the curve of a file/audio
/// card exactly, across all four bubble types.
const double kMultiAttachmentCardRadius = 10.0;

/// Shared inset between a multi-attachment bubble's edge and its content
/// (grid / rows / cards) — 4dp on all sides, the same on every bubble type.
/// (2dp proved imperceptible against the light incoming-bubble background.)
const double kMultiAttachmentContentInset = 4.0;

/// Count-based media grid shared by [CometChatImagesBubble] and
/// [CometChatVideosBubble] — layout by count (1 / 2 / 3 / 4 / 5+ with "+N"
/// overflow on the 4th cell). The same convention shipped on v7 React /
/// Angular / Android.
///
/// Cells are lightweight thumbnails (never the viewport-aware single bubbles —
/// those cannot be nested in a non-scrollable grid). Tapping a cell opens the
/// fullscreen [CometChatMediaViewer] pager over [media] at that index.
class CometChatMediaGrid extends StatelessWidget {
  const CometChatMediaGrid({
    super.key,
    required this.media,
    required this.width,
    this.thumbs = const [],
    this.gap = 2,
    this.style,
  });

  /// The media attachments to lay out, in order.
  final List<Attachment> media;

  /// Fixed grid width (intrinsic-safe — message bubbles size to content via
  /// intrinsic width, where LayoutBuilder can't lay out).
  final double width;

  /// Poster-frame thumbnail URL per item (null when none) — used for videos.
  final List<String?> thumbs;

  /// Gap between cells.
  final double gap;

  ///[style] customizes the grid — null fields fall back to defaults.
  final CometChatMediaGridStyle? style;

  Widget _cell(
    BuildContext context,
    int index,
    double w,
    double h, {
    int? overflow,
    BorderRadiusGeometry? radius,
  }) {
    final a = media[index];
    // A non-media attachment that landed in a media message (type mismatch):
    // show the doc-slash "no preview" tile instead of a broken thumbnail. The
    // tile stays tappable — the viewer shows the full "No preview available"
    // screen with a Download button.
    final unsupported = AttachmentUtils.isNonPreviewableFile(a);
    final isVideo = !unsupported && AttachmentUtils.isVideo(a);
    void open() => CometChatMediaViewer.open(context, media, startIndex: index);

    Widget thumb;
    if (unsupported) {
      thumb = CometChatMediaPlaceholder(
        backgroundColor: style?.placeholderColor,
        unsupported: true,
      );
    } else if (isVideo) {
      // The video cell owns its own poster + play badge + duration chip so it
      // can swap them for the doc-slash "no preview" glyph when the video turns
      // out to be unplayable (same controller/URL the viewer uses — see
      // [_VideoCell]).
      thumb = _VideoCell(
        attachment: a,
        thumbUrl: index < thumbs.length ? thumbs[index] : null,
        showDurationChip: overflow == null && style?.showVideoDuration != false,
        style: style,
      );
    } else {
      // Offline (W5, G9): the device copy first; a URL that cannot load while
      // offline is on shows "Available when online" (offlineError). With
      // offline off this is exactly today's Image.network.
      thumb = OfflineMediaImage(
        attachment: a,
        placeholderColor: style?.placeholderColor,
        network: (context, offlineError) => Image.network(
          a.fileUrl,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          // CanvasKit needs CORS to fetch pixels; fall back to an <img> element
          // when the CDN response lacks the headers (fixes gif/image cells on
          // web going blank).
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          // Legacy-look holder until the first frame decodes, and on failure —
          // same art as the single-attachment CometChatImageBubble. frameBuilder
          // (not loadingBuilder) so the slow-network waiting phase before any
          // HTTP chunk arrives is covered too — loadingBuilder gets null
          // progress there and would paint a blank cell.
          frameBuilder: (context, child, frame, wasSync) {
            if (wasSync || frame != null) return child;
            return CometChatMediaPlaceholder(
              backgroundColor: style?.placeholderColor,
              loading: true,
            );
          },
          // A failed image load is a "no preview" case — show the doc-slash
          // glyph (matching the mismatch tile), not the plain image placeholder.
          errorBuilder: (_, _, _) =>
              offlineError ??
              CometChatMediaPlaceholder(
                backgroundColor: style?.placeholderColor,
                unsupported: true,
              ),
        ),
      );
    }

    return GestureDetector(
      onTap: open,
      child: SizedBox(
        width: w,
        height: h,
        child: ClipRRect(
          borderRadius:
              radius ??
              BorderRadius.circular(
                style?.cellBorderRadius ?? kMultiAttachmentCardRadius,
              ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              thumb,
              if (overflow != null)
                Container(
                  alignment: Alignment.center,
                  color: style?.overflowScrimColor ?? Colors.black54,
                  child: Text(
                    '+$overflow',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ).merge(style?.overflowTextStyle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = width;
    final n = media.length;

    // Every cell is individually and fully rounded (each grid panel curved),
    // separated by [gap] — the batch reads as a set of distinct rounded tiles.
    final r = BorderRadius.circular(
      style?.cellBorderRadius ?? kMultiAttachmentCardRadius,
    );

    if (n == 1) {
      // Single media: a square bubble, fully rounded.
      return SizedBox(
        width: w,
        child: _cell(context, 0, w, w, radius: r),
      );
    }
    if (n == 2) {
      // Two square cells side by side (fits a square-ish bubble).
      final cw = (w - gap) / 2;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _cell(context, 0, cw, cw, radius: r),
          SizedBox(width: gap),
          _cell(context, 1, cw, cw, radius: r),
        ],
      );
    }
    if (n == 3) {
      // Aspect-ratio-aware layout inside a SQUARE (w × w) bubble.
      return _TripleGrid(grid: this, side: w, radius: r);
    }
    // n >= 4 -> 2x2 square, "+N" overflow on the 4th cell when n > 4.
    final cw = (w - gap) / 2;
    final overflow = n > 4 ? n - 4 : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _cell(context, 0, cw, cw, radius: r),
            SizedBox(width: gap),
            _cell(context, 1, cw, cw, radius: r),
          ],
        ),
        SizedBox(height: gap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _cell(context, 2, cw, cw, radius: r),
            SizedBox(width: gap),
            _cell(context, 3, cw, cw, overflow: overflow, radius: r),
          ],
        ),
      ],
    );
  }
}

/// The 3-image layout: fits three fully-rounded cells inside a square (side ×
/// side) bubble, choosing between a top-hero and a left-hero arrangement.
///
/// With [MediaGridTripleLayout.auto] (the default) the hero image's aspect
/// ratio decides: a wide/landscape hero sits on top with two cells below
/// ("1 horizontal, 2 vertical"); a tall/portrait hero sits on the left with two
/// cells stacked to its right ("1 vertical, 2 horizontal"). The hero's share of
/// the square is [CometChatMediaGridStyle.heroFraction] (default 0.6).
class _TripleGrid extends StatefulWidget {
  const _TripleGrid({
    required this.grid,
    required this.side,
    required this.radius,
  });

  final CometChatMediaGrid grid;
  final double side;
  final BorderRadius radius;

  @override
  State<_TripleGrid> createState() => _TripleGridState();
}

class _TripleGridState extends State<_TripleGrid> {
  double? _heroAspect; // hero (index 0) width / height once resolved
  ImageStream? _stream;
  ImageStreamListener? _listener;

  MediaGridTripleLayout get _configured =>
      widget.grid.style?.tripleLayout ?? MediaGridTripleLayout.auto;

  @override
  void initState() {
    super.initState();
    // Only probe the hero dimensions when the layout is auto.
    if (_configured == MediaGridTripleLayout.auto) _resolveHeroAspect();
  }

  void _resolveHeroAspect() {
    final grid = widget.grid;
    final a = grid.media[0];
    final isVideo = AttachmentUtils.isVideo(a);
    // For a video hero, the poster thumbnail carries the frame's dimensions.
    final url = isVideo
        ? ((grid.thumbs.isNotEmpty ? grid.thumbs[0] : null) ?? '')
        : a.fileUrl;
    // Offline on: an image hero is measured from the copy saved on the phone
    // when there is one, before any network fetch (BEH-MEDIA-18).
    if (!isVideo && OfflineMedia.enabled) {
      final known = OfflineMedia.localPathOf(a, offlineOn: true);
      if (known != null) {
        _probeHero(platform_image.fileImageProvider(known));
        return;
      }
      OfflineMedia.resolve(a).then((path) {
        if (!mounted) return;
        if (path != null) {
          _probeHero(platform_image.fileImageProvider(path));
        } else if (url.isNotEmpty) {
          _probeHero(NetworkImage(url));
        }
      });
      return;
    }
    if (url.isEmpty) return;
    _probeHero(NetworkImage(url));
  }

  /// Reads the hero's width / height from [image].
  void _probeHero(ImageProvider image) {
    final stream = image.resolve(const ImageConfiguration());
    final listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() => _heroAspect = info.image.width / info.image.height);
    }, onError: (_, _) {});
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  /// Resolved arrangement: an explicit override wins; otherwise auto decides
  /// from the hero aspect ratio (portrait → left hero, else top hero). Until
  /// the hero resolves, defaults to the top-hero arrangement.
  MediaGridTripleLayout get _layout {
    if (_configured != MediaGridTripleLayout.auto) return _configured;
    final ar = _heroAspect;
    if (ar == null) return MediaGridTripleLayout.heroTop;
    return ar < 1.0
        ? MediaGridTripleLayout.heroLeft
        : MediaGridTripleLayout.heroTop;
  }

  @override
  Widget build(BuildContext context) {
    final grid = widget.grid;
    final side = widget.side;
    final gap = grid.gap;
    final r = widget.radius;
    final heroFraction = grid.style?.heroFraction ?? 0.6;

    if (_layout == MediaGridTripleLayout.heroLeft) {
      // 1 vertical (tall hero, left) + 2 horizontal (stacked, right).
      final heroW = (side - gap) * heroFraction;
      final restW = side - gap - heroW;
      final smallH = (side - gap) / 2;
      return SizedBox(
        width: side,
        height: side,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            grid._cell(context, 0, heroW, side, radius: r),
            SizedBox(width: gap),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                grid._cell(context, 1, restW, smallH, radius: r),
                SizedBox(height: gap),
                grid._cell(context, 2, restW, smallH, radius: r),
              ],
            ),
          ],
        ),
      );
    }

    // heroTop: 1 horizontal (wide hero, top) + 2 vertical (side by side, below).
    final heroH = (side - gap) * heroFraction;
    final restH = side - gap - heroH;
    final smallW = (side - gap) / 2;
    return SizedBox(
      width: side,
      height: side,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          grid._cell(context, 0, side, heroH, radius: r),
          SizedBox(height: gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              grid._cell(context, 1, smallW, restH, radius: r),
              SizedBox(width: gap),
              grid._cell(context, 2, smallW, restH, radius: r),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single video grid cell: server poster (or client first-frame) under a
/// centered play badge and a duration chip — swapped for the doc-slash "no
/// preview" glyph (no play badge) when the video can't be loaded.
///
/// The unplayable case is detected via [CometChatVideoFirstFrame.onFailed]:
/// its controller uses the same URL/codec the fullscreen player does, so a
/// failure here means the viewer would show "No preview available" too. Kept
/// consistent so a tile never advertises a play button for a video that won't
/// play. (A video that has a valid server poster is assumed playable — the
/// failure signal only fires when the client first-frame path is reached.)
class _VideoCell extends StatefulWidget {
  const _VideoCell({
    required this.attachment,
    required this.thumbUrl,
    required this.showDurationChip,
    this.style,
  });

  final Attachment attachment;
  final String? thumbUrl;
  final bool showDurationChip;
  final CometChatMediaGridStyle? style;

  @override
  State<_VideoCell> createState() => _VideoCellState();
}

class _VideoCellState extends State<_VideoCell> {
  bool _unsupported = false;

  // Offline (W5, G9): like an image cell, the device copy first, then the
  // URL, then "Available when online" when the URL cannot load. Re-resolved
  // on the hub's MediaReady. With offline off none of this runs.
  late final bool _offlineOn = OfflineMedia.enabled;
  String? _localPath;
  bool _localFailed = false;
  bool _unavailable = false;
  StreamSubscription<OfflineHubEvent>? _mediaReady;

  @override
  void initState() {
    super.initState();
    if (!_offlineOn) return;
    _startResolve();
    _mediaReady = OfflineMedia.listenMediaReady(_resolve);
  }

  @override
  void didUpdateWidget(_VideoCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_offlineOn && !identical(oldWidget.attachment, widget.attachment)) {
      _localFailed = false;
      _unavailable = false;
      _startResolve();
    }
  }

  void _startResolve() {
    _localPath = OfflineMedia.localPathOf(widget.attachment, offlineOn: true);
    if (_localPath == null) _resolve();
  }

  Future<void> _resolve() async {
    final path = await OfflineMedia.resolve(widget.attachment);
    if (!mounted || path == null || (path == _localPath && !_localFailed)) {
      return;
    }
    setState(() {
      _localPath = path;
      _localFailed = false;
      _unavailable = false;
    });
  }

  @override
  void dispose() {
    _mediaReady?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.attachment;
    final style = widget.style;

    if (_unsupported) {
      return CometChatMediaPlaceholder(
        backgroundColor: style?.placeholderColor,
        unsupported: true,
      );
    }

    if (_offlineOn && _unavailable) {
      return OfflineMediaPlaceholder(
        attachment: a,
        backgroundColor: style?.placeholderColor,
      );
    }

    // Server thumbnail when present; otherwise extract the video's first frame
    // client-side (the server's thumbnail generation fails for some formats,
    // e.g. iPhone .mov), falling to the doc-slash glyph when even that fails
    // (offline on: to "Available when online").
    Widget firstFrame() => CometChatVideoFirstFrame(
      key: ValueKey('cc_grid_video_frame_${a.fileUrl}'),
      source: a.fileUrl,
      fallback: CometChatMediaPlaceholder(
        backgroundColor: style?.placeholderColor,
      ),
      onFailed: () {
        if (!mounted) return;
        // A late failure of the URL frame after the device copy took over.
        if (_offlineOn && _localPath != null && !_localFailed) return;
        setState(() {
          if (_offlineOn) {
            _unavailable = true;
          } else {
            _unsupported = true;
          }
        });
      },
    );

    final local = _localFailed ? null : _localPath;
    final vthumb = widget.thumbUrl;
    final poster = local != null
        ? CometChatVideoFirstFrame(
            key: ValueKey('cc_grid_video_local_$local'),
            source: local,
            fallback: CometChatMediaPlaceholder(
              backgroundColor: style?.placeholderColor,
            ),
            onFailed: () {
              if (mounted && _localPath == local) {
                setState(() => _localFailed = true);
              }
            },
          )
        : (vthumb != null && vthumb.isNotEmpty)
        ? Image.network(
            vthumb,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            frameBuilder: (context, child, frame, wasSync) {
              if (wasSync || frame != null) return child;
              return CometChatMediaPlaceholder(
                backgroundColor: style?.placeholderColor,
                loading: true,
              );
            },
            errorBuilder: (_, _, _) => firstFrame(),
          )
        : firstFrame();

    return Stack(
      fit: StackFit.expand,
      children: [
        poster,
        Center(
          child: CircleAvatar(
            radius: 16,
            backgroundColor: style?.playBadgeBackgroundColor ?? Colors.black45,
            child: Icon(
              Icons.play_arrow_rounded,
              color: style?.playBadgeIconColor ?? Colors.white,
              size: 22,
            ),
          ),
        ),
        if (widget.showDurationChip)
          Positioned(
            left: 4,
            bottom: 4,
            child: _VideoDurationChip(url: local ?? a.fileUrl, style: style),
          ),
      ],
    );
  }
}

/// A bottom-start `m:ss` pill on a video cell. Reads the duration lazily from
/// the video URL (cached per URL by [MediaDurationCache]), so old and
/// cross-platform messages get a chip without any duration in their metadata.
/// Shows nothing until/unless a duration is available (fails soft when offline).
class _VideoDurationChip extends StatelessWidget {
  const _VideoDurationChip({required this.url, this.style});

  final String url;
  final CometChatMediaGridStyle? style;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Duration?>(
      // The cache returns the same future per URL, so this never re-probes.
      future: MediaDurationCache.of(url),
      builder: (context, snapshot) {
        final d = snapshot.data;
        if (d == null) return const SizedBox.shrink();
        final m = d.inMinutes;
        final s = (d.inSeconds % 60).toString().padLeft(2, '0');
        return DecoratedBox(
          decoration: BoxDecoration(
            color:
                style?.durationChipBackgroundColor ??
                Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            child: Text(
              '$m:$s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ).merge(style?.durationChipTextStyle),
            ),
          ),
        );
      },
    );
  }
}
