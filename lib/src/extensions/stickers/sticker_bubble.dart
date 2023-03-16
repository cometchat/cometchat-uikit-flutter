import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

///creates a widget that gives sticker bubble
///
///used by default  when [messageObject.category]=custom and [messageObject.type]=[MessageTypeConstants.sticker]
class CometChatStickerBubble extends StatelessWidget {
  const CometChatStickerBubble(
      {Key? key, this.messageObject, this.stickerUrl, this.stickerName})
      : super(key: key);

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
    String? _stickerUrl = getStickerUrl();

    return _stickerUrl != null && _stickerUrl.isNotEmpty
        ? Image.network(
            _stickerUrl,
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
