import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

///creates a widget that gives group action bubble
class CometChatGroupActionBubble extends StatelessWidget {
  const CometChatGroupActionBubble(
      {Key? key,
      this.message,
      required this.text,
      this.style = const GroupActionBubbleStyle()})
      : super(key: key);

  ///[message] action message object
  final String? message;

  ///[text] if message object is not passed then text should be passed
  final String? text;

  ///[style] group action bubble styling properties
  final GroupActionBubbleStyle style;

  @override
  Widget build(BuildContext context) {
    String? _text = text;
    if (_text == null) {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }

    return Container(
      height: style.height ?? 24,
      width: style.width,
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
      decoration: BoxDecoration(
          color: style.gradient != null
              ? style.background ?? const Color(0xff000000).withOpacity(0.0)
              : null,
          border: style.border ??
              Border.all(
                color: const Color(0xff141414).withOpacity(0.14),
              ),
          borderRadius: BorderRadius.circular(style.borderRadius ?? 11),
          gradient: style.gradient),
      alignment: Alignment.center,
      child: Text(
        _text.replaceAll('', '\u{200B}'),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        softWrap: false,
        style: style.textStyle ??
            TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: const Color(0xff141414).withOpacity(0.58)),
      ),
    );
  }
}
