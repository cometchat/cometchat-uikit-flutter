import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
// import 'package:flutter_chat_ui_kit/src/utils/loading_indicator.dart';

/// A component that gives UI to join protected group
///
/// ```dart
/// CometChatJoinProtectedGroup(
///       group: Group(),
///       closeIcon: Container(),
///       title: 'Join Group',
///       hideCloseButton: false,
///       joinIcon:Icon(),
///       onJoinTap: (group){},
///       style: JoinProtectedGroupStyle(
///         background: Colors.white,
///         titleStyle: TextStyle()
///       )
//   );
/// ```
class CometChatJoinProtectedGroup extends StatelessWidget {
  CometChatJoinProtectedGroup(
      {Key? key,
      required Group group,
      this.title,
      this.description,
      this.passwordPlaceholderText,
      Function({Group group,String password})? onJoinTap,
      this.closeIcon,
      this.joinIcon,
      this.style,
      OnError? onError,
      this.theme,
      this.onBack
      })
      : cometChatJoinProtectedGroupController =
            CometChatJoinProtectedGroupController(
                group:group, onError: onError,onJoinTap: onJoinTap,background: style?.background,errorTextStyle: style?.errorTextStyle),
        super(key: key);


  ///[title] sets title of the component
  final String? title;

  ///[description] sets description of the component
  final String? description;

  ///[closeIcon] replace back button
  final Widget? closeIcon;

  ///[joinIcon] replace join icon
  final Widget? joinIcon;

  ///[style] set styling properties
  final JoinProtectedGroupStyle? style;

  ///[theme] set custom theme
  final CometChatTheme? theme;

  ///[passwordPlaceholderText] placeholder for password input field
  final String? passwordPlaceholderText;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;


  final CometChatJoinProtectedGroupController
      cometChatJoinProtectedGroupController;

  @override
  Widget build(BuildContext context) {
    CometChatTheme _theme = theme ?? cometChatTheme;

    return GetBuilder(
        init: cometChatJoinProtectedGroupController,
        global: false,
        dispose:
            (GetBuilderState<CometChatJoinProtectedGroupController> state) =>
                state.controller?.onClose(),
        builder: (CometChatJoinProtectedGroupController controller) {
          return CometChatListBase(
              title: title ?? Translations.of(context).protected_group,
              theme: theme,
              backIcon: closeIcon ??
                  Image.asset(
                    AssetConstants.close,
                    package: UIConstants.packageName,
                    color: style?.closeIconTint ?? _theme.palette.getPrimary(),
                  ),
              showBackButton: true,
              onBack: onBack,
              hideSearch: true,
              style: ListBaseStyle(
                  backIconTint: style?.closeIconTint,
                  background: style?.background,
                  titleStyle: style?.titleStyle,
                  gradient: style?.gradient,
                  border: style?.border,
                  borderRadius: style?.borderRadius,
                  width: style?.width,
                  height: style?.height),
              menuOptions: [
                IconButton(
                    onPressed: () => controller.requestJoinGroup(context, _theme),
                    icon: joinIcon ??
                        Image.asset(
                          AssetConstants.checkmark,
                          package: UIConstants.packageName,
                          color: style?.joinIconTint ??
                              _theme.palette.getPrimary(),
                        ))
              ],
              container: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Column(
                  children: [
                    Text(
                      description ?? '${Translations.of(context).enter_password_to_access} ${controller.getGroupName(context)}.',
                      style: TextStyle(
                        color: _theme.palette.getAccent(),
                        fontSize: _theme.typography.subtitle1.fontSize,
                        fontFamily: _theme.typography.subtitle1.fontFamily,
                        fontWeight: _theme.typography.subtitle1.fontWeight,
                      ).merge(style?.descriptionTextStyle),
                    ),
                    const SizedBox(
                      height: 24,
                    ),
                    SizedBox(
                      height: 56,
                      child: TextFormField(
                        key: controller.passwordsFieldKey,
                        keyboardAppearance: _theme.palette.mode==PaletteThemeModes.light?Brightness.light:Brightness.dark,
                        obscureText: true,
                        validator: (value) =>
                            controller.validatePassword(value, context),
                        controller: controller.textEditingController,
                        maxLength: 16,
                        style: TextStyle(
                          color: _theme.palette.getAccent(),
                          fontSize: _theme.typography.body.fontSize,
                          fontFamily: _theme.typography.body.fontFamily,
                          fontWeight: _theme.typography.body.fontWeight,
                        ).merge(style?.passwordInputTextStyle),
                        decoration: InputDecoration(
                            counterText: '',
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: style?.inputBorderColor ??
                                      _theme.palette.getAccent100()),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: style?.inputBorderColor ??
                                      _theme.palette.getAccent100()),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: style?.inputBorderColor ??
                                      _theme.palette.getAccent100()),
                            ),
                            hintText: passwordPlaceholderText ?? Translations.of(context).group_password,
                            hintStyle: TextStyle(
                              color: _theme.palette.getAccent600(),
                              fontSize: _theme.typography.body.fontSize,
                              fontFamily: _theme.typography.body.fontFamily,
                              fontWeight: _theme.typography.body.fontWeight,
                            ).merge(style?.passwordPlaceholderStyle)),
                      ),
                    ),
                  ],
                ),
              ));
        });
  }
}
