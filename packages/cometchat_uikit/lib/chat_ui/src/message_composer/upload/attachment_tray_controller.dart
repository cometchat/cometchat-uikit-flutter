// @dart=3.0

import 'dart:async';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart';

import '../../../../shared_ui/src/clean_architecture/core/utils/attachment_utils.dart';
import '../../../../shared_ui/src/logging/cometchat_log.dart';
import '../../../../shared_ui/src/clean_architecture/core/utils/platform_utils/platform_file_utils.dart'
    as platform;

enum AttachmentTileStatus { uploading, done, failed, rejected }

/// Thrown by [AttachmentTrayController.stage] when a batch cannot be staged at
/// all — the composer hasn't bound a conversation yet. The caller (composer)
/// surfaces [message] to the user so the failure isn't swallowed silently.
/// [cause] is the original error, when there is one.
class AttachmentStageException implements Exception {
  AttachmentStageException(this.message, [this.cause]);

  /// User-facing reason.
  final String message;

  /// The underlying error/exception, when there is one.
  final Object? cause;

  @override
  String toString() => 'AttachmentStageException: $message'
      '${cause != null ? ' (cause: $cause)' : ''}';
}

/// One staged item in the tray, keyed by the **app-supplied** `fileId`.
class AttachmentTile {
  AttachmentTile({
    required this.fileId,
    required this.name,
    required this.mimeType,
    required this.size,
    this.loaded = 0,
    this.status = AttachmentTileStatus.uploading,
    this.thumbUrl,
    this.attachment,
    this.durationMillis,
    this.errorMessage,
  });

  final String fileId;
  final String name;
  final String mimeType;
  final int size;

  /// Human-readable reason this tile failed/was rejected (from the SDK error);
  /// surfaced in the composer's error bar. Null while uploading/done.
  String? errorMessage;

  /// Video/audio playback length in milliseconds, probed from the local file at
  /// staging (null until known, or for non-media / probe failure).
  int? durationMillis;

  /// Bytes uploaded so far.
  int loaded;
  AttachmentTileStatus status;

  /// Local preview path while uploading; `attachment.fileUrl` once done.
  String? thumbUrl;

  /// Set on `onFileUploaded` — the message-ready attachment that gets sent.
  Attachment? attachment;

  int get percent =>
      size == 0 ? 0 : ((loaded / size) * 100).clamp(0, 100).round();

  /// Kind of the staged file, by the **same rule the send path uses**
  /// ([AttachmentUtils]) — mimeType OR extension. Classifying the tray on
  /// mimeType alone disagreed with what was actually sent: a `.m4v`/`.flac`
  /// picked up with a generic mimeType previewed as a plain file card but sent
  /// as video/audio, and an `.ogg` reported as `video/ogg` previewed as video
  /// but sent as audio.
  bool get isImage => AttachmentUtils.isImageOf(mimeType, name);
  bool get isVideo => AttachmentUtils.isVideoOf(mimeType, name);
  bool get isAudio => AttachmentUtils.isAudioOf(mimeType, name);

  /// True for a failed upload (retryable) or a rejected one (over the
  /// count/size limit — not retryable).
  bool get hasError =>
      status == AttachmentTileStatus.failed ||
      status == AttachmentTileStatus.rejected;
}

/// Owns the composer's staging model and drives the SDK's multi-upload surface:
/// a per-composer [UploadFileRequest] (`CometChat.createUploadFileRequest`).
///
/// One controller per composer instance. The controller **supplies each file's
/// id**, so a tile is rendered at 0% the instant a file is staged — no waiting
/// for the SDK to assign an id. The request's `getBatchId()` becomes the sent
/// message's `metadata.batchId` (and its `muid`) for optimistic reconciliation.
class AttachmentTrayController extends ChangeNotifier {
  AttachmentTrayController({this.receiverId, this.receiverType}) {
    _listener = _TrayUploadListener(this);
  }

