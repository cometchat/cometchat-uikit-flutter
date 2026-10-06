import 'package:flutter/material.dart';
import '../base_styles.dart';

/// Style for the date time interactive element.
@Deprecated(
  'Has no effect: v6 renders form-message elements as unsupported, as the Android UI Kit does, so nothing reads it. No replacement. Will be removed in 7.0.0.',
)
class DateTimeElementStyle extends BaseStyles {
  /// Creates a [DateTimeElementStyle].
  DateTimeElementStyle({
    this.textStyle,
    this.hintTextStyle,
    this.labelStyle,
    super.width,
    super.height,
    super.background,
    super.border,
    super.borderRadius,
    super.gradient,
  });

  /// The text style. Has no effect; deprecated with this class.
  TextStyle? textStyle;

  /// The label style. Has no effect; deprecated with this class.
  TextStyle? labelStyle;

  /// The hint text style. Has no effect; deprecated with this class.
  TextStyle? hintTextStyle;

  /// Returns this style with the non-null values of [mergeWith] applied.
  DateTimeElementStyle merge(DateTimeElementStyle mergeWith) {
    return DateTimeElementStyle(
      textStyle: textStyle ?? mergeWith.textStyle,
      hintTextStyle: hintTextStyle ?? mergeWith.hintTextStyle,
      width: width ?? mergeWith.width,
      height: height ?? mergeWith.height,
      background: background ?? mergeWith.background,
      border: border ?? mergeWith.border,
      borderRadius: borderRadius ?? mergeWith.borderRadius,
      gradient: gradient ?? mergeWith.gradient,
      labelStyle: labelStyle ?? mergeWith.labelStyle,
    );
  }
}
