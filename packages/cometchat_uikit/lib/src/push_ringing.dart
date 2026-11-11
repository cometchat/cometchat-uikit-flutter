import 'dart:async';

import 'package:flutter/foundation.dart';

import '../call_ui/src/call_event_service.dart';
import '../call_ui/src/call_operations/di/call_operations_service_locator.dart';
import '../call_ui/src/call_settings/call_navigation_context.dart';
import '../call_ui/src/call_settings/cometchat_call_push_bridge.dart';
import '../call_ui/src/call_settings/cometchat_uikit_calls.dart';
import '../call_ui/src/incoming_call/cometchat_display_incoming_call_overlay.dart';
import '../call_ui/src/ongoing_call/call_screen_overlay.dart';
import '../call_ui/src/utils/call_extension_constants.dart';
import '../cometchat_calls_uikit.dart'
    show
        Call,
        CometChatCalls,
        CometChatException,
        IncomingCallListener,
        InitiatedCall,
        User;
import '../shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';
import '../shared_ui/src/constants/ui_kit_constants.dart'
    show CallStatusConstants, OnError;
import '../shared_ui/src/logging/cometchat_log.dart';
import 'active_call_tracker.dart';
import 'busy_reject.dart';
import 'call_errors.dart';
import 'call_permission_notice.dart';
import 'call_session_settings.dart';
import 'calling_configuration_resolver.dart';
import 'calls_lifecycle.dart';
import 'calls_sdk_session.dart';
import 'incoming_call_gate.dart';
import 'ringing_call_mapping.dart';

/// Ringing v2 on the incoming side: calls ring through push, on the push
/// ringer's own ring screen (Android) or CallKit (iOS), not in the UI Kit.
///
/// Package-private (see `lib/src/`). [start]ed with call handling for the
/// logged-in user on Android and iOS (web keeps the chat SDK's call
/// listener), it:
///
/// * follows the calls the push ringer hands the Calls SDK
///   (`CometChatCalls.addIncomingCallListener`): records the one ringing, so
///   a second call is answered busy ([IncomingCallGate]). A call that
///   arrives during a 1-on-1 call on the call screen rings over it (call
///   waiting), as the push ringer does; one that arrives while another
///   rings, or while a call this device placed still rings, is answered
///   busy;
/// * joins every call answered on the ring screen, on the UI Kit's call
///   screen, through the app's [CometChatCallPushBridge] (as Android's UI
///   Kit does; the app never joins calls itself). Answered over a 1-on-1
///   call, it ends that call first ("End & accept");
/// * lets go of a call that stopped ringing, and closes the call screen of
///   an answered call ended from CallKit.
abstract final class PushRinging {
  /// The id the incoming call listener is registered under.
  static const String listenerId = 'CometChatUIKit.PushRinging';

  /// The app's push ringer, or null: on web, or when the app set none.
  static CometChatCallPushBridge? get bridge =>
      kIsWeb ? null : CometChatUIKit.authenticationSettings?.callPushBridge;

  /// Registers the Calls SDK's incoming call listener (tests).
  @visibleForTesting
  static void Function(String id, IncomingCallListener listener)
  addIncomingCallListener = CometChatCalls.addIncomingCallListener;

  /// Removes it (tests).
  @visibleForTesting
  static void Function(String id) removeIncomingCallListener =
      CometChatCalls.removeIncomingCallListener;

  /// How long a join waits for the app's navigator: an answer can launch the
  /// app, and the first frame comes after the UI Kit starts.
  @visibleForTesting
  static Duration navigatorWait = const Duration(seconds: 2);

  /// How long a call on screen is given to leave before an answered call
  /// joins anyway.
  static const Duration _leaveLimit = Duration(seconds: 3);

  static final _IncomingObserver _observer = _IncomingObserver();
  static StreamSubscription<CometChatPushCall>? _answered;
  static StreamSubscription<CometChatPushCallEnded>? _ended;
  static bool _started = false;

  /// Whether it is started.
  static bool get isStarted => _started;

