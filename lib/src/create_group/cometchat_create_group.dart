import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart' as cc;
import 'package:get/get.dart';

/// An Screen that gives you option to create different type of groups
class CometChatCreateGroup extends StatefulWidget {
  const CometChatCreateGroup(
      {Key? key,
      this.title,
      this.createIcon,
      this.namePlaceholderText,
      this.closeIcon,
      this.disableCloseButton,
      this.onCreateTap,
      this.style = const CreateGroupStyle(),
      this.theme,
      this.passwordPlaceholderText,
      this.onBack,
      this.onError
      })
      : super(key: key);

  ///[title] Title of the component
  final String? title;

  ///[createIcon] create icon widget
  final Widget? createIcon;

  ///[closeIcon] close icon widget
  final Widget? closeIcon;

  ///[namePlaceholderText] group name input placeholder
  final String? namePlaceholderText;

  ///[passwordPlaceholderText] group password input placeholder
  final String? passwordPlaceholderText;

  ///[disableCloseButton] toggle visibility for close button
  final bool? disableCloseButton;

  ///[theme] instance of cometchat theme
  final CometChatTheme? theme;

  ///[onCreateTap] triggered on create group icon click
  final Function(Group group)? onCreateTap;

  ///[style] styling properties
  final CreateGroupStyle style;

  ///[onError] callback triggered in case any error happens when trying to create group
  final OnError? onError;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  @override
  State<CometChatCreateGroup> createState() => _CometChatCreateGroupState();
}

