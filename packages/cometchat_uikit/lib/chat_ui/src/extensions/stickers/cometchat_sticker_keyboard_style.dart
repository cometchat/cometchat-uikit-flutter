import 'package:flutter/material.dart';

///[CometChatStickerKeyboardStyle] styles the `CometChatStickerKeyboard`
///(Android's `CometChatStickerKeyboardStyle`). Every field is optional — null
///keeps the keyboard's theme-driven default.
///
///Pass it to `CometChatStickerKeyboard.style`, to
///`CometChatMessageComposerStyle.stickerKeyboardStyle` for the keyboard the
///composer opens, or register it as a [ThemeExtension]; the widget-level style
///wins over the theme, field by field.
/// ```dart
/// CometChatStickerKeyboardStyle(
///   backgroundColor: Colors.white,
///   separatorColor: Colors.black12,
///   tabActiveIndicatorColor: Colors.purple.shade50,
/// );
/// ```
class CometChatStickerKeyboardStyle
    extends ThemeExtension<CometChatStickerKeyboardStyle> {
  /// Creates a [CometChatStickerKeyboardStyle]. Null fields keep the defaults.
  const CometChatStickerKeyboardStyle({
    this.backgroundColor,
    this.separatorColor,
    this.tabActiveIndicatorColor,
    this.emptyStateTextStyle,
    this.emptyStateTextColor,
    this.emptyStateSubTitleTextStyle,
    this.emptyStateSubTitleTextColor,
    this.errorStateTextStyle,
    this.errorStateTextColor,
  });

  ///[backgroundColor] fills the keyboard, including its loading, empty and
  ///error states and the sticker-set tab bar. Defaults to the palette's
  ///`background1`.
  final Color? backgroundColor;

  ///[separatorColor] draws a 1px line between the sticker grid and the
  ///sticker-set tab bar. No line is drawn when null.
  final Color? separatorColor;

  ///[tabActiveIndicatorColor] fills the selected sticker-set tab. Defaults to
  ///the palette's `extendedPrimary100`.
  final Color? tabActiveIndicatorColor;

  ///[emptyStateTextStyle] styles the empty-state title
  ///("No Stickers Available").
  final TextStyle? emptyStateTextStyle;

  ///[emptyStateTextColor] colours the empty-state title; wins over the colour
  ///of [emptyStateTextStyle].
  final Color? emptyStateTextColor;

  ///[emptyStateSubTitleTextStyle] styles the empty-state subtitle.
  final TextStyle? emptyStateSubTitleTextStyle;

  ///[emptyStateSubTitleTextColor] colours the empty-state subtitle; wins over
  ///the colour of [emptyStateSubTitleTextStyle].
  final Color? emptyStateSubTitleTextColor;

  ///[errorStateTextStyle] styles the error-state message.
  final TextStyle? errorStateTextStyle;

  ///[errorStateTextColor] colours the error-state message; wins over the
  ///colour of [errorStateTextStyle].
  final Color? errorStateTextColor;

  /// The fallback `CometChatThemeHelper.getTheme` uses when no
  /// [CometChatStickerKeyboardStyle] is registered on the theme: every field
  /// null, so the keyboard keeps its defaults.
  static CometChatStickerKeyboardStyle of(BuildContext context) =>
      const CometChatStickerKeyboardStyle();

  @override
  CometChatStickerKeyboardStyle copyWith({
    Color? backgroundColor,
    Color? separatorColor,
    Color? tabActiveIndicatorColor,
    TextStyle? emptyStateTextStyle,
    Color? emptyStateTextColor,
    TextStyle? emptyStateSubTitleTextStyle,
    Color? emptyStateSubTitleTextColor,
    TextStyle? errorStateTextStyle,
    Color? errorStateTextColor,
  }) {
    return CometChatStickerKeyboardStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      separatorColor: separatorColor ?? this.separatorColor,
      tabActiveIndicatorColor:
          tabActiveIndicatorColor ?? this.tabActiveIndicatorColor,
      emptyStateTextStyle: emptyStateTextStyle ?? this.emptyStateTextStyle,
      emptyStateTextColor: emptyStateTextColor ?? this.emptyStateTextColor,
      emptyStateSubTitleTextStyle:
          emptyStateSubTitleTextStyle ?? this.emptyStateSubTitleTextStyle,
      emptyStateSubTitleTextColor:
          emptyStateSubTitleTextColor ?? this.emptyStateSubTitleTextColor,
      errorStateTextStyle: errorStateTextStyle ?? this.errorStateTextStyle,
      errorStateTextColor: errorStateTextColor ?? this.errorStateTextColor,
    );
  }

  /// Returns a copy of this style with the non-null fields of [style] on top.
  CometChatStickerKeyboardStyle merge(CometChatStickerKeyboardStyle? style) {
    if (style == null) return this;
    return copyWith(
      backgroundColor: style.backgroundColor,
      separatorColor: style.separatorColor,
      tabActiveIndicatorColor: style.tabActiveIndicatorColor,
      emptyStateTextStyle: style.emptyStateTextStyle,
      emptyStateTextColor: style.emptyStateTextColor,
      emptyStateSubTitleTextStyle: style.emptyStateSubTitleTextStyle,
      emptyStateSubTitleTextColor: style.emptyStateSubTitleTextColor,
      errorStateTextStyle: style.errorStateTextStyle,
      errorStateTextColor: style.errorStateTextColor,
    );
  }

  @override
  CometChatStickerKeyboardStyle lerp(
    ThemeExtension<CometChatStickerKeyboardStyle>? other,
    double t,
  ) {
    if (other is! CometChatStickerKeyboardStyle) return this;
    return CometChatStickerKeyboardStyle(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      separatorColor: Color.lerp(separatorColor, other.separatorColor, t),
      tabActiveIndicatorColor: Color.lerp(
        tabActiveIndicatorColor,
        other.tabActiveIndicatorColor,
        t,
      ),
      emptyStateTextStyle: TextStyle.lerp(
        emptyStateTextStyle,
        other.emptyStateTextStyle,
        t,
      ),
      emptyStateTextColor: Color.lerp(
        emptyStateTextColor,
        other.emptyStateTextColor,
        t,
      ),
      emptyStateSubTitleTextStyle: TextStyle.lerp(
        emptyStateSubTitleTextStyle,
        other.emptyStateSubTitleTextStyle,
        t,
      ),
      emptyStateSubTitleTextColor: Color.lerp(
        emptyStateSubTitleTextColor,
        other.emptyStateSubTitleTextColor,
        t,
      ),
      errorStateTextStyle: TextStyle.lerp(
        errorStateTextStyle,
        other.errorStateTextStyle,
        t,
      ),
      errorStateTextColor: Color.lerp(
        errorStateTextColor,
        other.errorStateTextColor,
        t,
      ),
    );
  }
}
