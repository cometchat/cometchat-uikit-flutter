import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[StickersExtension] is the controller class for enabling and disabling the extension
///this extension offers a wide range of stickers to share as custom messages
class StickersExtension extends ExtensionsDataSource {
  StickerConfiguration? configuration;
  StickersExtension({this.configuration});

  @override
  void addExtension() {
    ChatConfigurator.enable((dataSource) =>
        StickersExtensionDecorator(dataSource, configuration: configuration));
  }

  @override
  String getExtensionId() {
    return "stickers";
  }
}
