import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show
        CallLog,
        CallSession,
        CometChatCalls,
        CometChatCallsException,
        IncomingCallListener,
        InitiatedCall,
        Participant,
        ParticipantEventListeners,
        SessionStatusListeners;
import 'package:flutter/foundation.dart';

import '../shared_ui/src/constants/ui_kit_constants.dart'
    show CallStatusConstants;
import '../shared_ui/src/logging/cometchat_log.dart';
import 'ringing_call_mapping.dart';

/// Follows a call this device placed while it rings, from the caller's
/// prepared session (ringing v2): whether the callee's phone rings, answers,
/// or the call ends before anyone joined.
///
/// Package-private (see `lib/src/`). It replaces the chat SDK's call
/// listener (`onOutgoingCallAccepted`, `onOutgoingCallRejected`), deprecated
/// with the rest of its calling APIs.
///
/// `CometChatCalls.initiateCall` prepares the caller's session without
/// joining it. Its events, per the Calls SDK 5.1 docs:
///
/// * `onParticipantConnected` for the callee: the callee's device prepared
///   the session, so it is ringing ([onRinging]).
/// * `onParticipantJoined` for the callee: the callee answered and joined
///   ([onAnswered]). The caller joins then.
/// * `IncomingCallListener.onIncomingCallEnded` for this session: the
///   callee declined (or was busy) and the backend's terminal push for the
///   call reached this device ([onEnded] with that reason). The push ringer
///   hands it to the Calls SDK, which reports it on the caller too, once per
///   session, though the call never rang here. It needs no room: a callee
///   that declines before its ringer is in the room leaves nothing in it to
///   close (`endSessionForAll: not in the room yet`), and this is then the
///   only signal (Android's UI Kit, 9 Oct 2026).
/// * `onConnectionClosed` (or `onSessionTimedOut`) after this call's
///   prepared session connected: the call ended before the join. The
///   terminal push is given [pushWait] to bring the reason; then
///   `CometChatCalls.getCallDetails` is read, and the call ends as `ended`
///   when that says nothing final, as on Android.
///
/// The same signals as the Android and iOS UI Kits, and nothing else: no
/// status is read while the call rings. The server's `ongoing` is never
/// taken as the answer. The callee's push ringer prepares the session while
/// it rings, and the server then reports the call `ongoing` (and the callee
/// joined) though nobody answered; a caller reading that joined calls that
/// were still ringing. A prepared caller does receive `onParticipantJoined`
/// when the callee joins (checked on two devices, 9 Oct 2026).
final class OutgoingCallWatch {
  /// Watches [sessionId], placed by [callerUid] to [calleeUid] (null for a
  /// group: anyone but the caller).
  OutgoingCallWatch({
    required this.sessionId,
    required this.callerUid,
    required this.calleeUid,
    required this.onRinging,
    required this.onAnswered,
    required this.onEnded,
  });

  /// The call's session.
  final String sessionId;

  /// Who placed it (this device's user), or null when unknown.
  final String? callerUid;

  /// Who it was placed to, or null for a group call.
  final String? calleeUid;

  /// The callee's device rings. Once at most.
  final void Function() onRinging;

  /// The callee answered. Once at most, and never after [onEnded].
  final void Function() onAnswered;

  /// The call ended before it was joined, with its status. Once at most,
  /// and never after [onAnswered].
  final void Function(String status) onEnded;

  /// The Calls SDK's session the listeners go on (tests).
  @visibleForTesting
  static CallSession? Function() session = CallSession.getInstance;

  /// Reads the call's status from the server, or null when it could not
  /// (tests).
  @visibleForTesting
  static Future<String?> Function(String sessionId) fetchStatus = _fetchStatus;

  /// Registers the Calls SDK's incoming call listener (tests).
  @visibleForTesting
  static void Function(String id, IncomingCallListener listener)
  addIncomingCallListener = CometChatCalls.addIncomingCallListener;

  /// Removes it (tests).
  @visibleForTesting
  static void Function(String id) removeIncomingCallListener =
      CometChatCalls.removeIncomingCallListener;

  /// How long a closed prepared session waits for the terminal push to say
  /// how the call ended, before the status is read: Android waits 1.5 s.
  @visibleForTesting
  static Duration pushWait = const Duration(milliseconds: 1500);

  /// Puts the Calls SDK back, after a test replaced it.
  @visibleForTesting
  static void debugReset() {
    session = CallSession.getInstance;
    fetchStatus = _fetchStatus;
    addIncomingCallListener = CometChatCalls.addIncomingCallListener;
    removeIncomingCallListener = CometChatCalls.removeIncomingCallListener;
    pushWait = const Duration(milliseconds: 1500);
  }

  late final _OutgoingSessionListener _sessionListener =
      _OutgoingSessionListener(this);
  late final _OutgoingParticipantListener _participantListener =
      _OutgoingParticipantListener(this);
  late final _OutgoingEndListener _endListener = _OutgoingEndListener(this);
  late final String _listenerId = 'cc_uikit_outgoing_watch_$sessionId';
  CallSession? _session;
  Timer? _pushWaitTimer;
  bool _connectedHere = false;
  bool _fetching = false;
  bool _rang = false;
  bool _settled = false;
  bool _stopped = false;

