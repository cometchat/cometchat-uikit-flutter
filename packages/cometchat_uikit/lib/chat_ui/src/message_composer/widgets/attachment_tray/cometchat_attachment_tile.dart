import 'dart:async';

import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart' as vp;

import '../../../../../shared_ui/src/clean_architecture/core/utils/platform_utils/platform_file_utils.dart'
    as platform_file;
import '../../../../../shared_ui/src/clean_architecture/core/utils/platform_utils/platform_image_utils.dart'
    as platform_image;

/// One staged item in the [CometChatAttachmentTray]. Renders in one of three
/// modes:
///   • image / video → **square thumbnail** with a whole-tile status scrim
///   • audio         → **inline player card** — circular play button + seek
///     slider + "pos/total" time; upload status lives *inside* the play
///     circle (scrim + spinner / error badge)
///   • file          → **wide card** where status lives *inside* the leading
///     icon container (scrim + spinner / error badge) plus a status subtitle
///     ("PDF" / "Upload failed" / "Tap to retry")
///
/// Card status mapping (audio + file, reference mobile design):
///   • uploading → spinner over the leading icon
///   • failed    → red border, "Tap to retry" — tap surfaces the error
///     snackbar (which carries the retry action)
///   • rejected  → red border, "Upload failed" (not retryable — the snackbar
///     is informational only)
/// The top-right ✕ badge is shown on every touch platform; on web it appears
/// only while the pointer hovers the tile. Tapping it cancels an in-flight
/// upload (if any) and removes the tile from the tray.
///
/// An errored tile shows its reason two ways: on a hover-capable web browser,
/// hovering reveals a plain [Tooltip]; tapping (any platform) surfaces the
/// full actionable error snackbar (which carries the retry action).
class CometChatAttachmentTile extends StatefulWidget {
  const CometChatAttachmentTile({
    super.key,
    required this.tile,
    required this.onCancelOrRemove,
    this.onTap,
    this.onErrorInteract,
    this.onRetry,
    this.height = 64,
    this.style,
  });

  final AttachmentTile tile;
  final VoidCallback onCancelOrRemove;

  /// Opens the fullscreen preview (image / video tiles only — audio has an
  /// inline player and files are not previewable).
  final VoidCallback? onTap;

  /// Shows the informational error snackbar (the failure reason) for this
  /// tile. Used for a **rejected** (non-retryable) tile — over the size/type/
  /// count limit. On web the same reason also shows as a hover tooltip.
  final VoidCallback? onErrorInteract;

  /// Retries the upload of a **failed** (network, retryable) tile — this is the
  /// in-tile retry: tapping a failed tile re-uploads it. Non-null only for
  /// `failed` tiles; rejected tiles are not retryable.
  final VoidCallback? onRetry;

  final double height;

  ///[style] customizes the tile — null fields fall back to theme defaults.
  final CometChatAttachmentTrayStyle? style;

  @override
  State<CometChatAttachmentTile> createState() =>
      _CometChatAttachmentTileState();
}

class _CometChatAttachmentTileState extends State<CometChatAttachmentTile> {
  // Aliases so the render helpers below read the same as when this was a
  // StatelessWidget.
  AttachmentTile get tile => widget.tile;
  VoidCallback get onCancelOrRemove => widget.onCancelOrRemove;
  VoidCallback? get onTap => widget.onTap;
  VoidCallback? get onErrorInteract => widget.onErrorInteract;
  VoidCallback? get onRetry => widget.onRetry;

  /// Grows with the user's text size: at 64pt fixed, the file card's name and
  /// meta lines overflow the tile by 8px at 200%.
  double heightFor(BuildContext context) =>
      scaledDimension(context, widget.height);
  CometChatAttachmentTrayStyle? get style => widget.style;

  // Hover-capable only on a DESKTOP web browser. Native mobile and web opened
  // in a mobile browser (kIsWeb true but defaultTargetPlatform reports the
  // device OS from the user agent) never fire hover, so touch/tap remains the
  // only way to reach the error snackbar there.
  bool get _hoverCapable =>
      kIsWeb &&
      defaultTargetPlatform != TargetPlatform.iOS &&
      defaultTargetPlatform != TargetPlatform.android;

