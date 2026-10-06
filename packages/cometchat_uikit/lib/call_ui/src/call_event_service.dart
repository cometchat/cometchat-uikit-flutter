import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../cometchat_calls_uikit.dart';
import '../../cometchat_chat_uikit.dart';
import '../../shared_ui/src/logging/cometchat_log.dart';
import '../../src/active_call_tracker.dart';
import '../../src/busy_reject.dart';
import '../../src/call_errors.dart';
import '../../src/calling_configuration_resolver.dart';
import '../../src/calls_lifecycle.dart';
import '../../src/calls_sdk_session.dart';

/// Singleton service that manages global call SDK event listeners
/// with proper lifecycle (init/dispose).
///
/// Centralizes all call-related SDK listener handling:
/// - Incoming call received → shows [IncomingCallOverlay]
/// - Outgoing call accepted/rejected → navigates or cleans up
/// - Call ended → clears active call state
/// - Updates [CallStateService] for global call state tracking
///
/// With `UIKitSettings.enableCalls`, the UI Kit starts this itself at login
/// (including a session restored by `CometChatUIKit.init`) and stops it at
/// logout, and it follows a direct `CometChat.login`/`logout` too. It also
/// initialises the Calls SDK and logs the user into it, within a time limit.
/// Configure the call UI through `UIKitSettings.callingConfiguration`.
///
/// [init] and [dispose] remain for apps that manage calls themselves. Both
/// are safe to call more than once:
/// ```dart
/// // After login, when UIKitSettings.enableCalls is off.
/// await CallEventService.instance.init();
///
/// // To wait for the Calls SDK before a call, e.g. from a push handler.
/// await CallEventService.instance.waitForCallsSdk();
/// ```
class CallEventService with CallListener, CometChatCallEventListener {
  CallEventService._();

  /// The service.
  static final CallEventService instance = CallEventService._();

  /// The call this device placed or answered, until it is over.
  ///
  /// Android keeps this in the chat SDK (`CometChat.getActiveCall()`): set
  /// when initiateCall or acceptCall succeeds, refreshed by an "ongoing"
  /// event for the same session, cleared when that session is rejected,
  /// cancelled, unanswered or ended. The Dart SDK's `getActiveCall` /
  /// `clearActiveCall` are HTTP calls to an endpoint the server does not
  /// have, so the UI Kit keeps the record itself.
  BaseMessage? activeCall;

  /// Whether a new incoming call should be answered with busy. The ringing
  /// call, the busy check and the release live in [ActiveCallTracker], which
  /// the other call components read too.
  bool get _isBusy => ActiveCallTracker.isBusy;

  /// Starts call handling for the logged-in user: registers the call
  /// listeners (at once), then initialises the Calls SDK and logs the user
  /// into it (bounded; a failure is logged, never thrown, and retried once
  /// at the next [waitForCallsSdk]).
  ///
  /// Safe to call repeatedly and concurrently: calls for the same user share
  /// one start. A call for a different user than the one started stops the
  /// previous one first. Returns without doing anything when no user is
  /// logged in.
  ///
  /// [configuration] is used only when `UIKitSettings.callingConfiguration`
  /// is not set, and only the first non-null one passed after login counts:
  /// a later call no longer replaces it. It then applies to the incoming
  /// call banner, the message header's call buttons and the meeting bubble.
  Future<void> init({
    @Deprecated(
      'Set UIKitSettings.callingConfiguration instead. It wins over this '
      'parameter, which is only read when UIKitSettings has none. '
      'Will be removed in 7.0.0.',
    )
    CallingConfiguration? configuration,
  }) async {
    final user = await _loggedInUser();
    if (user == null) {
      CallingConfigurationResolver.offerHostConfiguration(configuration);
      ccLog(
        'CallEventService.init(): no logged-in user; call it after login. '
        'Nothing was started.',
      );
      return;
    }
    // start() stops the previous user synchronously on a user switch, and
    // that clears the host configuration: offer this one after it.
    final started = CallsLifecycle.start(user);
    CallingConfigurationResolver.offerHostConfiguration(configuration);
    await started;
  }

