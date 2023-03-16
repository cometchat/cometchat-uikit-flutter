import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_image/flutter_image.dart';

///creates a widget that gives video bubble
///
///used by default  when [messageObject.category]=message and [messageObject.type]=[MessageTypeConstants.video]
class CometChatVideoBubble extends StatelessWidget {
  const CometChatVideoBubble({
    Key? key,
    this.style,
    this.videoUrl,
    this.thumbnailUrl,
    this.placeHolderImage,
    this.placeHolderImagePackageName,
    this.playIcon,
    this.theme,
    this.onClick
  }) : super(key: key);


  ///[videoUrl] if message object is not passed then video url should be passed
  final String? videoUrl;

  ///[thumbnailUrl] custom thumbnail for the video
  final String? thumbnailUrl;

  ///[style] video bubble styling properties
  final VideoBubbleStyle? style;

  ///[placeHolderImage] shows placeholder for video
  final String? placeHolderImage;

  ///[placeHolderImagePackageName] is package path for the custom placeholder image
  final String? placeHolderImagePackageName;

  ///[playIcon] video play pause icon
  final Icon? playIcon;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[onClick] custom action on tapping the image
  final Function()? onClick;

  @override
  Widget build(BuildContext context) {
    CometChatTheme _theme=theme??cometChatTheme;

    return GestureDetector(
      onTap: onClick ?? () {
        String? _videoUrl = videoUrl;
        if (_videoUrl != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => VideoPlayer(
                        backIcon: _theme.palette.getPrimary(),
                        fullScreenBackground: _theme.palette.getBackground(),
                        videoUrl: _videoUrl,
                      )));
        }
      },
      child: Container(
        height: style?.height ?? 225,
        width: style?.width ?? 225,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
            border: style?.border,
            borderRadius: BorderRadius.circular(style?.borderRadius ?? 0),
            color: style?.gradient == null
                ? style?.background ?? Colors.transparent
                : null,
            gradient: style?.gradient),
        alignment: Alignment.center,
        child: Stack(
          children: [
            // SizedBox.expand(
            //   child: thumbnailUrl != null && thumbnailUrl!.isNotEmpty
            //       ? FadeInImage(
            //           placeholder: AssetImage(
            //             placeHolderImage ??  AssetConstants.imagePlaceholder,
            //               package: UIConstants.packageName),
            //           fit: BoxFit.cover,
            //           placeholderFit: BoxFit.cover,
            //           imageErrorBuilder: (context, object, stackTrace) {
      
            //             return Image.asset( placeHolderImage ?? AssetConstants.imagePlaceholder,
            //                 package: UIConstants.packageName, fit: BoxFit.cover);
            //           },
            //           image: NetworkImage(thumbnailUrl!),
            //         )
            //       : Image.asset(placeHolderImage ?? AssetConstants.imagePlaceholder,
            //           package: UIConstants.packageName, fit: BoxFit.cover),
            // ),
                      SizedBox.expand(
              child: thumbnailUrl != null && thumbnailUrl!.isNotEmpty
                  ? FadeInImage(
                      placeholder: AssetImage(
                         placeHolderImage ?? AssetConstants.imagePlaceholder,
                          package:placeHolderImagePackageName ?? UIConstants.packageName),
                      fit: BoxFit.cover,
                      placeholderFit: BoxFit.cover,
                      imageErrorBuilder: (context, object, stackTrace) {
    
                        return Image.asset(placeHolderImage ?? AssetConstants.imagePlaceholder,
                            package:placeHolderImagePackageName ?? UIConstants.packageName, fit: BoxFit.cover);
                      },
                      image: NetworkImageWithRetry(thumbnailUrl!,
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
                  : Image.asset(placeHolderImage ?? AssetConstants.imagePlaceholder,
                      package: placeHolderImagePackageName ?? UIConstants.packageName, fit: BoxFit.cover),
            ),
            Align(
              alignment: Alignment.center,
              child: playIcon ??
                   Icon(
                    Icons.play_circle_fill,
                    size: 56.0,
                    color: style?.playIconTint ?? _theme.palette.getPrimary(),
                  ),
            )
          ],
        ),
      ),
    );
  }
}