class _CometChatCreateGroupState extends State<CometChatCreateGroup>
    with SingleTickerProviderStateMixin {
  late CometChatCreateGroupController createGroupController;
  late CometChatTheme theme;

  @override
  void initState() {
    theme = widget.theme ?? cometChatTheme;
    createGroupController =
        CometChatCreateGroupController(theme, onCreateTap: widget.onCreateTap, onError: widget.onError);
    createGroupController.tabController = TabController(length: 3, vsync: this);
    createGroupController.tabController
        .addListener(createGroupController.tabControllerListener);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder(
        init: createGroupController,
        tag: createGroupController.tag,
        builder: (CometChatCreateGroupController _createGroupController) {
          return CometChatListBase(
              title: widget.title ?? cc.Translations.of(context).new_group,
              backIcon: widget.closeIcon ??
                  Image.asset(
                    AssetConstants.close,
                    package: UIConstants.packageName,
                    color: widget.style.closeIconTint ??
                        _createGroupController.theme.palette.getPrimary(),
                  ),
              showBackButton: !(widget.disableCloseButton == true),
              onBack: widget.onBack,
              hideSearch: true,
              style: ListBaseStyle(
                  backIconTint: widget.style.closeIconTint,
                  background: widget.style.background,
                  titleStyle: widget.style.titleTextStyle,
                  gradient: widget.style.gradient,
                  border: widget.style.border,
                  borderRadius: widget.style.borderRadius,
                  height: widget.style.height,
                  width: widget.style.width),
              menuOptions: [
                IconButton(
                    onPressed: () async {
                      _createGroupController.onCreateIconCLick(context);
                    },
                    icon: widget.createIcon ??
                        Image.asset(
                          AssetConstants.checkmark,
                          package: UIConstants.packageName,
                          color: widget.style.createIconTint ??
                              _createGroupController.theme.palette.getPrimary(),
                        ))
              ],
              container: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                child: Column(
                  children: [
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: widget.style.tabColor ??
                            _createGroupController.theme.palette.getAccent50(),
                        borderRadius: BorderRadius.circular(
                          18.0,
                        ),
                      ),
                      child: TabBar(
                        controller: _createGroupController.tabController,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            18.0,
                          ),
                          color: widget.style.selectedTabColor ??
                              _createGroupController.theme.palette.getPrimary(),
                        ),
                        labelColor: widget.style.selectedTabTextStyle?.color ??
                            _createGroupController.theme.palette
                                .getBackground(),
                        unselectedLabelColor: widget
                                .style.tabTextStyle?.color ??
                            _createGroupController.theme.palette.getAccent50(),
                        labelStyle: widget.style.selectedTabTextStyle ??
                            const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                        unselectedLabelStyle: widget.style.tabTextStyle ??
                            const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                        tabs: [
                          Tab(
                            text: cc.Translations.of(context).public,
                          ),
                          Tab(
                            text: cc.Translations.of(context).private,
                          ),
                          Tab(
                            text: cc.Translations.of(context).protected,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 24,
                    ),
                    Form(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 56,
                            child: TextFormField(
                              initialValue: _createGroupController.groupName,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return cc.Translations.of(context)
                                      .enter_group_name;
                                }
                                return null;
                              },
                              onChanged: _createGroupController.onNameChange,
                              maxLength: 25,
                              style: widget.style.nameInputTextStyle ??
                                  TextStyle(
                                    color: _createGroupController.theme.palette
                                        .getAccent(),
                                    fontSize: _createGroupController
                                        .theme.typography.body.fontSize,
                                    fontFamily: _createGroupController
                                        .theme.typography.body.fontFamily,
                                    fontWeight: _createGroupController
                                        .theme.typography.body.fontWeight,
                                  ),
                              decoration: InputDecoration(
                                  counterText: '',
                                  border: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: widget.style.borderColor ??
                                            _createGroupController.theme.palette
                                                .getAccent100()),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: widget.style.borderColor ??
                                            _createGroupController.theme.palette
                                                .getAccent100()),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: _createGroupController
                                            .theme.palette
                                            .getAccent100()),
                                  ),
                                  hintText: widget.namePlaceholderText ??
                                      cc.Translations.of(context).name,
                                  hintStyle:
                                      widget.style.namePlaceholderTextStyle ??
                                          TextStyle(
                                            color: _createGroupController
                                                .theme.palette
                                                .getAccent600(),
                                            fontSize: _createGroupController
                                                .theme.typography.body.fontSize,
                                            fontFamily: _createGroupController
                                                .theme
                                                .typography
                                                .body
                                                .fontFamily,
                                            fontWeight: _createGroupController
                                                .theme
                                                .typography
                                                .body
                                                .fontWeight,
                                          )),
                                  keyboardAppearance: theme.palette.mode==PaletteThemeModes.light?Brightness.light:Brightness.dark,
                            ),
                          ),
                          if (_createGroupController.groupType ==
                              GroupTypeConstants.password)
                            SizedBox(
                              height: 56,
                              child: TextFormField(
                                initialValue:
                                    _createGroupController.groupPassword,
                                validator: (value) {
                                  if (_createGroupController.groupType ==
                                          GroupTypeConstants.password &&
                                      (value == null || value.isEmpty)) {
                                    return cc.Translations.of(context)
                                        .enter_group_password;
                                  }
                                  return null;
                                },
                                maxLength: 16,
                                onChanged:
                                    _createGroupController.onPasswordChange,
                                style: widget.style.passwordInputTextStyle ??
                                    TextStyle(
                                      color: _createGroupController
                                          .theme.palette
                                          .getAccent(),
                                      fontSize: _createGroupController
                                          .theme.typography.body.fontSize,
                                      fontFamily: _createGroupController
                                          .theme.typography.body.fontFamily,
                                      fontWeight: _createGroupController
                                          .theme.typography.body.fontWeight,
                                    ),
                                decoration: InputDecoration(
                                    counterText: '',
                                    border: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: widget.style.borderColor ??
                                              _createGroupController
                                                  .theme.palette
                                                  .getAccent100()),
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: widget.style.borderColor ??
                                              _createGroupController
                                                  .theme.palette
                                                  .getAccent100()),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: _createGroupController
                                              .theme.palette
                                              .getAccent100()),
                                    ),
                                    hintText: widget.passwordPlaceholderText ??
                                        cc.Translations.of(context).password,
                                    hintStyle: widget.style
                                            .passwordPlaceholderTextStyle ??
                                        TextStyle(
                                          color: theme.palette.getAccent600(),
                                          fontSize:
                                              theme.typography.body.fontSize,
                                          fontFamily:
                                              theme.typography.body.fontFamily,
                                          fontWeight:
                                              theme.typography.body.fontWeight,
                                        )),
                                    keyboardAppearance: theme.palette.mode==PaletteThemeModes.light?Brightness.light:Brightness.dark,
                              ),
                            )
                        ],
                      ),
                    )
                  ],
                ),
              ));
        });
  }
}