  /// Starts following incoming calls and the app's push ringer. Idempotent.
  ///
  /// The bridge's streams are listened to from here, as call handling
  /// starts: an answer that launched the app is held by the push ringer for
  /// its first listener, and joins once the Calls SDK is ready.
  static void start() {
    if (kIsWeb || _started) return;
    _started = true;
    addIncomingCallListener(listenerId, _observer);
    final push = bridge;
    if (push == null) {
      // On the console, not only dart:developer: since 6.3.0 an app without
      // a bridge gets no incoming calls on Android and iOS, and an app
      // upgraded from 6.2.x would otherwise lose them with no visible sign.
      ccLogConsole(
        'Incoming calls will not ring on Android/iOS: set '
        'UIKitSettingsBuilder.callPushBridge (required since 6.3.0). '
        'Without it, only calls the app joins itself are handled.',
      );
      return;
    }
    _answered = push.answered.listen(
      (call) => unawaited(join(call)),
      onError: (Object e) => ccLog('PushRinging: answered stream: $e'),
    );
    _ended = push.ended.listen(
      ended,
      onError: (Object e) => ccLog('PushRinging: ended stream: $e'),
    );
  }

  /// Stops it. Idempotent.
  static void stop() {
    if (!_started) return;
    _started = false;
    removeIncomingCallListener(listenerId);
    unawaited(_answered?.cancel());
    unawaited(_ended?.cancel());
    _answered = null;
    _ended = null;
  }

  /// [call] rings on this device (the push ringer handed it in).
  @visibleForTesting
  static void received(InitiatedCall call) {
    _forgetRingingPastItsWindow();
    final ringing = _asCall(call);
    switch (IncomingCallGate.admit(ringing)) {
      case IncomingVerdict.ignore:
        return;
      case IncomingVerdict.busy:
        // Call waiting: the push ringer rings it over the call in progress,
        // and answering it ends that call ([join]). Recorded as ringing, so
        // a third call is still answered busy.
        if (_ringsOverCallInProgress(call.sessionId)) {
          ccLog(
            'PushRinging: ${call.sessionId} rings over '
            '${ActiveCallTracker.callScreenSessionId}',
          );
          _recordRinging(ringing);
          return;
        }
        // Busy, with the right status (rejectCall "busy" on the Calls SDK),
        // and the ring stopped: the ringer's own decline would send
        // "rejected" for a call it does not know this device is in.
        unawaited(rejectAsBusy(ringing));
        return;
      case IncomingVerdict.ring:
        ccLog('PushRinging: ${call.sessionId} rings');
        _recordRinging(ringing);
    }
  }

  /// When the call last recorded as ringing started ringing.
  static ({String sessionId, DateTime at})? _ringStarted;

  /// Records [ringing] as the call ringing on this device.
  static void _recordRinging(Call ringing) {
    ActiveCallTracker.ringingCall = ringing;
    _ringStarted = (
      sessionId: ringing.sessionId ?? '',
      at: ActiveCallTracker.wallClock(),
    );
  }

  /// Gives up on a call still recorded as ringing past the ring window
  /// ([ActiveCallTracker.incomingRingTimeout]) with no end heard for it.
  ///
  /// Every later call was answered busy for as long as such a record stayed
  /// — until the user placed a call, which clears it — because nothing timed
  /// it out: the incoming call screen that did ([IncomingCallBloc]) is not
  /// shown with a push ringer. Read when the next call arrives rather than
  /// on a timer, which iOS does not run while the app is suspended. The
  /// push ringer stops ringing by the same deadline.
  static void _forgetRingingPastItsWindow() {
    final started = _ringStarted;
    final ringing = ActiveCallTracker.ringingCall;
    if (started == null || ringing == null) return;
    final sessionId = ringing.sessionId ?? '';
    if (sessionId != started.sessionId) return;
    final elapsed = ActiveCallTracker.wallClock().difference(started.at);
    if (elapsed < ActiveCallTracker.incomingRingTimeout) return;
    if (ActiveCallTracker.isRespondingTo(sessionId)) return;
    ccLog(
      'PushRinging: $sessionId was still recorded as ringing '
      '${elapsed.inSeconds} s on, with no end heard; giving up on it here',
    );
    _ringStarted = null;
    ActiveCallTracker.ringingEnded(sessionId);
  }

  /// [sessionId] stopped ringing on this device without being answered
  /// here ([reason]): cancelled, timed out, declined, or answered or
  /// declined on another device.
  @visibleForTesting
  static void stoppedRinging(String sessionId, String reason) {
    if (sessionId.isEmpty) return;
    ccLog('PushRinging: $sessionId stopped ringing ($reason)');
    // The deprecated incoming call screen, for an app that still shows it.
    IncomingCallOverlay.dismiss(sessionId: sessionId);
    if (!ActiveCallTracker.isRespondingTo(sessionId)) {
      ActiveCallTracker.ringingEnded(sessionId);
    }
  }

