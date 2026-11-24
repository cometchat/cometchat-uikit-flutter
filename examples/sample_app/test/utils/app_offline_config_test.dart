import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sample_app/app_credentials.dart';
import 'package:sample_app/utils/app_uikit_settings.dart';

/// D86, D92: master_app always runs with offline on and an encrypted offline
/// cache. There is no setting that turns either off, so whatever an older
/// build left in prefs has no effect.
void main() {
  /// A launch: main.dart loads the saved credentials, then inits the UI Kit.
  Future<UIKitSettings> launch(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    await AppCredentials.loadSavedCredentials();
    return buildAppUIKitSettings();
  }

  void expectOfflineAndEncryptionOn(OfflineConfig? config) {
    expect(config, isNotNull);
    expect(config!.enabled, isTrue);
    expect(config.encryption, isTrue);
    // Encryption that cannot run never falls back to a plaintext cache.
    expect(
      config.encryptionFailureBehavior,
      EncryptionFailureBehavior.onlineOnly,
    );
  }

  test('appOfflineConfig: offline on, encryption on', () {
    expectOfflineAndEncryptionOn(appOfflineConfig());
  });

  test('fresh install: the UI Kit init gets offline and encryption on',
      () async {
    expectOfflineAndEncryptionOn((await launch({})).offlineConfig);
  });

  test('upgrade from a build that stored the switches off: still on',
      () async {
    // The keys the removed switches were saved under (D86, before D92).
    for (final stored in [
      {'cc_offline_enabled': false, 'cc_offline_encryption': false},
      {'cc_offline_enabled': false, 'cc_offline_encryption': true},
      {'cc_offline_enabled': true, 'cc_offline_encryption': false},
    ]) {
      final settings = await launch(stored);
      expectOfflineAndEncryptionOn(settings.offlineConfig);
    }
  });
}
