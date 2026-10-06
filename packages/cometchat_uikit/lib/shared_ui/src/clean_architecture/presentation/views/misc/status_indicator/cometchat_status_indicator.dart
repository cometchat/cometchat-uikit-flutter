import 'package:flutter/material.dart';
import '../../../../../../cometchat_uikit_shared.dart';

///[CometChatStatusIndicator] is a widget that is used to indicate the online status of a [User]
/// ```dart
/// CometChatStatusIndicator(
///  style: CometChatStatusIndicatorStyle(
///  backgroundColor: Colors.green,
///  border: Border.all(color: Colors.white, width: 2),
///  ),
///  width: 12,
///  height: 12,
///  backgroundImage: Icon(
///  Icons.circle,
///  color: Colors.white,
///  size: 12,
///  ),
///  );
/// ```
class CometChatStatusIndicator extends StatelessWidget {
  const CometChatStatusIndicator({
    super.key,
    this.style,
    this.width,
    this.height,
    this.backgroundImage,
  });

  ///[style] contains properties that affects the appearance of this widget
  final CometChatStatusIndicatorStyle? style;

  ///[width] provides width to the widget
  final double? width;

  ///[height] provides height to the widget
  final double? height;

  ///[backgroundImage] icon for status indicator
  final Widget? backgroundImage;

  @override
  Widget build(BuildContext context) {
    final statusIndicatorStyle =
        CometChatThemeHelper.getTheme<CometChatStatusIndicatorStyle>(
          context: context,
          defaultTheme: CometChatStatusIndicatorStyle.of,
        ).merge(style);

    final spacing = CometChatThemeHelper.getSpacing(context);

    // An unlabelled coloured dot. It conveys presence visually but announces
    // nothing, so it is hidden rather than read out as an empty node.
    return ExcludeSemantics(
      child: Container(
        width: width ?? 12,
        height: height ?? 12,
        decoration: BoxDecoration(
          borderRadius:
              statusIndicatorStyle.borderRadius ??
              BorderRadius.circular(spacing.radiusMax ?? 0),
          border: statusIndicatorStyle.border,
          color: statusIndicatorStyle.backgroundColor,
        ),
        child: backgroundImage,
      ),
    );
  }
}
