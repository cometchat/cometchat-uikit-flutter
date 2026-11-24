import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/scheduler.dart';

import '../../../chat_ui/src/message_composer/upload/attachment_tray_controller.dart';

/// The composer's upload batch key: (receiver id, receiver type, parent id).
typedef ComposerTriple = ({String? id, String? type, int parentMessageId});

/// W8's seam for the composer's upload tray restore (BEH-UPLOAD-14).
///
/// On chat or thread open, once the composer's triple has settled, the tray is
/// restored exactly once from the SDK's saved batch
/// (`CometChat.getExistingUploadFileRequest`, called unconditionally; it
/// returns null with offline support off, so the restore is a no-op there).
/// Nothing uploads on restore. A triple change with offline on detaches the
/// tray without destroying the batch; with offline off it destroys it, as
/// today.
abstract final class ComposerTrayOffline {
  /// Test seam for the SDK lookup.
  @visibleForTesting
  static Future<UploadFileRequest?> Function(
    String receiverId,
    String receiverType,
    int? parentMessageId,
  )
  lookup = _sdkLookup;

  /// Restores the SDK default (tests).
  @visibleForTesting
  static void resetForTest() => lookup = _sdkLookup;

  static Future<UploadFileRequest?> _sdkLookup(
    String receiverId,
    String receiverType,
    int? parentMessageId,
  ) => CometChat.getExistingUploadFileRequest(
    receiverId,
    receiverType,
    parentMessageId: parentMessageId,
  );

  /// The parent id the batch is keyed with: the thread's id with offline on;
  /// null for a main composer, and always null with offline off (today's
  /// request, unchanged). Create and restore use the same value, so a
  /// composer finds the batch it made.
  static int? batchParentId(int? parentMessageId, {required bool offlineOn}) =>
      offlineOn && parentMessageId != null && parentMessageId > 0
      ? parentMessageId
      : null;

  /// One tile per restored file: `uploaded` → done (send-ready, carries its
  /// attachment); `rejected` → rejected (terminal); everything else →
  /// failed, retryable, except a file whose durable copy is missing: it
  /// cannot be uploaded again, so it is rejected and marked
  /// [AttachmentTile.notSaved] (remove only; the user adds it again — D57).
  /// Preview from the file's durable copy.
  static AttachmentTile tileFromRestored(UploadFileView f) {
    var status = switch (f.state) {
      UploadFileState.uploaded => AttachmentTileStatus.done,
      UploadFileState.rejected => AttachmentTileStatus.rejected,
      _ => AttachmentTileStatus.failed,
    };
    final notSaved =
        status == AttachmentTileStatus.failed && f.localCopyPath == null;
    if (notSaved) status = AttachmentTileStatus.rejected;
    final done = status == AttachmentTileStatus.done;
    return AttachmentTile(
      fileId: f.fileId,
      name: f.name,
      mimeType: f.mimeType,
      size: f.size,
      loaded: done ? f.size : 0,
      status: status,
      thumbUrl: f.localCopyPath ?? (done ? f.attachment?.fileUrl : null),
      attachment: done ? f.attachment : null,
      // The tile explains a missing copy itself, in the user's language.
      errorMessage: done || notSaved ? null : f.errorMessage,
      notSaved: notSaved,
    );
  }

  /// The next `tile_N` sequence after [files], so a new pick never reuses a
  /// restored id.
  static int nextTileSeq(int current, List<UploadFileView> files) {
    var next = current;
    for (final f in files) {
      if (!f.fileId.startsWith('tile_')) continue;
      final n = int.tryParse(f.fileId.substring(5));
      if (n != null && n >= next) next = n + 1;
    }
    return next;
  }
}

/// Runs the restore for one composer: deferred past the frame the triple is
/// configured in, coalesced, once per settled triple.
class ComposerTrayRestorer {
  /// Creates a restorer for one composer's [tray].
  ComposerTrayRestorer({
    required this.tray,
    required this.tripleOf,
    required this.isMounted,
  });

  /// The composer's tray that a restored upload is put back into. A tray
  /// that already holds files is never overwritten.
  final AttachmentTrayController tray;

  /// The composer's current triple, read when the restore runs (so the
  /// final triple wins over any intermediate one).
  final ComposerTriple Function() tripleOf;

  /// Whether the composer is still mounted; the restore is skipped once it
  /// is not.
  final bool Function() isMounted;

  String? _restoredKey;
  bool _scheduled = false;

  /// The triple last restored (or looked up), for tests.
  @visibleForTesting
  String? get restoredKey => _restoredKey;

  static String _key(ComposerTriple t) =>
      '${t.type}|${t.id}|${t.parentMessageId}';

  /// Asks for a restore after the current frame. Calls in the same frame
  /// coalesce into one.
  void schedule() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      unawaited(runNow());
    });
  }

  /// Restores for the current triple if it has not been restored yet.
  @visibleForTesting
  Future<void> runNow() async {
    if (!isMounted()) return;
    final triple = tripleOf();
    final id = triple.id, type = triple.type;
    if (id == null || id.isEmpty || type == null || type.isEmpty) return;
    final key = _key(triple);
    if (key == _restoredKey) return;
    _restoredKey = key;
    // Never clobber a live tray.
    if (!tray.isEmpty) return;
    try {
      final parent = triple.parentMessageId > 0 ? triple.parentMessageId : null;
      final request = await ComposerTrayOffline.lookup(id, type, parent);
      if (request == null || !isMounted()) return;
      if (_key(tripleOf()) != key) return; // the chat moved on meanwhile
      tray.restore(request);
    } catch (_) {
      // Better an empty tray than a broken chat open.
    }
  }

  /// The triple changed: forget the last restore so the new triple restores.
  void tripleChanged() => _restoredKey = null;
}