  @override
  Widget build(BuildContext context) {
    final colors = CometChatThemeHelper.getColorPalette(context);
    // Image / video render as square tiles; audio keeps the legacy wide card;
    // plain files get the state-driven card (status inside the icon box).
    final bool isMedia = tile.isImage || tile.isVideo;
    final bool isFile = !isMedia && !tile.isAudio;
    final Widget body = isMedia
        ? _mediaTile(context, colors)
        : isFile
        ? _fileCard(context, colors)
        : _AudioTileCard(
            key: ValueKey('cc_audio_tile_${tile.fileId}'),
            tile: tile,
            height: heightFor(context),
            style: style,
          );
    final radius = BorderRadius.circular(
      style?.tileBorderRadius ?? (isMedia ? 10 : 12),
    );
    // Audio and file cards show status inside their leading icon — the
    // whole-tile scrim overlay is media-only.
    final overlay = isMedia ? _statusOverlay(colors) : null;

    // Outer padding lets the corner badge overflow the tile bounds. The
    // Align lets the Stack shrink-wrap the body instead of stretching to the
    // tray's (taller) tight cross-axis constraint — otherwise the
    // Positioned.fill overlay paints past the 64px body and media tiles read
    // taller than the file/audio cards in uploading/failed states.
    final tileTree = Padding(
      padding: const EdgeInsets.only(top: 6, right: 6),
      child: Align(
        alignment: Alignment.topLeft,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              // A failed (network) tile retries in place on tap — the retry
              // affordance lives inside the tile. A rejected (non-retryable)
              // tile surfaces its reason via the informational snackbar, but
              // only where there's no hover: on desktop web the tooltip already
              // says why, so a tap-snackbar is redundant. Gated on
              // [_hoverCapable] rather than kIsWeb — a mobile browser is kIsWeb
              // yet never hovers, so tap must still explain there.
              // Non-error media tiles open the preview.
              onTap: tile.hasError
                  ? (tile.status == AttachmentTileStatus.failed
                        ? onRetry
                        : (_hoverCapable ? null : onErrorInteract))
                  : (isMedia ? onTap : null),
              child: body,
            ),
            if (overlay != null)
              // IgnorePointer: the overlay is a coloured Container (hit-testable)
              // filling the tile ABOVE the GestureDetector, so without this it
              // swallowed every tap on an errored/uploading media tile — the
              // error icon showed but tapping did nothing.
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(borderRadius: radius, child: overlay),
                ),
              ),
            // The remove/cancel badge is always visible (web included) so it's
            // discoverable without hovering — cancels the upload if in flight,
            // then removes the tile.
            Positioned(top: -6, right: -6, child: _removeBadge()),
          ],
        ),
      ),
    );

    // Hover-only affordance on desktop web: a plain tooltip with the error
    // reason. It IS the explanation there — a rejected tile shows no snackbar
    // on tap when hover is available (see the tap handler above). Elsewhere
    // (native, mobile browsers) there's no hover, so tap surfaces the snackbar.
    if (_hoverCapable && tile.hasError) {
      return Tooltip(
        message: tile.errorMessage ?? Translations.of(context).uploadFailed,
        waitDuration: const Duration(milliseconds: 300),
        // The tray sits at the bottom of the composer; show the bubble above the
        // tile (toward the message area) so it isn't pinned to the screen edge
        // on web.
        preferBelow: false,
        child: tileTree,
      );
    }
    return tileTree;
  }

  /// Centered state overlay on a dark scrim: determinate progress while
  /// uploading, an error indicator on failure (tap = retry) / rejection.
  /// Used by media (image / video) tiles only — audio and file cards render
  /// status inside their leading icon instead.
  Widget? _statusOverlay(CometChatColorPalette colors) {
    final scrim = style?.scrimColor ?? Colors.black38;
    final progress = style?.progressColor ?? Colors.white;
    switch (tile.status) {
      case AttachmentTileStatus.uploading:
        final pct = tile.percent;
        return Container(
          color: scrim,
          alignment: Alignment.center,
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              // Indeterminate until the first progress event arrives.
              value: pct > 0 ? pct / 100 : null,
              strokeWidth: 3,
              backgroundColor: progress.withValues(alpha: 0.24),
              valueColor: AlwaysStoppedAnimation<Color>(progress),
            ),
          ),
        );
      case AttachmentTileStatus.failed:
        // Tapping anywhere on the tile (handled by the outer GestureDetector)
        // shows the error snackbar, which carries the retry action — the icon
        // itself is just a static indicator.
        return Container(
          color: scrim,
          alignment: Alignment.center,
          child: SvgPicture.asset(
            kAttachmentRetryIconAsset,
            width: 28,
            height: 28,
            package: kAttachmentIconPackage,
          ),
        );
      case AttachmentTileStatus.rejected:
        return Container(
          color: scrim,
          alignment: Alignment.center,
          child: SvgPicture.asset(
            kAttachmentErrorIconAsset,
            width: 28,
            height: 28,
            package: kAttachmentIconPackage,
          ),
        );
      case AttachmentTileStatus.done:
        return null;
    }
  }

  // ---- media (image / video) : square thumbnail ----------------------------

  Widget _mediaTile(BuildContext context, CometChatColorPalette colors) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: heightFor(context),
        height: heightFor(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _thumbWidget(colors),
            if (tile.isVideo)
              const Center(
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: Colors.black45,
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            if (tile.isVideo &&
                tile.durationMillis != null &&
                style?.showVideoDuration != false)
              Positioned(
                left: 3,
                bottom: 3,
                child: _durationPill(
                  Duration(milliseconds: tile.durationMillis!),
                ),
              ),
            if (_isGif) Positioned(left: 3, top: 3, child: _gifTag()),
          ],
        ),
      ),
    );
  }

  /// True for animated GIF tiles (by mime, falling back to the extension).
  bool get _isGif =>
      tile.mimeType.toLowerCase() == 'image/gif' ||
      tile.name.toLowerCase().endsWith('.gif');

  /// The "GIF" corner tag — translucent black pill with white uppercase text,
  /// top-start of the thumbnail (same chrome idiom as the duration pill).
  Widget _gifTag() => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Text(
        'GIF',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: 0.5,
        ),
      ),
    ),
  );

  /// A small bottom-start `m:ss` pill on a video thumbnail.
  Widget _durationPill(Duration d) {
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          '$m:$s',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ).merge(style?.durationChipTextStyle),
        ),
      ),
    );
  }

  /// Thumbnail: server URL → network image; local path (staging) → cross-platform
  /// file image; otherwise a type icon. Audio always shows the centered icon.
  Widget _thumbWidget(CometChatColorPalette colors) {
    if (tile.isAudio) {
      final base = colors.primary ?? const Color(0xFF6C5CE7);
      final lightA = Color.lerp(base, Colors.white, 0.46) ?? base;
      final lightB = Color.lerp(base, Colors.white, 0.30) ?? base;
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [lightA, lightB],
          ),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.audiotrack, color: base, size: 26),
      );
    }
    final url = tile.thumbUrl;
    if (url != null && url.isNotEmpty) {
      // A staged video's thumbUrl is always its LOCAL source — a file path
      // (native) or a blob: URL (web bytes) — never the remote CDN url, so
      // there's no poster image to fetch. Render a real first frame instead
      // of trying (and failing) to load the video file itself as an image.
      if (tile.isVideo) {
        return CometChatVideoFirstFrame(
          key: ValueKey('cc_video_thumb_${tile.fileId}'),
          source: url,
          fallback: _typeIconFill(colors),
        );
      }
      // http(s) CDN urls and web blob: object urls both load via the network
      // image; the html-element fallback keeps CanvasKit working when the CDN
      // response lacks CORS headers (which would otherwise blank the preview).
      if (url.startsWith('http') || url.startsWith('blob:')) {
        return Image.network(
          url,
          fit: BoxFit.cover,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          // Placeholder until the first frame decodes (covers the slow-
          // network waiting phase before any HTTP chunk arrives).
          frameBuilder: (context, child, frame, wasSync) {
            if (wasSync || frame != null) return child;
            return _typeIconFill(colors);
          },
          errorBuilder: (_, _, _) => _typeIconFill(colors),
        );
      }
      if (tile.isImage) {
        return platform_image.buildFileImage(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _typeIconFill(colors),
        );
      }
    }
    return _typeIconFill(colors);
  }

  // Legacy-look holder (same art as CometChatImageBubble's placeholder) when
  // a staged image/video tile has nothing to preview.
  Widget _typeIconFill(CometChatColorPalette colors) =>
      const CometChatMediaPlaceholder(glyphWidth: 26);

  // ---- file : state-driven wide card (reference mobile design) -------------

  Widget _fileCard(BuildContext context, CometChatColorPalette colors) {
    final bool hasError = tile.hasError;

    return Container(
      key: const Key('cometchat_attachment_file_card'),
      width: scaledDimension(context, 200),
      height: heightFor(context),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: style?.tileBackgroundColor ?? colors.background1,
        borderRadius: BorderRadius.circular(style?.tileBorderRadius ?? 12),
        border: Border.all(
          color: hasError
              ? (style?.errorBorderColor ?? colors.error ?? Colors.red)
              : (style?.tileBorderColor ??
                    colors.borderDefault ??
                    colors.neutral200 ??
                    Colors.black12),
        ),
      ),
      child: Row(
        children: [
          _fileIconBox(context, colors),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ).merge(style?.nameTextStyle),
                ),
                const SizedBox(height: 2),
                _fileSubtitle(context, colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The 40×40 type-badge container (full-colour SVG icon). Upload state renders
  /// *inside* it: a dark scrim with a white spinner (uploading) or a red badge
  /// with a refresh / "!" glyph (failed / rejected).
  Widget _fileIconBox(BuildContext context, CometChatColorPalette colors) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(style?.iconBorderRadius ?? 10),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: attachmentSvgIcon(
                fileName: tile.name,
                mimeType: tile.mimeType,
                size: 32,
              ),
            ),
            if (tile.status != AttachmentTileStatus.done)
              Container(
                color: style?.scrimColor ?? Colors.black38,
                alignment: Alignment.center,
                child: _fileIconStatusChild(colors),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fileIconStatusChild(CometChatColorPalette colors) {
    final progress = style?.progressColor ?? Colors.white;
    switch (tile.status) {
      case AttachmentTileStatus.uploading:
        final pct = tile.percent;
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            // Indeterminate until the first progress event arrives.
            value: pct > 0 ? pct / 100 : null,
            strokeWidth: 2.4,
            backgroundColor: progress.withValues(alpha: 0.24),
            valueColor: AlwaysStoppedAnimation<Color>(progress),
          ),
        );
      case AttachmentTileStatus.failed:
        return SvgPicture.asset(
          kAttachmentRetryIconAsset,
          width: 20,
          height: 20,
          package: kAttachmentIconPackage,
        );
      case AttachmentTileStatus.rejected:
        return SvgPicture.asset(
          kAttachmentErrorIconAsset,
          width: 20,
          height: 20,
          package: kAttachmentIconPackage,
        );
      case AttachmentTileStatus.done:
        return const SizedBox.shrink();
    }
  }

  /// Status subtitle: type label while uploading / done, localized error text
  /// in [CometChatColorPalette.error] for the two failure states.
  Widget _fileSubtitle(BuildContext context, CometChatColorPalette colors) {
    final errorStyle = TextStyle(
      fontSize: 11,
      color: style?.errorBorderColor ?? colors.error ?? Colors.red,
    ).merge(style?.errorTextStyle);
    switch (tile.status) {
      case AttachmentTileStatus.failed:
        return Text(
          Translations.of(context).tapToRetry,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: errorStyle,
        );
      case AttachmentTileStatus.rejected:
        return Text(
          Translations.of(context).uploadFailed,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: errorStyle,
        );
      case AttachmentTileStatus.uploading:
      case AttachmentTileStatus.done:
        return Text(
          _typeLabel(),
          style: TextStyle(
            fontSize: 11,
            color: colors.textSecondary,
          ).merge(style?.subtitleTextStyle),
        );
    }
  }

  String _typeLabel() {
    final ext = FileTypeStyle.extOf(tile.name);
    return (ext.isEmpty ? 'file' : ext).toUpperCase();
  }

  // ---- remove badge ---------------------------------------------------------

  /// The permanent top-right ✕ — cancels the upload if in flight, then removes
  /// the tile from the tray.
  Widget _removeBadge() {
    return Semantics(
      button: true,
      label: Translations.of(context).remove,
      child: GestureDetector(
        onTap: onCancelOrRemove,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: style?.removeBadgeBackgroundColor ?? Colors.black54,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.close,
            size: 12,
            color: style?.removeBadgeIconColor ?? Colors.white,
          ),
        ),
      ),
    );
  }
}

