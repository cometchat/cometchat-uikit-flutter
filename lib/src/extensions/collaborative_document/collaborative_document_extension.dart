import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CollaborativeDocumentExtension] is the controller class for enabling and disabling the extension
///the extension provides a document to collaborate on
///will be received on the client side realtime through the message listener onCustomMessageReceived
class CollaborativeDocumentExtension extends ExtensionsDataSource {
  CollaborativeDocumentConfiguration? configuration;
  CollaborativeDocumentExtension({this.configuration});

  @override
  void addExtension() {
    ChatConfigurator.enable((dataSource) =>
        CollaborativeDocumentExtensionDecorator(dataSource,
            configuration: configuration));
  }

  @override
  String getExtensionId() {
    return "document";
  }
}
