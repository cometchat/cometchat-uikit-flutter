import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_chat_ui_kit/src/utils/loading_indicator.dart';

/// A component that gives UI to join protected group
///
/// ```dart
/// CometChatJoinProtectedGroup(
///       group: Group(),
///       backButtonIcon: Container(),
///       title: 'Join Group',
///       hideCloseButton: false,
///       joinIcon:Container(),
///       style: JoinProtectedGroupStyle(
///         background: Colors.white,
///         titleStyle: TextStyle()
///       )
//   );
/// ```
class CometChatJoinProtectedGroup extends StatefulWidget {
  const CometChatJoinProtectedGroup(
      {Key? key,
      required this.group,
      this.title,
      this.backButtonIcon,
      this.hideCloseButton = false,
      this.joinIcon,
      this.style = const JoinProtectedGroupStyle(),
      this.theme})
      : super(key: key);

  final Group group;

  ///[title] set title of the component
  final String? title;

  ///[backButtonIcon] replace back button
  final Widget? backButtonIcon;

  ///[hideCloseButton] toggle visibility for close button
  final bool hideCloseButton;

  ///[joinIcon] replace create icon
  final Widget? joinIcon;

  ///[style] set styling properties
  final JoinProtectedGroupStyle style;

  ///[theme] set custom theme
  final CometChatTheme? theme;

  @override
  State<CometChatJoinProtectedGroup> createState() =>
      _CometChatJoinProtectedGroupState();
}

