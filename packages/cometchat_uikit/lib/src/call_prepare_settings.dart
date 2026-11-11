import 'package:cometchat_calls_sdk/cometchat_calls_sdk.dart'
    show SessionSettings;
import 'package:cometchat_sdk/cometchat_sdk.dart' show Call;

/// The session settings a call is to be placed with, carried on the [Call]
/// on its way to `CometChatUIKitCalls.initiateCall`.
///
/// Package-private (see `lib/src/`). `CometChatCalls.initiateCall` prepares
/// the caller's session with the settings it is given, and they are frozen
/// by that prepare: the join once the call is answered uses them. The call
/// components know them, but the data source's `initiateCall(Call)` has no
/// place for them, and its signature stays as it is (ringing v2 keeps the
/// public API). They travel with the call object instead, as the placement
/// time does (`ActiveCallTracker.markPlaced`).
abstract final class CallPrepareSettings {
  static final Expando<SessionSettings> _settings = Expando<SessionSettings>(
    'call prepare settings',
  );

  /// Places [call] with [settings].
  static void attach(Call call, SessionSettings settings) =>
      _settings[call] = settings;

  /// The settings [call] is to be placed with, or null for the Calls SDK's
  /// defaults.
  static SessionSettings? of(Call call) => _settings[call];
}
