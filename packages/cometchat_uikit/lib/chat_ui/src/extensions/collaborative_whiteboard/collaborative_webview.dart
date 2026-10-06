import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

///[CometChatCollaborativeWebView] is a full-screen page that renders a
///collaborative document or whiteboard URL in a WebView, under an app bar
///with a title and a close button.
class CometChatCollaborativeWebView extends StatefulWidget {
  /// Creates a [CometChatCollaborativeWebView].
  const CometChatCollaborativeWebView({
    super.key,
    required this.title,
    required this.webviewUrl,
    this.titleStyle,
    this.backIcon,
    this.appBarColor,
    this.backIconColor,
  });

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
          icon:
              widget.backIcon ??
              Icon(
                Icons.close,
                size: 24,
                color: widget.backIconColor ?? const Color(0xff3399FF),
              ),
        ),
        title: Text(
          widget.title,
          style:
              widget.titleStyle ??
              const TextStyle(
                color: Color(0xff141414),
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
      body: _CollaborativeWebViewBody(url: widget.webviewUrl),
    );
  }
}

/// Owns the [WebViewController], so the page loads once rather than on
/// every rebuild of the app bar above it.
class _CollaborativeWebViewBody extends StatefulWidget {
  const _CollaborativeWebViewBody({required this.url});

  final String url;

  @override
  State<_CollaborativeWebViewBody> createState() =>
      _CollaborativeWebViewBodyState();
}

class _CollaborativeWebViewBodyState extends State<_CollaborativeWebViewBody> {
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..loadRequest(Uri.parse(widget.url));

  @override
  void didUpdateWidget(_CollaborativeWebViewBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
