import 'dart:async';

import '../../../cometchat_calls_uikit.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../shared_ui/src/logging/cometchat_log.dart';
import '../../../src/active_call_tracker.dart';
import '../../../src/calls_join.dart';
import '../../../src/calls_ringing.dart';
import '../../../src/push_ringing.dart';
import '../../../src/ringing_call_mapping.dart';
import '../../../shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';
import '../../../shared_ui/src/constants/ui_kit_constants.dart'
    show CallStatusConstants, ReceiverTypeConstants;

///[CometChatUIKitCalls] is a class that initializes the CometChat Calls SDK. And contains methods to initiate a call, accept a call, reject a call, end a call
class CometChatUIKitCalls {
  ///[init] is the method to initialize the CometChat Calls SDK. It takes [appId] and [region] as input. And an optional [onSuccess] and [onError] callback.
  static void init(
    String appId,
    String region, {
    dynamic Function(String)? onSuccess,
    dynamic Function(CometChatCallsException)? onError,
  }) {
    CallAppSettings callAppSettings =
        (CallAppSettingBuilder()
              ..appId = appId
              ..region = region)
            .build();

    CometChatCalls.init(
      callAppSettings,
      onSuccess: (String successMessage) {
        //execute custom onSuccess callback
        try {
          if (onSuccess != null) {
            onSuccess(successMessage);
          }
        } catch (e) {
          if (kDebugMode) {
            ccLog('unable to execute custom onSuccess callback $e');
          }
        }
        ccLog(
          "CometChatCalls initialization completed successfully  $successMessage",
        );
      },
      onError: (CometChatCallsException e) {
        //execute custom onError callback
        try {
          if (onError != null) {
            onError(e);
          }
        } catch (e) {
          if (kDebugMode) {
            ccLog('unable to execute custom onError callback $e');
          }
        }
        ccLog(
          "CometChatCalls initialization failed with exception: ${e.message}",
        );
      },
    );
  }

  ///[initiateCall] places [call] (to [Call.receiverUid], a user or a group,
  /// as an audio or video call by [Call.type]) and gives back the call as the
  /// server has it. It takes an optional [onSuccess] and [onError] callback.
  ///
  /// Since ringing v2 the call is placed with the Calls SDK
  /// (`CometChatCalls.initiateCall`): the receiver's devices ring through
  /// push, and this device's session starts preparing with
  /// [sessionSettings] (the Calls SDK's defaults when null). Those settings
  /// are frozen by the prepare, so the join once the call is answered uses
  /// them. The caller does not join yet: it joins with [startSession] once
  /// the receiver has joined, and gives up on the call with [rejectCall].
  /// [onSuccess] gets the call as a chat [Call], with the ID of its call
  /// message; a refusal reaches [onError] with the Calls SDK's code.
  ///
  /// On web, where the Calls SDK cannot place calls, it is placed with the
  /// chat SDK, as before ringing v2.
  static void initiateCall(
    Call call, {
    dynamic Function(Call)? onSuccess,
    dynamic Function(CometChatException)? onError,
    SessionSettings? sessionSettings,
  }) {
    if (kIsWeb) {
      _initiateWithChatSdk(call, onSuccess: onSuccess, onError: onError);
      return;
    }
    unawaited(
      CallsRinging.initiateCall(
        receiver: call.receiverUid,
        options: InitiateCallOptions(
          type: call.type.isEmpty ? CallType.video : call.type,
          receiverType: call.receiverType.isEmpty
              ? ReceiverType.user
              : call.receiverType,
          sessionSettings: sessionSettings,
        ),
        onSuccess: (InitiatedCall placed) {
          // The prepared session is the Calls SDK's one session: a logout or
          // dispose leaves it, even if the call is never joined.
          ActiveCallTracker.mayHaveMediaSession = true;
          final Call placedCall = RingingCallMapping.fromInitiated(
            placed,
            caller: CometChatUIKit.loggedInUser,
            receiver: call.receiver ?? call.callReceiver,
          );
          _succeed(onSuccess, placedCall);
          if (kDebugMode) {
            ccLog('call initiated successfully: ${placed.sessionId}');
          }
        },
        onError: (CometChatCallsException e) {
          _fail(onError, _chatException(e));
          if (kDebugMode) {
            ccLog('call could not be initiated ${e.message} ${e.code}');
          }
        },
      ),
    );
  }

