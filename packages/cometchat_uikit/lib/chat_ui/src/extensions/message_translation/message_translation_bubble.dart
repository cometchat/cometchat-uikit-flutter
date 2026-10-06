import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';

///[MessageTranslationBubble] shows a text message's content with its
///translation underneath: the original [child], a separator, the
///[translatedText] and a "Text Translated" label. The message list renders
///it for a text message once the Translate option has translated it.
///
/// ```dart
/// MessageTranslationBubble(
///   translatedText: "¡Hola mundo!",
///   alignment: BubbleAlignment.right,
///   style: CometChatMessageTranslationBubbleStyle(
///     translatedTextStyle: TextStyle(
///       fontSize: 16,
///       fontWeight: FontWeight.bold,
///       color: Colors.black,
///     ),
///   ),
/// );
///
/// ```
class MessageTranslationBubble extends StatelessWidget {
  const MessageTranslationBubble({
    super.key,
    this.translatedText = "",
    required this.alignment,
    this.child,
    this.style,
  });

  ///[translatedText] translated version of messageText
  final String translatedText;

  ///[alignment] of the bubble
  final BubbleAlignment alignment;

  ///[child] some child component
  final Widget? child;

  ///[style] styles this bubble
  final CometChatMessageTranslationBubbleStyle? style;

  @override
  Widget build(BuildContext context) {
    final style =
        CometChatThemeHelper.getTheme<CometChatMessageTranslationBubbleStyle>(
          defaultTheme: CometChatMessageTranslationBubbleStyle.of,
          context: context,
        ).merge(this.style);
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    final spacing = CometChatThemeHelper.getSpacing(context);
    final typography = CometChatThemeHelper.getTypography(context);

    // As wide as the text bubble may grow (75% of the screen), not a fixed
    // 232 — a translated message is the text bubble plus the translation
    // and must not squeeze the original. IntrinsicWidth sizes the column to
    // its widest line so the separator spans the whole bubble, whether the
    // original or the translation is the longer.
    final maxWidth = (MediaQuery.maybeSizeOf(context)?.width ?? 400) * 0.75;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (child != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color:
                          style.dividerColor ??
                          (alignment == BubbleAlignment.right
                              ? colorPalette.extendedPrimary800
                              : colorPalette.neutral400) ??
                          Colors.transparent,
                      width: 1,
                    ),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(bottom: spacing.padding2 ?? 0),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: 1,
                    child: child!,
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(
                left: spacing.padding2 ?? 0,
                right: spacing.padding2 ?? 0,
                top: spacing.padding2 ?? 0,
              ),
              child: Text(
                translatedText,
                style: TextStyle(
                  color: alignment == BubbleAlignment.right
                      ? colorPalette.white
                      : colorPalette.neutral900,
                  fontWeight: typography.body?.regular?.fontWeight,
                  fontSize: typography.body?.regular?.fontSize,
                  fontFamily: typography.body?.regular?.fontFamily,
                ).merge(style.translatedTextStyle),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.padding2 ?? 0,
                vertical: spacing.padding ?? 0,
              ),
              child: Text(
                Translations.of(context).textTranslated,
                style: TextStyle(
                  color: alignment == BubbleAlignment.right
                      ? colorPalette.white
                      : colorPalette.neutral900,
                  fontWeight: FontWeight.w400,
                  fontSize: typography.caption2?.regular?.fontSize,
                  fontFamily: typography.caption2?.regular?.fontFamily,
                ).merge(style.infoTextStyle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
