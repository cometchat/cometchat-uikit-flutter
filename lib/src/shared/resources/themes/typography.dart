import 'package:flutter/material.dart';

///Base class for
class FontStyle {
  double fontSize;
  FontWeight? fontWeight;
  String? fontFamily;

  FontStyle({required this.fontSize, this.fontWeight, this.fontFamily});
}

class FontBasics {
  String? fontFamily;

  FontWeight fontWeightRegular;

  FontWeight fontWeightMedium;

  FontWeight fontWeightSemibold;

  FontWeight fontWeightBold;

  FontBasics(this.fontFamily, this.fontWeightRegular, this.fontWeightMedium,
      this.fontWeightSemibold, this.fontWeightBold);

  //Should used for development
  factory FontBasics.fromDefault(
      {String? fontFamily,
      FontWeight? fontWeightRegular,
      FontWeight? fontWeightMedium,
      FontWeight? fontWeightSemibold,
      FontWeight? fontWeightBold}) {
    return FontBasics(
        fontFamily,
        fontWeightRegular ?? FontWeight.w400,
        fontWeightMedium ?? FontWeight.w500,
        fontWeightSemibold ?? FontWeight.w600,
        fontWeightBold ?? FontWeight.w700);
  }
}

class Typography {
  FontBasics fontBasics;
  FontStyle heading;
  FontStyle name;
  FontStyle title1;
  FontStyle title2;
  FontStyle subtitle1;
  FontStyle subtitle2;
  FontStyle text1;
  FontStyle text2;
  FontStyle caption1;
  FontStyle body;
  late FontStyle caption2;

  Typography(
      {required this.fontBasics,
      required this.heading,
      required this.name,
      required this.title1,
      required this.title2,
      required this.subtitle1,
      required this.subtitle2,
      required this.text1,
      required this.text2,
      required this.caption1,
      required this.caption2,
      required this.body});

  ///Should be used to make custom themes
  factory Typography.fromDefault(
      {FontBasics? fontBasics,
      String? fontFamily,
      FontWeight? fontWeightRegular,
      FontWeight? fontWeightMedium,
      FontStyle? heading,
      FontStyle? name,
      FontStyle? title1,
      FontStyle? title2,
      FontStyle? subtitle1,
      FontStyle? subtitle2,
      FontStyle? text1,
      FontStyle? text2,
      FontStyle? caption1,
      FontStyle? caption2,
      FontStyle? body}) {
    FontBasics _fontBasics = fontBasics ?? FontBasics.fromDefault();

    //Setting Optional values to default font weght values if null
    heading?.fontWeight ??= _fontBasics.fontWeightBold;
    name?.fontWeight ??= _fontBasics.fontWeightMedium;
    title1?.fontWeight ??= _fontBasics.fontWeightSemibold;
    title2?.fontWeight ??= _fontBasics.fontWeightRegular;
    subtitle1?.fontWeight ??= _fontBasics.fontWeightRegular;
    subtitle2?.fontWeight ??= _fontBasics.fontWeightRegular;
    text1?.fontWeight ??= _fontBasics.fontWeightMedium;
    text2?.fontWeight ??= _fontBasics.fontWeightMedium;
    caption1?.fontWeight ??= _fontBasics.fontWeightMedium;
    caption2?.fontWeight ??= _fontBasics.fontWeightMedium;
    body?.fontWeight ??= _fontBasics.fontWeightRegular;

    //Setting Optional values to default font family values if null
    heading?.fontFamily ??= _fontBasics.fontFamily;
    name?.fontFamily ??= _fontBasics.fontFamily;
    title1?.fontFamily ??= _fontBasics.fontFamily;
    title2?.fontFamily ??= _fontBasics.fontFamily;
    subtitle1?.fontFamily ??= _fontBasics.fontFamily;
    subtitle2?.fontFamily ??= _fontBasics.fontFamily;
    text1?.fontFamily ??= _fontBasics.fontFamily;
    text2?.fontFamily ??= _fontBasics.fontFamily;
    caption1?.fontFamily ??= _fontBasics.fontFamily;
    caption2?.fontFamily ??= _fontBasics.fontFamily;
    body?.fontFamily ??= _fontBasics.fontFamily;

    return Typography(
      fontBasics: _fontBasics,
      heading: heading ??
          FontStyle(
              fontSize: 22,
              fontWeight: _fontBasics.fontWeightBold,
              fontFamily: _fontBasics.fontFamily),
      name: name ??
          FontStyle(
              fontSize: 17,
              fontWeight: _fontBasics.fontWeightMedium,
              fontFamily: _fontBasics.fontFamily),
      title1: title1 ??
          FontStyle(
              fontSize: 20,
              fontWeight: _fontBasics.fontWeightMedium,
              fontFamily: _fontBasics.fontFamily),
      title2: title2 ??
          FontStyle(
              fontSize: 16,
              fontWeight: _fontBasics.fontWeightRegular,
              fontFamily: _fontBasics.fontFamily),
      subtitle1: subtitle1 ??
          FontStyle(
              fontSize: 15,
              fontWeight: _fontBasics.fontWeightRegular,
              fontFamily: _fontBasics.fontFamily),
      subtitle2: subtitle2 ??
          FontStyle(
              fontSize: 13,
              fontWeight: _fontBasics.fontWeightRegular,
              fontFamily: _fontBasics.fontFamily),
      text1: text1 ??
          FontStyle(
              fontSize: 15,
              fontWeight: _fontBasics.fontWeightMedium,
              fontFamily: _fontBasics.fontFamily),
      text2: text2 ??
          FontStyle(
              fontSize: 13,
              fontWeight: _fontBasics.fontWeightMedium,
              fontFamily: _fontBasics.fontFamily),
      caption1: caption1 ??
          FontStyle(
              fontSize: 12,
              fontWeight: _fontBasics.fontWeightMedium,
              fontFamily: _fontBasics.fontFamily),
      caption2: caption2 ??
          FontStyle(
              fontSize: 11,
              fontWeight: _fontBasics.fontWeightMedium,
              fontFamily: _fontBasics.fontFamily),
      body: body ??
          FontStyle(
              fontSize: 17,
              fontWeight: _fontBasics.fontWeightRegular,
              fontFamily: _fontBasics.fontFamily),
    );
  }
}

///Default exposed typographytheme
Typography defaultTypographyTheme = Typography.fromDefault();
