import 'package:flutter/material.dart';

import '../../cometchat_chat_uikit.dart';

///[DetailsStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatDetails]
class DetailsStyle extends BaseStyles {
  const DetailsStyle(
      {this.titleStyle,
      this.closeIconTint,
      this.privateGroupIconBackground,
      this.protectedGroupIconBackground,
      this.onlineStatusColor,
      double? width,
      super.height,
      super.background,
      super.gradient,
      Border? super.border});

  ///[titleStyle] provides styling for title text
  final TextStyle? titleStyle;

  ///[closeIconTint] provide color to close button
  final Color? closeIconTint;

  ///[privateGroupIconBackground] provides background color for status indicator if group is private
  final Color? privateGroupIconBackground;

  ///[protectedGroupIconBackground] provides background color for status indicator if group is protected
  final Color? protectedGroupIconBackground;

  ///[onlineStatusColor] set online status color
  final Color? onlineStatusColor;
}
