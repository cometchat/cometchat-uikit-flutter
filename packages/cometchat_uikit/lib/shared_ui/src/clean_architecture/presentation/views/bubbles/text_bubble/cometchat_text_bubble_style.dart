import 'package:flutter/material.dart';
import "../../../../clean_architecture.dart";
import '../../../../../../cometchat_uikit_shared.dart'
    show CometChatAvatarStyle, CometChatDateStyle, CometChatMessageReceiptStyle;

///[CometChatTextBubbleStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatTextBubble]
///
/// ```dart
/// CometChatTextBubbleStyle(
/// textStyle: TextStyle(),
/// border: Border.all(color: Colors.red),
/// borderRadius: 10,
class CometChatTextBubbleStyle
    extends ThemeExtension<CometChatTextBubbleStyle> {
  const CometChatTextBubbleStyle({
    this.textStyle,
    this.border,
    this.borderRadius,
    this.textColor,
    this.backgroundColor,
    this.messageBubbleAvatarStyle,
    this.messageBubbleDateStyle,
    this.messageBubbleBackgroundImage,
    this.threadedMessageIndicatorTextStyle,
    this.threadedMessageIndicatorIconColor,
    this.senderNameTextStyle,
    this.messageReceiptStyle,
  });

  ///[textStyle] provides style to text
  final TextStyle? textStyle;

  ///[border] provides border to the text bubble
  final BoxBorder? border;

  ///[borderRadius] provides border radius to the text bubble
  final BorderRadiusGeometry? borderRadius;

  ///[textColor] provides color to the text
  final Color? textColor;

  ///[backgroundColor] provides background color to the text bubble
  final Color? backgroundColor;

  ///[messageBubbleAvatarStyle] provides style to the avatar of the sender
  final CometChatAvatarStyle? messageBubbleAvatarStyle;

  ///[messageBubbleDateStyle] provides style to the date of the message bubble
  final CometChatDateStyle? messageBubbleDateStyle;

  ///[messageBubbleBackgroundImage] provides background image to the message bubble of the sent message
  final DecorationImage? messageBubbleBackgroundImage;

  ///[threadedMessageIndicatorTextStyle] provides text style to the threaded message indicator
  final TextStyle? threadedMessageIndicatorTextStyle;

  ///[threadedMessageIndicatorIconColor] provides color to the threaded message icon
  final Color? threadedMessageIndicatorIconColor;

  ///[senderNameTextStyle] provides style to the sender name of the message
  final TextStyle? senderNameTextStyle;

  ///[messageReceiptStyle] provides style to the message receipt
  final CometChatMessageReceiptStyle? messageReceiptStyle;

  static CometChatTextBubbleStyle of(BuildContext context) =>
      const CometChatTextBubbleStyle();

  @override
  CometChatTextBubbleStyle copyWith({
    TextStyle? textStyle,
    BoxBorder? border,
    BorderRadiusGeometry? borderRadius,
    Color? textColor,
    Color? backgroundColor,
    CometChatAvatarStyle? messageBubbleAvatarStyle,
    CometChatDateStyle? messageBubbleDateStyle,
    DecorationImage? messageBubbleBackgroundImage,
    TextStyle? threadedMessageIndicatorTextStyle,
    Color? threadedMessageIndicatorIconColor,
    TextStyle? senderNameTextStyle,
    CometChatMessageReceiptStyle? messageReceiptStyle,
  }) {
    return CometChatTextBubbleStyle(
      textStyle: textStyle ?? this.textStyle,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      messageBubbleAvatarStyle:
          messageBubbleAvatarStyle ?? this.messageBubbleAvatarStyle,
      messageBubbleDateStyle:
          messageBubbleDateStyle ?? this.messageBubbleDateStyle,
      messageBubbleBackgroundImage:
          messageBubbleBackgroundImage ?? this.messageBubbleBackgroundImage,
      threadedMessageIndicatorTextStyle:
          threadedMessageIndicatorTextStyle ??
          this.threadedMessageIndicatorTextStyle,
      threadedMessageIndicatorIconColor:
          threadedMessageIndicatorIconColor ??
          this.threadedMessageIndicatorIconColor,
      senderNameTextStyle: senderNameTextStyle ?? this.senderNameTextStyle,
      messageReceiptStyle: messageReceiptStyle ?? this.messageReceiptStyle,
    );
  }

  CometChatTextBubbleStyle merge(CometChatTextBubbleStyle? style) {
    if (style == null) return this;
    return copyWith(
      textStyle: style.textStyle,
      border: style.border,
      borderRadius: style.borderRadius,
      textColor: style.textColor,
      backgroundColor: style.backgroundColor,
      messageBubbleAvatarStyle: style.messageBubbleAvatarStyle,
      messageBubbleDateStyle: style.messageBubbleDateStyle,
      messageBubbleBackgroundImage: style.messageBubbleBackgroundImage,
      threadedMessageIndicatorTextStyle:
          style.threadedMessageIndicatorTextStyle,
      threadedMessageIndicatorIconColor:
          style.threadedMessageIndicatorIconColor,
      senderNameTextStyle: style.senderNameTextStyle,
      messageReceiptStyle: style.messageReceiptStyle,
    );
  }

  @override
  CometChatTextBubbleStyle lerp(CometChatTextBubbleStyle? other, double t) {
    return CometChatTextBubbleStyle(
      textStyle: TextStyle.lerp(textStyle, other?.textStyle, t),
      borderRadius: BorderRadiusGeometry.lerp(
        borderRadius,
        other?.borderRadius,
        t,
      ),
      textColor: Color.lerp(textColor, other?.textColor, t),
      backgroundColor: Color.lerp(backgroundColor, other?.backgroundColor, t),
      messageBubbleAvatarStyle: messageBubbleAvatarStyle?.lerp(
        other?.messageBubbleAvatarStyle,
        t,
      ),
      messageBubbleDateStyle: messageBubbleDateStyle?.lerp(
        other?.messageBubbleDateStyle,
        t,
      ),
      messageBubbleBackgroundImage: DecorationImage.lerp(
        messageBubbleBackgroundImage,
        other?.messageBubbleBackgroundImage,
        t,
      ),
      threadedMessageIndicatorTextStyle: TextStyle.lerp(
        threadedMessageIndicatorTextStyle,
        other?.threadedMessageIndicatorTextStyle,
        t,
      ),
      threadedMessageIndicatorIconColor: Color.lerp(
        threadedMessageIndicatorIconColor,
        other?.threadedMessageIndicatorIconColor,
        t,
      ),
      senderNameTextStyle: TextStyle.lerp(
        senderNameTextStyle,
        other?.senderNameTextStyle,
        t,
      ),
      messageReceiptStyle: messageReceiptStyle?.lerp(
        other?.messageReceiptStyle,
        t,
      ),
      // Absent from the constructor call, so the bubble's border vanished
      // during an animated theme transition. ENG-39124.
      border: BoxBorder.lerp(border, other?.border, t),
    );
  }
}
