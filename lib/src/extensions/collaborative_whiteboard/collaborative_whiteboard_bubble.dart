import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

///creates a widget that gives collaborative whiteboard bubble
///
///used by default  when [messageObject.category]=[MessageTypes.custom] and [messageObject.type]=[MessageTypeConstants.whiteboard]
class CometChatCollaborativeWhiteBoardBubble extends StatelessWidget {
  const CometChatCollaborativeWhiteBoardBubble(
      {Key? key,
      required this.url,
      this.title,
      this.subtitle,
      this.icon,
      this.buttonText,
      this.style,
      this.theme
     })
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
      color: style?.background ?? _theme.palette.getAccent50(),
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
                        builder: (context) => CometChatCollaborativeWebView(
                              title: title ??
                                  Translations.of(context)
                                      .collaborative_whiteboard,
                              webviewUrl: url!,
                              appBarColor: style?.webViewAppBarColor ??  _theme.palette.getBackground(),
                              backIconColor: style?.webViewBackIconColor ?? _theme.palette.getPrimary(),
                              titleStyle: style?.webViewTitleStyle ?? TextStyle(
              color: _theme.palette.getAccent(),
              fontSize: 20,
              fontWeight: _theme.typography.heading.fontWeight),
                            )));
              }
            },
            child: SizedBox(
              height: 48,
              child: Center(
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
