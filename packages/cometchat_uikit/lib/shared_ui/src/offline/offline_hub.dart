import 'dart:async';

import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../shared_ui/src/clean_architecture/domain/events/message_events/cometchat_message_events.dart';
import 'message_send_state.dart';
import 'offline_gate.dart';
import 'offline_hub_event.dart';
import 'offline_notice.dart';

/// Shows a hub notice on a list that displays notices (W1 §2.8).
typedef OfflineNoticeSink = void Function(OfflineNotice notice);

/// The one offline listener hub for the Flutter UI Kit (W1 §2.6, PR #23 §3.5).
///
/// A process-level singleton, started once from `CometChatUIKit.init` /
/// `initFromSettings` after the SDK init resolves. It registers its SDK
/// listeners once, each under its own id, and **never unregisters** them; a
/// second init registers nothing. The outbox, sync, cache-reset, media and
/// synced-message handlers return at once while offline is off, so the OFF
/// path is untouched. Events go out on a private broadcast channel, each
/// stamped with the session [gen]; the hub is never wired to a kit's public
/// event bus.
///
/// **Session end (G8).** The SDK answers `isOfflineEnabled() == false` once a
/// logout has happened, so the session-end decision cannot read the gate. The
/// hub records whether offline was on at any point during the session (every
/// `true` gate read calls [noteOfflineOn]) and ends the session — bumping [gen]
/// and emitting [SessionEnded] — on logout or a different-uid login only when
/// it was. A same-uid login (token refresh) keeps the session.
class OfflineHub {
  OfflineHub._();

  /// The process-wide hub.
  static final OfflineHub instance = OfflineHub._();

  // Listener ids — each SDK listener type under its own id.
  static const String _outboxId = 'uikit_offline_outbox';
  static const String _syncId = 'uikit_offline_sync';
  static const String _cacheResetId = 'uikit_offline_cache_reset';
  static const String _mediaId = 'uikit_offline_media';
  static const String _messageId = 'uikit_offline_synced_messages';
  static const String _loginId = 'uikit_offline_login';

  final StreamController<OfflineHubEvent> _events =
      StreamController<OfflineHubEvent>.broadcast();

  /// The private event channel the blocs subscribe to.
  Stream<OfflineHubEvent> get events => _events.stream;

  bool _started = false;
  int _startRegistrations = 0;
  int _gen = 0;

  /// The uid of the active session, or null when logged out.
  String? _lastUid;

  /// Whether offline was on at any point during the current session.
  bool _sessionOffline = false;

  /// Forward-only "last emitted state" per non-empty localMessageId (ON path
  /// only), so exactly one public event fires per transition (G5, §3.4).
  final Map<String, CometChatMessageSendState> _lastEmitted = {};

  /// Lists currently showing notices, most recently attached last.
  final List<OfflineNoticeSink> _sinks = [];

  /// Hub notices waiting for a list that shows notices.
  final List<OfflineNotice> _pendingNotices = [];

  /// The current session generation.
  int get gen => _gen;

  /// Registers every offline SDK listener once. Idempotent: a second call does
  /// nothing. Call from each init entry point after the SDK init resolves.
  void start() {
    if (_started) return;
    _started = true;
    _startRegistrations++;

    CometChat.addOfflineMessageListener(
      _outboxId,
      _HubOfflineMessageListener(),
    );
    CometChat.addSyncListener(_syncId, _HubSyncListener());
    CometChat.addOfflineCacheResetListener(
      _cacheResetId,
      _HubCacheResetListener(),
    );
    CometChat.addMediaDownloadListener(_mediaId, _HubMediaListener());
    CometChat.addMessageListener(_messageId, _HubMessageListener());
    CometChat.addloginListener(_loginId, _HubLoginListener());
  }

  // --- Session / generation (G8, §2.7) --------------------------------------

  /// Records that offline was on during the current session. Called by
  /// [OfflineGate.isOn] on every `true` read.
  void noteOfflineOn() => _sessionOffline = true;

  /// Seeds the session from a restored login (relaunch with a session, where
  /// no `loginSuccess` fires). Called by the kit's init after it restores the
  /// logged-in user.
  void seedSession(String uid) {
    _lastUid ??= uid;
    OfflineGate.isOn(); // records offline-on for this session when it is
  }