  /// The logged-in user as the chat SDK reports it. A host that logged in
  /// with `CometChat.login` directly never set `CometChatUIKit.loggedInUser`,
  /// and one that logged out that way may have left it stale, so that field
  /// is used only when the chat SDK cannot answer (it is not initialised).
  static Future<User?> _loggedInUser() async {
    var sdkFailed = false;
    final user = await CometChatUIKit.getLoggedInUser(
      onError: (_) => sdkFailed = true,
    );
    if (user != null) return user;
    return sdkFailed ? CometChatUIKit.loggedInUser : null;
  }

  /// Returns true if the Calls SDK has been initialized successfully.
  ///
  /// It does not mean the user is logged into the Calls SDK, which a call
  /// also needs: await [waitForCallsSdk] before starting or joining one.
  bool get isCallsSdkReady => CallsSdkSession.instance.isInitialized;

  /// Returns the cached user auth token, or null if not yet fetched.
  ///
  /// Set once call handling has started for the logged-in user, refreshed on
  /// a user switch, cleared on logout.
  String? get cachedAuthToken => CallsLifecycle.cachedAuthToken;

  /// Waits for the Calls SDK to be initialised and the logged-in user to be
  /// logged into it. Returns at once when it already is.
  ///
  /// Other components (e.g. CallLogsBloc, VoipCallHandler) should call this
  /// instead of initializing the SDK themselves.
  ///
  /// Bounded: it returns within 22 seconds whatever the Calls SDK does. When
  /// an earlier init or login failed, this runs it once more. Concurrent
  /// callers share one attempt. It never throws; the call screen checks
  /// readiness itself afterwards.
  ///
  /// When call handling has not been started (`UIKitSettings.enableCalls`
  /// is off and [init] was never called) but a user is logged in, this
  /// starts it first, as [init] would.
  Future<void> waitForCallsSdk() async {
    if (!CallsLifecycle.isStarted) {
      final user = await _loggedInUser();
      // Re-checked: a login may have started it while the user was read.
      if (user != null && !CallsLifecycle.isStarted) {
        ccLog('CallEventService: waitForCallsSdk starts call handling');
        await CallsLifecycle.start(user);
      }
    }
    final session = CallsSdkSession.instance;
    final ready = await session.ensureReady();
    if (!ready) {
      ccLog(
        'CallEventService: waitForCallsSdk finished but the Calls SDK is not '
        'ready (init=${session.initPhase}, login=${session.loginPhase})',
      );
    }
  }

  /// Remove all SDK listeners and reset state, then log the Calls SDK out.
  ///
  /// Takes this device's calls down locally first: the outgoing call
  /// screens, the incoming call banner and the call screen are closed, the
  /// media session is left and the call records are cleared. Nothing is sent
  /// to the server; `CometChatUIKit.logout` does that, while the user is
  /// still logged in, before it logs out.
  ///
  /// Also clears the calling configuration passed to [init], the service
  /// locators and [CallStateService]. Anything [init] still has in flight
  /// lands without effect, so a slow start can no longer register listeners
  /// for a user who has logged out. Safe to call more than once.
  void dispose() {
    unawaited(CallsLifecycle.shutdown());
    ccLog('CallEventService disposed');
  }

  /// Makes sure the Calls SDK is still initialised and logged in after a
  /// call session.
  ///
  /// It used to reset the Calls SDK state and initialise and log in again
  /// after every call, even after logout. Now it only repairs what is
  /// missing: it initialises again when the plugin reports it is not
  /// initialised, and logs in again when the Calls SDK holds no login (or
  /// another user's). A failed init or login is retried once. It does
  /// nothing once call handling has stopped (logged out).
  @Deprecated(
    'Not needed: the UI Kit keeps the Calls SDK initialised and logged in, '
    'and waitForCallsSdk() retries a failed init or login once. Use '
    'waitForCallsSdk() to wait for it. Will be removed in 7.0.0.',
  )
  Future<void> reinitializeAfterSession() async {
    if (!CallsLifecycle.isStarted) return;
    await CallsSdkSession.instance.ensureReady();
  }

  // ================================================================
  // SDK Call Events (CallListener)
  // ================================================================

