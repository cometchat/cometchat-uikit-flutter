import 'dart:async';

import 'package:flutter/foundation.dart';

import '../call_ui/src/call_event_service.dart';
import '../call_ui/src/call_logs/di/call_logs_service_locator.dart';
import '../call_ui/src/call_operations/di/call_operations_service_locator.dart';
import '../call_ui/src/incoming_call/cometchat_display_incoming_call_overlay.dart';
import '../call_ui/src/utils/call_state_service.dart';
import '../call_ui/src/ongoing_call/call_screen_overlay.dart';
import '../call_ui/src/utils/call_extension_constants.dart';
import '../cometchat_calls_uikit.dart'
    show
        Call,
        CallListener,
        CallSession,
        CometChat,
        CometChatOngoingCallService,
        LoginListener,
        User;
import '../shared_ui/src/constants/ui_kit_constants.dart'
    show CallStatusConstants, MessageCategoryConstants;
import '../shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';
import '../shared_ui/src/events/call_events/cometchat_call_event_listener.dart';
import '../shared_ui/src/events/call_events/cometchat_call_events.dart';
import '../shared_ui/src/logging/cometchat_log.dart';
import 'active_call_tracker.dart';
import 'calling_configuration_resolver.dart';
import 'calls_sdk_session.dart';
import 'ghost_join_guard.dart';
import 'incoming_ringtone.dart';

/// Starts and stops the UI Kit's call handling for the logged-in user.
///
/// Package-private (see `lib/src/`). `CometChatUIKit` starts it at login and
/// `CallEventService.init`/`dispose` are thin public wrappers over it.
///
/// [start] registers the global call listeners first, synchronously, before
/// anything is awaited, so an incoming call rings from the moment the user
/// is known. Only then does it wait for the Calls SDK (bounded; failures are
/// logged, never thrown). It is single-flight per user: a second start for
/// the same user joins the first, a start for another user stops the
/// previous one first.
///
/// A package-private chat SDK login listener keeps this right when a host
/// logs in or out with `CometChat.login`/`logout` directly instead of
/// through `CometChatUIKit`.
abstract final class CallsLifecycle {
  /// The id [CallEventService] is registered under with the chat SDK and
  /// with `CometChatCallEvents`.
  static const String callListenerId = 'CallEventService';

  static const String _loginListenerId = 'CometChatUIKit.CallsLifecycle';

  /// How long a logout waits for the server side of this device's calls to
  /// be cleaned up (see [prepareForLogout]) before it logs out anyway.
  static const Duration logoutCleanupTimeout = Duration(seconds: 3);

  static String? _uid;
  static bool _listenersRegistered = false;
  static int _generation = 0;
  static int _callEpoch = 0;
  static int _logoutCleanups = 0;
  static Future<void>? _running;
  static String? _cachedAuthToken;
  static final _OutOfBandLoginListener _loginListener =
      _OutOfBandLoginListener();

  /// Registers a chat SDK call listener. A seam: the chat SDK does not expose
  /// its listener map.
  @visibleForTesting
  static void Function(String listenerId, CallListener listener)
  addChatCallListener = CometChat.addCallListener;

  /// Removes a chat SDK call listener. See [addChatCallListener].
  @visibleForTesting
  static void Function(String listenerId) removeChatCallListener =
      CometChat.removeCallListener;

  /// The user the call listeners are registered for, or null when stopped.
  static String? get uid => _uid;

  /// Whether the call listeners are registered for a user.
  static bool get isStarted => _uid != null;

  /// The chat auth token of the started user. Read as soon as call handling
  /// starts (the chat login is already done by then) and again once the
  /// Calls SDK is set up. Cleared by [stop].
  static String? get cachedAuthToken => _cachedAuthToken;

  /// Changes whenever this device's calls are torn down: a logout starting
  /// ([prepareForLogout]), the local teardown ([tearDownLocalCalls]) or call
  /// handling stopping ([stop]). A call component that started something
  /// before (an accept, a call being placed) compares it afterwards, and
  /// lands without effect when it changed: no screen is shown, and a call it
  /// placed or answered meanwhile is cancelled or ended again.
  static int get callEpoch => _callEpoch;

