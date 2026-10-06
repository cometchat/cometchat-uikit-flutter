import 'dart:async';

import '../call_ui/src/call_operations/di/call_operations_service_locator.dart';
import '../call_ui/src/incoming_call/cometchat_display_incoming_call_overlay.dart';
import '../cometchat_calls_uikit.dart' show Call;
import '../shared_ui/src/constants/ui_kit_constants.dart'
    show CallStatusConstants;
import '../shared_ui/src/logging/cometchat_log.dart';
import 'active_call_tracker.dart';
import 'incoming_ringtone.dart';

/// Answers an incoming call with busy, as the UI Kit does when one arrives
/// while this device is in a call or another one rings.
///
/// Package-private (see `lib/src/`).
///
/// Waits [ActiveCallTracker.busyRejectDelay] first, as Kotlin does (the
/// caller on the other end sees the same thing from either platform), then
/// sends `busy`. Best effort: a failure is logged, and the call simply rings
/// out on the caller's side.
Future<void> rejectAsBusy(Call call) async {
  final sessionId = call.sessionId;
  if (sessionId == null || sessionId.isEmpty) return;
  await Future<void>.delayed(ActiveCallTracker.busyRejectDelay);
  final result = await CallOperationsServiceLocator.instance.rejectCallUseCase
      .call(sessionId, CallStatusConstants.busy);
  result.fold(
    (failure) => ccLog(
      'CallEventService: busy reject failed for $sessionId: '
      '${failure.message}',
    ),
    (_) => ccLog('CallEventService: rejected $sessionId as busy'),
  );
}

/// The user's own call came up on this device ([sessionId]: a call they
/// placed or answered, or a group meeting they joined) while another
/// incoming call still rang here: that call is answered busy (the owner's
/// rule, round 3 review).
///
/// It used to ring on for up to 60 s under the call screen, which covers its
/// banner: the ringtone and the vibration went on with nothing on screen to
/// stop them, and the caller rang on. Android's sample does the same on any
/// "outgoing call accepted": it closes its incoming call snackbar and stops
/// the sound.
///
/// Its banner closes, the ringtone and the vibration stop, and it stops
/// counting as ringing and is remembered as finished here, so a late copy of
/// its "initiated" does not ring again. The ringtone's audio is handed to
/// the call starting rather than given back: giving it back (on iOS, a
/// deactivation queued natively) could land on the call's session as the
/// Calls engine takes it. Then `busy` goes to the server, as for an incoming
/// call that arrives during a call ([rejectAsBusy]).
///
/// Nothing happens for the call this device is answering itself (its own
/// call screen is [sessionId], or its accept is on its way).
void rejectRingingAsBusy({required String sessionId}) {
  final ringing = ActiveCallTracker.ringingCall;
  final ringingId = ringing?.sessionId;
  if (ringing == null || ringingId == null || ringingId.isEmpty) return;
  if (ringingId == sessionId || ActiveCallTracker.isRespondingTo(ringingId)) {
    return;
  }
  ccLog(
    'CallEventService: $sessionId came up while $ringingId rang; answering '
    '$ringingId busy',
  );
  IncomingCallOverlay.dismiss(sessionId: ringingId);
  ActiveCallTracker.ringingEnded(ringingId);
  // Whoever rings: a host's own incoming call bloc is not closed by the
  // banner's dismiss.
  if (IncomingRingtone.isRinging) unawaited(IncomingRingtone.handOverAll());
  unawaited(rejectAsBusy(ringing));
}