  /// Places [call] with the chat SDK: [initiateCall] on web.
  static void _initiateWithChatSdk(
    Call call, {
    dynamic Function(Call)? onSuccess,
    dynamic Function(CometChatException)? onError,
  }) {
    // The Calls SDK cannot place calls on web.
    // ignore: deprecated_member_use
    CometChat.initiateCall(
      call,
      onSuccess: (Call call) {
        _succeed(onSuccess, call);
        if (kDebugMode) {
          ccLog('call initiated successfully');
        }
      },
      onError: (CometChatException e) {
        _fail(onError, e);
        if (kDebugMode) {
          ccLog(
            'call could not be initiated ${e.message} ${e.details} ${e.code}',
          );
        }
      },
    );
  }

  ///[acceptCall] answers the incoming call [sessionId]. It takes an optional
  /// [onSuccess] and [onError] callback.
  ///
  /// Since ringing v2, with the app's push ringer set
  /// (`UIKitSettings.callPushBridge`), the call is answered through it, as
  /// the ring screen's Answer is (`cometchat_voip` tells CometChat it was
  /// answered and stops ringing), and [onSuccess] gets the call as this
  /// device knows it, now ongoing. The UI Kit then joins it on its call
  /// screen, unless the caller of this method shows the call screen itself
  /// first (the UI Kit's incoming call screen does). Without a push ringer,
  /// and on web, the call is accepted with the chat SDK, as before.
  ///
  /// A failure reaches [onError], and the UI Kit's record of the call is
  /// dropped so a later incoming call is not answered with busy.
  static void acceptCall(
    String sessionId, {
    dynamic Function(Call)? onSuccess,
    dynamic Function(CometChatException)? onError,
  }) {
    final push = PushRinging.bridge;
    if (push != null) {
      unawaited(
        _answerThroughPush(
          push,
          sessionId,
          onSuccess: onSuccess,
          onError: onError,
        ),
      );
      return;
    }
    // No push ringer (or web): the chat SDK accepts it, as before ringing v2.
    // ignore: deprecated_member_use
    CometChat.acceptCall(
      sessionId,
      onSuccess: (Call call) {
        _succeed(onSuccess, call);
        if (kDebugMode) {
          ccLog('call accepted successfully');
        }
      },
      onError: (CometChatException e) {
        // The call was not answered, so drop the UI Kit's record of it, or
        // every later incoming call is answered with busy. "Already started"
        // means it was answered through another path and is live.
        if (e.message?.contains('already started') != true) {
          ActiveCallTracker.release(sessionId);
        }
        _fail(onError, e);
        if (kDebugMode) {
          ccLog('call could not be accepted ${e.message}');
        }
      },
    );
  }

  /// Answers [sessionId] through the app's push ringer: [acceptCall] with
  /// one set.
  static Future<void> _answerThroughPush(
    CometChatCallPushBridge push,
    String sessionId, {
    dynamic Function(Call)? onSuccess,
    dynamic Function(CometChatException)? onError,
  }) async {
    final ringing = ActiveCallTracker.ringingCall;
    final Call base = ringing != null && ringing.sessionId == sessionId
        ? ringing
        : Call(
            sessionId: sessionId,
            receiverUid: CometChatUIKit.loggedInUser?.uid ?? '',
            type: '',
            receiverType: ReceiverTypeConstants.user,
          );
    try {
      await push.answer(sessionId);
    } catch (e) {
      ActiveCallTracker.release(sessionId);
      _fail(
        onError,
        e is CometChatException
            ? e
            : CometChatException(
                'ERR_ANSWER_FAILED',
                e.toString(),
                'The call could not be answered',
              ),
      );
      if (kDebugMode) {
        ccLog('call could not be answered: $e');
      }
      return;
    }
    _succeed(
      onSuccess,
      RingingCallMapping.withStatus(base, CallStatusConstants.ongoing),
    );
    if (kDebugMode) {
      ccLog('call answered through the push ringer: $sessionId');
    }
  }

