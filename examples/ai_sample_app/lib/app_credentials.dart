import 'package:shared_preferences/shared_preferences.dart';

/// CometChat app credentials for the public sample app.
///
/// Unlike the internal master_app, nothing is hardcoded here: the defaults are
/// blank and the real values are entered on [AppCredentialsScreen] at first
/// launch, then read back from SharedPreferences. The keys below are the ones
/// that screen writes — keep them in step.
///
/// This file is TRACKED and mirrored verbatim by release-to-public.yml. It is
/// not generated, and not derived from master_app's version by deletion. See
/// the header of lib/main.dart for why.
class AppCredentials {
  AppCredentials._();

  // Blank on purpose. A published sample app ships no credentials; the user
  // supplies their own from the CometChat dashboard.
  static const String _defaultAppId = '';
  static const String _defaultRegion = '';
  static const String _defaultAuthKey = '';

  // ── Runtime values, overridden from SharedPreferences ────────────────────
  static String _appId = _defaultAppId;
  static String _region = _defaultRegion;
  static String _authKey = _defaultAuthKey;

  static String get appId => _appId;
  static String get region => _region;
  static String get authKey => _authKey;

  /// True once all three values are present, which is what gates the
  /// credentials screen in [main.dart].
  static bool get hasValidCredentials =>
      _appId.isNotEmpty && _region.isNotEmpty && _authKey.isNotEmpty;

  /// Always null here.
  ///
  /// master_app can point at CometChat's staging environment, which needs
  /// these two hosts. The public sample always talks to production, so the
  /// UI Kit's own defaults apply. They are kept as members rather than removed
  /// because lib/utils/app_uikit_settings.dart reads both — returning null is
  /// how that file asks for the default host.
  static String? get adminHost => null;
  static String? get clientHost => null;

  // Keys written by AppCredentialsScreen. Changing one here without changing
  // it there silently loses the user's saved credentials on next launch.
  static const String _keyAppId = 'cc_app_id';
  static const String _keyRegion = 'cc_region';
  static const String _keyAuthKey = 'cc_auth_key';

  /// Load whatever the user previously entered. Called before `runApp`, so the
  /// first frame already knows whether to show the credentials screen.
  static Future<void> loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    _appId = prefs.getString(_keyAppId) ?? _defaultAppId;
    _region = prefs.getString(_keyRegion) ?? _defaultRegion;
    _authKey = prefs.getString(_keyAuthKey) ?? _defaultAuthKey;
  }
}
