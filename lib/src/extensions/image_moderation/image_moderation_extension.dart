import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class ImageModerationExtension implements ExtensionsDataSource {
  ImageModerationConfiguration? configuration;
  ImageModerationExtension({this.configuration});

  @override
  void enable() {
    ChatConfigurator.enable((dataSource) => ImageModerationExtensionDecorator(
        dataSource,
        configuration: configuration));
  }
}
