import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import '../call_ui/src/call_settings/call_navigation_context.dart';
import '../cometchat_chat_uikit.dart'
    show CometChatLocalize, CometChatThemeHelper;
import '../shared_ui/src/logging/cometchat_log.dart';

/// What the user sees when an incoming call cannot be answered because the
/// microphone (and the camera, for a video call) was refused, and the app
/// handles no call errors itself (no `onError`).
///
/// Package-private (see `lib/src/`). A SnackBar on the app's navigator
/// (`CallNavigationContext.navigatorKey`) says what is needed, with a
/// Settings action when the system will not ask again. Shown by the
/// deprecated incoming call screen when its Accept is refused, and for a call
/// answered on the push ringer's screen (ringing v2) whose call screen could
/// not join for the same reason: that screen closes first, so the SnackBar
/// shows on the app underneath.
abstract final class CallPermissionNotice {
  /// Shows the notice for a voice or a video ([isVideoCall]) call;
  /// [permanentlyDenied] adds the Settings action.
  static void show({
    required bool isVideoCall,
    required bool permanentlyDenied,
  }) {
    final context = CallNavigationContext.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final translations = CometChatLocalize.of(context);
    final colors = CometChatThemeHelper.getColorPalette(context);
    final typography = CometChatThemeHelper.getTypography(context);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: colors.error,
        content: Text(
          isVideoCall
              ? translations.cameraAndMicrophoneRequiredToAnswerCall
              : translations.microphoneRequiredToAnswerCall,
          style: TextStyle(
            color: colors.white,
            fontSize: typography.button?.medium?.fontSize,
            fontWeight: typography.button?.medium?.fontWeight,
            fontFamily: typography.button?.medium?.fontFamily,
          ),
        ),
        action: permanentlyDenied
            ? SnackBarAction(
                label: translations.settings,
                textColor: colors.white,
                onPressed: () => unawaited(_openSettings()),
              )
            : null,
      ),
    );
  }

  static Future<void> _openSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      ccLog('CallPermissionNotice: could not open the app settings: $e');
    }
  }
}
