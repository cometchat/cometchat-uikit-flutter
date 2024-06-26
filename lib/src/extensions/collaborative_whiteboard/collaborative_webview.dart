import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

///[CometChatCollaborativeWebView] is widget that renders a WebView
class CometChatCollaborativeWebView extends StatefulWidget {
  const CometChatCollaborativeWebView(
      {super.key,
      required this.title,
      required this.webviewUrl,
      this.titleStyle,
      this.backIcon,
      this.appBarColor,
      this.backIconColor});

  ///[title] of the page
  final String title;

  ///[titleStyle]  text style
  final TextStyle? titleStyle;

  ///WebView package use [webviewUrl] to render page
  final String webviewUrl;

  ///[backIcon] displays back  Icon
  final Icon? backIcon;

  ///[appBarColor] , default is Color(0xffFFFFFF)
  final Color? appBarColor;

  ///[backIconColor] , default is Color(0xff3399FF)
  final Color? backIconColor;

  @override
  State<CometChatCollaborativeWebView> createState() =>
      _CometChatCollaborativeWebViewState();
}

class _CometChatCollaborativeWebViewState
    extends State<CometChatCollaborativeWebView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.appBarColor ?? const Color(0xffFFFFFF),
        elevation: 0,
        toolbarHeight: 56,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: widget.backIcon ??
              Icon(
                Icons.close,
                size: 24,
                color: widget.backIconColor ?? const Color(0xff3399FF),
              ),
        ),
        title: Text(
          widget.title,
          style: widget.titleStyle ??
              const TextStyle(
                  color: Color(0xff141414),
                  fontSize: 20,
                  fontWeight: FontWeight.w500),
        ),
      ),
      body: WebViewWidget(
          controller: WebViewController()
            ..loadRequest(Uri.parse(widget.webviewUrl))
            ..setJavaScriptMode(JavaScriptMode.unrestricted)),
    );
  }
}
