import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CometChatCollaborativeDocumentBubble] a widget that provides access to collaborative document
///where users can work on common document
///
/// ```dart
///
/// CometChatCollaborativeDocumentBubble(
///      url: "https://example.com/collaborative-document",
///      title: "My Collaborative Document",
///      subtitle: "Edit with your team members",
///      icon: Icon(Icons.document),
///      buttonText: "Edit Now",
///      style: DocumentBubbleStyle(
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
///
/// ```
class CometChatCollaborativeDocumentBubble extends StatelessWidget {
  const CometChatCollaborativeDocumentBubble(
      {Key? key,
      required this.url,
      this.title,
      this.subtitle,
      this.icon,
      this.buttonText,
      this.style,
      this.theme})
      : super(key: key);

  ///[url] url should be passed to open web view
  final String? url;

  ///[title] title to be displayed , default is 'Collaborative Document'
  final String? title;

  ///[subtitle] subtitle to be displayed , default is 'Open document to edit content together'
  final String? subtitle;

  ///[icon] document icon to be shown on bubble
  final Widget? icon;

  ///[buttonText] button text to be shown , default is 'Open Document'
  final String? buttonText;

  ///[style] document bubble styling properties
  final DocumentBubbleStyle? style;

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
              title ?? Translations.of(context).collaborative_document,
              style: style?.titleStyle ??
                  TextStyle(
                      color: _theme.palette.getAccent(),
                      fontSize: _theme.typography.text1.fontSize,
                      fontWeight: _theme.typography.text1.fontWeight),
            ),
            subtitle: Text(
              subtitle ?? Translations.of(context).open_document_subtitle,
              style: style?.subtitleStyle ??
                  TextStyle(
                      color: _theme.palette.getAccent600(),
                      fontSize: _theme.typography.subtitle2.fontSize,
                      fontWeight: _theme.typography.subtitle2.fontWeight),
            ),
            trailing: icon ??
                Image.asset(
                  AssetConstants.collaborativeDocument,
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
                                      .collaborative_document,
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
                  buttonText ?? Translations.of(context).open_document,
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
