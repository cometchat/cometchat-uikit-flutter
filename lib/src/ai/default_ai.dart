import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CometChatUIKitChatAIFeatures] is a utility class that provides a list of default ai features
class CometChatUIKitChatAIFeatures {
  static List<AIExtension> getDefaultAiFeatures() {
    return [
      AISmartRepliesExtension(),
      AIConversationStarterExtension(),
      AIConversationSummaryExtension(),
      AIAssistBotExtension()
    ];
  }
}
