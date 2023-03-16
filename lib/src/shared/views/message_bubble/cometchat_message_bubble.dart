import 'package:flutter/material.dart';

import '../../../../flutter_chat_ui_kit.dart';

class CometChatMessageBubble extends StatelessWidget {
  const CometChatMessageBubble(
      {Key? key,
      this.style = const MessageBubbleStyle(),
      this.alignment,
      this.contentView,
      this.footerView,
      this.headerView,
      this.leadingView,
      this.replyView,
      this.threadView,
      this.bottomView})
      : super(key: key);

  final Widget? leadingView;

  final Widget? headerView;

  final Widget? replyView;

  final Widget? contentView;

  final Widget? threadView;

  final Widget? footerView;

  final BubbleAlignment? alignment;

  final MessageBubbleStyle style;

  final Widget? bottomView;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          //color: Colors.red,
          gradient: style.gradient,
          border: style.border,
          borderRadius: BorderRadius.circular(style.borderRadius ?? 0)),
      child: Padding(
        padding: style.contentPadding ?? const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leadingView != null) leadingView!,
            Column(
              crossAxisAlignment: alignment == BubbleAlignment.right
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [headerView ?? const SizedBox()],
                ),
                //-----bubble-----
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: alignment == BubbleAlignment.right
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 3,
                      ),
                      child: Container(
                        constraints: BoxConstraints(
                            maxWidth: style.width ??
                                MediaQuery.of(context).size.width * 65 / 100),
                        decoration: BoxDecoration(
                            color: style.background ??
                                const Color(0xffF8F8F8).withOpacity(0.92),
                            borderRadius: BorderRadius.all(
                                Radius.circular(style.borderRadius ?? 8)),
                            border: style.border,
                            gradient: style.gradient),
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(
                              Radius.circular(style.borderRadius ?? 8)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (replyView != null) replyView!,

                              if (contentView != null) contentView!,

                              if (bottomView != null) bottomView!,

                              //-----thread replies-----
                              if (threadView != null) threadView!,
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (footerView != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: footerView!,
                      )
                  ],
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