  @override
  void onIncomingCallReceived(Call call) {
    User? user;
    if (call.callInitiator is User) {
      user = call.callInitiator as User;
    }

    // Ignore calls initiated by the logged-in user (echo). Read now, not at
    // start: the user may have switched since. The started user comes first
    // because a host's direct CometChat.login leaves
    // CometChatUIKit.loggedInUser unset or stale.
    final myUid = CallsLifecycle.uid ?? CometChatUIKit.loggedInUser?.uid;
    if (user != null && myUid != null && user.uid == myUid) {
      return;
    }

    // On iOS background, the VoIP push + CallKit handles the call.
    // The WebSocket listener should NOT interfere — setting activeCall
    // here can cause the server to auto-reject new calls with "busy"
    // if the app crashes or the call state isn't properly cleared.
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      ccLog(
        'CallEventService: skipping onIncomingCallReceived in background on iOS '
        '(VoIP push handles it) sessionId=${call.sessionId}',
      );
      return;
    }

    // Deduplicate: ignore a call this device is already handling. Duplicate
    // FCM pushes can trigger this listener twice for the same call, which
    // creates a second overlay/bloc and causes the reject API to fail with
    // "call is ended".
    //
    // "Already handling" is not just activeCall. A call accepted from the
    // native call UI (CallKit, or the Android call notification) is opened by
    // the host app straight onto the call screen and never sets activeCall; if
    // the SDK then delivers this callback for it as the app comes to the
    // foreground, the busy check below saw a call screen up and rejected the
    // very call the user had just accepted.
    if (_isHandlingSession(call.sessionId)) {
      ccLog(
        'CallEventService: ignoring duplicate onIncomingCallReceived '
        'for sessionId=${call.sessionId}',
      );
      return;
    }

    // A call this device has already finished with (declined, cancelled,
    // ended, given up on) in the last two minutes: a late copy of its
    // "initiated", after a socket reconnect or from a duplicate push. It
    // rang again, or was answered busy. Ignored as a duplicate is.
    if (ActiveCallTracker.finishedLately(call.sessionId)) {
      ccLog(
        'CallEventService: ignoring onIncomingCallReceived for '
        '${call.sessionId}, a call this device already finished',
      );
      return;
    }

    // Already in a call, or another one is ringing: answer this one with busy
    // instead of stacking a second incoming screen over the first. Kotlin's
    // app does exactly this (SampleApplication / master-app-kotlin
    // `rejectCallWithBusyStatus`). The records of the call in progress are
    // left untouched — the bounced call never becomes the ringing one.
    if (_isBusy) {
      ccLog(
        'CallEventService: busy — rejecting incoming ${call.sessionId}, '
        'already in a call',
      );
      unawaited(_rejectAsBusy(call));
      return;
    }

