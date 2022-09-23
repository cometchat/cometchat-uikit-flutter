import 'package:flutter/material.dart';

/// Creates a widget that that gives user presence  UI.
class CometChatStatusIndicator extends StatelessWidget {
  const CometChatStatusIndicator(
      {Key? key,
      this.width,
      this.height,
      this.cornerRadius,
      this.backgroundColor,
      this.icon,
      this.border})
      : super(key: key);

  ///[width] width of container
  final double? width;

  ///[height] of container
  final double? height;

  ///[cornerRadius] of container
  final double? cornerRadius;

  ///[backgroundColor] background color of status indicator
  final Color? backgroundColor;

  ///[icon] icon for status indicator
  final Widget? icon;

  ///[border] border
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? 14,
      height: height ?? 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(cornerRadius ?? 7.0)),
        border: border,
        color: backgroundColor,
      ),
      child: icon,
    );
  }
}
