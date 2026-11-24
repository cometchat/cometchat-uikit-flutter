import 'dart:async';
import 'dart:collection';

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../chat_ui/src/message_composer/data/datasources/message_composer_datasource.dart'
    show MessageComposerDataSourceException;
import '../../../chat_ui/src/message_list/bloc/message_list_bloc.dart'
    show MessageReceiptStatus;
import '../../../chat_ui/src/message_list/bloc/message_list_event.dart';
import '../../../chat_ui/src/message_list/bloc/message_list_state.dart';
import '../../../chat_ui/src/message_list/utils/message_operation.dart';
import '../../../chat_ui/src/message_list/utils/message_template_utils.dart';
import '../../cometchat_uikit_shared.dart'
    show
        CometChatMessageEvents,
        CometChatMessageOption,
        CometChatThemeHelper,
        CometChatUIKit,
        Translations;
import '../clean_architecture/core/constants/enums.dart' as core_enums;
import 'message_key.dart';
import 'message_list_offline_sync.dart';
import 'message_list_seam_context.dart';
import 'message_send_state.dart';
import 'offline_gate.dart';
import 'offline_hub.dart';
import 'offline_hub_event.dart';
import 'offline_notice.dart';

/// Option id of the Retry row action, offered on unsent rows only (G4).
const String kRetryMessageOptionId = 'retryMessage';

/// The kit's copy option id (same value in both constants classes).
const String _copyOptionId = 'copyMessage';

/// Who announces the legacy `ccMessageSent` events of a send (G5: one per
/// transition). The composer and the multi-attachment batch announce their
/// own `inProgress`; the composer also announces `sent` and a direct error
/// when its future settles. Everything else is announced here.
enum _Origin { composer, statics, batch, retry }

/// One send started through the helper in this process.
class _SendRecord {
  _SendRecord(this.message, this.origin, {this.onSuccess, this.onError});

  /// The message as handed to the SDK (the object of the optimistic row).
  final BaseMessage message;
  final _Origin origin;
  final void Function(BaseMessage message)? onSuccess;
  final void Function(CometChatException e)? onError;

  /// Settles the caller: the static's future (value or null), the composer's
  /// future (value or error).
  final Completer<BaseMessage?> completer = Completer<BaseMessage?>();

  String? localMessageId;
  bool pendingSeen = false;
  bool settled = false;
  CometChatException? lastError;

  void complete(BaseMessage? m) {
    if (!completer.isCompleted) completer.complete(m);
  }

  void fail(Object e) {
    if (!completer.isCompleted) completer.completeError(e);
  }
}

/// W4's seam: one send helper for every send path, the send state machine,
/// Retry/Delete, and option/receipt gating (W1 §2.9, PR #23 §3.4 as corrected
/// by G4). Every entry runs only when offline is on; with offline off nothing
/// here is reached and today's send paths run unchanged (G1).
///
/// **State machine.** The SDK is called with a [MessageSentListener], so the
/// send goes through the outbox. Every per-call callback is fed through
/// [OfflineHub.reportSend]; the hub's outbox listener feeds the same entry, and
/// its forward-only map turns both into exactly one [SendStateEvent] per
/// transition. This class subscribes to those events once (settling futures and
/// announcing the legacy `ccMessageSent` once per transition), and each message
/// list applies them to its rows through [onHubEvent].
///
/// **Failed** is derived from `message.status` (BEH-SEND-30), except a
/// *direct* failure — a send refused or answered with an error before it was
/// ever pending — which has no outbox row and is kept here in memory; its Retry
/// is a fresh send.
class OfflineSend {
  OfflineSend._();

  /// The single instance.
  static final OfflineSend instance = OfflineSend._();

  StreamSubscription<OfflineHubEvent>? _hubSub;

  /// Live sends of this process, by localMessageId once known, and by muid.
  final Map<String, _SendRecord> _byLid = {};
  final Map<String, _SendRecord> _byMuid = {};

  /// The multi-attachment batch waits for each message to be queued.
  final Map<_SendRecord, Completer<void>> _batchQueued = {};

  /// Direct failures (no outbox row), keyed by [_key]. In memory only.
  final Set<String> _directFailed = {};

  /// Rows with a Retry in flight: further taps are ignored (PR #23 §3.4).
  final Set<String> _retrying = {};

  /// Rows the user deleted: their removal shows no "removed" notice.
  final Set<String> _userDeleted = {};

  /// Receipts for a server id not shown yet, per list (BEH-SEND-32, §3.6).
  final Map<String, LinkedHashMap<int, MessageReceipt>> _heldReceipts = {};

  /// Cap of held receipts per list (§3.6).
  static const int heldReceiptCap = 200;

  /// Test-only: replaces the SDK send call (`CometChat.send*` with a
  /// listener).
  @visibleForTesting
  Future<Object?> Function(BaseMessage message, MessageSentListener listener)?
  debugSendOverride;

  /// Test-only: replaces the offline-off resend of a leftover failed row.
  @visibleForTesting
  Future<Object?> Function(BaseMessage message)? debugOfflineOffResendOverride;

  /// Test-only: replaces `CometChat.retryMessage`.
  @visibleForTesting
  Future<void> Function(String localMessageId, MessageSentListener listener)?
  debugRetryOverride;

