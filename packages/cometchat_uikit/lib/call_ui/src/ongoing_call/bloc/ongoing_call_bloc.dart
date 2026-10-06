import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../cometchat_calls_uikit.dart';
import '../../../../cometchat_chat_uikit.dart';
import '../../../../shared_ui/src/logging/cometchat_log.dart';
import '../../../../src/active_call_tracker.dart';
import '../../../../src/busy_reject.dart';
import '../../call_operations/data/datasources/start_session_deadline.dart';
import '../../../../src/call_audio_handover.dart';
import '../../../../src/call_errors.dart';
import '../../../../src/call_orientation.dart';
import '../../../../src/call_permission_check.dart';
import '../../../../src/calls_lifecycle.dart';
import '../../../../src/calls_sdk_session.dart';
import '../../../../src/ghost_join_guard.dart';

/// Session status listener for the ongoing call
class _OngoingCallSessionListener extends SessionStatusListeners {
  final OngoingCallBloc bloc;
  _OngoingCallSessionListener(this.bloc);

  @override
  void onSessionJoined() => bloc._addFromSdk(const _SessionJoined());

  @override
  void onSessionTimedOut() => bloc._addFromSdk(const SessionTimeout());

  @override
  void onSessionLeft() => bloc._addFromSdk(const OngoingCallEnded());

  @override
  void onConnectionClosed() => bloc._addFromSdk(const OngoingCallEnded());
}

/// Button click listener for the ongoing call
class _OngoingCallButtonListener extends ButtonClickListeners {
  final OngoingCallBloc bloc;
  _OngoingCallButtonListener(this.bloc);

  @override
  void onLeaveSessionButtonClicked() =>
      bloc._addFromSdk(const EndCallButtonPressed());
}

/// Participant event listener for the ongoing call
class _OngoingCallParticipantListener extends ParticipantEventListeners {
  final OngoingCallBloc bloc;
  _OngoingCallParticipantListener(this.bloc);

  @override
  void onParticipantListChanged(List<Participant> participants) {
    bloc._addFromSdk(ParticipantListChanged(participants));
  }

  @override
  void onParticipantJoined(Participant participant) {
    bloc._addFromSdk(_ParticipantJoined(participant));
  }

  @override
  void onParticipantLeft(Participant participant) {
    bloc._addFromSdk(ParticipantLeft(participant));
  }
}

/// BLoC for managing ongoing call screen state and actions
///
/// This BLoC handles:
/// - Session initialization (join session; the SDK generates the token)
/// - End call button press (leave session for direct calling; leave, then
///   end the call on the server otherwise)
/// - Session timeout handling
/// - Call ended handling (a 1-on-1 call ended elsewhere closes without
///   ending it again)
/// - Participant list tracking
/// - CallStateService updates on init and close
/// - Device orientation restoration in close()
///
/// Ending a 1-on-1 call (End, or back while it is still connecting) leaves
/// the media session first, closes the screen at once, and sends `endCall`
/// in the background; `ccCallEnded` goes out when the server confirms it,
/// whether or not the screen is still there. A second End tap is ignored.
/// When the other side ends the call at about the same time (its own End,
/// or its "peer left" rule as this side leaves), one of the two `endCall`s
/// fails because the call has already ended: that failure reaches
/// `onError`, and the side that lost gets no `ccCallEnded`.
///
/// A call screen that cannot join closes at once: the device is freed, the
/// media session left and the Android ongoing-call service stopped, and
/// `onError` gets the reason (`CALLS_NOT_READY`, `PERMISSION_DENIED`,
/// `PERMISSION_PERMANENTLY_DENIED`, `JOIN_TIMEOUT` or `JOIN_FAILED`). Nothing
/// is sent to the server. That includes a call view the Calls SDK never
/// reports joining within 30 s of appearing.
///
/// The screen owns the call on this device until a newer call screen is
/// shown. Only then does closing it touch what the app shares: the media
/// session, the call record, `CallStateService.isActiveCall` and the screen
/// orientation (round 4).
class OngoingCallBloc extends Bloc<OngoingCallEvent, OngoingCallState> {
  /// Session settings builder
  final SessionSettingsBuilder sessionSettingsBuilder;

  /// Session ID for the call
  final String sessionId;

  /// Error callback
  final OnError? errorCallback;

  /// Call workflow type (directCalling or defaultCalling)
  final CallWorkFlow? callWorkFlow;

  /// Internal list of participants in the call
  List<Participant> _participantsList = [];

  /// Set once the auto-teardown has fired, so a later participant update
  /// cannot queue a second end-call sequence.
  bool _peerLeftHandled = false;

  /// Whether the call screen has already been dismissed.
  ///
  /// _closeCallScreen() can be reached more than once per teardown. After
  /// the first dismissal CallScreenOverlay.isShowing is false, so a second
  /// run would fall through to the Navigator branch and pop whatever route
  /// is underneath the call screen.
  bool _callScreenClosed = false;

  /// Whether this bloc drives the screen [CallScreenOverlay] is showing, as
  /// it was when the bloc was built (the overlay builds the screen right
  /// after it records the session).
  ///
  /// Such a screen is closed by dismissing the overlay, and only while it
  /// still owns the call ([_isOwner]). Falling back to Navigator.pop would
  /// pop the host's own screen instead.
  final bool _shownInOverlay;

  /// [ActiveCallTracker.callScreenGeneration] when this bloc was built: its
  /// ownership token. See [_isOwner].
  final int _generation;

  /// Set once this call is on its way out from here: End (or back while
  /// connecting), a failed join, a timeout, the session left. A second End
  /// and the call's own "left" echoing back are ignored then.
  bool _teardownStarted = false;

  /// Whether the Calls SDK handed the call view back (the screen went
  /// active).
  bool _joined = false;

  /// Whether this bloc asked the Calls SDK to join.
  bool _joinStarted = false;

  /// Whether this bloc has asked the Calls SDK to leave the session.
  bool _sessionLeft = false;

  /// This bloc's leave of the session, once asked for: what giving the
  /// handed-over audio back waits for (see [_giveBackHandedOverAudio]).
  /// Never completes with an error.
  Future<void>? _leaving;

  /// Whether the audio the ringback or the ringtone handed to this call
  /// has been asked back: see [_giveBackHandedOverAudio].
  bool _audioGivenBack = false;

  /// Whether this bloc started the Android ongoing-call service and has not
  /// stopped it since: see [_stopOwnService].
  bool _serviceLaunched = false;

