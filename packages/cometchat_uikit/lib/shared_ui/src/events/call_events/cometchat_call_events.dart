import 'package:flutter/foundation.dart';

import '../../../cometchat_uikit_shared.dart';

/// class for handling call events.
///
/// Dispatch is synchronous and in registration order, so the UI Kit's own
/// call bookkeeping (registered first, at login) is up to date before any
/// screen hears the event. Each dispatch works on a copy of the listeners: a
/// listener may add or remove listeners from inside its handler, and one that
/// is removed during a dispatch is not called for the rest of it. A listener
/// that throws is reported through [FlutterError.reportError] (so
/// `FlutterError.onError` and crash reporters see it) and the others still
/// get the event.
class CometChatCallEvents {
  /// Map to store the registered call event listeners.
  static Map<String, CometChatCallEventListener> callEventsListener = {};

  /// Adds a call event listener with the specified tag.
  static void addCallEventsListener(
    String listenerId,
    CometChatCallEventListener listenerClass,
  ) {
    callEventsListener[listenerId] = listenerClass;
  }

  /// Removes the call event listener associated with the specified tag.
  static void removeCallEventsListener(String listenerId) {
    callEventsListener.remove(listenerId);
  }

  /// Called when an outgoing call is initiated by the logged-in user.
  static void ccOutgoingCall(Call call) {
    _dispatch('ccOutgoingCall', (listener) => listener.ccOutgoingCall(call));
  }

  /// Called when a call is accepted by the logged-in user.
  static void ccCallAccepted(Call call) {
    _dispatch('ccCallAccepted', (listener) => listener.ccCallAccepted(call));
  }

  /// Called when a call is rejected by the logged-in user.
  static void ccCallRejected(Call call) {
    _dispatch('ccCallRejected', (listener) => listener.ccCallRejected(call));
  }

  /// Called when a call is ended by the logged-in user.
  static void ccCallEnded(Call call) {
    _dispatch('ccCallEnded', (listener) => listener.ccCallEnded(call));
  }

  /// Calls [deliver] on every listener registered when the dispatch starts.
  ///
  /// Iterating the live map threw ConcurrentModificationError as soon as a
  /// handler added or removed a listener (a screen closing on ccCallEnded
  /// does exactly that), and one throwing host listener stopped the event
  /// reaching every listener after it.
  static void _dispatch(
    String event,
    void Function(CometChatCallEventListener listener) deliver,
  ) {
    final snapshot = List.of(callEventsListener.entries);
    for (final entry in snapshot) {
      // Removed or replaced by an earlier listener during this dispatch.
      if (!identical(callEventsListener[entry.key], entry.value)) continue;
      try {
        deliver(entry.value);
      } catch (e, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: stackTrace,
            library: 'cometchat_chat_uikit',
            context: ErrorDescription(
              'while dispatching $event to CometChatCallEvents listener '
              '"${entry.key}"',
            ),
          ),
        );
      }
    }
  }
}