  /// Test-only: replaces `CometChat.discardLocalMessage`.
  @visibleForTesting
  Future<void> Function(
    String localMessageId,
    void Function(String id) onSuccess,
    void Function(CometChatException e) onError,
  )?
  debugDiscardOverride;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Subscribes to the hub once. Called from kit init right after the hub
  /// starts (and lazily by the first send); idempotent. Inert while offline
  /// is off: the hub publishes nothing then.
  void start() {
    _hubSub ??= OfflineHub.instance.events.listen(_onHub);
  }

  /// Row identity for the in-memory maps: own muid first (stable across a
  /// direct failure's fresh send), else [rowKey].
  static String _key(BaseMessage m) =>
      m.muid.isNotEmpty ? 'm:${m.muid}' : rowKey(m);

  // ---------------------------------------------------------------------------
  // Hooks: send entry points
  // ---------------------------------------------------------------------------

  /// Hook: `CometChatUIKit.sendTextMessage` / `sendCustomMessage` /
  /// `sendMediaMessage`, called only when offline is on (G12). The future
  /// resolves with the sent message, completes with `null` on a final failure
  /// or a direct error (as today's statics do on an error), and stays pending
  /// while the message is queued. At a session end it completes with `null`
  /// and no `onError`: a quiet removal.
  Future<T?>? trySend<T extends BaseMessage>(
    T message, {
    dynamic Function(T message)? onSuccess,
    dynamic Function(CometChatException e)? onError,
    bool replacePathForIOS = true,
  }) {
    if (message.parentMessageId == -1) message.parentMessageId = 0;
    message.sender ??= CometChatUIKit.loggedInUser;
    if (message.muid.trim().isEmpty) {
      message.muid = DateTime.now().microsecondsSinceEpoch.toString();
    }
    CometChatMessageEvents.ccMessageSent(
      message,
      core_enums.MessageStatus.inProgress,
    );
    final BaseMessage outgoing = message is MediaMessage && replacePathForIOS
        ? _iosFileCopy(message)
        : message;
    final rec = _SendRecord(
      outgoing,
      _Origin.statics,
      onSuccess: onSuccess == null
          ? null
          : (m) {
              if (m is T) onSuccess(m);
            },
      onError: onError == null ? null : (e) => onError(e),
    );
    _start(rec);
    return rec.completer.future.then((m) => m is T ? m : null);
  }

  /// Hook: the composer datasource's send methods, called only when offline
  /// is on. Resolves with the sent message; fails only on a direct error, so
  /// the composer shows it exactly as with offline off (BEH-SEND-33). A queued
  /// or outbox-failed send leaves it pending: the row state comes from the
  /// hub, never from this future (PR #23 §3.4). Because it can settle minutes
  /// after the tap, the composer lets its result move the composer status
  /// only while that is still `sending`, so an edit or reply panel opened in
  /// the meantime survives.
  Future<T>? tryComposerSend<T extends BaseMessage>(T message) {
    final rec = _SendRecord(message, _Origin.composer);
    _start(rec);
    return rec.completer.future.then((m) => m is T ? m : message);
  }

  /// Hook: one message of the composer's multi-attachment batch, called only
  /// when offline is on (its `inProgress` is already announced). Completes
  /// once the message is queued or answered, so the batch keeps its order
  /// without waiting for the network (the outbox sends in order).
  Future<void> sendBatchMessage(MediaMessage message) {
    final rec = _SendRecord(message, _Origin.batch);
    final queued = Completer<void>();
    _batchQueued[rec] = queued;
    _start(rec);
    return queued.future;
  }

  void _releaseBatch(_SendRecord rec) {
    final c = _batchQueued.remove(rec);
    if (c != null && !c.isCompleted) c.complete();
  }

  void _start(_SendRecord rec) {
    start();
    final m = rec.message;
    if (m.muid.isNotEmpty) _byMuid[m.muid] = rec;
    final listener = _PerCallListener(this, rec);
    final Future<Object?> f;
    final override = debugSendOverride;
    if (override != null) {
      f = override(m, listener);
    } else if (m is TextMessage) {
      f = CometChat.sendMessage(m, listener: listener);
    } else if (m is MediaMessage) {
      f = CometChat.sendMediaMessage(m, listener: listener);
    } else if (m is CustomMessage) {
      f = CometChat.sendCustomMessage(m, listener: listener);
    } else if (m is InteractiveMessage) {
      f = CometChat.sendInteractiveMessage(m, listener: listener);
    } else {
      listener.onError(
        CometChatException(
          'ERROR_UNSUPPORTED_MESSAGE',
          'Unsupported message type',
          'Unsupported message type',
        ),
      );
      return;
    }
    // The SDK's own future rejects when a queued send gets no answer; the
    // state comes from the listener only (PR #23 §3.4).
    unawaited(f.then<void>((_) {}, onError: (Object _) {}));
  }

  static MediaMessage _iosFileCopy(MediaMessage message) {
    final file = message.file;
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (!isIOS || file == null || file.startsWith('file://')) return message;
    return MediaMessage(
      receiverType: message.receiverType,
      type: message.type,
      receiverUid: message.receiverUid,
      file: 'file://$file',
      metadata: message.metadata,
      sender: message.sender,
      parentMessageId: message.parentMessageId,
      muid: message.muid,
      category: message.category,
      attachment: message.attachment,
      caption: message.caption,
      tags: message.tags,
    );
  }

