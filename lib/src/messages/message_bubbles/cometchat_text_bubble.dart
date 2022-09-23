import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bubble_utils.dart';

///creates a widget that gives text bubble
///
///used by default  when [messageObject.category]=message and [messageObject.type]=[MessageTypeConstants.text]
class CometChatTextBubble extends StatelessWidget {
  const CometChatTextBubble(
      {Key? key,
      this.textStyle,
      this.messageObject,
      this.text,
      this.loggedInUserId})
      : super(key: key);

  ///[textStyle] for the text
  final TextStyle? textStyle;

  ///[messageObject]text message object
  final TextMessage? messageObject;

  ///[text] if message object is not passed then text should be passed
  final String? text;

  ///[loggedInUserId] logged in user uid
  final String? loggedInUserId;

  onTapUrl(String url) async {
    if (BubbleUtils.urlRegex.hasMatch(url)) {
      await launch(url);
    } else if (BubbleUtils.emailRegex.hasMatch(url)) {
      await launch('mailto:$url');
    } else if (BubbleUtils.phoneNumberRegex.hasMatch(url)) {
      await launch('tel:$url');
    }
  }

  TextStyle getTextStyle(String word) {
    if (BubbleUtils.urlRegex.hasMatch(word)) {
      return const TextStyle(decoration: TextDecoration.underline);
    } else if (BubbleUtils.emailRegex.hasMatch(word)) {
      return const TextStyle(decoration: TextDecoration.underline);
    } else if (BubbleUtils.phoneNumberRegex.hasMatch(word)) {
      return const TextStyle(decoration: TextDecoration.underline);
    } else if (textStyle != null) {
      return textStyle!;
    }
    return const TextStyle(
      color: Color(0xff141414),
      fontSize: 17,
      fontWeight: FontWeight.w400,
    );
  }

  @override
  Widget build(BuildContext context) {
    String? _message;
    List<dynamic> links = [];
    if (text != null) {
      _message = text;
    } else if (messageObject != null) {
      if (loggedInUserId == null ||
          (loggedInUserId != null &&
              messageObject?.sender?.uid != null &&
              messageObject?.sender?.uid != loggedInUserId)) {
        _message = Extensions.checkProfanityMessage(messageObject!);
        if (_message == messageObject!.text) {
          _message = Extensions.checkDataMasking(messageObject!);
        }
      } else {
        _message = messageObject?.text;
      }
      links = Extensions.getMessageLinks(messageObject!);
    }
    if (_message == null) {
      return const SizedBox(height: 0, width: 0);
    }

    List<String> words = _message.split(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //-----link preview image-----
        if (links.isNotEmpty &&
            links[0]["image"] != null &&
            links[0]["image"].toString().isNotEmpty)
          Center(
            child: Image.network(links[0]["image"],
                height: 108,
                width: MediaQuery.of(context).size.width * 65 / 100,
                fit: BoxFit.cover, errorBuilder: (context, object, stack) {
              return const SizedBox(
                height: 0,
                width: 0,
              );
            }),
          ),

        //-----link preview title-----
        if (links.isNotEmpty && links[0]["title"] != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              links[0]["title"],
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xff141414)),
            ),
          ),

        //-----text-----
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
          child: RichText(
            text: TextSpan(
                style: textStyle ??
                    const TextStyle(
                      color: Color(0xff141414),
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                    ),
                children: [
                  for (String word in words)
                    TextSpan(
                        text: word + ' ',
                        style: getTextStyle(word),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            await onTapUrl(word);
                          })
                ]),
          ),
        )
      ],
    );
  }
}
