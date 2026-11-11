import 'package:flutter/foundation.dart';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show
        CometChatCalls,
        CometChatCallsException,
        InitiateCallOptions,
        InitiatedCall;

/// How `CometChatUIKitCalls.initiateCall` and
/// `CometChatUIKitCalls.rejectCall` reach the Calls SDK's ringing calls:
/// `CometChatCalls.initiateCall` and `CometChatCalls.endCall`.
///
/// Package-private (see `lib/src/`). A seam, like `CallsJoin`: the real
/// calls need the network and a device, and the tests of what the UI Kit
/// does around them replace them with ones that answer when they say.
abstract final class CallsRinging {
  /// Places a call to `receiver`; `onSuccess` gets the call,
  /// `onError` the Calls SDK's refusal.
  static InitiateRingingCall get initiateCall => _initiate;

  /// Replaces the placement (tests).
  @visibleForTesting
  static set initiateCall(InitiateRingingCall initiate) => _initiate = initiate;

  /// Ends `sessionId` before it is joined with `status`; `onSuccess` is
  /// told it is done (the Calls SDK reports no data since 5.1.0-team),
  /// `onError` gets the Calls SDK's refusal.
  static EndRingingCall get endCall => _end;

  /// Replaces the end (tests).
  @visibleForTesting
  static set endCall(EndRingingCall end) => _end = end;

  static InitiateRingingCall _initiate = _initiateCall;
  static EndRingingCall _end = _endCall;

  static Future<void> _initiateCall({
    required String receiver,
    InitiateCallOptions? options,
    required void Function(InitiatedCall) onSuccess,
    required void Function(CometChatCallsException) onError,
  }) => CometChatCalls.initiateCall(
    receiver: receiver,
    options: options,
    onSuccess: onSuccess,
    onError: onError,
  );

  static Future<void> _endCall({
    required String sessionId,
    String? status,
    required void Function() onSuccess,
    required void Function(CometChatCallsException) onError,
  }) => CometChatCalls.endCall(
    sessionId: sessionId,
    status: status,
    onSuccess: onSuccess,
    onError: onError,
  );

  /// Puts the Calls SDK's own calls back, after a test replaced them.
  @visibleForTesting
  static void debugReset() {
    _initiate = _initiateCall;
    _end = _endCall;
  }
}

/// What [CallsRinging.initiateCall] is.
typedef InitiateRingingCall =
    Future<void> Function({
      required String receiver,
      InitiateCallOptions? options,
      required void Function(InitiatedCall) onSuccess,
      required void Function(CometChatCallsException) onError,
    });

/// What [CallsRinging.endCall] is.
typedef EndRingingCall =
    Future<void> Function({
      required String sessionId,
      String? status,
      required void Function() onSuccess,
      required void Function(CometChatCallsException) onError,
    });
