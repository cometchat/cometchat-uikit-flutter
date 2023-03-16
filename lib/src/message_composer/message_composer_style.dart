import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class MessageComposerStyle extends BaseStyles {
  const MessageComposerStyle({
    this.inputBackground,
    this.inputTextStyle,
    this.inputGradient,
    this.placeholderTextStyle,
    this.sendButtonIcon,
    this.attachmentIconTint,
    this.emojiIconTint,
    this.stickerIconTint,
    this.sendButtonIconTint,
    this.closeIconTint,
    this.dividerTint,
    this.contentPadding,
    double? width,
    double? height,
    Color? background,
    BoxBorder? border,
    double? borderRadius,
    Gradient? gradient,
  }) : super(
            width: width,
            height: height,
            background: background,
            border: border,
            borderRadius: borderRadius,
            gradient: gradient);

  ///[inputBackground] background color of text field
  final Color? inputBackground;

  ///[inputTextStyle] provides style to input text
  final TextStyle? inputTextStyle;

  ///[inputGradient] provides gradient background to the input field
  final Gradient? inputGradient;

  ///[placeholderTextStyle] hint text style
  final TextStyle? placeholderTextStyle;

  ///[sendButtonIcon] custom send button icon
  final Widget? sendButtonIcon;

  ///[attachmentIconTint] provides color to the attachment Icon/widget
  final Color? attachmentIconTint;

  ///[emojiIconTint] provides color to the emoji Icon/widget
  final Color? emojiIconTint;

  ///[stickerIconTint] provides color to the sticker Icon/widget
  final Color? stickerIconTint;

  ///[sendButtonIconTint] provides color to the sendButton Icon/widget
  final Color? sendButtonIconTint;

  ///[closeIconTint] provides color to the close Icon/widget
  final Color? closeIconTint;

  ///[dividerTint] provides color to the divider
  final Color? dividerTint;

  final EdgeInsetsGeometry? contentPadding;
}