  /// Whether the service this bloc started is a video call's.
  bool _serviceIsVideo = false;

  /// The session the UI Kit left just before this call's join (a meeting
  /// left for this answered call, say), or null: until this call's own
  /// native join, a session end or a participant event is taken for that
  /// session's late echo. See [_isEchoOfLeftSession].
  String? _echoOf;

  /// Whether the native join was reported: `onSessionJoined`, a
  /// participant joining, or a participant list with anyone in it. Not a
  /// participant leaving, nor an empty list: a stale event of an earlier
  /// session can be one (round 4 review, native 7).
  bool _nativeJoined = false;

  /// Whether the join watchdog stopped counting while the app was not in
  /// the foreground: it starts again when the app comes back.
  bool _watchdogPaused = false;

  /// Tells this bloc when the app leaves or comes back to the foreground,
  /// while its join watchdog runs.
  _CallScreenLifecycle? _lifecycle;

  /// Whether a participant other than the logged-in user has been seen in
  /// the session: the peer-left rule is armed only then.
  bool _peerSeen = false;

  /// Whether this screen's hold on the app's shared state was given up:
  /// see [_releaseScreenEffects].
  bool _screenEffectsReleased = false;

  /// Fails the join if the native side never reports it: see
  /// [_armJoinWatchdog].
  Timer? _joinWatchdog;

  /// Time since the call view appeared, for the "session joined" log.
  final Stopwatch _sinceView = Stopwatch();

  /// What back does while this screen shows in [CallScreenOverlay]:
  /// registered as [ActiveCallTracker.callScreenBack].
  late final void Function() _backHandler = _onBack;

  /// Internal listeners for V5 SDK callbacks
  late final _OngoingCallSessionListener _sessionListener;
  late final _OngoingCallButtonListener _buttonListener;
  late final _OngoingCallParticipantListener _participantListener;

  /// Creates an OngoingCallBloc
  OngoingCallBloc({
    required this.sessionSettingsBuilder,
    required this.sessionId,
    this.errorCallback,
    this.callWorkFlow,
  }) : _shownInOverlay =
           CallScreenOverlay.isShowing &&
           ActiveCallTracker.callScreenSessionId == sessionId,
       _generation = ActiveCallTracker.callScreenGeneration,
       super(const OngoingCallState()) {
    // Create listeners
    _sessionListener = _OngoingCallSessionListener(this);
    _buttonListener = _OngoingCallButtonListener(this);
    _participantListener = _OngoingCallParticipantListener(this);

    // Register event handlers
    on<LoadCallingScreen>(_onLoadCallingScreen);
    on<EndCallButtonPressed>(_onEndCallButtonPressed);
    on<SessionTimeout>(_onSessionTimeout);
    on<OngoingCallEnded>(_onCallEnded);
    on<ParticipantListChanged>(_onParticipantListChanged);
    on<ParticipantLeft>(_onParticipantLeft);
    on<_ParticipantJoined>(_onParticipantJoined);
    on<_SessionJoined>(_onSessionJoined);
    on<_NativeJoinTimedOut>(_onNativeJoinTimedOut);
    on<_EndCallSettled>(_onEndCallSettled);

    if (_shownInOverlay) ActiveCallTracker.callScreenBack = _backHandler;
    // The standalone CometChatOngoingCall asks for the same rule.
    ActiveCallTracker.setBackHandlerOf(this, _backHandler);

    // Initialize
    _initialize();
  }

  /// Initialize the BLoC
  void _initialize() {
    // Portrait during the call; given back by the owner's close.
    unawaited(CallOrientation.hold(released: () => _screenEffectsReleased));

    // Update CallStateService to track active call
    CallStateService.instance.setActiveCallValue(true);

    // Load the calling screen
    add(const LoadCallingScreen());
  }

  /// Whether this screen still owns the call on this device: no newer call
  /// screen has been shown since it was built
  /// ([ActiveCallTracker.callScreenGeneration]).
  ///
  /// A screen replaced by a newer one (for another call, or the same call
  /// shown again) is closed a frame after the newer screen was built. Its
  /// clean-up used to run under the new call: CallStateService said no
  /// call, the orientation was unlocked, and a leave would have left the
  /// new call's session (the Calls SDK has one for the app).
  bool get _isOwner => ActiveCallTracker.callScreenGeneration == _generation;

  /// Whether this screen gives up what the app shares when it closes: it
  /// owns the call, or no call screen is up any more.
  ///
  /// The second half is for a newer screen that was taken down before it
  /// was ever built (a VoIP accept in the background whose caller hung up,
  /// a logout right after an accept, a remote end within a frame): it never
  /// ran, and the screen it replaced, no longer the owner, kept
  /// CallStateService on, the orientation held and its session joined
  /// (round 4 review, probe C).
  bool get _actsForApp => _isOwner || !CallScreenOverlay.isShowing;

  /// Whether this overlay screen was taken down from outside while this bloc
  /// still owns the call (its call ended elsewhere), before the frame that
  /// closes the bloc: an app in the background draws none.
  bool get _screenTakenDown =>
      _shownInOverlay &&
      _isOwner &&
      (!CallScreenOverlay.isShowing ||
          ActiveCallTracker.callScreenSessionId != sessionId);

  /// Whether the join on its way no longer matters: the screen is closing or
  /// closed, or a newer call screen owns the call.
  bool get _abandoned =>
      isClosed || _teardownStarted || _callScreenClosed || !_isOwner;

  /// Adds [event] from a Calls SDK callback, unless the bloc is closed: a
  /// native event can still be on its way when the listeners are removed.
  void _addFromSdk(OngoingCallEvent event) {
    if (!isClosed) add(event);
  }

  /// Hands a Calls SDK error to the host's onError as a
  /// [CometChatException], its code, message and details each in their own
  /// slot (it used to put the message in `details` and the details in
  /// `message`). When the SDK gives neither, the message is
  /// "Call error occurred".
  void handleCallsError(CometChatCallsException ce) {
    final error = callsSdkException(ce);
    _handleError(
      error.message == null
          ? CometChatException(
              error.code,
              'Call error occurred',
              'Call error occurred',
            )
          : error,
    );
  }

  /// Infer whether a call session is audio-only.
  ///
  /// The codebase uses two equivalent conventions:
  /// 1. `SessionType.audio` (native AUDIO value), what the UI Kit's own
  ///    voice calls use.
  /// 2. `SessionType.video` combined with `startVideoPaused=true` +
  ///    `hideToggleVideoButton=true`, what older UI Kit versions and host
  ///    settings use for a voice call.
  ///
  /// Both are treated as audio-only here so we don't ask for the camera
  /// runtime permission on calls that never use the camera.
  static bool _isAudioOnlySession(SessionSettings s) {
    if (s.type == SessionType.audio) return true;
    if (s.startVideoPaused && s.hideToggleVideoButton) return true;
    return false;
  }

