import 'package:flutter/foundation.dart';

import '../call_ui/src/calling_configuration.dart';
import '../shared_ui/src/cometchat_ui_kit/cometchat_ui_kit.dart';
import '../shared_ui/src/logging/cometchat_log.dart';

/// The one [CallingConfiguration] the call UI reads: the incoming call
/// banner, the message header's call buttons and the meeting bubble.
///
/// Package-private (see `lib/src/`).
///
/// `UIKitSettings.callingConfiguration` wins. When it is not set, the first
/// non-null configuration a host passed to `CallEventService.init` is used.
/// A later `init(configuration:)` no longer replaces it (it used to, so the
/// banner showed whichever init ran last), and the UI Kit's own start at
/// login never fills it.
abstract final class CallingConfigurationResolver {
  static CallingConfiguration? _hostConfiguration;
  static bool _loggedIgnored = false;

  /// The configuration in effect.
  static CallingConfiguration? get resolved =>
      CometChatUIKit.authenticationSettings?.callingConfiguration ??
      _hostConfiguration;

  /// Records [configuration] as the host's, when it is the first non-null
  /// one since the last [clearHostConfiguration]. Logs once when it is not
  /// the one in effect.
  static void offerHostConfiguration(CallingConfiguration? configuration) {
    if (configuration == null) return;
    _hostConfiguration ??= configuration;
    final inEffect = resolved;
    if (!identical(inEffect, configuration) && !_loggedIgnored) {
      _loggedIgnored = true;
      ccLog(
        'CallEventService.init(configuration:) ignored: '
        '${CometChatUIKit.authenticationSettings?.callingConfiguration != null ? 'UIKitSettings.callingConfiguration is set and wins' : 'the first configuration passed to init() is kept'}. '
        'Set UIKitSettings.callingConfiguration instead.',
      );
    }
  }

  /// Forgets the host's configuration (logout, user switch).
  static void clearHostConfiguration() {
    _hostConfiguration = null;
    _loggedIgnored = false;
  }

  /// The host configuration on record, for tests.
  @visibleForTesting
  static CallingConfiguration? get debugHostConfiguration => _hostConfiguration;
}
