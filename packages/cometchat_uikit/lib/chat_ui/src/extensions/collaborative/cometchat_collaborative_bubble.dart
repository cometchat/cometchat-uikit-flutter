import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[CometChatCollaborativeBubble] a widget that provides access to collaborative document
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
class CometChatCollaborativeBubble extends StatelessWidget {
  const CometChatCollaborativeBubble({
    super.key,
    required this.url,
    this.title,
    this.subtitle,
    this.icon,
    this.buttonText,
    this.style,
    this.alignment,
    this.previewImage,
  });

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
  final CometChatCollaborativeBubbleStyle? style;

  ///[theme] sets custom theme
  // final CometChatTheme? theme;

  ///[alignment] provides alignment to the link preview bubble
  final BubbleAlignment? alignment;

  ///[previewImage] provides preview image to the link preview bubble
  final String? previewImage;

  @override
  Widget build(BuildContext context) {
    final style =
        CometChatThemeHelper.getTheme<CometChatCollaborativeBubbleStyle>(
          context: context,
          defaultTheme: CometChatCollaborativeBubbleStyle.of,
        ).merge(this.style);

    final typography = CometChatThemeHelper.getTypography(context);
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final spacing = CometChatThemeHelper.getSpacing(context);

    return Container(
      constraints: const BoxConstraints(maxWidth: 246),
      decoration: BoxDecoration(
        color: style.backgroundColor ?? Colors.transparent,
        borderRadius: style.borderRadius,
        border: style.border,
      ),
      child: Column(
        children: [
          if (previewImage != null)
            Container(
              alignment: Alignment.topCenter,
              // constraints: const BoxConstraints(
              //     maxWidth: 232),
              child: Image.asset(
                previewImage!,
                package: UIConstants.packageName,
                fit: BoxFit.cover,
              ),
            ),
          Container(
            padding: EdgeInsets.only(
              top: spacing.padding2 ?? 0,
              bottom: spacing.padding2 ?? 0,
            ),
            decoration: BoxDecoration(
              color: style.backgroundColor ?? Colors.transparent,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    left: spacing.padding2 ?? 0,
                    right: spacing.padding2 ?? 0,
                  ),
                  child:
                      icon ??
                      Image.asset(
                        AssetConstants.whiteBoard,
                        package: UIConstants.packageName,
                        height: 24,
                        width: 24,
                        color:
                            style.iconTint ??
                            (alignment == BubbleAlignment.left
                                ? colorPalette.primary
                                : colorPalette.white),
                      ),
                ),
                // The bubble constrains its own width, so without a flex
                // factor this Column laid itself out at its natural size and
                // overflowed the Row by 130–174px — clipping the title
                // silently in release builds (ENG-38925). Expanded plus
                // ellipsis keeps long titles and localized strings inside the
                // bubble.
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title ?? "",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            style.titleStyle ??
                            TextStyle(
                              color: alignment == BubbleAlignment.left
                                  ? colorPalette.neutral900
                                  : colorPalette.white,
                              fontSize: typography.body?.medium?.fontSize,
                              fontWeight: typography.body?.medium?.fontWeight,
                              fontFamily: typography.body?.medium?.fontFamily,
                              letterSpacing: 0,
                            ),
                      ),
                      Text(
                        subtitle ?? "",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            style.subtitleStyle ??
                            TextStyle(
                              color: alignment == BubbleAlignment.left
                                  ? colorPalette.neutral600
                                  : colorPalette.white,
                              fontSize:
                                  typography.caption2?.regular?.fontSize ?? 10,
                              fontWeight:
                                  typography.caption2?.regular?.fontWeight,
                              fontFamily:
                                  typography.caption2?.regular?.fontFamily,
                              letterSpacing: 0,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 0,
            color:
                style.dividerColor ??
                (alignment == BubbleAlignment.left
                    ? colorPalette.borderDark
                    : colorPalette.extendedPrimary800),
          ),
          GestureDetector(
            onTap: () {
              if (url != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CometChatWebView(
                      title:
                          title ??
                          Translations.of(context).collaborativeDocument,
                      webViewUrl: url!,
                      appBarColor: style.webViewAppBarColor,
                      webViewStyle: WebViewStyle(
                        backIconColor: style.webViewBackIconColor,
                        titleStyle: style.webViewTitleStyle,
                      ),
                    ),
                  ),
                );
              }
            },
            child: SizedBox(
              height: 30,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  buttonText ?? "",
                  style:
                      style.buttonTextStyle ??
                      TextStyle(
                        color: alignment == BubbleAlignment.left
                            ? colorPalette.primary
                            : colorPalette.white,
                        fontSize: typography.body?.medium?.fontSize,
                        fontWeight: typography.body?.medium?.fontWeight,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
