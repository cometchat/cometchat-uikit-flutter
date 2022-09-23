import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

import 'bubble_utils.dart';

///creates a widget that gives image bubble
///
///used by default  when [messageObject.category]=message and [messageObject.type]=[MessageTypeConstants.image]
class CometChatImageBubble extends StatefulWidget {
  const CometChatImageBubble(
      {Key? key,
      this.messageObject,
      this.imageUrl,
      this.loggedInUser,
      this.confirmDialogConfiguration = const ConfirmDialogConfiguration(),
      this.style = const ImageBubbleStyle()})
      : super(key: key);

  ///[messageObject] media message object
  final MediaMessage? messageObject;

  ///[imageUrl] if message object is not passed then image url should be passed
  final String? imageUrl;

  ///[loggedInUser] UID of logged in user for image moderation
  final String? loggedInUser;

  final ConfirmDialogConfiguration confirmDialogConfiguration;

  final ImageBubbleStyle style;

  @override
  State<CometChatImageBubble> createState() => _CometChatImageBubbleState();
}

class _CometChatImageBubbleState extends State<CometChatImageBubble> {
  bool _showImage = true;

  @override
  void initState() {
    super.initState();
    if (widget.messageObject != null &&
        widget.loggedInUser != null &&
        widget.loggedInUser != widget.messageObject?.sender?.uid) {
      bool _isUnsafe = Extensions.checkImageModeration(widget.messageObject!);
      if (_isUnsafe == true) _showImage = false;
    }
  }

  Widget _getImageWidget(String _imageUrl) {
    return FadeInImage(
      placeholder: const AssetImage("assets/icons/image_placeholder.png",
          package: UIConstants.packageName),
      fit: BoxFit.cover,
      placeholderFit: BoxFit.cover,
      imageErrorBuilder: (context, object, stackTrace) {
        return Center(
            child: Text(Translations.of(context).failed_to_load_image));
      },
      image: NetworkImage(
        _imageUrl,
      ),
    );
  }

  showImage() {
    _showImage = true;
    setState(() {});
  }

  Widget _getOpaqueFilter() {
    return GestureDetector(
      onTap: () {
        showCometChatConfirmDialog(
            context: context,
            title: widget.confirmDialogConfiguration.title,
            messageText: widget.confirmDialogConfiguration.messageText,
            confirmButtonText:
                widget.confirmDialogConfiguration.confirmButtonText,
            //Translations.of(context).yes,
            cancelButtonText:
                widget.confirmDialogConfiguration.cancelButtonText,
            onConfirm: () {
              showImage();
              Navigator.of(context).pop();
            },
            style: widget.confirmDialogConfiguration.confirmDialogStyle);
      },
      child: Opacity(
        opacity: 0.95,
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(
              minWidth: double.infinity, minHeight: double.infinity),
          color: widget.style.moderationFilterColor ?? Colors.black,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                "assets/icons/messages_unsafe.png",
                package: UIConstants.packageName,
                color: widget.style.moderationImageColor ??
                    const Color(0xffFFFFFF),
              ),
              const SizedBox(
                height: 12,
              ),
              Text(
                Translations.of(context).unsafe_content,
                style: widget.style.moderationTextStyle ??
                    const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Color(0xffFFFFFF)),
              )
            ],
          ),
        ),
      ),
    );
  }

  String? _getImageUrl() {
    if (widget.imageUrl != null) {
      return widget.imageUrl;
    } else if (widget.messageObject != null &&
        widget.messageObject!.attachment != null) {
      return widget.messageObject!.attachment!.fileUrl;
    }
    return null;
  }

  Widget _getImage() {
    String? _imageUrl = _getImageUrl();
    if (widget.messageObject?.file != null &&
        widget.messageObject!.file!.isNotEmpty) {
      return Image.file(
        File(widget.messageObject!.file!),
        fit: BoxFit.cover,
      );
    } else if (_imageUrl != null && _imageUrl.isNotEmpty) {
      return _showImage == true
          ? _getImageWidget(_imageUrl)
          : Stack(
              alignment: Alignment.center,
              children: [_getImageWidget(_imageUrl), _getOpaqueFilter()],
            );
    } else {
      return Center(child: Text(Translations.of(context).failed_to_load_image));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: _getImage(),
    );
  }
}

class ImageBubbleStyle {
  final Color? moderationFilterColor;
  final TextStyle? moderationTextStyle;
  final Color? moderationImageColor;
  final double? moderationImageSize;

  const ImageBubbleStyle(
      {this.moderationFilterColor,
      this.moderationTextStyle,
      this.moderationImageColor,
      this.moderationImageSize});
}
