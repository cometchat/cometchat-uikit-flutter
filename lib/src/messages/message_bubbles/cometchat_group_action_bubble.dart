import 'package:flutter/material.dart';
import 'package:cometchat/models/action.dart' as action;

///creates a widget that gives group action bubble
class CometChatGroupActionBubble extends StatelessWidget {
  const CometChatGroupActionBubble(
      {Key? key,
      this.messageObject,
      this.text,
      this.style = const GroupActionBubbleStyle()})
      : super(key: key);

  ///[messageObject] action message object
  final action.Action? messageObject;

  ///[text] if message object is not passed then text should be passed
  final String? text;

  ///[style] group action bubble styling properties
  final GroupActionBubbleStyle style;

  @override
  Widget build(BuildContext context) {
    String? _text;
    if (text != null) {
      _text = text;
    } else if (messageObject != null) {
      _text = messageObject!.message;
    }

    if (_text == null) {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }

    return Container(
      height: style.height ?? 24,
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
      decoration: BoxDecoration(
          color: const Color(0xff000000).withOpacity(0.0),
          border: Border.all(
            color: const Color(0xff141414).withOpacity(0.14),
          ),
          borderRadius: BorderRadius.circular(11)),
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

class GroupActionBubbleStyle {
  const GroupActionBubbleStyle({this.height, this.width, this.textStyle});

  ///[height] height of bubble
  final double? height;

  ///[width] width of bubble
  final double? width;

  ///[textStyle] text style of group action message
  final TextStyle? textStyle;
}
