import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';

import '../../l10n/translations.dart';
import '../clean_architecture/core/utils/platform_utils/platform_file_utils.dart'
    as platform;
import '../clean_architecture/core/utils/platform_utils/platform_image_utils.dart'
    as platform_image;
import 'offline_gate.dart';
import 'offline_hub.dart';
import 'offline_hub_event.dart';

/// Media from the device on the offline path (W5, G9, BEH-MEDIA-13).
///
/// Order: the attachment's cached bytes (`attachment.localPath`, else the
/// SDK's `getCachedMediaPath`) → the URL → a placeholder with the file's name
/// and size and "Available when online". Re-resolved on the hub's
/// `MediaReady`. The kit keeps no media cache of its own. With offline off
/// every call returns null at once, so today's media paths run unchanged.
abstract final class OfflineMedia {
  /// Test seam: replaces `CometChat.getCachedMediaPath`.
  @visibleForTesting
  static Future<String?> Function(BaseMessage message)? debugCachedMediaPath;

  /// Test seam: replaces the "is this path usable" check (file exists).
  @visibleForTesting
  static bool Function(String path)? debugIsUsable;

  /// Whether offline is on for this operation (the gate, read once).
  static bool get enabled => OfflineGate.isOn();

  /// [path] if it points at bytes this platform can render, else null.
  static String? usable(String? path) {
    if (path == null || path.isEmpty) return null;
    final check = debugIsUsable;
    if (check != null) return check(path) ? path : null;
    if (kIsWeb) return path.startsWith('blob:') ? path : null;
    return platform.isLocalFileAvailable(path) ? path : null;
  }

  /// The attachment's cached bytes known without an SDK call, or null (always
  /// null with offline off).
  static String? localPathOf(Attachment attachment, {bool? offlineOn}) {
    if (!(offlineOn ?? OfflineGate.isOn())) return null;
    return usable(attachment.localPath);
  }

  /// Resolves [attachment]'s cached bytes: `localPath`, else the SDK's cache.
  /// Null when not cached, and always null with offline off. A path found in
  /// the SDK's cache is kept on the attachment for this session (a hint the
  /// SDK re-resolves on every read; never persisted).
  static Future<String?> resolve(Attachment attachment) async {
    if (!OfflineGate.isOn()) return null;
    final known = usable(attachment.localPath);
    if (known != null) return known;
    if (attachment.fileUrl.isEmpty) return null;
    final probe = MediaMessage(
      receiverUid: '',
      type: CometChatMessageType.file,
      receiverType: CometChatReceiverType.user,
      attachment: attachment,
    );
    String? path;
    try {
      final lookup = debugCachedMediaPath ?? CometChat.getCachedMediaPath;
      path = usable(await lookup(probe));
    } catch (_) {
      path = null;
    }
    if (path != null) attachment.localPath = path;
    return path;
  }

  /// [resolve] for a bubble that has only the media URL (voice notes).
  static Future<String?> resolveUrl(String? url) {
    if (url == null || url.isEmpty) return Future<String?>.value(null);
    return resolve(Attachment(url, '', '', '', null));
  }

  /// Web: what a download fetches — the saved copy ([local], a `blob:` URL)
  /// when there is one, else the link. [local] is always null with offline
  /// off, so the link is used as before.
  static String webDownloadSource(String url, String? local) =>
      local != null && local.isNotEmpty ? local : url;

  /// Most URLs [rememberedUrl] keeps (oldest dropped first).
  static const int _memoCap = 256;

  /// URL → its saved copy, or null for "known not saved" (offline on only).
  static final Map<String, String?> _memo = <String, String?>{};

  /// Bumped when the memo is cleared, so a lookup that started before does
  /// not write a stale answer after it.
  static int _memoEpoch = 0;

  /// Bumped when a download lands, so a "not saved" answer from a lookup that
  /// started before it is not written after it.
  static int _downloadEpoch = 0;
  static StreamSubscription<OfflineHubEvent>? _memoWatch;

  /// What an earlier [resolveUrlRemembered] found for [url] in this session:
  /// `(true, path)` with the saved copy, `(true, null)` for "not saved", or
  /// `(false, null)` when unknown. Lets a widget rebuilt with a new state start
  /// on the answer with no lookup. Always unknown with offline off.
  static (bool, String?) rememberedUrl(String? url) {
    if (url == null || url.isEmpty || !OfflineGate.isOn()) return (false, null);
    if (!_memo.containsKey(url)) return (false, null);
    final path = _memo.remove(url);
    if (path != null && usable(path) == null) return (false, null);
    _memo[url] = path; // most recently used
    return (true, path);
  }

  /// [resolveUrl], remembering the answer for [rememberedUrl]. The memo is
  /// cleared on a session end (logout, user switch) and a cache reset, and its
  /// "not saved" answers are dropped when any download lands.
  static Future<String?> resolveUrlRemembered(String? url) async {
    // Watch before the first lookup starts, so a session end or cache reset
    // while it runs bumps the epoch and its answer is not written after.
    if (url != null && url.isNotEmpty && OfflineGate.isOn()) _watchMemo();
    final epoch = _memoEpoch;
    final downloads = _downloadEpoch;
    final path = await resolveUrl(url);
    if (url != null &&
        url.isNotEmpty &&
        epoch == _memoEpoch &&
        (path != null || downloads == _downloadEpoch) &&
        OfflineGate.isOn()) {
      _memo.remove(url);
      _memo[url] = path;
      if (_memo.length > _memoCap) _memo.remove(_memo.keys.first);
    }
    return path;
  }

