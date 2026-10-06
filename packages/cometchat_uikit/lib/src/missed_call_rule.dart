import '../shared_ui/src/clean_architecture/core/constants/ui_kit_constants.dart'
    show CallStatusConstants;

/// What counts as a missed call, wherever the UI Kit shows one: the call
/// bubbles (text, icon and colour), the call logs, `CallUtils.isMissedCall`
/// and the Chats list's last-message subtitle.
///
/// The owner's rule (P5-D09): a call is missed when it went unanswered or was
/// cancelled, for the person who did not start it. A rejected or busy call is
/// never missed: it reads neutrally on both sides. That is also the only rule
/// that holds with the Dart chat SDK as it is: realtime and history call
/// messages carry the user who acted as `callInitiator` (the callee who
/// declined, say), so only the statuses the caller itself sends (cancelled,
/// unanswered) say reliably who started the call.
///
/// Package-private (see `lib/src/`).
abstract final class MissedCallRule {
  /// Whether [status] is one a call is missed with: unanswered or cancelled.
  static bool isMissedStatus(String? status) =>
      status == CallStatusConstants.unanswered ||
      status == CallStatusConstants.cancelled;

  /// Whether a call with [status] is missed for the logged-in user, who
  /// started it when [startedByMe] is true.
  static bool isMissed({required String? status, required bool startedByMe}) =>
      !startedByMe && isMissedStatus(status);
}