  /// Whether a logout (or a login as another user) is cleaning this
  /// device's calls up ([prepareForLogout]). The call components place and
  /// accept nothing meanwhile: the clean-up has already picked the calls it
  /// ends, and a new one would be closed locally with nothing sent.
  static bool get isPreparingLogout => _logoutCleanups > 0;

  /// The out-of-band login listener, for tests.
  @visibleForTesting
  static LoginListener get debugLoginListener => _loginListener;

  /// Starts call handling for [user]. The returned future completes once the
  /// Calls SDK is ready or has given up (bounded, see
  /// [CallsSdkSession.ensureReady]); it never throws.
  ///
  /// The listeners are registered before this returns.
  static Future<void> start(User user) {
    final uid = user.uid;
    final current = _uid;
    if (current != null && current != uid) {
      // A user switch. Local only: this runs after the new user's chat
      // login, so anything sent now would go out as the new user.
      // CometChatUIKit.login cleans the previous user's calls up on the
      // server before that login (prepareForLogout).
      ccLog('CallsLifecycle: user switch $current -> $uid');
      stop();
    }
    if (_uid != uid) {
      _uid = uid;
      _registerListeners();
    }
    return _running ?? _launch();
  }

  /// What `CometChatUIKit` waits for before it calls the host's `onSuccess`
  /// from `init`, `login` or `loginWithAuthToken`, as the Android UI Kit
  /// does. Null when `UIKitSettings.enableCalls` is off: then there is
  /// nothing to wait for and nothing is started.
  ///
  /// With [user] (a login, or a session `init` restored) this is [start]:
  /// the call listeners at once, then the Calls SDK init and login. Without
  /// one (`init` with nobody logged in) it is the Calls SDK init only.
  ///
  /// Completes within [CallsSdkTimeouts.overall] and never fails. A Calls
  /// failure or timeout is only logged: the host still hears of the chat
  /// success, and the next [CallsSdkSession.ensureReady] (a call, an
  /// answer, the call logs) runs the failed step once more.
  static Future<void>? readyForHost(User? user) {
    if (CometChatUIKit.authenticationSettings?.enableCalls != true) {
      return null;
    }
    void failed(Object e) =>
        ccLog('CallsLifecycle: Calls SDK set-up before onSuccess failed: $e');
    try {
      final session = CallsSdkSession.instance;
      // A Future<void> at run time too: timeout's onTimeout below returns
      // nothing, which a Future<bool> would reject.
      final Future<void> work = user != null
          ? start(user)
          : session.ensureInitialized().then<void>((_) {});
      return work
          .timeout(
            session.timeouts.overall,
            onTimeout: () => ccLog(
              'CallsLifecycle: onSuccess no longer waits for the Calls SDK '
              '(${session.timeouts.overall.inSeconds} s)',
            ),
          )
          .then<void>((_) {}, onError: failed);
    } catch (e) {
      failed(e);
      return Future<void>.value();
    }
  }

  /// Stops call handling: removes the listeners, takes the call screens
  /// down ([tearDownLocalCalls]), clears the call records, the host's
  /// calling configuration and the auth token, resets the call service
  /// locators and call state, and makes anything still in flight land
  /// without effect.
  ///
  /// Idempotent. Sends nothing to the server (see [prepareForLogout]) and
  /// does not log the Calls SDK out (see [shutdown]).
  static void stop() {
    _generation++;
    _callEpoch++;
    CallsSdkSession.instance.stop();
    CallingConfigurationResolver.clearHostConfiguration();
    final wasStarted = _uid != null || _listenersRegistered;
    _uid = null;
    _running = null;
    _cachedAuthToken = null;
    _unregisterListeners();
    // Whether or not anything was started: a host that shows the call
    // screens itself and calls CallEventService.dispose() expects them gone.
    tearDownLocalCalls();
    if (!wasStarted) return;

    // The locators hold datasources built for the previous user.
    unawaited(CallOperationsServiceLocator.instance.reset());
    unawaited(CallLogsServiceLocator.instance.reset());

    CallStateService.instance.setActiveCallValue(false);
    CallStateService.instance.setActiveIncomingValue(false);
    CallStateService.instance.setActiveOutgoingValue(false);

    ccLog('CallsLifecycle: stopped');
  }

