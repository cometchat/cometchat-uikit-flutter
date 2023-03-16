import 'package:flutter/widgets.dart';

class CometChatOption {
  ///unique id foe any option
  String id;

  ///[title] passes title to option
  String? title;

  ///to pass icon url
  String? icon;

  ///to pass package name for the used icon
  String? packageName;

  ///[titleStyle] styling property for [title]
  TextStyle? titleStyle;

  Color? backgroundColor;

  Color? iconTint;

  Function()? onClick;

  CometChatOption(
      {required this.id,
      this.title,
      this.icon,
      this.packageName,
      this.titleStyle,
      this.backgroundColor,
      this.iconTint,
      this.onClick});
}
