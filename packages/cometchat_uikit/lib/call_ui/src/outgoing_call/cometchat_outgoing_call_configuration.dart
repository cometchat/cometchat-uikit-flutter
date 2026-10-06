import 'package:flutter/material.dart';
import '../../../cometchat_calls_uikit.dart';
import '../../../cometchat_chat_uikit.dart';

///[CometChatOutgoingCallConfiguration] is a data class that has configuration properties for  [CometChatOutgoingCall]
///
/// ```dart
/// CometChatOutgoingCallConfiguration(
///   subtitleView: (context, call) => const Text('Calling…'),
///   declineButtonIcon: const Icon(Icons.call_end),
///   outgoingCallStyle: CometChatOutgoingCallStyle(
///     backgroundColor: Colors.black,
///   ),
///   onError: (error) => debugPrint('Call error: $error'),
///   // The app's own asset: no package.
///   customSoundForCalls: 'assets/sounds/ringback.mp3',
/// );
/// ```
///
class CometChatOutgoingCallConfiguration {
  CometChatOutgoingCallConfiguration({
    this.subtitleView,
    this.onCancelled,
    this.disableSoundForCalls,
    this.customSoundForCalls,
    this.customSoundForCallsPackage,
    this.onError,
    this.outgoingCallStyle,
    this.sessionSettingsBuilder,
    this.width,
    this.height,
    this.declineButtonIcon,
    this.avatarView,
    this.titleView,
    this.cancelledView,
  });

  ///[subtitleView] is used to define the subtitle for the widget.
  final Widget? Function(BuildContext, Call)? subtitleView;

  /// Called when End is tapped, instead of the UI Kit's own cancel: the
  /// app then cancels the call itself, and End stays live.
  ///
  /// The ringback plays on until the call ends, the screen closes, or the
  /// app calls `CometChatUIKit.soundManager.stop()`, which stops it as in
  /// 6.1.x. A call left ringing is still given up after 45 seconds. End
  /// wins does not apply: an accept that arrives after this tap is still
  /// joined, since the UI Kit does not know whether the app ended the call.
  final Function(BuildContext, Call)? onCancelled;

  /// Whether the outgoing call screen plays no ringback. See
  /// [CometChatOutgoingCall.disableSoundForCalls].
  final bool? disableSoundForCalls;

  /// The ringback to play instead of the UI Kit's own: a Flutter asset path.
  /// See [CometChatOutgoingCall.customSoundForCalls] for how it plays.
  final String? customSoundForCalls;

  /// The Flutter package that ships [customSoundForCalls]. Leave it null
  /// for an asset of the app's own. See
  /// [CometChatOutgoingCall.customSoundForCallsPackage].
  final String? customSoundForCallsPackage;

  /// Called when something about this call fails:
  ///
  /// * the SDK's own exception, code kept, when cancelling fails (End, or a
  ///   screen removed while the call rang), or giving up after 45 seconds
  ///   unanswered does. The call is usually already over by then: declined,
  ///   answered at that moment, or ended by the server. It still comes when
  ///   that answer arrives after the screen has closed, but not once a
  ///   logout has begun;
  /// * `PERMISSION_DENIED` / `PERMISSION_PERMANENTLY_DENIED` when the callee
  ///   answered but microphone or camera access was refused here; `details`
  ///   lists the missing permissions;
  /// * a platform error, its code kept, when asking for those permissions
  ///   fails (a request already running, say);
  /// * `NO_NAVIGATOR` when the callee answered but
  ///   `CallNavigationContext.navigatorKey` has no navigator to show the
  ///   call screen on;
  /// * whatever the call screen then reports: see
  ///   `CometChatOngoingCall.onError`.
  final OnError? onError;

  ///[outgoingCallStyle] is used to set a custom incoming call style
  final CometChatOutgoingCallStyle? outgoingCallStyle;

  ///[sessionSettingsBuilder] is used to set the session settings (V5)
  final SessionSettingsBuilder? sessionSettingsBuilder;

  ///[height] is used to set the height of the widget.
  final double? height;

  ///[width] is used to set the width of the widget.
  final double? width;

  ///[declineButtonIcon] is used to define the decline button icon for the widget.
  final Widget? declineButtonIcon;

  ///[avatarView] is used to define the avatar view.
  final Widget? Function(BuildContext, Call)? avatarView;

  ///[titleView] is used to define the avatar view.
  final Widget? Function(BuildContext, Call)? titleView;

  ///[cancelledView] is used to define the cancelled view.
  final Widget? Function(BuildContext, Call)? cancelledView;
}
