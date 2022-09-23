import 'package:flutter/material.dart';
import '../../../flutter_chat_ui_kit.dart';

/// Creates a widget that that gives message receipts  UI.
class CometChatMessageReceipt extends StatelessWidget {
  const CometChatMessageReceipt({
    Key? key,
    this.waitIcon,
    this.sentIcon,
    this.deliveredIcon,
    this.errorIcon,
    this.readIcon,
    required this.message,
  }) : super(key: key);

  ///[waitIcon] widget visible while sentAt and deliveredAt is null in [message]. If blank will load default waitIcon
  final Widget? waitIcon;

  ///[sentIcon] widget visible while sentAt != null and deliveredAt is null in [message]. If blank will load default sentIcon
  final Widget? sentIcon;

  ///[deliveredIcon] widget visible while  deliveredAt != null  in [message]. If blank will load default deliveredIcon
  final Widget? deliveredIcon;

  ///[errorIcon] widget visible while sentAt and deliveredAt is null in [message]. If blank will load default errorIcon
  final Widget? errorIcon;

  ///[readIcon] widget visible when readAt != null in [message]. If blank will load default readIcon
  final Widget? readIcon;

  ///message object from which sentAt and readAt will be read to get the receipts
  final BaseMessage message;

  @override
  Widget build(BuildContext context) {
    late Widget receiptWidget;
    receiptWidget = waitIcon ?? const CircularProgressIndicator();
    if (message.metadata != null &&
        message.metadata!.containsKey("error") &&
        message.metadata?["error"] == true) {
      receiptWidget = const Icon(Icons.error_outline, size: 14);
    } else if (message.readAt != null) {
      receiptWidget = readIcon ??
          Image.asset(
            "assets/icons/message_received.png",
            package: UIConstants.packageName,
            color: const Color(0xff3399FF),
          );
    } else if (message.deliveredAt != null) {
      receiptWidget = deliveredIcon ??
          Image.asset(
            "assets/icons/message_received.png",
            package: UIConstants.packageName,
          );
    } else if (message.sentAt != null) {
      receiptWidget = sentIcon ??
          Image.asset(
            "assets/icons/message_sent.png",
            package: UIConstants.packageName,
          );
    } else if (message.sentAt == null) {
      receiptWidget = waitIcon ??
          const SizedBox(
            height: 14,
            width: 14,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          );
    } else {
      receiptWidget = const SizedBox();
    }

    return receiptWidget;
  }
}
