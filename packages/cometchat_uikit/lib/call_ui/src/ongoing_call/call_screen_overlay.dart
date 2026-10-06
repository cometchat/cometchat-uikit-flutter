import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../cometchat_calls_uikit.dart';
import '../../../cometchat_chat_uikit.dart';
import '../../../shared_ui/src/logging/cometchat_log.dart';
import '../../../src/active_call_tracker.dart';
import '../../../src/busy_reject.dart';
import '../../../src/call_errors.dart';

/// Launches [CometChatOngoingCall] in a completely isolated widget tree
/// (its own [MaterialApp] inside an [OverlayEntry]).
///
/// This decouples the call screen from the host app's navigation stack:
/// - Own [Navigator]: the call screen is not one of the app's routes (while
///   it is up, a pop entry on the app's top route keeps back off the app's
///   screens: see [show])
/// - Own [BuildContext] — no dependency on the app's widget tree
/// - Own theme; the app's language (the locale of the app's navigator)
///
/// Usage:
/// ```dart
/// // Show the call screen
/// CallScreenOverlay.show(
///   sessionId: 'abc123',
///   sessionSettingsBuilder: SessionSettingsBuilder()..setLayout(LayoutType.tile),
/// );
///
/// // Dismiss when the call ends
/// CallScreenOverlay.dismiss(sessionId: 'abc123');
/// ```
class CallScreenOverlay {
  CallScreenOverlay._();

  /// The entry on screen. Only ever an entry that was inserted, so
  /// [dismiss] can always remove it.
  static OverlayEntry? _entry;

  /// Keeps the back button off the app's own screens while a call screen is
  /// up: see [show].
  static _CallScreenBackGuard? _backGuard;

  /// Whether the overlay is currently showing.
  static bool get isShowing => _entry != null;

  /// Show the ongoing call screen in an isolated overlay.
  ///
  /// If an overlay is already showing, it is dismissed first. Except for
  /// the same meeting: a [CallWorkFlow.directCalling] screen for
  /// [sessionId] that is already up stays as it is, and this call does
  /// nothing ([sessionSettingsBuilder] and [onError] are not used). Showing
  /// it again used to tear the live meeting screen down and join the
  /// meeting a second time. A 1-on-1 call shown again still replaces its
  /// screen.
  ///
  /// The screen is inserted into the overlay of
  /// `CallNavigationContext.navigatorKey`. When that key has no navigator,
  /// nothing is kept: [isShowing] stays false, the call's record is released
  /// so the device is not left "in a call" with nothing on screen, and
  /// [onError] gets `NO_NAVIGATOR`. Nothing is sent to the server.
  ///
  /// An incoming call still ringing on this device when the screen comes up
  /// for another call (one the user placed or answered, or a group meeting)
  /// is answered busy: its banner, which the call screen covers, closes and
  /// it stops ringing.
  ///
  /// While the screen is up the back button does nothing to the app's own
  /// screens underneath it: it used to reach the app's navigator first and
  /// close the screen the call was placed from (a chat, say) behind the
  /// call. While the call is still connecting, back cancels it (see
  /// [CometChatOngoingCall]); once it is connected, back does nothing.
  ///
  /// To do that, a pop entry is registered on the top route of
  /// `CallNavigationContext.navigatorKey`'s navigator while the screen is
  /// up. That route's own `PopScope` callbacks are then called with
  /// `didPop: false`, even with `canPop: true`, and `Navigator.maybePop()`
  /// on it does not pop. Not covered: routes pushed (or the top route
  /// replaced or popped) while the call screen is up, nested navigators
  /// (tabs, go_router shell routes), and a route whose own handler swallows
  /// back first.
  ///
  /// The screen follows the language of the app's navigator.
  ///
  /// [onError] also receives what the call screen reports while it runs:
  /// see [CometChatOngoingCall.onError] for the codes. An app that shows the
  /// call screen itself (after a VoIP or CallKit accept, say) should pass
  /// one: a failed join is otherwise silent.
  static void show({
    required String sessionId,
    required SessionSettingsBuilder sessionSettingsBuilder,
    CallWorkFlow? callWorkFlow,
    OnError? onError,
  }) {
    final workFlow = callWorkFlow ?? CallWorkFlow.defaultCalling;
    // The same meeting already on screen stays (round 5, D03 A): a second
    // Join on its bubble, or the host's call buttons once its message was
    // sent after the host joined from the bubble, tore the live screen
    // down and joined again. A 1-on-1 call shown again is still replaced
    // (round 4: an app re-shows a call it answered on another path).
    if (workFlow == CallWorkFlow.directCalling &&
        _entry != null &&
        ActiveCallTracker.callScreenWorkFlow == CallWorkFlow.directCalling &&
        ActiveCallTracker.callScreenSessionId == sessionId) {
      ccLog('CallScreenOverlay: meeting $sessionId is already on screen');
      return;
    }
    dismiss(); // clear any existing
    // Back is the new screen's to handle once its bloc is built. The
    // replaced screen's handler used to stay until that screen closed a
    // frame later, so a back in between cancelled the old call (round 4
    // review, correctness 13).
    ActiveCallTracker.callScreenBack = null;

    final navigator = CallNavigationContext.navigatorKey.currentState;
    final overlay = navigator?.overlay;
    if (navigator == null || overlay == null) {
      // It used to keep the entry and the session anyway: isShowing and
      // hasActiveCall stayed true with nothing on screen, every later call
      // was refused or answered busy, and the next show() or dismiss()
      // threw on removing an entry that was never inserted.
      ccLog(
        'CallScreenOverlay: no navigator overlay for call $sessionId. Set '
        'CallNavigationContext.navigatorKey as the navigatorKey of the '
        "app's MaterialApp.",
      );
      // Only a known session: an empty one would release every record.
      if (sessionId.isNotEmpty) ActiveCallTracker.release(sessionId);
      // A host callback that throws must not reach the caller: an accept
      // still has its bookkeeping to finish after this show().
      reportCallError(
        onError,
        noNavigatorException('call screen'),
        where: 'CallScreenOverlay',
      );
      return;
    }

    // A newer call screen: the one it replaces (for this call or another)
    // no longer owns the call. See ActiveCallTracker.callScreenGeneration.
    ActiveCallTracker.callScreenGeneration++;
    // What is on screen, for the call components that match events to it.
    ActiveCallTracker.callScreenSessionId = sessionId;
    ActiveCallTracker.callScreenWorkFlow = workFlow;

    final entry = OverlayEntry(
      builder: (BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        localizationsDelegates: Translations.localizationsDelegates,
        // The app's language: without these the overlay's own MaterialApp
        // resolved to en_US whatever the app's locale was.
        supportedLocales: Translations.supportedLocales,
        locale: Localizations.maybeLocaleOf(context),
        // English for a language the UI Kit does not ship. Flutter's own
        // resolution falls back to the first supported locale, which is
        // Arabic: an Italian app showed "Connecting..." in Arabic, right to
        // left (round 4 review).
        localeResolutionCallback: _callScreenLocale,
        home: CometChatOngoingCall(
          sessionSettingsBuilder: sessionSettingsBuilder,
          sessionId: sessionId,
          callWorkFlow: workFlow,
          onError: onError,
        ),
      ),
    );
    overlay.insert(entry);
    _entry = entry;
    _guardBack(navigator);

    // The user's own call is up: an incoming call still ringing under it is
    // answered busy.
    rejectRingingAsBusy(sessionId: sessionId);
  }

