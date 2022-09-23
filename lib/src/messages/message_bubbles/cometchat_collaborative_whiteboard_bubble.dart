import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_chat_ui_kit/src/messages/message_bubbles/cometchat_collaborative_webview.dart';

///creates a widget that gives collaborative whiteboard bubble
///
///used by default  when [messageObject.category]=[MessageTypes.custom] and [messageObject.type]=[MessageTypeConstants.whiteboard]
class CometChatCollaborativeWhiteBoardBubble extends StatelessWidget {
  const CometChatCollaborativeWhiteBoardBubble(
      {Key? key,
      this.title,
      this.subtitle,
      this.icon,
      this.messageObject,
      this.buttonText,
      this.style = const WhiteBoardBubbleStyle(),
      this.url})
      : super(key: key);

  ///[messageObject] custom message object
  final CustomMessage? messageObject;

  ///[title] title to be displayed default is 'Collaborative Whiteboard'
  final String? title;

  ///[subtitle] subtitle to be displayed default is 'Open whiteboard to draw together'
  final String? subtitle;

  ///[icon] document icon to be shown on bubble
  final Widget? icon;

  ///[buttonText] button text to be shown default is 'Open Whiteboard'
  final String? buttonText;

  ///[style] whiteboard bubble styling properties
  final WhiteBoardBubbleStyle style;

  ///[url] if message object is not passed then url should be passed to open webview
  final String? url;

  String? getWebViewUrl() {
    if (messageObject != null &&
        messageObject!.customData != null &&
        messageObject!.customData!.containsKey("whiteboard")) {
      Map? whiteboard = messageObject?.customData?["whiteboard"];
      if (whiteboard != null && whiteboard.containsKey("board_url")) {
        return whiteboard["board_url"];
      }
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    String? _url = getWebViewUrl();

    return Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 65 / 100),
      child: Column(
        children: [
          ListTile(
            title: Text(
              title ?? Translations.of(context).collaborative_whiteboard,
              style: style.titleStyle ??
                  const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xff141414)),
            ),
            subtitle: Text(
              subtitle ?? Translations.of(context).open_whiteboard_subtitle,
              style: style.subtitleStyle ??
                  TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xff141414).withOpacity(0.58)),
            ),
            trailing: icon ??
                Image.asset(
                  "assets/icons/collaborative_whiteboard.png",
                  package: UIConstants.packageName,
                  color: style.iconTint,
                ),
          ),
          const SizedBox(
            height: 9,
          ),
          Divider(
            height: 0,
            color: const Color(0xff141414).withOpacity(0.58),
          ),
          GestureDetector(
            onTap: () {
              if (_url != null) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CometChatCollaborativeWebView(
                              title: title ??
                                  Translations.of(context)
                                      .collaborative_whiteboard,
                              webviewUrl: _url,
                              appBarColor: style.webViewAppBarColor,
                              titleStyle: style.webViewTitleStyle,
                            )));
              }
            },
            child: SizedBox(
              height: 48,
              child: Center(
                child: Text(
                  buttonText ?? Translations.of(context).open_whiteboard,
                  style: style.buttonTextStyle ??
                      const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: Color(0xff3399FF)),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class WhiteBoardBubbleStyle {
  ///Style for WhiteBoard bubble
  const WhiteBoardBubbleStyle(
      {this.titleStyle,
      this.subtitleStyle,
      this.buttonTextStyle,
      this.webViewTitleStyle,
      this.webViewBackIconColor,
      this.webViewAppBarColor,
      this.iconTint});

  ///[titleStyle] title text style
  final TextStyle? titleStyle;

  ///[subtitleStyle] subtitle text style
  final TextStyle? subtitleStyle;

  ///[buttonTextStyle] buttonText text style
  final TextStyle? buttonTextStyle;

  ///[iconTint] default document bubble icon
  final Color? iconTint;

  ///[webViewTitleStyle] webview title style
  final TextStyle? webViewTitleStyle;

  ///[webViewBackIconColor] webview back icon color
  final Color? webViewBackIconColor;

  ///[webViewAppBarColor] webview app bar color
  final Color? webViewAppBarColor;
}