  /// Ends this device's calls on the server while the user can still be
  /// heard, then takes them down locally. What `CometChatUIKit.logout`
  /// runs before the chat logout, and `CometChatUIKit.login` before logging
  /// another user in: once the chat session is gone (or belongs to someone
  /// else) nothing can be sent as this user any more.
  ///
  /// Best effort and bounded by [logoutCleanupTimeout] altogether: an
  /// incoming call still ringing is declined (`rejected`), a call this
  /// device placed that is still ringing is cancelled (`cancelled`), a
  /// 1-on-1 call in progress is ended (`endCall`). A group meeting is only
  /// left (locally). Failures are logged; they never stop the logout. Then
  /// [tearDownLocalCalls]. The call listeners stay registered: if the chat
  /// logout fails, the user is still logged in and must still get calls.
  ///
  /// A call being placed or accepted when it starts is waited for too
  /// (within the same bound): it lands without effect, cancelling or ending
  /// its own call, and the call being accepted is not declined as well.
  /// Nothing new is placed or accepted until it is done
  /// ([isPreparingLogout]).
  static Future<void> prepareForLogout() async {
    _callEpoch++;
    _logoutCleanups++;
    try {
      final cleanup = _serverCleanup();
      if (cleanup.isNotEmpty) {
        try {
          await Future.wait(cleanup).timeout(logoutCleanupTimeout);
        } on TimeoutException {
          ccLog(
            'CallsLifecycle: call clean-up still running after '
            '${logoutCleanupTimeout.inSeconds} s; logging out anyway',
          );
        } catch (e) {
          ccLog('CallsLifecycle: call clean-up failed: $e');
        }
      }
      tearDownLocalCalls();
    } finally {
      _logoutCleanups--;
    }
  }

  /// Takes this device's calls down locally: closes the outgoing call
  /// screens, the incoming call banner and the call screen, leaves the media
  /// session when there is one (and stops the Android ongoing-call service),
  /// and clears the call records. Sends nothing to the server.
  ///
  /// The call screen is dismissed here, not left to its session's "left"
  /// callback: the iOS plugin drops its listeners before leaving, so on
  /// iOS that callback never came and a dead call screen stayed above the
  /// login screen.
  static void tearDownLocalCalls() {
    // Anything placed or accepted during a logout's server clean-up missed
    // it; this makes it land without effect too.
    _callEpoch++;
    ActiveCallTracker.closeOutgoingScreens();
    IncomingCallOverlay.dismiss();
    final hadCallScreen = CallScreenOverlay.isShowing;
    CallScreenOverlay.dismiss();
    // Only when there is a session to leave: a call screen was up, or a join
    // was asked for and not left since. Asking the plugin cannot tell (its
    // CallSession always exists), and an app that never made a call has no
    // media session or ongoing-call service to stop; on iOS the leave also
    // ends the CallKit call.
    if (hadCallScreen || ActiveCallTracker.mayHaveMediaSession) {
      _leaveMediaSession();
    }
    CallEventService.instance.activeCall = null;
    ActiveCallTracker.ringingCall = null;
    ActiveCallTracker.forgetFinishedCalls();
    ActiveCallTracker.takeLeftBeforeJoin();
    // Its own leave covers a session given up before its native join.
    GhostJoinGuard.disarm();
    // Whoever rings: a host's own incoming call bloc is not closed by the
    // banner's dismiss, and an accept cut short by the teardown kept the
    // ringtone (paused) as its own. Either way message sounds stayed held
    // back after the logout, and a host's ringing went on.
    if (IncomingRingtone.isRinging) unawaited(IncomingRingtone.stopAll());
  }

  static void _leaveMediaSession() {
    ActiveCallTracker.mayHaveMediaSession = false;
    try {
      unawaited(CometChatOngoingCallService.abort());
      final leave = CallSession.getInstance()?.leaveSession();
      if (leave != null) {
        // Fails when no session is up; that is fine, but it must not surface
        // as an unhandled error.
        unawaited(
          leave.catchError((Object e) {
            ccLog('CallsLifecycle: leaving the call session failed: $e');
          }),
        );
      }
    } catch (e) {
      ccLog('CallsLifecycle: leaving the call session failed: $e');
    }
  }

