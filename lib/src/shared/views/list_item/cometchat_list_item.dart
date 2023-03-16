import 'package:flutter/material.dart';
import 'package:flutter_chat_ui_kit/flutter_chat_ui_kit.dart';

class CometChatListItem extends StatelessWidget {
  const CometChatListItem({
    Key? key,
    this.avatarURL,
    this.avatarName,
    this.statusIndicatorColor,
    this.statusIndicatorIcon,
    this.title,
    this.subtitleView,
    this.options,
    this.tailView,
    this.hideSeparator = true,
    this.avatarStyle = const AvatarStyle(),
    this.statusIndicatorStyle = const StatusIndicatorStyle(),
    this.style = const ListItemStyle(),
    this.theme,
    this.id,
  })  : assert(avatarURL != null || avatarName != null),
        super(key: key);

  ///[avatarURL] sets image url to be shown in avatar
  final String? avatarURL;

  ///[avatarName] sets name  to be shown in avatar if avatarURL is not available
  final String? avatarName;

  ///[statusIndicatorColor] toggle visibility for status indicator
  final Color? statusIndicatorColor;

  ///[statusIndicatorIcon] sets status
  final Widget? statusIndicatorIcon;

  ///[title] sets title
  final String? title;

  ///[subtitleView] gives subtitle view
  final Widget? subtitleView;

  ///[options] set options for
  final List<CometChatOption>? options;

  ///[tailView] sets tail
  final Widget? tailView;

  ///[hideSeparator] toggle separator visibility
  final bool? hideSeparator;

  ///[style] style for DataItem
  final ListItemStyle style;

  final AvatarStyle avatarStyle;

  final StatusIndicatorStyle statusIndicatorStyle;

  ///[theme] can pass custom theme class or dark theme defaultDarkTheme object from CometChatTheme class, by default light theme
  final CometChatTheme? theme;

  ///[id] for list item
  final String? id;

  Widget getAvatar(CometChatTheme _theme) {
    return CometChatAvatar(
      image: avatarURL,
      name: avatarName,
      style: AvatarStyle(
        width: avatarStyle.width,
        height: avatarStyle.height,
        background: avatarStyle.background ?? _theme.palette.getAccent700(),
        borderRadius: avatarStyle.borderRadius,
        outerBorderRadius: avatarStyle.outerBorderRadius,
        border: avatarStyle.border,
        outerViewBackgroundColor: avatarStyle.outerViewBackgroundColor,
        nameTextStyle: avatarStyle.nameTextStyle ??
            TextStyle(
                color: _theme.palette.getBackground(),
                fontSize: _theme.typography.name.fontSize,
                fontWeight: _theme.typography.name.fontWeight,
                fontFamily: _theme.typography.name.fontFamily),
        outerViewBorder: avatarStyle.outerViewBorder,
        outerViewSpacing: avatarStyle.outerViewSpacing,
        outerViewWidth: avatarStyle.outerViewWidth,
      ),
    );
  }

  Widget getStatus(CometChatTheme _theme) {
    return CometChatStatusIndicator(
      backgroundImage: statusIndicatorIcon,
      backgroundColor: statusIndicatorColor,
      style: StatusIndicatorStyle(
          border: statusIndicatorStyle.border,
          borderRadius: statusIndicatorStyle.borderRadius,
          height: statusIndicatorStyle.height,
          width: statusIndicatorStyle.width,
          gradient: statusIndicatorStyle.gradient),
    );
  }

  Widget? getTitle(CometChatTheme _theme) {
    return Text(
      title ?? "",
      style: style.titleStyle ??
          TextStyle(
              color: _theme.palette.getAccent(),
              fontWeight: _theme.typography.name.fontWeight,
              fontSize: _theme.typography.name.fontSize,
              fontFamily: _theme.typography.name.fontFamily),
    );
  }

  Widget? getSubtitle(CometChatTheme _theme) {
    return subtitleView;
  }

  @override
  Widget build(BuildContext context) {
    CometChatTheme _theme = theme ?? cometChatTheme;
    return SwipeTile(
        menuItems: options ?? [],
        key: UniqueKey(),
        id: id,
        child: Container(
            alignment: Alignment.center,
            height: style.height ?? 73,
            width: style.width,
            decoration: BoxDecoration(
                color: style.gradient==null? style.background ?? _theme.palette.getBackground():null,
                gradient: style.gradient,
                border: style.border,
                borderRadius: BorderRadius.circular(style.borderRadius ?? 0)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Flexible(
                  flex: (style.height?.toInt() ?? 72) - 1,
                  child: ListTile(
                      contentPadding: const EdgeInsets.all(0),
                      minVerticalPadding: 0,
                      dense: true,
                      minLeadingWidth: avatarStyle.width,
                      leading: Stack(
                        children: [
                          getAvatar(_theme),
                          if (statusIndicatorColor != null ||
                              statusIndicatorIcon != null)
                            Positioned(
                              height: statusIndicatorStyle.height ?? 14,
                              width: statusIndicatorStyle.width ?? 14,
                              right: 0,
                              bottom: 0,
                              child: getStatus(_theme),
                            )
                        ],
                      ),
                      title: getTitle(
                        _theme,
                      ),
                      subtitle: getSubtitle(_theme),
                      trailing: tailView),
                ),
                if (hideSeparator == false)
                  Flexible(
                    child: Divider(
                      thickness: 1,
                      indent: avatarStyle.width ?? 40,
                      height: 1,
                    ),
                  )
              ],
            )));
  }
}
