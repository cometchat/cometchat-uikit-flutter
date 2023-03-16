import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../flutter_chat_ui_kit.dart';
import '../utils/loading_indicator.dart';

class CometChatCreateGroupController extends GetxController {
  late CometChatTheme theme;
  BuildContext? context;
  late TabController tabController;
  Function(Group group)? onCreateTap;

  ///[onError] callback triggered in case any error happens when trying to create group
  final Function(Exception)? onError;

  CometChatCreateGroupController(this.theme, {this.onCreateTap,this.onError}) {
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
      String _gUid =
          "group_${DateTime.now().millisecondsSinceEpoch.toString()}";
      Group _group = Group(
          guid: _gUid,
          name: groupName,
          type: groupType,
          password: groupPassword);

      onCreateTap!(_group);
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

    Group _group = Group(
        guid: gUid,
        name: groupName,
        type: groupType,
        password:
            groupType == GroupTypeConstants.password ? groupPassword : null);
    CometChat.createGroup(
        group: _group,
        onSuccess: (Group group) {
          debugPrint("Group Created Successfully : $group ");
          Navigator.pop(context); //pop loading indicator
          isLoading = false;
          Navigator.pop(context);
          CometChatGroupEvents.ccGroupCreated(group);
        },
        onError: onError ?? (CometChatException e) {
          Navigator.pop(context); //pop loading indicator
          isLoading = false;
          update();
          debugPrint("Group Creation failed with exception: ${e.message}");
        });
  }
}
