import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class SmartReplyExtension implements ExtensionsDataSource {
  SmartReplyConfiguration? configuration;
  SmartReplyExtension({this.configuration});

  @override
  void enable() {
    ChatConfigurator.enable((dataSource) =>
        SmartReplyExtensionDecorator(dataSource, configuration: configuration));
  }
}
