import 'package:flutter/material.dart';

import '../../../../clean_architecture.dart';

/// Renders an **image message** (1..N image attachments) as a count-based media
/// grid, with the optional caption below. Part of the multi-attachment bubble
/// family (images / videos / audios / voice note / files) that replaces the
/// deprecated single-attachment media bubbles when `enableMultipleAttachments`
/// is on.
class CometChatImagesBubble extends StatelessWidget {
  const CometChatImagesBubble({
    super.key,
    required this.message,
    required this.alignment,
    this.formatters,
    this.maxWidth = 280,
    this.gridGap = 2,
    this.style,
  });

  /// The image message whose attachments are rendered.
  final MediaMessage message;

  /// Incoming / outgoing alignment (drives the caption colours).
  final BubbleAlignment alignment;

  /// Text formatters applied to the caption (markdown guaranteed by caller).
  final List<CometChatTextFormatter>? formatters;

  /// Upper bound on the grid width.
  final double maxWidth;

  /// Gap between grid cells.
  final double gridGap;

  ///[style] customizes the bubble — see [CometChatImagesBubbleStyle]. Merged
  ///over the [CometChatImagesBubbleStyle] theme extension when one is
  ///registered (widget values win).
  final CometChatImagesBubbleStyle? style;

  @override
  Widget build(BuildContext context) {
    final attachments = AttachmentUtils.attachmentsOf(message);
    final caption = message.caption;
    final hasCaption = caption != null && caption.trim().isNotEmpty;
    // A media message can reach us with its attachments missing while still
    // carrying a caption (the caption is parsed independently of the
    // attachments). Dropping the whole bubble there silently discarded the
    // user's text — render the caption on its own instead.
    if (attachments.isEmpty && !hasCaption) return const SizedBox.shrink();

    final resolved = CometChatThemeHelper.getTheme<CometChatImagesBubbleStyle>(
      context: context,
      defaultTheme: CometChatImagesBubbleStyle.of,
    ).merge(style);

    final screenW = MediaQuery.sizeOf(context).width;
    final bubbleWidth = (screenW * 0.72) < maxWidth
        ? (screenW * 0.72)
        : maxWidth;
    // 2dp inset on all sides between the bubble edge and the grid — same as
    // every other multi-attachment bubble (audios / files).
    const inset = kMultiAttachmentContentInset;
    final gridWidth = bubbleWidth - inset * 2;

    final children = <Widget>[
      if (attachments.isNotEmpty)
        Padding(
          padding: const EdgeInsets.all(inset),
          child: CometChatMediaGrid(
            style: CometChatMediaGridStyle(
              cellBorderRadius: resolved.tileBorderRadius,
              placeholderColor: resolved.placeholderColor,
              overflowScrimColor: resolved.overflowScrimColor,
              overflowTextStyle: resolved.overflowTextStyle,
            ),
            media: attachments,
            width: gridWidth,
            gap: resolved.gridSpacing ?? gridGap,
          ),
        ),
    ];

    if (hasCaption) {
      children.add(
        CometChatMediaCaption(
          caption: caption,
          alignment: alignment,
          formatters: formatters,
          textStyle: resolved.captionTextStyle,
        ),
      );
    }

    // Fixed bubble width so every bubble of a batch renders at the same width.
    return SizedBox(
      width: bubbleWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
