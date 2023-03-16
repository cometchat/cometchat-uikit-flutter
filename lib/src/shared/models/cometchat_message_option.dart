import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

enum OptionFor { sender, receiver, both }

///Model class for message options
///
///```dart
/// CometChatMessageOption(
///  id: '',
///  title: 'Share',
///  iconUrl: 'assets url',
///  optionFor: OptionFor.sender,
///  overrideDefaultAction: false,
///  onClick: (BaseMessage baseMessage,
///      CometChatMessageListState state) {}
///  )
/// ```

class CometChatMessageOption {
  CometChatMessageOption(
      {required this.id,
      required this.title,
      this.icon,
      this.onClick,
      this.packageName,
      this.iconTint,
      this.titleStyle});

  String id;
  String title;
  String? icon;
  String? packageName;
  Color? iconTint;
  TextStyle? titleStyle;
  Color? backgroundColor;
  Function(BaseMessage message, CometChatMessageListController state)?
      onClick; //Change to onItemClick

  ActionItem toActionItem() {
    return ActionItem(
        id: id,
        title: title,
        iconUrl: icon,
        onItemClick: onClick,
        iconUrlPackageName: packageName,
        iconTint: iconTint,
        background: backgroundColor,
        titleStyle: titleStyle);
  }

  ActionItem toActionItemFromFunction(
    Function(BaseMessage message, CometChatMessageListController state)?
        passedFunction,
  ) {
    return ActionItem(
        id: id,
        title: title,
        iconUrl: icon,
        onItemClick: passedFunction,
        iconTint: iconTint,
        titleStyle: titleStyle,
        iconUrlPackageName: packageName,
        background: backgroundColor);
  }
}