  // ============================================================
  // EVENT HANDLERS
  // ============================================================

  /// Handle load calling screen event.
  ///
  /// Uses the V5 sessionId-based joinSession API. The SDK generates the
  /// call token internally — no separate generateCallToken step needed.
  Future<void> _onLoadCallingScreen(
    LoadCallingScreen event,
    Emitter<OngoingCallState> emit,
  ) async {
    try {
      await _join(emit);
    } catch (e, stackTrace) {
      // Whatever the join threw that nothing on the way caught (a host's
      // settings builder, a data source of the host's): a failed join. It
      // used to escape the handler and leave "Connecting..." up for good,
      // with no watchdog (round 4 review, correctness 14).
      ccLog('OngoingCallBloc: joining $sessionId threw: $e\n$stackTrace');
      if (_abandoned || emit.isDone) return;
      const message = 'Could not join the call.';
      _failJoin(
        emit,
        CometChatException(
          CallErrorCodes.joinFailed,
          'Joining the call failed: $e',
          message,
        ),
        message,
      );
    }
  }

  /// The join itself: see [_onLoadCallingScreen].
  Future<void> _join(Emitter<OngoingCallState> emit) async {
    emit(state.copyWith(status: OngoingCallStatus.loading));

    // Ensure the Calls SDK is fully initialized and logged in.
    await CallOperationsServiceLocator.instance.repository.waitForCallsSdk();
    if (_abandoned) return;

    // Guard: if the SDK still isn't ready after waiting, fail with a clear
    // message instead of letting the native SDK throw a cryptic error.
    // Ready means initialised AND logged in: without the Calls login the
    // join fails with "User auth token is null".
    if (!CallsSdkSession.instance.isReady) {
      ccLog(
        'OngoingCallBloc: Calls SDK not ready after waitForCallsSdk — cannot start session',
      );
      const message = 'Call service is not ready. Please try again.';
      _failJoin(
        emit,
        CometChatException(
          CallErrorCodes.callsNotReady,
          'The Calls SDK is not initialised or not logged in.',
          message,
        ),
        message,
      );
      return;
    }

    // Android 14+ (targetSdk 34+) blocks starting the OngoingCallService
    // foreground service with SecurityException if RECORD_AUDIO / CAMERA
    // are not granted at runtime. The calls plugin's OngoingCallService
    // declares FGS types `mediaPlayback|microphone|camera` and the OS
    // validates each required runtime permission when startForeground()
    // is called. Path-level checks elsewhere (OutgoingCallBloc,
    // IncomingCallBloc, VoipCallHandler) can be bypassed by cold-boot
    // VOIP accepts (pendingCallNavigation jumps straight here). Do the
    // final check here so no path reaches startSession without mic+camera.
    final SessionSettings sessionSettings = sessionSettingsBuilder.build();
    final bool isAudioOnly = _isAudioOnlySession(sessionSettings);
    final CallPermissionOutcome permissions;
    try {
      permissions = await CallPermissionCheck.request(
        isVideoCall: !isAudioOnly,
      );
    } catch (e, stackTrace) {
      // The permission plugin refusing (a request already running, say).
      ccLog('OngoingCallBloc: asking for permissions failed: $e\n$stackTrace');
      if (_abandoned) return;
      final error = callExceptionFrom(e);
      _failJoin(emit, error, error.message ?? '$e');
      return;
    }
    if (_abandoned) return;
    if (!permissions.isGranted) {
      ccLog(
        'OngoingCallBloc: permissions denied (audioOnly=$isAudioOnly), aborting session',
      );
      final message =
          'Microphone${isAudioOnly ? '' : ' and camera'} permission is required to join the call.';
      _failJoin(emit, permissions.toException(message), message);
      return;
    }

    // A session lately given up before its native join: on iOS its view
    // may have joined since with nobody to leave it, which blocks this join
    // ("Session already started"). It is left once more first.
    await GhostJoinGuard.beforeJoin();
    if (_abandoned) return;

    ccLog('OngoingCallBloc: Joining session $sessionId');
    _echoOf = ActiveCallTracker.takeLeftBeforeJoin();

    // Join session directly with sessionId — SDK handles token internally
    final startSessionUseCase =
        CallOperationsServiceLocator.instance.startSessionUseCase;
    _joinStarted = true;
    final sessionResult = await startSessionUseCase.call(
      sessionId,
      sessionSettings,
    );

    if (_abandoned) {
      _joinLandedTooLate(sessionResult);
      return;
    }

    sessionResult.fold(
      (failure) => _failJoin(emit, _joinFailure(failure), failure.message),
      (screen) {
        _joined = true;

        // The user's own call is up (a call screen a host shows itself, not
        // through CallScreenOverlay): an incoming call still ringing under
        // it is answered busy.
        rejectRingingAsBusy(sessionId: sessionId);

        // Register listeners AFTER session starts successfully
        final session = CallSession.getInstance();
        session?.addSessionStatusListener(_sessionListener);
        session?.addButtonClickListener(_buttonListener);
        session?.addParticipantEventListener(_participantListener);

        // The Android ongoing-call service ("Call in progress"), started
        // here now that this screen is known to still be the one on show,
        // with the call's type (a voice call asks for the microphone only).
        // Before the call view mounts, as it was when the Calls SDK's
        // success started it: the native join comes after. This bloc stops
        // it again when it leaves ([_stopOwnService]).
        _serviceLaunched = true;
        _serviceIsVideo = !isAudioOnly;
        unawaited(CometChatOngoingCallService.launch(isVideo: !isAudioOnly));

        emit(
          state.copyWith(
            status: OngoingCallStatus.active,
            callingWidget: screen,
          ),
        );
        _armJoinWatchdog();
      },
    );
  }

