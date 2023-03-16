import 'package:flutter/material.dart';
import '../../flutter_chat_ui_kit.dart';

///Styling class for [CometChatGroupScope]
class GroupScopeStyle extends BaseStyles {
  ///[scopeTextStyle] text style for scope text shown,
  /// Works when there is no drop down
  final TextStyle? scopeTextStyle;

  ///[dropDownItemStyle] style for every drop down item
  final TextStyle? dropDownItemStyle;

  ///[selectedItemTextStyle] TextStyle for selected drop down value
  ///Works when there is  drop down
  final TextStyle? selectedItemTextStyle;

  const GroupScopeStyle({
    this.dropDownItemStyle,
    this.scopeTextStyle,
    this.selectedItemTextStyle,
    double? width,
    double? height,
    BoxBorder? border,
    double? borderRadius,
    Color? backgroundColor,
  }) : super(
          width: width,
          height: height,
          border: border,
          borderRadius: borderRadius,
        );
}
