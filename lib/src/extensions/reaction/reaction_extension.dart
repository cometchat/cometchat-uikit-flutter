import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class ReactionExtension implements ExtensionsDataSource {
  ReactionConfiguration? configuration;
  ReactionExtension({this.configuration});

  @override
  void enable() {
    ChatConfigurator.enable((dataSource) =>
        ReactionExtensionDecorator(dataSource, configuration: configuration));
  }
}
