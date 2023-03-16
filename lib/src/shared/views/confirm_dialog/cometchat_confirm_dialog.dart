import 'package:flutter/material.dart';

showCometChatConfirmDialog(
    {required BuildContext context,
    Widget? title,
    Widget? messageText,
    String? confirmButtonText,
    String? cancelButtonText,
    Function()? onConfirm,
    Function()? onCancel,
    ConfirmDialogStyle style = const ConfirmDialogStyle()}) {
  showDialog(
    context: context,
    barrierColor: style.shadowColor ?? const Color(0xff000000).withOpacity(0.2),
    builder: (BuildContext context) {
      return AlertDialog(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0))),
        backgroundColor: style.backgroundColor ?? const Color(0xffFFFFFF),
        elevation: 10,
        title: title,
        content: messageText,
        actions: [
          if (cancelButtonText != null)
            TextButton(
              child: Text(
                cancelButtonText,
                style: style.cancelButtonTextStyle ??
                    const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xff3399FF)),
              ),
              onPressed: onCancel ??
                  () {
                    Navigator.of(context).pop();
                  },
            ),
          if (confirmButtonText != null)
            TextButton(
              child: Text(confirmButtonText,
                  style: style.confirmButtonTextStyle ??
                      const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xff3399FF))),
              onPressed: onConfirm ??
                  () {
                    Navigator.of(context).pop();
                  },
            ),
        ],
      );
    },
  );
}

class ConfirmDialogStyle {
  ///confirm dialog style
  const ConfirmDialogStyle(
      {this.backgroundColor,
      this.shadowColor,
      this.confirmButtonTextStyle,
      this.cancelButtonTextStyle});

  final Color? backgroundColor;
  final Color? shadowColor;
  final TextStyle? confirmButtonTextStyle;
  final TextStyle? cancelButtonTextStyle;
}
