import 'package:cometchat_sdk/cometchat_sdk.dart';

/// A list's server error that shows no error view (D84 (5)). Internal: not
/// exported.
///
/// With offline on, a list that already shows rows from the cache phase keeps
/// them when the server phase fails. A real error (not the not-connected one)
/// on a load the user or app started still reaches the app's `onError`. The
/// list's bloc reports the error here, keyed by the bloc; the list widget that
/// owns the `onError` callback listens for that bloc.
abstract final class OfflineListErrors {
  static final Expando<void Function(CometChatException)> _sinks =
      Expando<void Function(CometChatException)>('OfflineListErrors');

  /// Routes the errors reported for [owner] to [sink] (the widget's onError).
  static void listen(Object owner, void Function(CometChatException) sink) =>
      _sinks[owner] = sink;

  /// Stops routing [owner]'s errors, if [sink] is still the one listening.
  static void cancel(Object owner, void Function(CometChatException) sink) {
    if (_sinks[owner] == sink) _sinks[owner] = null;
  }

  /// Reports [error] for [owner]; nothing happens when no widget listens.
  static void report(Object owner, CometChatException error) =>
      _sinks[owner]?.call(error);
}
