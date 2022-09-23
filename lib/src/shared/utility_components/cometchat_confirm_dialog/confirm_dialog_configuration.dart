import 'package:flutter/material.dart';

import '../../../../flutter_chat_ui_kit.dart';

class ConfirmDialogConfiguration {
  const ConfirmDialogConfiguration({
    this.messageText,
    this.confirmButtonText,
    this.cancelButtonText,
    this.onCancel,
    this.onConfirm,
    this.title,
    this.confirmDialogStyle = const ConfirmDialogStyle(),
  });

  final ConfirmDialogStyle confirmDialogStyle;

  final Widget? title;

  final Widget? messageText;

  final String? confirmButtonText;

  final String? cancelButtonText;

  final Function()? onConfirm;

  final Function()? onCancel;
}
