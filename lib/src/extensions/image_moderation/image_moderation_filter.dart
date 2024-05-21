import 'package:flutter/material.dart';

import '../../../../../cometchat_chat_uikit.dart';

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
  const ImageModerationFilter(
      {required this.message,
      this.theme,
      required this.child,
      super.key,
      this.warningText,
      this.style});

  ///[message] the object containing the image
  final MediaMessage message;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

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
  late CometChatTheme _theme;

  static bool checkImageModeration(MediaMessage mediaMessage) {
    Map<String, Map>? extensions =
        ExtensionModerator.extensionCheck(mediaMessage);
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
        debugPrint("$e");
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
          showCometChatConfirmDialog(
            context: context,
            title: Text(Translations.of(context).areYouSureUnsafeContent),
            messageText: const Text("Do image change"),
            confirmButtonText: Translations.of(context).yes,
            cancelButtonText: Translations.of(context).cancel,
            onConfirm: () {
              showImage();
              Navigator.of(context).pop();
            },
          );
        },
        child: Opacity(
          opacity: 0.95,
          child: Container(
            alignment: Alignment.center,
            constraints: const BoxConstraints(
                minWidth: double.infinity, minHeight: double.infinity),
            color: widget.style?.filterColor ?? _theme.palette.getAccent(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  widget.style?.warningImageUrl ??
                      AssetConstants.messagesUnsafe,
                  package: widget.style?.warningImagePackageName ??
                      UIConstants.packageName,
                  color: widget.style?.warningImageColor ??
                      _theme.palette.getBackground(),
                ),
                const SizedBox(
                  height: 12,
                ),
                Text(
                  widget.warningText ?? Translations.of(context).unsafeContent,
                  style: widget.style?.warningTextStyle ??
                      TextStyle(
                          fontSize: _theme.typography.subtitle2.fontSize,
                          fontWeight: _theme.typography.subtitle2.fontWeight,
                          color: _theme.palette.getBackground()),
                )
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
    _theme = widget.theme ?? cometChatTheme;
    imageModerated = checkImageModeration(widget.message);
  }

  showImage() {
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
