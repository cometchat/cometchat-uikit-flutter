import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class StickersExtension implements ExtensionsDataSource {
  StickerConfiguration? configuration;
  StickersExtension({this.configuration});

  @override
  void enable() {
    ChatConfigurator.enable((dataSource) =>
        StickersExtensionDecorator(dataSource, configuration: configuration));
  }
}
