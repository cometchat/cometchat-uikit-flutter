import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_image/flutter_image.dart';

import 'bubble_utils.dart';

///creates a widget that gives video bubble
///
///used by default  when [messageObject.category]=message and [messageObject.type]=[MessageTypeConstants.video]
class CometChatVideoBubble extends StatelessWidget {
  const CometChatVideoBubble({
    Key? key,
    this.style = const VideoBubbleStyle(),
    this.videoUrl,
    this.messageObject,
    this.thumbnailUrl,
  }) : super(key: key);

  ///[messageObject] media message object
  final MediaMessage? messageObject;

  ///[videoUrl] if message object is not passed then video url should be passed
  final String? videoUrl;

  ///[thumbnailUrl] f message object is not passed then thumbnailUrl should be passed
  final String? thumbnailUrl;

  ///[style] video bubble styling properties
  final VideoBubbleStyle style;

  getVideoUrl() {
    if (videoUrl != null) {
      return videoUrl;
    } else if (messageObject != null) {
      return messageObject!.attachment?.fileUrl;
    }
  }

  String? checkForThumbnail() {
    if (thumbnailUrl != null) {
      return thumbnailUrl;
    } else if (messageObject != null) {
      try {
        String? smallUrl = Extensions.getThumbnailGeneration(messageObject!);
        Attachment? attachment = messageObject?.attachment;
        if (attachment != null) {
          if (smallUrl != null) {
            return smallUrl;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    String? _thumbnailUrl = checkForThumbnail();

    return Center(
      child: Stack(
        children: [
          SizedBox.expand(
            child: _thumbnailUrl != null && _thumbnailUrl.isNotEmpty
                ? FadeInImage(
                    placeholder: const AssetImage(
                        "assets/icons/image_placeholder.png",
                        package: UIConstants.packageName),
                    fit: BoxFit.cover,
                    placeholderFit: BoxFit.cover,
                    imageErrorBuilder: (context, object, stackTrace) {
                      //return const Center(child: Text("Failed to load image"));

                      return Image.asset("assets/icons/image_placeholder.png",
                          package: UIConstants.packageName, fit: BoxFit.cover);
                    },
                    image: NetworkImageWithRetry(_thumbnailUrl,
                        fetchStrategy: (Uri uri, FetchFailure? failure) async {
                      if (failure == null) {
                        return FetchInstructions.attempt(
                            uri: uri, timeout: const Duration(seconds: 10));
                      }
                      if (failure.httpStatusCode == 403 &&
                          failure.attemptCount <= 10) {
                        await Future.delayed(const Duration(seconds: 1));
                        return FetchInstructions.attempt(
                            uri: uri, timeout: const Duration(seconds: 5));
                      } else {
                        return FetchInstructions.giveUp(uri: uri);
                      }
                    }),
                  )
                : Image.asset("assets/icons/image_placeholder.png",
                    package: UIConstants.packageName, fit: BoxFit.cover),
          ),
          Align(
            alignment: Alignment.center,
            child: style.playPauseIcon ??
                const Icon(
                  Icons.play_circle_fill,
                  size: 56.0,
                  color: Color(0xff3399FF),
                ),
          )
        ],
      ),
    );
  }
}

class VideoBubbleStyle {
  const VideoBubbleStyle({
    this.playPauseIcon,
  });

  ///[playPauseIcon] video play pause icon
  final Icon? playPauseIcon;
}