  /// The conversation these uploads belong to — recipient `uid` / group `guid`
  /// and its kind (`'user'`/`'group'`). Captured on the [UploadFileRequest] when
  /// it is first created (the first [stage]). Mutable: the composer refreshes
  /// these from the live conversation right before each stage, and a
  /// conversation switch calls [clear], which drops the request so the next
  /// stage re-creates it with the current receiver.
  String? receiverId;
  String? receiverType;

  late final _TrayUploadListener _listener;

  /// The per-composer upload request (one batch). Created lazily on the first
  /// [stage] with the then-current receiver; dropped by [clear] / [dispose].
  UploadFileRequest? _request;

  /// The effective batch id (from the request). Also used as the sent message's
  /// grouping id. Null until the first stage.
  String? _batchId;
  String? get batchId => _batchId;

  int _tileSeq = 0;

  final List<AttachmentTile> _tiles = [];
  List<AttachmentTile> get tiles => List.unmodifiable(_tiles);

  String caption = '';
  bool _disposed = false;

  /// Send is enabled once ≥1 tile is `done`, none are `uploading`, and none
  /// are in an error state — a failed/rejected attachment must be retried or
  /// removed before the message can be sent.
  bool get canSend =>
      _tiles.any((t) => t.status == AttachmentTileStatus.done) &&
      !_tiles.any((t) => t.status == AttachmentTileStatus.uploading) &&
      !hasErrors;

  /// Max attachments per message, from the app settings cached by the SDK
  /// (`file.count.max`); the SDK default is 10.
  int get maxFileCount {
    try {
      return CometChat.getMaxAttachmentCount();
    } catch (_) {
      return 10;
    }
  }

  /// Tiles that count against [maxFileCount] — everything except rejected ones
  /// (mirrors the SDK's own count gate, which excludes rejected/cancelled).
  int get activeCount =>
      _tiles.where((t) => t.status != AttachmentTileStatus.rejected).length;

  /// How many more attachments can still be staged.
  int get remainingSlots {
    final left = maxFileCount - activeCount;
    return left > 0 ? left : 0;
  }

  /// False once the tray already holds [maxFileCount] attachments.
  bool get canAddMore => remainingSlots > 0;

  /// Staged tiles that failed to upload or were rejected — these stay in the
  /// tray; tapping (or, on web, hovering) the tile surfaces the reason via a
  /// snackbar.
  List<AttachmentTile> get errorTiles =>
      _tiles.where((t) => t.hasError).toList();

  /// True while any staged attachment is in an error state.
  bool get hasErrors => errorTiles.isNotEmpty;

  /// Max size per file in bytes (`file.size.max`; SDK default 100 MB).
  int get maxFileSize {
    try {
      return CometChat.getMaxAttachmentSize();
    } catch (_) {
      return 100 * 1024 * 1024;
    }
  }

  /// Byte-weighted aggregate [loaded, total] — never average percents.
  List<int> get aggregate {
    var loaded = 0, total = 0;
    for (final t in _tiles) {
      loaded += t.loaded;
      total += t.size;
    }
    return [loaded, total];
  }

  /// The attachments to send (done tiles, in order).
  List<Attachment> get doneAttachments => _tiles
      .where(
        (t) => t.status == AttachmentTileStatus.done && t.attachment != null,
      )
      .map((t) => t.attachment!)
      .toList();

  AttachmentTile? _byId(String fileId) {
    for (final t in _tiles) {
      if (t.fileId == fileId) return t;
    }
    return null;
  }

  /// Creates the upload request on first use, capturing the current receiver.
  /// The controller registers itself as the batch's global listener, so every
  /// per-file event lands here.
  UploadFileRequest _ensureRequest() {
    final req = _request ??= CometChat.createUploadFileRequest(
      receiverId!,
      receiverType!,
    )..addUploadListener(_listener);
    _batchId = req.getBatchId();
    return req;
  }

