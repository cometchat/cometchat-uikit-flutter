import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class ThumbnailGenerationExtension implements ExtensionsDataSource {
  ThumbnailGenerationConfiguration? configuration;
  ThumbnailGenerationExtension({this.configuration});

  @override
  void enable() {
    ChatConfigurator.enable((dataSource) =>
        ThumbnailGenerationExtensionDecorator(dataSource,
            configuration: configuration));
  }
}