  ///[rejectCall] ends the call [sessionId] before it is joined, with
  /// [status]: the receiver declines (`rejected`, or `busy`), or the caller
  /// withdraws (`cancelled`) or gives up on a call nobody answered
  /// (`unanswered`). It takes an optional [onSuccess] and [onError] callback.
  ///
  /// Since ringing v2 the call is ended with the Calls SDK
  /// (`CometChatCalls.endCall`), which leaves the call's session first if it
  /// is the session in progress. [onSuccess] gets the call in its new status
  /// as a chat [Call] (the Calls SDK reports no call message for it); a
  /// refusal reaches [onError] with the Calls SDK's code. A call that was joined is ended with [endSession] instead.
  ///
  /// On web, where the Calls SDK cannot end calls, it is ended with the chat
  /// SDK, as before ringing v2.
  static void rejectCall(
    String sessionId,
    String status, {
    dynamic Function(Call)? onSuccess,
    dynamic Function(CometChatException)? onError,
  }) {
    if (kIsWeb) {
      _rejectWithChatSdk(
        sessionId,
        status,
        onSuccess: onSuccess,
        onError: onError,
      );
      return;
    }
    // The caller's own call: the Calls SDK leaves the session it prepared,
    // whatever the network result.
    final leavesOwnSession =
        status == CallStatusConstants.cancelled ||
        status == CallStatusConstants.unanswered;
    unawaited(
      CallsRinging.endCall(
        sessionId: sessionId,
        status: status,
        onSuccess: () {
          if (leavesOwnSession) ActiveCallTracker.mayHaveMediaSession = false;
          // The Calls SDK reports no data (5.1.0-team): the call as this
          // device knows it, in its new status.
          _succeed(
            onSuccess,
            RingingCallMapping.ended(
              sessionId,
              status,
              known: _knownCall(sessionId),
            ),
          );
          if (kDebugMode) {
            ccLog('call ended before the join: $status');
          }
        },
        onError: (CometChatCallsException e) {
          if (leavesOwnSession) ActiveCallTracker.mayHaveMediaSession = false;
          // No ccCallRejected goes out when a reject fails, so drop the UI
          // Kit's record of the call here, or every later incoming call is
          // answered with busy.
          ActiveCallTracker.release(sessionId);
          _fail(onError, _chatException(e));
          if (kDebugMode) {
            ccLog('call could not be rejected ${e.message} ${e.code}');
          }
        },
      ),
    );
  }

  /// The call [sessionId] as this device knows it: the incoming call ringing
  /// here, or the call it placed, or null.
  static Call? _knownCall(String sessionId) {
    final ringing = ActiveCallTracker.ringingCall;
    if (ringing != null && ringing.sessionId == sessionId) return ringing;
    final active = CallEventService.instance.activeCall;
    if (active is Call && active.sessionId == sessionId) return active;
    return null;
  }

  /// Ends [sessionId] with the chat SDK: [rejectCall] on web.
  static void _rejectWithChatSdk(
    String sessionId,
    String status, {
    dynamic Function(Call)? onSuccess,
    dynamic Function(CometChatException)? onError,
  }) {
    // The Calls SDK cannot end calls on web.
    // ignore: deprecated_member_use
    CometChat.rejectCall(
      sessionId,
      status,
      onSuccess: (Call call) {
        _succeed(onSuccess, call);
        if (kDebugMode) {
          ccLog('call rejected successfully');
        }
      },
      onError: (CometChatException e) {
        // No ccCallRejected goes out when a reject fails, so drop the UI Kit's
        // record of the call here, or every later incoming call is answered
        // with busy.
        ActiveCallTracker.release(sessionId);
        _fail(onError, e);
        if (kDebugMode) {
          ccLog('call could not be rejected ${e.message}');
        }
      },
    );
  }

  /// Hands [call] to a host's [onSuccess]; a callback that throws is only
  /// logged.
  static void _succeed(dynamic Function(Call)? onSuccess, Call call) {
    try {
      if (onSuccess != null) {
        onSuccess(call);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        ccLog('unable to execute custom onSuccess callback: $e');
        ccLog('Stack trace: $stackTrace');
      }
    }
  }

  /// Hands [e] to a host's [onError]; a callback that throws is only logged.
  static void _fail(
    dynamic Function(CometChatException)? onError,
    CometChatException e,
  ) {
    try {
      if (onError != null) {
        onError(e);
      }
    } catch (e) {
      if (kDebugMode) {
        ccLog('unable to execute custom onError callback: $e');
      }
    }
  }

  /// A Calls SDK refusal as the chat SDK's exception the calling API hands
  /// on: its code, message and details kept.
  static CometChatException _chatException(CometChatCallsException e) =>
      CometChatException(e.code, e.details, e.message);

  ///[generateToken] generates a call token for the given [sessionId].
  /// Uses [CometChatCalls.generateCallToken] which manages the auth token
  /// internally (fetched during login).
  static void generateToken(
    String sessionId, {
    dynamic Function(CallToken)? onSuccess,
    dynamic Function(CometChatCallsException)? onError,
  }) {
    CometChatCalls.generateCallToken(
      sessionId,
      onSuccess: (CallToken callToken) {
        try {
          if (onSuccess != null) {
            onSuccess(callToken);
          }
        } catch (e) {
          if (kDebugMode) {
            ccLog("unable to execute custom onSuccess callback");
          }
        }
        if (kDebugMode) {
          ccLog("token was generated successfully: ${callToken.callToken}");
        }
      },
      onError: (CometChatCallsException e) {
        try {
          if (onError != null) {
            onError(e);
          }
        } catch (e) {
          if (kDebugMode) {
            ccLog('unable to execute custom onError callback');
          }
        }
        if (kDebugMode) {
          ccLog('token could not be generated: ${e.message}');
        }
      },
    );
  }