  // ---------------------------------------------------------------------------
  // Per-call callbacks → hub
  // ---------------------------------------------------------------------------

  void _onPending(_SendRecord rec, BaseMessage m) {
    rec.pendingSeen = true;
    final lid = m.localMessageId;
    if (lid != null && lid.isNotEmpty) {
      rec.localMessageId = lid;
      _byLid[lid] = rec;
    }
    _releaseBatch(rec);
    _report(rec, m, CometChatMessageSendState.sending);
  }

  void _onSent(_SendRecord rec, BaseMessage m) {
    if (m.muid.isEmpty && rec.message.muid.isNotEmpty) {
      m.muid = rec.message.muid;
    }
    final lid = m.localMessageId ?? rec.localMessageId;
    if (lid != null && lid.isNotEmpty) _byLid.putIfAbsent(lid, () => rec);
    _report(rec, m, CometChatMessageSendState.sent);
  }

  void _onError(_SendRecord rec, CometChatException e) {
    rec.lastError = e;
    if (rec.pendingSeen && OfflineGate.isOn()) {
      // After pending: queued, not failed (BEH-SEND-10). A final failure
      // arrives as the outbox's failed event, which is authoritative.
      return;
    }
    // No pending (BEH-SEND-33), or offline went off mid-send so no outbox
    // event will follow: a direct failure. The SDK stamps a refusal's reason
    // on the message right after this callback, so read it later.
    _directFailed.add(_key(rec.message));
    final lid = rec.message.localMessageId;
    if (lid != null && lid.isNotEmpty) {
      rec.localMessageId = lid;
      _byLid[lid] = rec;
    }
    scheduleMicrotask(() {
      _report(
        rec,
        rec.message,
        CometChatMessageSendState.failed,
        reason: rec.message.failureReason,
      );
    });
  }

  /// Feeds one per-call outcome to the hub. With offline off at callback time
  /// the hub publishes nothing, so the record settles here instead: every
  /// send record settles, whatever the gate did mid-send. With no outbox
  /// running, an error is final and direct, as today's path reports it.
  void _report(
    _SendRecord rec,
    BaseMessage m,
    CometChatMessageSendState state, {
    MessageFailureReason? reason,
  }) {
    if (OfflineGate.isOn()) {
      OfflineHub.instance.reportSend(m, state, reason: reason);
      return;
    }
    if (rec.settled) return;
    switch (state) {
      case CometChatMessageSendState.sending:
        return;
      case CometChatMessageSendState.sent:
        _directFailed.remove(_key(m));
        _retrying.remove(_key(m));
        _settleSent(rec, m);
      case CometChatMessageSendState.failed:
        _retrying.remove(_key(m));
        if (isRemoval(reason)) {
          _settleRemoved(rec);
        } else {
          _settleFailed(rec, rec.message, true);
        }
    }
  }

  // ---------------------------------------------------------------------------
  // Hub events → futures + legacy events (once per transition, process-wide)
  // ---------------------------------------------------------------------------

  void _onHub(OfflineHubEvent event) {
    if (event is SessionEnded) {
      _endSession();
      return;
    }
    if (event is CacheReset) {
      _failOpenSends();
      return;
    }
    if (event is MessageSyncCompleted) {
      _heldReceipts.clear(); // §3.6
      return;
    }
    if (event is! SendStateEvent) return;
    final m = event.message;
    final lid = event.localMessageId;
    final rec =
        (lid.isNotEmpty ? _byLid[lid] : null) ??
        (m.muid.isNotEmpty ? _byMuid[m.muid] : null);
    final live = rec != null && !rec.settled;
    switch (event.state) {
      case CometChatMessageSendState.sending:
        return; // inProgress was announced by the send's origin.
      case CometChatMessageSendState.sent:
        _directFailed.remove(_key(m));
        _retrying.remove(_key(m));
        if (live) {
          _settleSent(rec, m);
        } else {
          // A send that flushed with no live per-call listener (relaunch).
          CometChatMessageEvents.ccMessageSent(
            m,
            core_enums.MessageStatus.sent,
          );
        }
        return;
      case CometChatMessageSendState.failed:
        _retrying.remove(_key(m));
        final reason = event.reason;
        if (isRemoval(reason)) {
          if (rec != null) _settleRemoved(rec);
          return;
        }
        final direct = _isDirect(m, reason);
        if (direct) _directFailed.add(_key(m));
        if (live) {
          _settleFailed(rec, m, direct);
        } else {
          CometChatMessageEvents.ccMessageSent(
            m,
            core_enums.MessageStatus.error,
          );
        }
        return;
    }
  }

  void _forget(_SendRecord rec) {
    rec.settled = true;
    final lid = rec.localMessageId;
    if (lid != null && identical(_byLid[lid], rec)) _byLid.remove(lid);
    final muid = rec.message.muid;
    if (muid.isNotEmpty && identical(_byMuid[muid], rec)) _byMuid.remove(muid);
    _releaseBatch(rec);
  }

