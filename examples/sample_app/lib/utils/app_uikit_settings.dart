import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:sample_app/app_credentials.dart';
import 'package:sample_app/utils/call_debug_switches.dart';
import 'package:sample_app/utils/call_error_snackbar.dart';

/// The [UIKitSettings] for every `CometChatUIKit.init` in this app, built
/// from the current [AppCredentials].
///
/// main.dart inits the UI Kit at launch and AppCredentialsScreen inits it
/// again after new credentials are saved. Both use this (the screen gets it
/// as its `buildSettings`), so calls, the calling configuration, the hosts
/// and thread subscription are the same whichever screen ran the init.
UIKitSettings buildAppUIKitSettings() {
  final settingsBuilder = UIKitSettingsBuilder()
    ..subscriptionType = CometChatSubscriptionType.allUsers
    ..region = AppCredentials.region
    ..autoEstablishSocketConnection = true
    ..appId = AppCredentials.appId
    ..authKey = AppCredentials.authKey
    ..adminHost = AppCredentials.adminHost
    ..clientHost = AppCredentials.clientHost;

  // Calls SDK — all platforms (including web with beta). The UI Kit starts
  // call handling itself on init and login, and every call component reads
  // this configuration: the message header's call buttons, the meeting
  // bubble, the outgoing and incoming call screens and the call screen they
  // open. Their errors show as SnackBars; see call_error_snackbar.dart.
  settingsBuilder
    ..enableCalls = true
    ..callingConfiguration = CallingConfiguration(
      callButtonsConfiguration: CallButtonsConfiguration(
        onError: showCallButtonsError,
        // Null unless --dart-define=CC_CALL_SETTINGS=1: see
        // CallDebugSwitches.
        callSettingsBuilder: CallDebugSwitches.callSettingsBuilder,
      ),
      outgoingCallConfiguration: CometChatOutgoingCallConfiguration(
        onError: showInCallError,
      ),
      // The ringtone and hook switches for the device checks: see
      // CallDebugSwitches (--dart-define=CC_RINGTONE / CC_CALL_HOOKS).
      incomingCallConfiguration: CallDebugSwitches.incomingCallConfiguration(
        onError: showInCallError,
      ),
      // Null unless --dart-define=CC_GROUP_SETTINGS=1: see
      // CallDebugSwitches.
      groupSessionSettingsBuilder:
          CallDebugSwitches.groupSessionSettingsBuilder,
    );

  // Thread subscription (ENG-37601): the feature gate defaults to OFF in
  // the kit; the master app opts in so both follow/unfollow surfaces
  // (message action sheet + threaded header) are exercisable.
  settingsBuilder.enableThreadSubscription = true;

  return settingsBuilder.build();
}
