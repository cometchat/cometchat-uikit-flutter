import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

import '../utils/loading_indicator.dart';

/// An Screen that gives you option to create different type of groups
///
/// ```dart
/// CometChatCreateGroup(
///     title: 'Create Group',
///     showBackButton: true,
///     backButtonIcon: Container(),
///     createIcon: Container(),
///     style: CreateGroupStyle(
///       titleStyle: TextStyle(),
///       background: Colors.white
///     ),
///   );
/// ```
class CometChatCreateGroup extends StatefulWidget {
  const CometChatCreateGroup(
      {Key? key,
      this.title,
      this.backButtonIcon,
      this.showBackButton = true,
      this.createIcon,
      this.style = const CreateGroupStyle(),
      this.theme})
      : super(key: key);

  ///[title] Title of the component
  final String? title;

  ///[backButtonIcon] back button to be rendered
  final Widget? backButtonIcon;

  ///[showBackButton]switch on/off close button
  final bool showBackButton;

  ///[createIcon] create icon
  final Widget? createIcon;

  ///[style] styling properties
  final CreateGroupStyle style;

  ///[theme] custom theme
  final CometChatTheme? theme;

  @override
  State<CometChatCreateGroup> createState() => _CometChatCreateGroupState();
}

class _CometChatCreateGroupState extends State<CometChatCreateGroup>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _groupType = GroupTypeConstants.public;

  String _groupName = '';

  String _groupPassword = '';

  final _nameFieldKey = GlobalKey<FormFieldState>();

  final _passwordsFieldKey = GlobalKey<FormFieldState>();

  bool _isLoading = false;

  void _tabControllerListener() {
    if (_tabController.index == 0) {
      _groupType = GroupTypeConstants.public;
    } else if (_tabController.index == 1) {
      _groupType = GroupTypeConstants.private;
    } else if (_tabController.index == 2) {
      _groupType = GroupTypeConstants.password;
    }
    setState(() {});
  }

  @override
  void initState() {
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_tabControllerListener);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
  }

  _createGroup(CometChatTheme theme) async {
    if (_nameFieldKey.currentState!.validate() &&
        (_groupType != GroupTypeConstants.password ||
            (_groupType == GroupTypeConstants.password &&
                _passwordsFieldKey.currentState!.validate()))) {
      String gUid = "group_${DateTime.now().millisecondsSinceEpoch.toString()}";

      showLoadingIndicatorDialog(context,
          background: theme.palette.getBackground(),
          progressIndicatorColor: theme.palette.getPrimary(),
          shadowColor: theme.palette.getAccent300());

      setState(() {
        _isLoading = true;
      });

      CometChat.createGroup(gUid, _groupName, _groupType,
          password: _groupType == GroupTypeConstants.password
              ? _groupPassword
              : null, onSuccess: (Group group) {
        debugPrint("Group Created Successfully : $group ");
        Navigator.pop(context); //pop loading indicator
        _isLoading = false;
        Navigator.pop(context);
        CometChatGroupEvents.onGroupCreate(group);
      }, onError: (CometChatException e) {
        Navigator.pop(context); //pop loading indicator
        _isLoading = false;
        setState(() {});
        CometChatGroupEvents.onGroupError(e);
        debugPrint("Group Creation failed with exception: ${e.message}");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    CometChatTheme _theme = widget.theme ?? cometChatTheme;

    return CometChatListBase(
        title: Translations.of(context).new_group,
        backIcon: widget.backButtonIcon ??
            Image.asset(
              "assets/icons/close.png",
              package: UIConstants.packageName,
              color:
                  widget.style.backButtonIconColor ?? const Color(0xff3399FF),
            ),
        showBackButton: widget.showBackButton,
        hideSearch: true,
        style: ListBaseStyle(
          background: widget.style.background,
          titleStyle: widget.style.titleStyle,
        ),
        menuOptions: [
          IconButton(
              onPressed: () async {
                if (_isLoading == false) {
                  _createGroup(_theme);
                }
              },
              icon: widget.createIcon ??
                  Image.asset(
                    "assets/icons/checkmark.png",
                    package: UIConstants.packageName,
                    color:
                        widget.style.createIconColor ?? const Color(0xff3399FF),
                  ))
        ],
        container: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0),
          child: Column(
            children: [
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: widget.style.inActiveColor ??
                      const Color(0xff141414).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(
                    18.0,
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      18.0,
                    ),
                    color: widget.style.activeColor ?? const Color(0xff3399FF),
                  ),
                  labelColor: widget.style.selectedLabelStyle?.color ??
                      const Color(0xffFFFFFF),
                  unselectedLabelColor:
                      widget.style.unSelectedLabelStyle?.color ??
                          const Color(0xff141414).withOpacity(0.58),
                  labelStyle: widget.style.selectedLabelStyle ??
                      const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                  unselectedLabelStyle: widget.style.unSelectedLabelStyle ??
                      const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                  tabs: [
                    Tab(
                      text: Translations.of(context).public,
                    ),
                    Tab(
                      text: Translations.of(context).private,
                    ),
                    Tab(
                      text: Translations.of(context).protected,
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 24,
              ),
              SizedBox(
                height: 56,
                child: TextFormField(
                  key: _nameFieldKey,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return Translations.of(context).enter_group_name;
                    }
                    return null;
                  },
                  onChanged: (String val) {
                    _groupName = val;
                  },
                  maxLength: 25,
                  style: widget.style.inputTextStyle,
                  decoration: InputDecoration(
                      counterText: '',
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: widget.style.borderColor ??
                                const Color(0xff141414).withOpacity(0.1)),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: widget.style.borderColor ??
                                const Color(0xff141414).withOpacity(0.1)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: widget.style.borderColor ??
                                const Color(0xff141414).withOpacity(0.1)),
                      ),
                      hintText: Translations.of(context).name,
                      hintStyle: widget.style.hintTextStyle ??
                          TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                              color:
                                  const Color(0xff141414).withOpacity(0.58))),
                ),
              ),
              if (_groupType == GroupTypeConstants.password)
                SizedBox(
                  height: 56,
                  child: TextFormField(
                    key: _passwordsFieldKey,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return Translations.of(context).enter_group_password;
                      }
                      return null;
                    },
                    maxLength: 16,
                    onChanged: (String val) {
                      _groupPassword = val;
                    },
                    style: widget.style.inputTextStyle,
                    decoration: InputDecoration(
                        counterText: '',
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: widget.style.borderColor ??
                                  const Color(0xff141414).withOpacity(0.1)),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: widget.style.borderColor ??
                                  const Color(0xff141414).withOpacity(0.1)),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: widget.style.borderColor ??
                                  const Color(0xff141414).withOpacity(0.1)),
                        ),
                        hintText: Translations.of(context).password,
                        hintStyle: widget.style.hintTextStyle ??
                            TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w400,
                                color:
                                    const Color(0xff141414).withOpacity(0.58))),
                  ),
                )
            ],
          ),
        ));
  }
}

class CreateGroupStyle {
  const CreateGroupStyle(
      {this.background,
      this.titleStyle,
      this.borderColor,
      this.backButtonIconColor,
      this.createIconColor,
      this.activeColor,
      this.inActiveColor,
      this.selectedLabelStyle,
      this.unSelectedLabelStyle,
      this.hintTextStyle,
      this.inputTextStyle});

  final Color? backButtonIconColor;

  final Color? createIconColor;

  final Color? background;

  final TextStyle? titleStyle;

  final Color? activeColor;

  final Color? inActiveColor;

  final TextStyle? selectedLabelStyle;

  final TextStyle? unSelectedLabelStyle;

  final TextStyle? hintTextStyle;

  final Color? borderColor;

  final TextStyle? inputTextStyle;
}
