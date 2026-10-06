import 'dart:async';

import 'package:flutter/widgets.dart';

import '../cometchat_calls_uikit.dart';
import '../shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';
import '../shared_ui/src/logging/cometchat_log.dart';
import 'calls_lifecycle.dart';

/// Call bookkeeping the call components share: the call ringing on this
/// device, what the call overlays are showing, and the route of each outgoing
/// call screen.
///
/// Package-private. It lives under `lib/src/`, which no barrel exports and
/// which pub and `dart_apitool` treat as the package's private API, so none of
/// this is part of the UI Kit's public API. It is here rather than in private
/// members of [CallEventService] and the overlays because components in other
/// files read it, and Dart privacy is per file.
abstract final class ActiveCallTracker {
  /// The incoming call ringing on this device, not yet answered.
  ///
  /// Android's app keeps this in the UI Kit's `CallManager`: set when the
  /// incoming call is shown, cleared once it is answered, declined or
  /// cancelled. It is kept apart from [CallEventService.activeCall] because
  /// Android checks the two in different places — see [hasActiveCall] and
  /// [isBusy].
  static Call? ringingCall;

  /// Session of the call [CallScreenOverlay] is showing, or null when it shows
  /// nothing. Lets a broadcast "call ended" be matched to the call it is
  /// actually about.
  static String? callScreenSessionId;

  /// Kind of call [CallScreenOverlay] is showing — a 1-on-1 call
  /// ([CallWorkFlow.defaultCalling]) or a group meeting
  /// ([CallWorkFlow.directCalling]) — or null when it shows nothing. Only a
  /// 1-on-1 call counts as a call in progress.
  static CallWorkFlow? callScreenWorkFlow;

  /// Counts the call screens [CallScreenOverlay] has shown: bumped by every
  /// `CallScreenOverlay.show` that puts a screen up, and never by a dismiss.
  ///
  /// The call screen's ownership token (round 4). Each call screen's bloc
  /// takes the count when it is built, and stays the screen that owns the
  /// call on this device while the count is unchanged: until a newer call
  /// screen, for this call or another one, is shown. Only the owner touches
  /// what the whole app shares when it closes — the media session (the
  /// Calls SDK's `CallSession` is one for the app), the call record,
  /// `CallStateService.isActiveCall`, the screen orientation. A screen that
  /// was replaced is closed a frame after its successor was built, and used
  /// to undo all of that under the new call.
  static int callScreenGeneration = 0;

  /// Retires the call screen on show: it no longer owns the call (see
  /// [callScreenGeneration]), though it stays up until a newer screen
  /// replaces it or it is dismissed. A 1-on-1 call answered during a group
  /// meeting does this before it leaves the meeting: a join of the
  /// meeting's that lands during the leave then starts nothing, and its
  /// call view is never mounted to join natively after the leave (round 4
  /// review, correctness 6).
  static void retireCallScreen() => callScreenGeneration++;

  /// The session the UI Kit left last just before another call joins (a
  /// meeting left for an answered call, a session given up before its
  /// native join), with when.
  static ({String sessionId, DateTime at})? _leftBeforeJoin;

  /// How long such a leave counts for the next call screen's join.
  static const Duration _leftBeforeJoinFor = Duration(seconds: 15);

  /// Records that [sessionId] was left just before another call joins. Its
  /// own "left" (and its participant events) can still arrive after the
  /// next call screen has registered its listeners, and the Calls SDK says
  /// nothing about which session an event is for: see
  /// [takeLeftBeforeJoin].
  static void noteLeftBeforeJoin(String sessionId) =>
      _leftBeforeJoin = (sessionId: sessionId, at: now());

  /// The session left just before this join, if any and lately (15 s), for
  /// the call screen about to join: until its own native join it takes a
  /// session end or a participant event for that session's, not its own
  /// (round 4 review, regression 9). Asking forgets it.
  static String? takeLeftBeforeJoin() {
    final left = _leftBeforeJoin;
    _leftBeforeJoin = null;
    if (left == null) return null;
    if (now().difference(left.at) > _leftBeforeJoinFor) return null;
    return left.sessionId;
  }

