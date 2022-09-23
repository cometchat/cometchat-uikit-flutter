import 'package:flutter/material.dart';

/// Creates a widget that that gives avatar UI.
class CometChatAvatar extends StatelessWidget {
  const CometChatAvatar({
    Key? key,
    this.image,
    this.width,
    this.height,
    this.border,
    this.cornerRadius,
    this.backgroundColor,
    this.outerViewWidth,
    this.outerViewBackgroundColor,
    this.outerViewSpacing,
    this.name,
    this.nameTextStyle,
    this.outerCornerRadius,
    this.outerViewBorder,
    //this.nameTextColor
  }) : super(key: key);

  ///[image] sets the image url  for the avatar ,  will be preferred over name
  final String? image;

  ///[width] Width of Avatar
  final double? width;

  ///[height] height of inner container
  final double? height;

  ///[border] style of inner border
  final BoxBorder? border;

  ///[backgroundColor] background color of widget
  final Color? backgroundColor;

  ///[cornerRadius] of inner container
  final double? cornerRadius;

  ///[outerCornerRadius] of outer container
  final double? outerCornerRadius;

  ///[outerViewBorder] style the outer Container border
  final BoxBorder? outerViewBorder;

  ///[outerViewWidth] outer view With
  final double? outerViewWidth;

  ///[outerViewBackgroundColor] outer Container background Color
  final Color? outerViewBackgroundColor;

  ///[outerViewSpacing] Spacing between the image and the outer border
  final double? outerViewSpacing;

  ///[name] only visible when [image] tag is not passed
  final String? name;

  ///[nameTextStyle] font style if visible
  final TextStyle? nameTextStyle;

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
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        borderRadius:
            BorderRadius.all(Radius.circular(outerCornerRadius ?? 100.0)),
        border: outerViewBorder ??
            Border.all(
              color: outerViewBackgroundColor ??
                  backgroundColor ??
                  const Color(0xff141414).withOpacity(0.71),
              width: outerViewWidth ?? 0,
            ),
        color: backgroundColor ?? const Color(0xff141414).withOpacity(0.71),
      ),
      child: Padding(
        padding: EdgeInsets.all(outerViewSpacing ?? 0),
        child: Container(
          height: width ?? _width,
          width: height ?? _height,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius:
                BorderRadius.all(Radius.circular(cornerRadius ?? 100.0)),
            border: border,
          ),

          //--------on image url null or image url is not valid then show text--------
          child: _url.isNotEmpty
              ? Image.network(_url,
                  errorBuilder: (context, object, stackTrace) {
                  return Center(
                    child: Text(_text,
                        style: nameTextStyle ??
                            const TextStyle(
                                fontSize: 17.0,
                                color: Color(0xffFFFFFF),
                                fontWeight: FontWeight.w500)),
                  );
                })
              : Center(
                  child: Text(_text,
                      style: nameTextStyle ??
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
