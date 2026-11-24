/// CometChat credentials and test user configuration for E2E tests.
///
/// Values are read from `--dart-define` flags at build time.
/// The fallbacks below are placeholders — supply real values via `--dart-define`.
/// Never commit real keys to this file.
///
/// Usage:
///   flutter test integration_test/e2e_test.dart -d emulator-5554 \
///     --dart-define=COMETCHAT_APP_ID=xxx \
///     --dart-define=COMETCHAT_REGION=us \
///     --dart-define=COMETCHAT_AUTH_KEY=xxx \
///     --dart-define=COMETCHAT_REST_API_KEY=xxx
class TestCredentials {
  TestCredentials._();

  // ─── CometChat App ─────────────────────────────────────────────────────────

  static const String appId = String.fromEnvironment(
    'COMETCHAT_APP_ID',
    defaultValue: '',
  );

  static const String region = String.fromEnvironment(
    'COMETCHAT_REGION',
    defaultValue: '', // e.g. us, eu, in
  );

  static const String authKey = String.fromEnvironment(
    'COMETCHAT_AUTH_KEY',
    defaultValue: '',
  );

  static const String restApiKey = String.fromEnvironment(
    'COMETCHAT_REST_API_KEY',
    defaultValue: '',
  );

  // ─── User A: The UI user (drives the Flutter app) ──────────────────────────

  static const String userAUid = String.fromEnvironment(
    'TEST_USER_A_UID',
    defaultValue: '',
  );

  static const String userAName = String.fromEnvironment(
    'TEST_USER_A_NAME',
    defaultValue: '',
  );

  // ─── User B: The SDK-only user (headless, no UI) ───────────────────────────

  static const String userBUid = String.fromEnvironment(
    'TEST_USER_B_UID',
    defaultValue: '',
  );

  static const String userBName = String.fromEnvironment(
    'TEST_USER_B_NAME',
    defaultValue: '',
  );

  // ─── Test Group ────────────────────────────────────────────────────────────

  static const String testGroupGuid = String.fromEnvironment(
    'TEST_GROUP_GUID',
    defaultValue: '',
  );

  static const String testGroupName = String.fromEnvironment(
    'TEST_GROUP_NAME',
    defaultValue: '',
  );

  // ─── REST API base URL ─────────────────────────────────────────────────────

  /// True when the app under test is a staging app
  /// (`--dart-define=COMETCHAT_STAGING=true`). REST calls then go to the
  /// staging host. Defaults to production, as before.
  static const bool staging = bool.fromEnvironment('COMETCHAT_STAGING');

  /// The offline E2E suite (patrol_test/, ENG-41597) sets this to the host-side
  /// User B relay (`http://127.0.0.1:<port>`, mapped in with `adb reverse`), so
  /// User B's REST calls still work while the test has cut the device's
  /// network. The relay adds the REST host and keys itself. Unset (the
  /// default), REST calls go straight to the REST host, as before.
  static const String userBRelayUrl =
      String.fromEnvironment('E2E_USER_B_RELAY_URL');

  static String get restBaseUrl => userBRelayUrl.isNotEmpty
      ? userBRelayUrl
      : staging
          ? 'https://$appId.api-$region.cometchat.io/v3'
          : 'https://$appId.api-$region.cometchat.io/v3';
}
