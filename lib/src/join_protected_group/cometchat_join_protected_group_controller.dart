import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:get/get_state_manager/get_state_manager.dart';

///[CometChatJoinProtectedGroupController] is the view model for [CometChatJoinProtectedGroup]
///it contains all the business logic involved in changing the state of the UI of [CometChatJoinProtectedGroup]
class CometChatJoinProtectedGroupController extends GetxController {
  CometChatJoinProtectedGroupController(
      {required this.group,
      this.onJoinTap,
      this.onError,
      this.errorStateText,
      this.errorTextStyle,
      this.background});

  ///[group] the group to join
  final Group group;

  ///[errorTextStyle] provides styling for error text
  final TextStyle? errorTextStyle;

  ///[background] default background color of widget
  final Color? background;

  ///[onError] callback triggered if unable to join group
  final OnError? onError;

  ///[onJoinTap] triggered on join group icon tap
  final Function({Group group, String password})? onJoinTap;

  ///[errorStateText] text to show if any error occurs when joining the group
  final String? errorStateText;

  final passwordsFieldKey = GlobalKey<FormFieldState>();

  final TextEditingController textEditingController = TextEditingController();

  String getGroupName(BuildContext context) {
    final String groupName = group.name;

    if (groupName.isNotEmpty) {
      return '$groupName ${Translations.of(context).group}';
    } else {
      return Translations.of(context).protectedGroup;
    }
  }

  _joinGroup(
      {required String guid,
      required String groupType,
      String password = "",
      required CometChatTheme theme,
      required BuildContext context}) {
    showLoadingIndicatorDialog(context,
        background: theme.palette.getBackground(),
        progressIndicatorColor: theme.palette.getPrimary(),
        shadowColor: theme.palette.getAccent300());
    CometChat.joinGroup(guid, groupType, password: password,
        onSuccess: (Group group) async {
      if (kDebugMode) {
        debugPrint("Group Joined Successfully : $group ");
      }
      User? user = await CometChat.getLoggedInUser();
      if (context.mounted) {
        Navigator.pop(context); //pop loading indicator
        Navigator.pop(context); //pop join group screen
      }
      if (group.hasJoined == false) {
        group.hasJoined = true;
      }
      CometChatGroupEvents.ccGroupMemberJoined(user!, group);
    },
        onError: onError ??
            (CometChatException e) {
              Navigator.pop(context); //pop loading indicator
              showCometChatConfirmDialog(
                  context: context,
                  style: ConfirmDialogStyle(
                      backgroundColor:
                          theme.palette.mode == PaletteThemeModes.light
                              ? theme.palette.getBackground()
                              : Color.alphaBlend(theme.palette.getAccent200(),
                                  theme.palette.getBackground()),
                      shadowColor: theme.palette.getAccent300(),
                      confirmButtonTextStyle: TextStyle(
                          fontSize: theme.typography.text2.fontSize,
                          fontWeight: theme.typography.text2.fontWeight,
                          color: theme.palette.getPrimary())),
                  title: Text(Translations.of(context).incorrectPassword,
                      style: TextStyle(
                          fontSize: theme.typography.name.fontSize,
                          fontWeight: theme.typography.name.fontWeight,
                          color: theme.palette.getAccent(),
                          fontFamily: theme.typography.name.fontFamily)),
                  messageText: Text(
                    errorStateText ??
                        Translations.of(context).pleaseTryAnotherPassword,
                    style: TextStyle(
                            fontSize: theme.typography.title2.fontSize,
                            fontWeight: theme.typography.title2.fontWeight,
                            color: theme.palette.getAccent(),
                            fontFamily: theme.typography.title2.fontFamily)
                        .merge(errorTextStyle),
                  ),
                  confirmButtonText: Translations.of(context).okay,
                  onConfirm: () {
                    Navigator.pop(context); //pop confirm dialog
                  });
            });
  }

  requestJoinGroup(BuildContext context, CometChatTheme theme) async {
    if (passwordsFieldKey.currentState!.validate()) {
      if (onJoinTap != null) {
        onJoinTap!(group: group, password: textEditingController.text);
      } else {
        final String guid = group.guid;
        _joinGroup(
            guid: guid,
            groupType: GroupTypeConstants.password,
            password: textEditingController.text,
            theme: theme,
            context: context);
      }
    }
  }

  String? validatePassword(String? value, BuildContext context) {
    if (value == null || value.isEmpty) {
      return Translations.of(context).enterGroupPassword;
    }
    return null;
  }
}
