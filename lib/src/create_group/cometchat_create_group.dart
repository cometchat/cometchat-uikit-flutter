import 'package:flutter/material.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart';
import 'package:cometchat_chat_uikit/cometchat_chat_uikit.dart' as cc;
import 'package:get/get.dart';

///[CometChatCreateGroup] is a widget that allows users to create different type of groups
///
/// ```dart
/// CometChatCreateGroup(createGroupStyle: CreateGroupStyle(),);
/// ```
///
class CometChatCreateGroup extends StatefulWidget {
  const CometChatCreateGroup(
      {Key? key,
      this.title,
      this.createIcon,
      this.namePlaceholderText,
      this.closeIcon,
      this.disableCloseButton,
      this.onCreateTap,
      this.createGroupStyle = const CreateGroupStyle(),
      this.theme,
      this.passwordPlaceholderText,
      this.onBack,
      this.onError})
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

  ///[createGroupStyle] styling properties
  final CreateGroupStyle createGroupStyle;

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
    createGroupController = CometChatCreateGroupController(theme,
        onCreateTap: widget.onCreateTap, onError: widget.onError);
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
        builder: (CometChatCreateGroupController createGroupController) {
          return CometChatListBase(
              title: widget.title ?? cc.Translations.of(context).new_group,
              theme: theme,
              backIcon: widget.closeIcon ??
                  Image.asset(
                    AssetConstants.close,
                    package: UIConstants.packageName,
                    color: widget.createGroupStyle.closeIconTint ??
                        theme.palette.getPrimary(),
                  ),
              showBackButton: !(widget.disableCloseButton == true),
              onBack: widget.onBack,
              hideSearch: true,
              style: ListBaseStyle(
                  backIconTint: widget.createGroupStyle.closeIconTint ??
                      theme.palette.getPrimary(),
                  background: widget.createGroupStyle.background ??
                      theme.palette.getBackground(),
                  titleStyle: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: theme.palette.getAccent())
                      .merge(widget.createGroupStyle.titleTextStyle),
                  gradient: widget.createGroupStyle.gradient,
                  border: widget.createGroupStyle.border,
                  borderRadius: widget.createGroupStyle.borderRadius,
                  height: widget.createGroupStyle.height,
                  width: widget.createGroupStyle.width),
              menuOptions: [
                IconButton(
                    onPressed: () async {
                      createGroupController.onCreateIconCLick(context);
                    },
                    icon: widget.createIcon ??
                        Image.asset(
                          AssetConstants.checkmark,
                          package: UIConstants.packageName,
                          color: widget.createGroupStyle.createIconTint ??
                              theme.palette.getPrimary(),
                        ))
              ],
              container: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                child: Column(
                  children: [
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: widget.createGroupStyle.tabColor ??
                            theme.palette.getAccent100(),
                        borderRadius: BorderRadius.circular(
                          18.0,
                        ),
                      ),
                      child: TabBar(
                        controller: createGroupController.tabController,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            18.0,
                          ),
                          color: widget.createGroupStyle.selectedTabColor ??
                              theme.palette.getPrimary(),
                        ),
                        labelColor: widget
                                .createGroupStyle.selectedTabTextStyle?.color ??
                            theme.palette.getBackground(),
                        unselectedLabelColor:
                            widget.createGroupStyle.tabTextStyle?.color ??
                                theme.palette.getAccent600(),
                        labelStyle: TextStyle(
                          color: theme.palette.getBackground(),
                          fontSize: theme.typography.text1.fontSize,
                          fontFamily: theme.typography.text1.fontFamily,
                          fontWeight: theme.typography.text1.fontWeight,
                        ).merge(widget.createGroupStyle.selectedTabTextStyle),
                        unselectedLabelStyle: TextStyle(
                          color: theme.palette.getAccent600(),
                          fontSize: theme.typography.text1.fontSize,
                          fontFamily: theme.typography.text1.fontFamily,
                          fontWeight: theme.typography.text1.fontWeight,
                        ).merge(widget.createGroupStyle.tabTextStyle),
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
                              initialValue: createGroupController.groupName,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return cc.Translations.of(context)
                                      .enter_group_name;
                                }
                                return null;
                              },
                              onChanged: createGroupController.onNameChange,
                              maxLength: 25,
                              style: widget
                                      .createGroupStyle.nameInputTextStyle ??
                                  TextStyle(
                                    color: theme.palette.getAccent(),
                                    fontSize: theme.typography.body.fontSize,
                                    fontFamily:
                                        theme.typography.body.fontFamily,
                                    fontWeight:
                                        theme.typography.body.fontWeight,
                                  ),
                              decoration: InputDecoration(
                                  counterText: '',
                                  border: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: widget
                                                .createGroupStyle.borderColor ??
                                            theme.palette.getAccent100()),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: widget
                                                .createGroupStyle.borderColor ??
                                            theme.palette.getAccent100()),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: theme.palette.getAccent100()),
                                  ),
                                  hintText: widget.namePlaceholderText ??
                                      cc.Translations.of(context).name,
                                  hintStyle: widget.createGroupStyle
                                          .namePlaceholderTextStyle ??
                                      TextStyle(
                                        color: theme.palette.getAccent600(),
                                        fontSize:
                                            theme.typography.body.fontSize,
                                        fontFamily:
                                            theme.typography.body.fontFamily,
                                        fontWeight:
                                            theme.typography.body.fontWeight,
                                      )),
                              keyboardAppearance:
                                  theme.palette.mode == PaletteThemeModes.light
                                      ? Brightness.light
                                      : Brightness.dark,
                            ),
                          ),
                          if (createGroupController.groupType ==
                              GroupTypeConstants.password)
                            SizedBox(
                              height: 56,
                              child: TextFormField(
                                initialValue:
                                    createGroupController.groupPassword,
                                validator: (value) {
                                  if (createGroupController.groupType ==
                                          GroupTypeConstants.password &&
                                      (value == null || value.isEmpty)) {
                                    return cc.Translations.of(context)
                                        .enter_group_password;
                                  }
                                  return null;
                                },
                                maxLength: 16,
                                onChanged:
                                    createGroupController.onPasswordChange,
                                style: widget.createGroupStyle
                                        .passwordInputTextStyle ??
                                    TextStyle(
                                      color: theme.palette.getAccent(),
                                      fontSize: theme.typography.body.fontSize,
                                      fontFamily:
                                          theme.typography.body.fontFamily,
                                      fontWeight:
                                          theme.typography.body.fontWeight,
                                    ),
                                decoration: InputDecoration(
                                    counterText: '',
                                    border: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: widget.createGroupStyle
                                                  .borderColor ??
                                              theme.palette.getAccent100()),
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: widget.createGroupStyle
                                                  .borderColor ??
                                              theme.palette.getAccent100()),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: theme.palette.getAccent100()),
                                    ),
                                    hintText: widget.passwordPlaceholderText ??
                                        cc.Translations.of(context).password,
                                    hintStyle: widget.createGroupStyle
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
                                keyboardAppearance: theme.palette.mode ==
                                        PaletteThemeModes.light
                                    ? Brightness.light
                                    : Brightness.dark,
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