  /// The join came back after this screen stopped waiting for it: it
  /// closed, its call was ended or cancelled from here, or a newer call
  /// screen took over.
  ///
  /// Nothing was started for it: the call view is never shown, so the
  /// native side never joins, and the Android ongoing-call service starts
  /// only for a screen still on show (it used to start on every successful
  /// join, and stopping it again stopped the service of whatever call was
  /// on by then). A screen that still owns the call (none newer) takes back
  /// the "maybe in a session" mark the join set: it used to stay, and every
  /// incoming call rang as if over a call until a logout.
  void _joinLandedTooLate(Result<Widget> result) {
    ccLog(
      'OngoingCallBloc: the join of $sessionId came back '
      '(${result is Success<Widget> ? 'joined' : 'failed'}) after its '
      'screen stopped waiting; nothing was started for it',
    );
    if (_isOwner && !_joined) ActiveCallTracker.mayHaveMediaSession = false;
  }

  /// The call screen could not join: frees the device, closes the screen,
  /// gives the audio back and tells the host why.
  ///
  /// Every way a join fails ends here — the Calls SDK not ready, the
  /// permissions refused, the SDK refusing the join or not answering it in
  /// time, the call view never reporting the join. Each used to only show
  /// an error, so the record stayed: the call buttons refused every later
  /// call with ACTIVE_CALL and every incoming call was answered busy, until
  /// an event for this session or a logout. onError never fired.
  ///
  /// The screen closes at once (the owner's choice; there is no error
  /// screen), before onError, so a host that tries again from there is not
  /// refused and finds no call screen up. The media session is left (which
  /// also stops the Android ongoing-call service) when one may be up, and
  /// once that is done the audio the ringback or the ringtone handed to the
  /// call is given back ([_giveBackHandedOverAudio]).
  ///
  /// Nothing is sent to the server, as on Android: no endCall, no reject.
  void _failJoin(
    Emitter<OngoingCallState> emit,
    CometChatException error,
    String screenMessage,
  ) {
    _teardownStarted = true;
    _stopJoinWatchdog();
    // Only a session this screen asked for: the mark can be another
    // screen's or the host's (round 4 review, native 9).
    if (_isOwner &&
        (_joined || (_joinStarted && ActiveCallTracker.mayHaveMediaSession))) {
      unawaited(_leaveSession());
    }
    // Gives the handed-over audio back once the leave is done.
    _closeCallScreen();
    _handleError(error);
    emit(
      state.copyWith(
        status: OngoingCallStatus.error,
        errorMessage: screenMessage,
        errorCode: error.code,
      ),
    );
  }

  /// How long the end of a call waits for the media session to be left
  /// before it carries on (the server's endCall, the audio given back).
  static const Duration _leaveWaitLimit = Duration(seconds: 2);

  /// [failure] of the join as onError reports it: JOIN_TIMEOUT when the
  /// Calls SDK did not answer in time, otherwise JOIN_FAILED carrying the
  /// SDK's own code, message and details in `errorParams`.
  static CometChatException _joinFailure(Failure failure) {
    if (failure.code == kStartSessionTimeoutCode) {
      return CometChatException(
        CallErrorCodes.joinTimeout,
        'The Calls SDK did not answer the join within '
        '${kStartSessionTimeout.inSeconds} s.',
        failure.message,
      );
    }
    final original = failure.exception;
    final String? sdkCode;
    final String? sdkMessage;
    final String? sdkDetails;
    if (original is CometChatCallsException) {
      sdkCode = original.code;
      sdkMessage = original.message;
      sdkDetails = original.details;
    } else if (original is CometChatException) {
      sdkCode = original.code;
      sdkMessage = original.message;
      sdkDetails = original.details;
    } else {
      sdkCode = failure.code;
      sdkMessage = failure.message;
      sdkDetails = null;
    }
    return CometChatException(
      CallErrorCodes.joinFailed,
      sdkCode == null
          ? failure.message
          : '$sdkCode: ${sdkDetails ?? sdkMessage ?? failure.message}',
      failure.message,
      errorParams: <String, dynamic>{
        'sdkCode': ?sdkCode,
        'sdkMessage': ?sdkMessage,
        'sdkDetails': ?sdkDetails,
      },
    );
  }

  /// Handle end call button pressed event.
  ///
  /// Once: the call is already on its way out after the first End (or the
  /// peer-left rule), and a second leave and endCall used to fail and reach
  /// onError as a false error.
  ///
  /// A 1-on-1 call (the owner's order, round 4): the media session is left
  /// first (when the call joined), the screen closes at once, and the
  /// server's endCall goes out in the background once the leave is done
  /// ([_finishEndCall]). It used to wait for endCall before the screen
  /// closed; and on Android the leave's own "left" closed the bloc first,
  /// which dropped ccCallEnded. Also back while the call still connects
  /// (see [CometChatOngoingCall]): the join is cancelled and endCall still
  /// goes out, as the user ended the call.
  ///
  /// A meeting is only left.
  Future<void> _onEndCallButtonPressed(
    EndCallButtonPressed event,
    Emitter<OngoingCallState> emit,
  ) async {
    if (_teardownStarted || _callScreenClosed) {
      ccLog('OngoingCallBloc: $sessionId is already ending; End ignored');
      return;
    }
    if (_replaced('End')) return;
    _teardownStarted = true;
    _stopJoinWatchdog();

    if (callWorkFlow == CallWorkFlow.directCalling) {
      await _endSession(emit);
      return;
    }

    emit(
      state.copyWith(isCallEndedByMe: true, status: OngoingCallStatus.ending),
    );
    // Per CometChat docs: leave the WebRTC session first, then notify the
    // server via endCall, so the other participant is told the call ended
    // only once this side's media is down. A call still connecting has no
    // session to leave yet.
    final Future<void> left = _joined ? _leaveSession() : Future<void>.value();
    _closeCallScreen();
    // Always end the call on the server for 1-on-1 calls so the other
    // participant gets the "call ended" event.
    unawaited(_finishEndCall(left));
  }

  /// The server side of ending a 1-on-1 call from here, once [left] (the
  /// media session left) is done, or after [_leaveWaitLimit].
  ///
  /// ccCallEnded goes out when the server confirms, whether or not the
  /// screen and this bloc are still there: the chat's call bubble, the call
  /// buttons and the call logs hear of the end. A failure reaches onError
  /// with the SDK's code (the owner: report everything); a logout that began
  /// meanwhile owns the call, and the failure is only logged. A logout waits
  /// for this request (within its bound) before it logs out: the whole of
  /// it, the wait for the leave included. Only endCall used to be tracked,
  /// so a logout within 2 s of End saw nothing in flight and logged out
  /// before endCall went out (round 4 review, probe E).
  Future<void> _finishEndCall(Future<void> left) async {
    final epoch = CallsLifecycle.callEpoch;
    try {
      await ActiveCallTracker.trackCallRequest(() async {
        await left.timeout(_leaveWaitLimit, onTimeout: () {});
        final result = await CallOperationsServiceLocator
            .instance
            .endCallUseCase
            .call(sessionId);
        result.fold(
          (failure) {
            ccLog(
              'OngoingCallBloc: ending $sessionId failed: ${failure.message}',
            );
            if (epoch != CallsLifecycle.callEpoch) return;
            final error = callFailureException(failure);
            _handleError(error);
            _addFromSdk(
              _EndCallSettled(
                errorMessage: failure.message,
                errorCode: error.code,
              ),
            );
          },
          (endedCall) {
            endedCall.category = MessageCategoryConstants.call;
            CometChatCallEvents.ccCallEnded(endedCall);
            _addFromSdk(const _EndCallSettled());
          },
        );
      });
    } catch (e) {
      ccLog('OngoingCallBloc: ending $sessionId failed: $e');
    }
  }

