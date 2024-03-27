import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[MessageTranslationExtension] is the controller class for enabling and disabling the extension
///this extension temporarily translates text to the default language of the device if it is not so originally
class MessageTranslationExtension extends ExtensionsDataSource {
  MessageTranslationConfiguration? configuration;
  MessageTranslationExtension({this.configuration});

  @override
  void addExtension() {
    ChatConfigurator.enable((dataSource) =>
        MessageExtensionTranslationDecorator(dataSource,
            configuration: configuration));
  }

  @override
  String getExtensionId() {
    return "message-translation";
  }
}
