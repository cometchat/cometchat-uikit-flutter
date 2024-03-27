import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[TransferOwnershipStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatTransferOwnership]
class TransferOwnershipStyle extends BaseStyles {
  const TransferOwnershipStyle(
      {this.memberScopeStyle,
      this.submitIconTint,
      this.selectIconTint,
      double? width,
      double? height,
      Color? background,
      Gradient? gradient,
      BoxBorder? border,
      double? borderRadius})
      : super(
            width: width,
            height: height,
            background: background,
            gradient: gradient,
            border: border,
            borderRadius: borderRadius);

  ///[memberScopeStyle] is used to customize the appearance of the text in trailing widget
  final TextStyle? memberScopeStyle;

  ///[submitIconTint] will override the color of the default selection complete icon
  final Color? submitIconTint;

  ///[selectIconTint] will override the color of the default selection icon
  final Color? selectIconTint;
}
