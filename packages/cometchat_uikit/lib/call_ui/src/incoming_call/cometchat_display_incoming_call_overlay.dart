import 'package:flutter/material.dart';
import '../../../cometchat_calls_uikit.dart';
import '../../../cometchat_chat_uikit.dart';
import '../../../shared_ui/src/logging/cometchat_log.dart';
import '../../../src/active_call_tracker.dart';
import '../../../src/call_errors.dart';

class IncomingCallOverlay {
  /// The banner on screen. Only ever an entry that was inserted, so
  /// [dismiss] can always remove it.
  static OverlayEntry? _overlayEntry;

  /// Shows the incoming call banner for [call] over the app, in the overlay
  /// of `CallNavigationContext.navigatorKey`, replacing any banner already
  /// up.
  ///
  /// When that key has no navigator nothing is kept, the call stops counting
  /// as ringing on this device (so the next call is not answered busy
  /// because of it), and [onError] gets `NO_NAVIGATOR`. The call is not
  /// declined: push or CallKit may still ring for it.
  static void show({
    required BuildContext context,
    required Call call,
    User? user,
    OnError? onError,
    Widget? subtitle,
    Function(BuildContext, Call)? onDecline,
    Function(BuildContext, Call)? onAccept,
    bool? disableSoundForCalls,
    String? customSoundForCalls,
    String? customSoundForCallsPackage,
    CometChatIncomingCallStyle? style,
    SessionSettingsBuilder? callSettingsBuilder,
    double? height,
    double? width,
    String? declineButtonText,
    String? acceptButtonText,
    Widget? Function(BuildContext, Call)? titleView,
    Widget? Function(BuildContext, Call)? leadingView,
    Widget? Function(BuildContext, Call)? trailingView,
    Widget? Function(BuildContext, Call)? subtitleView,
    Widget? Function(BuildContext, Call)? itemView,
  }) {
    // Dismiss any existing overlay before showing a new one
    _removeEntry();
    ActiveCallTracker.incomingCallSessionId = null;

    final overlay = CallNavigationContext.navigatorKey.currentState?.overlay;
    if (overlay == null) {
      // It used to keep the entry and the session anyway, so the next
      // show() or dismiss() threw on removing an entry that was never
      // inserted, and the call stayed "ringing" with nothing on screen.
      ccLog(
        'IncomingCallOverlay: no navigator overlay for call '
        '${call.sessionId}. Set CallNavigationContext.navigatorKey as the '
        "navigatorKey of the app's MaterialApp.",
      );
      ActiveCallTracker.releaseRinging(call.sessionId);
      reportCallError(
        onError,
        noNavigatorException('incoming call'),
        where: 'IncomingCallOverlay',
      );
      return;
    }

    // The session on screen, so a dismiss aimed at one call cannot take down
    // the overlay of another. See [dismiss].
    ActiveCallTracker.incomingCallSessionId = call.sessionId;
    final entry = OverlayEntry(
      // Below the status bar, the notch or the Dynamic Island: a fixed 40
      // put the card over the island and the clock on newer iPhones.
      builder: (context) => Positioned(
        top: (MediaQuery.maybePaddingOf(context)?.top ?? 0) + 8,
        left: 20.0,
        right: 20.0,
        child: Material(
          color: Colors.transparent,
          child: CometChatIncomingCall(
            call: call,
            user: user,
            onError: onError,
            onDecline: onDecline,
            onAccept: onAccept,
            disableSoundForCalls: disableSoundForCalls,
            customSoundForCalls: customSoundForCalls,
            customSoundForCallsPackage: customSoundForCallsPackage,
            incomingCallStyle: style,
            callSettingsBuilder: callSettingsBuilder,
            height: height,
            width: width,
            declineButtonText: declineButtonText,
            acceptButtonText: acceptButtonText,
            titleView: titleView,
            leadingView: leadingView,
            trailingView: trailingView,
            subTitleView: subtitleView,
            itemView: itemView,
          ),
        ),
      ),
    );

    // Insert above all existing entries so it appears on top of any route
    overlay.insert(entry);
    _overlayEntry = entry;
  }

  /// Takes the banner's entry off the screen, if there is one. Tolerates an
  /// entry already removed from outside.
  static void _removeEntry() {
    final entry = _overlayEntry;
    _overlayEntry = null;
    if (entry == null) return;
    try {
      entry.remove();
    } catch (e) {
      ccLog('IncomingCallOverlay: the entry was already removed: $e');
    }
  }

  /// Dismisses the incoming call overlay.
  ///
  /// Pass [sessionId] when the dismiss is about one particular call — a
  /// cancel or an end relayed by the SDK — and the overlay is then only
  /// removed if it is showing that call. The SDK broadcasts those events to
  /// every listener, so without the check a cancel for some other call (or
  /// one that lands just after a new call rang) dismissed the call on screen.
  /// Kotlin checks the session the same way before dismissing.
  ///
  /// The call whose banner is removed, and the call [sessionId] names, stop
  /// counting as ringing on this device, so the next incoming call is not
  /// answered busy because of them. Before, a host dismissing the banner
  /// itself (on a push cancel, say) left the device "busy" until that call's
  /// cancel arrived over the socket, which may never happen. The call is not
  /// declined on the server.
  ///
  /// The call [sessionId] names is over for this device: it is remembered
  /// as finished for two minutes, so a late copy of its "initiated" (after
  /// a socket reconnect, or from a duplicate push) does not ring again, and
  /// an accept of it still waiting for the permission prompt is not sent. A
  /// dismiss with no [sessionId] (a host taking the banner down, from its
  /// `onAccept` say) only takes it off the screen: an accept under way goes
  /// on.
  static void dismiss({String? sessionId}) {
    final named = sessionId != null && sessionId.isNotEmpty;
    final onScreen = ActiveCallTracker.incomingCallSessionId;
    if (named &&
        _overlayEntry != null &&
        onScreen != null &&
        onScreen != sessionId) {
      ccLog(
        'IncomingCallOverlay: not dismissing $onScreen for an event about '
        '$sessionId',
      );
      ActiveCallTracker.ringingEnded(sessionId);
      return;
    }
    final hadBanner = _overlayEntry != null;
    if (hadBanner) {
      ccLog('IncomingCallOverlay.dismiss() stack: ${StackTrace.current}');
    }
    _removeEntry();
    ActiveCallTracker.incomingCallSessionId = null;
    if (hadBanner) ActiveCallTracker.releaseRinging(onScreen);
    if (named) ActiveCallTracker.ringingEnded(sessionId);
  }
}
