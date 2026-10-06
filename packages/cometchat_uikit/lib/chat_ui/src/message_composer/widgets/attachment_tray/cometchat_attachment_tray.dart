import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// The composer strip that shows staged attachment tiles, rendered directly
/// above the input row. One [CometChatAttachmentTile] per `fileId` (square
/// thumbnails for image/video, an inline player card for audio, and a
/// state-driven wide card for files — upload status inside the leading
/// icon plus a status subtitle). Driven by an
/// [AttachmentTrayController]; rebuilds as upload events arrive and renders
/// nothing while empty. Sending is handled by the composer's own send button.
class CometChatAttachmentTray extends StatelessWidget {
  // Deprecated in 6.2.0: no effect, removed in 7.0.0.

  /// Add hook.
  @Deprecated(
    'Has no effect. The tray has no add button. Will be removed in 7.0.0.',
  )
  final VoidCallback? onAdd;

  /// Send hook.
  @Deprecated(
    'Has no effect. The tray has no send button; the composer calls onAttachmentTraySend. Will be removed in 7.0.0.',
  )
  final VoidCallback? onSend;

  const CometChatAttachmentTray({
    super.key,
    required this.controller,
    this.style,
    this.attachmentErrorAlertStyle,
    this.attachmentErrorSnackBarBuilder,
    this.onAttachmentErrorTap,
    this.onAdd,
    this.onSend,
  });

  final AttachmentTrayController controller;

  ///[style] customizes the tray's tiles — null fields fall back to theme
  ///defaults. Also reachable via
  ///[CometChatMessageComposerStyle.attachmentTrayStyle].
  final CometChatAttachmentTrayStyle? style;

  ///[attachmentErrorAlertStyle] styles the alert shown when tapping a tile that
  ///was rejected. Not raised on desktop web, where hovering already reveals a
  ///plain tooltip with the same reason.
  final CometChatAttachmentErrorAlertStyle? attachmentErrorAlertStyle;

  ///[attachmentErrorSnackBarBuilder] fully replaces the default error snackbar.
  ///Receives the errored [AttachmentTile]. The snackbar is informational only
  ///(it shows the failure reason) — retry is offered in the tile itself, so a
  ///`failed` tile is retried by tapping it, not from the snackbar.
  final SnackBar Function(BuildContext context, AttachmentTile tile)?
  attachmentErrorSnackBarBuilder;

  ///[onAttachmentErrorTap] fully overrides the tap/hover action on an errored
  ///tile (skips showing the default/custom snackbar entirely).
  final void Function(BuildContext context, AttachmentTile tile)?
  onAttachmentErrorTap;

  void _showError(BuildContext context, AttachmentTile tile) {
    if (onAttachmentErrorTap != null) {
      onAttachmentErrorTap!(context, tile);
      return;
    }
    if (attachmentErrorSnackBarBuilder != null) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(attachmentErrorSnackBarBuilder!(context, tile));
      return;
    }
    CometChatAttachmentErrorSnackBar.show(
      context,
      tile: tile,
      style: attachmentErrorAlertStyle,
    );
  }

  /// Opens the fullscreen viewer over the tray's visual-media tiles (image /
  /// video) starting at [tapped]. Audio tiles have their own inline player
  /// and file tiles are not previewable.
  void _openPreview(BuildContext context, AttachmentTile tapped) {
    final mediaTiles = controller.tiles
        .where((t) => t.isImage || t.isVideo)
        .toList();
    final items = <Attachment>[];
    var start = 0;
    for (final t in mediaTiles) {
      // Local-first: the staged local file path (native) or blob URL (web) is
      // the reliable preview source. The freshly-presigned remote fileUrl may
      // not be fetchable yet (it isn't secure-media-transformed), which made
      // the tray preview fail on both mobile and web.
      final url = (t.thumbUrl != null && t.thumbUrl!.isNotEmpty)
          ? t.thumbUrl!
          : (t.attachment?.fileUrl ?? '');
      if (url.isEmpty) continue;
      // Index among the items actually added (empty-URL tiles are skipped),
      // so the viewer opens on the tapped tile rather than a shifted one.
      if (t.fileId == tapped.fileId) start = items.length;
      final ext = t.name.contains('.') ? t.name.split('.').last : '';
      items.add(Attachment(url, t.name, ext, t.mimeType, t.size));
    }
    if (items.isEmpty) return;
    CometChatMediaViewer.open(
      context,
      items,
      startIndex: start.clamp(0, items.length - 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final tiles = controller.tiles;
        if (tiles.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: SizedBox(
            height: 78,
            child: _HorizontalWheelScroller(
              builder: (context, scrollController) => ListView.separated(
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: tiles.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final t = tiles[i];
                  final previewable = t.isImage || t.isVideo;
                  return CometChatAttachmentTile(
                    tile: t,
                    onCancelOrRemove: () => controller.cancelOrRemove(t.fileId),
                    onTap: previewable ? () => _openPreview(context, t) : null,
                    // Rejected (non-retryable) tiles surface their reason via
                    // the informational snackbar; failed (network) tiles retry
                    // in place when tapped.
                    onErrorInteract: t.status == AttachmentTileStatus.rejected
                        ? () => _showError(context, t)
                        : null,
                    onRetry: t.status == AttachmentTileStatus.failed
                        ? () => controller.retry(t.fileId)
                        : null,
                    style: style,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Makes a horizontal, single-axis list scrollable on desktop web/desktop:
/// a plain vertical mouse wheel only drives a Scrollable along its own axis
/// (`dy` for vertical, `dx` for horizontal), so a mouse wheel does nothing
/// over a purely horizontal list by default — only a trackpad's genuine `dx`
/// (shift+scroll / two-finger horizontal swipe) worked. This redirects a
/// vertical wheel's `dy` into horizontal scroll; also allows mouse
/// click-drag (excluded from [MaterialScrollBehavior]'s drag devices by
/// default, to avoid clashing with text selection).
class _HorizontalWheelScroller extends StatefulWidget {
  const _HorizontalWheelScroller({required this.builder});

  /// Builds the scrollable child, wired to the controller this widget owns.
  final Widget Function(BuildContext context, ScrollController controller)
  builder;

  @override
  State<_HorizontalWheelScroller> createState() =>
      _HorizontalWheelScrollerState();
}

class _HorizontalWheelScrollerState extends State<_HorizontalWheelScroller> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) return;
    // A horizontal drag/swipe already arrives as scrollDelta.dx and needs no
    // help; only a vertical wheel's dy needs redirecting onto this axis.
    final delta = event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    if (delta == 0) return;
    final target = (_controller.offset + delta).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    _controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: ScrollConfiguration(
        behavior: _MouseDragScrollBehavior(),
        child: widget.builder(context, _controller),
      ),
    );
  }
}

class _MouseDragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}