  /// The push ringer reports [event]: a call that stopped ringing, or an
  /// answered call ended from CallKit (iOS), whose call screen closes.
  @visibleForTesting
  static void ended(CometChatPushCallEnded event) {
    final sessionId = event.call.sessionId;
    stoppedRinging(sessionId, event.reason);
    if (CallScreenOverlay.isShowing &&
        ActiveCallTracker.callScreenSessionId == sessionId) {
      ccLog('PushRinging: $sessionId ended from the system call UI');
      unawaited(_leaveAndClose(sessionId));
    }
  }

  /// Joins [answered], a call answered on the ring screen, on the UI Kit's
  /// call screen, as the UI Kit's own Accept does.
  ///
  /// Nothing happens for a call this device is joining or has on screen
  /// already (its Accept answered through the ringer), on web, or once a
  /// logout began. It waits for the Calls SDK (bounded) and for the app's
  /// navigator, which an answer that launched the app may not have yet.
  ///
  /// Answered over a 1-on-1 call on the call screen (call waiting: it rang
  /// over that call), the call in progress is ended first, as the push
  /// ringer's "Answering ends your current call" and CallKit's "End &
  /// Accept" say: its session is left, which is how ringing v2 ends a call,
  /// so the other side's screen closes on its "peer left" rule. Answered
  /// during any other call (one this device placed that still rings, say)
  /// it is declined through the push ringer and the call in progress stays.
  /// A group meeting on screen is left first, as when a call is accepted
  /// during one (meetings do not make the device busy).
  @visibleForTesting
  static Future<void> join(CometChatPushCall answered) async {
    final sessionId = answered.sessionId;
    if (kIsWeb || sessionId.isEmpty) return;
    if (_joinedOrJoining(sessionId)) return;
    if (CallsLifecycle.isPreparingLogout) return;
    // Read before the active record becomes this call's.
    final callToEnd = _callOnScreenToEnd(sessionId);
    if (callToEnd == null && _inAnotherCall(sessionId)) {
      _declineSecondCall(sessionId);
      return;
    }
    final epoch = CallsLifecycle.callEpoch;

    // Taken off the ringing record now: a second call while this one
    // connects is answered busy, not stacked over it.
    final record = _answeredRecord(answered);
    CallEventService.instance.activeCall = record;
    if (ActiveCallTracker.ringingCall?.sessionId == sessionId) {
      ActiveCallTracker.ringingCall = null;
    }
    // The deprecated incoming call screen, for an app that still shows it
    // and whose user answered on the ring screen instead.
    IncomingCallOverlay.dismiss(sessionId: sessionId);

    await CallsSdkSession.instance.ensureReady();
    if (epoch != CallsLifecycle.callEpoch) return;
    if (_joinedOrJoining(sessionId)) return;
    if (!await _waitForNavigator()) {
      ccLog('PushRinging: no navigator to show $sessionId on');
    }
    if (epoch != CallsLifecycle.callEpoch) return;

    if (callToEnd != null) {
      await _endCallOnScreen(callToEnd, before: sessionId);
    } else {
      await _leaveCallOnScreen(sessionId);
    }
    if (epoch != CallsLifecycle.callEpoch) return;
    // Its own Accept may have joined it meanwhile.
    if (_joinedOrJoining(sessionId)) return;

    final config =
        CallingConfigurationResolver.resolved?.incomingCallConfiguration;
    ccLog('PushRinging: joining $sessionId, answered on the ring screen');
    CallScreenOverlay.show(
      sessionId: sessionId,
      sessionSettingsBuilder: CallSessionSettings.forCall(
        isVideo: answered.isVideo,
        hostBuilder: config?.callSettingsBuilder,
      ),
      callWorkFlow: CallWorkFlow.defaultCalling,
      onError: _onJoinError(config?.onError, isVideo: answered.isVideo),
    );
  }

  /// What a call answered on the ring screen reports while its screen joins
  /// and runs: the app's [onError], when it gave one. Without one, a call
  /// that could not join because the microphone (or camera) was refused
  /// shows the notice the UI Kit's incoming call screen shows
  /// ([CallPermissionNotice]): the call screen asks again before it joins,
  /// and closes when it is still refused, so the user would otherwise see
  /// nothing. (The call stays `ongoing` on the server, answered by the push
  /// ringer: the caller ends it.)
  static OnError _onJoinError(OnError? onError, {required bool isVideo}) {
    return (Exception e) {
      if (onError != null) {
        onError(e);
        return;
      }
      if (e is CometChatException &&
          (e.code == CallErrorCodes.permissionDenied ||
              e.code == CallErrorCodes.permissionPermanentlyDenied)) {
        CallPermissionNotice.show(
          isVideoCall: isVideo,
          permanentlyDenied:
              e.code == CallErrorCodes.permissionPermanentlyDenied,
        );
      }
    };
  }

