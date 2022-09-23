import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_chat_ui_kit/src/utils/container_dotted_border.dart';

///creates a widget that gives delete bubble
///
///used by default  when messageObject.deletedAt!=null for all types of messages
class CometChatDeleteMessageBubble extends StatelessWidget {
  const CometChatDeleteMessageBubble(
      {Key? key, this.textStyle, this.background, this.borderColor})
      : super(key: key);

  ///[textStyle] delete message bubble text style
  final TextStyle? textStyle;

  ///[background] background color of bubble
  final Color? background;

  ///[borderColor] border color of bubble
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return DottedBorder(
      radius: const Radius.circular(8),
      color: borderColor ?? const Color(0xff141414).withOpacity(0.16),
      strokeWidth: 1,
      child: Container(
        height: 36,
        width: 164,
        decoration: BoxDecoration(
          color: background ?? const Color(0xff3399FF).withOpacity(0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            Translations.of(context).message_is_deleted,
            style: textStyle ??
                TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xff141414).withOpacity(0.4)),
          ),
        ),
      ),
    );
  }
}
