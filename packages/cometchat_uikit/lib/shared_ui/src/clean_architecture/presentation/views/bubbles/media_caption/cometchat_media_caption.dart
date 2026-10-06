import 'package:flutter/material.dart';

import '../../../../clean_architecture.dart';

/// Renders a media message's caption so it reads **exactly like a normal text
/// message** — body typography, outgoing/incoming colour, and the same
/// [FormatterUtils] pipeline (markdown, mentions, links, …).
///
/// Shared by the multi-attachment bubbles (images / videos / audios / files)
/// and the single-attachment content views, so a caption renders identically
/// whether a message carries one attachment or many.
class CometChatMediaCaption extends StatelessWidget {
  const CometChatMediaCaption({
    super.key,
    required this.caption,
    required this.alignment,
    this.formatters,
    this.padding = const EdgeInsets.fromLTRB(10, 6, 10, 8),
    this.showDivider = false,
    this.textStyle,
  });

  /// The caption text (may contain markdown / mention / link markers).
  final String caption;

  /// Incoming / outgoing alignment — drives the text colour.
  final BubbleAlignment alignment;

  /// Text formatters; markdown is guaranteed by the caller via
  /// [FormatterUtils.ensureMarkdownFormatter].
  final List<CometChatTextFormatter>? formatters;

  /// Padding around the caption block.
  final EdgeInsets padding;

  /// Whether to draw the hairline separator above the caption (used under media).
  final bool showDivider;

  /// Optional overrides merged over the default caption text style (colour,
  /// size, weight …) — threaded from each bubble's `captionTextStyle`.
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final colors = CometChatThemeHelper.getColorPalette(context);
    final typography = CometChatThemeHelper.getTypography(context);
    // Matches CometChatTextBubble's text style.
    final captionStyle = TextStyle(
      color: alignment == BubbleAlignment.right
          ? colors.white
          : colors.neutral900,
      fontSize: typography.body?.regular?.fontSize,
      fontWeight: typography.body?.regular?.fontWeight,
      fontFamily: typography.body?.regular?.fontFamily,
    ).merge(textStyle);
    // Thin, translucent separator that reads on both the coloured (outgoing) and
    // neutral (incoming) bubble backgrounds.
    final dividerColor = alignment == BubbleAlignment.right
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.08);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDivider) Container(height: 0.33, color: dividerColor),
          if (showDivider) const SizedBox(height: 3),
          RichText(
            textAlign: TextAlign.left,
            text: TextSpan(
              style: captionStyle,
              // Pass the caption style down as well: the spans set their own
              // style, which would otherwise override this parent's.
              children: FormatterUtils.buildTextSpan(
                caption,
                formatters,
                context,
                alignment,
                textStyle: captionStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
