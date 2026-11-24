import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'offline_hub.dart';

/// The single switch the whole kit reads for offline support (W1 §2.1, G1,
/// UIK-GATE-01, BEH-AUTH-11).
///
/// [isOn] is the **only** call site of `CometChat.isOfflineEnabled()` in
/// `chat_uikit/lib` and `master_app/lib`. Read it once per operation (one
/// load, one send, one connection event, one tap) and pass the resulting
/// `bool offlineOn` down; an operation that started on the offline path
/// finishes there even if the switch flips mid-flight.
///
/// Dart cannot feature-detect a missing method, so the kit raises its
/// `cometchat_sdk` floor to the offline minor (PR #23 §3.1, Q5). A runtime
/// error from the SDK reads as off, so the kit still behaves exactly as today.
///
/// Every `true` read is recorded on the [OfflineHub] as "offline was on during
/// this session", because the SDK answers `false` once a logout has happened
/// and the session-end clear must still run (G8).
///
/// Tests drive the answer with
/// `CometChat.debugSetOfflineEnabledOverride(true/false/null)` — there is no
/// kit-side override.
abstract final class OfflineGate {
  /// Whether offline support is on right now; read once per operation.
  static bool isOn() {
    final on = readSafely(CometChat.isOfflineEnabled);
    if (on) OfflineHub.instance.noteOfflineOn();
    return on;
  }

  /// Runs [read] and treats a throw as "off". Exposed for the throw test.
  @visibleForTesting
  static bool readSafely(bool Function() read) {
    try {
      return read();
    } catch (_) {
      return false;
    }
  }
}
