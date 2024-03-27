///[ExtensionConstants] is a data class for storing String constants related to extension names
class ExtensionConstants {
  static const String extensions = "extensions";
  static const String linkPreview = "link-preview";
  static const String smartReply = "smart-reply";
  static const String messageTranslation = "message-translation";
  static const String profanityFilter = "profanity-filter";
  static const String imageModeration = "image-moderation";
  static const String thumbnailGeneration = "thumbnail-generation";
  static const String sentimentalAnalysis = "sentiment-analysis";
  static const String polls = "polls";
  static const String reactions = "reactions";
  static const String whiteboard = "whiteboard";
  static const String document = "document";
  static const String dataMasking = "data-masking";
  static const String stickers = "stickers";
  static const String xssFilter = "xss-filter";
  static const String saveMessage = "save-message";
  static const String pinMessage = "pin-message";
  static const String voiceTranscription = "voice-transcription";
  static const String richMedia = "rich-media";
  static const String malwareScanner = "virus-malware-scanner";
  static const String mentions = "mentions";
  static const String customStickers = "customStickers";
  static const String defaultStickers = "defaultStickers";
  static const String stickerUrl = "stickerUrl";
}

///[ExtensionUrls] is a data class for storing String constants related to extension urls
class ExtensionUrls {
  static const String reaction = '/v1/react';
  static const String stickers = "/v1/fetch";
  static const String document = "/v1/create";
  static const String whiteboard = "/v1/create";
  static const String votePoll = "/v2/vote";
  static const String createPoll = "/v2/create";
  static const String translate = '/v2/translate';
}

///[ExtensionType] is a data class for storing String constants related to extension types
class ExtensionType {
  static const String extensionPoll = "extension_poll";
  static const String location = "location";
  static const String sticker = "extension_sticker";
  static const String document = "extension_document";
  static const String whiteboard = "extension_whiteboard";
}
