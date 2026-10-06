import 'package:flutter/material.dart';

import '../../../../cometchat_chat_uikit.dart';
import '../../../../shared_ui/src/logging/cometchat_log.dart';

///[ImageModerationFilter] is a widget that renders an overlay filter over an image with graphic content
///
/// ```dart
/// ImageModerationFilter(
///   message: MediaMessage(),
///   child: Image.network('https://example.com/image.png'),
///   warningText: 'Warning: Graphic Content',
///   style: ImageModerationFilterStyle(),
///   theme: CometChatTheme(),
/// );
///
/// ```
class ImageModerationFilter extends StatefulWidget {
  const ImageModerationFilter({
    required this.message,
    required this.child,
    super.key,
    this.warningText,
    this.style,
  });

  ///[message] the object containing the image
  final MediaMessage message;

  ///[child] the image to be shown behind filter
  final Widget child;

  ///[warningText] text shown if image has sensitive/graphic content
  final String? warningText;

  ///[style] provides styling to this widget
  final ImageModerationFilterStyle? style;

  @override
  State<ImageModerationFilter> createState() => _ImageModerationFilterState();
}

class _ImageModerationFilterState extends State<ImageModerationFilter> {
  bool imageModerated = false;

  static bool checkImageModeration(MediaMessage mediaMessage) {
    Map<String, Map>? extensions = ExtensionModerator.extensionCheck(
      mediaMessage,
    );
    if (extensions != null) {
      try {
        if (extensions.containsKey(ExtensionConstants.imageModeration)) {
          Map<dynamic, dynamic>? imageModerationMap =
              extensions[ExtensionConstants.imageModeration];

          if (imageModerationMap != null) {
            String? unsafe = imageModerationMap["unsafe"];
            if (unsafe != null && unsafe.trim().toLowerCase() == "yes") {
              return true;
            }
          }
        }

        return false;
      } catch (e) {
        ccLog("$e");
      }
    }
    return false;
  }

  Widget getOpaqueFilter() {
    return SizedBox(
      height: 225,
      width: 225,
      child: GestureDetector(
        onTap: () {
          CometChatConfirmDialog(
            context: context,
            title: Text(Translations.of(context).areYouSureUnsafeContent),
            // The title asks the question. Without a messageText the dialog
            // falls back to its block-contact message, which is wrong here.
            messageText: const SizedBox.shrink(),
            confirmButtonText: Translations.of(context).yes,
            cancelButtonText: Translations.of(context).cancel,
            onConfirm: (dialogContext) {
              showImage();
              Navigator.of(dialogContext).pop();
            },
          ).show();
        },
        child: Opacity(
          opacity: 0.95,
          child: Container(
            alignment: Alignment.center,
            constraints: const BoxConstraints(
              minWidth: double.infinity,
              minHeight: double.infinity,
            ),
            color: widget.style?.filterColor,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  widget.style?.warningImageUrl ??
                      AssetConstants.messagesUnsafe,
                  package:
                      widget.style?.warningImagePackageName ??
                      UIConstants.packageName,
                  color: widget.style?.warningImageColor,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.warningText ?? Translations.of(context).unsafeContent,
                  style: widget.style?.warningTextStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget getChild() {
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    imageModerated = checkImageModeration(widget.message);
  }

  void showImage() {
    imageModerated = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: imageModerated == true ? getOpaqueFilter() : getChild(),
    );
  }
}
