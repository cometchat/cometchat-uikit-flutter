import 'package:flutter/material.dart';

import '../../../../cometchat_chat_uikit.dart';

///[StickerAuxiliaryButton] is the widget that represents the [StickersExtension] in auxiliary button view of the [CometChatMessageComposer]
///
/// ```dart
///
/// StickerAuxiliaryButton(
///   stickerButtonIcon: Icon(Icons.sticky_note),
///   keyboardButtonIcon: Icon(Icons.keyboard),
///   onStickerTap: () {
///     // Custom action for when the sticker button is tapped
///   },
///   onKeyboardTap: () {
///     // Custom action for when the keyboard button is tapped
///   },
///   theme: CometChatTheme.dark(),
/// );
///
/// ```
class StickerAuxiliaryButton extends StatefulWidget {
  const StickerAuxiliaryButton(
      {super.key,
      this.keyboardButtonIcon,
      this.stickerButtonIcon,
      this.onKeyboardTap,
      this.onStickerTap,
      this.theme,
      this.stickerIconTint,
      this.keyboardIconTint});

  ///[stickerButtonIcon] shows stickers keyboard
  final Widget? stickerButtonIcon;

  ///[keyboardButtonIcon] hides stickers keyboard
  final Widget? keyboardButtonIcon;

  ///[onStickerTap] overrides default action that shows the stickers
  final Function()? onStickerTap;

  ///[onKeyboardTap] overrides default action that hides the stickers
  final Function()? onKeyboardTap;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[stickerIconTint] provides color to the sticker Icon/widget
  final Color? stickerIconTint;

  ///[keyboardIconTint] provides color to the keyboard Icon/widget
  final Color? keyboardIconTint;

  @override
  State<StickerAuxiliaryButton> createState() => _StickerAuxiliaryButtonState();
}

class _StickerAuxiliaryButtonState extends State<StickerAuxiliaryButton>
    with CometChatUIEventListener {
  bool _isStickerButtonActive = true;

  late CometChatTheme theme;

  late String dateStamp;
  late String _listenerId;

  @override
  void initState() {
    theme = widget.theme ?? cometChatTheme;
    dateStamp = DateTime.now().microsecondsSinceEpoch.toString();
    _listenerId = "StickerAuxiliaryButtonListener";
    CometChatUIEvents.addUiListener(_listenerId, this);
    super.initState();
  }

  @override
  void dispose() {
    CometChatUIEvents.removeUiListener(_listenerId);
    super.dispose();
  }

  @override
  void hidePanel(Map<String, dynamic>? id, CustomUIPosition uiPosition) {
    if (uiPosition == CustomUIPosition.composerBottom &&
        _isStickerButtonActive == false) {
      setState(() {
        _isStickerButtonActive = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isStickerButtonActive == true
        ? IconButton(
            onPressed: () {
              if (widget.onStickerTap != null) {
                widget.onStickerTap!();
              }
              setState(() {
                _isStickerButtonActive = false;
              });
            },
            icon: widget.stickerButtonIcon ??
                Image.asset(
                  AssetConstants.smile,
                  package: UIConstants.packageName,
                  color: widget.stickerIconTint ?? theme.palette.getAccent700(),
                ))
        : IconButton(
            onPressed: () {
              if (widget.onKeyboardTap != null) {
                widget.onKeyboardTap!();
              }
              setState(() {
                _isStickerButtonActive = true;
              });
            },
            icon: widget.keyboardButtonIcon ??
                Image.asset(
                  AssetConstants.keyboard,
                  package: UIConstants.packageName,
                  color:
                      widget.keyboardIconTint ?? theme.palette.getAccent700(),
                ));
  }
}
