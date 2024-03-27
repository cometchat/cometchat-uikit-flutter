import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[AIConversationSummaryExtension] is the controller class for enabling and disabling the extension
///enabling this extension you can use the conversation summary ai feature
class AIConversationSummaryExtension extends AIExtension {
  AIConversationSummaryConfiguration? configuration;
  AIConversationSummaryExtension({this.configuration});

  @override
  void addExtension() {
    ChatConfigurator.enable((dataSource) => AIConversationSummaryDecorator(
        dataSource,
        configuration: configuration));
  }

  @override
  String getExtensionId() {
    return AIFeatureConstants.aiConversationSummary;
  }
}
