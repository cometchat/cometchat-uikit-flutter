import 'package:flutter/material.dart';

import '../../../flutter_chat_ui_kit.dart';

class CometChatGroupMemberOption extends CometChatBaseOptions {
  ///[onClick] call function which takes 2 parameters
  Function(Group group, GroupMember member,
      CometChatGroupMembersController state)? onClick;

  CometChatGroupMemberOption(
      {this.onClick,
      required String id,
      String? title,
      String? icon,
      String? packageName,
      Color? backgroundColor,
      TextStyle? titleStyle})
      : super(
            id: id,
            icon: icon,
            packageName: packageName,
            title: title,
            titleStyle: titleStyle,
            backgroundColor: backgroundColor);
}
