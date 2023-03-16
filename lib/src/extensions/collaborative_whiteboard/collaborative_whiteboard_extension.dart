import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class CollaborativeWhiteBoardExtension implements ExtensionsDataSource {
  CollaborativeWhiteBoardConfiguration? configuration;
  CollaborativeWhiteBoardExtension({this.configuration});

  @override
  void enable() {
    ChatConfigurator.enable((dataSource) =>
        CollaborativeWhiteBoardExtensionDecorator(dataSource,
            configuration: configuration));
  }
}
