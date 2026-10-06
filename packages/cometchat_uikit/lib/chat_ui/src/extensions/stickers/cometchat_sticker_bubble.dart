import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CometChatStickerBubble] is a widget that is rendered as the content view for `StickersExtension`
///
/// ```dart
/// CometChatStickerBubble(
///   messageObject: CustomMessage(),
///   stickerUrl: "url of the sticker",
///   height: 100,
///   width: 100,
/// );
/// ```
class CometChatStickerBubble extends StatelessWidget {
  const CometChatStickerBubble({
    super.key,
    this.message,
    this.stickerUrl,
    this.width,
    this.height,
    this.padding,
    this.style,
  });

  ///[message] custom message object
  final CustomMessage? message;

  ///[stickerUrl] if message object is not passed then sticker url should be passed
  final String? stickerUrl;

  ///[height] height of the sticker
  final double? height;

  ///[width] width of the sticker
  final double? width;

  ///[padding] padding of the sticker
  final EdgeInsetsGeometry? padding;

  ///[style] style to customize the appearance of the sticker
  final CometChatStickerBubbleStyle? style;

  String? getStickerUrl() {
    if (stickerUrl != null) {
      return stickerUrl;
    } else if (message != null) {
      return message?.customData?["sticker_url"];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    String? stickerUrl = getStickerUrl();
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final spacing = CometChatThemeHelper.getSpacing(context);
    final style = CometChatThemeHelper.getTheme<CometChatStickerBubbleStyle>(
      context: context,
      defaultTheme: CometChatStickerBubbleStyle.of,
    ).merge(this.style);

    return stickerUrl != null && stickerUrl.isNotEmpty
        ? Container(
            padding:
                padding ??
                EdgeInsets.symmetric(vertical: spacing.padding2 ?? 0),
            decoration: BoxDecoration(
              color: style.backgroundColor,
              border: style.border,
              borderRadius: style.borderRadius,
            ),
            constraints: BoxConstraints(
              maxWidth: width ?? 180,
              maxHeight: height ?? 180,
            ),
            child: Image.network(
              stickerUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                } else {
                  return SizedBox(
                    height: height ?? 180,
                    width: width ?? 180,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: colorPalette.iconSecondary,
                      ),
                    ),
                  );
                }
              },
              errorBuilder: (context, object, stackTrace) {
                return SizedBox(
                  height: height ?? 180,
                  width: width ?? 180,
                  child: Center(
                    child: Text(Translations.of(context).failedToLoadSticker),
                  ),
                );
              },
            ),
          )
        : SizedBox(
            height: height ?? 100,
            width: width ?? 100,
            child: Center(
              child: Text(Translations.of(context).failedToLoadSticker),
            ),
          );
  }
}