  /// What ending the call on the server came to, for the state.
  void _onEndCallSettled(
    _EndCallSettled event,
    Emitter<OngoingCallState> emit,
  ) {
    if (event.errorMessage == null && event.errorCode == null) {
      emit(state.copyWith(status: OngoingCallStatus.ended));
      return;
    }
    emit(
      state.copyWith(
        status: OngoingCallStatus.error,
        errorMessage: event.errorMessage,
        errorCode: event.errorCode,
      ),
    );
  }

  /// Handle session timeout event
  Future<void> _onSessionTimeout(
    SessionTimeout event,
    Emitter<OngoingCallState> emit,
  ) async {
    if (_teardownStarted || _callScreenClosed) return;
    if (_replaced('a session timeout')) return;
    _teardownStarted = true;
    _stopJoinWatchdog();
    await _endSession(emit);
  }

  /// Handle call ended event: the session was left or its connection
  /// closed (Calls SDK callbacks).
  ///
  /// A 1-on-1 call this device did not end closes without an endCall (kept
  /// as it is, the owner's choice). While this device is ending the call
  /// itself (End, a failed join) this is its own leave echoing back, and
  /// nothing more happens. A meeting ignores it.
  Future<void> _onCallEnded(
    OngoingCallEnded event,
    Emitter<OngoingCallState> emit,
  ) async {
    if (callWorkFlow != CallWorkFlow.defaultCalling) return;
    if (_teardownStarted || _callScreenClosed) return;
    if (_replaced('the session ending')) return;
    if (_isEchoOfLeftSession('the session ending')) {
      // On Android the late "left" also stopped the ongoing-call service
      // natively (the plugin stops it on every "left"), this call's
      // included: started again. Before the native join, so this call's
      // own audio route still wins.
      if (_serviceLaunched) {
        unawaited(CometChatOngoingCallService.launch(isVideo: _serviceIsVideo));
      }
      return;
    }
    _teardownStarted = true;
    _stopJoinWatchdog();
    await _endSession(emit);
  }

  /// Whether a newer call screen has replaced this one ([_isOwner]), which
  /// then ignores [what] and leaves nothing: the session, and the call on
  /// it, are the newer screen's.
  ///
  /// A replaced screen is closed a frame after the newer one was built, and
  /// its native listeners hear the session until then. An End tapped on
  /// its view, its session's "left" or a timeout used to leave the session
  /// and, for End, send endCall: on the same call shown again that ended
  /// the live call (round 4 review, correctness 13).
  bool _replaced(String what) {
    if (_isOwner) return false;
    ccLog('OngoingCallBloc: $sessionId was replaced; $what ignored');
    return true;
  }

  /// Whether [what], an event of the session's, comes before this call's
  /// own native join right after another session was left for this call
  /// ([_echoOf]): it is then taken for that session's, and ignored.
  ///
  /// The Calls SDK's events say nothing about which session they are for.
  /// The "left" of a meeting answered over used to reach the answered
  /// call's screen once it had started joining and end that call; its
  /// participant list could arm the peer-left rule with the meeting's
  /// members (round 4 review, regression 9). The call's own
  /// `onSessionJoined` ends the window.
  bool _isEchoOfLeftSession(String what) {
    final left = _echoOf;
    if (left == null || _nativeJoined) return false;
    ccLogConsole(
      'OngoingCallBloc: $what before $sessionId joined, just after $left was '
      "left: taken for $left's; ignored",
    );
    return true;
  }

  /// Handle participant list changed event
  Future<void> _onParticipantListChanged(
    ParticipantListChanged event,
    Emitter<OngoingCallState> emit,
  ) async {
    if (_isEchoOfLeftSession('a participant list')) return;
    if (event.participants.isNotEmpty) _nativeJoinSeen('a participant list');
    _participantsList = [...event.participants];
    if (_otherCount(_participantsList) > 0) _peerSeen = true;
    emit(state.copyWith(participantsList: _participantsList));

    _evaluatePeerLeft();
  }

  /// Another participant joined: the peer has been seen.
  void _onParticipantJoined(
    _ParticipantJoined event,
    Emitter<OngoingCallState> emit,
  ) {
    if (_isEchoOfLeftSession('a participant joining')) return;
    _nativeJoinSeen('a participant joining');
    if (_isOther(event.participant.uid)) _peerSeen = true;
  }

  /// Handles a participant leaving the session.
  ///
  /// Not observed on iOS - the native Calls SDK emits no participant
  /// join/leave events there - but kept for platforms that do deliver it.
  /// The leaver is discounted explicitly because the participant list may not
  /// have refreshed by the time the leave arrives. A peer that leaves was in
  /// the session, so it has been seen.
  Future<void> _onParticipantLeft(
    ParticipantLeft event,
    Emitter<OngoingCallState> emit,
  ) async {
    if (_isEchoOfLeftSession('a participant leaving')) return;
    // Seen, but no native join: a stale event of an earlier session can be
    // one (native 7).
    if (_isOther(event.participant.uid)) _peerSeen = true;
    _evaluatePeerLeft(excludeUid: event.participant.uid);
  }

  /// The Calls SDK reported the native join.
  void _onSessionJoined(_SessionJoined event, Emitter<OngoingCallState> emit) {
    if (_nativeJoined) {
      // A participant event came first; the device check wants to see this
      // one arrive on both platforms too.
      ccLogConsole(
        'OngoingCallBloc: onSessionJoined for $sessionId, '
        '${_sinceView.elapsedMilliseconds} ms after the call view appeared',
      );
    }
    _nativeJoinSeen('onSessionJoined');
  }

