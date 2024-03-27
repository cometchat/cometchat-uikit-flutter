import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[PollsExtension] is the controller class for enabling and disabling the extension
///this extension allows to create a poll bubble
///will be received on the client side realtime through the message listener onCustomMessageReceived
class PollsExtension extends ExtensionsDataSource {
  PollsConfiguration? configuration;
  PollsExtension({this.configuration});

  @override
  void addExtension() {
    ChatConfigurator.enable((dataSource) =>
        PollsExtensionDecorator(dataSource, configuration: configuration));
  }

  @override
  String getExtensionId() {
    return "polls";
  }
}
