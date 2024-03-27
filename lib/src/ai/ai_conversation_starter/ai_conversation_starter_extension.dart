import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[AIConversationStarterExtension] is the controller class for enabling and disabling the extension
///enabling this extension you can use the conversation starter ai feature
class AIConversationStarterExtension extends AIExtension {
  AIConversationStarterConfiguration? configuration;
  AIConversationStarterExtension({this.configuration});

  @override
  void addExtension() {
    ChatConfigurator.enable((dataSource) => AIConversationStarterDecorator(
        dataSource,
        configuration: configuration));
  }

  @override
  String getExtensionId() {
    return AIFeatureConstants.aiConversationStarters;
  }
}
