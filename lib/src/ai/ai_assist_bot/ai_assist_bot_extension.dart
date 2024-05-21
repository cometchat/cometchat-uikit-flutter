import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[AIAssistBotExtension] is the controller class for enabling and disabling the extension
///enabling this extension you can use the assist bot ai feature
class AIAssistBotExtension extends AIExtension {
  AIAssistBotConfiguration? configuration;
  AIAssistBotExtension({this.configuration});

  @override
  void addExtension() {
    ChatConfigurator.enable((dataSource) =>
        AIAssistBotDecorator(dataSource, configuration: configuration));
  }

  @override
  String getExtensionId() {
    return AIFeatureConstants.aiAssistBot;
  }
}