  /// Stage a batch via the SDK. Accumulates into the same batch (reuses the
  /// per-composer [UploadFileRequest]). The tile for each file is created
  /// immediately at 0% under the id this controller supplies; per-file progress
  /// then arrives through the upload listener.
  Future<void> stage(List<UploadFile> files) async {
    if (files.isEmpty) return;
    // Fail fast when the composer hasn't bound a conversation yet: presigning
    // without a receiver is rejected by the server once RBAC/SBAC is on, and an
    // early typed error gives a clear toast instead of an opaque server 4xx
    // mid-upload (R7).
    if ((receiverId ?? '').isEmpty || (receiverType ?? '').isEmpty) {
      throw AttachmentStageException(
        'No conversation context (receiverId/receiverType) for upload',
      );
    }
    ccLog(
      '🟦 [stage] files=${files.map((f) => "${f.name}|${f.mimeType}|size=${f.size}|path=${f.path}").toList()}',
    );

    final request = _ensureRequest();

    // Create every tile up front (at 0%) under the id we supply, then hand the
    // files to the SDK. Because the tile exists before any event fires, a fast
    // rejection always lands on an already-rendered tile — no buffering needed.
    final batch = <UploadAttachment>[];
    for (final f in files) {
      final id = 'tile_${_tileSeq++}';
      // Local preview while uploading: the file path where one exists
      // (mobile/desktop), else a browser object URL over the bytes (web picks/
      // paste/drop have no path). Revoked when the tile leaves the tray.
      final isMedia = f.mimeType.startsWith('image/') ||
          f.mimeType.startsWith('video/') ||
          f.mimeType.startsWith('audio/');
      final localThumb = (f.path != null && f.path!.isNotEmpty)
          ? f.path
          : (isMedia && f.bytes != null
              ? platform.objectUrlFromBytes(f.bytes!, f.mimeType)
              : null);
      final tile = AttachmentTile(
        fileId: id,
        name: f.name,
        mimeType: f.mimeType,
        size: f.size,
        thumbUrl: localThumb,
      );
      _tiles.add(tile);
      batch.add(UploadAttachment(id, f));

      // Extract the duration for video AND audio tiles from the local source
      // once (fire-and-forget; failure just omits it). Video uses it for the
      // m:ss chip; audio carries it into the sent message's metadata so the
      // received bubble can show the duration up front instead of the file
      // size (ENG-37180).
      if ((tile.isVideo || tile.isAudio) &&
          localThumb != null &&
          localThumb.isNotEmpty) {
        unawaited(_probeDuration(tile, localThumb));
      }
    }
    _safeNotify();

    // Hand the batch to the SDK. Per-file events arrive on the global listener
    // (_listener); passing it per-call too is fine — the SDK dedupes by identity.
    request.uploadAttachments(batch, _listener);
  }

  int _localRejectSeq = 0;

  /// Adds a client-side-rejected tile (over the max file count or size) to the
  /// tray WITHOUT uploading it: it shows the error state, its [reason] surfaces
  /// through the composer error bar, and it can be removed like any other tile.
  /// Never reaches the SDK, so removal just drops it locally.
  void addLimitRejected(UploadFile file, String reason) {
    final isMedia = file.mimeType.startsWith('image/') ||
        file.mimeType.startsWith('video/') ||
        file.mimeType.startsWith('audio/');
    final localThumb = (file.path != null && file.path!.isNotEmpty)
        ? file.path
        : (isMedia && file.bytes != null
            ? platform.objectUrlFromBytes(file.bytes!, file.mimeType)
            : null);
    _tiles.add(
      AttachmentTile(
        fileId: 'local_reject_${_localRejectSeq++}',
        name: file.name,
        mimeType: file.mimeType,
        size: file.size,
        thumbUrl: localThumb,
        status: AttachmentTileStatus.rejected,
        errorMessage: reason,
      ),
    );
    _safeNotify();
  }

  /// Releases a tile's blob preview URL, if it holds one (web only).
  void _releaseThumb(AttachmentTile tile) {
    final t = tile.thumbUrl;
    if (t != null) platform.revokeObjectUrl(t);
  }