  void _settleSent(_SendRecord rec, BaseMessage m) {
    _forget(rec);
    switch (rec.origin) {
      case _Origin.composer:
        rec.complete(m); // the composer announces `sent`
      case _Origin.statics:
        try {
          rec.onSuccess?.call(m);
        } catch (_) {}
        CometChatMessageEvents.ccMessageSent(m, core_enums.MessageStatus.sent);
        rec.complete(m);
      case _Origin.batch:
        m.metadata ??= rec.message.metadata;
        CometChatMessageEvents.ccMessageSent(m, core_enums.MessageStatus.sent);
        rec.complete(m);
      case _Origin.retry:
        CometChatMessageEvents.ccMessageSent(m, core_enums.MessageStatus.sent);
        rec.complete(m);
    }
  }

  void _settleFailed(_SendRecord rec, BaseMessage m, bool direct) {
    final error =
        rec.lastError ??
        CometChatException(
          'ERROR_MESSAGE_SEND_FAILED',
          'Message send failed',
          m.failureReason?.name ?? 'Message send failed',
        );
    if (direct) {
      // Shown exactly as with offline off (BEH-SEND-33); the row has no
      // outbox row, so its failed mark lives in [_directFailed].
      _forget(rec);
      final row = rec.message;
      switch (rec.origin) {
        case _Origin.composer:
          // The composer stamps and announces the error, as today.
          rec.fail(
            MessageComposerDataSourceException(
              message: error.message ?? 'Failed to send message',
              code: error.code,
              originalException: error,
            ),
          );
        case _Origin.statics:
          (row.metadata ??= {})['error'] = error;
          try {
            rec.onError?.call(error);
          } catch (_) {}
          CometChatMessageEvents.ccMessageSent(
            row,
            core_enums.MessageStatus.error,
          );
          rec.complete(null);
        case _Origin.batch:
          row.metadata = {...?row.metadata, 'error': error.message};
          CometChatMessageEvents.ccMessageSent(
            row,
            core_enums.MessageStatus.error,
          );
          rec.complete(null);
        case _Origin.retry:
          CometChatMessageEvents.ccMessageSent(
            row,
            core_enums.MessageStatus.error,
          );
          rec.complete(null);
      }
      return;
    }
    // Outbox failure: failed is derived from `status`; nothing is stamped
    // into metadata (invariant 2).
    CometChatMessageEvents.ccMessageSent(m, core_enums.MessageStatus.error);
    if (rec.origin == _Origin.composer) {
      // The composer's future stays pending: a later Retry that succeeds
      // settles it, and the composer announces `sent` then.
      return;
    }
    _forget(rec);
    if (rec.origin == _Origin.statics) {
      try {
        rec.onError?.call(error);
      } catch (_) {}
    }
    rec.complete(null);
  }

  void _settleRemoved(_SendRecord rec) {
    final userDeleted = _userDeleted.contains(_key(rec.message));
    _forget(rec);
    if (rec.origin == _Origin.statics && !userDeleted) {
      try {
        rec.onError?.call(
          rec.lastError ??
              CometChatException(
                OfflineSendError.discarded,
                'The message was removed before it could be sent',
                MessageFailureReason.discarded.name,
              ),
        );
      } catch (_) {}
    }
    if (rec.origin != _Origin.composer) rec.complete(null);
  }

  void _endSession() {
    // G12: futures still waiting complete quietly; no error, no event.
    for (final rec in {..._byLid.values, ..._byMuid.values}) {
      rec.settled = true;
      if (rec.origin != _Origin.composer) rec.complete(null);
      _releaseBatch(rec);
    }
    _byLid.clear();
    _byMuid.clear();
    _directFailed.clear();
    _retrying.clear();
    _userDeleted.clear();
    _heldReceipts.clear();
  }

  /// A cache reset lost every unsent message. The SDK reports a per-send
  /// discard for an encryption change or a schema reset, but not for a
  /// corruption or lost-key wipe, so every send still open settles here,
  /// exactly as that discard settles it (an SDK discard arriving later finds
  /// no live send).
  void _failOpenSends() {
    for (final rec in {..._byLid.values, ..._byMuid.values}) {
      if (rec.settled) continue;
      rec.lastError = CometChatException(
        OfflineSendError.discarded,
        'The message was removed before it could be sent',
        MessageFailureReason.discarded.name,
      );
      _settleRemoved(rec);
    }
  }

  /// Whether [reason] removes the row instead of marking it failed.
  static bool isRemoval(MessageFailureReason? reason) =>
      reason == MessageFailureReason.discarded ||
      reason == MessageFailureReason.queueOverflow;

  bool _isDirect(BaseMessage m, MessageFailureReason? reason) =>
      reason == MessageFailureReason.queueFull ||
      reason == MessageFailureReason.byteOverflow ||
      _directFailed.contains(_key(m));

  // ---------------------------------------------------------------------------
  // Row state (read by the message list widget and receipt utils, ON only)
  // ---------------------------------------------------------------------------

  static bool _isOwn(BaseMessage m) {
    final me = CometChatUIKit.loggedInUser?.uid;
    return me != null && m.sender?.uid == me;
  }

  /// Whether [m] is an own message that has not reached the server: no server
  /// id, an un-acked SDK status, or a direct failure.
  bool isUnsent(BaseMessage m) =>
      _isOwn(m) &&
      (m.id <= 0 ||
          sendStateOf(m) != CometChatMessageSendState.sent ||
          _directFailed.contains(_key(m)));