  ///[startSession] starts a call session using the V5 sessionId-based API.
  /// The SDK generates the call token internally.
  ///
  /// On success it starts the Android ongoing-call service ("Call in
  /// progress"), unless [launchOngoingCallService] is false, with the
  /// session's type: an audio session (`SessionType.audio`) asks only for
  /// the microphone foreground-service type. [endSession] stops it.
  ///
  /// The UI Kit's own call screen passes false: it starts the service
  /// itself once the call view is back and its screen is still up, and
  /// stops it when it leaves. A join that lands after its screen closed
  /// then starts no service that nothing stops, and the service of a newer
  /// call is not stopped to undo it.
  static void startSession(
    String sessionId,
    SessionSettings sessionSettings, {
    dynamic Function(Widget?)? onSuccess,
    dynamic Function(CometChatCallsException)? onError,
    bool launchOngoingCallService = true,
  }) {
    // So a logout or dispose leaves this session even if its screen is gone.
    ActiveCallTracker.mayHaveMediaSession = true;
    CallsJoin.joinSession(
      sessionId: sessionId,
      sessionSettings: sessionSettings,
      onSuccess: (Widget? callingWidget) {
        // Launch the ongoing call foreground service (Android notification)
        if (launchOngoingCallService) {
          CometChatOngoingCallService.launch(
            isVideo: sessionSettings.type != SessionType.audio,
          );
        }
        try {
          if (onSuccess != null) {
            onSuccess(callingWidget);
          }
        } catch (e) {
          if (kDebugMode) {
            ccLog("unable to execute custom onSuccess callback");
          }
        }
        if (kDebugMode) {
          ccLog("startCallSession was successful");
        }
      },
      onError: (CometChatCallsException e) {
        try {
          if (onError != null) {
            onError(e);
          }
        } catch (e) {
          if (kDebugMode) {
            ccLog('unable to execute custom onError callback');
          }
        }
        // The Calls SDK refused the join: there is no session to leave. The
        // mark used to stay until a logout, and every incoming call meanwhile
        // rang as if over a call (quieter, the audio left alone).
        ActiveCallTracker.mayHaveMediaSession = false;
        if (kDebugMode) {
          ccLog('startCallSession failed: ${e.message}');
        }
      },
    );
  }

  ///[endSession] leaves the call session. It first stops the Android
  /// ongoing-call service ("Call in progress"), whoever started it: this
  /// method, the UI Kit's call screen or your app. It takes an optional
  /// [onSuccess] and [onError] callback.
  static Future<void> endSession({
    dynamic Function(String)? onSuccess,
    dynamic Function(CometChatCallsException)? onError,
  }) async {
    try {
      // Abort the ongoing call foreground service (Android notification)
      await CometChatOngoingCallService.abort();
      // Left, or not there to leave: either way nothing is left to leave
      // later. The mark used to stay set when the leave failed, and every
      // incoming call after it rang as if over a call.
      try {
        await CallSession.getInstance()?.leave();
      } finally {
        ActiveCallTracker.mayHaveMediaSession = false;
      }
      // NOTE: do NOT clear the active call here.
      //
      // The documented teardown order is leave() first, then
      // CometChat.endCall(). endCall resolves the required `joinedAt` post
      // parameter from the call cached by initiateCall/acceptCall, so wiping
      // that cache here left endCall sending `joinedAt: 0`, which the server
      // rejects with "The joinedAt post parameter is required to end a call".
      // The call then stayed `ongoing` server-side and the other participant
      // never received the call-ended event.
      //
      // Clearing is not needed here anyway: CometChat.endCall() nulls the
      // cached call itself once the status update succeeds.
      try {
        if (onSuccess != null) {
          onSuccess('session ended successfully');
        }
      } catch (e) {
        if (kDebugMode) {
          ccLog("unable to execute custom onSuccess callback");
        }
      }
      ccLog("session ended successfully");
    } catch (e) {
      final error = e is CometChatCallsException
          ? e
          : CometChatCallsException(
              'ERR_END_SESSION',
              'Failed to end session',
              e.toString(),
            );
      try {
        if (onError != null) {
          onError(error);
        }
      } catch (e) {
        if (kDebugMode) {
          ccLog("unable to execute custom onError callback");
        }
      }
      ccLog("session could not be ended: ${error.message}");
    }
  }

  static Future<String?> getUserAuthToken() async {
    return await CometChat.getUserAuthToken();
  }
}
