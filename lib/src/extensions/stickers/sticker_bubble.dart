import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CometChatStickerBubble] is a widget that is rendered as the content view for [StickersExtension]
///
/// ```dart
/// CometChatStickerBubble(
///   messageObject: CustomMessage(),
///   stickerUrl: "url of the sticker",
///   stickerName: "name of sticker"
/// );
/// ```
class CometChatStickerBubble extends StatelessWidget {
  const CometChatStickerBubble(
      {super.key, this.messageObject, this.stickerUrl, this.stickerName});

  ///[messageObject] custom message object
  final CustomMessage? messageObject;

  ///[stickerUrl] if message object is not passed then sticker url should be passed
  final String? stickerUrl;

  ///[stickerName] sticker name
  final String? stickerName;

  String? getStickerUrl() {
    if (stickerUrl != null) {
      return stickerUrl;
    } else if (messageObject != null) {
      return messageObject?.customData?["sticker_url"];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    String? stickerUrl = getStickerUrl();

    return stickerUrl != null && stickerUrl.isNotEmpty
        ? Image.network(
            stickerUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, object, stackTrace) {
              return const SizedBox(
                height: 100,
                width: 100,
                child: Center(child: Text("Failed To Load Sticker")),
              );
            },
          )
        : const SizedBox(
            height: 100,
            width: 100,
            child: Center(child: Text("Failed To Load Sticker")),
          );
  }
}
