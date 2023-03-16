// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_image/network.dart';

// import 'bubble_utils.dart';

///creates a widget that gives image bubble
///
///used by default  when [messageObject.category]=message and [messageObject.type]=[MessageTypeConstants.image]
class CometChatImageBubble extends StatefulWidget {
  const CometChatImageBubble(
      {Key? key,
      this.imageUrl,
      this.style = const ImageBubbleStyle(),
      this.placeholderImage,
      this.placeHolderImagePackageName,
      this.caption,
      required this.theme,
      this.onClick})
      : super(key: key);

  ///[imageUrl] image url should be passed
  final String? imageUrl;

  ///[style] manages appearance of this widget
  final ImageBubbleStyle style;

  ///[placeholderImage] is shown temporarily for the duration when image is loading from url
  final String? placeholderImage;

  ///[placeHolderImagePackageName] is package path for the custom placeholder image
  final String? placeHolderImagePackageName;

  ///[caption] text sent along with image
  final String? caption;

  ///[theme] set custom theme
  final CometChatTheme theme;

  ///[onClick] custom action on tapping the image
  final Function()? onClick;

  @override
  State<CometChatImageBubble> createState() => _CometChatImageBubbleState();
}

class _CometChatImageBubbleState extends State<CometChatImageBubble> {
  @override
  void initState() {
    super.initState();
  }


  Widget _getImageWidget(String _imageUrl) {
    return FadeInImage(
      placeholder: AssetImage(
        widget.placeholderImage ?? AssetConstants.imagePlaceholder,
        package: widget.placeHolderImagePackageName ?? UIConstants.packageName),
      fit: BoxFit.cover,
      placeholderFit: BoxFit.cover,
      imageErrorBuilder: (context, object, stackTrace) {
        return Center(
            child: Text(Translations.of(context).failed_to_load_image));
      },
      // image: NetworkImage(
      //   _imageUrl,
      // ),
     image: NetworkImageWithRetry(_imageUrl,
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
                      })
    );
  }

  Widget _getImage() {
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      return _getImageWidget(widget.imageUrl!);
    }
    // else {
    //   return Center(child: Text(Translations.of(context).failed_to_load_image));
    // }
    else {
      return Image(
          fit: BoxFit.cover,
          image: AssetImage(
              widget.placeholderImage ?? AssetConstants.imagePlaceholder,
              package: UIConstants.packageName));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClick ??
          () {
            if (widget.imageUrl != null || widget.imageUrl!.isNotEmpty) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ImageViewer(
                            imageUrl: widget.imageUrl!,
                            backgroundColor:
                                widget.theme.palette.getBackground(),
                            backIconColor: widget.theme.palette.getPrimary(),
                          )));
            }
          },
      child: Container(
        height: widget.style.height ?? 225,
        width: widget.style.width ?? 225,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
            border: widget.style.border,
            borderRadius: BorderRadius.circular(widget.style.borderRadius ?? 0),
            color: widget.style.gradient == null
                ? widget.style.background ?? Colors.transparent
                : null,
            gradient: widget.style.gradient),
        // child: _getImage()
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _getImage()),
            if (widget.caption != null && widget.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
                child: Text(
                  widget.caption!,
                  style: widget.style.captionStyle ??
                      const TextStyle(
                        color: Color(0xff141414),
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                      ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