  /// Whether [m] is failed: from its status (outbox rows, BEH-SEND-30) or the
  /// in-memory direct-failure mark.
  bool isFailed(BaseMessage m) {
    if (m.id > 0 || !_isOwn(m)) return false;
    return sendStateOf(m) == CometChatMessageSendState.failed ||
        _directFailed.contains(_key(m));
  }

  /// Whether [m] is a row left failed when offline went off under it (W5's
  /// effective-off transition marks shown un-acked rows FAILED): own, no
  /// server id, a localMessageId, status FAILED. A send made with offline off
  /// never has a localMessageId, so with offline never on no row matches.
  bool isLeftoverFailed(BaseMessage m) =>
      m.id <= 0 &&
      _isOwn(m) &&
      (m.localMessageId?.isNotEmpty ?? false) &&
      sendStateOf(m) == CometChatMessageSendState.failed;

  /// Whether the offline row UI (caption, receipt, menu, tap) applies to
  /// [m]: offline is on, or [m] is a leftover failed row.
  bool appliesTo(BaseMessage m, {bool? offlineOn}) =>
      (offlineOn ?? OfflineGate.isOn()) || isLeftoverFailed(m);

  /// How [m]'s Retry works. With offline off every failure is direct: no
  /// outbox runs (W5's leftover rows included).
  OfflineFailureKind failureKindOf(BaseMessage m) {
    if (!OfflineGate.isOn()) return OfflineFailureKind.direct;
    final lid = m.localMessageId;
    if (_isDirect(m, m.failureReason) || lid == null || lid.isEmpty) {
      return OfflineFailureKind.direct;
    }
    return OfflineFailureKind.outbox;
  }

  /// The receipt an unsent row shows instead of a server receipt
  /// (BEH-SEND-32): failed, or the clock. Null for a row that reached the
  /// server.
  MessageReceiptStatus? unsentReceiptOf(BaseMessage m) {
    if (!isUnsent(m)) return null;
    return isFailed(m)
        ? MessageReceiptStatus.error
        : MessageReceiptStatus.sending;
  }

  // ---------------------------------------------------------------------------
  // Option gating (G5, BEH-SEND-31)
  // ---------------------------------------------------------------------------

  /// Filters [options] for an unsent row to Copy only (no option needing a
  /// server id). Returns [options] unchanged for any other row.
  List<CometChatMessageOption> filterUnsent(
    BaseMessage m,
    List<CometChatMessageOption> options,
  ) {
    if (!isUnsent(m)) return options;
    return options.where((o) => o.id == _copyOptionId).toList();
  }

  /// The row menu of an unsent row: Retry, Delete and Copy (G4, G5). Copy is
  /// kept only when the template offered it (e.g. text).
  List<CometChatMessageOption> unsentOptions(
    BuildContext context,
    BaseMessage m,
    List<CometChatMessageOption> templateOptions,
  ) {
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final typography = CometChatThemeHelper.getTypography(context);
    final retry = CometChatMessageOption(
      id: kRetryMessageOptionId,
      title: Translations.of(context).retry,
      icon: Icon(Icons.refresh, color: colorPalette.iconSecondary, size: 24),
    );
    final delete = MessageTemplateUtils.getDeleteOption(
      context,
      colorPalette,
      typography,
      null,
    );
    return [retry, delete, ...filterUnsent(m, templateOptions)];
  }

  // ---------------------------------------------------------------------------
  // Retry / Delete (G4, D33a/b)
  // ---------------------------------------------------------------------------

