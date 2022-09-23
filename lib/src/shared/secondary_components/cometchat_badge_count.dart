import 'package:flutter/material.dart';

class CometChatBadgeCount extends StatelessWidget {
  /// Creates a widget that that gives  date UI.
  const CometChatBadgeCount(
      {Key? key,
      required this.count,
      this.background,
      this.textStyle,
      this.cornerRadius,
      this.borderWidth,
      this.borderColor,
      this.height,
      this.width})
      : super(key: key);

  ///[count] shows the value inside badge if less then 0 then only size box will be displayed
  ///if [count] > 999 the 999+ will be displayed
  final int count;

  ///[background] gives background color to badge
  final Color? background;

  ///[textStyle] gives style to count
  final TextStyle? textStyle;

  ///[cornerRadius] of wrapping container
  final double? cornerRadius;

  ///[borderWidth] of wrapping container
  final double? borderWidth;

  ///[borderColor] of wrapping container
  final Color? borderColor;

  ///[height] of container
  final double? height;

  ///[width] of container
  final double? width;

  @override
  Widget build(BuildContext context) {
    Color _backGroundColor =
        background ?? const Color(0xff141414).withOpacity(0.71);

    return count > 0
        ? Container(
            height: height ?? 30,
            width: width ?? 30,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius:
                  BorderRadius.all(Radius.circular(cornerRadius ?? 4.0)),
              border: Border.all(
                color: borderColor ?? _backGroundColor,
                width: borderWidth ?? 5,
              ),
              color: background ?? _backGroundColor,
            ),
            child: Center(
              child: FittedBox(
                child: Text(
                  "${count <= 999 ? count : '999+'}",
                  style: textStyle ??
                      const TextStyle(
                        color: Color(0xffFFFFFF),
                        fontSize: 18.0,
                      ),
                ),
              ),
            ),
          )
        : const SizedBox();
  }
}