  /// Starts listening.
  void start() {
    if (_stopped || _session != null) return;
    final s = session();
    _session = s;
    s?.addSessionStatusListener(_sessionListener);
    s?.addParticipantEventListener(_participantListener);
    addIncomingCallListener(_listenerId, _endListener);
  }

  /// Stops everything; nothing is reported after this.
  void stop() {
    if (_stopped) return;
    _stopped = true;
    _pushWaitTimer?.cancel();
    _pushWaitTimer = null;
    removeIncomingCallListener(_listenerId);
    _session?.removeSessionStatusListener(_sessionListener);
    _session?.removeParticipantEventListener(_participantListener);
    _session = null;
  }

  bool _isCallee(Participant participant) {
    final uid = participant.uid;
    if (uid == null || uid.isEmpty || uid == callerUid) return false;
    final callee = calleeUid;
    return callee == null || callee.isEmpty || uid == callee;
  }

  void _connected(Participant participant) {
    if (_stopped || _settled || _rang || !_isCallee(participant)) return;
    _rang = true;
    onRinging();
  }

  void _joined(Participant participant) {
    if (!_isCallee(participant)) return;
    _answered('the callee joined');
  }

  void _answered(String how) {
    if (_stopped || _settled) return;
    _settled = true;
    ccLog('OutgoingCallWatch: $sessionId answered ($how)');
    onAnswered();
  }

  void _ended(String status) {
    if (_stopped || _settled) return;
    _settled = true;
    _pushWaitTimer?.cancel();
    _pushWaitTimer = null;
    ccLog('OutgoingCallWatch: $sessionId ended before the join ($status)');
    onEnded(status);
  }

  /// This call's prepared session connected: a close from now on is its own.
  void _sessionConnected() {
    _connectedHere = true;
  }

  /// The terminal push for [call] reached this device: the call is over,
  /// with [reason], when it is this call and the reason is an end.
  void _pushEnded(InitiatedCall call, String reason) {
    if (_stopped || _settled || call.sessionId != sessionId) return;
    final status = RingingCallMapping.endStatusForReason(reason);
    if (status == null) return;
    ccLog('OutgoingCallWatch: $sessionId ended by push ($reason)');
    _ended(status);
  }

  /// The prepared session closed before the callee joined. The terminal push
  /// is given [pushWait] to say how; then the server is asked, and the call
  /// ends as `ended` when it says nothing final.
  ///
  /// A close before this call's session connected is ignored: the session is
  /// a singleton, and a call placed seconds after the last one has heard the
  /// last one's close.
  void _closed() {
    if (_stopped || _settled || _pushWaitTimer != null) return;
    if (!_connectedHere) {
      ccLog(
        'OutgoingCallWatch: $sessionId: a close before it connected; '
        'not this call\'s',
      );
      return;
    }
    _pushWaitTimer = Timer(pushWait, () {
      _pushWaitTimer = null;
      unawaited(_readStatus());
    });
  }

  Future<void> _readStatus() async {
    if (_stopped || _settled || _fetching) return;
    _fetching = true;
    try {
      final status = await fetchStatus(sessionId);
      // The room closed and nobody joined: the call is over even when the
      // server does not say so yet (`initiated`, unreadable, or `ongoing`,
      // which a callee that only prepared already shows). Only
      // onParticipantJoined is the answer.
      _ended(
        status != null && _isFinal(status) ? status : CallStatusConstants.ended,
      );
    } catch (e) {
      ccLog('OutgoingCallWatch: reading $sessionId failed: $e');
      _ended(CallStatusConstants.ended);
    } finally {
      _fetching = false;
    }
  }

  static bool _isFinal(String status) =>
      status == CallStatusConstants.rejected ||
      status == CallStatusConstants.busy ||
      status == CallStatusConstants.cancelled ||
      status == CallStatusConstants.unanswered ||
      status == CallStatusConstants.ended;

  static Future<String?> _fetchStatus(String sessionId) {
    final completer = Completer<String?>();
    CometChatCalls.getCallDetails(
      sessionId,
      onSuccess: (List<CallLog> logs) {
        if (completer.isCompleted) return;
        String? status;
        for (final log in logs) {
          if (log.sessionId == null || log.sessionId == sessionId) {
            status = log.status;
            break;
          }
        }
        completer.complete(status);
      },
      onError: (CometChatCallsException e) {
        ccLog(
          'OutgoingCallWatch: details of $sessionId: ${e.code} ${e.message} '
          '${e.details}',
        );
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    return completer.future;
  }
}

final class _OutgoingSessionListener extends SessionStatusListeners {
  _OutgoingSessionListener(this._watch);

  final OutgoingCallWatch _watch;

  @override
  void onConnected() => _watch._sessionConnected();

  @override
  void onConnectionClosed() => _watch._closed();

  @override
  void onSessionTimedOut() => _watch._closed();
}

final class _OutgoingParticipantListener extends ParticipantEventListeners {
  _OutgoingParticipantListener(this._watch);

  final OutgoingCallWatch _watch;

  @override
  void onParticipantConnected(Participant participant) =>
      _watch._connected(participant);

  @override
  void onParticipantJoined(Participant participant) =>
      _watch._joined(participant);
}

final class _OutgoingEndListener extends IncomingCallListener {
  _OutgoingEndListener(this._watch);

  final OutgoingCallWatch _watch;

  @override
  void onIncomingCallEnded(InitiatedCall call, String reason) =>
      _watch._pushEnded(call, reason);
}