  /// The native join was reported ([how]): the watchdog stops, and the
  /// audio the ringback or the ringtone handed over is the call's now.
  void _nativeJoinSeen(String how) {
    if (_nativeJoined) return;
    // On its way out: a participant event the leave itself caused (the
    // list emptied, say) is not a join, and must not forget the audio the
    // close is about to give back.
    if (_teardownStarted || _callScreenClosed) return;
    if (_screenTakenDown) {
      // A late native join for a screen already taken down from outside
      // (its call ended elsewhere, and no frame has closed this bloc yet:
      // the app is in the background): left at once (the owner's ghost
      // guard).
      ccLogConsole(
        'OngoingCallBloc: $sessionId joined natively ($how) after its '
        'screen was taken down; leaving it',
      );
      _teardownStarted = true;
      unawaited(_leaveSession());
      return;
    }
    _nativeJoined = true;
    _stopJoinWatchdog();
    ccLogConsole(
      'OngoingCallBloc: session joined: $sessionId ($how), '
      '${_sinceView.elapsedMilliseconds} ms after the call view appeared',
    );
    unawaited(CallAudioHandover.forget());
  }

  /// Starts the native join watchdog once the call view is on screen.
  ///
  /// The join's own 30 s bound covers only the Calls SDK's token and
  /// verification; the native join, once the view mounts, had no bound, and
  /// its errors never reach Dart. If no native join signal (see
  /// [_nativeJoined]) arrives within [ActiveCallTracker.nativeJoinTimeout]
  /// (30 s, the owner's choice) of the view appearing, the call is given up
  /// as a failed join (JOIN_TIMEOUT). Counted from the first frame after the
  /// view is handed over: the native side joins only once the view is
  /// mounted, and an app in the background draws no frames.
  ///
  /// Counted only while the app is in the foreground: it stops when the
  /// app leaves it (the screen locked right after an accept, say) and
  /// starts again, from 30 s, when it comes back. It used to go on, and a
  /// join that paused with the app failed as soon as the phone was unlocked
  /// (round 4 review, correctness 9 and native 6). Not on web: the
  /// browser's microphone and camera prompt comes only once the call view
  /// is mounted, and a user slow to answer it got JOIN_TIMEOUT (regression
  /// 2).
  void _armJoinWatchdog() {
    final timeout = ActiveCallTracker.nativeJoinTimeout;
    if (timeout == null || kIsWeb) return;
    _lifecycle ??= _CallScreenLifecycle(this)..attach();
    _scheduleJoinWatchdog(timeout);
  }

  /// Starts the watchdog's [timeout] at the end of the next frame, unless
  /// the app is not in the foreground then.
  void _scheduleJoinWatchdog(Duration timeout) {
    unawaited(
      SchedulerBinding.instance.endOfFrame.then((_) {
        if (_abandoned || _nativeJoined || _joinWatchdog != null) return;
        if (!_appInForeground) {
          _watchdogPaused = true;
          return;
        }
        if (!_sinceView.isRunning) _sinceView.start();
        _joinWatchdog = Timer(timeout, () {
          _joinWatchdog = null;
          _addFromSdk(const _NativeJoinTimedOut());
        });
      }),
    );
  }