    ccLog(
      'CallEventService: onIncomingCallReceived sessionId=${call.sessionId}',
    );
    ActiveCallTracker.ringingCall = call;
    _showIncomingCallOverlay(call, user);
  }

  /// Whether [sessionId] is a call this device is already on: the active
  /// call, the call screen, or the incoming call ringing on screen.
  bool _isHandlingSession(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) return false;
    final active = activeCall;
    return (active is Call && active.sessionId == sessionId) ||
        ActiveCallTracker.ringingCall?.sessionId == sessionId ||
        ActiveCallTracker.callScreenSessionId == sessionId ||
        ActiveCallTracker.incomingCallSessionId == sessionId;
  }

  /// Rejects [call] with the busy status. Best-effort: if it fails the call
  /// simply rings out on the caller's side.
  Future<void> _rejectAsBusy(Call call) => rejectAsBusy(call);

  /// Attempts to show the incoming call overlay, retrying briefly if the
  /// navigator context isn't available yet.
  Future<void> _showIncomingCallOverlay(Call call, User? user) async {
    BuildContext? context;
    for (int i = 0; i < 10; i++) {
      context = CallNavigationContext.navigatorKey.currentContext;
      if (context != null && context.mounted) break;
      context = null;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // The call stopped ringing during the wait (cancelled, answered or
    // declined on another device, released): a banner now would ring for
    // a call that is over, until the timeout.
    if (ActiveCallTracker.ringingCall?.sessionId != call.sessionId) {
      ccLog(
        'CallEventService: ${call.sessionId} stopped ringing before its '
        'banner could be shown',
      );
      return;
    }

    ccLog(
      'CallEventService: showing overlay, context=${context != null}, overlay=${CallNavigationContext.navigatorKey.currentState?.overlay != null}',
    );

    if (context != null && context.mounted) {
      // Read at show time: UIKitSettings.callingConfiguration, or the host's
      // init(configuration:) when the settings have none.
      final config =
          CallingConfigurationResolver.resolved?.incomingCallConfiguration;
      IncomingCallOverlay.show(
        context: context,
        call: call,
        user: user,
        onError: config?.onError,
        disableSoundForCalls: config?.disableSoundForCalls,
        customSoundForCalls: config?.customSoundForCalls,
        customSoundForCallsPackage: config?.customSoundForCallsPackage,
        onAccept: config?.onAccept,
        onDecline: config?.onDecline,
        style: config?.incomingCallStyle,
        callSettingsBuilder: config?.callSettingsBuilder,
        height: config?.height,
        width: config?.width,
        declineButtonText: config?.declineButtonText,
        acceptButtonText: config?.acceptButtonText,
        titleView: config?.titleView,
        leadingView: config?.leadingView,
        trailingView: config?.trailingView,
        subtitleView: config?.subTitleView,
        itemView: config?.itemView,
      );
    } else {
      ccLog(
        'WARNING: CallNavigationContext.navigatorKey has no context. '
        'Did you set CallNavigationContext.navigatorKey = yourNavigatorKey '
        'in main()? Incoming call overlay cannot be shown.',
      );
      // Nothing can show this call, so it must not keep the device "busy":
      // every later incoming call was answered busy until this one's cancel
      // arrived. Only the ringing record; the call is not declined, so push
      // or CallKit can still ring for it.
      ActiveCallTracker.releaseRinging(call.sessionId);
      reportCallError(
        CallingConfigurationResolver
            .resolved
            ?.incomingCallConfiguration
            ?.onError,
        noNavigatorException('incoming call'),
        where: 'CallEventService',
      );
    }
  }

  /// "Ongoing" for a call — delivered to every listener, whichever side
  /// this device is on and whichever call it is about.
  ///
  /// Only refreshes the record of the same call, as the Android SDK does. It
  /// used to set the record from any "ongoing", so one arriving after the
  /// call screen had closed brought a finished call back as active — every
  /// later call refused, every incoming one answered with busy, until logout.
  /// The record is set where the call was placed or answered (ccOutgoingCall,
  /// ccCallAccepted).
  ///
  /// "Ongoing" for the call ringing here, while this device is not
  /// answering it, means the same user answered it on another device: it
  /// stops ringing here. The banner's bloc does this too; this covers a
  /// ringing record that has no bloc (no banner shown, or one a host shows
  /// elsewhere), which kept every later call answered busy.
  @override
  void onOutgoingCallAccepted(Call call) {
    final active = activeCall;
    final sid = call.sessionId;
    if (active is Call && sid != null && active.sessionId == sid) {
      activeCall = call;
    }
    _stopRingingHandledElsewhere(call);
  }

  /// "Rejected" or "busy". For the call ringing here, while this device is
  /// not declining it, the same user declined it on another device (or it
  /// was bounced busy there): the banner goes with the record, so the two
  /// cannot disagree.
  @override
  void onOutgoingCallRejected(Call call) {
    _clearActiveCall(call);
    _stopRingingHandledElsewhere(call);
  }

  /// The call ringing here was answered or declined on another device of
  /// this user ([call] is its "ongoing", "rejected" or "busy"): its banner
  /// closes and it stops counting as ringing. Not while this device is
  /// answering or declining it itself: that is its own echo.
  ///
  /// Only when the logged-in user is who acted: another member answering a
  /// group call sends "ongoing" to every member, and the call must ring on
  /// for the others.
  ///
  /// The call is remembered as finished (through the scoped dismiss), with
  /// or without a banner, so a late "initiated" for it does not ring here.
  /// The active call is not touched.
  void _stopRingingHandledElsewhere(Call call) {
    final sid = call.sessionId;
    if (sid == null || sid.isEmpty) return;
    if (!ActiveCallTracker.actedByLoggedInUser(call)) return;
    final ringingHere =
        ActiveCallTracker.ringingCall?.sessionId == sid ||
        ActiveCallTracker.incomingCallSessionId == sid;
    if (!ringingHere || ActiveCallTracker.isRespondingTo(sid)) return;
    ccLog('CallEventService: $sid was answered or declined on another device');
    IncomingCallOverlay.dismiss(sessionId: sid);
  }

  @override
  void onIncomingCallCancelled(Call call) {
    ccLog(
      'CallEventService: onIncomingCallCancelled sessionId=${call.sessionId}',
    );
    // Small delay to avoid race where cancel arrives before overlay is visible.
    // Scoped to this call's session: the SDK broadcasts cancels, and within
    // that 300ms a different call can already be ringing — an unscoped
    // dismiss took that one down instead.
    Future.delayed(const Duration(milliseconds: 300), () {
      IncomingCallOverlay.dismiss(sessionId: call.sessionId);
    });
    _clearActiveCall(call);
  }

  @override
  void onCallEndedMessageReceived(Call call) {
    ccLog(
      'CallEventService: onCallEndedMessageReceived sessionId=${call.sessionId}',
    );
    IncomingCallOverlay.dismiss(sessionId: call.sessionId);

    // Only the call this is about. The SDK broadcasts "call ended", and now
    // that a second incoming call is answered with busy, the end of that
    // bounced call arrives here while the user is still in their own call —
    // an unscoped teardown hung that one up.
    final onScreen = ActiveCallTracker.callScreenSessionId;
    if (onScreen != null &&
        call.sessionId != null &&
        call.sessionId!.isNotEmpty &&
        onScreen != call.sessionId) {
      _clearActiveCall(call);
      return;
    }

    // The remote party ended the call — tear down this device's call screen.
    //
    // Nothing else does it: OngoingCallBloc subscribes to no call events and
    // only closes the screen from locally-initiated end paths, and the v5
    // guard (onUserLeft -> endSession once <=1 participant remained) was
    // dropped during the Clean Architecture + BLoC migration. Without this the
    // surviving device sits on a dead call screen after the peer hangs up.
    unawaited(_tearDownOngoingCall(call.sessionId));
    _clearActiveCall(call);
  }

  /// Leaves the media session and closes the ongoing call screen of
  /// [sessionId], if one is up.
  ///
  /// Safe on the device that ended the call itself: the overlay is already
  /// gone, so this returns immediately.
  ///
  /// Only that call's screen is closed: a screen another call put up while
  /// the session was being left stays (round 4, P4-C07).
  ///
  /// Deliberately does NOT call `CometChat.endCall()` — the call is already
  /// ended server-side, and re-ending it just fails with
  /// "The call with sessionid ... is ended."
  Future<void> _tearDownOngoingCall(String? sessionId) async {
    if (!CallScreenOverlay.isShowing) return;
    try {
      // Aborts the Android ongoing-call foreground service and leaves the
      // WebRTC session, so audio actually stops rather than only the UI going
      // away.
      await CometChatUIKitCalls.endSession();
    } catch (e) {
      ccLog('CallEventService: endSession during remote teardown failed: $e');
    }
    final hasSession = sessionId != null && sessionId.isNotEmpty;
    CallScreenOverlay.dismiss(sessionId: hasSession ? sessionId : null);
  }

  // ================================================================
  // UIKit Call Events (CometChatCallEventListener)
  // ================================================================

  @override
  void ccOutgoingCall(Call call) {
    activeCall = call;
  }

  /// Answered here: the call stops ringing and becomes the active one.
  @override
  void ccCallAccepted(Call call) {
    if (ActiveCallTracker.ringingCall?.sessionId == call.sessionId) {
      ActiveCallTracker.ringingCall = null;
    }
    activeCall = call;
  }

  @override
  void ccCallRejected(Call call) {
    _clearActiveCall(call);
  }

  @override
  void ccCallEnded(Call call) {
    _clearActiveCall(call);
  }

  // ================================================================
  // Internal helpers
  // ================================================================

  /// Clears [activeCall] and [ActiveCallTracker.ringingCall] when [call] is
  /// the one they hold.
  ///
  /// Local only. This used to also call `CometChat.clearActiveCall()` on every
  /// reject/end, whichever call it was about; on the Dart SDK that is an HTTP
  /// DELETE to an endpoint the server does not have, so it did nothing but
  /// fail. Matching is by session id, as Kotlin does — a call's `id` can
  /// differ between the object an event carries and the one that was stored,
  /// which is what made the old id match miss and leave stale state behind.
  void _clearActiveCall(Call call) {
    final sid = call.sessionId;
    if (sid != null && sid.isNotEmpty) {
      ActiveCallTracker.release(sid);
      return;
    }
    if (call.id <= 0) return;
    if (activeCall?.id == call.id) activeCall = null;
    if (ActiveCallTracker.ringingCall?.id == call.id) {
      ActiveCallTracker.ringingCall = null;
    }
  }
}
