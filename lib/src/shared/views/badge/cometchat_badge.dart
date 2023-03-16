import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class CometChatBadge extends StatelessWidget {
  /// Creates a widget that that gives  date UI.
  const CometChatBadge(
      {Key? key, required this.count, this.style = const BadgeStyle()})
      : super(key: key);

  ///[count] shows the value inside badge if less then 0 then only size box will be displayed
  ///if [count] > 999 the 999+ will be displayed
  final int count;

  ///[style] contains properties that affects the appearance of this widget
  final BadgeStyle style;

  @override
  Widget build(BuildContext context) {
    Color _backGroundColor =
        style.background ?? const Color(0xff141414).withOpacity(0.71);

    return count > 0
        ? Container(
            height: style.height ?? 30,
            width: style.width ?? 30,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius:
                  BorderRadius.all(Radius.circular(style.borderRadius ?? 4.0)),
              border: style.border ??
                  Border.all(
                    color: _backGroundColor,
                    width: 5,
                  ),
              gradient: style.gradient,
              color: style.gradient == null
                  ? style.background ?? _backGroundColor
                  : null,
            ),
            child: Center(
              child: FittedBox(
                child: Text(
                  "${count <= 999 ? count : '999+'}",
                  style: style.textStyle ??
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
