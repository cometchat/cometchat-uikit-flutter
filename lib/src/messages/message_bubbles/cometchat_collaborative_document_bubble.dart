import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/src/messages/message_bubbles/cometchat_collaborative_webview.dart';

import '../../../flutter_chat_ui_kit.dart';

///creates a widget that gives collaborative document bubble
///
///used by default  when [messageObject.category]=[MessageTypes.custom] and [messageObject.type]=[MessageTypeConstants.document]
class CometChatCollaborativeDocumentBubble extends StatelessWidget {
  const CometChatCollaborativeDocumentBubble(
      {Key? key,
      this.title,
      this.subtitle,
      this.icon,
      this.messageObject,
      this.buttonText,
      this.style = const DocumentBubbleStyle(),
      this.url})
      : super(key: key);

  ///[messageObject] custom message object
  final CustomMessage? messageObject;

  ///[title] title to be displayed , default is 'Collaborative Document'
  final String? title;

  ///[subtitle] subtitle to be displayed , default is 'Open document to edit content together'
  final String? subtitle;

  ///[icon] document icon to be shown on bubble
  final Widget? icon;

  ///[buttonText] button text to be shown , default is 'Open Document'
  final String? buttonText;

  ///[style] document bubble stying properties
  final DocumentBubbleStyle style;

  ///[url] if message object is not passed then url should be passed to open web view
  final String? url;

  String? getWebViewUrl() {
    if (messageObject != null &&
        messageObject!.customData != null &&
        messageObject!.customData!.containsKey("document")) {
      Map? document = messageObject?.customData?["document"];
      if (document != null && document.containsKey("document_url")) {
        return document["document_url"];
      }
    } else {
      return url;
    }
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
              title ?? Translations.of(context).collaborative_document,
              style: style.titleStyle ??
                  const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xff141414)),
            ),
            subtitle: Text(
              subtitle ?? Translations.of(context).open_document_subtitle,
              style: style.subtitleStyle ??
                  TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xff141414).withOpacity(0.58)),
            ),
            trailing: icon ??
                Image.asset(
                  "assets/icons/collaborative_document.png",
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
                                      .collaborative_document,
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
                  buttonText ?? Translations.of(context).open_document,
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

class DocumentBubbleStyle {
  ///Style Component for DocumentBubble
  const DocumentBubbleStyle(
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