  Future<void> _probeDuration(AttachmentTile tile, String source) async {
    final d = await platform.probeMediaDuration(source);
    if (d != null && _tiles.contains(tile)) {
      tile.durationMillis = d.inMilliseconds;
      _safeNotify();
    }
  }

  Future<void> cancelOrRemove(String fileId) async {
    for (final t in _tiles) {
      if (t.fileId == fileId) _releaseThumb(t);
    }
    _tiles.removeWhere((t) => t.fileId == fileId);
    _safeNotify();
    // Locally-rejected tiles (over the count/size limit) never reached the SDK.
    if (!fileId.startsWith('local_reject_')) {
      _request?.removeAttachment(fileId);
    }
  }

  Future<void> retry(String fileId) async {
    final t = _byId(fileId);
    if (t == null || _request == null) return;
    // Over-limit tiles can't be retried — the file is too large / over count.
    if (fileId.startsWith('local_reject_')) return;
    t.loaded = 0;
    t.status = AttachmentTileStatus.uploading;
    _safeNotify();
    _request!.retryAttachment(fileId);
  }

  void setCaption(String value) => caption = value;

  /// Clears the tray and releases the upload batch from SDK memory. The next
  /// [stage] re-creates the request with the current receiver.
  Future<void> clear() async {
    _request?.clearAll();
    _request = null;
    _batchId = null;
    _tiles.forEach(_releaseThumb);
    _tiles.clear();
    caption = '';
    _safeNotify();
  }

  /// Builds one optimistic [MediaMessage] **per attachment kind** (image → video
  /// → audio → file, in that order) from the staged (done) attachments.
  ///
  /// Every fanned-out message carries the batch contract shared by all UIKits:
  /// `metadata['batchId']` (so the list groups them — avatar on the first,
  /// timestamp on the last) plus `batchIndex`/`batchSize` for order-independent
  /// grouping, a unique `muid` (`{batchId}_{kind}` when multi-kind), and an
  /// incremented [sentAt] for stable ordering. The [caption] rides on the last
  /// message only.
  List<MediaMessage> buildBatchMessages({
    required String receiverUid,
    required String receiverType,
    User? sender,
  }) {
    final all = doneAttachments;
    if (all.isEmpty) return const [];

    // Per-attachment audio duration (ms), keyed by the exact Attachment
    // instance each done tile carries, so the audio message can stamp it into
    // metadata for the received bubble to show up front (ENG-37180). Null when
    // the stage-time probe hasn't finished or failed — the reader tolerates it.
    final durationOf = Map<Attachment, int?>.identity();
    for (final t in _tiles) {
      if (t.status == AttachmentTileStatus.done && t.attachment != null) {
        durationOf[t.attachment!] = t.durationMillis;
      }
    }

    String kindOf(Attachment a) {
      if (AttachmentUtils.isImage(a)) return 'image';
      if (AttachmentUtils.isVideo(a)) return 'video';
      if (AttachmentUtils.isAudio(a)) return 'audio';
      return 'file';
    }

    final byKind = <String, List<Attachment>>{
      'image': [],
      'video': [],
      'audio': [],
      'file': [],
    };
    for (final a in all) {
      byKind[kindOf(a)]!.add(a);
    }
    const order = ['image', 'video', 'audio', 'file'];
    final kinds = order.where((k) => byKind[k]!.isNotEmpty).toList();

    final batchId =
        _batchId ?? DateTime.now().microsecondsSinceEpoch.toString();
    final cap = caption.trim();
    final isBatch = kinds.length > 1;
    final now = DateTime.now();

    final msgs = <MediaMessage>[];
    for (var i = 0; i < kinds.length; i++) {
      final kind = kinds[i];
      final atts = byKind[kind]!;
      final isLast = i == kinds.length - 1;
      final msg = MediaMessage(
        receiverUid: receiverUid,
        receiverType: receiverType,
        type: kind,
        muid: isBatch ? '${batchId}_$kind' : batchId,
      );
      msg.attachments = atts;
      msg.attachment = atts.first;
      msg.caption = (isLast && cap.isNotEmpty) ? cap : null;
      msg.sender = sender;
      // Stable ordering: image (earliest) … file (latest).
      msg.sentAt = now.add(Duration(milliseconds: i));
      final metadata = <String, dynamic>{
        UploadMetadataKeys.batchId: batchId,
        'batchIndex': i,
        'batchSize': kinds.length,
      };
      if (kind == 'audio') {
        // Index-aligned with `atts` (the received message's attachments order)
        // so each audio row reads its own duration before the file loads.
        metadata['audioDurationsMs'] = atts.map((a) => durationOf[a]).toList();
      }
      msg.metadata = metadata;
      msgs.add(msg);
    }
    return msgs;
  }

