import '../call_ui/src/call_event_service.dart';
import '../cometchat_calls_uikit.dart' show Call, User;
import '../shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';
import '../shared_ui/src/logging/cometchat_log.dart';
import 'active_call_tracker.dart';
import 'calls_lifecycle.dart';

/// What to do with an incoming call: see [IncomingCallGate.admit].
enum IncomingVerdict {
  /// Not a call to ring: this user's own, one already handled here, or a
  /// late copy of one this device finished.
  ignore,

  /// A call to answer with busy: this device is already in a call, or
  /// another one rings.
  busy,

  /// A call to ring.
  ring,
}

/// The checks every incoming call goes through before it rings, whichever
/// way it arrived: the chat SDK's call listener (web, ringing v1) or the
/// Calls SDK's incoming call listener (a push, ringing v2).
///
/// Package-private (see `lib/src/`).
abstract final class IncomingCallGate {
  /// What to do with [call], an incoming call that just arrived. Logs why it
  /// is not rung.
  static IncomingVerdict admit(Call call) {
    final sessionId = call.sessionId;
    final initiator = call.callInitiator;

    // The logged-in user's own call (an echo). Read now, not at start: the
    // user may have switched since. The started user comes first because a
    // host's direct CometChat.login leaves CometChatUIKit.loggedInUser unset
    // or stale.
    final myUid = CallsLifecycle.uid ?? CometChatUIKit.loggedInUser?.uid;
    if (initiator is User && myUid != null && initiator.uid == myUid) {
      return IncomingVerdict.ignore;
    }

    // A call this device is already handling. Duplicate pushes can deliver
    // the same call twice, which created a second banner and failed the
    // reject with "call is ended". And a call accepted from the native call
    // UI is opened straight onto the call screen without an active call
    // record: the busy check below saw a call screen up and rejected the
    // very call the user had just accepted.
    if (isHandling(sessionId)) {
      ccLog('IncomingCallGate: ignoring a duplicate of $sessionId');
      return IncomingVerdict.ignore;
    }

    // A call this device finished with (declined, cancelled, ended, given up
    // on) in the last two minutes: a late copy of its "initiated".
    if (ActiveCallTracker.finishedLately(sessionId)) {
      ccLog('IncomingCallGate: ignoring $sessionId, finished here already');
      return IncomingVerdict.ignore;
    }

    // Already in a call, or another one rings: answered with busy instead of
    // stacking a second incoming call over the first, as Kotlin's app does.
    // The records of the call in progress are left untouched.
    if (ActiveCallTracker.isBusy) {
      ccLog('IncomingCallGate: busy, answering $sessionId with busy');
      return IncomingVerdict.busy;
    }
    return IncomingVerdict.ring;
  }

  /// Whether [sessionId] is a call this device is already on: the active
  /// call, the call screen, or the incoming call ringing here.
  static bool isHandling(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) return false;
    final active = CallEventService.instance.activeCall;
    return (active is Call && active.sessionId == sessionId) ||
        ActiveCallTracker.ringingCall?.sessionId == sessionId ||
        ActiveCallTracker.callScreenSessionId == sessionId ||
        ActiveCallTracker.incomingCallSessionId == sessionId;
  }
}
