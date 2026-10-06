import 'dart:async';

import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show
        CallSession,
        Participant,
        ParticipantEventListeners,
        SessionStatusListeners;
import 'package:flutter/foundation.dart';

import '../call_ui/src/call_operations/di/call_operations_service_locator.dart';
import '../call_ui/src/ongoing_call/call_screen_overlay.dart';
import '../shared_ui/src/logging/cometchat_log.dart';
import 'active_call_tracker.dart';

/// Guards against a "ghost join": a call view that joins natively after its
/// call screen gave the call up (the owner's decision 2, round 4 review).
///
/// Package-private (see `lib/src/`). A call screen arms it when it closes
/// after its call view was handed over but before the native join was
/// reported: the 30 s watchdog, back while connecting, a remote end during
/// "Connecting", a failed join after the view appeared. It stays armed for
/// that session for [window] at most, and never acts while a call of the
/// app's own is joining or up.
///
/// Why it is needed, from the Calls plugin 5.0.8 and the shipped native SDK
/// 5.0.4: on iOS a disposed call view does not stop its join (the native
/// join holds the view's container and the React Native app runs on the
/// shared bridge), and a 1-on-1 call's leave before its conference exists
/// does nothing in the Calls JS: the join goes on, joins with a live
/// microphone and no UI, and the next call's join fails with "Session
/// already started". Android stops the join when the view is disposed.
///
/// What it does:
///
/// * A native join signal (onSessionJoined, a participant joining, a
///   non-empty participant list) that reaches Dart while it is armed and no
///   call of the app's is joining or up: the session is left at once.
///   On iOS this cannot happen after the call screen's own leave: the
///   plugin's leave clears every native listener (`clearAllListeners`), and
///   only the next join attaches them again. It covers what does reach Dart:
///   Android's late events, and a plugin that keeps its listeners.
/// * iOS: [beforeJoin], right before the next call screen joins: the given
///   up session is left once more (which ends its conference if the late
///   join came, and lets the next join start), the leave is recorded as just
///   before a join so the next screen takes that session's late "left" for
///   an echo ([ActiveCallTracker.noteLeftBeforeJoin]), and the next join
///   waits [settle] for the Calls SDK to finish it.
abstract final class GhostJoinGuard {
  /// How long a session given up before its native join is watched.
  static const Duration window = Duration(seconds: 120);

  /// How long the next join waits after leaving a given-up session again.
  @visibleForTesting
  static Duration settle = const Duration(milliseconds: 500);

  static ({String sessionId, DateTime at, int generation})? _armed;
  static final _GhostSessionListener _sessionListener = _GhostSessionListener();
  static final _GhostParticipantListener _participantListener =
      _GhostParticipantListener();
  static bool _listening = false;

  /// The session armed for, while armed (for logs and tests).
  static String? get armedFor => _current()?.sessionId;

  /// [sessionId]'s call screen closed after its call view was handed over,
  /// but before its native join was reported.
  static void arm(String sessionId) {
    if (sessionId.isEmpty) return;
    _armed = (
      sessionId: sessionId,
      at: ActiveCallTracker.wallClock(),
      generation: ActiveCallTracker.callScreenGeneration,
    );
    final CallSession? session = CallSession.getInstance();
    if (!_listening && session != null) {
      session.addSessionStatusListener(_sessionListener);
      session.addParticipantEventListener(_participantListener);
      _listening = true;
    }
  }

  /// Stops watching: the next join has dealt with it, the window passed, or
  /// calls were torn down (which leave the session themselves).
  static void disarm() {
    _armed = null;
    if (!_listening) return;
    final CallSession? session = CallSession.getInstance();
    session?.removeSessionStatusListener(_sessionListener);
    session?.removeParticipantEventListener(_participantListener);
    _listening = false;
  }

  static ({String sessionId, DateTime at, int generation})? _current() {
    final armed = _armed;
    if (armed == null) return null;
    if (ActiveCallTracker.wallClock().difference(armed.at) > window) {
      disarm();
      return null;
    }
    return armed;
  }

  /// A native join signal reached Dart ([how]).
  static void _nativeJoin(String how) {
    final armed = _current();
    if (armed == null) return;
    // A call of the app's own is joining or up, or a newer call screen came
    // since: the event may be that call's, and its session is not ours to
    // leave.
    if (CallScreenOverlay.isShowing ||
        ActiveCallTracker.mayHaveMediaSession ||
        ActiveCallTracker.callScreenGeneration != armed.generation) {
      return;
    }
    ccLogConsole(
      'GhostJoinGuard: ${armed.sessionId} joined natively after its call '
      'screen gave it up ($how); leaving it',
    );
    disarm();
    unawaited(_leave());
  }

  /// Right before a call screen joins: on iOS, a session given up before its
  /// native join within [window] is left once more first. See the class
  /// doc. Elsewhere it only stops watching. Never throws.
  static Future<void> beforeJoin() async {
    final armed = _current();
    if (armed == null) return;
    disarm();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    ccLogConsole(
      'GhostJoinGuard: leaving ${armed.sessionId} again before the next '
      'join: it was given up before its native join, which may have come '
      'since',
    );
    ActiveCallTracker.noteLeftBeforeJoin(armed.sessionId);
    await _leave().timeout(const Duration(seconds: 2), onTimeout: () {});
    await Future<void>.delayed(settle);
  }

  static Future<void> _leave() async {
    try {
      final result = await CallOperationsServiceLocator
          .instance
          .endSessionUseCase
          .call();
      result.fold(
        (failure) =>
            ccLog('GhostJoinGuard: leaving failed: ${failure.message}'),
        (_) {},
      );
    } catch (e) {
      ccLog('GhostJoinGuard: leaving failed: $e');
    }
  }
}

/// The guard's own session listener: the native join.
final class _GhostSessionListener extends SessionStatusListeners {
  @override
  void onSessionJoined() => GhostJoinGuard._nativeJoin('onSessionJoined');
}

/// The guard's own participant listener: someone joining, or a list with
/// anyone in it (a participant leaving is no join).
final class _GhostParticipantListener extends ParticipantEventListeners {
  @override
  void onParticipantJoined(Participant participant) =>
      GhostJoinGuard._nativeJoin('a participant joining');

  @override
  void onParticipantListChanged(List<Participant> participants) {
    if (participants.isNotEmpty) {
      GhostJoinGuard._nativeJoin('a participant list');
    }
  }
}
