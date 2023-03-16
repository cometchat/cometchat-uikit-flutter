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
    
    // print( "Placeholder for ${message.id} category ${message.category} type ${message.type}");

    return Container(
      height: style.height,
      width: style.width,
      decoration: BoxDecoration(
          border: style.border,
          borderRadius: BorderRadius.circular(style.borderRadius ?? 0),
          color: style.gradient == null
              ? style.background ?? Colors.transparent
              : null,
          gradient: style.gradient),
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
