import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../cometchat_chat_uikit.dart';
import '../../../cometchat_chat_uikit.dart' as cc;

///[CometChatMessageHeader] is a widget which shows [user]/[group] details using [CometChatListItem]
///if its being shown for an [User] then the name of the user will be in the [title] of [CometChatListItem] and their online/offline status will be in the [subtitle]
///if its being shown for an [Group] then the name of the group will be in the [title] of [CometChatListItem] and their member count will be in the [subtitle]
///
/// ```dart
/// CometChatMessageHeader(
///   user: <user>,
///   messageHeaderStyle: MessageHeaderStyle(),
/// );
///
/// ```
/// For Group
/// ```dart
/// CometChatMessageHeader(
///   group: <group>,
///  messageHeaderStyle: MessageHeaderStyle(),
/// );
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

  Widget getBackButton(BuildContext context, CometChatTheme theme) {
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
                theme.palette.getPrimary(),
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
      CometChatMessageHeaderController controller, CometChatTheme theme) {
    String text;
    if (controller.userObject != null) {
      text = cc.Translations.of(context).is_typing;
    } else {
      text =
          "${controller.typingUser?.name ?? ''} ${cc.Translations.of(context).is_typing}";
    }
    return Text(
      text,
      style: messageHeaderStyle.typingIndicatorTextStyle ??
          TextStyle(
            fontSize: theme.typography.subtitle2.fontSize,
            color: theme.palette.getPrimary(),
            fontWeight: theme.typography.subtitle2.fontWeight,
          ),
    );
  }

  Widget? _getSubtitleView(BuildContext context,
      CometChatMessageHeaderController controller, CometChatTheme theme) {
    Widget? subtitle;

    if (controller.isTyping == true) {
      subtitle = _getTypingIndicator(context, controller, theme);
    } else if (subtitleView != null) {
      subtitle =
          subtitleView!(controller.groupObject, controller.userObject, context);
    } else if (controller.userObject != null) {
      subtitle = Text(
        controller.userObject?.status ?? "",
        style: TextStyle(
          color: controller.userObject?.status == UserStatusConstants.online
              ? theme.palette.getPrimary()
              : theme.palette.getAccent600(),
          fontSize: theme.typography.subtitle2.fontSize,
          fontFamily: theme.typography.subtitle2.fontFamily,
          fontWeight: theme.typography.subtitle2.fontWeight,
        ).merge(messageHeaderStyle.subtitleTextStyle),
      );
    } else {
      subtitle = Text(
        '${controller.membersCount ?? 0} ${cc.Translations.of(context).members}',
        style: TextStyle(
          color: controller.userObject?.status == UserStatusConstants.online
              ? theme.palette.getPrimary()
              : theme.palette.getAccent600(),
          fontSize: theme.typography.subtitle2.fontSize,
          fontFamily: theme.typography.subtitle2.fontFamily,
          fontWeight: theme.typography.subtitle2.fontWeight,
        ).merge(messageHeaderStyle.subtitleTextStyle),
      );
    }
    return subtitle;
  }

  _getBody(CometChatMessageHeaderController controller, BuildContext context,
      CometChatTheme theme) {
    return GetBuilder(
        init: controller,
        tag: controller.tag,
        dispose: (GetBuilderState<CometChatMessageHeaderController> state) =>
            Get.delete<CometChatMessageHeaderController>(
                tag: state.controller?.tag),
        builder: (CometChatMessageHeaderController value) {
          return _getListItem(value, theme, context);
        });
  }

  Widget _getListItem(CometChatMessageHeaderController controller,
      CometChatTheme theme, BuildContext context) {
    if (listItemView != null) {
      return listItemView!(group, user, context);
    }

    String? avatarName;
    String? avatarUrl;
    String? title;
    Widget? subtitleView;
    Color? statusIndicatorColor;
    Widget? icon;
    Widget? tailView;

    if (user != null) {
      avatarName = controller.userObject?.name;
      avatarUrl = controller.userObject?.avatar;
      title = controller.userObject?.name;
    } else {
      avatarName = controller.groupObject?.name;
      avatarUrl = controller.groupObject?.icon;
      title = controller.groupObject?.name;
    }
    StatusIndicatorUtils util =
        StatusIndicatorUtils.getStatusIndicatorFromParams(
            theme: theme,
            user: controller.userObject,
            group: controller.groupObject,
            privateGroupIcon: privateGroupIcon,
            protectedGroupIcon: protectedGroupIcon,
            onlineStatusIndicatorColor: messageHeaderStyle.onlineStatusColor);

    statusIndicatorColor = util.statusIndicatorColor;
    icon = util.icon;
    subtitleView = _getSubtitleView(context, controller, theme);
    List<Widget>? tailWidgetList = [];
    if (appBarOptions != null) {
      var temp = appBarOptions!(
          controller.userObject, controller.groupObject, context);

      if (temp != null) {
        tailWidgetList.addAll(temp);
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

    if (tailWidgetList.isNotEmpty) {
      tailView = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: tailWidgetList,
      );
    }

    return GestureDetector(
      onTap: () {},
      child: CometChatListItem(
        avatarName: avatarName,
        avatarURL: avatarUrl,
        title: title,
        subtitleView: subtitleView,
        avatarStyle: avatarStyle ?? const AvatarStyle(),
        statusIndicatorColor: statusIndicatorColor,
        statusIndicatorIcon: icon,
        statusIndicatorStyle:
            statusIndicatorStyle ?? const StatusIndicatorStyle(),
        theme: theme,
        hideSeparator: true,
        tailView: tailView,
        style: listItemStyle ??
            ListItemStyle(
                background: Colors.transparent,
                height: 56,
                titleStyle: TextStyle(
                    fontSize: theme.typography.name.fontSize,
                    fontWeight: theme.typography.name.fontWeight,
                    fontFamily: theme.typography.name.fontFamily,
                    color: theme.palette.getAccent())),
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
