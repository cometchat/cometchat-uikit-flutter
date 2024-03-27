import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CollaborativeWhiteBoardExtension] is the controller class for enabling and disabling the extension
///this extension provides users a whiteboard to collaborate on
///will be received on the client side realtime through the message listener onCustomMessageReceived
class CollaborativeWhiteBoardExtension extends ExtensionsDataSource {
  CollaborativeWhiteBoardConfiguration? configuration;
  CollaborativeWhiteBoardExtension({this.configuration});

  @override
  void addExtension() {
    ChatConfigurator.enable((dataSource) =>
        CollaborativeWhiteBoardExtensionDecorator(dataSource,
            configuration: configuration));
  }

  @override
  String getExtensionId() {
    return "whiteboard";
  }
}