// ---- audio : inline player card (reference mobile design) ------------------

/// The staged-audio card: circular play/pause button, compact seek slider and
/// a "pos/total" clock, mirroring the received-audio row. Upload status lives
/// *inside* the play circle (scrim + spinner / red badge); the two failure
/// states swap the player row for the localized status subtitle. Playback
/// follows the `_AudioRow` pattern in [CometChatAudiosBubble]: a paused
/// [vp.VideoPlayerController] is initialized eagerly so the total duration
/// shows up front — local staging path natively, URL once uploaded (web).
class _AudioTileCard extends StatefulWidget {
  const _AudioTileCard({
    super.key,
    required this.tile,
    required this.height,
    this.style,
  });

  final AttachmentTile tile;
  final double height;
  final CometChatAttachmentTrayStyle? style;

  @override
  State<_AudioTileCard> createState() => _AudioTileCardState();
}

class _AudioTileCardState extends State<_AudioTileCard> {
  vp.VideoPlayerController? _player;
  bool _playbackFailed = false;
  String? _src; // source the current player was built for

  // Coordinates with every other audio player in the app (voice notes,
  // sent audio-file rows, other staged tray tiles) via the shared broadcast
  // stream so only one plays at a time.
  late final int _tag = tile.fileId.hashCode;
  StreamSubscription<AudioBubbleEvents>? _eventSub;

