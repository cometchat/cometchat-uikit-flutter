import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import '../../../../cometchat_calls_uikit.dart';
import '../../../../cometchat_chat_uikit.dart';
import '../../../../shared_ui/src/logging/cometchat_log.dart';
import '../../../../src/active_call_tracker.dart';
import '../../../../src/call_errors.dart';
import '../../../../src/call_permission_check.dart';
import '../../../../src/call_session_settings.dart';
import '../../../../src/calls_lifecycle.dart';
import '../../../../src/incoming_ringtone.dart';

/// BLoC for managing incoming call screen state and actions
///
/// This BLoC handles:
/// - The ringtone and vibration on initialization (unless disabled)
/// - Accept call action (calls SDK, navigates to OngoingCall)
/// - Reject call action (calls SDK, dismisses overlay)
/// - Call cancelled handling (dismisses overlay)
/// - CallStateService updates on init and close
///
/// The first tap wins: once Accept or Decline is tapped, the other is
/// ignored, and the ringtone stops at the tap. The call is given up locally
/// ([IncomingCallStatus.cancelled], nothing sent to the server) when it is
/// cancelled, answered or declined on another device of the same user, or
/// when it has rung for 60 seconds with nobody acting on it.
///
/// Hears the call's own events through [CallListener]: a cancel
/// (`onIncomingCallCancelled`), and the same user answering or declining it
/// on another device (`onOutgoingCallAccepted` / `onOutgoingCallRejected`
/// naming them as the actor).
///
/// Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7
class IncomingCallBloc extends Bloc<IncomingCallEvent, IncomingCallState>
    with CallListener {
  /// The active incoming call
  final Call call;

  /// User who is calling (optional, for display purposes)
  final User? user;

  /// Custom session settings builder (V5)
  final SessionSettingsBuilder? callSettingsBuilder;

  /// Called at the Decline tap, with the navigator's context
  /// (`CallNavigationContext.navigatorKey`), before the decline goes to the
  /// server; not without that navigator, or for an ignored tap. A side
  /// effect only: the decline goes ahead, and whatever it throws is
  /// reported to [errorCallback] (`HOST_CALLBACK_ERROR` when it is not a
  /// `CometChatException`).
  final Function(BuildContext, Call)? onDecline;

  /// Called at the Accept tap, as [onDecline], before the permission
  /// request and the accept. A side effect only: the accept goes ahead, even
  /// if the hook takes the banner down.
  final Function(BuildContext, Call)? onAccept;

  /// Whether to disable sound for calls. Turns the vibration off too.
  final bool? disableSoundForCalls;

  /// Custom sound asset for calls
  final String? customSoundForCalls;

  /// Package name for custom sound asset
  final String? customSoundForCallsPackage;

  /// Error callback
  final OnError? errorCallback;

  /// Unique listener ID for SDK listeners
  late final String _listenerId;

  /// Creates an IncomingCallBloc
  ///
  /// [call] is required and represents the active incoming call.
  /// Sound playback starts on init unless [disableSoundForCalls] is true.
  ///
  /// Close a bloc you create when you are done with it: it rings, listens
  /// for the call's events and runs a 60-second timer from its creation
  /// until then. In a widget test, close it before the test's body ends: a
  /// timer still pending when the body ends fails the test (a `tearDown` is
  /// too late).
  IncomingCallBloc({
    required this.call,
    this.user,
    this.callSettingsBuilder,
    this.onDecline,
    this.onAccept,
    this.disableSoundForCalls,
    this.customSoundForCalls,
    this.customSoundForCallsPackage,
    this.errorCallback,
  }) : super(const IncomingCallState()) {
    // Generate unique listener ID
    _listenerId =
        'incomingCall_${DateTime.now().microsecondsSinceEpoch.toString()}';

    // Register event handlers
    on<AcceptCall>(_onAcceptCall);
    on<RejectCall>(_onRejectCall);
    on<CallCancelled>(_onCallCancelled);

    // Initialize
    _initialize();
  }

  /// Initialize the BLoC - add listeners, update call state, play sound
  void _initialize() {
    // Update CallStateService to track active incoming call
    CallStateService.instance.setActiveIncomingValue(true);

    // Add SDK listener for call events
    CometChat.addCallListener(_listenerId, this);

    _ringDeadline = ActiveCallTracker.wallClock().add(
      ActiveCallTracker.incomingRingTimeout,
    );

    // Play incoming call sound unless disabled
    if (disableSoundForCalls != true) {
      _playIncomingSound();
    }

    _ringTimeout = Timer(ActiveCallTracker.incomingRingTimeout, _onRingTimeout);
    _lifecycle = AppLifecycleListener(onResume: _checkRingDeadline);
  }

  /// When this call stops ringing at the latest, by the wall clock: 60 s
  /// ([ActiveCallTracker.incomingRingTimeout]) from when it started.
  DateTime? _ringDeadline;

  /// Hears the app come back to the foreground: see [_checkRingDeadline].
  AppLifecycleListener? _lifecycle;

  /// The app came back to the foreground. On iOS a suspended app runs no
  /// timers, so a call that started ringing before the app went away can be
  /// past its 60 s by now with [_ringTimeout] still waiting: it is given up
  /// at once, as the timer would have. (The native ringtone does not ring
  /// past the same deadline either.)
  void _checkRingDeadline() {
    final deadline = _ringDeadline;
    // Not ringing any more: the timer stops at the tap and at every end.
    if (_ringTimeout == null || deadline == null || isClosed) return;
    if (ActiveCallTracker.wallClock().isBefore(deadline)) return;
    _stopRingTimeout();
    _onRingTimeout();
  }

  /// Gives up on a call nobody acted on: see
  /// [ActiveCallTracker.incomingRingTimeout]. Cancelled at the first tap
  /// and whenever ringing ends.
  Timer? _ringTimeout;

  /// The call rang out on this device: it is given up locally, as a cancel
  /// is (the banner closes, the ringtone stops, the call stops counting as
  /// ringing), so a host that shows this bloc on a screen of its own sees
  /// [IncomingCallStatus.cancelled] and can close it. Nothing goes to the
  /// server: the caller's side ends the call.
  void _onRingTimeout() {
    _ringTimeout = null;
    // Every way out of ringing cancels the timer; a closed bloc takes no
    // more events.
    if (isClosed) return;
    ccLog(
      'IncomingCallBloc: ${call.sessionId} rang for '
      '${ActiveCallTracker.incomingRingTimeout.inSeconds} s with no answer; '
      'giving up on it here',
    );
    add(const CallCancelled());
  }

  void _stopRingTimeout() {
    _ringTimeout?.cancel();
    _ringTimeout = null;
  }

  /// Rings. The ringtone is this bloc's until another one starts: see
  /// [_stopSound]. A custom sound with no package is the app's own asset.
  void _playIncomingSound() {
    try {
      unawaited(
        IncomingRingtone.play(
          assetPath: customSoundForCalls,
          package: customSoundForCallsPackage,
          owner: this,
          deadline: _ringDeadline,
        ),
      );
      ccLog('Incoming call sound playing');
    } catch (e) {
      ccLog('Failed to play incoming call sound: $e');
    }
  }

  /// Stops the ringtone and the vibration, and gives the audio back, when
  /// they are still the ones this bloc started.
  ///
  /// A banner replaced by the next incoming call is closed after the next
  /// one has started ringing; stopping the player then silenced the new
  /// call's ringtone (round 2, P3-C15).
  ///
  /// Through the UI Kit's own stop, not `SoundManager.stop()`: that one is
  /// the host's, and also stops the outgoing call's ringback.
  ///
  /// A bloc with its sound turned off never started one, so it stops
  /// nothing.
  void _stopSound() => unawaited(IncomingRingtone.stop(owner: this));

  /// The call screen is about to open: the audio the ringtone held is the
  /// call's now (see `IncomingRingtone.handOver`).
  void _handOverSound() {
    if (disableSoundForCalls == true) return;
    unawaited(IncomingRingtone.handOver(owner: this));
  }

  // ============================================================
  // SDK LISTENER CALLBACKS - CallListener
  // ============================================================

  /// Called when the incoming call is cancelled by the caller.
  ///
  /// Only for this call. The SDK broadcasts cancels to every listener, and a
  /// cancel for some other session — a call bounced with busy, or a stale one
  /// — used to dismiss the call ringing on screen. Kotlin's incoming ViewModel
  /// checks the session the same way.
  @override
  void onIncomingCallCancelled(Call cancelled) {
    final ours = call.sessionId;
    if (ours != null &&
        ours.isNotEmpty &&
        cancelled.sessionId != null &&
        cancelled.sessionId != ours) {
      return;
    }
    add(const CallCancelled());
  }

  /// "Rejected" or "busy" for a call. For this one, while this device has
  /// not acted on it, the same user declined it (or it was bounced busy) on
  /// another device: ringing here is over, as for a cancel. The Dart SDK
  /// delivers that echo here when the server names this user as the actor,
  /// and as [onIncomingCallCancelled] otherwise.
  ///
  /// Every other "rejected" belongs to an outgoing call, or is this device's
  /// own decline: ignored.
  @override
  void onOutgoingCallRejected(Call rejected) =>
      _handledElsewhere(rejected, 'declined');

  /// "Ongoing" for a call. For this one, while this device has not acted on
  /// it, the same user answered it on another device: ringing here is over,
  /// as for a cancel. This device's own accept is already accepting when its
  /// echo arrives, and is left alone.
  ///
  /// Only when the logged-in user is who answered: in a group call another
  /// member joining sends "ongoing" to every member, and the call rings on
  /// here.
  @override
  void onOutgoingCallAccepted(Call accepted) =>
      _handledElsewhere(accepted, 'answered');

  void _handledElsewhere(Call other, String how) {
    final ours = call.sessionId;
    if (ours == null || ours.isEmpty || other.sessionId != ours) return;
    // Someone else acted (another member of a group call): not this user.
    if (!ActiveCallTracker.actedByLoggedInUser(other)) return;
    if (isClosed) return;
    // Still ringing, or Accept tapped but its request not sent yet (the
    // permission prompt is up): the answer came from another device. Once
    // the request is out, an "ongoing" is this device's own echo.
    final waitingToAccept =
        state.status == IncomingCallStatus.accepting && !_acceptRequested;
    if (state.status != IncomingCallStatus.idle && !waitingToAccept) return;
    ccLog('IncomingCallBloc: $ours was $how on another device');
    add(const CallCancelled());
  }

  /// Whether this bloc's accept request has gone out: from then on an
  /// "ongoing" for the call is its own echo.
  bool _acceptRequested = false;

  // ============================================================
  // EVENT HANDLERS
  // ============================================================

  /// Whether this call has been answered, declined or given up already: the
  /// first tap wins, so Accept and Decline both stop here then.
  bool get _alreadyActedOn =>
      _declined ||
      switch (state.status) {
        IncomingCallStatus.cancelled ||
        IncomingCallStatus.accepting ||
        IncomingCallStatus.accepted ||
        IncomingCallStatus.rejecting ||
        IncomingCallStatus.rejected => true,
        // A failed accept or decline can be tried again.
        IncomingCallStatus.idle || IncomingCallStatus.error => false,
      };

  /// Handle accept call event.
  ///
  /// Uses a [Completer] to bridge the callback-based [CometChat.acceptCall]
  /// into the async handler so that [emit] is called within the handler scope
  /// (prevents "emit was called after an event handler completed normally").
  Future<void> _onAcceptCall(
    AcceptCall event,
    Emitter<IncomingCallState> emit,
  ) async {
    // The first tap wins: an accept after a decline (or a second accept, or
    // after the call ended) is ignored, so only one of them reaches the
    // server. A decline racing an accept in flight used to send both, and a
    // failed decline then cleared the record of the call just connected.
    if (_alreadyActedOn) {
      ccLog(
        'IncomingCallBloc: ignoring AcceptCall — status is ${state.status}',
      );
      return;
    }

    // A logout is ending this device's calls: it has already picked the ones
    // it declines, so an accept now would open a call nothing ends.
    if (CallsLifecycle.isPreparingLogout) {
      ccLog('IncomingCallBloc: logging out; not accepting ${call.sessionId}');
      return;
    }

    // A logout (or call handling stopping) while this accept is in flight
    // must not end with a call screen over the login screen.
    final epoch = CallsLifecycle.callEpoch;
    final uid = CallsLifecycle.uid;

    // Disable buttons during accept
    emit(
      state.copyWith(status: IncomingCallStatus.accepting, isDisabled: true),
    );

    // Ringing ends at the tap, not once the server has answered: it used to
    // go on through the permission prompt and the whole round trip. Only
    // the sound and vibration stop: the audio stays as it is for the call
    // until the call screen takes it over (or is given back when no call
    // screen follows).
    _stopRingTimeout();
    _finishedBeforeAccept = ActiveCallTracker.finishedLately(call.sessionId);
    final Future<void> ringtonePaused = disableSoundForCalls == true
        ? Future<void>.value()
        : IncomingRingtone.pause(owner: this);
    await _accept(epoch, uid, ringtonePaused, emit);
  }

  Future<void> _accept(
    int epoch,
    String? uid,
    Future<void> ringtonePaused,
    Emitter<IncomingCallState> emit,
  ) async {
    // The host's hook is a side effect: whatever it throws is reported and
    // the accept goes ahead. A throw used to stop the accept part-way, and
    // with both buttons off the banner would have stayed up for good.
    _runHostHook(onAccept, 'onAccept');
    // Given up meanwhile (the hook dismissed the banner, a cancel came in):
    // nothing to answer. Every way out that opens no call screen gives the
    // ringtone up: still owned while paused, it held every message sound
    // back, until the next incoming call (a logout did not end it).
    if (_gaveUp) {
      _stopSound();
      return;
    }

    // Get session ID
    final String? sessionId = call.sessionId;
    if (sessionId == null) {
      _stopSound();
      emit(
        state.copyWith(
          status: IncomingCallStatus.error,
          isDisabled: false,
          errorMessage: 'Session ID is null',
        ),
      );
      return;
    }

    // Request microphone/camera permissions before accepting the call.
    // Without this, WebRTC throws SecurityError: Permission denied. A voice
    // call needs the microphone, a video call the microphone and the camera
    // (the owner's strict rule: no video call without its camera).
    final isVideoCall = call.type == CallTypeConstants.videoCall;
    CallPermissionOutcome? permissions;
    Object? permissionError;
    try {
      permissions = await CallPermissionCheck.request(isVideoCall: isVideoCall);
    } catch (e, stackTrace) {
      // The permission plugin refusing (a request already running, say).
      // Left to escape, the banner stayed up with both buttons off.
      ccLog('IncomingCallBloc: asking for permissions failed: $e\n$stackTrace');
      permissionError = e;
    }
    if (epoch != CallsLifecycle.callEpoch) {
      // Logged out while the permission prompt was up: nothing to answer.
      // Given up here as a cancel is: nothing goes to the server (the
      // logout declines what it declines), and a host showing this bloc
      // itself sees cancelled rather than an accept that never ends.
      ccLog('IncomingCallBloc: calls were torn down; not accepting $sessionId');
      _stopSound();
      emit(state.copyWith(status: IncomingCallStatus.cancelled));
      return;
    }
    // The call was cancelled (or answered elsewhere, or the banner taken
    // down) while the prompt was up: accepting it now would only fail.
    if (_gaveUp) {
      ccLog('IncomingCallBloc: $sessionId ended during the permission prompt');
      _stopSound();
      return;
    }
    if (permissions == null || !permissions.isGranted) {
      await _declineForPermissions(
        sessionId,
        permissions,
        isVideoCall,
        permissionError,
        emit,
      );
      return;
    }

    // Accept call via use case. Tracked, so a logout that starts meanwhile
    // lets it land and end its call rather than declining the call too.
    final acceptCallUseCase =
        CallOperationsServiceLocator.instance.acceptCallUseCase;
    // From here until the answer has been dealt with, an "ongoing" for this
    // call is this device's own. Not from the tap: while the permission
    // prompt was up, the same user answering on another device has to stop
    // this accept, and was taken for this device's echo.
    _acceptRequested = true;
    ActiveCallTracker.respondingTo(sessionId);
    try {
      await ActiveCallTracker.trackCallRequest(() async {
        final result = await acceptCallUseCase.call(sessionId);
        if (epoch != CallsLifecycle.callEpoch) {
          await _landAfterTeardown(result, sessionId, uid, emit);
          return;
        }
        // Given up while the request was on its way (a cancel, the call
        // ended): no call screen for it.
        if (_gaveUp) {
          await _landAfterGivingUp(result, sessionId);
          return;
        }
        // The ringtone's own audio work is done before the Calls engine
        // starts on the session (on iOS it runs on a queue of its own).
        // Bounded: a native side that does not answer must not hold the
        // call.
        if (result is Success<Call>) {
          await ringtonePaused.timeout(_ringtoneWorkLimit, onTimeout: () {});
          // A group meeting on screen is left before this call joins.
          final String? meeting = await _leaveMeetingOnScreen();
          if (meeting != null) {
            // Logged out, or given up, while the meeting was being left: no
            // call screen follows, so the meeting's goes too.
            if (epoch != CallsLifecycle.callEpoch) {
              _closeLeftMeeting(meeting);
              await _landAfterTeardown(result, sessionId, uid, emit);
              return;
            }
            if (_gaveUp) {
              _closeLeftMeeting(meeting);
              await _landAfterGivingUp(result, sessionId);
              return;
            }
          }
        }
        _landAccept(result, sessionId, emit);
      }, acceptingSessionId: sessionId);
    } finally {
      ActiveCallTracker.doneResponding(sessionId);
    }
  }

  /// How long the accept waits for the ringtone's native stop: see [_accept].
  static const Duration _ringtoneWorkLimit = Duration(seconds: 1);

  /// How long an accept waits for a meeting on screen to be left: see
  /// [_leaveMeetingOnScreen].
  static const Duration _meetingLeaveLimit = Duration(seconds: 3);

  /// A group meeting on screen when this 1-on-1 call is answered is left
  /// before the call joins (the owner's choice, round 3; P3-C21): its media
  /// session is left (which also stops the Android ongoing-call service),
  /// then the call screen that replaces it closes it. Returns the meeting's
  /// session, or null when there was none.
  ///
  /// A meeting does not make the device busy (as on Android), so a 1-on-1
  /// call can ring during one. Answering it used to take the meeting's
  /// screen down without leaving its session: the Calls SDK has one
  /// session for the app, and the call then joined over a meeting that was
  /// still live. Bounded by [_meetingLeaveLimit]: the call joins anyway
  /// (the Calls SDK leaves a session still up before it joins the next).
  ///
  /// First the meeting's screen stops owning the call: a meeting still
  /// connecting whose join lands during the leave starts nothing, and its
  /// view never joins natively after the leave (round 4 review,
  /// correctness 6). And the meeting is recorded as just left: its "left"
  /// can come after this call's screen has started joining, and a late
  /// leave used to end the new call (regression 9).
  Future<String?> _leaveMeetingOnScreen() async {
    if (ActiveCallTracker.callScreenWorkFlow != CallWorkFlow.directCalling) {
      return null;
    }
    final meeting = ActiveCallTracker.callScreenSessionId ?? '';
    ccLog(
      'IncomingCallBloc: leaving the meeting $meeting before joining '
      '${call.sessionId}',
    );
    ActiveCallTracker.retireCallScreen();
    ActiveCallTracker.noteLeftBeforeJoin(meeting);
    try {
      final left = await CallOperationsServiceLocator.instance.endSessionUseCase
          .call()
          .timeout(_meetingLeaveLimit);
      left.fold(
        (failure) => ccLog(
          'IncomingCallBloc: leaving the meeting $meeting: ${failure.message}',
        ),
        (_) => ccLog('IncomingCallBloc: left the meeting $meeting'),
      );
    } catch (e) {
      ccLog('IncomingCallBloc: leaving the meeting $meeting: $e');
    }
    return meeting;
  }

  /// Closes the screen of the [meeting] this accept left, when no call
  /// screen follows (the call was given up, or a logout began, during the
  /// leave). Its session is gone and its own screen ignores the end of a
  /// meeting's session: it stayed up, black, with back doing nothing
  /// (round 4 review, correctness 2).
  void _closeLeftMeeting(String meeting) {
    ccLog('IncomingCallBloc: no call follows; closing the left meeting');
    CallScreenOverlay.dismiss(sessionId: meeting.isEmpty ? null : meeting);
  }

  /// Whether the call was given up on while an accept was on its way: a
  /// cancel, answered or declined on another device, the 60 s timeout (this
  /// bloc is cancelled), or the call ended for this device some other way
  /// (a push cancel or a "call ended" dismissing its banner by its session:
  /// [ActiveCallTracker.finishedLately]). A logout is the epoch's.
  ///
  /// Not the bloc being closed alone: the host's hooks are side effects
  /// (D-P3-04 A), and an `onAccept` that takes the banner down with
  /// `IncomingCallOverlay.dismiss()` used to drop the accept silently once
  /// a frame ran before the permission answer, with nothing sent and no
  /// `onError`.
  ///
  /// Only an end that came after the tap counts: a host retrying after a
  /// failed accept (whose clean-up remembered the call) is not stopped by
  /// it.
  bool get _gaveUp =>
      state.status == IncomingCallStatus.cancelled ||
      (!_finishedBeforeAccept &&
          ActiveCallTracker.finishedLately(call.sessionId));

  /// Whether the call already counted as finished when this accept was
  /// tapped: see [_gaveUp].
  bool _finishedBeforeAccept = false;

  /// The permissions an accept needs were refused ([permissions]), or could
  /// not be asked for ([permissionError], [permissions] null). The call is
  /// declined (`rejected`) so the caller is not left ringing, the banner
  /// goes, `ccCallRejected` goes out (on a failed decline too, as for a
  /// tapped one) and the record is released. [errorCallback] gets
  /// `PERMISSION_DENIED` or `PERMISSION_PERMANENTLY_DENIED` (or the plugin's
  /// error); without one, the user is told in a SnackBar, with a way to the
  /// app's settings when the system will not ask again.
  ///
  /// The user hears why at once, as the banner goes: the notice used to
  /// wait for the decline's round trip, up to a minute on a bad network,
  /// with nothing on screen meanwhile. A logout during that round trip
  /// leaves the rest to it: the decline's answer is only logged.
  ///
  /// The buttons stay off: the call is declined on the server, and a second
  /// accept of it could only fail.
  Future<void> _declineForPermissions(
    String sessionId,
    CallPermissionOutcome? permissions,
    bool isVideoCall,
    Object? permissionError,
    Emitter<IncomingCallState> emit,
  ) async {
    ccLog('Call permissions denied, cannot accept call');
    _declined = true;
    _stopSound();
    // Dismiss the overlay so the user isn't stuck on a frozen call screen
    IncomingCallOverlay.dismiss(sessionId: sessionId);
    final message =
        'Microphone${isVideoCall ? '/camera' : ''} permission denied';
    if (permissions == null) {
      _handleError(callExceptionFrom(permissionError ?? message));
    } else {
      _handleError(permissions.toException(message));
      if (errorCallback == null) {
        _showPermissionNotice(
          isVideoCall: isVideoCall,
          permanentlyDenied: permissions.permanentlyDenied,
        );
      }
    }
    // Reject the call on the server so the caller gets feedback. Its
    // "rejected" echo is this device's own.
    final epoch = CallsLifecycle.callEpoch;
    final rejectUseCase =
        CallOperationsServiceLocator.instance.rejectCallUseCase;
    ActiveCallTracker.respondingTo(sessionId);
    final Result<Call> rejectResult;
    try {
      rejectResult = await rejectUseCase.call(
        sessionId,
        CallStatusConstants.rejected,
      );
    } finally {
      ActiveCallTracker.doneResponding(sessionId);
    }
    if (epoch != CallsLifecycle.callEpoch) {
      // Logged out meanwhile: the teardown has dealt with this device's
      // calls, and an event or a report now would reach whoever comes next.
      ccLog(
        'IncomingCallBloc: the decline of $sessionId landed after calls were '
        'torn down: ${rejectResult.isSuccess ? 'declined' : 'it failed'}',
      );
      return;
    }
    CometChatException? rejectFailure;
    rejectResult.fold(
      (failure) {
        rejectFailure = callFailureException(failure);
        call.category = MessageCategoryConstants.call;
        CometChatCallEvents.ccCallRejected(call);
      },
      (rejectedCall) {
        rejectedCall.category = MessageCategoryConstants.call;
        CometChatCallEvents.ccCallRejected(rejectedCall);
      },
    );
    // The call is over for this device whether or not the reject landed.
    ActiveCallTracker.release(sessionId);
    // A decline that failed is reported too, after the refusal that
    // caused it, with the SDK's own code, as every other failure is.
    final failedReject = rejectFailure;
    if (failedReject != null) _handleError(failedReject);
    if (isClosed) return;
    _emitError(
      emit,
      message,
      explained: permissions != null,
      keepDisabled: true,
    );
  }

  /// Whether this call was declined here after a refused permission: the
  /// buttons stay off, and Accept and Decline are ignored from then on.
  bool _declined = false;

  /// Tells the user an incoming call could not be answered without its
  /// permissions, in a SnackBar on the app's navigator: the banner is gone
  /// by then, and nothing else said why. With [permanentlyDenied] it offers
  /// the app's settings page, where they can be granted now.
  void _showPermissionNotice({
    required bool isVideoCall,
    required bool permanentlyDenied,
  }) {
    final context = CallNavigationContext.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final translations = Translations.of(context);
    final colors = CometChatThemeHelper.getColorPalette(context);
    final typography = CometChatThemeHelper.getTypography(context);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: colors.error,
        content: Text(
          isVideoCall
              ? translations.cameraAndMicrophoneRequiredToAnswerCall
              : translations.microphoneRequiredToAnswerCall,
          style: TextStyle(
            color: colors.white,
            fontSize: typography.button?.medium?.fontSize,
            fontWeight: typography.button?.medium?.fontWeight,
            fontFamily: typography.button?.medium?.fontFamily,
          ),
        ),
        action: permanentlyDenied
            ? SnackBarAction(
                label: translations.settings,
                textColor: colors.white,
                onPressed: () => unawaited(_openSettings()),
              )
            : null,
      ),
    );
  }

  static Future<void> _openSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      ccLog('IncomingCallBloc: could not open the app settings: $e');
    }
  }

  /// Runs the host's [hook] with the navigator's context, as a side effect:
  /// a [CometChatException] it throws goes to [errorCallback] as it is,
  /// anything else as `HOST_CALLBACK_ERROR`; either way, what follows the
  /// hook goes ahead. A hook that returns a future is not waited for, but
  /// its failure is reported too.
  void _runHostHook(Function(BuildContext, Call)? hook, String name) {
    if (hook == null) return;
    final navigatorContext = CallNavigationContext.navigatorKey.currentContext;
    if (navigatorContext == null) return;
    try {
      final Object? result = hook(navigatorContext, call);
      if (result is Future) {
        unawaited(
          result.then<void>(
            (_) {},
            onError: (Object e) => _handleError(_hostHookException(e, name)),
          ),
        );
      }
    } catch (e) {
      _handleError(_hostHookException(e, name));
    }
  }

  static CometChatException _hostHookException(Object error, String name) {
    if (error is CometChatException) return error;
    return CometChatException(
      CallErrorCodes.hostCallbackError,
      error.toString(),
      'The $name callback threw: $error',
    );
  }

  /// Emits the error state for [message]. [explained]: it needs no generic
  /// "Something went wrong" from the widget (see
  /// [explainedIncomingCallErrors]).
  void _emitError(
    Emitter<IncomingCallState> emit,
    String? message, {
    bool explained = false,
    bool keepDisabled = false,
  }) {
    final next = state.copyWith(
      status: IncomingCallStatus.error,
      isDisabled: keepDisabled,
      errorMessage: message,
    );
    if (explained) explainedIncomingCallErrors[next] = true;
    emit(next);
  }

  /// What the accept of [sessionId] came to, calls still up.
  void _landAccept(
    Result<Call> result,
    String sessionId,
    Emitter<IncomingCallState> emit,
  ) {
    result.fold(
      (failure) {
        final error = callFailureException(failure);
        _handleError(error);

        if (kDebugMode) {
          ccLog('Call could not be accepted: ${failure.message}');
        }

        // No call screen follows: the ringtone gives its audio back.
        _stopSound();
        // Dismiss overlay on accept failure — the call is likely already
        // ended by the remote party. This call's banner only.
        IncomingCallOverlay.dismiss(sessionId: sessionId);
        ActiveCallTracker.release(sessionId);

        // A call that was already over (cancelled while the socket was down
        // during the prompt, say) needs no "Something went wrong".
        _emitError(emit, failure.message, explained: isCallAlreadyOver(error));
      },
      (acceptedCall) {
        // The call screen takes the audio over from the ringtone, which
        // lets it go untouched. Before the banner goes: its close stops
        // whatever ringtone this bloc still owns. With no navigator to show
        // the call screen on there is nothing to hand it to: it is given
        // back.
        if (CallNavigationContext.navigatorKey.currentState?.overlay != null) {
          _handOverSound();
        } else {
          _stopSound();
        }

        // Dismiss overlay: this call's banner only.
        IncomingCallOverlay.dismiss(sessionId: sessionId);

        // Fire call accepted event
        CometChatCallEvents.ccCallAccepted(acceptedCall);

        // Determine if audio only.
        // Log both values to diagnose cross-version type mismatches.
        ccLog(
          'IncomingCallBloc: call.type="${call.type}", '
          'acceptedCall.type="${acceptedCall.type}", '
          'sessionId="$sessionId", acceptedCall.sessionId="${acceptedCall.sessionId}"',
        );

        // Check both the original incoming call and the accepted call.
        // For cross-version calls (V4→V5), the type field may be set
        // differently. Treat as video ONLY if explicitly marked as video.
        final bool isVideoCall =
            call.type == CallTypeConstants.videoCall ||
            acceptedCall.type == CallTypeConstants.videoCall;

        // The call's settings: the host's with the call's type applied on
        // top (the host's builder is left as it was), or the kit's own (a
        // voice call on the earpiece, a video call on the loudspeaker).
        final SessionSettingsBuilder sessionSettings =
            CallSessionSettings.forCall(
              isVideo: isVideoCall,
              hostBuilder: callSettingsBuilder,
            );

        // Navigate to ongoing call screen via isolated overlay
        ccLog(
          'IncomingCallBloc: showing CallScreenOverlay with sessionId=$sessionId',
        );
        // The call screen reports to the same onError: a join that fails,
        // or no navigator to show it on, is this call failing.
        CallScreenOverlay.show(
          sessionId: sessionId,
          sessionSettingsBuilder: sessionSettings,
          callWorkFlow: CallWorkFlow.defaultCalling,
          onError: errorCallback,
        );

        if (kDebugMode) {
          ccLog('Call has been accepted successfully');
        }

        emit(
          state.copyWith(
            status: IncomingCallStatus.accepted,
            isDisabled: false,
          ),
        );
      },
    );
  }

  /// The accept of [sessionId] landed after the call was given up here (it
  /// was cancelled, or ended for this device, while the request was on its
  /// way). The bloc already reads cancelled and its banner is gone, so no
  /// call screen is opened: it used to open anyway, for a call this device
  /// had let go, with nothing left to end it from the banner's side.
  ///
  /// An accept that went through left the call live on the server, so it
  /// is ended, best effort, and the caller is not left alone in it. One that
  /// failed is reported, as every failure is, and nothing more.
  Future<void> _landAfterGivingUp(Result<Call> result, String sessionId) async {
    _stopSound();
    ActiveCallTracker.ringingEnded(sessionId);
    if (result is Failure) {
      _handleError(callFailureException(result));
      return;
    }
    ccLog('IncomingCallBloc: $sessionId accepted after it was given up here');
    final ended = await CallOperationsServiceLocator.instance.endCallUseCase
        .call(sessionId);
    ended.fold(
      (failure) => ccLog(
        'IncomingCallBloc: ending $sessionId failed: ${failure.message}',
      ),
      (_) {},
    );
  }

  /// The accept of [sessionId] landed after a logout (or a stop of call
  /// handling) began: this device has moved on. No call screen is opened and
  /// the record is released.
  ///
  /// An accept that went through left the call live on the server, so it is
  /// ended, best effort, so the caller is not left alone in it. The logout
  /// waits for this (within its bound), so it goes out while the user can
  /// still be heard; after the chat logout it simply fails, and is logged.
  /// Not when another user has logged in meanwhile ([uid] is who accepted):
  /// it would go out as them.
  ///
  /// An accept that failed is not reported: the calls were torn down, which
  /// is why (the logout may have declined this very call).
  Future<void> _landAfterTeardown(
    Result<Call> result,
    String sessionId,
    String? uid,
    Emitter<IncomingCallState> emit,
  ) async {
    _stopSound();
    ActiveCallTracker.release(sessionId);
    if (result is Success<Call>) {
      ccLog('IncomingCallBloc: $sessionId accepted after calls were torn down');
      final now = CallsLifecycle.uid;
      if (now != null && now != uid) {
        ccLog('IncomingCallBloc: $now is logged in now; not ending $sessionId');
      } else {
        final ended = await CallOperationsServiceLocator.instance.endCallUseCase
            .call(sessionId);
        ended.fold(
          (failure) => ccLog(
            'IncomingCallBloc: ending $sessionId failed: ${failure.message}',
          ),
          (_) {},
        );
      }
    } else if (result is Failure) {
      ccLog(
        'IncomingCallBloc: accept of $sessionId failed after calls were '
        'torn down: ${result.message}',
      );
    }
    if (!isClosed) {
      emit(
        state.copyWith(
          status: IncomingCallStatus.error,
          isDisabled: false,
          errorMessage: 'The call ended: calls were stopped.',
        ),
      );
    }
  }

  /// Handle reject call event.
  ///
  /// Uses a [Completer] to bridge the callback-based [CometChatUIKitCalls.rejectCall]
  /// so that [emit] stays within the handler scope.
  Future<void> _onRejectCall(
    RejectCall event,
    Emitter<IncomingCallState> emit,
  ) async {
    // The first tap wins: a decline after an accept (the accept may be on
    // its way to the server) or after the call ended is ignored.
    if (_alreadyActedOn) {
      ccLog(
        'IncomingCallBloc: ignoring RejectCall — status is ${state.status}',
      );
      return;
    }

    // Update state to rejecting
    emit(
      state.copyWith(status: IncomingCallStatus.rejecting, isDisabled: true),
    );

    // Ringing ends at the tap, and the audio goes back.
    _stopRingTimeout();
    _stopSound();
    await _decline(emit);
  }

  Future<void> _decline(Emitter<IncomingCallState> emit) async {
    // The host's hook is a side effect, as onAccept's.
    _runHostHook(onDecline, 'onDecline');

    // Get session ID
    final String? sessionId = call.sessionId;
    if (sessionId == null) {
      emit(
        state.copyWith(
          status: IncomingCallStatus.error,
          isDisabled: false,
          errorMessage: 'Session ID is null',
        ),
      );
      return;
    }

    // Reject call via use case. Its "rejected" echo is this device's own.
    ccLog('Trying to reject call');
    final rejectCallUseCase =
        CallOperationsServiceLocator.instance.rejectCallUseCase;
    ActiveCallTracker.respondingTo(sessionId);
    final Result<Call> result;
    try {
      result = await rejectCallUseCase.call(
        sessionId,
        CallStatusConstants.rejected,
      );
    } finally {
      ActiveCallTracker.doneResponding(sessionId);
    }

    result.fold(
      (failure) {
        ccLog('Unable to reject call from incoming call screen');

        // Announce the rejection anyway, as Kotlin does on a failed reject.
        // The user declined and the screen is going away either way; without
        // the event, everything that cleans up on it — the local active call,
        // the call buttons, the chat's call bubble — stayed as if the call
        // were still ringing.
        call.category = MessageCategoryConstants.call;
        CometChatCallEvents.ccCallRejected(call);

        final error = callFailureException(failure);
        _handleError(error);

        // Still dismiss overlay on error: this call's banner only.
        IncomingCallOverlay.dismiss(sessionId: sessionId);

        // A call that was already over needs no "Something went wrong".
        _emitError(emit, failure.message, explained: isCallAlreadyOver(error));
      },
      (rejectedCall) {
        rejectedCall.category = MessageCategoryConstants.call;
        CometChatCallEvents.ccCallRejected(rejectedCall);
        ccLog('Incoming call was rejected');

        // Dismiss overlay: this call's banner only.
        IncomingCallOverlay.dismiss(sessionId: sessionId);

        emit(
          state.copyWith(
            status: IncomingCallStatus.rejected,
            isDisabled: false,
          ),
        );
      },
    );
  }

  /// The call stopped ringing for this device without being answered or
  /// declined here: the caller cancelled it or gave up, the same user
  /// answered or declined it on another device, or it rang out
  /// ([ActiveCallTracker.incomingRingTimeout]). The ringtone stops even when
  /// this bloc is shown somewhere other than the banner (a host's own
  /// screen), where the dismiss below does nothing.
  ///
  /// Only the ringing record is released, and the call is remembered as
  /// finished: the active call is never touched. A call answered outside
  /// this bloc (CallKit, a host's own accept) is the active one by then, and
  /// its own "ongoing" echo, taken here for an answer elsewhere, used to
  /// clear it mid-call.
  Future<void> _onCallCancelled(
    CallCancelled event,
    Emitter<IncomingCallState> emit,
  ) async {
    _stopRingTimeout();
    _stopSound();
    emit(state.copyWith(status: IncomingCallStatus.cancelled));

    final sessionId = call.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      // No session to tell this call's banner from another's: an unscoped
      // dismiss and release took down whatever call was up, and cleared
      // every record. Only a record that holds this very call goes.
      ActiveCallTracker.releaseCall(call);
      return;
    }
    // Dismiss overlay — this call's, not whatever may have replaced it.
    IncomingCallOverlay.dismiss(sessionId: sessionId);
    ActiveCallTracker.ringingEnded(sessionId);
  }

  /// Hands [e] to [errorCallback], if provided. A callback that throws is
  /// only logged: it must not stop what follows the report (the banner
  /// dismissed, the state emitted).
  void _handleError(CometChatException e) =>
      reportCallError(errorCallback, e, where: 'IncomingCallBloc');

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Get subtitle text based on call type: a video call only when the call
  /// says so, as for the banner's icon and the permissions asked at accept.
  /// A call with no type (a cross-version call, say) used to read as a video
  /// call next to a phone icon, and was answered as a voice call.
  String getSubtitle(BuildContext context) {
    return call.type == CallTypeConstants.videoCall
        ? Translations.of(context).incomingVideoCall
        : Translations.of(context).incomingAudioCall;
  }

  @override
  Future<void> close() {
    // The banner went away without this call being answered: however it was
    // taken down (the host, a replacing banner, a logout), the call can no
    // longer be answered here, so it stops counting as ringing and the next
    // incoming call is not answered busy because of it. Only the ringing
    // record, and only this call's: an accept in flight or done turns it into
    // the active call, which must stay. Nothing goes to the server.
    //
    // Not while another banner shows this same call (it was shown again,
    // replacing this one): that banner still rings for it.
    if (state.status != IncomingCallStatus.accepting &&
        state.status != IncomingCallStatus.accepted &&
        ActiveCallTracker.incomingCallSessionId != call.sessionId) {
      ActiveCallTracker.releaseRinging(call.sessionId);
    }

    // Update CallStateService: no incoming call any more, unless a banner
    // still shows one. A banner replaced by another is closed after the new
    // one set the flag, and used to clear it while the new call rang.
    if (ActiveCallTracker.incomingCallSessionId == null) {
      CallStateService.instance.setActiveIncomingValue(false);
    }

    // Remove SDK listener
    CometChat.removeCallListener(_listenerId);

    _stopRingTimeout();
    _lifecycle?.dispose();
    _lifecycle = null;
    // Stop sound playback. Not during an accept: it carries on without the
    // banner (a host's onAccept may take it down), and ends the paused
    // ringtone itself, handing its audio to the call screen or giving it
    // back. A full stop here let music resume during "Connecting...".
    if (state.status != IncomingCallStatus.accepting) _stopSound();

    return super.close();
  }
}