  static void _watchMemo() {
    _memoWatch ??= OfflineHub.instance.events.listen((e) {
      if (e is SessionEnded || e is CacheReset) {
        _memoEpoch++;
        _memo.clear();
      } else if (e is MediaReady) {
        _downloadEpoch++;
        _memo.removeWhere((_, path) => path == null);
      }
    });
  }

  /// Test-only: empties the memo of [rememberedUrl] and drops its hub watch,
  /// so the next lookup is the first of a session.
  @visibleForTesting
  static void debugClearMemo() {
    _memoEpoch++;
    _memo.clear();
    _memoWatch?.cancel();
    _memoWatch = null;
  }

  /// Test-only: how many URLs the memo of [rememberedUrl] holds.
  @visibleForTesting
  static int get debugMemoLength => _memo.length;

  /// Calls [onReady] on every hub `MediaReady` (a download landed); null with
  /// offline off. The caller cancels the subscription in `dispose`.
  static StreamSubscription<OfflineHubEvent>? listenMediaReady(
    void Function() onReady,
  ) {
    if (!OfflineGate.isOn()) return null;
    return OfflineHub.instance.events
        .where((e) => e is MediaReady)
        .listen((_) => onReady());
  }
}

/// Renders [attachment] for the offline path: the cached bytes when present,
/// else [network] (today's URL widget). While offline is on, a URL that fails
/// to load shows [OfflineMediaPlaceholder] instead of [network]'s error art;
/// [network] receives that fallback as its `offlineError` argument (null when
/// offline is off, so today's error art stays).
class OfflineMediaImage extends StatefulWidget {
  /// Creates the image for [attachment].
  const OfflineMediaImage({
    super.key,
    required this.attachment,
    required this.network,
    this.fit = BoxFit.cover,
    this.placeholderColor,
  });

  /// The attachment to render.
  final Attachment attachment;

  /// Today's URL widget; `offlineError` replaces its error art when non-null.
  final Widget Function(BuildContext context, Widget? offlineError) network;

  /// How the local image fills its box.
  final BoxFit fit;

  /// Background of the offline placeholder.
  final Color? placeholderColor;

  @override
  State<OfflineMediaImage> createState() => _OfflineMediaImageState();
}

class _OfflineMediaImageState extends State<OfflineMediaImage> {
  late final bool _on = OfflineGate.isOn();
  String? _path;
  StreamSubscription<OfflineHubEvent>? _ready;

  @override
  void initState() {
    super.initState();
    if (!_on) return;
    _path = OfflineMedia.localPathOf(widget.attachment, offlineOn: true);
    if (_path == null) _resolve();
    _ready = OfflineMedia.listenMediaReady(_resolve);
  }

  @override
  void didUpdateWidget(OfflineMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_on && !identical(oldWidget.attachment, widget.attachment)) {
      _path = OfflineMedia.localPathOf(widget.attachment, offlineOn: true);
      if (_path == null) _resolve();
    }
  }

  Future<void> _resolve() async {
    final path = await OfflineMedia.resolve(widget.attachment);
    if (!mounted || path == null || path == _path) return;
    setState(() => _path = path);
  }

  @override
  void dispose() {
    _ready?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    if (!_on) return widget.network(context, null);
    if (path != null) {
      if (kIsWeb) return Image.network(path, fit: widget.fit);
      return platform_image.buildFileImage(
        path,
        fit: widget.fit,
        errorBuilder: (context, _, _) => widget.network(
          context,
          OfflineMediaPlaceholder(
            attachment: widget.attachment,
            backgroundColor: widget.placeholderColor,
          ),
        ),
      );
    }
    return widget.network(
      context,
      OfflineMediaPlaceholder(
        attachment: widget.attachment,
        backgroundColor: widget.placeholderColor,
      ),
    );
  }
}

/// Placeholder for media not on the device while it cannot be loaded: an
/// icon, the file's name and size, and "Available when online".
class OfflineMediaPlaceholder extends StatelessWidget {
  /// Creates the placeholder for [attachment].
  const OfflineMediaPlaceholder({
    super.key,
    required this.attachment,
    this.backgroundColor,
  });

  /// The attachment that is not on the device.
  final Attachment attachment;

  /// Background colour.
  final Color? backgroundColor;

  static String _size(int? b) {
    if (b == null || b <= 0) return '';
    if (b >= 1 << 20) return '${(b / (1 << 20)).toStringAsFixed(1)} MB';
    if (b >= 1 << 10) return '${(b / (1 << 10)).round()} KB';
    return '$b B';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final size = _size(attachment.fileSize);
    final name = attachment.fileName;
    return Container(
      color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(6),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, color: muted, size: 24),
            if (name.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            if (size.isNotEmpty)
              Text(size, style: TextStyle(color: muted, fontSize: 11)),
            Text(
              Translations.of(context).mediaAvailableWhenOnline,
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
