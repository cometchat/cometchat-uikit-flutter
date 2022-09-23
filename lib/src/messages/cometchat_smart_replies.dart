import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'message_bubbles/bubble_utils.dart';

class CometChatSmartReplies extends StatelessWidget {
  const CometChatSmartReplies({
    Key? key,
    required this.messageObject,
    this.style = const SmartReplyStyle(),
    this.onCloseTap,
    this.onClick,
  }) : super(key: key);
  final BaseMessage messageObject;

  final SmartReplyStyle style;

  final void Function()? onCloseTap;

  final void Function(String)? onClick;

  List<String> getReplies() {
    List<String> _replies = [];
    Map<String, dynamic>? map = Extensions.extensionCheck(messageObject);

    if (map != null && map.containsKey(ExtensionConstants.smartReply)) {
      Map<String, dynamic> smartReplies = map[ExtensionConstants.smartReply];
      if (smartReplies.containsKey("reply_neutral")) {
        _replies.add(smartReplies["reply_neutral"]);
      }
      if (smartReplies.containsKey("reply_negative")) {
        _replies.add(smartReplies["reply_negative"]);
      }
      if (smartReplies.containsKey("reply_positive")) {
        _replies.add(smartReplies["reply_positive"]);
      }
    }
    return _replies;
  }

  @override
  Widget build(BuildContext context) {
    List<String> _replies = getReplies();

    if (_replies.isEmpty) {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }

    return Container(
      padding: const EdgeInsets.only(left: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (String reply in _replies)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () {
                    if (onClick != null) {
                      onClick!(reply);
                    }
                  },
                  child: Chip(
                    backgroundColor:
                        style.replyBackgroundColor ?? const Color(0xffFFFFFF),
                    elevation: 4,
                    shadowColor: const Color(0xffFFFFFF).withOpacity(0.8),
                    label: Text(
                      reply,
                      style: style.replyTextStyle ??
                          const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: Color(0xff141414)),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () {
                  if (onCloseTap != null) {
                    onCloseTap!();
                  }
                },
                child: Image.asset(
                  "assets/icons/close.png",
                  package: UIConstants.packageName,
                  color: style.closeIconColor ??
                      const Color(0xff141414).withOpacity(0.40),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class SmartReplyStyle {
  const SmartReplyStyle(
      {this.replyTextStyle, this.replyBackgroundColor, this.closeIconColor});

  final TextStyle? replyTextStyle;

  final Color? replyBackgroundColor;

  final Color? closeIconColor;
}
