import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

/// Creates a widget that that gives user presence  UI.
class CometChatStatusIndicator extends StatelessWidget {
  const CometChatStatusIndicator(
      {Key? key, this.backgroundImage, this.backgroundColor, this.style})
      : super(key: key);

  ///[icon] icon for status indicator
  final Widget? backgroundImage;

  final Color? backgroundColor;

  ///[style] contains properties that affects the appearance of this widget
  final StatusIndicatorStyle? style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: style?.width ?? 14,
      height: style?.height ?? 14,
      decoration: BoxDecoration(
          borderRadius:
              BorderRadius.all(Radius.circular(style?.borderRadius ?? 7.0)),
          border: style?.border,
          color: backgroundColor,
          gradient: style?.gradient),
      child: backgroundImage,
    );
  }
}
