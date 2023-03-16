import '../../../../../flutter_chat_ui_kit.dart';

class TextModerationExtension implements ExtensionsDataSource {
  TextModerationConfiguration? configuration;
  TextModerationExtension({this.configuration});

  @override
  void enable() {
    ChatConfigurator.enable((dataSource) => TextModerationExtensionDecorator(
        dataSource,
        configuration: configuration));
  }
}
