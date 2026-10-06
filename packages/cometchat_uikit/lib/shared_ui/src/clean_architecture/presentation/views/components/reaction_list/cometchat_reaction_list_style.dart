import 'package:flutter/material.dart';

import '../../misc/avatar/cometchat_avatar_style.dart';

///[CometChatReactionListStyle] is a class which is used to set the style for the reaction list
///It takes `loadingStateColor`, [emptyTextStyle], [errorTextStyle], [subtitleTextStyle], `width`, `height`, `background`, `gradient`, [border], [borderRadius] as a parameter
///
/// ```dart
/// ReactionListStyle(
/// loadingIconTint: Colors.white,
/// emptyTextStyle: TextStyle(color: Colors.white),
/// errorTextStyle: TextStyle(color: Colors.white),
/// subtitleTextStyle: TextStyle(color: Colors.white),
/// background: Colors.blue,
/// );
class CometChatReactionListStyle
    extends ThemeExtension<CometChatReactionListStyle> {
  CometChatReactionListStyle({
    this.subtitleTextStyle,
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.errorTextStyle,
    this.errorTextColor,
    this.errorSubtitleStyle,
    this.errorSubtitleColor,
    this.titleTextStyle,
    this.titleTextColor,
    this.tabTextStyle,
    this.tabTextColor,
    this.activeTabTextColor,
    this.activeTabIndicatorColor,
    this.activeTabBackgroundColor,
    this.tailViewTextStyle,
    this.subtitleTextColor,
    this.emptyTextStyle,
    this.avatarStyle,
  });

  ///[backgroundColor] provides background color to the modal sheet
  final Color? backgroundColor;

  ///[border] provides border to the the modal sheet
  final BoxBorder? border;

  ///[borderRadius] provides border radius to the the modal sheet
  final BorderRadiusGeometry? borderRadius;

  ///[subtitleTextStyle] provides styling to the text in the subtitle
  final TextStyle? subtitleTextStyle;

  ///[emptyTextStyle] defines the style of the text to be displayed when the reaction list is empty
  final TextStyle? emptyTextStyle;

  ///[errorTextStyle] defines the style of the text to be displayed when the reaction list is in error state
  final TextStyle? errorTextStyle;

  ///[errorTextColor] defines the color of the text to be displayed when the reaction list is in error state
  final Color? errorTextColor;

  ///[errorSubtitleStyle] defines the style of the subtitle to be displayed when the reaction list is in error state
  final TextStyle? errorSubtitleStyle;

  ///[errorSubtitleColor] defines the color of the subtitle to be displayed when the message list is in error state
  final Color? errorSubtitleColor;

  ///[titleTextStyle] provides styling to the title of the modal sheet
  final TextStyle? titleTextStyle;

  ///[titleTextColor] provides color to the title of the modal sheet
  final Color? titleTextColor;

  ///[tabTextStyle] provides styling to the tabs in the modal sheet
  final TextStyle? tabTextStyle;

  ///[tabTextColor] provides color to the tabs in the modal sheet
  final Color? tabTextColor;

  ///[activeTabTextColor] provides color to the active tab in the modal sheet
  final Color? activeTabTextColor;

  ///[activeTabIndicatorColor] provides color to the active tab indicator in the modal sheet
  final Color? activeTabIndicatorColor;

  ///[activeTabBackgroundColor] provides background color to the active tab in the modal sheet
  final Color? activeTabBackgroundColor;

  ///[tailViewTextStyle] provides styling to the tail view in the modal sheet
  final TextStyle? tailViewTextStyle;

  ///[subtitleTextStyle] provides styling to the subtitle in the modal sheet
  final Color? subtitleTextColor;

  ///[avatarStyle] styles the avatar on each reactor row. The list's own
  ///[CometChatReactionList.avatarStyle], when set, takes precedence.
  final CometChatAvatarStyle? avatarStyle;

  @override
  CometChatReactionListStyle copyWith({
    TextStyle? subtitleTextStyle,
    Color? backgroundColor,
    BoxBorder? border,
    BorderRadiusGeometry? borderRadius,
    TextStyle? errorTextStyle,
    Color? errorTextColor,
    TextStyle? errorSubtitleStyle,
    Color? errorSubtitleColor,
    TextStyle? titleTextStyle,
    Color? titleTextColor,
    TextStyle? tabTextStyle,
    Color? tabTextColor,
    Color? activeTabTextColor,
    Color? activeTabIndicatorColor,
    Color? activeTabBackgroundColor,
    TextStyle? tailViewTextStyle,
    Color? subtitleTextColor,
    TextStyle? emptyTextStyle,
    CometChatAvatarStyle? avatarStyle,
  }) {
    return CometChatReactionListStyle(
      subtitleTextStyle: subtitleTextStyle ?? this.subtitleTextStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      errorTextStyle: errorTextStyle ?? this.errorTextStyle,
      errorTextColor: errorTextColor ?? this.errorTextColor,
      errorSubtitleStyle: errorSubtitleStyle ?? this.errorSubtitleStyle,
      errorSubtitleColor: errorSubtitleColor ?? this.errorSubtitleColor,
      titleTextStyle: titleTextStyle ?? this.titleTextStyle,
      titleTextColor: titleTextColor ?? this.titleTextColor,
      tabTextStyle: tabTextStyle ?? this.tabTextStyle,
      tabTextColor: tabTextColor ?? this.tabTextColor,
      activeTabTextColor: activeTabTextColor ?? this.activeTabTextColor,
      activeTabIndicatorColor:
          activeTabIndicatorColor ?? this.activeTabIndicatorColor,
      activeTabBackgroundColor:
          activeTabBackgroundColor ?? this.activeTabBackgroundColor,
      tailViewTextStyle: tailViewTextStyle ?? this.tailViewTextStyle,
      subtitleTextColor: subtitleTextColor ?? this.subtitleTextColor,
      emptyTextStyle: emptyTextStyle ?? this.emptyTextStyle,
      avatarStyle: avatarStyle ?? this.avatarStyle,
    );
  }

  @override
  CometChatReactionListStyle lerp(
    covariant ThemeExtension<CometChatReactionListStyle>? other,
    double t,
  ) {
    if (other is! CometChatReactionListStyle) {
      return this;
    }
    return copyWith(
      subtitleTextStyle: TextStyle.lerp(
        subtitleTextStyle,
        other.subtitleTextStyle,
        t,
      ),
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      border: BoxBorder.lerp(border, other.border, t),
      borderRadius: BorderRadiusGeometry.lerp(
        borderRadius,
        other.borderRadius,
        t,
      ),
      errorTextStyle: TextStyle.lerp(errorTextStyle, other.errorTextStyle, t),
      errorTextColor: Color.lerp(errorTextColor, other.errorTextColor, t),
      errorSubtitleStyle: TextStyle.lerp(
        errorSubtitleStyle,
        other.errorSubtitleStyle,
        t,
      ),
      errorSubtitleColor: Color.lerp(
        errorSubtitleColor,
        other.errorSubtitleColor,
        t,
      ),
      titleTextStyle: TextStyle.lerp(titleTextStyle, other.titleTextStyle, t),
      titleTextColor: Color.lerp(titleTextColor, other.titleTextColor, t),
      tabTextStyle: TextStyle.lerp(tabTextStyle, other.tabTextStyle, t),
      tabTextColor: Color.lerp(tabTextColor, other.tabTextColor, t),
      activeTabTextColor: Color.lerp(
        activeTabTextColor,
        other.activeTabTextColor,
        t,
      ),
      activeTabIndicatorColor: Color.lerp(
        activeTabIndicatorColor,
        other.activeTabIndicatorColor,
        t,
      ),
      activeTabBackgroundColor: Color.lerp(
        activeTabBackgroundColor,
        other.activeTabBackgroundColor,
        t,
      ),
      tailViewTextStyle: TextStyle.lerp(
        tailViewTextStyle,
        other.tailViewTextStyle,
        t,
      ),
      subtitleTextColor: Color.lerp(
        subtitleTextColor,
        other.subtitleTextColor,
        t,
      ),
      emptyTextStyle: TextStyle.lerp(emptyTextStyle, other.emptyTextStyle, t),
      avatarStyle: avatarStyle?.lerp(other.avatarStyle, t) ?? other.avatarStyle,
    );
  }

  CometChatReactionListStyle merge(CometChatReactionListStyle? style) {
    if (style == null) return this;
    return copyWith(
      subtitleTextStyle: style.subtitleTextStyle,
      backgroundColor: style.backgroundColor,
      border: style.border,
      borderRadius: style.borderRadius,
      errorTextStyle: style.errorTextStyle,
      errorTextColor: style.errorTextColor,
      errorSubtitleStyle: style.errorSubtitleStyle,
      errorSubtitleColor: style.errorSubtitleColor,
      titleTextStyle: style.titleTextStyle,
      titleTextColor: style.titleTextColor,
      tabTextStyle: style.tabTextStyle,
      tabTextColor: style.tabTextColor,
      activeTabTextColor: style.activeTabTextColor,
      activeTabIndicatorColor: style.activeTabIndicatorColor,
      activeTabBackgroundColor: style.activeTabBackgroundColor,
      tailViewTextStyle: style.tailViewTextStyle,
      subtitleTextColor: style.subtitleTextColor,
      emptyTextStyle: style.emptyTextStyle,
      avatarStyle: style.avatarStyle,
    );
  }

  static CometChatReactionListStyle of(BuildContext context) {
    return CometChatReactionListStyle();
  }
}
