import '../../../flutter_chat_ui_kit.dart';

///Used to set Ui kit level settings
class UIKitSettings {
  final String? appId;
  final String? region;
  final String? subscriptionType;
  final bool? autoEstablishSocketConnection;
  final String? apiKey;
  // final String? deviceToken;
  // final String? googleApiKey;
  final List<ExtensionsDataSource>? extensions;

  UIKitSettings._builder(UIKitSettingsBuilder builder)
      : appId = builder.appId,
        region = builder.region,
        subscriptionType = builder.subscriptionType,
        autoEstablishSocketConnection =
            builder.autoEstablishSocketConnection ?? true,
        apiKey = builder.apiKey,
        // deviceToken = builder.deviceToken,
        // googleApiKey = builder.googleApiKey,
        extensions = builder.extensions;
}

///Builder class for [UIKitSettings]
class UIKitSettingsBuilder {
  String? appId;
  String? region;
  String? subscriptionType;
  List<String>? roles;
  bool? autoEstablishSocketConnection;
  String? apiKey;
  // String? deviceToken;
  // String? googleApiKey;
  List<ExtensionsDataSource>? extensions;

  UIKitSettingsBuilder();

  UIKitSettings build() {
    return UIKitSettings._builder(this);
  }
}
