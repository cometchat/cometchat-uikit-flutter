import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../shared_ui/src/constants/ui_kit_constants.dart';
import '../shared_ui/src/logging/cometchat_log.dart';

/// The call screen's hold on the screen orientation: portrait (either way
/// up) during the call, and afterwards what the app had before (round 4
/// review: API 4, native 8).
///
/// Package-private (see `lib/src/`).
///
/// * Android: the UI Kit's plugin saves the activity's own requested
///   orientation before it holds the activity in portrait, and puts exactly
///   that back: a manifest `android:screenOrientation`, or an orientation
///   the app set from code. Flutter's `setPreferredOrientations([])` maps to
///   "unspecified", which unlocked a manifest lock after every call and lost
///   an orientation set from code.
/// * iOS, and wherever the plugin cannot do it: `SystemChrome`, the two
///   portraits during the call and the empty list afterwards, which on iOS
///   is the orientations in Info.plist. An orientation the app set from code
///   cannot be read back there: the app sets it again when
///   `CallStateService.isActiveCall` turns false, which comes after the
///   release.
abstract final class CallOrientation {
  static const List<DeviceOrientation> _portrait = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ];

  static bool get _byPlugin =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Holds the screen in portrait for a call screen. [released] says
  /// whether that screen has given the orientation up meanwhile (it closed
  /// while the plugin was answering): then nothing is held.
  static Future<void> hold({required bool Function() released}) async {
    if (_byPlugin) {
      try {
        final bool? held = await UIConstants.channel.invokeMethod<bool>(
          'holdCallOrientation',
        );
        if (held == true) return;
      } catch (e) {
        ccLog('CallOrientation: the plugin could not hold the orientation: $e');
      }
      if (released()) return;
    }
    await SystemChrome.setPreferredOrientations(_portrait);
  }

  /// Gives the orientation back (see the class doc). Asked for at once,
  /// before the caller says the call is over, so an app that sets its own
  /// orientation then has the last word.
  static void release() {
    if (_byPlugin) {
      unawaited(_releaseByPlugin());
      return;
    }
    unawaited(
      SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]),
    );
  }

  static Future<void> _releaseByPlugin() async {
    try {
      final bool? released = await UIConstants.channel.invokeMethod<bool>(
        'releaseCallOrientation',
      );
      if (released == true) return;
    } catch (e) {
      ccLog('CallOrientation: the plugin could not give it back: $e');
    }
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
  }
}
