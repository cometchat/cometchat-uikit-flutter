import 'package:flutter/material.dart';
import '../../../../cometchat_uikit_shared.dart' show SnackBarConfiguration;

class SnackBarUtils {
  static void show(
    String text,
    BuildContext context, {
    SnackBarConfiguration? snackBarConfiguration,
  }) {
    SnackBar snackBar = SnackBar(
      backgroundColor: snackBarConfiguration?.backgroundColor,
      elevation: snackBarConfiguration?.elevation,
      margin: snackBarConfiguration?.margin,
      // SnackBar asserts `margin == null` unless the behavior is floating, so
      // setting SnackBarConfiguration.margin used to crash the frame outright.
      // Only opt into floating when a margin is actually supplied, so the
      // default appearance is unchanged for everyone else.
      behavior: snackBarConfiguration?.margin != null
          ? SnackBarBehavior.floating
          : null,
      padding: snackBarConfiguration?.padding,
      duration: snackBarConfiguration?.duration ?? const Duration(seconds: 2),
      content: Text(text, style: snackBarConfiguration?.contentTextStyle),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
