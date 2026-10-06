import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../../../shared_ui/cometchat_uikit_shared.dart';

/// Style configuration for the rich text formatting toolbar
@immutable
class CometChatRichTextToolbarStyle
    extends ThemeExtension<CometChatRichTextToolbarStyle> {
  const CometChatRichTextToolbarStyle({
    this.backgroundColor,
    this.buttonColor,
    this.activeButtonColor,
    this.disabledButtonColor,
    this.buttonIconColor,
    this.activeButtonIconColor,
    this.disabledButtonIconColor,
    this.borderRadius,
    this.border,
    this.buttonSpacing,
    this.padding,
    this.buttonSize,
    this.iconSize,
    this.dividerColor,
  });

  /// Background color of the toolbar
  final Color? backgroundColor;

  /// Background color of inactive buttons
  final Color? buttonColor;

  /// Background color of active buttons
  final Color? activeButtonColor;

  /// Background color of disabled buttons (incompatible formats)
  final Color? disabledButtonColor;

  /// Icon color for inactive buttons
  final Color? buttonIconColor;

  /// Icon color for active buttons
  final Color? activeButtonIconColor;

  /// Icon color for disabled buttons (incompatible formats)
  final Color? disabledButtonIconColor;

  /// Border radius of the toolbar
  final BorderRadiusGeometry? borderRadius;

  /// Border of the toolbar
  final BoxBorder? border;

  /// Spacing between buttons
  final double? buttonSpacing;

  /// Padding inside the toolbar
  final EdgeInsetsGeometry? padding;

  /// Size of each button
  final double? buttonSize;

  /// Size of icons inside buttons
  final double? iconSize;

  /// Color of the divider between button groups
  final Color? dividerColor;

  /// Factory for theme-based defaults
  static CometChatRichTextToolbarStyle of(BuildContext context) {
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final spacing = CometChatThemeHelper.getSpacing(context);

    return CometChatRichTextToolbarStyle(
      backgroundColor: colorPalette.background2,
      buttonColor: Colors.transparent,
      activeButtonColor:
          colorPalette.neutral300?.withValues(alpha: 0.2) ??
          Colors.black.withValues(alpha: 0.08),
      disabledButtonColor: Colors.transparent,
      buttonIconColor: colorPalette.iconSecondary,
      activeButtonIconColor: colorPalette.neutral900 ?? Colors.black,
      disabledButtonIconColor: colorPalette.iconSecondary?.withValues(
        alpha: 0.3,
      ),
      borderRadius: BorderRadius.circular(spacing.radius2 ?? 8),
      buttonSpacing: 16,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.padding3 ?? 12,
        vertical: spacing.padding1 ?? 4,
      ),
      buttonSize: 32,
      iconSize: 24,
      dividerColor: colorPalette.borderDefault,
    );
  }

  /// Merge with another style
  CometChatRichTextToolbarStyle merge(CometChatRichTextToolbarStyle? other) {
    if (other == null) return this;
    return copyWith(
      backgroundColor: other.backgroundColor,
      buttonColor: other.buttonColor,
      activeButtonColor: other.activeButtonColor,
      disabledButtonColor: other.disabledButtonColor,
      buttonIconColor: other.buttonIconColor,
      activeButtonIconColor: other.activeButtonIconColor,
      disabledButtonIconColor: other.disabledButtonIconColor,
      borderRadius: other.borderRadius,
      border: other.border,
      buttonSpacing: other.buttonSpacing,
      padding: other.padding,
      buttonSize: other.buttonSize,
      iconSize: other.iconSize,
      dividerColor: other.dividerColor,
    );
  }

  @override
  CometChatRichTextToolbarStyle copyWith({
    Color? backgroundColor,
    Color? buttonColor,
    Color? activeButtonColor,
    Color? disabledButtonColor,
    Color? buttonIconColor,
    Color? activeButtonIconColor,
    Color? disabledButtonIconColor,
    BorderRadiusGeometry? borderRadius,
    BoxBorder? border,
    double? buttonSpacing,
    EdgeInsetsGeometry? padding,
    double? buttonSize,
    double? iconSize,
    Color? dividerColor,
  }) {
    return CometChatRichTextToolbarStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      buttonColor: buttonColor ?? this.buttonColor,
      activeButtonColor: activeButtonColor ?? this.activeButtonColor,
      disabledButtonColor: disabledButtonColor ?? this.disabledButtonColor,
      buttonIconColor: buttonIconColor ?? this.buttonIconColor,
      activeButtonIconColor:
          activeButtonIconColor ?? this.activeButtonIconColor,
      disabledButtonIconColor:
          disabledButtonIconColor ?? this.disabledButtonIconColor,
      borderRadius: borderRadius ?? this.borderRadius,
      border: border ?? this.border,
      buttonSpacing: buttonSpacing ?? this.buttonSpacing,
      padding: padding ?? this.padding,
      buttonSize: buttonSize ?? this.buttonSize,
      iconSize: iconSize ?? this.iconSize,
      dividerColor: dividerColor ?? this.dividerColor,
    );
  }

  @override
  CometChatRichTextToolbarStyle lerp(
    CometChatRichTextToolbarStyle? other,
    double t,
  ) {
    return CometChatRichTextToolbarStyle(
      backgroundColor: Color.lerp(backgroundColor, other?.backgroundColor, t),
      buttonColor: Color.lerp(buttonColor, other?.buttonColor, t),
      activeButtonColor: Color.lerp(
        activeButtonColor,
        other?.activeButtonColor,
        t,
      ),
      disabledButtonColor: Color.lerp(
        disabledButtonColor,
        other?.disabledButtonColor,
        t,
      ),
      buttonIconColor: Color.lerp(buttonIconColor, other?.buttonIconColor, t),
      activeButtonIconColor: Color.lerp(
        activeButtonIconColor,
        other?.activeButtonIconColor,
        t,
      ),
      disabledButtonIconColor: Color.lerp(
        disabledButtonIconColor,
        other?.disabledButtonIconColor,
        t,
      ),
      borderRadius: BorderRadiusGeometry.lerp(
        borderRadius,
        other?.borderRadius,
        t,
      ),
      border: BoxBorder.lerp(border, other?.border, t),
      buttonSpacing: lerpDouble(buttonSpacing, other?.buttonSpacing, t),
      buttonSize: lerpDouble(buttonSize, other?.buttonSize, t),
      iconSize: lerpDouble(iconSize, other?.iconSize, t),
      dividerColor: Color.lerp(dividerColor, other?.dividerColor, t),
      // Absent from the constructor call, so every animated theme transition
      // collapsed the toolbar's padding. ENG-39124.
      padding: EdgeInsetsGeometry.lerp(padding, other?.padding, t),
    );
  }
}
