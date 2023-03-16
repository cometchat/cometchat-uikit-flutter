import 'package:flutter/material.dart';

import '../../../flutter_chat_ui_kit.dart';

class CometChatDetailsOption extends CometChatBaseOptions {
  ///to pass custom view to options
  Widget? customView;

  /// to pass tail component for detail option
  Widget? tail;

  ///to pass height for details
  double? height;

  ///[onClick] call function which takes 3 parameter , and one of user or group is populated at a time
  Function(User? user, Group? group, String section,
      CometChatDetailsController state)? onClick;

  CometChatDetailsOption(
      {this.customView,
      this.onClick,
      this.tail,
      required String id,
      this.height,
      String? title,
      String? icon,
      String? packageName,
      TextStyle? titleStyle})
      : super(
            id: id,
            icon: icon,
            packageName: packageName,
            title: title,
            titleStyle: titleStyle);

  @override
  String toString() {
    return 'DetailOption{customView: $customView, tail: $tail, onClick: $onClick , id $id , title $title ';
  }
}
