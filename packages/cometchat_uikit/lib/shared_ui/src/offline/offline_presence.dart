import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:flutter/foundation.dart';

import 'offline_gate.dart';

/// No presence while the SDK is not connected (ENG-41552 A). Internal: not
/// exported.
///
/// With offline on, the message header, the users list, the conversations
/// list and the group members list (D84 (10)) show no "Online" subtitle and
/// no online dot while the SDK is not connected: the last presence they hold
/// may be stale. The lists' connection
/// listeners report here; a reconnect clears the flag and the lists' existing
/// re-fetch brings fresh presence. With offline off [hidden] is always false,
/// so nothing changes.
abstract final class OfflinePresence {
  static final ValueNotifier<bool> _notConnected = ValueNotifier<bool>(false);

  /// Notifies when [hidden] may have changed.
  static ValueListenable<bool> get listenable => _notConnected;

  /// Whether presence is hidden right now: the SDK reported it is not
  /// connected and offline is on.
  static bool get hidden => _notConnected.value && OfflineGate.isOn();

  /// Bumped by every connection event, so a [sync] that started before one
  /// knows its answer is stale.
  static int _generation = 0;

  /// The SDK connected.
  static void connected() {
    _generation++;
    _notConnected.value = false;
  }

  /// The SDK disconnected. Recorded only with offline on.
  static void disconnected() {
    _generation++;
    if (OfflineGate.isOn()) _notConnected.value = true;
  }

  /// Reads the SDK's connection state once, for a list or header that starts
  /// while the SDK is not connected (no disconnect event will come). Only
  /// with offline on; a failed read changes nothing. A connection event that
  /// arrives while the read is in flight wins: the read's answer is dropped.
  static Future<void> sync() async {
    if (!OfflineGate.isOn()) return;
    final generation = _generation;
    try {
      final status = await debugReadConnectionStatus();
      if (generation != _generation) return;
      _notConnected.value = status != CometChatWSState.connected;
    } catch (_) {
      // The SDK is not ready: keep the current answer.
    }
  }

  /// Test-only seam: how [sync] reads the SDK's connection state.
  @visibleForTesting
  static Future<String> Function() debugReadConnectionStatus =
      CometChat.getConnectionStatus;

  /// Test-only: back to connected.
  @visibleForTesting
  static void debugReset() {
    _notConnected.value = false;
    debugReadConnectionStatus = CometChat.getConnectionStatus;
  }
}
