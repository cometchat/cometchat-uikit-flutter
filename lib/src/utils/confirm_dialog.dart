import 'package:flutter/material.dart';

showConfirmDialog(
  BuildContext context,
  Widget title,
  List<Widget> actions,
  Widget content, {
  Color? background,
  Color? shadowColor,
  Color? progressIndicatorColor,
  bool? barrierDismissible,
}) {
  showDialog(
      context: context,
      barrierDismissible: barrierDismissible ?? false,
      barrierColor: shadowColor ?? const Color(0xff000000).withOpacity(0.2),
      builder: (BuildContext context) {
        return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 80),
            backgroundColor: background ?? const Color(0xffFFFFFF),
            title: title,
            actions: actions,
            content: content);
      });
}
