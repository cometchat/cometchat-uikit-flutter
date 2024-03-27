import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[SmartReplyExtension] is the controller class for enabling and disabling the extension
///enabling this extension would display automated suggestions to send in response of received text messages
class SmartReplyExtension extends ExtensionsDataSource {
  SmartReplyConfiguration? configuration;
  SmartReplyExtension({this.configuration});

  @override
  void addExtension() {
    ChatConfigurator.enable((dataSource) =>
        SmartReplyExtensionDecorator(dataSource, configuration: configuration));
  }

  @override
  String getExtensionId() {
    return "smart-reply";
  }
}