  /// What the back button does for the call screen [CallScreenOverlay] is
  /// showing: set by that screen's bloc, cleared when it closes. Called when
  /// the user presses back while the screen is up (see
  /// `CallScreenOverlay.show`).
  static void Function()? callScreenBack;

  /// The route each standalone call screen (a `CometChatOngoingCall` the
  /// host pushed) sits on, keyed by its bloc, so the bloc closes exactly
  /// that route, in whatever navigator it is.
  static final Expando<Route<dynamic>> _ongoingCallRoutes =
      Expando<Route<dynamic>>('call screen route');

  /// Records [route] as the route of [bloc]'s call screen.
  static void attachOngoingCallRoute(Object bloc, Route<dynamic> route) =>
      _ongoingCallRoutes[bloc] = route;

  /// The route of [bloc]'s call screen, or null when no screen recorded
  /// one (a host's bloc driving a screen of its own).
  static Route<dynamic>? ongoingCallRouteOf(Object bloc) =>
      _ongoingCallRoutes[bloc];

  /// What back does on each call screen, keyed by the screen's bloc: its
  /// own rule (cancel while connecting, nothing once the call is up), for
  /// the standalone `CometChatOngoingCall`, which hears back itself.
  static final Expando<void Function()> _backHandlers =
      Expando<void Function()>('call screen back');

  /// Records [handler] as what back does on [bloc]'s call screen.
  static void setBackHandlerOf(Object bloc, void Function() handler) =>
      _backHandlers[bloc] = handler;

  /// What back does on [bloc]'s call screen, or null for a bloc that is not
  /// the UI Kit's own.
  static void Function()? backHandlerOf(Object bloc) => _backHandlers[bloc];

  /// How long a call screen waits, once its call view is on screen, for the
  /// Calls SDK to report the join (`onSessionJoined`, or any participant
  /// event) before it gives the call up as a failed join (`JOIN_TIMEOUT`).
  /// The owner chose 30 s (round 4). Tests shorten it, or turn it off with
  /// null.
  static Duration? get nativeJoinTimeout => _nativeJoinTimeout;

  @visibleForTesting
  static set nativeJoinTimeout(Duration? value) => _nativeJoinTimeout = value;

  static Duration? _nativeJoinTimeout = const Duration(seconds: 30);

  /// Session of the call [IncomingCallOverlay] is showing, or null when it
  /// shows nothing, so a dismiss aimed at one call cannot take down the
  /// overlay of another.
  static String? incomingCallSessionId;

  /// Whether the UI Kit has asked the Calls SDK to join a session that has
  /// not been left since: set by `CometChatUIKitCalls.startSession`, cleared
  /// once the session is left (`CometChatUIKitCalls.endSession`, or a
  /// teardown that leaves it), and by a call screen that gave up on a join
  /// the Calls SDK never answered (no call view was mounted, so there is no
  /// session to leave).
  ///
  /// A teardown (logout, user switch, `CallEventService.dispose`) leaves the
  /// media session and stops the Android ongoing-call service only when this
  /// is set or a call screen is up. The Calls plugin cannot say: its
  /// `CallSession.getInstance()` is created eagerly and is never null, so
  /// checking it sent a native leave (on iOS also a CallKit end) at every
  /// teardown, even in an app that never made a call.
  static bool mayHaveMediaSession = false;

  /// How long a second incoming call rings before it is answered with busy.
  ///
  /// Kotlin waits 2 seconds before its busy reject and does not say why. Kept
  /// the same so the caller on the other end sees the same thing from either
  /// platform. Tests set it to zero.
  static Duration busyRejectDelay = const Duration(seconds: 2);