  static bool get _appInForeground {
    final AppLifecycleState? state = SchedulerBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  /// The app left the foreground, or came back: see [_armJoinWatchdog].
  void _onAppLifecycle(AppLifecycleState state) {
    if (_abandoned || _nativeJoined) return;
    if (state == AppLifecycleState.resumed) {
      final timeout = ActiveCallTracker.nativeJoinTimeout;
      if (!_watchdogPaused || timeout == null) return;
      _watchdogPaused = false;
      _scheduleJoinWatchdog(timeout);
      return;
    }
    final Timer? watchdog = _joinWatchdog;
    if (watchdog == null) return;
    watchdog.cancel();
    _joinWatchdog = null;
    _watchdogPaused = true;
    ccLog(
      'OngoingCallBloc: the app left the foreground; the join watchdog of '
      '$sessionId waits for it to come back',
    );
  }

  void _stopJoinWatchdog() {
    _joinWatchdog?.cancel();
    _joinWatchdog = null;
    _watchdogPaused = false;
    _lifecycle?.detach();
    _lifecycle = null;
  }

  /// The call view never reported the join: a failed join (JOIN_TIMEOUT).
  void _onNativeJoinTimedOut(
    _NativeJoinTimedOut event,
    Emitter<OngoingCallState> emit,
  ) {
    if (_abandoned || _nativeJoined) return;
    final seconds = ActiveCallTracker.nativeJoinTimeout?.inSeconds;
    ccLogConsole(
      'OngoingCallBloc: $sessionId reported no join $seconds s after its '
      'call view appeared; giving the call up',
    );
    const message =
        'Could not join the call. Check your connection and try again.';
    _failJoin(
      emit,
      CometChatException(
        CallErrorCodes.joinTimeout,
        'The Calls SDK did not report joining the call within $seconds s of '
        'its call view appearing.',
        message,
      ),
      message,
    );
  }

  /// Ends a 1-on-1 call once no other participant remains.
  ///
  /// Mirrors the v5 UIKit guard (`onUserLeft` -> end the session when only the
  /// local user is left), but is driven by whichever signal the platform
  /// actually delivers: on iOS only `onParticipantListChanged` arrives, and it
  /// carries an empty list at the moment the peer goes away.
  ///
  /// Armed only once another participant has been seen in the session (a
  /// list naming them, or their joining or leaving): each side joins the
  /// media on its own after the accept, and a list holding only this user
  /// before the peer joined ended the call at once (round 4, the owner's
  /// choice; there is no "peer never joined" timer).
  ///
  /// The peer's app can terminate without a clean hangup, in which case no
  /// call-ended message arrives and nothing else closes this screen. Ends the
  /// call through the same path as the end-call button.
  void _evaluatePeerLeft({String? excludeUid}) {
    if (callWorkFlow != CallWorkFlow.defaultCalling) return;
    if (!_isOneToOneCall) return;
    if (!_peerSeen) return;
    if (_teardownStarted || _callScreenClosed || _peerLeftHandled) return;
    if (_otherCount(_participantsList, excludeUid: excludeUid) > 0) return;

    _peerLeftHandled = true;
    ccLog('OngoingCallBloc: the peer left $sessionId; ending the call');
    add(const EndCallButtonPressed());
  }

  /// The logged-in user, as call handling knows them.
  static String? get _myUid =>
      CallsLifecycle.uid ?? CometChatUIKit.loggedInUser?.uid;

  /// Whether [uid] is a participant other than the logged-in user.
  static bool _isOther(String? uid) => uid != null && uid != _myUid;

  /// Participants other than the logged-in user.
  ///
  /// Counts *others* rather than the whole list, which keeps this correct
  /// whether or not the SDK includes the local user in the participant list.
  int _otherCount(List<Participant> participants, {String? excludeUid}) {
    final myUid = _myUid;
    return participants
        .where((p) => p.uid != myUid && p.uid != excludeUid)
        .length;
  }

  /// True when this is a 1-on-1 (user-to-user) call.
  ///
  /// The call record says, when it holds this call: anything but a group
  /// call is 1-on-1. Without a record of it (a host that shows the call
  /// screen itself, or an accept the record never heard of) a
  /// [CallWorkFlow.defaultCalling] screen is a 1-on-1 call, as Android's
  /// DEFAULT workflow is (round 4, P4-C10).
  bool get _isOneToOneCall {
    final active = CallEventService.instance.activeCall;
    if (active is Call && active.sessionId == sessionId) {
      return active.receiverType != ReceiverTypeConstants.group;
    }
    return callWorkFlow == CallWorkFlow.defaultCalling;
  }

  /// What back does while this screen is up: while the call still connects,
  /// it cancels it (as End would: the join is given up, a 1-on-1 call is
  /// ended on the server, the screen closes). Once the call is up, nothing
  /// (the owner's choice; picture-in-picture comes later).
  void _onBack() {
    if (isClosed || _teardownStarted || _callScreenClosed || !_isOwner) {
      return;
    }
    // Once the native side has joined, the call is up: back does nothing.
    // Until then (the join on its way, or the call view up but not joined
    // yet: the iPad's slow view mount, say) it cancels (round 4 review,
    // correctness 8; Android only, as iOS has no system back).
    if (_nativeJoined) return;
    ccLog('OngoingCallBloc: back while $sessionId connects; cancelling it');
    add(const EndCallButtonPressed());
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Leaves the session and closes the screen: a remote end, a timeout, a
  /// meeting's End.
  Future<void> _endSession(Emitter<OngoingCallState> emit) async {
    emit(state.copyWith(status: OngoingCallStatus.ending));

    _sessionLeft = true;
    final Future<Result<void>> leaving = _stopOwnService().then(
      (_) => CallOperationsServiceLocator.instance.endSessionUseCase.call(),
    );
    _leaving = leaving.then<void>((_) {}, onError: (Object _) {});
    final result = await leaving;

    if (isClosed) return;

    result.fold(
      (failure) {
        if (kDebugMode) {
          ccLog('Session could not be ended: ${failure.message}');
        }
        final error = callFailureException(failure);
        _handleError(error);
        // Close the screen even when teardown fails. On the remote-hangup
        // path this fold is the only thing standing between a failed
        // endSession and a call screen the user cannot dismiss.
        _closeCallScreen();
        emit(
          state.copyWith(
            status: OngoingCallStatus.error,
            errorMessage: failure.message,
            errorCode: error.code,
          ),
        );
      },
      (_) {
        _closeCallScreen();
        emit(state.copyWith(status: OngoingCallStatus.ended));
      },
    );
  }

  /// Closes the call screen, once.
  ///
  /// The call is over for this device however the screen closed: its record
  /// is released (a failed end or a session-level teardown used to leave it,
  /// and with it set the next call is refused and the next incoming one
  /// gets busy). Not when a newer screen for this same call took over: the
  /// record is that screen's.
  ///
  /// Only while this screen owns the call, or no call screen is up any
  /// more ([_actsForApp]), does it give up the app's shared state
  /// ([_releaseScreenEffects]) and the handed-over audio. Only the owner
  /// dismisses the overlay, by its own session. A standalone screen (not in
  /// [CallScreenOverlay]) is popped off the app's navigator as before.
  void _closeCallScreen() {
    if (_callScreenClosed) return;
    _callScreenClosed = true;
    _stopJoinWatchdog();

    final owner = _isOwner;
    final actsForApp = _actsForApp;
    if (sessionId.isNotEmpty &&
        (actsForApp || ActiveCallTracker.callScreenSessionId != sessionId)) {
      ActiveCallTracker.release(sessionId);
    }
    if (actsForApp) {
      _releaseScreenEffects();
      _giveBackHandedOverAudio();
      _armGhostJoinGuard();
    }

    if (_shownInOverlay) {
      if (owner) CallScreenOverlay.dismiss(sessionId: sessionId);
      return;
    }

    // A standalone screen: the route its widget sits on, in whatever
    // navigator that is. A nested navigator's (a tab, a go_router shell
    // route) used to stay up: the root navigator was popped instead, and
    // could not pop (round 4 review, probe B).
    final Route<dynamic>? route = ActiveCallTracker.ongoingCallRouteOf(this);
    if (route != null) {
      final NavigatorState? navigator = route.navigator;
      if (navigator != null && route.isActive) {
        if (route.isCurrent) {
          navigator.pop();
        } else {
          navigator.removeRoute(route);
        }
      }
      return;
    }
    // Otherwise the overlay when it shows this very call, or Navigator.pop
    // for backward compatibility.
    if (owner &&
        CallScreenOverlay.isShowing &&
        ActiveCallTracker.callScreenSessionId == sessionId) {
      CallScreenOverlay.dismiss(sessionId: sessionId);
      return;
    }
    final navigatorContext = CallNavigationContext.navigatorKey.currentContext;
    if (navigatorContext != null && navigatorContext.mounted) {
      final navigator = Navigator.of(navigatorContext);
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  /// Gives up this screen's hold on what the app shares, once, and only
  /// while it owns the call: the orientation is the app's own again, then
  /// CallStateService says no call is on, and back is no longer this
  /// screen's to handle.
  ///
  /// The orientation goes back to what the app had before the call
  /// ([CallOrientation]): on Android the activity's own (its manifest lock,
  /// or one set from code), on iOS the orientations of Info.plist. It used
  /// to unlock all four, which made a portrait-only app rotatable after its
  /// first call. During the call it stays portrait, either way up (Android:
  /// user portrait, which also overrides a manifest lock while the call is
  /// on).
  ///
  /// The orientation first: an app that sets its own orientation when
  /// CallStateService turns false has the last word (round 4 review; 6.1.1
  /// did it in this order too).
  void _releaseScreenEffects() {
    if (_screenEffectsReleased) return;
    _screenEffectsReleased = true;
    CallOrientation.release();
    CallStateService.instance.setActiveCallValue(false);
    if (identical(ActiveCallTracker.callScreenBack, _backHandler)) {
      ActiveCallTracker.callScreenBack = null;
    }
  }

  /// Leaves the media session (which also stops the Android ongoing-call
  /// service), once. Never throws.
  Future<void> _leaveSession() {
    if (_sessionLeft) return _leaving ?? Future<void>.value();
    _sessionLeft = true;
    return _leaving = _leave();
  }

  Future<void> _leave() async {
    await _stopOwnService();
    try {
      final result = await CallOperationsServiceLocator
          .instance
          .endSessionUseCase
          .call();
      result.fold(
        (failure) =>
            ccLog('OngoingCallBloc: leaving $sessionId: ${failure.message}'),
        (_) => ccLog('OngoingCallBloc: left $sessionId'),
      );
    } catch (e) {
      ccLog('OngoingCallBloc: leaving $sessionId failed: $e');
    }
  }

  /// Arms the ghost-join guard for this session when its call view was
  /// handed over but its native join never reported: on iOS that view can
  /// still join after the screen gave the call up. See [GhostJoinGuard].
  void _armGhostJoinGuard() {
    if (_joined && !_nativeJoined) GhostJoinGuard.arm(sessionId);
  }

  /// Stops the Android ongoing-call service this bloc started, before it
  /// leaves the session (the order `CometChatUIKitCalls.endSession` keeps).
  ///
  /// The service is started and stopped in the same layer (round 4
  /// review): the UI Kit's data source (`CometChatUIKitCalls.endSession`)
  /// stops it too, but a data source of the host's
  /// (`CallOperationsServiceLocator.setup(dataSource:)`) whose `endSession`
  /// only leaves left the "Call in progress" notification up. Never throws.
  Future<void> _stopOwnService() {
    if (!_serviceLaunched) return Future<void>.value();
    _serviceLaunched = false;
    return CometChatOngoingCallService.abort();
  }

  /// Gives back the audio the ringback or the ringtone handed to this call,
  /// once this bloc's leave (if any) is done or after [_leaveWaitLimit]:
  /// on Android the communication mode, the route and the audio focus, on
  /// iOS the audio session. Only for a call that never joined natively
  /// (once it has, the Calls engine has the audio), and once.
  ///
  /// Every way a screen that owns the call closes before the native join
  /// comes here: a failed join, End or back while connecting, a remote end
  /// or a timeout, a screen taken down from outside. Only the failed join
  /// gave it back before (round 4 review): back on "Connecting..." left an
  /// Android phone in communication mode with the earpiece routed, and a
  /// remote end during the join left the iOS session active, so music
  /// never resumed.
  void _giveBackHandedOverAudio() {
    if (_audioGivenBack || _nativeJoined) return;
    _audioGivenBack = true;
    final Future<void> left = _leaving ?? Future<void>.value();
    unawaited(
      left
          .timeout(_leaveWaitLimit, onTimeout: () {})
          .then((_) => CallAudioHandover.restore()),
    );
  }

  /// Hands [error] to [errorCallback], if provided. A callback that throws
  /// is only logged: it must not stop what follows the report (the error
  /// state, the screen closing). A Calls SDK error goes through
  /// [handleCallsError].
  void _handleError(CometChatException error) =>
      reportCallError(errorCallback, error, where: 'OngoingCallBloc');

  /// Remove V5 listeners from CallSession
  void _removeListeners() {
    final session = CallSession.getInstance();
    session?.removeSessionStatusListener(_sessionListener);
    session?.removeButtonClickListener(_buttonListener);
    session?.removeParticipantEventListener(_participantListener);
  }

  /// Also the safety net for a screen taken down from outside (a host's
  /// `CallScreenOverlay.dismiss()`, say) without its call being ended: while
  /// it still owns the call, or no call screen is up any more
  /// ([_actsForApp]), the session it joined is left (it used to go on with
  /// no screen, the Android service with it) and the record is released,
  /// as Android's call activity does when it is destroyed. A screen a newer
  /// one replaced leaves nothing while that one is up: the session is the
  /// newer call's now.
  @override
  Future<void> close() {
    _stopJoinWatchdog();
    _removeListeners();

    final owner = _actsForApp;
    if (owner && !_callScreenClosed) {
      _callScreenClosed = true;
      if (_joined && !_sessionLeft && ActiveCallTracker.mayHaveMediaSession) {
        ccLog('OngoingCallBloc: left session on dispose ($sessionId)');
        unawaited(_leaveSession());
      }
      if (sessionId.isNotEmpty) ActiveCallTracker.release(sessionId);
      _giveBackHandedOverAudio();
      _armGhostJoinGuard();
    }
    if (owner) {
      _releaseScreenEffects();
    } else if (identical(ActiveCallTracker.callScreenBack, _backHandler)) {
      ActiveCallTracker.callScreenBack = null;
    }

    // No Calls SDK re-init here (Android never does one either). The plugin
    // stays initialised and logged in across sessions; the next join checks
    // readiness through waitForCallsSdk() and repairs only what is missing.

    ccLog('OngoingCallBloc closed');

    return super.close();
  }
}

/// The Calls SDK reported the native join (`onSessionJoined`). Private, so
/// no public event is added for it.
final class _SessionJoined extends OngoingCallEvent {
  const _SessionJoined();
}

/// A participant joined the session.
final class _ParticipantJoined extends OngoingCallEvent {
  const _ParticipantJoined(this.participant);

  final Participant participant;

  @override
  List<Object?> get props => [participant];
}

/// The call view never reported the join: see
/// `OngoingCallBloc._armJoinWatchdog`.
final class _NativeJoinTimedOut extends OngoingCallEvent {
  const _NativeJoinTimedOut();
}

/// What the server's endCall came to: ended, or failed with
/// [errorMessage] and [errorCode].
final class _EndCallSettled extends OngoingCallEvent {
  const _EndCallSettled({this.errorMessage, this.errorCode});

  final String? errorMessage;
  final String? errorCode;

  @override
  List<Object?> get props => [errorMessage, errorCode];
}

/// Tells a call screen's bloc when the app leaves or comes back to the
/// foreground, for its join watchdog.
final class _CallScreenLifecycle with WidgetsBindingObserver {
  _CallScreenLifecycle(this.bloc);

  final OngoingCallBloc bloc;

  void attach() => WidgetsBinding.instance.addObserver(this);

  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      bloc._onAppLifecycle(state);
}
