import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_chat_ui_kit/src/utils/container_dotted_border.dart';

///creates a widget that gives delete bubble
///
///used by default  when messageObject.deletedAt!=null for all types of messages
class CometChatDeleteMessageBubble extends StatelessWidget {
  const CometChatDeleteMessageBubble(
      {Key? key, this.style=const DeletedBubbleStyle()})
      : super(key: key);

  ///[style] contains properties that affects the appearance of this widget
  final DeletedBubbleStyle style;
  @override
  Widget build(BuildContext context) {
    return DottedBorder(
      radius: const Radius.circular(8),
      color: style.borderColor ?? const Color(0xff141414).withOpacity(0.16),
      strokeWidth: 1,
      child: Container(
        height: style.height ?? 36,
      width: style.width ?? 164,
      decoration: BoxDecoration(
        border: style.border,
        borderRadius: BorderRadius.circular(style.borderRadius??0),
        color: style.gradient==null?style.background??const Color(0xff3399FF).withOpacity(0):null,
        gradient: style.gradient
      ),
      alignment: Alignment.center,
        child: Text(
          Translations.of(context).message_is_deleted,
          style: style.textStyle ??
              TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xff141414).withOpacity(0.4)),
        ),
      ),
    );
  }
}
