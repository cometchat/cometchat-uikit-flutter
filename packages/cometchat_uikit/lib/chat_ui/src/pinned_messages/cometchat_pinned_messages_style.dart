import 'package:flutter/material.dart';

///[CometChatPinnedMessagesStyle] contains the styling properties for
///[CometChatPinnedMessages] — the pinned-messages bottom sheet.
class CometChatPinnedMessagesStyle {
  const CometChatPinnedMessagesStyle({
    this.backgroundColor,
    this.appBarColor,
    this.titleTextStyle,
    this.itemTitleTextStyle,
    this.itemSubtitleTextStyle,
    this.itemDateTextStyle,
    this.iconColor,
    this.unpinIconColor,
    this.separatorColor,
    this.borderRadius,
  });

  ///[backgroundColor] background of the sheet
  final Color? backgroundColor;

  /// Background colour of the header bar.
  final Color? appBarColor;

  ///[titleTextStyle] style of the "{n} Pinned Messages" header
  final TextStyle? titleTextStyle;

  ///[itemTitleTextStyle] style of each row's sender name
  final TextStyle? itemTitleTextStyle;

  ///[itemSubtitleTextStyle] style of each row's message preview
  final TextStyle? itemSubtitleTextStyle;

  ///[itemDateTextStyle] style of each row's pinned-at date
  final TextStyle? itemDateTextStyle;

  ///[iconColor] color of the header close icon
  final Color? iconColor;

  ///[unpinIconColor] color of the icon in the unpin confirmation dialog
  final Color? unpinIconColor;

  ///[separatorColor] color of the row separators
  final Color? separatorColor;

  ///[borderRadius] top corner radius of the sheet
  final BorderRadiusGeometry? borderRadius;

  CometChatPinnedMessagesStyle merge(CometChatPinnedMessagesStyle? other) {
    if (other == null) return this;
    return CometChatPinnedMessagesStyle(
      backgroundColor: other.backgroundColor ?? backgroundColor,
      appBarColor: other.appBarColor ?? appBarColor,
      titleTextStyle: other.titleTextStyle ?? titleTextStyle,
      itemTitleTextStyle: other.itemTitleTextStyle ?? itemTitleTextStyle,
      itemSubtitleTextStyle:
          other.itemSubtitleTextStyle ?? itemSubtitleTextStyle,
      itemDateTextStyle: other.itemDateTextStyle ?? itemDateTextStyle,
      iconColor: other.iconColor ?? iconColor,
      unpinIconColor: other.unpinIconColor ?? unpinIconColor,
      separatorColor: other.separatorColor ?? separatorColor,
      borderRadius: other.borderRadius ?? borderRadius,
    );
  }
}
