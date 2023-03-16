import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class MessageTranslationExtension implements ExtensionsDataSource {
  MessageTranslationConfiguration? configuration;
  MessageTranslationExtension({this.configuration});

  @override
  void enable() {
    ChatConfigurator.enable((dataSource) =>
        MessageExtensionTranslationDecorator(dataSource,
            configuration: configuration));
  }
}