  /// How long an outgoing call rings before the caller gives up on it: the
  /// outgoing call screen then sends `unanswered` and closes. Counted from
  /// the placement ([markPlaced]) when the UI Kit placed the call.
  ///
  /// Nothing else ends an unanswered call: the Dart SDK has no caller-side
  /// timer (Android's SDK sends `unanswered` itself), so the caller rang
  /// until End. The owner chose 45 s, the ring time of master_app's push
  /// and CallKit path. Not configurable; tests shorten it, or turn it off
  /// with null.
  static Duration? get outgoingCallTimeout => _outgoingCallTimeout;

  @visibleForTesting
  static set outgoingCallTimeout(Duration? value) =>
      _outgoingCallTimeout = value;

  static Duration? _outgoingCallTimeout = const Duration(seconds: 45);

  /// When each call this device placed was placed, keyed by its [Call], so
  /// the no-answer timeout counts from the placement, not from the first
  /// build of the outgoing call screen: an app in the background draws no
  /// frames, and the screen (and its timer) only started once it came back.
  static final Expando<DateTime> _placedAt = Expando<DateTime>(
    'outgoing call placed at',
  );

  /// The clock the placement times are read from. Tests move it.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  /// The time now, by [now]: the wall clock, or a test's.
  static DateTime wallClock() => now();

  /// Records that [call] was placed just now: the outgoing call launcher's
  /// first step.
  static void markPlaced(Call call) => _placedAt[call] = now();

  /// How much of [timeout] is left for [call]: all of it for a call the
  /// launcher did not place (a screen a host built itself), none once it
  /// has passed.
  static Duration remainingOf(Call call, Duration timeout) {
    final placedAt = _placedAt[call];
    if (placedAt == null) return timeout;
    final left = timeout - now().difference(placedAt);
    return left.isNegative ? Duration.zero : left;
  }

  /// How long the outgoing call screen waits for the server to answer the
  /// caller's cancel (End, or the no-answer timeout) before it closes
  /// anyway. The request carries on in the background. Tests shorten it.
  static Duration get outgoingEndCloseAfter => _outgoingEndCloseAfter;

  @visibleForTesting
  static set outgoingEndCloseAfter(Duration value) =>
      _outgoingEndCloseAfter = value;

  static Duration _outgoingEndCloseAfter = const Duration(seconds: 10);

  /// How long an incoming call rings on this device before the UI Kit gives
  /// up on it: the banner closes, the ringtone stops and the call stops
  /// counting as ringing. Nothing is sent to the server; the caller's side
  /// ends the call (it gives up at 45 s).
  ///
  /// A safety net (round 3, P3-C10): a cancel the Dart SDK lost (its socket
  /// drops while the app is inactive) left the phone ringing until the user
  /// acted, and every later call answered busy. Longer than every caller's
  /// own timeout, so it rarely ends a call the caller still rings. Tests
  /// shorten it.
  static Duration get incomingRingTimeout => _incomingRingTimeout;

  @visibleForTesting
  static set incomingRingTimeout(Duration value) =>
      _incomingRingTimeout = value;

  static Duration _incomingRingTimeout = const Duration(seconds: 60);

  /// The incoming calls this device is answering or declining now, from the
  /// tap until the server's answer has been dealt with.
  static final Set<String> _responding = <String>{};

  /// The incoming call [sessionId] is being answered or declined here.
  static void respondingTo(String? sessionId) {
    if (sessionId != null && sessionId.isNotEmpty) _responding.add(sessionId);
  }

  /// This device is done answering or declining [sessionId].
  static void doneResponding(String? sessionId) =>
      _responding.remove(sessionId);

  /// Whether this device is answering or declining [sessionId] now: an
  /// "ongoing" or "rejected" for it is this device's own then, not the same
  /// user acting on another device.
  static bool isRespondingTo(String? sessionId) =>
      _responding.contains(sessionId);

