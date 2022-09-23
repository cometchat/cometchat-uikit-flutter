import 'package:flutter/material.dart';

import '../../../flutter_chat_ui_kit.dart';

class CometChatDataItem<T> extends StatelessWidget {
  const CometChatDataItem(
      {Key? key,
      required this.inputData,
      this.isActive,
      this.style = const DataItemStyle(),
      this.options = const [],
      this.avatarConfiguration = const AvatarConfiguration(),
      this.statusIndicatorConfiguration = const StatusIndicatorConfiguration(),
      this.theme,
      this.user,
      this.group,
      this.groupMember})
      : assert(user != null || group != null || groupMember != null),
        super(key: key);

  ///[inputData] details to be show in listItem
  final InputData<T> inputData;

  ///[isActive] user is offline or online
  final bool? isActive;

  ///[style] style for DataItem
  final DataItemStyle style;

  ///[options] list of userOptions to show like voice call,video call,info
  final List<Widget> options;

  ///[avatarConfigurations]
  final AvatarConfiguration avatarConfiguration;

  ///[statusIndicatorConfiguration]
  final StatusIndicatorConfiguration statusIndicatorConfiguration;

  ///[theme] can pass custom theme class or dark theme defaultDarkTheme object from CometChatTheme class, by default light theme
  final CometChatTheme? theme;

  final User? user;

  final Group? group;

  final GroupMember? groupMember;

  Widget getAvatar(CometChatTheme _theme) {
    if (inputData.thumbnail) {
      String? _image;
      String? _name;
      if (user != null) {
        _image = user!.avatar;
        _name = user!.name;
      } else if (group != null) {
        _image = group!.icon;
        _name = group!.name;
      } else if (groupMember != null) {
        _image = groupMember!.avatar;
        _name = groupMember!.name;
      }

      return CometChatAvatar(
        image: _image,
        name: _name,
        width: avatarConfiguration.width,
        height: avatarConfiguration.height,
        backgroundColor: avatarConfiguration.backgroundColor ??
            _theme.palette.getAccent700(),
        cornerRadius: avatarConfiguration.cornerRadius,
        outerCornerRadius: avatarConfiguration.outerCornerRadius,
        border: avatarConfiguration.border,
        outerViewBackgroundColor: avatarConfiguration.outerViewBackgroundColor,
        nameTextStyle: avatarConfiguration.nameTextStyle ??
            TextStyle(
                color: _theme.palette.getBackground(),
                fontSize: _theme.typography.name.fontSize,
                fontWeight: _theme.typography.name.fontWeight,
                fontFamily: _theme.typography.name.fontFamily),
        outerViewBorder: avatarConfiguration.outerViewBorder,
        outerViewSpacing: avatarConfiguration.outerViewSpacing,
        outerViewWidth: avatarConfiguration.outerViewWidth,
      );
    } else {
      return const SizedBox();
    }
  }

  Widget getStatus(CometChatTheme _theme) {
    if (inputData.status) {
      Color? backgroundColor;
      Icon? icon;
      if (user != null) {
        backgroundColor =
            user!.status != null && user!.status == UserStatusConstants.online
                ? _theme.palette.getSuccess()
                : null;
      } else if (group != null) {
        if (group!.type == GroupTypeConstants.password) {
          backgroundColor = const Color(0xffF7A500);
          icon = const Icon(
            Icons.lock,
            color: Colors.white,
            size: 7,
          );
        } else if (group!.type == GroupTypeConstants.private) {
          backgroundColor = _theme.palette.getSuccess();
          icon = const Icon(Icons.privacy_tip_rounded,
              color: Colors.white, size: 7);
        }
      } else if (groupMember != null) {
        backgroundColor = groupMember!.status != null &&
                groupMember!.status == UserStatusConstants.online
            ? _theme.palette.getSuccess()
            : null;
      }

      return CometChatStatusIndicator(
        backgroundColor: backgroundColor,
        icon: icon,
        border: statusIndicatorConfiguration.border,
        cornerRadius: statusIndicatorConfiguration.cornerRadius,
        height: statusIndicatorConfiguration.height,
        width: statusIndicatorConfiguration.width,
      );
    } else {
      return const SizedBox();
    }
  }

  Widget? getTitle(CometChatTheme _theme) {
    if (inputData.title) {
      String _title = '';
      if (user != null) {
        _title = user!.name;
      } else if (group != null) {
        _title = group!.name;
      } else if (groupMember != null) {
        _title = groupMember!.name;
      }

      return Text(
        _title,
        style: style.titleStyle ??
            TextStyle(
                color: _theme.palette.getAccent(),
                fontWeight: _theme.typography.name.fontWeight,
                fontSize: _theme.typography.name.fontSize,
                fontFamily: _theme.typography.name.fontFamily),
      );
    } else {
      return const SizedBox();
    }
  }

  Widget? getSubtitle(CometChatTheme _theme) {
    var _object;
    if (user != null) {
      _object = user;
    } else if (group != null) {
      _object = group;
    } else if (groupMember != null) {
      _object = groupMember;
    }

    if (inputData.subtitle != null) {
      String? _subtitle = inputData.subtitle!(_object);
      if (_subtitle != null) {
        return Text(
          _subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style.subtitleStyle ??
              TextStyle(
                  color: _theme.palette.getAccent600(),
                  fontSize: _theme.typography.subtitle1.fontSize,
                  fontWeight: _theme.typography.subtitle1.fontWeight,
                  fontFamily: _theme.typography.subtitle1.fontFamily),
        );
      } else {
        return null;
      }
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    CometChatTheme _theme = theme ?? cometChatTheme;

    return Container(
      alignment: Alignment.center,
      height: style.height ?? 65,
      width: style.width ?? MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
          color: style.background ?? _theme.palette.getBackground(),
          gradient: style.gradient,
          border: style.border,
          borderRadius: BorderRadius.circular(style.cornerRadius ?? 0)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(0),
        minVerticalPadding: 0,
        dense: true,
        minLeadingWidth: avatarConfiguration.width,
        leading: inputData.thumbnail
            ? Stack(
                children: [
                  getAvatar(_theme),
                  if (inputData.status)
                    Positioned(
                      height: statusIndicatorConfiguration.height ?? 14,
                      width: statusIndicatorConfiguration.width ?? 14,
                      right: 0,
                      bottom: 0,
                      child: getStatus(_theme),
                    )
                ],
              )
            : null,
        title: getTitle(
          _theme,
        ),
        subtitle: getSubtitle(_theme),
        trailing: SizedBox(
          width: options.length * 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: options,
          ),
        ),
      ),
    );
  }
}

class DataItemStyle {
  ///class for the List Item style
  const DataItemStyle(
      {this.height,
      this.width,
      this.background,
      this.border,
      this.cornerRadius,
      this.titleStyle,
      this.subtitleStyle,
      this.gradient});

  ///[height] height of list item
  final double? height;

  ///[width] width of list item
  final double? width;

  ///[background] background color of list item
  final Color? background;

  ///[border] border of list item
  final BoxBorder? border;

  ///[cornerRadius] radius
  final double? cornerRadius;

  ///[titleStyle] TextStyle for List item title
  final TextStyle? titleStyle;

  ///[subtitleStyle] subtitle TextStyle
  final TextStyle? subtitleStyle;

  final Gradient? gradient;
}
