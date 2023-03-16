import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class PollsExtension implements ExtensionsDataSource {
  PollsConfiguration? configuration;
  PollsExtension({this.configuration});

  @override
  void enable() {
    ChatConfigurator.enable((dataSource) =>
        PollsExtensionDecorator(dataSource, configuration: configuration));
  }
}