  /// Whether the logged-in user is who acted in [event], an "ongoing",
  /// "rejected" or "busy" for a call ringing here: then the same user
  /// answered or declined it on another device, and it stops ringing here.
  ///
  /// The server names the actor as the event's `callInitiator`. Anyone else
  /// acting is not about this device: in a group call, another member
  /// joining sends "ongoing" to every member, and the call must ring on for
  /// the others. When the logged-in user is not known, nobody is taken for
  /// them.
  static bool actedByLoggedInUser(Call event) {
    final actor = event.callInitiator;
    final me = CallsLifecycle.uid ?? CometChatUIKit.loggedInUser?.uid;
    return actor is User && me != null && me.isNotEmpty && actor.uid == me;
  }

  /// The calls this device finished lately (released), newest last, with
  /// when. See [finishedLately].
  static final Map<String, DateTime> _finished = <String, DateTime>{};

  /// How many finished calls are remembered, and for how long.
  static const int _finishedLimit = 20;
  static const Duration _finishedFor = Duration(minutes: 2);

  static void _rememberFinished(String sessionId) {
    _finished.remove(sessionId);
    _finished[sessionId] = now();
    while (_finished.length > _finishedLimit) {
      _finished.remove(_finished.keys.first);
    }
  }

  /// Whether this device finished the call [sessionId] in the last two
  /// minutes (the last 20 calls at most). An "initiated" that arrives for it
  /// now is a late copy (a socket reconnect, a duplicate push): ringing for
  /// it, or answering it busy, would be wrong (round 3, P3-C23).
  static bool finishedLately(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) return false;
    final cutoff = now().subtract(_finishedFor);
    _finished.removeWhere((_, at) => at.isBefore(cutoff));
    return _finished.containsKey(sessionId);
  }

  /// Forgets the calls finished lately: at logout or a user switch.
  static void forgetFinishedCalls() => _finished.clear();

  /// Whether this device is on a call it placed or answered: what Android's
  /// call buttons check (the SDK's active call) before starting another.
  ///
  /// A call that is only ringing does not count, as on Android. A 1-on-1
  /// call screen does, even without a record: on Android every such screen
  /// has the SDK's active call behind it, but here a host app can open one
  /// directly. A group meeting counts for nothing — Android sets no flag for
  /// one (its `CallingState.isActiveMeeting` is never set to true).
  static bool get hasActiveCall =>
      CallEventService.instance.activeCall != null ||
      callScreenWorkFlow == CallWorkFlow.defaultCalling;

  /// Whether a call or meeting must not be started or joined now: a call is
  /// in progress ([hasActiveCall]) or a group meeting is on the call screen
  /// (round 5, the owner's D06 A). The new call's screen used to replace
  /// the meeting's without leaving it.
  ///
  /// Only for starting and joining: [isBusy] still leaves a meeting out, so
  /// an incoming 1-on-1 call rings during one, and answering it leaves the
  /// meeting (round 4).
  static bool get isInCallOrMeeting =>
      hasActiveCall || callScreenWorkFlow == CallWorkFlow.directCalling;

  /// Whether a new incoming call should be answered with busy: a call placed
  /// or answered ([hasActiveCall]) or another one still ringing — Android's
  /// app checks the SDK's active call and its `CallManager` both.
  static bool get isBusy => hasActiveCall || ringingCall != null;

  /// Releases [CallEventService.activeCall] once the call it holds is over
  /// for this device.
  ///
  /// Only when [sessionId] matches the active call's session (or is empty):
  /// the events that end calls are broadcast, and one about another call must
  /// not wipe the record of this one. Kotlin's `CallManager` matches the
  /// same way.
  ///
  /// Called from every place a call screen closes for good, not just from the
  /// SDK and UI Kit events. [hasActiveCall] refuses new calls and answers
  /// incoming ones with busy, so a record left behind by a path that emits no
  /// event — a failed cancel, a failed end — would block every call after it.
  ///
  /// Releases [ringingCall] under the same rule: an incoming call that is
  /// declined, cancelled or fails to be answered is over too.
  ///
  /// [sessionId] is remembered as finished for a while: see
  /// [finishedLately].
  static void release(String? sessionId) {
    final anySession = sessionId == null || sessionId.isEmpty;
    if (!anySession) _rememberFinished(sessionId);
    final service = CallEventService.instance;
    final active = service.activeCall;
    if (active != null &&
        (anySession || active is! Call || active.sessionId == sessionId)) {
      service.activeCall = null;
    }
    final ringing = ringingCall;
    if (ringing != null && (anySession || ringing.sessionId == sessionId)) {
      ringingCall = null;
    }
  }

  /// Releases the records held for [call]: [release] with its session.
  ///
  /// A call with no session releases only a record that holds this very
  /// call. [release] with no session releases every record, and a call that
  /// never got one must not clear another call's (an incoming call ringing,
  /// say).
  static void releaseCall(Call call) {
    final sessionId = call.sessionId;
    if (sessionId != null && sessionId.isNotEmpty) {
      release(sessionId);
      return;
    }
    final service = CallEventService.instance;
    if (identical(service.activeCall, call)) service.activeCall = null;
    if (identical(ringingCall, call)) ringingCall = null;
  }

  /// Releases [ringingCall] only, when it is [sessionId]'s: the incoming
  /// call can no longer be answered on this device (its banner could not be
  /// shown, or was taken down) but was not declined here.
  ///
  /// [CallEventService.activeCall] is never touched, so an accept, which
  /// turns the ringing call into the active one, is unaffected. Nothing goes
  /// to the server: push or CallKit may still be ringing for the same call.
  static void releaseRinging(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) return;
    if (ringingCall?.sessionId == sessionId) ringingCall = null;
  }

  /// [sessionId] stopped ringing on this device without being answered or
  /// declined here: the caller cancelled it, the same user acted on it on
  /// another device, it rang out, or something dismissed its banner by its
  /// session. [releaseRinging], and it is remembered as finished
  /// ([finishedLately]), so a late copy of its "initiated" does not ring it
  /// again.
  ///
  /// [CallEventService.activeCall] is never touched: a call answered outside
  /// the banner (CallKit, a host calling `CometChatUIKitCalls.acceptCall`)
  /// is the active one by now, and its own "ongoing" echo reaching the
  /// banner's bloc used to clear it mid-call.
  static void ringingEnded(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) return;
    _rememberFinished(sessionId);
    releaseRinging(sessionId);
  }

  /// The call component placing a call or starting a meeting right now —
  /// a call buttons bloc, a call logs bloc — from the tap until its screen
  /// is up or placing has failed.
  ///
  /// One at a time across the app: each component dropped a second tap of
  /// its own, but two of them (a header rebuilt for someone else mid-way,
  /// two quick taps on cards that each build a bloc) could each place a
  /// call, stack two outgoing screens and leave one record overwritten.
  static Object? _placingCall;

  /// Whether a call component is placing a call now: see
  /// [beginPlacingCall].
  static bool get isPlacingCall => _placingCall != null;

  /// [owner] starts placing a call. False, and nothing changes, while
  /// another component is placing one: the caller refuses with
  /// `ACTIVE_CALL`.
  static bool beginPlacingCall(Object owner) {
    if (_placingCall != null) return false;
    _placingCall = owner;
    return true;
  }

  /// [owner] has finished placing its call (shown, refused or failed).
  static void endPlacingCall(Object owner) {
    if (identical(_placingCall, owner)) _placingCall = null;
  }

  /// Forgets a placement a test left in flight.
  @visibleForTesting
  static void debugResetPlacingCall() => _placingCall = null;

  /// Call requests on their way to the server — a call being placed, an
  /// accept — each keyed by a future that completes once the request has
  /// landed and been dealt with, and valued with the session it answers (an
  /// accept) or null (a call being placed).
  static final Map<Future<void>, String?> _requestsInFlight =
      <Future<void>, String?>{};

  /// Runs [request], a call request on its way to the server together with
  /// whatever deals with its answer, as one in flight. For an accept,
  /// [acceptingSessionId] is the call it answers.
  ///
  /// A logout waits for the requests in flight (within its bound) before it
  /// logs out: one that lands after the logout began cancels or ends its own
  /// call while the user can still be heard, and the call being accepted is
  /// not declined by the logout as well.
  static Future<T> trackCallRequest<T>(
    Future<T> Function() request, {
    String? acceptingSessionId,
  }) async {
    final landed = Completer<void>();
    _requestsInFlight[landed.future] = acceptingSessionId;
    try {
      return await request();
    } finally {
      _requestsInFlight.remove(landed.future);
      landed.complete();
    }
  }

  /// The call requests still in flight: the future each completes with once
  /// it has been dealt with (never with an error), and the session it
  /// answers for an accept.
  static Map<Future<void>, String?> get callRequestsInFlight =>
      Map<Future<void>, String?>.unmodifiable(_requestsInFlight);

  /// The outgoing call screens open now, keyed by the bloc that drives each.
  static final Map<Object, OutgoingCallScreen> _outgoingScreens =
      <Object, OutgoingCallScreen>{};

  /// Records that [owner] (an outgoing call bloc) drives [screen], so a
  /// logout can cancel its call and close it.
  static void outgoingScreenOpened(Object owner, OutgoingCallScreen screen) {
    _outgoingScreens[owner] = screen;
  }

  /// Forgets [owner]'s screen: it has closed.
  static void outgoingScreenClosed(Object owner) {
    _outgoingScreens.remove(owner);
  }

  /// The outgoing call screen [owner] drives was disposed while [owner] (a
  /// bloc the host handed the screen) stays open: see
  /// [OutgoingCallScreen.screenGone].
  static void outgoingScreenGone(Object owner) {
    try {
      _outgoingScreens[owner]?.screenGone();
    } catch (e) {
      ccLog('ActiveCallTracker: an outgoing call screen went: $e');
    }
  }

  /// The calls of the outgoing call screens that are still ringing.
  static List<Call> get ringingOutgoingCalls => <Call>[
    for (final screen in _outgoingScreens.values)
      if (screen.isRinging()) screen.call,
  ];

  /// Closes every open outgoing call screen without cancelling its call
  /// again (the caller has dealt with the server), and forgets them.
  static void closeOutgoingScreens() {
    final screens = List<OutgoingCallScreen>.of(_outgoingScreens.values);
    _outgoingScreens.clear();
    for (final screen in screens) {
      try {
        screen.closeLocally();
      } catch (e) {
        ccLog('ActiveCallTracker: closing an outgoing call screen: $e');
      }
    }
  }

  /// The route each outgoing call screen was pushed as, keyed by its bloc.
  static final Expando<Route<dynamic>> _outgoingCallRoutes =
      Expando<Route<dynamic>>('outgoing call screen route');

  /// Records [route] as the screen [bloc] drives, so the bloc closes exactly
  /// that screen. A null [route] leaves any earlier one in place.
  static void attachOutgoingCallRoute(Object bloc, Route<dynamic>? route) {
    if (route != null) _outgoingCallRoutes[bloc] = route;
  }

  /// The route recorded for [bloc] by [attachOutgoingCallRoute], or null when
  /// the bloc is driving a screen it did not build.
  static Route<dynamic>? outgoingCallRouteOf(Object bloc) =>
      _outgoingCallRoutes[bloc];
}

/// What a logout needs from an open outgoing call screen. Package-private.
final class OutgoingCallScreen {
  /// Describes the screen for [call].
  const OutgoingCallScreen({
    required this.call,
    required this.isRinging,
    required this.closeLocally,
    required this.screenGone,
  });

  /// The call the screen is placing.
  final Call call;

  /// Whether the call is still ringing: not answered, declined or cancelled.
  final bool Function() isRinging;

  /// Closes the screen and releases the call's record, sending nothing to
  /// the server.
  final void Function() closeLocally;

  /// The screen's widget was disposed while its bloc, one the host handed
  /// it, stays open: nothing is left on screen to ring or to time out.
  final void Function() screenGone;
}