class _CometChatJoinProtectedGroupState
    extends State<CometChatJoinProtectedGroup> {
  final _passwordsFieldKey = GlobalKey<FormFieldState>();

  final TextEditingController _textEditingController = TextEditingController();

  _joinGroup(
      {required String guid,
      required String groupType,
      String password = "",
      required CometChatTheme theme}) {
    showLoadingIndicatorDialog(context,
        background: theme.palette.getBackground(),
        progressIndicatorColor: theme.palette.getPrimary(),
        shadowColor: theme.palette.getAccent300());
    CometChat.joinGroup(guid, groupType, password: password,
        onSuccess: (Group group) async {
      debugPrint("Group Joined Successfully : $group ");
      User? user = await CometChat.getLoggedInUser();
      Navigator.pop(context); //pop loading indicator
      Navigator.pop(context); //pop join group screen

      //ToDo: remove after sdk issue solve
      group.hasJoined = true;
      CometChatGroupEvents.onGroupMemberJoin(user!, group);
    }, onError: (CometChatException e) {
      Navigator.pop(context); //pop loading indicator
      showCometChatConfirmDialog(
          context: context,
          style: ConfirmDialogStyle(
              backgroundColor:
                  widget.style.background ?? theme.palette.getBackground(),
              shadowColor: theme.palette.getAccent300(),
              confirmButtonTextStyle: TextStyle(
                  fontSize: theme.typography.text2.fontSize,
                  fontWeight: theme.typography.text2.fontWeight,
                  color: theme.palette.getPrimary())),
          title: Text(Translations.of(context).incorrect_password,
              style: TextStyle(
                  fontSize: theme.typography.name.fontSize,
                  fontWeight: theme.typography.name.fontWeight,
                  color: theme.palette.getAccent(),
                  fontFamily: theme.typography.name.fontFamily)),
          messageText: Text(
            Translations.of(context).please_try_another_password,
            style: TextStyle(
                fontSize: theme.typography.title2.fontSize,
                fontWeight: theme.typography.title2.fontWeight,
                color: theme.palette.getAccent(),
                fontFamily: theme.typography.title2.fontFamily),
          ),
          confirmButtonText: Translations.of(context).okay,
          onConfirm: () {
            Navigator.pop(context); //pop confirm dialog
          });
      debugPrint("Group Joining failed with exception: ${e.message}");
      CometChatGroupEvents.onGroupError(e);
    });
  }

  String _getGroupName(BuildContext context) {
    if (widget.group.name.isNotEmpty) {
      return '${widget.group.name} ${Translations.of(context).group}';
    } else {
      return Translations.of(context).protected_group;
    }
  }

  @override
  Widget build(BuildContext context) {
    CometChatTheme _theme = widget.theme ?? cometChatTheme;

    return CometChatListBase(
        title: widget.title ?? Translations.of(context).protected_group,
        theme: widget.theme,
        backIcon: widget.backButtonIcon ??
            Image.asset(
              "assets/icons/close.png",
              package: UIConstants.packageName,
              color: widget.style.backButtonIconColor ??
                  _theme.palette.getPrimary(),
            ),
        showBackButton: !widget.hideCloseButton,
        hideSearch: true,
        style: ListBaseStyle(
            background: widget.style.background,
            titleStyle: widget.style.titleStyle,
            gradient: widget.style.gradient),
        menuOptions: [
          IconButton(
              onPressed: () async {
                if (_passwordsFieldKey.currentState!.validate()) {
                  _joinGroup(
                      guid: widget.group.guid,
                      groupType: GroupTypeConstants.password,
                      password: _textEditingController.text,
                      theme: _theme);
                }
              },
              icon: widget.joinIcon ??
                  Image.asset(
                    "assets/icons/checkmark.png",
                    package: UIConstants.packageName,
                    color: widget.style.joinIconColor ??
                        _theme.palette.getPrimary(),
                  ))
        ],
        container: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Column(
            children: [
              Text(
                '${Translations.of(context).enter_password_to_access} ${_getGroupName(context)}.',
                style: widget.style.headingStyle ??
                    TextStyle(
                      color: _theme.palette.getAccent(),
                      fontSize: _theme.typography.subtitle1.fontSize,
                      fontFamily: _theme.typography.subtitle1.fontFamily,
                      fontWeight: _theme.typography.subtitle1.fontWeight,
                    ),
              ),
              const SizedBox(
                height: 24,
              ),
              SizedBox(
                height: 56,
                child: TextFormField(
                  key: _passwordsFieldKey,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return Translations.of(context).enter_group_password;
                    }
                    return null;
                  },
                  controller: _textEditingController,
                  maxLength: 16,
                  style: TextStyle(
                    color: _theme.palette.getAccent(),
                    fontSize: _theme.typography.body.fontSize,
                    fontFamily: _theme.typography.body.fontFamily,
                    fontWeight: _theme.typography.body.fontWeight,
                  ),
                  decoration: InputDecoration(
                      counterText: '',
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: widget.style.borderColor ??
                                _theme.palette.getAccent100()),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: widget.style.borderColor ??
                                _theme.palette.getAccent100()),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: widget.style.borderColor ??
                                _theme.palette.getAccent100()),
                      ),
                      hintText: Translations.of(context).group_password,
                      hintStyle: widget.style.hintTextStyle ??
                          TextStyle(
                            color: _theme.palette.getAccent600(),
                            fontSize: _theme.typography.body.fontSize,
                            fontFamily: _theme.typography.body.fontFamily,
                            fontWeight: _theme.typography.body.fontWeight,
                          )),
                ),
              ),
            ],
          ),
        ));
  }
}

class JoinProtectedGroupStyle {
  const JoinProtectedGroupStyle(
      {this.backButtonIconColor,
      this.joinIconColor,
      this.background,
      this.titleStyle,
      this.inputTextStyle,
      this.headingStyle,
      this.hintTextStyle,
      this.borderColor,
      this.gradient});

  final Color? backButtonIconColor;

  final Color? joinIconColor;

  final Color? background;

  final TextStyle? titleStyle;

  final TextStyle? inputTextStyle;

  final TextStyle? headingStyle;

  final TextStyle? hintTextStyle;

  final Color? borderColor;

  final Gradient? gradient;
}
