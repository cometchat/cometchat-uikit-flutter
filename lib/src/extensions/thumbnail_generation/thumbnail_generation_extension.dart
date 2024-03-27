import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[ThumbnailGenerationExtension] is the controller class for enabling and disabling the extension
///the extension generates thumbnails for images and videos
class ThumbnailGenerationExtension extends ExtensionsDataSource {
  ThumbnailGenerationConfiguration? configuration;
  ThumbnailGenerationExtension({this.configuration});

  @override
  void addExtension() {
    ChatConfigurator.enable((dataSource) =>
        ThumbnailGenerationExtensionDecorator(dataSource,
            configuration: configuration));
  }

  @override
  String getExtensionId() {
    return "thumbnail-generation";
  }
}