  /// Whether [sessionId] is joining or on screen already: the UI Kit's own
  /// Accept for it (whose answer through the ringer brings it back here; the
  /// incoming call screen joins it itself, so it counts until that screen
  /// closes), or a second report of the same answer.
  static bool _joinedOrJoining(String sessionId) =>
      ActiveCallTracker.isRespondingTo(sessionId) ||
      ActiveCallTracker.isAcceptingOnScreen(sessionId) ||
      ActiveCallTracker.callScreenSessionId == sessionId;

  /// Whether this device is in a 1-on-1 call other than [sessionId]: one it
  /// placed (ringing or answered) or answered, or one on the call screen.
  static bool _inAnotherCall(String sessionId) {
    final active = CallEventService.instance.activeCall;
    if (active is Call &&
        active.sessionId != null &&
        active.sessionId != sessionId) {
      return true;
    }
    return CallScreenOverlay.isShowing &&
        ActiveCallTracker.callScreenWorkFlow == CallWorkFlow.defaultCalling &&
        ActiveCallTracker.callScreenSessionId != sessionId;
  }

  /// The 1-on-1 call on the call screen, other than [sessionId], when it is
  /// the only call this device is in: the call a call ringing over it ends
  /// once answered. Null otherwise: no such screen, or the active record is
  /// another call (one this device placed that still rings, say).
  static ({String sessionId, Call? record})? _callOnScreenToEnd(
    String sessionId,
  ) {
    final onScreen = ActiveCallTracker.callScreenSessionId;
    if (!CallScreenOverlay.isShowing ||
        ActiveCallTracker.callScreenWorkFlow != CallWorkFlow.defaultCalling ||
        onScreen == null ||
        onScreen.isEmpty ||
        onScreen == sessionId) {
      return null;
    }
    final active = CallEventService.instance.activeCall;
    if (active == null) return (sessionId: onScreen, record: null);
    if (active is Call && active.sessionId == onScreen) {
      return (sessionId: onScreen, record: active);
    }
    return null;
  }

  /// Whether an incoming call rings over the call in progress (call
  /// waiting) rather than being answered busy: the push ringer rings it
  /// and can report its answer, nothing else rings, and the call in
  /// progress is a 1-on-1 call on the call screen ([_callOnScreenToEnd]).
  static bool _ringsOverCallInProgress(String sessionId) =>
      bridge != null &&
      ActiveCallTracker.ringingCall == null &&
      _callOnScreenToEnd(sessionId) != null;

  /// Ends [call], the 1-on-1 call on the call screen, before [before] (a
  /// call answered over it) joins: "End & accept".
  ///
  /// As the UI Kit's End does, the session is left (nothing goes to the
  /// server; the other side's screen closes on its "peer left" rule), the
  /// end is announced (`ccCallEnded`) and the push ringer hears it is over
  /// (iOS CallKit). Its screen stops owning the call first, so its own late
  /// "left" ends nothing, and the answered call's screen takes that "left"
  /// for the ended call's, not its own. That screen replaces this one.
  ///
  /// Nothing to do when the call already ended meanwhile (the other side
  /// hung up, or the push ringer left its session for the answer).
  static Future<void> _endCallOnScreen(
    ({String sessionId, Call? record}) call, {
    required String before,
  }) async {
    final ending = call.sessionId;
    if (!CallScreenOverlay.isShowing ||
        ActiveCallTracker.callScreenSessionId != ending) {
      return;
    }
    ccLog('PushRinging: ending $ending, answered $before over it');
    ActiveCallTracker.retireCallScreen();
    ActiveCallTracker.noteLeftBeforeJoin(ending);
    try {
      await CallOperationsServiceLocator.instance.endSessionUseCase
          .call()
          .timeout(_leaveLimit);
    } catch (e) {
      ccLog('PushRinging: leaving $ending: $e');
    }
    // The active record is the answered call's by now: only the ended
    // call's own records go.
    ActiveCallTracker.release(ending);
    CallsLifecycle.endedHere(ending, call: call.record);
  }

