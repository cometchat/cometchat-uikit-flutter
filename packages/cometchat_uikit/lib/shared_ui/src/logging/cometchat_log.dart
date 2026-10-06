import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Release-safe logging for the UI Kit's own diagnostics.
///
/// Every call is compiled out of release and profile builds, so nothing the UI
/// Kit logs can reach a production device log. This matters beyond noise: log
/// lines here have carried tokens and message contents in the past.
///
/// Output goes to a named `dart:developer` channel so a host app can filter
/// the UI Kit's chatter out of its own logs.
///
/// Internal — deliberately not exported from any public barrel.
void ccLog(Object? message) {
  if (!kDebugMode) return;
  developer.log('$message', name: 'cometchat_uikit');
}

/// [ccLog], and in debug builds the console too (`debugPrint`): for the few
/// lines the call device checks read in `flutter run`, logcat or the Xcode
/// console, which `dart:developer` logging does not reach (round 4 review).
/// Compiled out of release and profile builds, like [ccLog].
void ccLogConsole(Object? message) {
  if (!kDebugMode) return;
  developer.log('$message', name: 'cometchat_uikit');
  debugPrint('cometchat_uikit: $message');
}
