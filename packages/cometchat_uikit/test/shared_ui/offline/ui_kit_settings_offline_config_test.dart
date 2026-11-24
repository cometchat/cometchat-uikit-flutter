import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offlineConfig round-trips through the builder', () {
    final config = OfflineConfig(enabled: true, encryption: true);
    final settings =
        (UIKitSettingsBuilder()
              ..appId = 'app'
              ..region = 'us'
              ..authKey = 'key'
              ..enableCalls = true
              ..offlineConfig = config)
            .build();
    expect(settings.offlineConfig, same(config));
    expect(settings.enableCalls, isTrue); // enableCalls kept alongside offline
  });

  test('offlineConfig is absent (null) by default -> offline off', () {
    final settings =
        (UIKitSettingsBuilder()
              ..appId = 'app'
              ..region = 'us'
              ..authKey = 'key')
            .build();
    expect(settings.offlineConfig, isNull);
  });
}
