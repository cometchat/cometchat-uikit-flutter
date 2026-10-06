import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart'
    show CallButtonsState;

/// Closes a call buttons bloc built for one call (the card action's), once
/// that call is placed: its outgoing call screen is up, or placing it was
/// refused or failed. [states] is the bloc's stream and [close] its
/// `close`.
///
/// The buttons come back (`isDisabled` false) exactly then: the UI Kit
/// brings them back when its own placement ends, and no call event brings
/// them back before that. Closed any earlier, the bloc stops before the
/// call is placed and the call is dropped without a word.
///
/// There is no time limit: placing always ends (the permission prompt is
/// the user's, and the SDK gives up on a request within about a minute). A
/// two-minute limit used to close the bloc under a permission prompt left
/// up that long, and the call was dropped.
Future<void> closeWhenPlaced(
  Stream<CallButtonsState> states,
  Future<void> Function() close,
) async {
  try {
    await states.firstWhere((CallButtonsState state) => !state.isDisabled);
  } catch (_) {
    // The stream ended first: the bloc was closed some other way.
  } finally {
    await close();
  }
}
