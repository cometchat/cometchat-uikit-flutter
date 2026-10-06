import 'package:cometchat_chat_uikit/cometchat_calls_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter/material.dart';

/// Debug switches for the calls, set at build time with `--dart-define`, so
/// the ringtone and hook checks (round 3: P3-N15, P3-N16, P3-N17) and the
/// meeting settings checks (round 5: P5-C05) need no code change:
///
/// ```sh
/// flutter run --dart-define=CC_RINGTONE=custom   # assets/custom_ring.wav
/// flutter run --dart-define=CC_RINGTONE=off      # no ringtone, no vibration
/// flutter run --dart-define=CC_CALL_HOOKS=1      # SnackBars from the hooks
/// flutter run --dart-define=CC_GROUP_SETTINGS=1  # one shared meeting builder
/// flutter run --dart-define=CC_CALL_SETTINGS=1   # a callSettingsBuilder
/// ```
///
/// Without them master_app behaves as before: the UI Kit's ringtone, no
/// hooks, and the UI Kit's own call and meeting settings.
class CallDebugSwitches {
  CallDebugSwitches._();

  /// `default`, `custom` or `off`.
  static const String ringtone = String.fromEnvironment(
    'CC_RINGTONE',
    defaultValue: 'default',
  );

  /// Whether the incoming call's onAccept / onDecline hooks show a SnackBar.
  static const bool callHooks =
      String.fromEnvironment('CC_CALL_HOOKS', defaultValue: '0') == '1';

  /// master_app's own short ringtone, in its assets.
  static const String customRingtone = 'assets/custom_ring.wav';

  /// Whether every meeting, the host's and each member's Join, uses one
  /// shared `CallingConfiguration.groupSessionSettingsBuilder`
  /// ([groupSessionSettingsBuilder]): the spotlight layout, titled
  /// "groupSessionSettingsBuilder". Before round 5 an audio Join wrote its
  /// audio flags into that builder, so a later video Join started with the
  /// camera paused; and the host never used it.
  static const bool groupSettings =
      String.fromEnvironment('CC_GROUP_SETTINGS', defaultValue: '0') == '1';

  /// Whether `CallButtonsConfiguration.callSettingsBuilder` is set
  /// ([callSettingsBuilder]): a new builder for every call or meeting, the
  /// sidebar layout, titled "callSettingsBuilder". For a meeting it wins
  /// over [groupSettings], for the host and (since round 5) for a Join. It
  /// also applies to the 1-on-1 calls the chat header places, with the
  /// call's type on top (round 4).
  static const bool callSettings =
      String.fromEnvironment('CC_CALL_SETTINGS', defaultValue: '0') == '1';

  /// The one builder [groupSettings] shares, or null when it is off.
  static final SessionSettingsBuilder? groupSessionSettingsBuilder =
      groupSettings
      ? (SessionSettingsBuilder()
          ..setLayout(LayoutType.spotlight)
          ..setTitle('groupSessionSettingsBuilder'))
      : null;

  /// The builder factory [callSettings] sets, or null when it is off.
  static SessionSettingsBuilder Function(
    User? user,
    Group? group,
    bool? isAudioOnly,
  )?
  get callSettingsBuilder => callSettings
      ? (User? user, Group? group, bool? isAudioOnly) =>
            SessionSettingsBuilder()
              ..setLayout(LayoutType.sidebar)
              ..setTitle('callSettingsBuilder')
      : null;

  /// The incoming call configuration master_app uses, with [onError] and
  /// the switches above applied.
  static CometChatIncomingCallConfiguration incomingCallConfiguration({
    required OnError onError,
    String ringtoneSwitch = ringtone,
    bool hooks = callHooks,
  }) {
    return CometChatIncomingCallConfiguration(
      onError: onError,
      // No package: the app's own asset.
      customSoundForCalls: ringtoneSwitch == 'custom' ? customRingtone : null,
      disableSoundForCalls: ringtoneSwitch == 'off' ? true : null,
      onAccept: hooks ? (context, _) => _hookFired(context, 'onAccept') : null,
      onDecline: hooks
          ? (context, _) => _hookFired(context, 'onDecline')
          : null,
    );
  }

  static void _hookFired(BuildContext context, String hook) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$hook hook fired'),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}
