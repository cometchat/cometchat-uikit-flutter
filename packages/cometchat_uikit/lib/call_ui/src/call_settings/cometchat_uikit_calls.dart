import '../../../cometchat_calls_uikit.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../shared_ui/src/logging/cometchat_log.dart';
import '../../../src/active_call_tracker.dart';
import '../../../src/calls_join.dart';

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

  ///[initiateCall] is the method to initiate a call. It takes [Call] as input. And an optional [onSuccess] and [onError] callback.
  static void initiateCall(
    Call call, {
    dynamic Function(Call)? onSuccess,
    dynamic Function(CometChatException)? onError,
  }) {
    CometChat.initiateCall(
      call,
      onSuccess: (Call call) {
        //execute custom onSuccess callback
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
        if (kDebugMode) {
          ccLog('call initiated successfully');
        }
      },
      onError: (CometChatException e) {
        //execute custom onError callback
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
          ccLog(
            'call could not be initiated ${e.message} ${e.details} ${e.code}',
          );
        }
      },
    );
  }

  ///[acceptCall] is the method to accept a call. It takes [sessionId] as input. And an optional [onSuccess] and [onError] callback.
  static void acceptCall(
    String sessionId, {
    dynamic Function(Call)? onSuccess,
    dynamic Function(CometChatException)? onError,
  }) {
    CometChat.acceptCall(
      sessionId,
      onSuccess: (Call call) {
        //execute custom onSuccess callback
        try {
          if (onSuccess != null) {
            onSuccess(call);
          }
        } catch (e) {
          if (kDebugMode) {
            ccLog('unable to execute custom onSuccess callback');
          }
        }
        if (kDebugMode) {
          ccLog('call initiated successfully');
        }
      },
      onError: (CometChatException e) {
        // The call was not answered, so drop the UI Kit's record of it, or
        // every later incoming call is answered with busy. "Already started"
        // means it was answered through another path and is live.
        if (e.message?.contains('already started') != true) {
          ActiveCallTracker.release(sessionId);
        }
        //execute custom onError callback
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
          ccLog('call could not be initiated ${e.message}');
        }
      },
    );
  }

  ///[rejectCall] is the method to reject or cancel a call. It takes [sessionId] and [status] as input. And an optional [onSuccess] and [onError] callback.
  static void rejectCall(
    String sessionId,
    String status, {
    dynamic Function(Call)? onSuccess,
    dynamic Function(CometChatException)? onError,
  }) {
    CometChat.rejectCall(
      sessionId,
      status,
      onSuccess: (Call call) {
        //execute custom onSuccess callback
        try {
          if (onSuccess != null) {
            onSuccess(call);
          }
        } catch (e) {
          if (kDebugMode) {
            ccLog('unable to execute custom onSuccess callback');
          }
        }
        if (kDebugMode) {
          ccLog('call rejected successfully');
        }
      },
      onError: (CometChatException e) {
        // No ccCallRejected goes out when a reject fails, so drop the UI Kit's
        // record of the call here, or every later incoming call is answered
        // with busy.
        ActiveCallTracker.release(sessionId);
        //execute custom onError callback
        try {
          if (onError != null) {
            onError(e);
          }
        } catch (e) {
          if (kDebugMode) {
            ccLog('unable to execute custom onError callback: $e}');
          }
        }
        if (kDebugMode) {
          ccLog('call could not be rejected ${e.message}');
        }
      },
    );
  }

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
        await CallSession.getInstance()?.leaveSession();
      } finally {
        ActiveCallTracker.mayHaveMediaSession = false;
      }
      // NOTE: do NOT clear the active call here.
      //
      // The documented teardown order is leaveSession() first, then
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
