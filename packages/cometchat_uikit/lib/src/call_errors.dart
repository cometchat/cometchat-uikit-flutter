import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show CometChatCallsException;
import 'package:cometchat_sdk/cometchat_sdk.dart' show CometChatException;
import 'package:flutter/services.dart' show PlatformException;

import '../shared_ui/src/clean_architecture/core/result.dart' show Failure;
import '../shared_ui/src/constants/ui_kit_constants.dart' show OnError;
import '../shared_ui/src/logging/cometchat_log.dart';

/// The codes the call components put on the [CometChatException] they hand
/// to `onError` when the UI Kit itself refuses or gives up on a call.
///
/// Package-private (see `lib/src/`). Hosts compare against the documented
/// strings; the `onError` docs of the call components list them. A failure
/// the SDK reported keeps the SDK's own code instead: see
/// [callFailureException].
abstract final class CallErrorCodes {
  /// Microphone (and, for a video call, camera) access was refused. The
  /// exception's `details` lists the missing permissions, comma separated,
  /// and `errorParams['permissions']` holds them as a list.
  static const String permissionDenied = 'PERMISSION_DENIED';

  /// As [permissionDenied], but the system will not ask again: only the
  /// app's settings page can grant it now.
  static const String permissionPermanentlyDenied =
      'PERMISSION_PERMANENTLY_DENIED';

  /// A call was refused because another one is in progress on this device.
  static const String activeCall = 'ACTIVE_CALL';

  /// The Calls SDK is not initialised or not logged in, so the call screen
  /// cannot join.
  static const String callsNotReady = 'CALLS_NOT_READY';

  /// The Calls SDK did not answer the join within the time limit. The data
  /// layer reports the same failure as `START_SESSION_TIMEOUT`
  /// (`kStartSessionTimeoutCode`), which stays as it was.
  static const String joinTimeout = 'JOIN_TIMEOUT';

  /// The Calls SDK refused the join. `errorParams` carries the SDK's own
  /// `sdkCode`, `sdkMessage` and `sdkDetails` when it gave them.
  static const String joinFailed = 'JOIN_FAILED';

  /// There is no navigator to show a call screen on:
  /// `CallNavigationContext.navigatorKey` is not attached to the app's
  /// `MaterialApp`.
  static const String noNavigator = 'NO_NAVIGATOR';

  /// A call from the call logs was not placed: the logged-in user has
  /// blocked the person it would call.
  static const String blockedByMe = 'BLOCKED_BY_ME';

  /// A call from the call logs was not placed: the person it would call has
  /// blocked the logged-in user.
  static const String hasBlockedMe = 'HAS_BLOCKED_ME';

  /// A host callback (an incoming call's `onAccept` or `onDecline`) threw
  /// something other than a [CometChatException]. `details` holds what it
  /// threw. The accept or decline goes ahead.
  static const String hostCallbackError = 'HOST_CALLBACK_ERROR';
}

/// Whether [error], from accepting or declining an incoming call, says the
/// call was already over or already answered before this device's request
/// landed: the caller cancelled it or gave up, it ended, it was declined
/// or bounced busy, or it was already answered (by this user on another
/// device). Common after the socket dropped during the permission prompt,
/// when the cancel, or the other device's "ongoing", never arrived.
///
/// Recognised by the server's code ([_callOverCodes]) or by the usual
/// wording of the message or details: "call" followed by "is", "has",
/// "was", "already" or "been", then ended, cancelled, terminated,
/// rejected, unanswered, busy, started, ongoing or accepted. Anything else
/// (a network failure, a server error) is not.
///
/// The SDK's own exception still reaches `onError`, code kept; only the
/// incoming call's generic "Something went wrong" message is skipped.
bool isCallAlreadyOver(CometChatException error) {
  if (_callOverCodes.contains(error.code)) return true;
  final text = '${error.message ?? ''} ${error.details ?? ''}'.toLowerCase();
  return _callOverText.hasMatch(text);
}