  /// The call screen's locale for the app's [locale]: the UI Kit's
  /// translation in that language (by language code), or English.
  static Locale _callScreenLocale(
    Locale? locale,
    Iterable<Locale> supportedLocales,
  ) {
    if (locale != null) {
      for (final Locale supported in supportedLocales) {
        if (supported.languageCode == locale.languageCode) return supported;
      }
    }
    return const Locale('en');
  }

  /// Dismiss the call screen overlay. Safe to call when nothing is showing.
  ///
  /// With [sessionId], only when the screen showing is that call's: a
  /// dismiss for a call that is over (its "call ended" arriving late, say)
  /// leaves the screen of a newer call alone. Without it, whatever call
  /// screen is showing goes.
  static void dismiss({String? sessionId}) {
    if (sessionId != null &&
        _entry != null &&
        ActiveCallTracker.callScreenSessionId != sessionId) {
      ccLog(
        'CallScreenOverlay: not dismissing '
        '${ActiveCallTracker.callScreenSessionId} for $sessionId',
      );
      return;
    }
    final entry = _entry;
    _entry = null;
    ActiveCallTracker.callScreenSessionId = null;
    ActiveCallTracker.callScreenWorkFlow = null;
    _backGuard?.remove();
    _backGuard = null;
    if (entry == null) return;
    try {
      entry.remove();
    } catch (e) {
      // Already removed from outside (its overlay was torn down). Nothing is
      // left to take off the screen; the state above is already cleared.
      ccLog('CallScreenOverlay: dismiss found the entry already removed: $e');
    }
  }

  /// Keeps back off the app's screens while the call screen is up.
  ///
  /// The app's navigator hears back before the call screen's own one does
  /// (the app registered first), and the call screen is not one of its
  /// routes: back closed the app's screen under the call. A pop entry on
  /// the app's top route turns that pop down and hands back to the call
  /// screen instead ([ActiveCallTracker.callScreenBack]).
  static void _guardBack(NavigatorState navigator) {
    try {
      Route<dynamic>? top;
      // The top route, without popping anything: the first route looked at
      // ends the walk.
      navigator.popUntil((Route<dynamic> route) {
        top = route;
        return true;
      });
      final route = top;
      if (route is! ModalRoute<dynamic>) return;
      final guard = _CallScreenBackGuard(route);
      route.registerPopEntry(guard);
      _backGuard = guard;
    } catch (e) {
      // The navigator busy with a change of its own, say: back then reaches
      // the call screen only when the app is on its first screen.
      ccLog('CallScreenOverlay: could not guard the back button: $e');
    }
  }
}

/// Turns down a pop of the app's top route while a call screen is up, and
/// hands back to the call screen.
final class _CallScreenBackGuard extends PopEntry<Object?> {
  _CallScreenBackGuard(this._route);

  final ModalRoute<dynamic> _route;

  final ValueNotifier<bool> _canPop = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get canPopNotifier => _canPop;

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (didPop) return;
    try {
      ActiveCallTracker.callScreenBack?.call();
    } catch (e) {
      ccLog('CallScreenOverlay: the call screen could not handle back: $e');
    }
  }

  void remove() {
    try {
      _route.unregisterPopEntry(this);
    } catch (e) {
      // The route is gone already: nothing is left to guard.
      ccLog('CallScreenOverlay: the back guard was already gone: $e');
    }
    _canPop.dispose();
  }
}
