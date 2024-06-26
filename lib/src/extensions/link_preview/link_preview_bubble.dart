import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[LinkPreviewBubble] is a widget that is rendered as the content view for [LinkPreviewExtension]
/// ```dart
/// LinkPreviewBubble(
///   onTapUrl: (url) async {
///     // Open the URL in a browser when it is tapped
///     await launch(url);
///   },
///   links: [    // The links contained in the website metadata    {      'url': 'https://www.example.com',      'title': 'Example Website',      'description': 'A sample website to demonstrate link previews',      'image': 'https://www.example.com/image.png',    }  ],
///   child: Text('Link Preview'),
///   defaultImage: Image.asset('assets/images/default.png'),
///   style: LinkPreviewBubbleStyle(
///     backgroundColor: Colors.white,
///     titleStyle: TextStyle(
///       fontSize: 16,
///       fontWeight: FontWeight.bold,
///     ),
///   ),
/// );
///
/// ```
class LinkPreviewBubble extends StatelessWidget {
  const LinkPreviewBubble(
      {super.key,
      this.theme,
      required this.onTapUrl,
      required this.links,
      this.child,
      this.defaultImage,
      this.style});

  ///[theme] sets custom theme
  final CometChatTheme? theme;

  ///[onTapUrl] opens the link in a browser
  final Future<void> Function(String url) onTapUrl;

  ///[links] returns links contained in the website metadata
  final List<dynamic> links;

  ///[child] some child component
  final Widget? child;

  ///[style] provides style to the link preview bubble
  final LinkPreviewBubbleStyle? style;

  ///[defaultImage] is shown unable to generate image from link
  final Widget? defaultImage;

  @override
  Widget build(BuildContext context) {
    CometChatTheme theme = this.theme ?? cometChatTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (links.isNotEmpty &&
            (links[0]["image"] != null ||
                (links[0]["url"] != null ||
                    links[0]["title"] != null ||
                    links[0]["favicon"] != null)))
          GestureDetector(
            onTap: () async {
              if (links.isNotEmpty && links[0]["url"] != null) {
                await onTapUrl(links[0]['url']);
              }
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                  color: style?.backgroundColor ?? theme.palette.getAccent50(),
                  borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8))),
              child: Column(
                children: [
                  if (links.isNotEmpty &&
                      links[0]["image"] != null &&
                      links[0]["image"].toString().isNotEmpty)
                    Center(
                      child: Image.network(links[0]["image"],
                          height: 108,
                          width: MediaQuery.of(context).size.width * 65 / 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, object, stack) {
                        return defaultImage ??
                            const SizedBox(
                              height: 0,
                              width: 0,
                            );
                      }),
                    ),
                  if (links.isNotEmpty &&
                      (links[0]["title"] != null ||
                          links[0]["url"] != null ||
                          links[0]["favicon"] != null))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(0),
                        minVerticalPadding: 0.0,
                        minLeadingWidth: 0,
                        tileColor: style?.tileColor,
                        title: (links.isNotEmpty && links[0]["title"] != null)
                            ? Text(
                                links[0]["title"],
                                style: TextStyle(
                                        fontSize:
                                            theme.typography.text1.fontSize,
                                        fontWeight:
                                            theme.typography.text1.fontWeight,
                                        color: theme.palette.getAccent())
                                    .merge(style?.titleStyle),
                              )
                            : null,
                        subtitle: (links.isNotEmpty && links[0]["url"] != null)
                            ? Text(
                                links[0]["url"],
                                style: TextStyle(
                                        fontSize:
                                            theme.typography.subtitle2.fontSize,
                                        fontWeight: theme
                                            .typography.subtitle2.fontWeight,
                                        color: theme.palette.getAccent())
                                    .merge(style?.urlStyle),
                              )
                            : null,
                        trailing: (links.isNotEmpty &&
                                links[0]["favicon"] != null &&
                                links[0]["favicon"].toString().isNotEmpty)
                            ? Image.network(links[0]["favicon"],
                                height: 36, width: 36,
                                errorBuilder: (context, object, stack) {
                                return defaultImage ??
                                    const SizedBox(
                                      height: 0,
                                      width: 0,
                                    );
                              })
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),

        //-----child widget-----
        if (child != null) child!
      ],
    );
  }
}
