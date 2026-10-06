import 'package:flutter/material.dart';
import '../../../cometchat_calls_uikit.dart';
import '../../../cometchat_chat_uikit.dart';

///[CometChatIncomingCallConfiguration] configures the incoming call banner
/// the UI Kit shows (see `CometChatIncomingCall`), through
/// `CallingConfiguration.incomingCallConfiguration`.
///
/// ```dart
/// CometChatIncomingCallConfiguration(
///   onError: (e) => debugPrint('${e.code}: ${e.message}'),
///   customSoundForCalls: 'assets/sounds/ringtone.wav', // the app's own asset
///   onDecline: (context, call) => debugPrint('Declined ${call.sessionId}'),
///   declineButtonText: 'Decline',
///   acceptButtonText: 'Accept',
///   incomingCallStyle: CometChatIncomingCallStyle(
///     backgroundColor: Colors.white,
///   ),
/// )
/// ```
class CometChatIncomingCallConfiguration {
  CometChatIncomingCallConfiguration({
    this.onError,
    this.disableSoundForCalls,
    this.customSoundForCalls,
    this.customSoundForCallsPackage,
    this.onDecline,
    this.onAccept,
    this.incomingCallStyle,
    this.callSettingsBuilder,
    this.acceptButtonText,
    this.declineButtonText,
    this.height,
    this.width,
    this.titleView,
    this.subTitleView,
    this.leadingView,
    this.itemView,
    this.trailingView,
  });

  /// Called when something about this call fails:
  ///
  /// * the SDK's own exception, code kept, when accepting or declining
  ///   fails, including when the call was already over (cancelled, ended,
  ///   declined or answered on another device) by the time the request
  ///   landed;
  /// * `PERMISSION_DENIED` / `PERMISSION_PERMANENTLY_DENIED` when microphone
  ///   or camera access was refused on accept (a video call needs both);
  ///   `details` lists the missing permissions. The call is declined;
  /// * `HOST_CALLBACK_ERROR` when [onAccept] or [onDecline] throws something
  ///   other than a `CometChatException` (which is passed on as it is);
  /// * whatever the call screen then reports: see
  ///   `CometChatOngoingCall.onError`;
  /// * `NO_NAVIGATOR` when the incoming call banner cannot be shown because
  ///   `CallNavigationContext.navigatorKey` has no navigator. The call is
  ///   not declined.
  ///
  /// Without one, the banner shows "Something went wrong" for a failure,
  /// except for a call that was already over, and a refused permission is
  /// explained in a SnackBar (with a way to the app's settings when the
  /// system will not ask again).
  final OnError? onError;

  /// Turns the ringtone and the vibration off.
  ///
  /// Otherwise the call rings as the phone's own ringer would for a caller
  /// who is not a phone contact:
  ///
  /// * Android: at the ring volume, silent in Silent and Vibrate mode and at
  ///   ring volume 0. Under Do Not Disturb it rings only when DND lets calls
  ///   from anyone through (DND's allowed-contacts list cannot include the
  ///   caller), and otherwise neither rings nor vibrates. It vibrates
  ///   always in Vibrate mode, never in Silent mode, and in Sound mode as
  ///   the phone's "Vibrate while ringing" (or ramping ringer, or from
  ///   Android 13 the ring vibration intensity) says; the settings differ
  ///   by maker. It keeps ringing in the background, up to the 60 s limit.
  /// * iOS: from the loudspeaker (or a headset), silent with the Ring/Silent
  ///   switch on Silent, vibrating every 2 seconds, at the media volume, and
  ///   pausing other apps' audio. It rings only while the app is in the
  ///   foreground and unlocked; back in the foreground it rings again if the
  ///   call still rings and is within 60 s of the ring's start. Focus modes
  ///   do not silence it.
  ///
  /// Over a group meeting it plays quieter and leaves the meeting's audio
  /// alone; on iOS it then plays through the meeting's audio, so the
  /// Ring/Silent switch does not silence it and it may not vibrate.
  ///
  /// While it rings, message sounds and other one-shot sounds are skipped.
  /// With [disableSoundForCalls] nothing rings, and they play as usual.
  final bool? disableSoundForCalls;

  /// The ringtone to play instead of the UI Kit's own: an asset path, from
  /// [customSoundForCallsPackage]'s assets, or the app's own when that is
  /// null.
  final String? customSoundForCalls;

  /// The package whose assets hold [customSoundForCalls]: set it only for a
  /// sound another package ships. A sound not found there is looked for in
  /// the app's own assets, and the UI Kit's ringtone plays when it is not
  /// found at all.
  final String? customSoundForCallsPackage;

  /// Called at the Decline tap, with the navigator's context
  /// (`CallNavigationContext.navigatorKey`), before the decline goes to the
  /// server. Not called without that navigator, or for a tap that is
  /// ignored (the first tap wins). A side effect: the decline goes ahead
  /// whatever it does, and what it throws goes to [onError]. The UI Kit
  /// stops the ringtone and closes the banner itself.
  final Function(BuildContext, Call)? onDecline;

  /// Called at the Accept tap, as [onDecline], before the permission
  /// request and the accept. The accept goes ahead whatever it does, even
  /// if it takes the banner down with `IncomingCallOverlay.dismiss()`; a
  /// dismiss that names this call's session counts as the call being over
  /// here, and nothing is sent.
  final Function(BuildContext, Call)? onAccept;

  ///[incomingCallStyle] is used to set a custom incoming call style
  final CometChatIncomingCallStyle? incomingCallStyle;

  ///[callSettingsBuilder] is used to set the session settings (V5)
  final SessionSettingsBuilder? callSettingsBuilder;

  ///[declineButtonText] is used to set a custom decline text
  final String? declineButtonText;

  ///[acceptButtonText] is used to set a custom accept text
  final String? acceptButtonText;

  ///[height] is used to set the height of the widget.
  final double? height;

  ///[width] is used to set the width of the widget.
  final double? width;

  ///[titleView] is used to define the title view.
  final Widget? Function(BuildContext, Call)? titleView;

  ///[subTitleView] is used to define the subtitle view.
  final Widget? Function(BuildContext, Call)? subTitleView;

  ///[leadingView] is used to define the leading view.
  final Widget? Function(BuildContext, Call)? leadingView;

  ///[itemView] is used to define the item view.
  final Widget? Function(BuildContext, Call)? itemView;

  ///[trailingView] is used to define the trailing view.
  final Widget? Function(BuildContext, Call)? trailingView;
}
