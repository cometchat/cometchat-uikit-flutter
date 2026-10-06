import 'package:flutter/material.dart';
import '../../../cometchat_uikit_shared.dart';

/// Styling properties for [CometChatAIAssistantBubble].
class CometChatAIAssistantBubbleStyle
    extends ThemeExtension<CometChatAIAssistantBubbleStyle> {
  // Deprecated in 6.2.0: no effect, removed in 7.0.0.

  /// Style for the sender avatar.
  @Deprecated(
    'Has no effect: never read. Style the AI message avatar with CometChatMessageListStyle.avatarStyle. Will be removed in 7.0.0.',
  )
  final CometChatAvatarStyle? messageBubbleAvatarStyle;

  /// Background image for the message bubble.
  @Deprecated(
    'Has no effect: never read; AI responses render on a transparent background. Will be removed in 7.0.0.',
  )
  final DecorationImage? messageBubbleBackgroundImage;

  const CometChatAIAssistantBubbleStyle({
    this.textStyle,
    this.border,
    this.borderRadius,
    this.textColor,
    this.backgroundColor,
    this.messageBubbleAvatarStyle,
    this.messageBubbleBackgroundImage,
  });

  /// Style applied to the markdown text.
  final TextStyle? textStyle;

  /// Border around the bubble.
  final BoxBorder? border;

  /// Border radius of the bubble.
  final BorderRadiusGeometry? borderRadius;

  /// Color applied to the text.
  final Color? textColor;

  /// Background color of the bubble.
  final Color? backgroundColor;

  static CometChatAIAssistantBubbleStyle of(BuildContext context) =>
      const CometChatAIAssistantBubbleStyle();

  @override
  CometChatAIAssistantBubbleStyle copyWith({
    TextStyle? textStyle,
    BoxBorder? border,
    BorderRadiusGeometry? borderRadius,
    Color? textColor,
    Color? backgroundColor,
  }) {
    return CometChatAIAssistantBubbleStyle(
      textStyle: textStyle ?? this.textStyle,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  CometChatAIAssistantBubbleStyle merge(
    CometChatAIAssistantBubbleStyle? style,
  ) {
    if (style == null) return this;
    return copyWith(
      textStyle: style.textStyle,
      border: style.border,
      borderRadius: style.borderRadius,
      textColor: style.textColor,
      backgroundColor: style.backgroundColor,
    );
  }

  @override
  CometChatAIAssistantBubbleStyle lerp(
    CometChatAIAssistantBubbleStyle? other,
    double t,
  ) {
    return CometChatAIAssistantBubbleStyle(
      textStyle: TextStyle.lerp(textStyle, other?.textStyle, t),
      borderRadius: BorderRadiusGeometry.lerp(
        borderRadius,
        other?.borderRadius,
        t,
      ),
      textColor: Color.lerp(textColor, other?.textColor, t),
      backgroundColor: Color.lerp(backgroundColor, other?.backgroundColor, t),
      // Absent from the constructor call, so the border vanished during an
      // animated theme transition. ENG-39124.
      border: BoxBorder.lerp(border, other?.border, t),
    );
  }
}