/// The server's codes for a call that is no longer ringing: ended ("The
/// call with sessionid … is ended."), cancelled, declined, bounced busy,
/// unanswered, or already answered.
const Set<String> _callOverCodes = <String>{
  'ERR_CALL_TERMINATED',
  'ERR_CALL_ENDED',
  'ERR_CALL_CANCELLED',
  'ERR_CALL_REJECTED',
  'ERR_CALL_BUSY',
  'ERR_CALL_UNANSWERED',
  'ERR_CALL_ACCEPTED',
  'ERR_CALL_ONGOING',
};

final RegExp _callOverText = RegExp(
  r'\bcall\b.*\b(is|has|was|already|been)\s+(already\s+|been\s+)?'
  r'(ended|cancell?ed|terminated|rejected|unanswered|busy|started|ongoing|'
  r'accepted)\b',
);

/// The error states an incoming call's bloc emits that need no message from
/// `CometChatIncomingCall`: the UI Kit has already explained the error (a
/// permission refused), or there is nothing to explain (the call was
/// already over). The widget shows its generic "Something went wrong" for
/// every other error state when it has no `onError`. Keyed by the state
/// object the bloc emits.
final Expando<bool> explainedIncomingCallErrors = Expando<bool>(
  'incoming call error needing no message',
);

/// Hands [error] to the host's [onError], if it gave one.
///
/// A host callback that throws is logged and goes no further. The call
/// components report and then carry on cleaning up (a record released, a
/// state emitted, a cancel sent), and a throw used to cut that short: a
/// placed call stayed uncancelled, an accept never finished its
/// bookkeeping. [where] names the component in the log.
void reportCallError(
  OnError? onError,
  CometChatException error, {
  required String where,
}) {
  if (onError == null) return;
  try {
    onError(error);
  } catch (e, stackTrace) {
    ccLog('$where: the onError callback threw: $e\n$stackTrace');
  }
}

/// The `onError` of the `CometChatCallLogs` showing a `CallLogsBloc` that
/// was handed to it (`callLogsBloc:`) without an `errorCallback` of its own.
/// The bloc reports to it instead, so the widget's documented `onError`
/// hears of a call from a log row that cannot be placed either way.
final Expando<OnError> callLogsWidgetOnError = Expando<OnError>(
  'CometChatCallLogs.onError',
);

/// The exception `onError` gets for a failed call operation: the SDK's own,
/// code and all, when the failure carries one.
///
/// It used to be rebuilt as `CometChatException('ERR', message, '')`, which
/// lost the SDK's code and put the text in `details` (the constructor is
/// `(code, details, message)`), leaving `message` empty.
CometChatException callFailureException(Failure failure) {
  final original = failure.exception;
  if (original is CometChatException) return original;
  if (original is CometChatCallsException) {
    return callsSdkException(original);
  }
  return CometChatException(
    failure.code ?? 'ERR',
    failure.message,
    failure.message,
  );
}

/// [error] from the Calls SDK as the [CometChatException] `onError` takes,
/// its code, message and details each kept in their own slot.
CometChatException callsSdkException(CometChatCallsException error) =>
    CometChatException(
      error.code,
      error.details ?? error.message,
      error.message ?? error.details,
    );

/// The [CallErrorCodes.activeCall] refusal: another call is in progress on
/// this device.
CometChatException activeCallException() => CometChatException(
  CallErrorCodes.activeCall,
  'An active call is already in progress',
  'Cannot initiate call while another call is active',
);

/// [error], thrown while a call was being placed, as the
/// [CometChatException] `onError` takes. The SDK's own exception is kept as
/// it is; a platform failure (permission_handler's "a request for
/// permissions is already running", say) keeps its platform code; anything
/// else is `ERR` with its text.
CometChatException callExceptionFrom(Object error) {
  if (error is CometChatException) return error;
  if (error is CometChatCallsException) return callsSdkException(error);
  if (error is PlatformException) {
    return CometChatException(
      error.code,
      error.details?.toString() ?? error.message,
      error.message ?? error.code,
    );
  }
  return CometChatException('ERR', error.toString(), error.toString());
}

/// The [CallErrorCodes.noNavigator] refusal: [what] could not be shown.
CometChatException noNavigatorException(String what) => CometChatException(
  CallErrorCodes.noNavigator,
  'CallNavigationContext.navigatorKey has no navigator to show the $what '
      'on.',
  'The $what cannot be shown: set CallNavigationContext.navigatorKey as the '
      "navigatorKey of the app's MaterialApp.",
);