  /// The server side of [prepareForLogout], one request per call.
  static List<Future<void>> _serverCleanup() {
    final requests = <Future<void>>[];
    final handled = <String>{};
    bool claim(String? sessionId) =>
        sessionId != null && sessionId.isNotEmpty && handled.add(sessionId);

    // Placed or accepted, but not answered yet: each deals with its own call
    // once it lands (the epoch has changed), so the clean-up waits for it,
    // and does not also decline the call being accepted.
    for (final MapEntry(key: landed, value: accepting)
        in ActiveCallTracker.callRequestsInFlight.entries) {
      claim(accepting);
      requests.add(landed);
    }

    final ringing = ActiveCallTracker.ringingCall?.sessionId;
    if (claim(ringing)) {
      requests.add(_reject(ringing!, CallStatusConstants.rejected));
    }
    for (final call in ActiveCallTracker.ringingOutgoingCalls) {
      final sessionId = call.sessionId;
      if (claim(sessionId)) {
        requests.add(_reject(sessionId!, CallStatusConstants.cancelled));
      }
    }
    if (ActiveCallTracker.callScreenWorkFlow == CallWorkFlow.defaultCalling) {
      final onScreen = ActiveCallTracker.callScreenSessionId;
      if (claim(onScreen)) requests.add(_end(onScreen!));
    }
    final active = CallEventService.instance.activeCall;
    if (active is Call && claim(active.sessionId)) {
      // A call this device placed that nobody answered yet is cancelled; one
      // that was answered is ended.
      requests.add(
        active.callStatus == CallStatusConstants.initiated
            ? _reject(active.sessionId!, CallStatusConstants.cancelled)
            : _end(active.sessionId!),
      );
    }
    return requests;
  }

  static Future<void> _reject(String sessionId, String status) async {
    try {
      final result = await CallOperationsServiceLocator
          .instance
          .rejectCallUseCase
          .call(sessionId, status);
      result.fold(
        (failure) => ccLog(
          'CallsLifecycle: $status of $sessionId at logout failed: '
          '${failure.message}',
        ),
        (call) {
          call.category = MessageCategoryConstants.call;
          CometChatCallEvents.ccCallRejected(call);
        },
      );
    } catch (e) {
      ccLog('CallsLifecycle: $status of $sessionId at logout failed: $e');
    }
  }

  static Future<void> _end(String sessionId) async {
    try {
      final result = await CallOperationsServiceLocator.instance.endCallUseCase
          .call(sessionId);
      result.fold(
        (failure) => ccLog(
          'CallsLifecycle: ending $sessionId at logout failed: '
          '${failure.message}',
        ),
        (call) {
          call.category = MessageCategoryConstants.call;
          CometChatCallEvents.ccCallEnded(call);
        },
      );
    } catch (e) {
      ccLog('CallsLifecycle: ending $sessionId at logout failed: $e');
    }
  }

  /// [call] was placed while this device's calls were being torn down: its
  /// placement started before [callEpoch] changed and landed after. No
  /// screen is shown for it and it was never recorded, so it is cancelled
  /// here, so the callee stops ringing. A logout waits for this (within its
  /// bound, see [ActiveCallTracker.trackCallRequest]), so the cancel goes
  /// out while the user can still be heard.
  ///
  /// Best effort: a failure is logged, not reported (the calls were torn
  /// down, which is why). Nothing is sent when another user has logged in
  /// meanwhile ([placedBy] is who placed it): it would go out as them.
  static Future<void> cancelPlacedDuringTeardown(
    Call call, {
    required String? placedBy,
  }) async {
    final sessionId = call.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    final now = _uid;
    if (now != null && now != placedBy) {
      ccLog('CallsLifecycle: $now is logged in now; not cancelling $sessionId');
      return;
    }
    ccLog(
      'CallsLifecycle: $sessionId was placed during a teardown; cancelling',
    );
    try {
      final result = await CallOperationsServiceLocator
          .instance
          .rejectCallUseCase
          .call(sessionId, CallStatusConstants.cancelled);
      result.fold(
        (failure) => ccLog(
          'CallsLifecycle: cancelling $sessionId failed: ${failure.message}',
        ),
        (_) {},
      );
    } catch (e) {
      ccLog('CallsLifecycle: cancelling $sessionId failed: $e');
    }
  }

