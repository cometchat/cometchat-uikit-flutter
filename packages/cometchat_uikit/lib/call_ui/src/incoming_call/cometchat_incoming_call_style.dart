import '../../../cometchat_chat_uikit.dart';

import 'package:flutter/material.dart';

/// [CometChatIncomingCallStyle] is a data class that has styling-related properties
/// to customize the appearance of [CometChatIncomingCall]
///
/// ```dart
/// CometChatIncomingCallStyle(
///  backgroundColor: Colors.white,
///  avatarStyle: CometChatAvatarStyle(),
///  declineIconColor: Colors.red,
///  acceptIconColor: Colors.green,
///  );
///
@Deprecated(
  'Styles the incoming call screen, deprecated since ringing v2: incoming '
  'calls ring on the push ringer\'s own screen (cometchat_voip, through '
  'UIKitSettings.callPushBridge) on Android and iOS, and this screen shows '
  'on web only.',
)
class CometChatIncomingCallStyle
    extends ThemeExtension<CometChatIncomingCallStyle> {
  CometChatIncomingCallStyle({
    this.backgroundColor,
    this.avatarStyle,
    this.subtitleColor,
    this.subtitleTextStyle,
    this.titleColor,
    this.titleTextStyle,
    this.borderRadius,
    this.border,
    this.declineButtonColor,
    this.acceptButtonColor,
    this.acceptTextColor,
    this.acceptTextStyle,
    this.declineTextColor,
    this.declineTextStyle,
    this.callIconColor,
  });

  ///[titleTextStyle] is used to set the text style for the title.
  final TextStyle? titleTextStyle;

  ///[titleColor] is used to set the color for the title.
  final Color? titleColor;

  ///[subtitleTextStyle] is used to set the text style for the subtitle.
  final TextStyle? subtitleTextStyle;

  ///[subtitleColor] is used to set the color for the subtitle.
  final Color? subtitleColor;

  ///[avatarStyle] is used to set the avatar style.
  final CometChatAvatarStyle? avatarStyle;

  ///[declineTextStyle] is used to set the text style for the decline text.
  final TextStyle? declineTextStyle;

  ///[declineTextColor] is used to set the color for the decline text.
  final Color? declineTextColor;

  ///[acceptTextStyle] is used to set the text style for the accept text.
  final TextStyle? acceptTextStyle;

  ///[acceptTextColor] is used to set the color for the accept text.
  final Color? acceptTextColor;

  ///[backgroundColor] is used to set the background color.
  final Color? backgroundColor;

  ///[declineButtonColor] is used to set the button color.
  final Color? declineButtonColor;

  ///[border] provides border for the widget
  final Border? border;

  ///[borderRadius] provides border radius for the widget
  final BorderRadiusGeometry? borderRadius;

  ///[acceptButtonColor] is used to set a custom color to accept button
  final Color? acceptButtonColor;

  ///[callIconColor] is used to set a custom color to call icon
  final Color? callIconColor;

  static CometChatIncomingCallStyle of(BuildContext context) =>
      CometChatIncomingCallStyle();

  @override
  CometChatIncomingCallStyle copyWith({
    Color? backgroundColor,
    CometChatAvatarStyle? avatarStyle,
    Color? subtitleColor,
    TextStyle? subtitleTextStyle,
    Color? titleColor,
    TextStyle? titleTextStyle,
    BorderRadiusGeometry? borderRadius,
    Border? border,
    Color? declineButtonColor,
    Color? acceptButtonColor,
    TextStyle? declineTextStyle,
    TextStyle? acceptTextStyle,
    Color? acceptTextColor,
    Color? declineTextColor,
    Color? callIconColor,
  }) {
    return CometChatIncomingCallStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      avatarStyle: avatarStyle ?? this.avatarStyle,
      subtitleColor: subtitleColor ?? this.subtitleColor,
      subtitleTextStyle: subtitleTextStyle ?? this.subtitleTextStyle,
      titleColor: titleColor ?? this.titleColor,
      titleTextStyle: titleTextStyle ?? this.titleTextStyle,
      borderRadius: borderRadius ?? this.borderRadius,
      border: border ?? this.border,
      declineButtonColor: declineButtonColor ?? this.declineButtonColor,
      acceptButtonColor: acceptButtonColor ?? this.acceptButtonColor,
      acceptTextColor: acceptTextColor ?? this.acceptTextColor,
      declineTextColor: declineTextColor ?? this.declineTextColor,
      acceptTextStyle: acceptTextStyle ?? this.acceptTextStyle,
      declineTextStyle: declineTextStyle ?? this.declineTextStyle,
      callIconColor: callIconColor ?? this.callIconColor,
    );
  }

  CometChatIncomingCallStyle merge(CometChatIncomingCallStyle? style) {
    if (style == null) return this;
    return copyWith(
      backgroundColor: style.backgroundColor,
      avatarStyle: style.avatarStyle,
      subtitleColor: style.subtitleColor,
      subtitleTextStyle: style.subtitleTextStyle,
      titleColor: style.titleColor,
      titleTextStyle: style.titleTextStyle,
      borderRadius: style.borderRadius,
      border: style.border,
      declineButtonColor: style.declineButtonColor,
      acceptButtonColor: style.acceptButtonColor,
      acceptTextColor: style.acceptTextColor,
      declineTextColor: style.declineTextColor,
      acceptTextStyle: style.acceptTextStyle,
      declineTextStyle: style.declineTextStyle,
      callIconColor: style.callIconColor,
    );
  }

  @override
  CometChatIncomingCallStyle lerp(
    ThemeExtension<CometChatIncomingCallStyle>? other,
    double t,
  ) {
    if (other is! CometChatIncomingCallStyle) {
      return this;
    }
    return CometChatIncomingCallStyle(
      titleTextStyle: TextStyle.lerp(titleTextStyle, other.titleTextStyle, t),
      titleColor: Color.lerp(titleColor, other.titleColor, t),
      subtitleTextStyle: TextStyle.lerp(
        subtitleTextStyle,
        other.subtitleTextStyle,
        t,
      ),
      subtitleColor: Color.lerp(subtitleColor, other.subtitleColor, t),
      avatarStyle: avatarStyle?.lerp(other.avatarStyle, t),
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      declineButtonColor: Color.lerp(
        declineButtonColor,
        other.declineButtonColor,
        t,
      ),
      acceptButtonColor: Color.lerp(
        acceptButtonColor,
        other.acceptButtonColor,
        t,
      ),
      border: Border.lerp(border, other.border, t),
      borderRadius: BorderRadiusGeometry.lerp(
        borderRadius,
        other.borderRadius,
        t,
      ),
      acceptTextColor: Color.lerp(acceptTextColor, other.acceptTextColor, t),
      declineTextColor: Color.lerp(declineTextColor, other.declineTextColor, t),
      acceptTextStyle: TextStyle.lerp(
        acceptTextStyle,
        other.acceptTextStyle,
        t,
      ),
      declineTextStyle: TextStyle.lerp(
        declineTextStyle,
        other.declineTextStyle,
        t,
      ),
      callIconColor: Color.lerp(callIconColor, other.callIconColor, t),
    );
  }
}
