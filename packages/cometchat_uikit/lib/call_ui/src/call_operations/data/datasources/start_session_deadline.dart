import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../../cometchat_calls_uikit.dart';
import '../../../../../shared_ui/src/logging/cometchat_log.dart';

/// How long joining a call may take before the join is reported as failed.
///
/// Joining makes two HTTPS requests (token, then verification) that have no
/// client-side timeout, and one Calls SDK path answers neither callback, so
/// the call screen needs a bound. It is generous on purpose: a slow join is
/// still a good join, and only the call view it returns can join the call.
const Duration kStartSessionTimeout = Duration(seconds: 30);

/// [CallOperationsException.code] reported when [kStartSessionTimeout]
/// passes without the Calls SDK answering.
const String kStartSessionTimeoutCode = 'START_SESSION_TIMEOUT';

/// Starts a call session and hands its callbacks to the caller.
typedef StartSessionCall =
    void Function(
      void Function(Widget? screen) onSuccess,
      void Function(CometChatCallsException error) onError,
    );

/// Waits for [start] to return the call view, for up to [timeout].
///
/// The Calls SDK returns an embedded call view on Android and iOS alike, and
/// the native side joins only once that view is mounted. Resolving early with
/// a placeholder discards the view, so the call never joins. This waits for
/// the real view and fails with [kStartSessionTimeoutCode] if none arrives.
///
/// A view that arrives after [timeout] is never shown, so it never joins;
/// [onLateSuccess] runs once to undo what the success path already started.
Future<Widget> joinWithDeadline(
  StartSessionCall start, {
  Duration timeout = kStartSessionTimeout,
  void Function()? onLateSuccess,
}) {
  final completer = Completer<Widget>();
  final stopwatch = Stopwatch()..start();
  var timedOut = false;
  Timer? deadline;

  start(
    (Widget? screen) {
      if (timedOut) {
        ccLog(
          'CallOperationsDataSource: startSession succeeded after '
          '${stopwatch.elapsedMilliseconds} ms, past the '
          '${timeout.inSeconds} s deadline; the call view is discarded',
        );
        onLateSuccess?.call();
        return;
      }
      if (completer.isCompleted) return;
      deadline?.cancel();
      ccLog(
        'CallOperationsDataSource: startSession onSuccess after '
        '${stopwatch.elapsedMilliseconds} ms',
      );
      // Only platforms without an embedded call view return null.
      completer.complete(screen ?? const SizedBox.shrink());
    },
    (CometChatCallsException e) {
      if (timedOut || completer.isCompleted) {
        ccLog(
          'CallOperationsDataSource: startSession onError after it was '
          'settled: ${e.message}',
        );
        return;
      }
      deadline?.cancel();
      ccLog('CallOperationsDataSource: startSession onError: ${e.message}');
      completer.completeError(
        CallOperationsException(
          message: e.message ?? 'Failed to start session',
          code: e.code,
          originalException: e,
        ),
      );
    },
  );

  if (!completer.isCompleted) {
    deadline = Timer(timeout, () {
      if (completer.isCompleted) return;
      timedOut = true;
      ccLog(
        'CallOperationsDataSource: startSession gave no result in '
        '${timeout.inSeconds} s',
      );
      completer.completeError(
        const CallOperationsException(
          message:
              'Could not join the call. Check your connection and try '
              'again.',
          code: kStartSessionTimeoutCode,
        ),
      );
    });
  }
  return completer.future;
}
