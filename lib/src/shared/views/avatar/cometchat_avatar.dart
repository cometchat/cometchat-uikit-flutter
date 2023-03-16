import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

/// Creates a widget that that gives avatar UI.
class CometChatAvatar extends StatelessWidget {
  const CometChatAvatar({
    Key? key,
    this.image,
    this.name,
    this.style,
  }) : super(key: key);

  ///[image] sets the image url  for the avatar ,  will be preferred over name
  final String? image;

  ///[name] only visible when [image] tag is not passed
  final String? name;

  ///[style] contains properties that affects the appearance of this widget
  final AvatarStyle? style;
 
  @override
  Widget build(BuildContext context) {
    String _url = "";
    String _text = "AB";
    double _width = 40;
    double _height = 40;

    //Check if Text should be visible or image
    if (image != null && image!.isNotEmpty) {
      _url = image!;
    }
    if (name != null) {
      if (name!.length >= 2) {
        _text = name!.substring(0, 2).toUpperCase();
      } else {
        _text = name!.toUpperCase();
      }
    }

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        borderRadius:
            BorderRadius.all(Radius.circular(style?.outerBorderRadius ?? 100.0)),
        border: style?.outerViewBorder ??
            Border.all(
              color: style?.outerViewBackgroundColor ??
                  style?.background ??
                  const Color(0xff141414).withOpacity(0.71),
              width: style?.outerViewWidth ?? 0,
            ),
            gradient: style?.gradient,
        color: style?.gradient==null? style?.background ?? const Color(0xff141414).withOpacity(0.71):null,
      ),
      child: Padding(
        padding: EdgeInsets.all(style?.outerViewSpacing ?? 0),
        child: Container(
          height: style?.width ?? _width,
          width: style?.height ?? _height,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius:
                BorderRadius.all(Radius.circular(style?.borderRadius ?? 100.0)),
            border: style?.border,
          ),

          //--------on image url null or image url is not valid then show text--------
          child: _url.isNotEmpty
              ? Image.network(_url,
                  errorBuilder: (context, object, stackTrace) {
                  return Center(
                    child: Text(_text,
                        style: style?.nameTextStyle ??
                            const TextStyle(
                                fontSize: 17.0,
                                color: Color(0xffFFFFFF),
                                fontWeight: FontWeight.w500)),
                  );
                })
              : Center(
                  child: Text(_text,
                      style: style?.nameTextStyle ??
                          const TextStyle(
                              fontSize: 17.0,
                              color: Color(0xffFFFFFF),
                              fontWeight: FontWeight.w500)),
                ),
        ),
      ),
    );
  }
}
