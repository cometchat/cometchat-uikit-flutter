import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../cometchat_calls_uikit.dart';
import '../../../../cometchat_chat_uikit.dart';
import '../../../../shared_ui/src/logging/cometchat_log.dart';
import '../../../../src/active_call_tracker.dart';
import '../../../../src/call_errors.dart';
import '../../../../src/call_permission_check.dart';
import '../../../../src/call_session_settings.dart';
import '../../../../src/call_tone.dart';
import '../../../../src/calls_lifecycle.dart';

/// BLoC for managing outgoing call screen state and actions
///
/// This BLoC handles:
/// - Sound playback on initialization (unless disabled)
/// - Cancel call action (calls SDK with cancelled status)
/// - Outgoing call accepted handling (navigates to OngoingCall)
/// - Outgoing call rejected handling (pops screen)
/// - CallStateService updates on init and close
///
/// Closing it while its call still rings (not answered, declined, cancelled
/// or handed to the host's own cancel) sends `rejectCall` with status
/// `cancelled`, so the callee stops ringing, and releases the call's record;
/// a failed cancel reaches [errorCallback]. The widget closes its own bloc
/// when it is disposed.
///
/// A call still ringing 45 seconds after it was placed is given up:
/// `rejectCall` with status `unanswered`, then the screen closes. Once End
/// was tapped or that happened, an accept for the call is not joined, and a
/// best-effort `endCall` tries to free the callee, as it does when that
/// cancel or reject fails (not when the cancel of a screen that went away
/// fails). After End the screen closes when the server answers, or after
/// 10 seconds at most. Once a logout has begun, nothing more is sent for
/// the call and nothing reaches [errorCallback]: the logout ends it.
///
/// Uses [CometChatCallEventListener] and [CallListener] mixins for SDK events
///
/// Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7
class OutgoingCallBloc extends Bloc<OutgoingCallEvent, OutgoingCallState>
    with CometChatCallEventListener, CallListener {
  /// The active outgoing call
  final Call call;

  /// User being called (optional, for display purposes)
  final User? user;

  /// Custom session settings builder (V5)
  final SessionSettingsBuilder? callSettingsBuilder;

  /// Called when End is tapped, instead of the UI Kit's own cancel (the
  /// screen's `onCancelled`): the host then cancels the call and owns the
  /// ringback, which it can stop with `CometChatUIKit.soundManager.stop()`.
  /// End stays live, and the 45 s no-answer timeout still runs.
  final Function(BuildContext, Call)? onCancelledCallTap;

  /// Whether to disable sound for calls
  final bool? disableSoundForCalls;

  /// Custom sound asset for calls
  final String? customSoundForCalls;

  /// Package name for custom sound asset
  final String? customSoundForCallsPackage;

  /// Error callback
  final OnError? errorCallback;

  /// Unique listener ID for SDK listeners
  late final String _listenerId;

  /// Creates an OutgoingCallBloc
  ///
  /// [call] is required and represents the active outgoing call.
  /// Sound playback starts on init unless [disableSoundForCalls] is true.
  OutgoingCallBloc({
    required this.call,
    this.user,
    this.callSettingsBuilder,
    this.onCancelledCallTap,
    this.disableSoundForCalls,
    this.customSoundForCalls,
    this.customSoundForCallsPackage,
    this.errorCallback,
  }) : super(const OutgoingCallState()) {
    // Generate unique listener ID
    _listenerId =
        'outgoingCall_${DateTime.now().microsecondsSinceEpoch.toString()}';

    // Register event handlers
    on<CancelCall>(_onCancelCall);
    on<OutgoingCallAccepted>(_onOutgoingCallAccepted);
    on<OutgoingCallRejected>(_onOutgoingCallRejected);
    on<_NoAnswer>(_onNoAnswer);

    // Initialize
    _initialize();
  }

  /// [CallsLifecycle.callEpoch] when this screen opened. A logout or stop
  /// since then owns the server side of this call.
  final int _epoch = CallsLifecycle.callEpoch;

  /// Whether this device's calls were torn down since this screen opened,
  /// or a logout is tearing them down now: that teardown owns the server
  /// side of this call (it cancels a call still ringing). Nothing more is
  /// sent for it from here, and nothing reaches onError: a request would go
  /// out as a user on their way out, or as the next one.
  bool get _tornDown =>
      _epoch != CallsLifecycle.callEpoch || CallsLifecycle.isPreparingLogout;

  /// Initialize the BLoC - add listeners, update call state, play sound
  void _initialize() {
    // Update CallStateService to track active outgoing call
    CallStateService.instance.setActiveOutgoingValue(true);

    // So a logout can cancel this call while the user can still be heard,
    // and close this screen.
    ActiveCallTracker.outgoingScreenOpened(
      this,
      OutgoingCallScreen(
        call: call,
        isRinging: () => !_screenClosed && _isRinging,
        closeLocally: () => _popScreen(fallBackToAppNavigator: false),
        screenGone: _screenGone,
      ),
    );

    // Add SDK listeners for call events
    CometChat.addCallListener(_listenerId, this);
    CometChatCallEvents.addCallEventsListener(_listenerId, this);

    // Play outgoing call sound unless disabled
    if (disableSoundForCalls != true) {
      _playOutgoingSound();
    }

    // Nothing else ends a call nobody answers: see _onNoAnswer. Counted
    // from the placement: an app in the background builds this screen only
    // once it comes back, and a call placed long enough before is given up
    // at once.
    final timeout = ActiveCallTracker.outgoingCallTimeout;
    if (timeout != null) {
      final remaining = ActiveCallTracker.remainingOf(call, timeout);
      _noAnswerTimer = Timer(remaining, () {
        _noAnswerTimer = null;
        if (!isClosed) add(const _NoAnswer());
      });
    }
  }

  /// Gives up on the call once it has rung for
  /// [ActiveCallTracker.outgoingCallTimeout] (45 s); cancelled when ringing
  /// ends ([_stopRinging]).
  Timer? _noAnswerTimer;

  /// Plays the ringback: a ringback that cannot play must not stop the
  /// call. CallTone itself never throws; the guard is for reading the call
  /// (a `Call` whose getters throw, such as a test fake, failed the screen
  /// as it opened).
  void _playOutgoingSound() {
    try {
      unawaited(
        CallTone.play(
          assetPath: customSoundForCalls,
          package: customSoundForCallsPackage,
          isVideo: call.type == CallTypeConstants.videoCall,
          owner: this,
        ),
      );
      ccLog('Outgoing call sound playing');
    } catch (e) {
      ccLog('Failed to play outgoing call sound: $e');
    }
  }

  /// Ringing is over for this screen: the ringback and the no-answer timer
  /// stop now, and the audio the ringback set up is given back.
  ///
  /// It used to stop only in [close], once the route was disposed after its
  /// pop animation, so it went on through the permission prompt after an
  /// accept and through a slow cancel. Android pauses its sound first in
  /// both places (round 2, P2-C06). [close] still stops it, for any path
  /// that does not come through here. The accept stops only the playback:
  /// see [_onOutgoingCallAccepted].
  void _stopRinging() {
    _noAnswerTimer?.cancel();
    _noAnswerTimer = null;
    if (disableSoundForCalls != true) _stopSound();
  }

  /// Stops the ringback and gives its audio back, when it is still the one
  /// this bloc started: a screen that closes a moment after its call ended
  /// must not silence the next call's ringback (round 2, P3-C15). After the
  /// hand-over to the call screen the tone is no longer this bloc's, so
  /// this does nothing.
  void _stopSound() => unawaited(CallTone.stop(owner: this));

  // ============================================================
  // SDK LISTENER CALLBACKS - CallListener & CometChatCallEventListener
  // ============================================================

  /// Called when the outgoing call is accepted by the receiver — for this
  /// call only: both sessions known and the same.
  @override
  void onOutgoingCallAccepted(Call accepted) {
    if (!_isThisCall(accepted)) return;
    add(OutgoingCallAccepted(accepted));
  }

  /// Called when the outgoing call is rejected by the receiver — for this
  /// call only: both sessions known and the same.
  @override
  void onOutgoingCallRejected(Call rejected) {
    if (!_isThisCall(rejected)) return;
    add(OutgoingCallRejected(rejected));
  }

  /// Whether an SDK callback is about this screen's call: both sessions are
  /// known and the same.
  ///
  /// The chat SDK hands these callbacks to every call listener, and routes
  /// them by who performed the action. The echo of this device's own busy
  /// reply to a third caller arrives as onOutgoingCallRejected, and a call
  /// the same user answered on another device as onOutgoingCallAccepted.
  /// Either used to close this screen and release this call's record, or
  /// join a session that was not this one (round 2, P2-C05).
  bool _isThisCall(Call other) {
    final ours = call.sessionId;
    return ours != null && ours.isNotEmpty && other.sessionId == ours;
  }

  /// Called when the server ends a call — it went unanswered, the callee was
  /// busy, or the system terminated it.
  ///
  /// None of those arrive as a rejection, so nothing closed this screen and
  /// the caller was left on "Calling…" for a call that no longer existed.
  /// Kotlin's outgoing ViewModel handles this callback; this matches it,
  /// including the session check — the SDK broadcasts it to every listener,
  /// and an unrelated call ending must not close this one.
  @override
  void onCallEndedMessageReceived(Call endedCall) {
    if (!_isThisCall(endedCall)) return;
    add(OutgoingCallRejected(endedCall));
  }

  /// Called with the callee's decline or busy, as the chat SDK delivers them.
  ///
  /// The SDK takes a realtime call's callInitiator from whoever performed the
  /// action — on a decline, the callee — so its dispatch decides the caller is
  /// not the initiator and sends the decline here instead of to
  /// [onOutgoingCallRejected]. Nothing closed the screen, and the caller sat
  /// on "Calling…" until they tapped End. The Android SDK always delivers a
  /// 1-on-1 decline as a rejection; treating one for this session as a
  /// rejection matches it.
  ///
  /// Once End or the no-answer timeout is on its way, our own `cancelled`
  /// or `unanswered` comes back here as well, and is skipped; so is
  /// anything once the call was answered, since it has moved on. The
  /// callee's decline or busy that crossed End still closes the screen at
  /// once: it used to be skipped too, and the screen then waited up to
  /// 10 s for the cancel's answer, a failure, and sent an endCall for a
  /// callee who was not in the call.
  @override
  void onIncomingCallCancelled(Call cancelledCall) {
    if (!_isThisCall(cancelledCall) || _screenClosed) return;
    if (state.isCallRejected) {
      final status = cancelledCall.callStatus;
      final declined =
          status == CallStatusConstants.rejected ||
          status == CallStatusConstants.busy;
      if (!declined || state.status != OutgoingCallStatus.cancelling) return;
    }
    add(OutgoingCallRejected(cancelledCall));
  }

  // ============================================================
  // EVENT HANDLERS
  // ============================================================

  /// Handle cancel call event
  Future<void> _onCancelCall(
    CancelCall event,
    Emitter<OutgoingCallState> emit,
  ) async {
    // Nothing to cancel once the call is over or being handed off: the callee
    // declined, it was accepted, a cancel is already in flight, or the screen
    // is closing. Cancelling then asks the server to cancel a call that is
    // already finished, which fails — that failure was the "Something went
    // wrong" in ENG-39486.
    if (state.isCallRejected ||
        _screenClosed ||
        state.status == OutgoingCallStatus.cancelling ||
        state.status == OutgoingCallStatus.rejected ||
        state.status == OutgoingCallStatus.accepted) {
      return;
    }

    // Execute custom onCancelledCallTap callback if provided
    if (onCancelledCallTap != null) {
      try {
        final navigatorContext =
            CallNavigationContext.navigatorKey.currentContext;
        if (navigatorContext != null) {
          // The host cancels the call itself, so closing this screen later
          // must not send a second cancel.
          _hostHandlesCancel = true;
          onCancelledCallTap!(navigatorContext, call);
          return; // Custom handler takes over
        }
      } catch (e) {
        ccLog('Error in onCancelledCallTap: $e');
      }
    }

    // The kit's own cancel. Use 'cancelled' so the callee gets
    // onIncomingCallCancelled and takes its banner down: 'rejected' left it
    // up, the server treating it as the callee's own decline.
    //
    // Historical note: 'rejected' was used as a workaround for a V4 race
    // condition where cancelCall() checked getActiveCall() which could be
    // null. The V5 SDK's rejectCall with 'cancelled' status works correctly.
    //
    // A host onCancelledCallTap that took over above owns the ringback and
    // the cancel instead.
    await _endRinging(CallStatusConstants.cancelled, emit);
  }

  /// Nobody answered in [ActiveCallTracker.outgoingCallTimeout].
  ///
  /// The Dart SDK has no caller-side timer, so an unanswered call used to
  /// ring until the caller tapped End. Android's SDK sends `unanswered`
  /// after its timeout, which comes back as a rejection and closes the
  /// screen (round 2, P2-C07): this sends the same, then closes.
  ///
  /// Also after a host's onCancelledCallTap took End over but left the call
  /// ringing: the call is still unanswered.
  Future<void> _onNoAnswer(
    _NoAnswer event,
    Emitter<OutgoingCallState> emit,
  ) async {
    if (_screenClosed ||
        state.isCallRejected ||
        state.status != OutgoingCallStatus.idle) {
      return;
    }
    // A logout is cancelling the call (or has): an `unanswered` now would be
    // a second request for it, and its failure would reach onError after
    // the logout.
    if (_tornDown) {
      ccLog(
        'OutgoingCallBloc: ${call.sessionId} not answered while calls are '
        'torn down; the teardown ends it',
      );
      return;
    }
    ccLog('OutgoingCallBloc: ${call.sessionId} was not answered; giving up');
    await _endRinging(CallStatusConstants.unanswered, emit);
  }

  /// The caller gives up on the call while it rings — End, or the no-answer
  /// timer: stops ringing, turns End off, sends [status] (`cancelled` or
  /// `unanswered`) and closes the screen.
  ///
  /// On success the call's rejection is announced (ccCallRejected). A
  /// failure reaches onError with the SDK's code, and a best-effort endCall
  /// goes out ([_freeCallee]): the request most often fails because the
  /// callee answered at that very moment, and would be left alone in the
  /// call. By the time any other failure comes the call is usually over
  /// already: master_app shows these to nobody.
  ///
  /// From here on an accept is not joined: End wins ([_endRequested]).
  ///
  /// The screen closes when the server answers, or after
  /// [ActiveCallTracker.outgoingEndCloseAfter] (10 s) at most: a slow
  /// network kept the caller on a dead screen for as long as the SDK
  /// retried. The request carries on; what it comes to is still handled as
  /// above, onError included (owner decision: report everything).
  Future<void> _endRinging(
    String status,
    Emitter<OutgoingCallState> emit,
  ) async {
    _stopRinging();
    emit(
      state.copyWith(
        status: OutgoingCallStatus.cancelling,
        isCallRejected: true,
      ),
    );
    final sessionId = call.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      emit(
        state.copyWith(
          status: OutgoingCallStatus.error,
          isCallRejected: false,
          errorMessage: 'Session ID is null',
        ),
      );
      return;
    }
    _endRequested = true;
    _closeCap?.cancel();
    _closeCap = Timer(ActiveCallTracker.outgoingEndCloseAfter, () {
      _closeCap = null;
      ccLog(
        'OutgoingCallBloc: no answer to the $status of $sessionId yet; '
        'closing, the request carries on',
      );
      _popScreen();
    });

    final result = await CallOperationsServiceLocator.instance.rejectCallUseCase
        .call(sessionId, status);
    _closeCap?.cancel();
    _closeCap = null;

    // isCallRejected stays true on both outcomes: the screen is closing, and
    // re-enabling End here let a second tap fire another cancel.
    result.fold(
      (failure) {
        ccLog(
          'OutgoingCallBloc: $status of $sessionId failed: ${failure.message}',
        );
        // Landed after a logout began (a slow network retries for up to a
        // minute): the logout owns the call now; this is only logged.
        if (_tornDown) return;
        _freeCallee(sessionId);
        _handleError(callFailureException(failure));
      },
      (rejectedCall) {
        rejectedCall.category = MessageCategoryConstants.call;
        CometChatCallEvents.ccCallRejected(rejectedCall);
      },
    );
    emit(
      state.copyWith(status: OutgoingCallStatus.rejected, isCallRejected: true),
    );
    _popScreen();
  }

  /// Set once End was tapped or the no-answer timer fired: the caller has
  /// given up on the call, so an accept that arrives now is not joined
  /// (owner decision: End wins).
  bool _endRequested = false;

  /// Closes the screen if the server has not answered a cancel in time.
  Timer? _closeCap;

  /// Set once a best-effort endCall has gone out for this call, or the call
  /// ended in a way that leaves nobody to free (declined, busy, ended by the
  /// server).
  bool _calleeFreed = false;

  /// Sends a best-effort `endCall` for [sessionId], once: the callee may
  /// have answered a call this device is giving up on, and would otherwise
  /// sit alone in it. A call that is not in progress just fails to end,
  /// which is only logged.
  void _freeCallee(String sessionId) {
    if (_calleeFreed) return;
    _calleeFreed = true;
    unawaited(_endCallBestEffort(sessionId));
  }

  static Future<void> _endCallBestEffort(String sessionId) async {
    try {
      final result = await CallOperationsServiceLocator.instance.endCallUseCase
          .call(sessionId);
      result.fold(
        (failure) => ccLog(
          'OutgoingCallBloc: best-effort end of $sessionId: ${failure.message}',
        ),
        (endedCall) {
          endedCall.category = MessageCategoryConstants.call;
          CometChatCallEvents.ccCallEnded(endedCall);
        },
      );
    } catch (e) {
      ccLog('OutgoingCallBloc: best-effort end of $sessionId: $e');
    }
  }

  /// Handle outgoing call accepted event
  Future<void> _onOutgoingCallAccepted(
    OutgoingCallAccepted event,
    Emitter<OutgoingCallState> emit,
  ) async {
    // The same accept twice (the handlers run concurrently): the first is
    // already joining, and a second would ask for permissions again and
    // open a second call screen.
    if (state.status == OutgoingCallStatus.accepted) return;

    // End wins (owner decision): once End was tapped or the no-answer timer
    // fired, the call is not joined, even while that cancel is still on its
    // way. The callee, who has just answered, would be left alone in the
    // call: a best-effort endCall lets them go. (Android joins here.)
    if (_endRequested) {
      // After a logout began, the logout owns the call: nothing is sent.
      if (_tornDown) {
        ccLog(
          'OutgoingCallBloc: accepted after the caller gave up and calls '
          'were torn down; left to the teardown',
        );
        return;
      }
      ccLog('OutgoingCallBloc: accepted after the caller gave up; ending it');
      final sessionId = call.sessionId;
      if (sessionId != null && sessionId.isNotEmpty) _freeCallee(sessionId);
      return;
    }

    // The screen is gone (a logout closed it, say); don't open a call screen
    // for a call nobody is waiting on.
    if (_screenClosed) return;

    // A logout is ending this device's calls: it has cancelled this one, so
    // the call is not joined. The screen closes now rather than when the
    // logout takes the call screens down.
    if (_tornDown) {
      ccLog('OutgoingCallBloc: accepted while calls are torn down; not joined');
      _popScreen();
      return;
    }

    // Before the permission prompt, which can stay up a while: the ringback
    // stops, and so does the no-answer timer. Only the playback stops: the
    // audio stays set up for a call (the iOS session, the Android route and
    // focus) until the call screen takes it over below, so the user's music
    // does not come back in between. Every way out of here that opens no
    // call screen closes the screen, which gives the audio back.
    _noAnswerTimer?.cancel();
    _noAnswerTimer = null;
    final Future<void> ringbackPaused = disableSoundForCalls == true
        ? Future<void>.value()
        : CallTone.pause(owner: this);

    // End goes dead as soon as the call is accepted, as in Kotlin: the
    // permission prompt below can take a while, and cancelling an accepted
    // call from here fails.
    emit(
      state.copyWith(status: OutgoingCallStatus.accepted, isCallRejected: true),
    );

    // Request permissions before navigating to the ongoing call screen.
    // OngoingCallBloc no longer requests them to avoid race conditions.
    final isVideoCall = event.call.type == CallTypeConstants.videoCall;
    final CallPermissionOutcome permissions;
    try {
      permissions = await CallPermissionCheck.request(isVideoCall: isVideoCall);
    } catch (e, stackTrace) {
      // The permission plugin refusing (a request already running, say).
      // Left to escape, it stranded the caller: End dead, no call screen,
      // the record held and onError never told.
      ccLog('OutgoingCallBloc: asking for permissions failed: $e\n$stackTrace');
      final wasOpen = !isClosed && !_screenClosed;
      _popScreen();
      if (wasOpen && !_tornDown) _handleError(callExceptionFrom(e));
      return;
    }
    // Closed meanwhile, by the user, the host or a logout: no call screen.
    if (isClosed || _screenClosed) return;
    // A logout began during the prompt: as above.
    if (_tornDown) {
      _popScreen();
      return;
    }
    if (!permissions.isGranted) {
      ccLog('OutgoingCallBloc: permissions denied, cannot join call');
      // As on Android: the call is over for this device, so closing the
      // screen releases its record, and onError hears why. Nothing is sent
      // to the server; the callee's side ends when nobody joins.
      _popScreen();
      _handleError(
        permissions.toException(
          'Microphone${isVideoCall ? ' and camera' : ''} permission is '
          'required to join the call.',
        ),
      );
      return;
    }

    // The call's settings: the host's with the call's type applied on top
    // (a voice call is an audio session with the camera off, whatever the
    // host's builder says, and the host's builder is left as it was), or
    // the kit's own (a voice call on the earpiece, a video call on the
    // loudspeaker). Video only when the call says so.
    final SessionSettingsBuilder sessionSettings = CallSessionSettings.forCall(
      isVideo: isVideoCall,
      hostBuilder: callSettingsBuilder,
    );

    // The ringback's own audio work is done before the Calls engine starts
    // on the session: on iOS it runs on a queue of its own, and a session
    // change of the tone's landing under the engine cut the call's audio.
    // Bounded: a native side that does not answer must not hold the call.
    await ringbackPaused.timeout(_toneWorkLimit, onTimeout: () {});
    if (isClosed || _screenClosed) return;
    if (_tornDown) {
      _popScreen();
      return;
    }

    // The call screen takes the audio over from the ringback, which lets it
    // go untouched. With no navigator to show the call screen on, there is
    // nothing to hand it to: closing this screen below gives it back.
    if (CallNavigationContext.navigatorKey.currentState?.overlay != null &&
        disableSoundForCalls != true) {
      unawaited(CallTone.handOver(owner: this));
    }

    // Pop the outgoing call screen, then show ongoing call in isolated overlay.
    // The call carries on, so its active-call record stays.
    _popScreen(callOver: false);
    // The call screen reports to the same onError: a join that fails, or no
    // navigator to show it on, is this call failing.
    CallScreenOverlay.show(
      sessionId: event.call.sessionId!,
      sessionSettingsBuilder: sessionSettings,
      callWorkFlow: CallWorkFlow.defaultCalling,
      onError: errorCallback,
    );

    ccLog('Outgoing call was accepted');
  }

  /// Handle outgoing call rejected event
  Future<void> _onOutgoingCallRejected(
    OutgoingCallRejected event,
    Emitter<OutgoingCallState> emit,
  ) async {
    // Disable End as well as closing. The close is a route transition, and
    // End used to stay live for its whole duration — a tap then tried to
    // cancel a call the callee had just declined, the server refused, and the
    // caller got "Something went wrong" (ENG-39486).
    _stopRinging();
    // Declined, busy or ended by the server: nobody is in the call, so a
    // cancel of ours that fails now has no callee to free.
    _calleeFreed = true;
    emit(
      state.copyWith(status: OutgoingCallStatus.rejected, isCallRejected: true),
    );

    // Pop the screen
    _popScreen();

    ccLog('Outgoing call was rejected');
  }

  /// How long an accept waits for the ringback's audio work before the call
  /// screen opens anyway.
  static const Duration _toneWorkLimit = Duration(seconds: 1);

  /// Set once the screen has been closed, so it is never closed twice.
  bool _screenClosed = false;

  /// Set when the host's onCancelledCallTap took the cancel over.
  bool _hostHandlesCancel = false;

  /// Closes the outgoing call screen — once, and only that screen.
  ///
  /// Several paths close it and they can race: the callee declines
  /// (onOutgoingCallRejected) while the caller taps End, and the cancel
  /// closed the screen "regardless of success/error". Each used to call a
  /// bare Navigator.pop on whatever was on top, so the second close popped
  /// the chat screen underneath. Kotlin closes its own Activity, which is
  /// naturally idempotent; this is the equivalent.
  ///
  /// [callOver] is false only when the screen closes because the call was
  /// answered and moves on to the call screen. Every other close — declined,
  /// cancelled, ended by the server, or a failed cancel that emits no event —
  /// releases the local active-call record, which would otherwise make every
  /// later call be refused and every incoming one answered with busy.
  ///
  /// [fallBackToAppNavigator] is false for a teardown from outside (a
  /// logout): a bloc driving a screen it did not build then leaves the app's
  /// navigator alone rather than pop whatever route is on top.
  void _popScreen({bool callOver = true, bool fallBackToAppNavigator = true}) {
    if (_screenClosed) return;
    _screenClosed = true;
    // However it closes (a logout, say), the screen rings no more.
    _stopRinging();
    if (callOver) {
      ActiveCallTracker.release(call.sessionId);
    }

    // The widget records its own route in ActiveCallTracker; null when the
    // bloc drives a screen it did not build.
    final route = ActiveCallTracker.outgoingCallRouteOf(this);
    if (route != null) {
      final navigator = route.navigator;
      if (navigator != null) {
        if (route.isCurrent) {
          navigator.pop();
        } else if (route.isActive) {
          // Something was pushed on top (e.g. a dialog); remove just our
          // screen.
          navigator.removeRoute(route);
        }
      }
      // A route that has gone already (the host popped it, a bloc of the
      // host's outliving its screen) leaves nothing to close. Popping the
      // app's navigator instead took the host's own screen down (round 2
      // review).
      return;
    }

    // No route handed over — the bloc is driving a screen it did not build.
    if (!fallBackToAppNavigator) return;
    final navigatorContext = CallNavigationContext.navigatorKey.currentContext;
    if (navigatorContext != null && navigatorContext.mounted) {
      Navigator.pop(navigatorContext);
    }
  }

  /// The screen's widget was disposed while this bloc, which the host handed
  /// it, stays open (the widget closes only a bloc of its own).
  ///
  /// Nothing is left on screen: the ringback stops and the no-answer timer
  /// with it. That timer, left running, sent `unanswered` 45 s later for a
  /// call a host's onCancelled had already ended. The record and the server
  /// side stay as they are until the host closes the bloc ([close]).
  void _screenGone() {
    if (_screenClosed) return;
    ccLog(
      'OutgoingCallBloc: the screen of ${call.sessionId} went; its bloc '
      'stays open',
    );
    _stopRinging();
  }

  /// Hands [e] to [errorCallback], if provided. A callback that throws is
  /// only logged: it must not stop what follows the report.
  void _handleError(CometChatException e) =>
      reportCallError(errorCallback, e, where: 'OutgoingCallBloc');

  /// The screen went away without this bloc closing it: the host removed
  /// the route (a `pushAndRemoveUntil`, say) or disposed the widget.
  ///
  /// The call's record is released, so the device is not left "in a call"
  /// with nothing on screen. If the call was still ringing — not answered,
  /// declined, cancelled or handed to the host's own cancel — it is
  /// cancelled on the server too, so the callee stops ringing for a caller
  /// who is gone (owner decision). A failed cancel reaches onError like any
  /// other. An answered call is not ended: the owner chose Android's rule of
  /// never ending a call the user did not hang up.
  ///
  /// When a logout or a stop of call handling came in between, it has dealt
  /// with the server side already (or can no longer): nothing is sent.
  void _screenLost() {
    _screenClosed = true;
    final sessionId = call.sessionId;
    ActiveCallTracker.releaseCall(call);
    if (!_isRinging || sessionId == null || sessionId.isEmpty) return;
    if (_tornDown) return;
    ccLog('OutgoingCallBloc: screen closed while $sessionId rang; cancelling');
    unawaited(_cancelLostCall(sessionId));
  }

  /// Whether the call is still ringing on the callee's side as far as this
  /// screen knows: not answered, declined, cancelled, or handed to the
  /// host's own cancel.
  bool get _isRinging =>
      !state.isCallRejected &&
      !_hostHandlesCancel &&
      state.status != OutgoingCallStatus.cancelling &&
      state.status != OutgoingCallStatus.rejected &&
      state.status != OutgoingCallStatus.accepted;

  /// Cancels the call of a screen that went away while it rang.
  ///
  /// A failure only reaches onError. No endCall follows it, even though the
  /// cancel most often fails because the callee answered at that moment:
  /// nobody on this device hung up, and the owner kept Android's rule of
  /// never ending a call the user did not end (unlike End and the no-answer
  /// timeout, see [_endRinging]).
  Future<void> _cancelLostCall(String sessionId) async {
    final result = await CallOperationsServiceLocator.instance.rejectCallUseCase
        .call(sessionId, CallStatusConstants.cancelled);
    result.fold(
      (failure) {
        ccLog(
          'OutgoingCallBloc: cancel of $sessionId failed: ${failure.message}',
        );
        if (_tornDown) return;
        _handleError(callFailureException(failure));
      },
      (cancelledCall) {
        cancelledCall.category = MessageCategoryConstants.call;
        CometChatCallEvents.ccCallRejected(cancelledCall);
      },
    );
  }

  @override
  Future<void> close() {
    _noAnswerTimer?.cancel();
    _noAnswerTimer = null;
    _closeCap?.cancel();
    _closeCap = null;
    ActiveCallTracker.outgoingScreenClosed(this);
    if (!_screenClosed) _screenLost();

    // Update CallStateService
    CallStateService.instance.setActiveOutgoingValue(false);

    // Remove SDK listeners
    CometChat.removeCallListener(_listenerId);
    CometChatCallEvents.removeCallEventsListener(_listenerId);

    // Stop sound playback
    if (disableSoundForCalls != true) {
      _stopSound();
    }

    ccLog('OutgoingCallBloc closed');

    return super.close();
  }
}

/// Nobody answered in time: see `OutgoingCallBloc._onNoAnswer`. Private, so
/// no public event is added for it.
final class _NoAnswer extends OutgoingCallEvent {
  const _NoAnswer();
}