  /// [stop], then logs the Calls SDK out (bounded, shared with any logout
  /// already in flight) when the UI Kit had set it up.
  static Future<void> shutdown() {
    final session = CallsSdkSession.instance;
    final hadCalls = isStarted || session.initPhase != CallsSdkPhase.idle;
    stop();
    return hadCalls ? session.logout() : Future<void>.value();
  }

  /// Registers the out-of-band login listener with the chat SDK. Idempotent.
  static void attachLoginListener() {
    CometChat.addloginListener(_loginListenerId, _loginListener);
  }

  /// Puts everything back as it was at startup, for tests.
  @visibleForTesting
  static void debugReset() {
    stop();
    _logoutCleanups = 0;
    CometChat.removeLoginListener(_loginListenerId);
    addChatCallListener = CometChat.addCallListener;
    removeChatCallListener = CometChat.removeCallListener;
  }

  // ---------------------------------------------------------------------------

  static Future<void> _launch() {
    final gen = _generation;
    late final Future<void> run;
    run = _run(gen).whenComplete(() {
      if (identical(_running, run)) _running = null;
    });
    _running = run;
    return run;
  }

  static Future<void> _run(int gen) async {
    try {
      final session = CallsSdkSession.instance;
      // Alongside the Calls SDK set-up, not after it: that can take up to
      // CallsSdkTimeouts.overall.
      unawaited(_readAuthToken(session, gen));
      final ready = await session.ensureReady();
      if (gen != _generation) return;
      // Again: right after a login the token can take a moment to appear.
      await _readAuthToken(session, gen);
      if (gen != _generation) return;
      ccLog('CallsLifecycle: started for $_uid (Calls SDK ready: $ready)');
    } catch (e) {
      ccLog('CallsLifecycle: start failed: $e');
    }
  }

  static Future<void> _readAuthToken(CallsSdkSession session, int gen) async {
    try {
      final token = await session.gateway.chatAuthToken();
      if (gen != _generation) return;
      if (token != null && token.isNotEmpty) _cachedAuthToken = token;
    } catch (e) {
      ccLog('CallsLifecycle: reading the chat auth token failed: $e');
    }
  }

  static void _registerListeners() {
    final service = CallEventService.instance;
    addChatCallListener(callListenerId, service);
    // First in line, so the call records are updated before any screen
    // hears the event (dispatch is synchronous and in registration order).
    final others = Map<String, CometChatCallEventListener>.of(
      CometChatCallEvents.callEventsListener,
    )..remove(callListenerId);
    CometChatCallEvents.callEventsListener
      ..clear()
      ..[callListenerId] = service
      ..addAll(others);
    _listenersRegistered = true;
  }

  static void _unregisterListeners() {
    removeChatCallListener(callListenerId);
    CometChatCallEvents.removeCallEventsListener(callListenerId);
    _listenersRegistered = false;
  }
}

/// Follows a host's direct `CometChat.login`/`logout`, which bypass
/// `CometChatUIKit`: a login starts call handling for that user, a logout
/// stops it and logs the Calls SDK out, and clears
/// `CometChatUIKit.loggedInUser`. When the login or logout came through
/// `CometChatUIKit`, the single-flight start and the shared logout make this
/// a no-op.
final class _OutOfBandLoginListener with LoginListener {
  bool get _callsEnabled =>
      CometChatUIKit.authenticationSettings?.enableCalls == true;

  // Both callbacks run inside the chat SDK's own login/logout, before its
  // onSuccess and inside its try block: anything thrown here would turn a
  // successful chat login or logout into loginFailure/onError. So nothing
  // may escape.

  @override
  void loginSuccess(User user) {
    try {
      if (!_callsEnabled) return;
      unawaited(CallsLifecycle.start(user));
    } catch (e, stackTrace) {
      ccLog(
        'CallsLifecycle: starting call handling on login failed: '
        '$e\n$stackTrace',
      );
    }
  }

  @override
  void logoutSuccess() {
    try {
      // Nobody is logged in any more. CometChatUIKit.logout clears this in
      // its own onSuccess; a direct CometChat.logout would leave it stale.
      CometChatUIKit.loggedInUser = null;
      if (!_callsEnabled && !CallsLifecycle.isStarted) return;
      unawaited(CallsLifecycle.shutdown());
    } catch (e, stackTrace) {
      ccLog(
        'CallsLifecycle: stopping call handling on logout failed: '
        '$e\n$stackTrace',
      );
    }
  }
}
