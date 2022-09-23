import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

enum OptionFor { sender, receiver, both }

///Model class for message options
///
///```dart
/// CometChatMessageOptions(
///  id: '',
///  title: 'Share',
///  iconUrl: 'assets url',
///  optionFor: OptionFor.sender,
///  overrideDefaultAction: false,
///  onClick: (BaseMessage baseMessage,
///      CometChatMessageListState state) {}
///  )
/// ```

class CometChatMessageOptions {
  const CometChatMessageOptions(
      {required this.id,
      required this.title,
      this.iconUrl,
      this.onClick,
      this.overrideDefaultAction = false,
      this.optionFor = OptionFor.both,
      this.packageName,
      this.iconTint});

  final String id;
  final String title;
  final String? iconUrl;
  final String? packageName;
  final bool overrideDefaultAction;
  final OptionFor optionFor;
  final Color? iconTint;
  final Function(BaseMessage message, CometChatMessageListState state)?
      onClick; //Change to onItemClick

  ActionItem toActionItem() {
    return ActionItem(
        id: id,
        title: title,
        iconUrl: iconUrl,
        onItemClick: onClick,
        iconUrlPackageName: packageName,
        iconTint: iconTint);
  }

  ActionItem toActionItemfromFunction(Function? passedFunction, Color iconTint,
      TextStyle titleStyle, String? packageName) {
    return ActionItem(
        id: id,
        title: title,
        iconUrl: iconUrl,
        onItemClick: passedFunction,
        iconTint: iconTint,
        titleStyle: titleStyle,
        iconUrlPackageName: packageName);
  }
}
