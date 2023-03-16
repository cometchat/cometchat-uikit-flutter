import 'package:flutter/widgets.dart';

class CometChatBaseOptions {
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

  // ///[action] should not be used by developer
  // Function(String optionID, String elementID)? action;

  CometChatBaseOptions({
    required this.id,
    this.title,
    this.icon,
    this.packageName,
    this.titleStyle,
    this.backgroundColor,
    this.iconTint,
    //this.action
  });
}