  AttachmentTile get tile => widget.tile;
  CometChatAttachmentTrayStyle? get style => widget.style;

  @override
  void initState() {
    super.initState();
    _ensurePlayer();
    _eventSub = AudioBubbleStream().stream.listen((event) {
      if (event.id != _tag && event.action == AudioBubbleActions.pausePlayer) {
        _player?.pause();
      }
    });
  }

  @override
  void didUpdateWidget(_AudioTileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The source can appear late (web bytes-staging gets a URL only once the
    // upload completes), and an upload failure should silence playback.
    _ensurePlayer();
    if (tile.status == AttachmentTileStatus.failed ||
        tile.status == AttachmentTileStatus.rejected) {
      final p = _player;
      if (p != null && p.value.isInitialized && p.value.isPlaying) p.pause();
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _player?.removeListener(_onTick);
    _player?.dispose();
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  /// Creates + initializes the (paused) player so the duration is known.
  /// Failure is non-fatal — the card just shows an inert slider.
  Future<void> _ensurePlayer() async {
    final src = tile.thumbUrl;
    if (src == null || src.isEmpty || src == _src) return;
    _src = src;
    _player?.removeListener(_onTick);
    await _player?.dispose();
    _player = null;
    _playbackFailed = false;

    final c = (src.startsWith('http') || src.startsWith('blob:'))
        ? vp.VideoPlayerController.networkUrl(Uri.parse(src))
        : platform_file.videoControllerForPath(src);
    if (c == null) {
      if (mounted) setState(() => _playbackFailed = true);
      return;
    }
    _player = c;
    c.addListener(_onTick);
    try {
      await c.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _playbackFailed = true);
    }
  }

  Future<void> _togglePlay() async {
    final c = _player;
    if (c == null || !c.value.isInitialized || _playbackFailed) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      AudioBubbleStream().controller.sink.add(
        AudioBubbleEvents(id: _tag, action: AudioBubbleActions.pausePlayer),
      );
      await c.play();
    }
  }

  /// Reference clock format: zero-padded minutes and seconds ("00:32").
  String _fmt(Duration d) {
    final m = (d.inMinutes).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = CometChatThemeHelper.getColorPalette(context);
    final bool hasError = tile.hasError;

    return Container(
      key: const Key('cometchat_attachment_audio_card'),
      width: 240,
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: style?.tileBackgroundColor ?? colors.background1,
        borderRadius: BorderRadius.circular(style?.tileBorderRadius ?? 12),
        border: Border.all(
          color: hasError
              ? (style?.errorBorderColor ?? colors.error ?? Colors.red)
              : (style?.tileBorderColor ??
                    colors.borderDefault ??
                    colors.neutral200 ??
                    Colors.black12),
        ),
      ),
      child: Row(
        children: [
          _playCircle(colors),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ).merge(style?.nameTextStyle),
                ),
                if (hasError)
                  _errorSubtitle(context, colors)
                else ...[
                  _seekBar(colors),
                  _clock(colors),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The 40×40 play/pause circle. Upload state renders *inside* it, matching
  /// the file card's icon-box treatment.
  Widget _playCircle(CometChatColorPalette colors) {
    final playing = _player?.value.isPlaying ?? false;
    return Semantics(
      button: true,
      label: playing
          ? Translations.of(context).pause
          : Translations.of(context).play,
      child: GestureDetector(
        onTap: tile.status == AttachmentTileStatus.done ? _togglePlay : null,
        child: ClipOval(
          child: Container(
            width: 40,
            height: 40,
            color:
                style?.playButtonColor ??
                colors.primary ??
                const Color(0xFF6852D6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Icon(
                    playing ? Icons.pause : Icons.play_arrow_rounded,
                    size: 24,
                    color: style?.playIconColor ?? Colors.white,
                  ),
                ),
                if (tile.status != AttachmentTileStatus.done)
                  Container(
                    color: style?.scrimColor ?? Colors.black38,
                    alignment: Alignment.center,
                    child: _circleStatusChild(colors),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleStatusChild(CometChatColorPalette colors) {
    final progress = style?.progressColor ?? Colors.white;
    switch (tile.status) {
      case AttachmentTileStatus.uploading:
        final pct = tile.percent;
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            // Indeterminate until the first progress event arrives.
            value: pct > 0 ? pct / 100 : null,
            strokeWidth: 2.4,
            backgroundColor: progress.withValues(alpha: 0.24),
            valueColor: AlwaysStoppedAnimation<Color>(progress),
          ),
        );
      case AttachmentTileStatus.failed:
        return SvgPicture.asset(
          kAttachmentRetryIconAsset,
          width: 20,
          height: 20,
          package: kAttachmentIconPackage,
        );
      case AttachmentTileStatus.rejected:
        return SvgPicture.asset(
          kAttachmentErrorIconAsset,
          width: 20,
          height: 20,
          package: kAttachmentIconPackage,
        );
      case AttachmentTileStatus.done:
        return const SizedBox.shrink();
    }
  }

  Widget _errorSubtitle(BuildContext context, CometChatColorPalette colors) {
    final text = tile.status == AttachmentTileStatus.failed
        ? Translations.of(context).tapToRetry
        : Translations.of(context).uploadFailed;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: style?.errorBorderColor ?? colors.error ?? Colors.red,
        ).merge(style?.errorTextStyle),
      ),
    );
  }

  Widget _seekBar(CometChatColorPalette colors) {
    final value = _player?.value;
    final ready = (value?.isInitialized ?? false) && !_playbackFailed;
    final maxMs = ready ? value!.duration.inMilliseconds.toDouble() : 0.0;
    final posMs = ready
        ? value!.position.inMilliseconds.toDouble().clamp(0.0, maxMs)
        : 0.0;
    final canSeek =
        ready && maxMs > 0 && tile.status == AttachmentTileStatus.done;

    return SizedBox(
      height: 16,
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 2,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          activeTrackColor: style?.sliderActiveColor ?? colors.primary,
          inactiveTrackColor:
              style?.sliderInactiveColor ??
              colors.neutral300 ??
              colors.neutral200,
          disabledActiveTrackColor:
              style?.sliderInactiveColor ??
              colors.neutral300 ??
              colors.neutral200,
          disabledInactiveTrackColor:
              style?.sliderInactiveColor ?? colors.neutral200,
          thumbColor: colors.white,
          disabledThumbColor: colors.white,
        ),
        child: Slider(
          value: posMs,
          max: maxMs > 0 ? maxMs : 1,
          onChanged: canSeek
              ? (v) => _player!.seekTo(Duration(milliseconds: v.round()))
              : null,
        ),
      ),
    );
  }

  Widget _clock(CometChatColorPalette colors) {
    final value = _player?.value;
    final ready = (value?.isInitialized ?? false) && !_playbackFailed;
    final text = ready
        ? '${_fmt(value!.position)}/${_fmt(value.duration)}'
        : '00:00/--:--';
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        color: colors.textSecondary,
      ).merge(style?.clockTextStyle),
    );
  }
}
