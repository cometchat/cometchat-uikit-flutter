import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

//A temporary class for enabling default extensions, maybe will remove later
class DefaultExtensions {
  static List<ExtensionsDataSource> get() {
    return [
      TextModerationExtension(),
      StickersExtension(),
      CollaborativeDocumentExtension(),
      CollaborativeWhiteBoardExtension(),
      ImageModerationExtension(),
      LinkPreviewExtension(),
      MessageTranslationExtension(),
      PollsExtension(),
      ReactionExtension(),
      SmartReplyExtension(),
      ThumbnailGenerationExtension()
    ];
  }
}