  // ---- Upload event handlers (called by _TrayUploadListener) ----

  void _onProgress(String fileId, int loaded, int total, int percent) {
    ccLog('⬆️ [prog] $fileId $loaded/$total ($percent%)');
    final t = _byId(fileId);
    if (t == null) return;
    t.loaded = loaded;
    _safeNotify();
  }

  void _onFileUploaded(String fileId, Attachment attachment) {
    ccLog('✅ [uploaded] $fileId url=${attachment.fileUrl}');
    final t = _byId(fileId);
    if (t == null) return;
    t.status = AttachmentTileStatus.done;
    t.loaded = t.size;
    t.attachment = attachment;
    // Keep the instant local-path preview — the freshly-uploaded CDN URL may
    // not be fetchable yet (signed URL propagation) and needs no network
    // anyway. Only adopt the remote URL when there is no local source (e.g.
    // bytes-based web picks).
    t.thumbUrl ??= attachment.fileUrl;
    _safeNotify();
  }

  void _onFileError(String fileId, CometChatException error) {
    ccLog('🟥 [tray] onFileError $fileId — '
        'code=${error.code} details=${error.details} msg=${error.message}');
    final t = _byId(fileId);
    if (t == null) return;
    t.status = AttachmentTileStatus.rejected;
    t.errorMessage = error.message ?? error.details ?? error.code;
    _safeNotify();
  }

  void _onFileFailure(String fileId, CometChatException error) {
    ccLog('🟧 [tray] onFileFailure $fileId — '
        'code=${error.code} details=${error.details} msg=${error.message}');
    final t = _byId(fileId);
    if (t == null) return;
    t.status = AttachmentTileStatus.failed;
    t.errorMessage = error.message ?? error.details ?? error.code;
    _safeNotify();
  }

  void _onComplete(UploadResult result) {
    ccLog('🏁 [complete] ok=${result.successful.length} '
        'rejected=${result.rejected.length} failed=${result.failed}');
    // Tiles are updated incrementally above; just re-evaluate canSend.
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _tiles.forEach(_releaseThumb);
    // Composer closed / conversation switched mid-stage: abort any in-flight
    // uploads and release the batch server-side (fire-and-forget — nothing from
    // the tray survives disposal).
    _request?.clearAll();
    _request = null;
    super.dispose();
  }
}

/// Adapts the SDK's [UploadFileListener] to the controller's private handlers.
/// The controller can't `extends UploadFileListener` itself (it already extends
/// [ChangeNotifier]), so it registers this forwarder as the batch's global
/// listener.
class _TrayUploadListener extends UploadFileListener {
  _TrayUploadListener(this._c);

  final AttachmentTrayController _c;

  @override
  void onFileProgress(String fileId, int loaded, int total, int percent) =>
      _c._onProgress(fileId, loaded, total, percent);

  @override
  void onFileUploaded(String fileId, Attachment attachment) =>
      _c._onFileUploaded(fileId, attachment);

  @override
  void onFileError(String fileId, CometChatException error) =>
      _c._onFileError(fileId, error);

  @override
  void onFileFailure(String fileId, CometChatException error) =>
      _c._onFileFailure(fileId, error);

  @override
  void onComplete(UploadResult result) => _c._onComplete(result);
}
