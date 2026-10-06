import 'package:flutter/material.dart';
import '../base_styles.dart';

/// Style for the check box interactive element.
@Deprecated(
  'Has no effect: v6 renders form-message elements as unsupported, as the Android UI Kit does, so nothing reads it. No replacement. Will be removed in 7.0.0.',
)
class CheckBoxElementStyle extends BaseStyles {
  /// Creates a [CheckBoxElementStyle].
  CheckBoxElementStyle({
    this.labelStyle,
    this.activeColor,
    this.checkColor,
    this.optionTextStyle,
    super.width,
    super.height,
    super.background,
    super.border,
    super.borderRadius,
    super.gradient,
  });

  /// The label style. Has no effect; deprecated with this class.
  final TextStyle? labelStyle;

  /// The active color. Has no effect; deprecated with this class.
  final Color? activeColor;

  /// The check color. Has no effect; deprecated with this class.
  final Color? checkColor;

  /// The option text style. Has no effect; deprecated with this class.
  final TextStyle? optionTextStyle;

  /// Returns this style with the non-null values of [mergeWith] applied.
  CheckBoxElementStyle merge(CheckBoxElementStyle mergeWith) {
    return CheckBoxElementStyle(
      labelStyle: labelStyle ?? mergeWith.labelStyle,
      activeColor: activeColor ?? mergeWith.activeColor,
      checkColor: checkColor ?? mergeWith.checkColor,
      optionTextStyle: optionTextStyle ?? mergeWith.optionTextStyle,
      width: width ?? mergeWith.width,
      height: height ?? mergeWith.height,
      background: background ?? mergeWith.background,
      border: border ?? mergeWith.border,
      borderRadius: borderRadius ?? mergeWith.borderRadius,
      gradient: gradient ?? mergeWith.gradient,
    );
  }
}
