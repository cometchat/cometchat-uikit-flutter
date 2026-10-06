import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../cometchat_calls_uikit.dart';
import '../../../../cometchat_chat_uikit.dart';
import '../../../../shared_ui/src/logging/cometchat_log.dart';
import '../../../../src/active_call_tracker.dart';
import '../../../../src/call_errors.dart';
import '../../../../src/call_permission_check.dart';
import '../../../../src/calling_configuration_resolver.dart';
import '../../../../src/calls_lifecycle.dart';
import '../../../../src/calls_sdk_session.dart';
import '../../../../src/meeting_session_settings.dart';
import '../../../../src/outgoing_call_launcher.dart';

/// BLoC for managing call buttons state and call initiation workflow
///
/// This BLoC handles:
/// - Voice and video call initiation for users (direct call) and groups (meeting)
/// - SDK listener callbacks for call events (rejected, ended)
/// - Button disabled state management during call workflow
///
/// Uses [CometChatCallEventListener] mixin for UI Kit events (ccCallRejected, ccCallEnded)
/// Uses [CallListener] mixin for SDK events (onOutgoingCallRejected, onCallEndedMessageReceived)
///
/// Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7
class CallButtonsBloc extends Bloc<CallButtonsEvent, CallButtonsState>
    with CometChatCallEventListener, CallListener {
  /// User receiver for direct calls
  final User? user;

  /// Group receiver for meeting calls
  final Group? group;

  /// Configuration for outgoing call screen
  final CometChatOutgoingCallConfiguration? outgoingCallConfiguration;

  /// Custom call settings builder
  final SessionSettingsBuilder Function(
    User? user,
    Group? group,
    bool? isAudioOnly,
  )?
  callSettingsBuilder;

  /// Error callback
  final OnError? errorCallback;

  /// Unique listener ID for SDK listeners
  late final String _listenerId;

  /// Receiver type (user or group)
  late final String _receiverType;

  /// Receiver ID (uid or guid)
  late final String _receiverId;

  /// Logged in user
  User? _loggedInUser;

  /// Creates a CallButtonsBloc
  ///
  /// Either [user] or [group] must be provided to determine the receiver.
  /// - For [user] receivers: initiates direct calls
  /// - For [group] receivers: initiates meetings
  CallButtonsBloc({
    this.user,
    this.group,
    this.outgoingCallConfiguration,
    this.callSettingsBuilder,
    this.errorCallback,
  }) : super(CallButtonsState.initial()) {
    // Initialize receiver info
    _initializeReceiver();

    // Generate unique listener ID
    _listenerId =
        'callButtons_${DateTime.now().microsecondsSinceEpoch.toString()}';

    // Register event handlers
    on<InitiateVoiceCall>(_onInitiateVoiceCall);
    on<InitiateVideoCall>(_onInitiateVideoCall);
    on<CallRejected>(_onCallRejected);
    on<CallEnded>(_onCallEnded);

    // Add SDK listeners
    _addListeners();

    // Initialize logged in user
    _initializeLoggedInUser();
  }

  /// Initialize receiver type and ID from user or group
  void _initializeReceiver() {
    if (user != null) {
      _receiverType = ReceiverTypeConstants.user;
      _receiverId = user!.uid;
    } else if (group != null) {
      _receiverType = ReceiverTypeConstants.group;
      _receiverId = group!.guid;
    } else {
      _receiverType = '';
      _receiverId = '';
    }
  }

  /// Initialize logged in user
  Future<void> _initializeLoggedInUser() async {
    final result = await CallOperationsServiceLocator
        .instance
        .getLoggedInUserUseCase
        .call();
    result.onSuccess((user) => _loggedInUser = user);
  }

  /// Add SDK and event listeners
  void _addListeners() {
    CometChat.addCallListener(_listenerId, this);
    CometChatCallEvents.addCallEventsListener(_listenerId, this);
  }

  /// Remove SDK and event listeners
  void _removeListeners() {
    CometChat.removeCallListener(_listenerId);
    CometChatCallEvents.removeCallEventsListener(_listenerId);
  }

  // ============================================================
  // SDK LISTENER CALLBACKS - CometChatCallEventListener
  // ============================================================

  /// Called when a call is rejected by the logged-in user
  @override
  void ccCallRejected(Call call) {
    add(CallRejected(call));
  }

  /// Called when a call is ended by the logged-in user
  @override
  void ccCallEnded(Call call) {
    add(CallEnded(call));
  }

  // ============================================================
  // SDK LISTENER CALLBACKS - CallListener
  // ============================================================

  /// Called when an outgoing call is rejected by the receiver
  @override
  void onOutgoingCallRejected(Call call) {
    add(CallRejected(call));
  }

  /// Called when a call ended message is received
  @override
  void onCallEndedMessageReceived(Call call) {
    add(CallEnded(call));
  }

  // ============================================================
  // EVENT HANDLERS
  // ============================================================

  /// Handle voice call initiation
  Future<void> _onInitiateVoiceCall(
    InitiateVoiceCall event,
    Emitter<CallButtonsState> emit,
  ) async {
    await _initiateCall(CallTypeConstants.audioCall, emit);
  }

  /// Handle video call initiation
  Future<void> _onInitiateVideoCall(
    InitiateVideoCall event,
    Emitter<CallButtonsState> emit,
  ) async {
    await _initiateCall(CallTypeConstants.videoCall, emit);
  }

  /// Handle call rejected event - re-enable buttons
  Future<void> _onCallRejected(
    CallRejected event,
    Emitter<CallButtonsState> emit,
  ) async {
    _placedCallOver(event.call, emit);
  }

  /// Handle call ended event - re-enable buttons
  Future<void> _onCallEnded(
    CallEnded event,
    Emitter<CallButtonsState> emit,
  ) async {
    _placedCallOver(event.call, emit);
  }

  /// Session of the call (or meeting) these buttons placed last, while it
  /// is not known to be over.
  String? _placedSessionId;

  /// A call was rejected or ended: if it is the one these buttons placed,
  /// they come back with no call in progress.
  ///
  /// Every other call is ignored, and so is any call while one is being
  /// placed (its own is not announced yet). The events are broadcast, and
  /// one about another call used to bring the buttons back in the middle of
  /// a placement: a host that closed its bloc on that (master_app's card
  /// action) then dropped the call without a word. Placing re-enables the
  /// buttons itself, however it ends.
  void _placedCallOver(Call call, Emitter<CallButtonsState> emit) {
    if (_placing) return;
    final placed = _placedSessionId;
    if (placed == null || placed.isEmpty || call.sessionId != placed) return;
    _placedSessionId = null;
    emit(
      state.copyWith(
        isDisabled: false,
        isCallInProgress: false,
        clearError: true,
      ),
    );
  }

  // ============================================================
  // CALL INITIATION LOGIC
  // ============================================================

  /// Set while a call or meeting is being placed, from the tap until its
  /// screen is up or it has failed.
  bool _placing = false;

  /// Places a call or starts a meeting, one at a time.
  ///
  /// Both handlers run concurrently, and the buttons only went dead after a
  /// rebuild, so two taps in one frame, or voice and video pressed
  /// together, asked for permission twice and placed two calls. A tap while
  /// one is being placed is now dropped (round 2, P2-C01; Android has no
  /// such guard, P2-D02 A). Another call component placing a call at the
  /// same moment refuses this one with ACTIVE_CALL (round 2 review). Anything
  /// that throws along the way (the permission plugin refusing a second
  /// request, a host callback) brings the buttons back and reaches onError:
  /// it used to leave them dead for the life of the bloc.
  Future<void> _initiateCall(
    String callType,
    Emitter<CallButtonsState> emit,
  ) async {
    if (_placing) return;
    if (!ActiveCallTracker.beginPlacingCall(this)) {
      _refuseActiveCall(emit);
      return;
    }
    _placing = true;
    try {
      await _placeCall(callType, emit);
    } catch (e, stackTrace) {
      ccLog('CallButtonsBloc: placing the call failed: $e\n$stackTrace');
      final error = callExceptionFrom(e);
      emit(
        state.copyWith(
          isDisabled: false,
          isCallInProgress: false,
          errorMessage: error.message,
        ),
      );
      _reportError(error);
    } finally {
      _placing = false;
      ActiveCallTracker.endPlacingCall(this);
    }
  }

  /// Refuses a call with ACTIVE_CALL: another is in progress, or being
  /// placed.
  void _refuseActiveCall(Emitter<CallButtonsState> emit) {
    const message = 'Cannot initiate call while another call is active';
    emit(
      state.copyWith(
        isDisabled: false,
        isCallInProgress: false,
        errorMessage: message,
      ),
    );
    _reportError(activeCallException());
    if (kDebugMode) ccLog('CallButtonsBloc: $message');
  }

  /// Initiate a call based on receiver type
  Future<void> _placeCall(
    String callType,
    Emitter<CallButtonsState> emit,
  ) async {
    // One call at a time. Starting a second while one is being placed or is
    // on screen stacked call screens and left two calls fighting over the
    // same media session. Kotlin refuses here with ACTIVE_CALL, reported
    // through onError only, and checks what hasActiveCall does: the SDK's
    // active call. A group meeting on screen refuses too (round 5, the
    // owner's D06 A): the new call's screen replaced the meeting's without
    // leaving it. An incoming call still ringing does not count.
    if (ActiveCallTracker.isInCallOrMeeting) {
      _refuseActiveCall(emit);
      return;
    }

    // Disable buttons during call initiation
    emit(state.copyWith(isDisabled: true, clearError: true));

    if (_receiverType == ReceiverTypeConstants.group) {
      await _initiateMeetWorkflow(callType, emit);
    } else {
      await _initiateCallWorkflow(callType, emit);
    }
  }

  /// Stops a call or meeting whose permissions were refused: the buttons
  /// come back with [message], and onError gets PERMISSION_DENIED, or
  /// PERMISSION_PERMANENTLY_DENIED when only the app's settings can grant
  /// them, with the missing permissions in its details.
  void _refusePermissions(
    CallPermissionOutcome permissions,
    String message,
    Emitter<CallButtonsState> emit,
  ) {
    emit(
      state.copyWith(
        isDisabled: false,
        isCallInProgress: false,
        errorMessage: message,
      ),
    );
    _reportError(permissions.toException(message));
  }

  /// Starts a meeting in the group: the meeting message goes out first, and
  /// the meeting's screen opens only once it is sent (Android's order; round
  /// 5, P5-C01, the owner's choice).
  ///
  /// The screen used to open first and the message to follow. When the send
  /// failed (offline, or no longer a member, say), the host sat in a meeting
  /// nobody had been told about, and onError never heard of it. Now nothing
  /// is sent when:
  /// * the microphone (or camera) is refused (PERMISSION_DENIED or
  ///   PERMISSION_PERMANENTLY_DENIED);
  /// * there is no navigator to show the meeting on (NO_NAVIGATOR);
  /// * a logout is under way, or begins before the message goes out;
  /// * the Calls SDK is still not ready after the UI Kit's bounded wait for
  ///   it (`CallEventService.waitForCallsSdk`, about 22 s at most):
  ///   CALLS_NOT_READY. The message would announce a meeting that the
  ///   host's own screen then fails to join.
  ///
  /// A send that fails reaches onError with the SDK's own exception, and no
  /// screen opens. Once the message is sent the screen opens, even if the
  /// chat was closed meanwhile (as a placed 1-on-1 call's does), unless
  /// this meeting is on screen already (its host joined from the bubble),
  /// another call is (ACTIVE_CALL), or a logout began meanwhile (nothing
  /// is reported then). The buttons stay off until then. On a
  /// bad network the chat SDK retries a send for up to about a minute.
  ///
  /// The message's own events (in progress, then sent or failed) come from
  /// `CometChatUIKit.sendCustomMessage`. This bloc used to send a second
  /// ccMessageSent of its own for each.
  Future<void> _initiateMeetWorkflow(
    String callType,
    Emitter<CallButtonsState> emit,
  ) async {
    final bool isAudioOnly = callType == CallTypeConstants.audioCall;

    // Same Android 14+ FGS permission gate as direct calls.
    final permissions = await CallPermissionCheck.request(
      isVideoCall: !isAudioOnly,
    );
    if (isClosed) return;
    if (!permissions.isGranted) {
      _refusePermissions(
        permissions,
        'Microphone${isAudioOnly ? '' : ' and camera'} permission is required to start the meeting.',
        emit,
      );
      return;
    }

    // Nowhere to show the meeting: refuse before anything is sent.
    if (_refuseWithoutNavigator(emit, what: 'call screen')) return;

    // A logout is ending this device's calls: a meeting announced now could
    // not be joined.
    if (CallsLifecycle.isPreparingLogout) {
      emit(state.copyWith(isDisabled: false, isCallInProgress: false));
      ccLog('CallButtonsBloc: logging out; the meeting was not started');
      return;
    }

    // The settings the meeting joins with: the one resolver a member's Join
    // from the bubble uses too (round 5, P5-C05). The host used to read
    // callSettingsBuilder, then the outgoing call configuration's builder,
    // and never groupSessionSettingsBuilder; for an audio meeting it got
    // the audio flags only on the UI Kit's own default. Resolved before
    // anything is sent: a builder of the app's that throws stops the
    // meeting with nothing announced.
    final SessionSettingsBuilder sessionSettingsBuilder =
        MeetingSessionSettings.resolve(
          isAudioOnly: isAudioOnly,
          settingsFactory: callSettingsBuilder,
          group: group,
          configuration: CallingConfigurationResolver.resolved,
          hostFallback: outgoingCallConfiguration?.sessionSettingsBuilder,
        );

    // A logout (or a login as another user) that begins from here on tears
    // this device's calls down: the meeting then goes no further, as a
    // 1-on-1 call being placed does.
    final epoch = CallsLifecycle.callEpoch;

    // The Calls SDK must be able to join before the meeting is announced.
    // Every call screen's join checks the same (OngoingCallBloc).
    await CallOperationsServiceLocator.instance.repository.waitForCallsSdk();
    if (isClosed) return;
    if (_tornDownSince(epoch, emit)) return;
    if (!CallsSdkSession.instance.isReady) {
      const message = 'Call service is not ready. Please try again.';
      emit(
        state.copyWith(
          isDisabled: false,
          isCallInProgress: false,
          errorMessage: message,
        ),
      );
      ccLog('CallButtonsBloc: the Calls SDK is not ready; no meeting started');
      _reportError(
        CometChatException(
          CallErrorCodes.callsNotReady,
          'The Calls SDK is not initialised or not logged in.',
          message,
        ),
      );
      return;
    }

    final result = await CallOperationsServiceLocator
        .instance
        .sendMeetingMessageUseCase
        .call(_meetingMessage(callType));

    // Torn down while the message was on its way: no screen over the logout,
    // and nothing to report.
    if (_tornDownSince(epoch, emit)) return;

    if (result is! Success<CustomMessage>) {
      final failure = result as Failure;
      if (!isClosed) {
        emit(
          state.copyWith(
            isDisabled: false,
            isCallInProgress: false,
            errorMessage: failure.message,
          ),
        );
      }
      ccLog('CallButtonsBloc: the meeting message failed: ${failure.message}');
      // The SDK's own exception, code kept (round 1b deferred this here).
      _reportError(callFailureException(failure));
      return;
    }

    // Sent. The meeting's screen opens even when the chat was closed
    // meanwhile, as a placed 1-on-1 call's does (P2-D07 A): the members have
    // been told, and only this screen puts the host in the meeting.
    if (_meetingOnScreen) {
      // The host joined from the meeting's bubble while the message was on
      // its way: that screen is this meeting's. Showing it again used to
      // tear the live screen down and join a second time.
      ccLog('CallButtonsBloc: meeting $_receiverId is already on screen');
    } else if (ActiveCallTracker.isInCallOrMeeting) {
      // A call, or another meeting, came up while the message was on its
      // way (a call answered from its banner, say). It stays; the meeting
      // is not shown over it (D06 A).
      _placedSessionId = null;
      _refuseActiveCall(emit);
      return;
    } else {
      CallScreenOverlay.show(
        sessionId: _receiverId,
        sessionSettingsBuilder: sessionSettingsBuilder,
        callWorkFlow: CallWorkFlow.directCalling,
        onError: errorCallback,
      );
    }

    // Not on screen: the navigator went during the send, and show() has
    // told onError (NO_NAVIGATOR).
    final bool shown = _meetingOnScreen;
    _placedSessionId = shown ? _receiverId : null;
    if (!isClosed) {
      emit(state.copyWith(isDisabled: false, isCallInProgress: shown));
    }
  }

  /// Whether this device's calls were torn down since [epoch] (a logout
  /// began, say). If so the buttons come back, and the meeting goes no
  /// further, with nothing reported.
  bool _tornDownSince(int epoch, Emitter<CallButtonsState> emit) {
    if (epoch == CallsLifecycle.callEpoch) return false;
    if (!isClosed) {
      emit(state.copyWith(isDisabled: false, isCallInProgress: false));
    }
    ccLog('CallButtonsBloc: calls were torn down; the meeting goes no further');
    return true;
  }

  /// Whether this group's meeting is on the call screen now.
  bool get _meetingOnScreen =>
      CallScreenOverlay.isShowing &&
      ActiveCallTracker.callScreenSessionId == _receiverId &&
      ActiveCallTracker.callScreenWorkFlow == CallWorkFlow.directCalling;

  /// The meeting message that announces a meeting in this group: its call
  /// type, and the session (the group's guid) members join.
  CustomMessage _meetingMessage(String callType) {
    final CustomMessage message = CustomMessage(
      receiverUid: _receiverId,
      receiverType: ReceiverTypeConstants.group,
      type: MessageTypeConstants.meeting,
      customData: <String, dynamic>{
        'callType': callType,
        'sessionID': _receiverId,
      },
    );
    message.receiver = group;
    message.sentAt = DateTime.now();
    message.muid = DateTime.now().microsecondsSinceEpoch.toString();
    message.category = MessageCategoryConstants.custom;
    message.sender = _loggedInUser;
    message.updateConversation = true;
    // Members get a push for it, as from Android (round 5, P5-C02). The
    // Dart SDK leaves sendNotification null unless it is set, and a null is
    // left out of the request.
    message.sendNotification = true;
    // The unread count goes up for members who are not looking at the
    // group, and the push is marked as a meeting's, as Android marks it.
    message.metadata = <String, dynamic>{
      ...?message.metadata,
      UpdateSettingsConstant.incrementUnreadCount: true,
      'pushNotification': MessageTypeConstants.meeting,
    };
    return message;
  }

  /// Initiate a direct call workflow for user receivers
  Future<void> _initiateCallWorkflow(
    String callType,
    Emitter<CallButtonsState> emit,
  ) async {
    final bool isAudioOnly = callType == CallTypeConstants.audioCall;

    // Nowhere to show the call: refuse before asking for permissions, and
    // before placing it. A call placed with no screen for it left the device
    // "in a call" and the callee ringing with nobody to cancel. (A meeting is
    // checked before its message is sent.)
    if (_refuseWithoutNavigator(emit)) return;

    // Android 14+ requires RECORD_AUDIO (and CAMERA for video) granted at
    // runtime BEFORE the Calls SDK registers the session and starts its
    // foreground service. Request here so the dialog shows before we hit
    // the network; this is the earliest point we know the call type.
    final permissions = await CallPermissionCheck.request(
      isVideoCall: !isAudioOnly,
    );
    if (isClosed) return;
    if (!permissions.isGranted) {
      _refusePermissions(
        permissions,
        'Microphone${isAudioOnly ? '' : ' and camera'} permission is required to start the call.',
        emit,
      );
      return;
    }

    // The host's settings for the call, or none: the outgoing call screen
    // then joins with the UI Kit's own (a voice call an audio session on
    // the earpiece, a video call on the loudspeaker), and applies the
    // call's type on top of a host's. A default built here used to reach
    // the call screen as a host builder, so a voice call placed from the
    // message header started on the loudspeaker while the callee's started
    // on the earpiece (round 4 review).
    final SessionSettingsBuilder? hostSessionSettingsBuilder =
        callSettingsBuilder?.call(user, group, isAudioOnly) ??
        outgoingCallConfiguration?.sessionSettingsBuilder;

    // Again: the navigator can go while the permission prompt is up.
    if (_refuseWithoutNavigator(emit)) return;

    // A logout is ending this device's calls and has picked the ones it
    // cancels: a call placed now would be closed with nothing sent.
    if (CallsLifecycle.isPreparingLogout) {
      emit(state.copyWith(isDisabled: false, isCallInProgress: false));
      ccLog('CallButtonsBloc: logging out; the call was not placed');
      return;
    }

    // Create call object
    final Call call = Call(
      receiverUid: _receiverId,
      receiverType: ReceiverTypeConstants.user,
      type: callType,
    );

    // Initiate call via use case. Tracked, so a logout that starts meanwhile
    // waits for it, and the call is cancelled while the user can still be
    // heard instead of ringing with nobody to end it.
    final epoch = CallsLifecycle.callEpoch;
    final uid = CallsLifecycle.uid;
    final initiateCallUseCase =
        CallOperationsServiceLocator.instance.initiateCallUseCase;
    final result = await ActiveCallTracker.trackCallRequest(() async {
      final placed = await initiateCallUseCase.call(call);
      if (epoch != CallsLifecycle.callEpoch && placed is Success<Call>) {
        await CallsLifecycle.cancelPlacedDuringTeardown(
          placed.data,
          placedBy: uid,
        );
      }
      return placed;
    });

    if (epoch != CallsLifecycle.callEpoch) {
      // Calls were torn down meanwhile: no screen, nothing to report.
      if (!isClosed) {
        emit(state.copyWith(isDisabled: false, isCallInProgress: false));
      }
      return;
    }

    if (result is! Success<Call>) {
      final failure = result as Failure;
      if (!isClosed) {
        emit(
          state.copyWith(
            isDisabled: false,
            isCallInProgress: false,
            errorMessage: failure.message,
          ),
        );
      }
      if (kDebugMode) {
        ccLog('Error initiating call: ${failure.message}');
      }
      _reportError(callFailureException(failure));
      return;
    }

    // Placed. Its screen is shown even when the chat that asked for it has
    // gone meanwhile and closed this bloc (owner decision, P2-D07 A): the
    // callee is ringing, and only that screen can cancel the call. The
    // buttons stay off until the screen is up, or the call could not be
    // shown: a tap in between used to hit ACTIVE_CALL.
    final shown = await OutgoingCallLauncher.show(
      result.data,
      epoch: epoch,
      user: user,
      configuration: outgoingCallConfiguration,
      sessionSettingsBuilder: hostSessionSettingsBuilder,
      onError: errorCallback,
    );
    _placedSessionId = shown ? result.data.sessionId : null;
    if (!isClosed) {
      emit(state.copyWith(isDisabled: false, isCallInProgress: shown));
    }
  }

  /// Refuses the call with NO_NAVIGATOR when there is no navigator to show
  /// its screen ([what]) on, and says whether it did.
  bool _refuseWithoutNavigator(
    Emitter<CallButtonsState> emit, {
    String what = 'outgoing call screen',
  }) {
    if (_hasNavigator) return false;
    final error = noNavigatorException(what);
    emit(
      state.copyWith(
        isDisabled: false,
        isCallInProgress: false,
        errorMessage: error.message,
      ),
    );
    ccLog('CallButtonsBloc: no navigator; the call was not placed');
    _reportError(error);
    return true;
  }

  /// Whether `CallNavigationContext.navigatorKey` has a navigator to push
  /// the outgoing call screen on.
  static bool get _hasNavigator {
    final context = CallNavigationContext.navigatorKey.currentContext;
    return context != null && context.mounted;
  }

  /// Hands [error] to [errorCallback]; a throwing callback is only logged.
  void _reportError(CometChatException error) =>
      reportCallError(errorCallback, error, where: 'CallButtonsBloc');

  @override
  Future<void> close() {
    // Remove all SDK and event listeners
    _removeListeners();
    return super.close();
  }
}
