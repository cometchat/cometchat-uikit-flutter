import 'package:flutter/material.dart';
import '../../../cometchat_calls_uikit.dart';
import '../../../cometchat_chat_uikit.dart';

///[CallButtonsConfiguration] is a data class that has configuration properties
///
/// ```dart
/// CallButtonsConfiguration(
///  callButtonsStyle: CometChatCallButtonsStyle(),
///  onError: (error) {
///  // Handle error
///  },
///  outgoingCallConfiguration: CometChatOutgoingCallConfiguration(),
///  hideVideoCall: false,
/// );
///
class CallButtonsConfiguration {
  CallButtonsConfiguration({
    this.callButtonsStyle,
    this.onError,
    this.outgoingCallConfiguration,
    this.hideVideoCallButton,
    this.hideVoiceCallButton,
    this.voiceCallIcon,
    this.videoCallIcon,
    this.callSettingsBuilder,
  });

  ///[callButtonsStyle] is a object of [CometChatCallButtonsStyle] which sets the style for the call buttons
  final CometChatCallButtonsStyle? callButtonsStyle;

  /// Errors from starting or joining calls: called when a call or meeting
  /// cannot be placed, started or joined:
  ///
  /// * `ACTIVE_CALL`: another call is in progress on this device, a group
  ///   meeting is on the call screen, or a call is being placed from
  ///   another call component (one at a time);
  /// * `NO_NAVIGATOR`: `CallNavigationContext.navigatorKey` has no navigator
  ///   to show the call on. Checked before anything is placed or sent; if
  ///   the navigator goes while a call is being placed, the call is
  ///   cancelled;
  /// * `PERMISSION_DENIED` / `PERMISSION_PERMANENTLY_DENIED`: microphone (or
  ///   camera) access was refused; `details` lists the missing permissions;
  /// * `CALLS_NOT_READY`: a meeting was not started because the Calls SDK
  ///   is not initialised or not logged in; its message was not sent;
  /// * the SDK's own exception, code kept, when placing the call or sending
  ///   a meeting's message fails (or cancelling a call that could not be
  ///   shown);
  /// * a platform error, its code kept, when asking for permissions fails
  ///   (a request already running, say);
  /// * for a meeting, whatever its call screen reports: see
  ///   `CometChatOngoingCall.onError`.
  ///
  /// The buttons are off from the tap until the call's screen is up (or it
  /// has failed); a tap in that time is dropped. A meeting's screen opens
  /// only once its message is sent. A call placed, or a meeting announced,
  /// while the chat closed still gets its screen, so this can be called
  /// after the buttons are gone.
  ///
  /// Also what a meeting joined from its message bubble reports to:
  /// `ACTIVE_CALL`, `NO_NAVIGATOR`, a [callSettingsBuilder] that throws,
  /// and what the meeting's call screen reports.
  final OnError? onError;

  ///[outgoingCallConfiguration] is a object of [CometChatOutgoingCallConfiguration] which sets the configuration for outgoing call
  final CometChatOutgoingCallConfiguration? outgoingCallConfiguration;

  ///[hideVoiceCallButton] is a bool which hides the voice call icon
  final bool? hideVoiceCallButton;

  ///[hideVideoCallButton] is a bool which hides the video call icon
  final bool? hideVideoCallButton;

  ///[voiceCallIcon] is a Widget which sets the icon for the voice call
  final Widget? voiceCallIcon;

  ///[videoCallIcon] is a Widget which sets the icon for the video call
  final Widget? videoCallIcon;

  /// The session settings for a call placed, or a meeting started, from the
  /// message header's call buttons, and for a meeting joined from its
  /// bubble. It gets the user or the group, and whether the call is voice
  /// only. For a meeting it wins over
  /// `CallingConfiguration.groupSessionSettingsBuilder`.
  final SessionSettingsBuilder Function(
    User? user,
    Group? group,
    bool? isAudioOnly,
  )?
  callSettingsBuilder;
}
