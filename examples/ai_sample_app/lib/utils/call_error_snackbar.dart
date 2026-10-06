import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart'
    show CallScreenOverlay;
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// The app's [ScaffoldMessenger], so call errors raised from the UI Kit's
/// call components (which have no [BuildContext] of ours) can be shown.
///
/// A SnackBar renders in the route's Scaffold, underneath the UI Kit's call
/// screen overlay, so one raised while a call screen is open only shows once
/// that screen closes. The join failures close it.
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// The codes the UI Kit's call components use for their own refusals. Any
/// other code is the SDK's own.
const Set<String> _kitCallCodes = <String>{
  'ACTIVE_CALL',
  'PERMISSION_DENIED',
  'PERMISSION_PERMANENTLY_DENIED',
  'CALLS_NOT_READY',
  'JOIN_TIMEOUT',
  'JOIN_FAILED',
  'NO_NAVIGATOR',
  'BLOCKED_BY_ME',
  'HAS_BLOCKED_ME',
};

/// For the onError of the components that place a call: the call buttons
/// and the call logs. Everything they report is something the user tried
/// and did not get — a refusal from the UI Kit or the SDK failing to place
/// the call — so all of it is shown.
///
/// Except right after NO_NAVIGATOR: the call that could not be shown is
/// cancelled then, and a failure of that cancel (the SDK's own code) would
/// replace the SnackBar that says what happened. It is only logged.
void showCallPlacementError(Exception error) {
  final e = _asCometChat(error);
  if (e == null) return;
  if (_codeOnScreen == 'NO_NAVIGATOR' && !_kitCallCodes.contains(e.code)) {
    debugPrint(
      'Call error ${e.code} after NO_NAVIGATOR: ${e.message} '
      '(not shown)',
    );
    return;
  }
  _show(e, fallback: "Couldn't place the call (${e.code})");
}

/// For the call buttons' onError (`CallButtonsConfiguration.onError`). The
/// UI Kit also hands it what a group meeting's call screen reports, and
/// the meeting bubble's join. While a call screen is up, what arrives is
/// that screen's (a failed leave, say): it goes through [showInCallError].
/// Otherwise it is about placing the call: [showCallPlacementError].
void showCallButtonsError(Exception error) {
  if (isCallScreenUp()) {
    showInCallError(error);
  } else {
    showCallPlacementError(error);
  }
}

/// Whether the UI Kit's call screen is up. A seam for tests.
@visibleForTesting
bool Function() isCallScreenUp = () => CallScreenOverlay.isShowing;

/// For the onError of the components that run a call already placed: the
/// outgoing and incoming call screens, and the call screen itself.
///
/// Only the UI Kit's own codes are shown: permissions, the Calls SDK not
/// ready, a join that failed or timed out, no navigator. What else reaches
/// these is the SDK's own exception for a cancel, a decline, an accept or an
/// end that failed because the call was already over — noise to the user,
/// so it is only logged. The UI Kit reports every such failure (the Android
/// rule), including the races nobody can act on: End or the 45 s no-answer
/// timeout racing the callee's accept or decline, and both people hanging
/// up at once.
void showInCallError(Exception error) {
  final e = _asCometChat(error);
  if (e == null) return;
  if (!_kitCallCodes.contains(e.code)) {
    debugPrint('Call ended with ${e.code}: ${e.message} (not shown)');
    return;
  }
  _show(e, fallback: "Couldn't join the call (${e.code})");
}

/// Whether [error] is a call being placed from the call logs that failed,
/// rather than the call logs failing to load (`CALL_LOGS_ERROR`), which the
/// call logs screen reports itself.
bool isCallLogsPlacementError(Exception error) =>
    error is CometChatException && error.code != 'CALL_LOGS_ERROR';

CometChatException? _asCometChat(Exception error) {
  if (error is CometChatException) return error;
  debugPrint('Call error: $error');
  return null;
}

/// The code of the call error SnackBar on screen, while it is.
String? _codeOnScreen;
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _snackBarOnScreen;

void _show(CometChatException e, {required String fallback}) {
  debugPrint('Call error ${e.code}: ${e.message} (${e.details})');
  final messenger = appScaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      content: Text(callErrorText(e, fallback: fallback)),
      action: e.code == 'PERMISSION_PERMANENTLY_DENIED'
          ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
          : null,
      duration: const Duration(seconds: 4),
    ),
  );
  _snackBarOnScreen = controller;
  _codeOnScreen = e.code;
  controller.closed.then((_) {
    if (identical(_snackBarOnScreen, controller)) {
      _snackBarOnScreen = null;
      _codeOnScreen = null;
    }
  });
}

/// The text shown for [e]; [fallback] for a code without its own.
@visibleForTesting
String callErrorText(CometChatException e, {required String fallback}) {
  switch (e.code) {
    case 'ACTIVE_CALL':
      return "You're already on a call.";
    case 'PERMISSION_DENIED':
    case 'PERMISSION_PERMANENTLY_DENIED':
      final missing = (e.details ?? '')
          .split(',')
          .where((p) => p.isNotEmpty)
          .join(' and ');
      // The same refusal stops a call being placed and one being answered.
      return 'Allow ${missing.isEmpty ? 'microphone' : missing} access to '
          'make and answer calls.';
    case 'CALLS_NOT_READY':
      return "Calling isn't ready yet. Try again in a moment.";
    case 'JOIN_TIMEOUT':
      return "Couldn't join the call. Check your connection and try again.";
    case 'JOIN_FAILED':
      final sdkCode = e.errorParams?['sdkCode'];
      return sdkCode == null
          ? "Couldn't join the call."
          : "Couldn't join the call ($sdkCode).";
    case 'NO_NAVIGATOR':
      return "Couldn't show the call screen.";
    case 'BLOCKED_BY_ME':
      return "You've blocked this user. Unblock them to call.";
    case 'HAS_BLOCKED_ME':
      return "This user can't be called.";
    default:
      return fallback;
  }
}
