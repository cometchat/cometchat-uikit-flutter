import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../cometchat_chat_uikit.dart';

///[CometChatCreateGroupController] is the view model for [CometChatCreateGroup]
///it contains all the business logic involved in changing the state of the UI of [CometChatCreateGroup]
class CometChatCreateGroupController extends GetxController {
  late CometChatTheme theme;
  BuildContext? context;
  late TabController tabController;
  Function(Group group)? onCreateTap;

  ///[onError] callback triggered in case any error happens when trying to create group
  final Function(Exception)? onError;

  CometChatCreateGroupController(this.theme, {this.onCreateTap, this.onError}) {
    tag = "tag$counter";
    counter++;
  }

  @override
  void dispose() {
    super.dispose();
    tabController.dispose();
  }

  void tabControllerListener() {
    if (tabController.index == 0) {
      groupType = GroupTypeConstants.public;
    } else if (tabController.index == 1) {
      groupType = GroupTypeConstants.private;
    } else if (tabController.index == 2) {
      groupType = GroupTypeConstants.password;
    }
    update();
  }

  static int counter = 0;
  late String tag;

  String groupType = GroupTypeConstants.public;

  String groupName = '';

  String groupPassword = '';

  bool isLoading = false;

  onPasswordChange(String val) {
    groupPassword = val;
  }

  onNameChange(String val) {
    groupName = val;
  }

  onCreateIconCLick(BuildContext context) {
    if (onCreateTap != null) {
      String gUid = "group_${DateTime.now().millisecondsSinceEpoch.toString()}";
      Group group = Group(
          guid: gUid,
          name: groupName,
          type: groupType,
          password: groupPassword);

      onCreateTap!(group);
    } else if (isLoading == false) {
      createGroup(context);
    }
  }

  createGroup(BuildContext context) async {
    String gUid = "group_${DateTime.now().millisecondsSinceEpoch.toString()}";

    showLoadingIndicatorDialog(context,
        background: theme.palette.getBackground(),
        progressIndicatorColor: theme.palette.getPrimary(),
        shadowColor: theme.palette.getAccent300());

    isLoading = true;

    update();

    Group group = Group(
        guid: gUid,
        name: groupName,
        type: groupType,
        password:
            groupType == GroupTypeConstants.password ? groupPassword : null);
    CometChat.createGroup(
        group: group,
        onSuccess: (Group group) {
          if (kDebugMode) {
            debugPrint("Group Created Successfully : $group ");
          }
          Navigator.pop(context); //pop loading indicator
          isLoading = false;
          Navigator.pop(context);
          CometChatGroupEvents.ccGroupCreated(group);
        },
        onError: onError ??
            (CometChatException e) {
              Navigator.pop(context); //pop loading indicator
              isLoading = false;
              update();
              debugPrint("Group Creation failed with exception: ${e.message}");
            });
  }
}
