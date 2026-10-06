import 'package:flutter/material.dart';
import '../base_styles.dart';

/// Style for the drop down interactive element.
@Deprecated(
  'Has no effect: v6 renders form-message elements as unsupported, as the Android UI Kit does, so nothing reads it. No replacement. Will be removed in 7.0.0.',
)
class DropDownElementStyle extends BaseStyles {
  /// Creates a [DropDownElementStyle].
  DropDownElementStyle({
    this.optionTextStyle,
    this.labelStyle,
    this.hintTextStyle,
    super.width,
    super.height,
    super.background,
    super.border,
    super.borderRadius,
    super.gradient,
  });

  /// The label style. Has no effect; deprecated with this class.
  final TextStyle? labelStyle;

  /// The option text style. Has no effect; deprecated with this class.
  final TextStyle? optionTextStyle;

  /// The hint text style. Has no effect; deprecated with this class.
  final TextStyle? hintTextStyle;

  /// Returns this style with the non-null values of [mergeWith] applied.
  DropDownElementStyle merge(DropDownElementStyle mergeWith) {
    return DropDownElementStyle(
      optionTextStyle: optionTextStyle ?? mergeWith.optionTextStyle,
      labelStyle: labelStyle ?? mergeWith.labelStyle,
      hintTextStyle: hintTextStyle ?? mergeWith.hintTextStyle,
      width: width ?? mergeWith.width,
      height: height ?? mergeWith.height,
      background: background ?? mergeWith.background,
      border: border ?? mergeWith.border,
      borderRadius: borderRadius ?? mergeWith.borderRadius,
      gradient: gradient ?? mergeWith.gradient,
    );
  }
}
