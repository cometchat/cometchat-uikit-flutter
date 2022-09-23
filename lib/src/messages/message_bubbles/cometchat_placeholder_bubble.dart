import 'package:flutter/material.dart';

import '../../../flutter_chat_ui_kit.dart';

///creates a widget that is used as a fallback bubble
///
/// used by default when received message have no specified view
class CometChatPlaceholderBubble extends StatelessWidget {
  const CometChatPlaceholderBubble(
      {Key? key,
      this.style = const PlaceholderBubbleStyle(),
      required this.message})
      : super(key: key);

  final PlaceholderBubbleStyle style;

  final BaseMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(children: [
          Text("Default Placeholder",
              style: style.headerTextStyle ??
                  const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black)),
          const SizedBox(
            height: 5,
          ),
          Text(
              "'${message.type}' message type is not supported , kindly pass custom view in template for this type ",
              style: style.textStyle ??
                  const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                      color: Colors.black))
        ]),
      ),
    );
  }
}

class PlaceholderBubbleStyle {
  const PlaceholderBubbleStyle({this.textStyle, this.headerTextStyle});
  final TextStyle? textStyle;
  final TextStyle? headerTextStyle;
}