  /// Declines [sessionId], answered on the ring screen during another call,
  /// through the push ringer (as Android's UI Kit does), and lets go of it.
  static void _declineSecondCall(String sessionId) {
    ccLog(
      'PushRinging: $sessionId was answered during another call; declining '
      'it through the push ringer',
    );
    if (ActiveCallTracker.ringingCall?.sessionId == sessionId) {
      ActiveCallTracker.ringingEnded(sessionId);
    }
    final push = bridge;
    if (push == null) return;
    unawaited(
      push
          .decline(sessionId)
          .catchError(
            (Object e) => ccLog('PushRinging: declining $sessionId: $e'),
          ),
    );
  }

  /// The active call record for [answered]: the ringing call, when it is
  /// this one, else one built from what the push carried.
  static Call _answeredRecord(CometChatPushCall answered) {
    final ringing = ActiveCallTracker.ringingCall;
    final base = ringing != null && ringing.sessionId == answered.sessionId
        ? ringing
        : _fromPush(answered);
    return RingingCallMapping.withStatus(base, CallStatusConstants.ongoing);
  }

  static Call _fromPush(CometChatPushCall call) {
    final callerUid = call.callerUid;
    final caller = callerUid == null || callerUid.isEmpty
        ? null
        : User(
            uid: callerUid,
            name: call.callerName ?? callerUid,
            avatar: call.callerAvatarUrl,
          );
    return Call(
      sessionId: call.sessionId,
      callStatus: CallStatusConstants.initiated,
      type: call.callType,
      receiverType: call.receiverType,
      receiverUid: CallsLifecycle.uid ?? '',
      callInitiator: caller,
      sender: caller,
    );
  }

  /// [call], as the chat SDK's [Call] the call records hold.
  static Call _asCall(InitiatedCall call) =>
      RingingCallMapping.fromInitiated(call, receiver: _me);

  static User? get _me => CometChatUIKit.loggedInUser;

  static Future<bool> _waitForNavigator() async {
    final until = DateTime.now().add(navigatorWait);
    while (CallNavigationContext.navigatorKey.currentState?.overlay == null) {
      if (DateTime.now().isAfter(until)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return true;
  }

  /// Leaves the group meeting on screen before [sessionId] joins: the Calls
  /// SDK has one session for the app. Its screen stops owning the call
  /// first, and its late "left" is taken for its own, not the new call's.
  /// (A 1-on-1 call on screen is ended instead: see [_endCallOnScreen].)
  static Future<void> _leaveCallOnScreen(String sessionId) async {
    final onScreen = ActiveCallTracker.callScreenSessionId;
    if (!CallScreenOverlay.isShowing ||
        ActiveCallTracker.callScreenWorkFlow != CallWorkFlow.directCalling ||
        onScreen == null ||
        onScreen == sessionId) {
      return;
    }
    ccLog('PushRinging: leaving $onScreen before joining $sessionId');
    ActiveCallTracker.retireCallScreen();
    ActiveCallTracker.noteLeftBeforeJoin(onScreen);
    try {
      await CallOperationsServiceLocator.instance.endSessionUseCase
          .call()
          .timeout(_leaveLimit);
    } catch (e) {
      ccLog('PushRinging: leaving $onScreen: $e');
    }
  }

  /// Leaves [sessionId]'s session and closes its call screen.
  static Future<void> _leaveAndClose(String sessionId) async {
    try {
      await CometChatUIKitCalls.endSession();
    } catch (e) {
      ccLog('PushRinging: leaving $sessionId: $e');
    }
    CallScreenOverlay.dismiss(sessionId: sessionId);
    ActiveCallTracker.release(sessionId);
  }

  /// Puts everything back (tests).
  @visibleForTesting
  static void debugReset() {
    stop();
    addIncomingCallListener = CometChatCalls.addIncomingCallListener;
    removeIncomingCallListener = CometChatCalls.removeIncomingCallListener;
    navigatorWait = const Duration(seconds: 2);
    _ringStarted = null;
  }
}

final class _IncomingObserver extends IncomingCallListener {
  @override
  void onIncomingCallReceived(InitiatedCall call) {
    try {
      PushRinging.received(call);
    } catch (e, stackTrace) {
      ccLog('PushRinging: incoming ${call.sessionId}: $e\n$stackTrace');
    }
  }

  @override
  void onIncomingCallEnded(InitiatedCall call, String reason) {
    try {
      PushRinging.stoppedRinging(call.sessionId, reason);
    } catch (e, stackTrace) {
      ccLog('PushRinging: ended ${call.sessionId}: $e\n$stackTrace');
    }
  }
}
