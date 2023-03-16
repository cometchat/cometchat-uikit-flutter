import 'package:flutter/material.dart';

import '../../../flutter_chat_ui_kit.dart';

class StatusIndicatorUtils {
  StatusIndicatorUtils({this.icon, this.statusIndicatorColor});

  static StatusIndicatorUtils getStatusIndicatorFromParams(
      {bool? isSelected,
      required CometChatTheme theme,
      User? user,
      Group? group,
      GroupMember? groupMember,
      Widget? protectedGroupIcon,
      Widget? privateGroupIcon,
      Color? onlineStatusIndicatorColor,
      Color? privateGroupIconBackground,
      Color? protectedGroupIconBackground,
      bool? disableUsersPresence,
      Widget? selectIcon}) {
    Color? backgroundColor;
    Widget? icon;
    if (isSelected == true) {
      // backgroundColor = theme.palette.getSuccess();
      backgroundColor = theme.palette.getPrimary();
      icon = selectIcon ?? const Icon(
        Icons.check,
        color: Colors.white,
        size: 12,
      );
    } else if (user != null && disableUsersPresence != true) {
      backgroundColor =
          user.status != null && user.status == UserStatusConstants.online
              ? (onlineStatusIndicatorColor ?? theme.palette.getSuccess())
              : null;
    } else if (group != null) {
      if (group.type == GroupTypeConstants.password) {
        backgroundColor =
            protectedGroupIconBackground ?? const Color(0xffF7A500);
        icon = protectedGroupIcon ??
            const Icon(
              Icons.lock,
              color: Colors.white,
              size: 7,
            );
      } else if (group.type == GroupTypeConstants.private) {
        backgroundColor =
            privateGroupIconBackground ?? theme.palette.getSuccess();
        icon = privateGroupIcon ??
            const Icon(Icons.back_hand, color: Colors.white, size: 7);
      }
    } else if (groupMember != null) {
      backgroundColor = groupMember.status != null &&
              groupMember.status == UserStatusConstants.online
          ? theme.palette.getSuccess()
          : null;
    }
    StatusIndicatorUtils utility = StatusIndicatorUtils();
    utility.icon = icon;
    utility.statusIndicatorColor = backgroundColor;
    return utility;
  }

  Widget? icon;
  Color? statusIndicatorColor;
}
