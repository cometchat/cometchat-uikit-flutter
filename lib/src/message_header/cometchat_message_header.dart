import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../flutter_chat_ui_kit.dart';
import '../../../flutter_chat_ui_kit.dart' as cc;

///[CometChatMessageHeader] is a widget which shows [user]/[group] details using [CometChatListItem]

///It user [CometChatMessageHeaderController] for defining its business logics
///
/// ```dart
/// CometChatMessageHeader(
///   user: <user>,
/// ),
///
/// ```
/// For Group
/// ```dart
/// CometChatMessageHeader(
///   group: <group>,
/// ),
///
/// ```
class CometChatMessageHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const CometChatMessageHeader(
      {Key? key,
      this.backButton,
      this.messageHeaderStyle = const MessageHeaderStyle(),
      this.group,
      this.user,
      this.appBarOptions,
      this.listItemView,
      this.hideBackButton,
      this.disableUserPresence,
      this.privateGroupIcon,
      this.protectedGroupIcon,
      this.subtitleView,
      this.theme,
      this.avatarStyle,
      this.statusIndicatorStyle,
      this.listItemStyle,
      this.disableTyping = false,
      this.onBack})
      : assert(user != null || group != null,
            "One of user or group should be passed"),
        assert(user == null || group == null,
            "Only one of user or group should be passed"),
        super(key: key);

  ///[backButton] used to set back button widget
  final WidgetBuilder? backButton;

  ///[subtitleView] to set subtitle view
  /// ```dart
  /// CometChatMessageHeader(
  ///    group: group,
  ///    subtitleView: (Group? group, User? user,BuildContext context) {
  ///                                 return Text("${group?.guid}");
  ///        },
  ///   )
  ///   ```
  final Widget? Function(Group? group, User? user, BuildContext context)?
      subtitleView;

  /// set [User] object, one is mandatory either [user] or [group]
  final User? user;

  ///set [Group] object, one is mandatory either [user] or [group]
  final Group? group;

  ///[listItemView] set custom view for listItem
  final Widget Function(Group? group, User? user, BuildContext context)?
      listItemView;

  ///[disableUserPresence] toggle functionality to show user's presence
  final bool? disableUserPresence;

  ///[protectedGroupIcon] group icon to be shown for protected groups
  final Widget? protectedGroupIcon;

  ///[privateGroupIcon] group icon to be shown for protected groups
  final Widget? privateGroupIcon;

  ///[MessageHeaderStyle] set styling props for message header
  ///
  /// ```dart
  ///CometChatMessageHeader(
  ///   group: group,
  ///   messageHeaderStyle: _headerStyle,
  ///   subtitleView: (Group? group, User? user,BuildContext context) {
  ///       return Text("${group?.guid}");
  ///       },
  /// ),
  /// ```
  final MessageHeaderStyle messageHeaderStyle;

  ///[hideBackButton] toggle visibility for back button
  final bool? hideBackButton;

  ///[theme] set custom theme
  final CometChatTheme? theme;

  ///[avatarStyle] set style for avatar
  final AvatarStyle? avatarStyle;

  ///[listItemStyle] style for every list item
  final ListItemStyle? listItemStyle;

  ///[statusIndicatorStyle] set style for status indicator
  final StatusIndicatorStyle? statusIndicatorStyle;

  ///[appBarOptions] set appbar options
  ///
  /// ```dart
  ///CometChatMessageHeader(
  /// 	 group: group,
  ///    appBarOptions: [
  // /
  ///       (User? user, Group? group,BuildContext context) {
  ///            return Icon(Icons.group);
  ///              },
  ///
  ///      (User? user, Group? group,BuildContext context) {
  ///                     return Icon(Icons.info);
  ///                     }
  ///         ],
  ///  ),
  ///  ```
  final List<Widget>? Function(User? user, Group? group, BuildContext context)?
      appBarOptions;

  ///[disableTyping] flag to disable typing indicators, default false
  final bool disableTyping;

  ///[onBack] callback triggered on closing this screen
  final VoidCallback? onBack;

  Widget getBackButton(BuildContext context, CometChatTheme _theme) {
    if (hideBackButton != true) {
      Widget _backButton;
      if (backButton != null) {
        _backButton = backButton!(context);
      } else {
        _backButton = GestureDetector(
          onTap: onBack ??
              () {
                Navigator.pop(context);
              },
          child: Image.asset(
            AssetConstants.back,
            package: UIConstants.packageName,
            color: messageHeaderStyle.backButtonIconTint ??
                _theme.palette.getPrimary(),
          ),
        );
      }

      return Padding(
          padding: const EdgeInsets.only(left: 20.0), child: _backButton);
    } else {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }
  }

  Widget _getTypingIndicator(BuildContext context,
      CometChatMessageHeaderController _controller, CometChatTheme _theme) {
    String text;
    if (_controller.userObject != null) {
      text = cc.Translations.of(context).is_typing;
    } else {
      text =
          "${_controller.typingUser?.name ?? ''} ${cc.Translations.of(context).is_typing}";
    }
    return Text(
      text,
      style: messageHeaderStyle.typingIndicatorTextStyle ??
          TextStyle(
            fontSize: _theme.typography.subtitle2.fontSize,
            color: _theme.palette.getPrimary(),
            fontWeight: _theme.typography.subtitle2.fontWeight,
          ),
    );
  }

  Widget? _getSubtitleView(BuildContext context,
      CometChatMessageHeaderController _controller, CometChatTheme _theme) {
    Widget? _subtitle;

    if (_controller.isTyping == true) {
      _subtitle = _getTypingIndicator(context, _controller, _theme);
    } else if (subtitleView != null) {
      _subtitle = subtitleView!(
          _controller.groupObject, _controller.userObject, context);
    } else if (_controller.userObject != null) {
      _subtitle = Text(
        _controller.userObject?.status ?? "",
        style: TextStyle(
          color: _controller.userObject?.status == UserStatusConstants.online
              ? _theme.palette.getPrimary()
              : _theme.palette.getAccent600(),
          fontSize: _theme.typography.subtitle2.fontSize,
          fontFamily: _theme.typography.subtitle2.fontFamily,
          fontWeight: _theme.typography.subtitle2.fontWeight,
        ).merge(messageHeaderStyle.subtitleTextStyle),
      );
    } else {
      _subtitle = Text(
        '${_controller.membersCount ?? 0} ${cc.Translations.of(context).members}',
        style: TextStyle(
          color: _controller.userObject?.status == UserStatusConstants.online
              ? _theme.palette.getPrimary()
              : _theme.palette.getAccent600(),
          fontSize: _theme.typography.subtitle2.fontSize,
          fontFamily: _theme.typography.subtitle2.fontFamily,
          fontWeight: _theme.typography.subtitle2.fontWeight,
        ).merge(messageHeaderStyle.subtitleTextStyle),
      );
    }
    return _subtitle;
  }

  _getBody(CometChatMessageHeaderController _controller, BuildContext context,
      CometChatTheme _theme) {
    return GetBuilder(
        init: _controller,
        tag: _controller.tag,
        dispose: (GetBuilderState<CometChatMessageHeaderController> state) =>
            Get.delete<CometChatMessageHeaderController>(
                tag: state.controller?.tag),
        builder: (CometChatMessageHeaderController value) {
          return _getListItem(value, _theme, context);
        });
  }

  Widget _getListItem(CometChatMessageHeaderController _controller,
      CometChatTheme _theme, BuildContext context) {
    if (listItemView != null) {
      return listItemView!(group, user, context);
    }

    String? _avatarName;
    String? _avatarUrl;
    String? _title;
    Widget? _subtitleView;
    Color? _statusIndicatorColor;
    Widget? _icon;
    Widget? _tailView;

    if (user != null) {
      _avatarName = _controller.userObject?.name;
      _avatarUrl = _controller.userObject?.avatar;
      _title = _controller.userObject?.name;
    } else {
      _avatarName = _controller.groupObject?.name;
      _avatarUrl = _controller.groupObject?.icon;
      _title = _controller.groupObject?.name;
    }
    StatusIndicatorUtils _util =
        StatusIndicatorUtils.getStatusIndicatorFromParams(
            theme: _theme,
            user: _controller.userObject,
            group: _controller.groupObject,
            privateGroupIcon: privateGroupIcon,
            protectedGroupIcon: protectedGroupIcon,
            onlineStatusIndicatorColor: messageHeaderStyle.onlineStatusColor);

    _statusIndicatorColor = _util.statusIndicatorColor;
    _icon = _util.icon;
    _subtitleView = _getSubtitleView(context, _controller, _theme);
    List<Widget>? _tailWidgetList = [];
    if (appBarOptions != null) {
      var temp = appBarOptions!(
          _controller.userObject, _controller.groupObject, context);

      if (temp != null) {
        _tailWidgetList.addAll(temp);
      }

      // for (var item in appBarOptions!) {
      //   _tailWidgetList.add(
      //       item(_controller.userObject, _controller.groupObject, context));
      // }
    }

    // if (hideDetail != true) {
    //   _tailWidgetList ??= [];
    //   _tailWidgetList.add(IconButton(
    //       padding: EdgeInsets.zero,
    //       onPressed: () {
    //         CometChatMessageEvents.onViewDetail(user, group);
    //       },
    //       icon: detailIcon ??
    //           Image.asset(
    //             AssetConstants.infoIcon,
    //             package: UIConstants.packageName,
    //           )));
    // }

    if (_tailWidgetList.isNotEmpty) {
      _tailView = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: _tailWidgetList,
      );
    }

    return GestureDetector(
      onTap: () {},
      child: CometChatListItem(
        avatarName: _avatarName,
        avatarURL: _avatarUrl,
        title: _title,
        subtitleView: _subtitleView,
        avatarStyle: avatarStyle ?? const AvatarStyle(),
        statusIndicatorColor: _statusIndicatorColor,
        statusIndicatorIcon: _icon,
        statusIndicatorStyle:
            statusIndicatorStyle ?? const StatusIndicatorStyle(),
        theme: _theme,
        hideSeparator: true,
        tailView: _tailView,
        style: listItemStyle ??
            ListItemStyle(
                background: Colors.transparent,
                height: 56,
                titleStyle: TextStyle(
                    fontSize: _theme.typography.name.fontSize,
                    fontWeight: _theme.typography.name.fontWeight,
                    fontFamily: _theme.typography.name.fontFamily,
                    color: _theme.palette.getAccent())),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    CometChatTheme _theme = theme ?? cometChatTheme;
    CometChatMessageHeaderController controller =
        CometChatMessageHeaderController(
            userObject: user, groupObject: group, disableTyping: disableTyping);

    return Container(
      height: messageHeaderStyle.height ?? 56,
      width: messageHeaderStyle.width ?? MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
          color: messageHeaderStyle.gradient == null
              ? messageHeaderStyle.background ?? _theme.palette.getBackground()
              : null,
          border: messageHeaderStyle.border,
          gradient: messageHeaderStyle.gradient,
          borderRadius:
              BorderRadius.circular(messageHeaderStyle.borderRadius ?? 0)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          getBackButton(context, _theme),
          Expanded(
              child: Padding(
            padding: const EdgeInsets.only(left: 20.0, right: 16),
            child: _getBody(controller, context, _theme),
          ))
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(messageHeaderStyle.height ?? 65);
}
