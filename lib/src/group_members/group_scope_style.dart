import 'package:flutter/material.dart';
import '../../cometchat_chat_uikit.dart';

///[GroupScopeStyle] is a data class that has styling-related properties
///to customize the appearance of [CometChatGroupScope]
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
    super.width,
    super.height,
    super.border,
    super.borderRadius,
    Color? backgroundColor,
  });
}
