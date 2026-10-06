import 'package:flutter/material.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import '../../../../core/constants/enums.dart';
import '../../../../core/utils/thumbnail_extraction_util.dart';
import '../../../theme/colors/cometchat_color_palette.dart';
import '../../../theme/typography/cometchat_typography.dart';
import '../../../theme/spacing/cometchat_spacing.dart';
import '../video_bubble/cometchat_video_bubble.dart';
import '../video_bubble/cometchat_video_bubble_style.dart';
import 'bubble_factory.dart';

/// Factory for creating video message bubbles.
class VideoBubbleFactory extends BubbleFactory<MediaMessage> {
  // Deprecated in 6.2.0: no effect, removed in 7.0.0.

  /// Placeholder image for the video.
  @Deprecated(
    'Has no effect. For the colour shown while a thumbnail loads, use CometChatVideosBubbleStyle.placeholderColor. Will be removed in 7.0.0.',
  )
  final String? placeHolderImage;

  /// Package of the placeholder image.
  @Deprecated(
    'Has no effect. For the colour shown while a thumbnail loads, use CometChatVideosBubbleStyle.placeholderColor. Will be removed in 7.0.0.',
  )
  final String? placeHolderImagePackageName;

  final CometChatVideoBubbleStyle? style;
  final Icon? playIcon;
  final Function()? onClick;

  VideoBubbleFactory({
    this.style,
    this.playIcon,
    this.onClick,
    this.placeHolderImage,
    this.placeHolderImagePackageName,
  });

  @override
  Widget build(
    BuildContext context,
    MediaMessage message,
    BubbleAlignment alignment, {
    CometChatColorPalette? colorPalette,
    CometChatTypography? typography,
    CometChatSpacing? spacing,
  }) {
    final thumbnailUrl = ThumbnailExtractionUtil.extractFromMetadata(
      message.metadata,
    );

    return CometChatVideoBubble(
      videoUrl: message.attachment?.fileUrl,
      thumbnailUrl: thumbnailUrl,
      style: style,
      playIcon: playIcon,
      onClick: onClick,
      metadata: message.metadata,
    );
  }
}
