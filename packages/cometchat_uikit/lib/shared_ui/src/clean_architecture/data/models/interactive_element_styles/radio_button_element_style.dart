import 'package:flutter/material.dart';
import '../base_styles.dart';

/// Style for the radio button interactive element.
@Deprecated(
  'Has no effect: v6 renders form-message elements as unsupported, as the Android UI Kit does, so nothing reads it. No replacement. Will be removed in 7.0.0.',
)
class RadioButtonElementStyle extends BaseStyles {
  /// Creates a [RadioButtonElementStyle].
  RadioButtonElementStyle({
    this.activeColor,
    this.labelStyle,
    this.optionTextStyle,
    this.radioColor,
    super.width,
    super.height,
    super.background,
    super.border,
    super.borderRadius,
    super.gradient,
  });

  /// The option text style. Has no effect; deprecated with this class.
  TextStyle? optionTextStyle;

  /// The label style. Has no effect; deprecated with this class.
  final TextStyle? labelStyle;

  /// The active color. Has no effect; deprecated with this class.
  final Color? activeColor;

  /// The radio color. Has no effect; deprecated with this class.
  final Color? radioColor;

  /// Returns this style with the non-null values of [mergeWith] applied.
  RadioButtonElementStyle merge(RadioButtonElementStyle mergeWith) {
    return RadioButtonElementStyle(
      optionTextStyle: optionTextStyle ?? mergeWith.optionTextStyle,
      labelStyle: labelStyle ?? mergeWith.labelStyle,
      activeColor: activeColor ?? mergeWith.activeColor,
      width: width ?? mergeWith.width,
      height: height ?? mergeWith.height,
      background: background ?? mergeWith.background,
      border: border ?? mergeWith.border,
      borderRadius: borderRadius ?? mergeWith.borderRadius,
      gradient: gradient ?? mergeWith.gradient,
      radioColor: radioColor ?? mergeWith.radioColor,
    );
  }
}
