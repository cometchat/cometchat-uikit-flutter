import '../../../../../../cometchat_uikit_shared.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

///[CometChatWebView] is widget that renders a WebView
class CometChatWebView extends StatefulWidget {
  const CometChatWebView({
    super.key,
    required this.title,
    required this.webViewUrl,
    this.backIcon,
    this.appBarColor,
    this.webViewStyle,
  });

  ///[title] of the page
  final String title;

  ///WebView package use [webViewUrl] to render page
  final String webViewUrl;

  ///[backIcon] displays back  Icon
  final Icon? backIcon;

  ///[appBarColor] , default is Color(0xffFFFFFF)
  final Color? appBarColor;

  ///[webViewStyle] , web view styling properties
  final WebViewStyle? webViewStyle;

  @override
  State<CometChatWebView> createState() => _CometChatWebViewState();
}

class _CometChatWebViewState extends State<CometChatWebView> {
  @override
  Widget build(BuildContext context) {
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    return Scaffold(
      appBar: AppBar(
        // The style's appBarColor was declared and read nowhere — the
        // widget's own parameter shadowed it. It still wins, so this is
        // additive. ENG-39125.
        backgroundColor:
            widget.appBarColor ??
            widget.webViewStyle?.appBarColor ??
            colorPalette.background1 ??
            const Color(0xffFFFFFF),
        elevation: 0,
        toolbarHeight: 56,
        leading: IconButton(
          tooltip: Translations.of(context).close,
          onPressed: () {
            Navigator.pop(context);
          },
          icon:
              widget.backIcon ??
              Icon(
                Icons.close,
                size: 24,
                color:
                    widget.webViewStyle?.backIconColor ??
                    colorPalette.iconHighlight ??
                    const Color(0xff3399FF),
              ),
        ),
        title: Text(
          widget.title,
          style:
              widget.webViewStyle?.titleStyle ??
              TextStyle(
                color: colorPalette.textPrimary ?? const Color(0xFF141414),
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
      body: kIsWeb ? _buildWebFallback() : _buildNativeWebView(),
    );
  }

  /// On web platform, use HtmlElementView with iframe for inline display
  Widget _buildWebFallback() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.open_in_browser, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'WebView is not supported on web.',
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              launchUrl(
                Uri.parse(widget.webViewUrl),
                mode: LaunchMode.externalApplication,
              );
            },
            icon: const Icon(Icons.open_in_new),
            label: Text(Translations.of(context).openInBrowser),
          ),
        ],
      ),
    );
  }

  /// On native platforms, use the webview_flutter package
  Widget _buildNativeWebView() {
    return Stack(
      children: <Widget>[
        WebViewWidget(
          controller: WebViewController()
            ..loadRequest(Uri.parse(widget.webViewUrl))
            ..setJavaScriptMode(JavaScriptMode.unrestricted),
        ),
      ],
    );
  }
}
