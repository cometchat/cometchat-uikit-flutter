import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class CollaborativeDocumentExtension implements ExtensionsDataSource {
  CollaborativeDocumentConfiguration? configuration;
  CollaborativeDocumentExtension({this.configuration});

  @override
  void enable() {
    ChatConfigurator.enable((dataSource) =>
        CollaborativeDocumentExtensionDecorator(dataSource,
            configuration: configuration));
  }
}