  /// Retries the unsent row [m] of the list driven by [bloc]. An outbox row
  /// uses `CometChat.retryMessage`; a direct failure is sent afresh. A tap
  /// while a retry is in flight is ignored; a message mid-send gets the
  /// "Sending… try again in a moment" notice (D33b).
  void retry(Object bloc, BaseMessage m) {
    if (!OfflineGate.isOn()) {
      // A row left failed when offline went off: a fresh send on today's
      // path (the statics with offline off), never `retryMessage`.
      if (isLeftoverFailed(m)) _resendWithOfflineOff(bloc, m);
      return;
    }
    final key = _key(m);
    if (_retrying.contains(key)) return;
    final wasFailed = isFailed(m);
    if (failureKindOf(m) == OfflineFailureKind.direct) {
      if (!wasFailed) {
        // A direct send still waiting for its answer.
        _postNotice(bloc, const SendingTryAgain());
        return;
      }
      _retrying.add(key);
      _directFailed.remove(key);
      // A fresh send through the same helper: the SDK gives it a new
      // localMessageId; the muid keeps the row in place. Clearing the send
      // state also clears the derived failure reason.
      m.localMessageId = null;
      m.sendState = null;
      m.metadata?.remove('error');
      CometChatMessageEvents.ccMessageSent(
        m,
        core_enums.MessageStatus.inProgress,
      );
      _refreshRow(bloc, m);
      _start(_SendRecord(m, _Origin.retry));
      return;
    }
    final lid = m.localMessageId!;
    _retrying.add(key);
    final existing = _byLid[lid];
    final rec = existing != null && !existing.settled
        ? existing
        : _SendRecord(m, _Origin.retry);
    rec.localMessageId = lid;
    rec.pendingSeen = true;
    rec.lastError = null; // a new attempt reports its own outcome
    _byLid[lid] = rec;
    if (wasFailed) {
      // The SDK moves the row back to PENDING; show it at once.
      m.sendState = 'PENDING';
      CometChatMessageEvents.ccMessageSent(
        m,
        core_enums.MessageStatus.inProgress,
      );
      OfflineHub.instance.reportSend(m, CometChatMessageSendState.sending);
    }
    final listener = _RetryListener(this, rec, bloc, m);
    final override = debugRetryOverride;
    unawaited(
      (override != null
              ? override(lid, listener)
              : CometChat.retryMessage(lid, listener: listener))
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }

  /// Deletes the unsent row [m] of the list driven by [bloc] (G4): an outbox
  /// row through `CometChat.discardLocalMessage`, removed on its success (no
  /// SDK event follows, BEH-SEND-36); a direct failure is removed from memory.
  void delete(Object bloc, BaseMessage m) {
    if (!OfflineGate.isOn()) {
      // A row left failed when offline went off: no outbox row is left, so
      // the in-memory row is all there is to remove.
      if (isLeftoverFailed(m)) {
        MessageListOfflineSync.instance.clearDirectFailure(m); // W5's mark
        messageListSeamHostOf(bloc)?.run((ctx) => removeRow(ctx, m));
      }
      return;
    }
    final lid = m.localMessageId;
    if (failureKindOf(m) == OfflineFailureKind.direct ||
        lid == null ||
        lid.isEmpty) {
      if (!isFailed(m)) {
        _postNotice(bloc, const SendingTryAgain());
        return;
      }
      _directFailed.remove(_key(m));
      _removeLocally(bloc, m);
      return;
    }
    void onSuccess(String _) => _removeLocally(bloc, m);
    void onError(CometChatException e) {
      if (e.code == OfflineSendError.inFlight) {
        _postNotice(bloc, const SendingTryAgain()); // D33b: row stays
      } else if (e.code == OfflineSendError.notFound) {
        _refreshRow(bloc, m); // re-render from its status
      }
    }

    final override = debugDiscardOverride;
    unawaited(
      (override != null
              ? override(lid, onSuccess, onError)
              : CometChat.discardLocalMessage(
                  lid,
                  onSuccess: onSuccess,
                  onError: onError,
                ))
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }

  /// Resends a leftover failed row on today's path. A type with no send
  /// static sends nothing, so its row keeps its failed state.
  void _resendWithOfflineOff(Object bloc, BaseMessage m) {
    final Future<Object?> Function() send;
    if (m is TextMessage) {
      send = () => CometChatUIKit.sendTextMessage(m);
    } else if (m is MediaMessage) {
      send = () => CometChatUIKit.sendMediaMessage(m);
    } else if (m is CustomMessage) {
      send = () => CometChatUIKit.sendCustomMessage(m);
    } else if (m is InteractiveMessage) {
      send = () => CometChatUIKit.sendCustomInteractiveMessage(m);
    } else {
      return;
    }
    // A send starts: only now is the failed state cleared.
    MessageListOfflineSync.instance.clearDirectFailure(m); // W5's mark
    m.localMessageId = null;
    m.sendState = null;
    m.metadata?.remove('error');
    _refreshRow(bloc, m);
    final resend = debugOfflineOffResendOverride;
    unawaited(resend != null ? resend(m) : send());
  }

  void _removeLocally(Object bloc, BaseMessage m) {
    _userDeleted.add(_key(m));
    _retrying.remove(_key(m));
    final lid = m.localMessageId;
    final rec =
        (lid != null ? _byLid[lid] : null) ??
        (m.muid.isNotEmpty ? _byMuid[m.muid] : null);
    if (rec != null) _settleRemoved(rec);
    messageListSeamHostOf(bloc)?.run((ctx) => removeRow(ctx, m));
    // Tell the other lists and the conversation list (no public event).
    OfflineHub.instance.reportRemoved(m);
  }

  void _postNotice(Object bloc, OfflineNotice notice) {
    messageListSeamHostOf(bloc)?.run((ctx) => ctx.postNotice(notice));
  }

  void _refreshRow(Object bloc, BaseMessage m) {
    messageListSeamHostOf(bloc)?.run((ctx) {
      final idx = findRow(ctx, m, m.localMessageId ?? '');
      if (idx != null) _replaceRow(ctx, idx, m);
    });
  }

  void _onRetryError(Object bloc, BaseMessage m, CometChatException e) {
    _retrying.remove(_key(m));
    if (e.code == OfflineSendError.inFlight) {
      _postNotice(bloc, const SendingTryAgain()); // D33b: row stays
    } else if (e.code == OfflineSendError.notFound) {
      _refreshRow(bloc, m);
    }
    // Not connected: queued, the row stays sending (BEH-SEND-10). A final
    // failure arrives as the outbox's failed event.
  }

  // ---------------------------------------------------------------------------
  // Message-list hooks
  // ---------------------------------------------------------------------------

  /// Hook: `_onMessageSentByUser`. Skips today's `sent` handling when the hub
  /// already applied the ack to the row (today's code would reset a receipt
  /// applied from a held one); otherwise falls through.
  Future<bool>? handleSentByUser(
    MessageListSeamContext ctx,
    MessageSentByUser event,
  ) {
    if (event.status != core_enums.MessageStatus.sent.toString()) return null;
    final m = event.message;
    if (m.id <= 0) return null;
    if (ctx.findMessageIndex(m.id) == null) return null;
    return Future.value(true);
  }

  /// Hook: the message list's receipt handlers, before today's code. Holds a
  /// receipt for a server id the list does not show yet while it has an
  /// un-acked own row, so it is applied when that row is acked
  /// (BEH-SEND-32, §3.6).
  void noteReceipt(MessageListSeamContext ctx, MessageReceipt receipt) {
    final id = receipt.messageId;
    if (id == null || id <= 0) return;
    if (ctx.findMessageIndex(id) != null) return;
    final me = ctx.loggedInUser?.uid;
    final hasUnacked = ctx.state.messages.any(
      (m) => m.id <= 0 && m.sender?.uid == me,
    );
    if (!hasUnacked) return;
    final held = _heldReceipts.putIfAbsent(
      _listKey(ctx),
      () => LinkedHashMap<int, MessageReceipt>(),
    );
    final prev = held.remove(id);
    held[id] = (prev?.readAt != null && receipt.readAt == null)
        ? prev!
        : receipt;
    while (held.length > heldReceiptCap) {
      held.remove(held.keys.first);
    }
  }

  static String _listKey(MessageListSeamContext ctx) =>
      '${ctx.conversationType}:${ctx.conversationWith}:'
      '${ctx.parentMessageId ?? 0}';

  /// Test-only: the receipts held for the list of [ctx].
  @visibleForTesting
  Map<int, MessageReceipt> debugHeldReceipts(MessageListSeamContext ctx) =>
      Map.of(_heldReceipts[_listKey(ctx)] ?? const <int, MessageReceipt>{});

  /// Hub collector, called inside the message-list bloc's event loop for every
  /// current-gen hub event: [SendStateEvent] drives the row state.
  Future<void> onHubEvent(
    MessageListSeamContext ctx,
    OfflineHubEvent event,
  ) async {
    if (event is SessionEnded || event is MessageSyncCompleted) {
      _heldReceipts.remove(_listKey(ctx));
      return;
    }
    if (event is! SendStateEvent) return;
    if (ctx.isStale || ctx.isClosed) return;
    final m = event.message;
    if (!belongsToList(ctx, m)) return;
    final idx = findRow(ctx, m, event.localMessageId);
    if (event.state == CometChatMessageSendState.failed &&
        isRemoval(event.reason)) {
      if (idx == null) return;
      final row = ctx.state.messages[idx];
      final userDeleted =
          _userDeleted.contains(_key(row)) || _userDeleted.contains(_key(m));
      removeRow(ctx, row);
      if (!userDeleted) {
        ctx.postNotice(UnsentRemoved(row is TextMessage ? row.text : null));
      }
      return;
    }
    if (idx == null) {
      // Not shown yet (e.g. a send started outside the kit): today's insert
      // path, with its filters and interceptors, and no public event.
      if (event.state != CometChatMessageSendState.failed) {
        final status = event.state == CometChatMessageSendState.sent
            ? core_enums.MessageStatus.sent
            : core_enums.MessageStatus.inProgress;
        ctx.add(MessageSentByUser(message: m, status: status.toString()));
      }
      return;
    }
    final old = ctx.state.messages[idx];
    if (m.muid.isEmpty && old.muid.isNotEmpty) m.muid = old.muid;
    if (event.state == CometChatMessageSendState.sent) {
      if (old.id <= 0 && old.muid.isNotEmpty) {
        // Today's ack path replaces the row in place by muid and moves its
        // receipt notifier to the server id.
        ctx.add(
          MessageSentByUser(
            message: m,
            status: core_enums.MessageStatus.sent.toString(),
          ),
        );
      } else {
        _replaceRow(ctx, idx, m);
        final notifier = ctx.receiptNotifierFor(m);
        if (notifier.value == MessageReceiptStatus.sending ||
            notifier.value == MessageReceiptStatus.error) {
          notifier.value = MessageReceiptStatus.sent;
        }
      }
      _replayHeldReceipts(ctx, m);
      return;
    }
    _replaceRow(ctx, idx, m);
    final notifier = ctx.receiptNotifierFor(m);
    if (event.state == CometChatMessageSendState.sending) {
      notifier.value = MessageReceiptStatus.sending;
      return;
    }
    notifier.value = MessageReceiptStatus.error;
    if (event.reason == MessageFailureReason.queueFull) {
      ctx.postNotice(const QueueFull());
    } else if (event.reason == MessageFailureReason.byteOverflow) {
      ctx.postNotice(const FileTooLargeOffline());
    }
  }

  /// Applies held receipts that cover a row just acked with a server id
  /// (§3.6), through the list's own receipt handlers, queued after the ack.
  void _replayHeldReceipts(MessageListSeamContext ctx, BaseMessage m) {
    final held = _heldReceipts[_listKey(ctx)];
    if (held == null || held.isEmpty || m.id <= 0) return;
    final covering = held.values
        .where((r) => (r.messageId ?? 0) >= m.id) // "up to X" covers ids ≤ X
        .toList();
    held.remove(m.id); // now shown
    for (final r in covering) {
      if (r.readAt != null) {
        ctx.add(ReadReceiptReceived(r));
      } else {
        ctx.add(DeliveryReceiptReceived(r));
      }
    }
  }

  /// Whether [m] belongs to the list of [ctx] (conversation and thread).
  static bool belongsToList(MessageListSeamContext ctx, BaseMessage m) {
    final parent = ctx.parentMessageId;
    if (parent != null && parent > 0) {
      if (m.parentMessageId != parent) return false;
    } else if (m.parentMessageId > 0 && ctx.hideReplies) {
      return false;
    }
    final group = ctx.group;
    if (group != null) {
      return m.receiverType == CometChatReceiverType.group &&
          m.receiverUid == group.guid;
    }
    final user = ctx.user;
    if (user != null) {
      return m.receiverType == CometChatReceiverType.user &&
          (m.receiverUid == user.uid || m.sender?.uid == user.uid);
    }
    return false;
  }

  /// Row index of [m] in the list of [ctx] (G6): server id; then
  /// [localMessageId] only against rows with no server id, the same sender and
  /// the same conversation; then the own muid.
  static int? findRow(
    MessageListSeamContext ctx,
    BaseMessage m,
    String localMessageId,
  ) {
    final rows = ctx.state.messages;
    if (m.id > 0) {
      final i = ctx.findMessageIndex(m.id);
      if (i != null && i < rows.length) return i;
    }
    final lid = localMessageId.isNotEmpty
        ? localMessageId
        : (m.localMessageId ?? '');
    if (lid.isNotEmpty) {
      for (var i = rows.length - 1; i >= 0; i--) {
        final r = rows[i];
        if (r.id > 0 || r.localMessageId != lid) continue;
        final sender = r.sender?.uid;
        if (sender == null || sender != m.sender?.uid) continue;
        if (r.receiverUid != m.receiverUid ||
            r.receiverType != m.receiverType) {
          continue;
        }
        return i;
      }
    }
    final myUid = ctx.loggedInUser?.uid;
    if (m.muid.isNotEmpty && myUid != null && m.sender?.uid == myUid) {
      final i = ctx.findMessageIndexByMuid(m.muid);
      if (i != null && i < rows.length) {
        final r = rows[i];
        if (r.id <= 0 || r.id == m.id) return i;
      }
    }
    return null;
  }

  static void _replaceRow(MessageListSeamContext ctx, int idx, BaseMessage m) {
    final rows = List<BaseMessage>.from(ctx.state.messages);
    final old = rows[idx];
    rows[idx] = m;
    ctx.markIndexMapsDirty();
    ctx.emit(ctx.state.copyWith(messages: rows));
    ctx.addOperation(MessageOperation.update(old, m, idx));
  }

  /// Removes [m]'s row from the list of [ctx], if shown.
  static void removeRow(MessageListSeamContext ctx, BaseMessage m) {
    final idx = findRow(ctx, m, m.localMessageId ?? '');
    if (idx == null) return;
    final rows = List<BaseMessage>.from(ctx.state.messages);
    final old = rows.removeAt(idx);
    ctx.markIndexMapsDirty();
    ctx.emit(
      ctx.state.copyWith(
        messages: rows,
        status: rows.isEmpty ? MessageListStatus.empty : null,
      ),
    );
    ctx.addOperation(MessageOperation.remove(old, idx));
  }

  /// Test-only: drops every live send, mark and held receipt.
  @visibleForTesting
  void debugReset() {
    debugSendOverride = null;
    debugRetryOverride = null;
    debugDiscardOverride = null;
    debugOfflineOffResendOverride = null;
    _byLid.clear();
    _byMuid.clear();
    _batchQueued.clear();
    _directFailed.clear();
    _retrying.clear();
    _userDeleted.clear();
    _heldReceipts.clear();
  }

  /// Test-only: whether [m] carries the in-memory direct-failure mark.
  @visibleForTesting
  bool debugIsDirectFailed(BaseMessage m) => _directFailed.contains(_key(m));
}

class _PerCallListener implements MessageSentListener {
  _PerCallListener(this._send, this._rec);
  final OfflineSend _send;
  final _SendRecord _rec;

  @override
  void onMessagePending(BaseMessage message) => _send._onPending(_rec, message);

  @override
  void onMessageSent(BaseMessage message) => _send._onSent(_rec, message);

  @override
  void onError(CometChatException e) => _send._onError(_rec, e);
}

class _RetryListener implements MessageSentListener {
  _RetryListener(this._send, this._rec, this._bloc, this._message);
  final OfflineSend _send;
  final _SendRecord _rec;
  final Object _bloc;
  final BaseMessage _message;

  @override
  void onMessagePending(BaseMessage message) => _send._onPending(_rec, message);

  @override
  void onMessageSent(BaseMessage message) => _send._onSent(_rec, message);

  @override
  void onError(CometChatException e) {
    // A refusal of the Retry call itself (mid-send, not found) is not an
    // outcome of the send: a later final failure reports its own error.
    if (e.code != OfflineSendError.inFlight &&
        e.code != OfflineSendError.notFound) {
      _rec.lastError = e;
    }
    _send._onRetryError(_bloc, _message, e);
  }
}
