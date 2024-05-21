import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[MessageInformationStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatMessageInformation]
class MessageInformationStyle extends BaseStyles {
  ///[closeIconTint] sets color for close icon
  final Color? closeIconTint;

  ///[readIconTint] sets color for read icon
  final Color? readIconTint;

  ///[deliveredIconTint] sets color for delivered icon
  final Color? deliveredIconTint;

  ///[dividerTint] sets color for divider icon
  final Color? dividerTint;

  ///[titleStyle] sets TextStyle for title
  final TextStyle? titleStyle;

  ///[subTitleStyle] sets TextStyle for title
  final TextStyle? subTitleStyle;

  ///[emptyTextStyle] sets TextStyle for empty text style
  final TextStyle? emptyTextStyle;

  ///[errorTextStyle] sets TextStyle for error text style
  final TextStyle? errorTextStyle;

  ///[loadingIconTint] sets color for loading icon
  final Color? loadingIconTint;

  const MessageInformationStyle({
    super.width,
    super.height,
    super.background,
    super.border,
    super.borderRadius,
    super.gradient,
    this.titleStyle,
    this.closeIconTint,
    this.deliveredIconTint,
    this.dividerTint,
    this.readIconTint,
    this.subTitleStyle,
    this.emptyTextStyle,
    this.errorTextStyle,
    this.loadingIconTint,
  });
}
