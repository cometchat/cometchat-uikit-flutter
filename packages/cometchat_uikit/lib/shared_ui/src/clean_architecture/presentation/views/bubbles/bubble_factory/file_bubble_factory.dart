import 'package:flutter/material.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import '../../../../core/constants/enums.dart';
import '../../../theme/colors/cometchat_color_palette.dart';
import '../../../theme/typography/cometchat_typography.dart';
import '../../../theme/spacing/cometchat_spacing.dart';
import '../file_bubble/cometchat_file_bubble.dart';
import '../file_bubble/cometchat_file_bubble_style.dart';
import 'bubble_factory.dart';

/// Factory for creating file message bubbles.
class FileBubbleFactory extends BubbleFactory<MediaMessage> {
  /// Icon for the bubble's download button; see
  /// [CometChatFileBubble.downloadIcon].
  final Icon? downloadIcon;

  final CometChatFileBubbleStyle? style;

  FileBubbleFactory({this.style, this.downloadIcon});

  @override
  Widget build(
    BuildContext context,
    MediaMessage message,
    BubbleAlignment alignment, {
    CometChatColorPalette? colorPalette,
    CometChatTypography? typography,
    CometChatSpacing? spacing,
  }) {
    return CometChatFileBubble(
      fileUrl: message.attachment?.fileUrl,
      title: message.attachment?.fileName,
      fileMimeType: message.attachment?.fileMimeType,
      fileExtension: message.attachment?.fileExtension,
      fileSize: message.attachment?.fileSize,
      style: style,
      alignment: alignment,
      id: message.id,
      dateTime: message.sentAt,
      metadata: message.metadata,
      downloadIcon: downloadIcon,
    );
  }
}
