import 'package:flutter/material.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart' hide CardMessage;
import '../../../../core/constants/enums.dart';
import '../../../theme/colors/cometchat_color_palette.dart';
import '../../../theme/typography/cometchat_typography.dart';
import '../../../theme/spacing/cometchat_spacing.dart';
import '../../../theme/theme/cometchat_theme_helper.dart';
import '../../../../../../l10n/translations.dart';
import 'bubble_factory.dart';

/// Factory for creating deleted message bubbles.
class DeletedBubbleFactory extends BubbleFactory<BaseMessage> {
  final TextStyle? textStyle;
  final Color? iconColor;

  DeletedBubbleFactory({this.textStyle, this.iconColor});

  @override
  Widget build(
    BuildContext context,
    BaseMessage message,
    BubbleAlignment alignment, {
    CometChatColorPalette? colorPalette,
    CometChatTypography? typography,
    CometChatSpacing? spacing,
  }) {
    final palette =
        colorPalette ?? CometChatThemeHelper.getColorPalette(context);
    final typo = typography ?? CometChatThemeHelper.getTypography(context);
    final space = spacing ?? CometChatThemeHelper.getSpacing(context);

    final isOutgoing = alignment == BubbleAlignment.right;
    final textColor = isOutgoing ? palette.white : palette.neutral600;

    return Padding(
      padding: EdgeInsets.all(space.padding2 ?? 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 16, color: iconColor ?? textColor),
          SizedBox(width: space.padding1 ?? 4),
          // Flexible so the label shrinks rather than overflowing the row.
          // CometChatDeletedBubble had the same layout and 6.2.0 fixed it
          // under A11Y3; this factory is the second copy the fix missed, and
          // it is the path the message list actually renders through. Bites on
          // a longer localized string or a large system text size.
          Flexible(
            child: Text(
              Translations.of(context).thisMessageDeleted,
              style:
                  textStyle ??
                  TextStyle(
                    color: textColor,
                    fontSize: typo.body?.regular?.fontSize,
                    fontWeight: typo.body?.regular?.fontWeight,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