  /// Ends the session if offline was on during it: bumps [gen], drops the
  /// send-state dedupe and queued notices, and emits [SessionEnded].
  /// Idempotent across the two logout signals (kit logout + SDK logout).
  void _endSession() {
    final wasOffline = _sessionOffline;
    _lastUid = null;
    _sessionOffline = false;
    if (!wasOffline) return;
    _lastEmitted.clear();
    _pendingNotices.clear();
    _gen++;
    _publish(SessionEnded(_gen));
  }

  /// Called from the kit's own logout path (`CometChatUIKit` logout).
  void onKitLogout() => _endSession();

  void _onLoginSuccess(String uid) {
    final previous = _lastUid;
    if (previous != null && previous != uid) {
      // User switch: end the old session before the new user's first paint.
      _endSession();
    }
    _lastUid = uid; // same uid (token refresh) keeps gen and state
    OfflineGate.isOn(); // records offline-on for the new session
  }

  // --- Publish --------------------------------------------------------------

  void _publish(OfflineHubEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// Posts a notice owned by no single list (cache reset, messages not sent).
  /// It is shown once, by the most recently attached list that shows notices;
  /// with none attached it waits until one attaches. No-op while offline is
  /// off, unless [whenOff] (the notice that reports offline turning off under
  /// unsent messages, C6).
  void postNotice(OfflineNotice notice, {bool whenOff = false}) {
    if (!whenOff && !OfflineGate.isOn()) return;
    if (_sinks.isEmpty) {
      _pendingNotices.add(notice);
    } else {
      _sinks.last(notice);
    }
  }

  /// Attaches a list that shows notices; delivers any queued notices to it.
  /// A list with `hideOfflineNotices` never attaches, so it never takes one.
  void attachNoticeSink(OfflineNoticeSink sink) {
    _sinks.add(sink);
    if (_pendingNotices.isEmpty) return;
    final queued = List.of(_pendingNotices);
    _pendingNotices.clear();
    queued.forEach(sink);
  }

  /// Detaches a list attached with [attachNoticeSink].
  void detachNoticeSink(OfflineNoticeSink sink) => _sinks.remove(sink);

  // --- Send-state dedupe + public event (§2.6, G5) --------------------------

  /// The entry W4 feeds its per-call [MessageSentListener] outcomes through
  /// (W1 stubs the dedupe). Also used by the hub's own outbox listener.
  void reportSend(
    BaseMessage message,
    CometChatMessageSendState state, {
    MessageFailureReason? reason,
  }) {
    if (!OfflineGate.isOn()) return;
    _emitSendState(message, state, reason);
  }

  /// W4: an unsent message the user deleted (`discardLocalMessage`, or a
  /// direct failure dropped from memory). Tells the lists and the
  /// conversation list to drop it, as a `discarded` [SendStateEvent] on the
  /// private channel only: no public event follows a delete (BEH-SEND-36).
  void reportRemoved(BaseMessage message) {
    if (!OfflineGate.isOn()) return;
    final lid = message.localMessageId ?? '';
    if (lid.isNotEmpty) _lastEmitted.remove(lid);
    _publish(
      SendStateEvent(
        _gen,
        lid,
        message,
        CometChatMessageSendState.failed,
        MessageFailureReason.discarded,
      ),
    );
  }

  void _emitSendState(
    BaseMessage message,
    CometChatMessageSendState state,
    MessageFailureReason? reason,
  ) {
    final lid = message.localMessageId;
    if (lid == null || lid.isEmpty) {
      // No localMessageId: bypass the dedupe (every OFF send; nothing to key).
      _fireSendState(lid ?? '', message, state, reason);
      return;
    }
    final prev = _lastEmitted[lid];
    if (!_forwardOnly(prev, state)) return;
    _lastEmitted[lid] = state;
    _fireSendState(lid, message, state, reason);
  }

  void _fireSendState(
    String lid,
    BaseMessage message,
    CometChatMessageSendState state,
    MessageFailureReason? reason,
  ) {
    _publish(SendStateEvent(_gen, lid, message, state, reason));
    // Public additive event for integrators with custom views (G14).
    CometChatMessageEvents.ccMessageSendStateChanged(message, state, reason);
  }

  /// Forward-only transition guard: `sending → sent/failed`,
  /// `failed → sending/sent`, never anything after `sent`, never a repeat.
  static bool _forwardOnly(
    CometChatMessageSendState? prev,
    CometChatMessageSendState next,
  ) {
    if (prev == next) return false;
    if (prev == CometChatMessageSendState.sent) return false; // terminal
    return true;
  }

  // --- Internal handlers driven by the SDK listeners ------------------------

  void _handleOutboxPending(BaseMessage m) {
    if (!OfflineGate.isOn()) return;
    _emitSendState(m, CometChatMessageSendState.sending, null);
  }

  void _handleOutboxSent(BaseMessage m) {
    if (!OfflineGate.isOn()) return;
    _emitSendState(m, CometChatMessageSendState.sent, null);
  }

  void _handleOutboxFailed(BaseMessage m, MessageFailureReason reason) {
    if (!OfflineGate.isOn()) return;
    _emitSendState(m, CometChatMessageSendState.failed, reason);
  }

  void _handleConversationSyncCompleted(List<Conversation> c) {
    if (!OfflineGate.isOn()) return;
    _publish(ConversationSyncCompleted(_gen, c));
  }

  void _handleConversationSyncError(CometChatException e) {
    if (!OfflineGate.isOn()) return;
    _publish(ConversationSyncFailed(_gen, e));
  }

  void _handleMessageSyncCompleted(List<BaseMessage> m, SyncOutcome outcome) {
    if (!OfflineGate.isOn()) return;
    _publish(MessageSyncCompleted(_gen, m, outcome));
  }

  void _handleMessageSyncError(CometChatException e) {
    if (!OfflineGate.isOn()) return;
    _publish(MessageSyncFailed(_gen, e));
  }

  void _handleMessagesSynced(List<BaseMessage> m) {
    if (!OfflineGate.isOn()) return;
    _publish(MessagesUpdated(_gen, m));
  }

  void _handleCacheReset(OfflineCacheResetReason reason, int? lost) {
    if (!OfflineGate.isOn()) return;
    _publish(CacheReset(_gen, reason, lost));
    // The notice goes out here, not from a list, so it is shown once and
    // waits in the queue when no list is mounted (G8, W5).
    final notice = cacheResetNotice(reason, lost);
    if (notice != null) postNotice(notice);
    // Public additive event for integrators (G14).
    CometChatMessageEvents.ccOfflineCacheReset(reason, lost);
  }

  /// The notice for a cache reset: `lost > 0` → [UnsentLost]; unknown and not
  /// an encryption change → [UnsentMaybeLost]; `0` or an encryption change
  /// (its unsent messages already failed `DISCARDED`, BEH-ENC-16) → none.
  @visibleForTesting
  static OfflineNotice? cacheResetNotice(
    OfflineCacheResetReason reason,
    int? lost,
  ) {
    if (lost != null && lost > 0) return UnsentLost(lost);
    if (lost == null && reason != OfflineCacheResetReason.encryptionChanged) {
      return const UnsentMaybeLost();
    }
    return null;
  }

  void _handleMediaDownloaded(
    String? localId,
    String attachmentId,
    String path,
  ) {
    if (!OfflineGate.isOn()) return;
    _publish(MediaReady(_gen, localId, null, path, attachmentId: attachmentId));
  }

  /// Test-only: resets the singleton's mutable state so each test starts clean.
  /// Does not remove SDK listeners (they are never unregistered by design).
  @visibleForTesting
  void debugReset() {
    _started = false;
    _startRegistrations = 0;
    _gen = 0;
    _lastUid = null;
    _sessionOffline = false;
    _lastEmitted.clear();
    _sinks.clear();
    _pendingNotices.clear();
  }

  /// Test-only: how many times [start] actually registered the listeners.
  @visibleForTesting
  int get debugStartRegistrations => _startRegistrations;

  /// Test-only: whether anything still listens to [events].
  @visibleForTesting
  bool get debugHasListeners => _events.hasListener;

  // --- Test seams: drive the private handlers as the SDK listeners would ----
  @visibleForTesting
  /// Test-only: as if the SDK reported an outbox message pending.
  void debugOutboxPending(BaseMessage m) => _handleOutboxPending(m);
  @visibleForTesting
  /// Test-only: as if the SDK reported an outbox message sent.
  void debugOutboxSent(BaseMessage m) => _handleOutboxSent(m);
  @visibleForTesting
  /// Test-only: as if the SDK reported an outbox message failed.
  void debugOutboxFailed(BaseMessage m, MessageFailureReason r) =>
      _handleOutboxFailed(m, r);
  @visibleForTesting
  /// Test-only: as if the SDK reported a login.
  void debugLoginSuccess(String uid) => _onLoginSuccess(uid);
  @visibleForTesting
  /// Test-only: as if the SDK reported a logout.
  void debugLogout() => _endSession();
  @visibleForTesting
  /// Test-only: as if the SDK reported a cache reset.
  void debugCacheReset(OfflineCacheResetReason reason, int? lost) =>
      _handleCacheReset(reason, lost);
  @visibleForTesting
  /// Test-only: as if the SDK delivered synced message updates.
  void debugMessagesSynced(List<BaseMessage> m) => _handleMessagesSynced(m);
  @visibleForTesting
  /// Test-only: as if the SDK completed a message sync.
  void debugMessageSyncCompleted(List<BaseMessage> m, SyncOutcome o) =>
      _handleMessageSyncCompleted(m, o);
  @visibleForTesting
  /// Test-only: as if the SDK finished a media download.
  void debugMediaDownloaded(String? localId, String attId, String path) =>
      _handleMediaDownloaded(localId, attId, path);
}

// --- SDK listener adapters: thin, forward to the singleton -------------------

class _HubOfflineMessageListener implements OfflineMessageListener {
  @override
  void onOutboxMessagePending(BaseMessage message) =>
      OfflineHub.instance._handleOutboxPending(message);
  @override
  void onOutboxMessageSent(BaseMessage message) =>
      OfflineHub.instance._handleOutboxSent(message);
  @override
  void onOutboxMessageFailed(
    BaseMessage message,
    MessageFailureReason reason,
  ) => OfflineHub.instance._handleOutboxFailed(message, reason);
}

class _HubSyncListener extends SyncListener {
  @override
  void onConversationSyncCompleted(List<Conversation> conversations) =>
      OfflineHub.instance._handleConversationSyncCompleted(conversations);
  @override
  void onConversationSyncError(CometChatException error) =>
      OfflineHub.instance._handleConversationSyncError(error);
  @override
  void onMessageSyncCompleted(
    List<BaseMessage> messages,
    SyncOutcome outcome,
  ) => OfflineHub.instance._handleMessageSyncCompleted(messages, outcome);
  @override
  void onMessageSyncError(CometChatException error) =>
      OfflineHub.instance._handleMessageSyncError(error);
}

class _HubCacheResetListener implements OfflineCacheResetListener {
  @override
  void onOfflineCacheReset(
    OfflineCacheResetReason reason,
    int? pendingMessagesLost,
  ) => OfflineHub.instance._handleCacheReset(reason, pendingMessagesLost);
}

class _HubMediaListener implements MediaDownloadListener {
  @override
  void onMediaDownloaded(
    String? messageLocalId,
    String attachmentId,
    String localPath,
  ) => OfflineHub.instance._handleMediaDownloaded(
    messageLocalId,
    attachmentId,
    localPath,
  );
  @override
  void onMediaDownloadFailed(
    String? messageLocalId,
    String attachmentId,
    MediaException error,
  ) {}
}

/// Overrides only `onMessagesSynced`; every other MessageListener method keeps
/// its empty default (the hub does not double-handle live messages).
class _HubMessageListener with MessageListener {
  @override
  void onMessagesSynced(List<BaseMessage> messages) =>
      OfflineHub.instance._handleMessagesSynced(messages);
}

/// Login/logout are not gated: the SDK reports offline off after a logout, so
/// the session decision uses what the hub recorded during the session.
class _HubLoginListener with LoginListener {
  @override
  void loginSuccess(User user) => OfflineHub.instance._onLoginSuccess(user.uid);
  @override
  void logoutSuccess() => OfflineHub.instance._endSession();
}
