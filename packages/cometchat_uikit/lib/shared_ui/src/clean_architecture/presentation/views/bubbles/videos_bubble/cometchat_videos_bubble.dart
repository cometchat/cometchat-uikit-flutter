import 'package:flutter/material.dart';

import '../../../../clean_architecture.dart';

/// Renders a **video message** (1..N video attachments) as a count-based media
/// grid — each cell shows the server poster frame when available (falling back
/// to a placeholder + play badge) — with the optional caption below. Part of
/// the multi-attachment bubble family that replaces the deprecated
/// single-attachment media bubbles when `enableMultipleAttachments` is on.
class CometChatVideosBubble extends StatelessWidget {
  const CometChatVideosBubble({
    super.key,
    required this.message,
    required this.alignment,
    this.formatters,
    this.maxWidth = 280,
    this.gridGap = 2,
    this.style,
  });

  /// The video message whose attachments are rendered.
  final MediaMessage message;

  /// Incoming / outgoing alignment (drives the caption colours).
  final BubbleAlignment alignment;

  /// Text formatters applied to the caption (markdown guaranteed by caller).
  final List<CometChatTextFormatter>? formatters;

  /// Upper bound on the grid width.
  final double maxWidth;

  /// Gap between grid cells.
  final double gridGap;

  ///[style] customizes the bubble — see [CometChatVideosBubbleStyle]. Merged
  ///over the [CometChatVideosBubbleStyle] theme extension when one is
  ///registered (widget values win).
  final CometChatVideosBubbleStyle? style;

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

    final resolved = CometChatThemeHelper.getTheme<CometChatVideosBubbleStyle>(
      context: context,
      defaultTheme: CometChatVideosBubbleStyle.of,
    ).merge(style);

    final screenW = MediaQuery.sizeOf(context).width;
    final bubbleWidth = (screenW * 0.72) < maxWidth
        ? (screenW * 0.72)
        : maxWidth;
    // 2dp inset on all sides between the bubble edge and the grid — same as
    // every other multi-attachment bubble (audios / files).
    const inset = kMultiAttachmentContentInset;
    final gridWidth = bubbleWidth - inset * 2;

    // Per-cell poster frames from the server thumbnail-generation extension.
    // Matched by the attachment's own URL/name when the extension echoes one
    // (so a reordered list can't mis-place a poster), else positional by index;
    // null falls back to the placeholder.
    final thumbs = <String?>[
      for (var i = 0; i < attachments.length; i++)
        ThumbnailExtractionUtil.thumbnailForAttachment(
          message.metadata,
          url: attachments[i].fileUrl,
          name: attachments[i].fileName,
          index: i,
        ),
    ];
    final children = <Widget>[
      if (attachments.isNotEmpty)
        Padding(
          padding: const EdgeInsets.all(inset),
          child: CometChatMediaGrid(
            style: CometChatMediaGridStyle(
              cellBorderRadius: resolved.tileBorderRadius,
              placeholderColor: resolved.placeholderColor,
              playBadgeBackgroundColor: resolved.playIconBackgroundColor,
              playBadgeIconColor: resolved.playIconColor,
              nameTextStyle: resolved.nameTextStyle,
              durationChipBackgroundColor: resolved.durationChipBackgroundColor,
              durationChipTextStyle: resolved.durationChipTextStyle,
              showVideoDuration: resolved.showVideoDuration,
              overflowScrimColor: resolved.overflowScrimColor,
              overflowTextStyle: resolved.overflowTextStyle,
            ),
            media: attachments,
            thumbs: thumbs,
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
