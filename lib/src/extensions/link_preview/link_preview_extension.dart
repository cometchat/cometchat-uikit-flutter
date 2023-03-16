import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class LinkPreviewExtension implements ExtensionsDataSource {
  LinkPreviewConfiguration? configuration;
  LinkPreviewExtension({this.configuration});


  @override
  void enable() {
    ChatConfigurator.enable((dataSource) => LinkPreviewExtensionDecorator(
        dataSource,
        configuration: configuration));
  }
}
