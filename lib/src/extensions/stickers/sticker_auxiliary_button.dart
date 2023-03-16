import 'package:flutter/material.dart';

import '../../../../flutter_chat_ui_kit.dart';

class StickerAuxiliaryButton extends StatefulWidget {
  const StickerAuxiliaryButton(
      {Key? key,
      this.keyboardButtonIcon,
      this.stickerButtonIcon,
      this.onKeyboardTap,
      this.onStickerTap,
      this.theme})
      : super(key: key);

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

  @override
  _StickerAuxiliaryButtonState createState() => _StickerAuxiliaryButtonState();
}

class _StickerAuxiliaryButtonState extends State<StickerAuxiliaryButton> {
  bool _isStickerButtonActive = true;

  late CometChatTheme theme;

  @override
  void initState() {
    theme = widget.theme ?? cometChatTheme;
    super.initState();
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
            icon: widget.stickerButtonIcon ?? Image.asset(
              AssetConstants.smile,
              package: UIConstants.packageName,
              color: theme.palette.getAccent700(),
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
            icon: widget.keyboardButtonIcon ?? Image.asset(
              AssetConstants.keyboard,
              package: UIConstants.packageName,
              color: theme.palette.getAccent700(),
            ));
  }
}
