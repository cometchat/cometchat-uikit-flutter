import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CometChatCollaborativeWhiteboardBubble] is a widget that is rendered as the content view for [CometChatCollaborativeWhiteboardExtension]
///
/// ```dart
/// CometChatCollaborativeWhiteboardBubble(
///      url: "https://example.com/collaborative-whiteboard",
///      title: "My Collaborative Whiteboard",
///      subtitle: "Edit with your team members",
///      icon: Icon(Icons.document),
///      buttonText: "Edit Now",
///      style: WhiteboardBubbleStyle(
///        background: Colors.grey,
///        iconTint: Colors.white,
///        dividerColor: Colors.black,
///        webViewAppBarColor: Colors.blueGrey,
///        webViewTitleStyle: TextStyle(
///          color: Colors.white,
///          fontWeight: FontWeight.bold,
///        ),
///        webViewBackIconColor: Colors.white,
///      ),
///      theme: CometChatTheme.light(),
///    );
/// ```
///
class CometChatCollaborativeWhiteBoardBubble extends StatelessWidget {
  const CometChatCollaborativeWhiteBoardBubble(
      {Key? key,
      required this.url,
      this.title,
      this.subtitle,
      this.icon,
      this.buttonText,
      this.style,
      this.theme})
      : super(key: key);

  ///[title] title to be displayed default is 'Collaborative Whiteboard'
  final String? title;

  ///[subtitle] subtitle to be displayed default is 'Open whiteboard to draw together'
  final String? subtitle;

  ///[icon] document icon to be shown on bubble
  final Widget? icon;

  ///[buttonText] button text to be shown default is 'Open Whiteboard'
  final String? buttonText;

  ///[style] whiteboard bubble styling properties
  final WhiteBoardBubbleStyle? style;

  ///[url] url should be passed to open webview
  final String? url;

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  @override
  Widget build(BuildContext context) {
    CometChatTheme _theme = theme ?? cometChatTheme;
    return Container(
      color: style?.background ?? Colors.transparent,
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 65 / 100),
      child: Column(
        children: [
          ListTile(
            title: Text(
              title ?? Translations.of(context).collaborative_whiteboard,
              style: style?.titleStyle ??
                  TextStyle(
                      color: _theme.palette.getAccent(),
                      fontSize: _theme.typography.text1.fontSize,
                      fontWeight: _theme.typography.text1.fontWeight),
            ),
            subtitle: Text(
              subtitle ?? Translations.of(context).open_whiteboard_subtitle,
              style: style?.subtitleStyle ??
                  TextStyle(
                      color: _theme.palette.getAccent600(),
                      fontSize: _theme.typography.subtitle2.fontSize,
                      fontWeight: _theme.typography.subtitle2.fontWeight),
            ),
            trailing: icon ??
                Image.asset(
                  AssetConstants.collaborativeWhiteboard,
                  package: UIConstants.packageName,
                  color: style?.iconTint ?? _theme.palette.getAccent700(),
                ),
            tileColor: style?.background ?? _theme.palette.getAccent50(),
          ),
          const SizedBox(
            height: 9,
          ),
          Divider(
            height: 0,
            color: style?.dividerColor ?? _theme.palette.getAccent500(),
          ),
          GestureDetector(
            onTap: () {
              if (url != null) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CometChatWebView(
                              title: title ??
                                  Translations.of(context)
                                      .collaborative_whiteboard,
                              webViewUrl: url!,
                              appBarColor: style?.webViewAppBarColor ??
                                  _theme.palette.getBackground(),
                              webViewStyle: WebViewStyle(
                               backIconColor: style?.webViewBackIconColor ??
                                   _theme.palette.getPrimary(),
                                titleStyle: style?.webViewTitleStyle??TextStyle(
                                    color: _theme.palette.getAccent(),
                                    fontSize: _theme.typography.heading.fontSize,
                                    fontWeight:
                                    _theme.typography.heading.fontWeight),
                              )
                            )));
              }
            },
            child: SizedBox(
              height: 30,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  buttonText ?? Translations.of(context).open_whiteboard,
                  style: style?.buttonTextStyle ??
                      TextStyle(
                          color: _theme.palette.getPrimary(),
                          fontSize: _theme.typography.name.fontSize,
                          fontWeight: _theme.typography.name.fontWeight),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
