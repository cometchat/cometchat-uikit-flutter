// import 'package:flutter/material.dart';
//
// import '../../../../flutter_chat_ui_kit.dart';
//
// enum Data { uid, avatar, status, name, subtitle }
// enum UserOptions { voiceCall, videoCall, info, customOption }
//
// /// Creates a widget that that gives CometChat List Item
// class CometChatUserListItem extends StatelessWidget {
//   const CometChatUserListItem(
//       {Key? key,
//       required this.isActive,
//       this.userOptions = const [],
//       required this.userObject,
//       this.style,
//       this.avatarConfiguration = const AvatarConfiguration(),
//       this.statusIndicatorConfiguration = const StatusIndicatorConfiguration(),
//       required this.inputData,
//       this.theme})
//       : super(key: key);
//
//   ///[inputData] details to be show in listItem
//   final Map<String, dynamic> inputData;
//
//   ///[isActive] user is offline or online
//   final bool isActive;
//
//   ///[style] user list item style
//   final UserListItemStyle? style;
//
//   ///[userOptions] list of userOptions to show like voice call,video call,info
//   final List<Widget> userOptions;
//
//   ///[avatarConfigurations]
//   final AvatarConfiguration avatarConfiguration;
//
//   ///[statusIndicatorConfiguration]
//   final StatusIndicatorConfiguration statusIndicatorConfiguration;
//
//   ///[theme] can pass custom theme class or dark theme defaultDarkTheme object from CometChatTheme class, by default light theme
//   final CometChatTheme? theme;
//
//   ///[userObject] CometChat User object
//   final User userObject;
//
//   Widget getAvatar(CometChatTheme _theme, Map<String, dynamic> userObjectMap) {
//     if (inputData.containsKey("thumbnail")) {
//       return CometChatAvatar(
//         image: inputData["thumbnail"] == 'avatar' ? userObject.avatar : '',
//         name: userObject.name,
//         width: avatarConfiguration.width,
//         height: avatarConfiguration.height,
//         backgroundColor: avatarConfiguration.backgroundColor ??
//             _theme.palette.getAccent700(),
//         cornerRadius: avatarConfiguration.cornerRadius,
//         outerCornerRadius: avatarConfiguration.outerCornerRadius,
//         border: avatarConfiguration.border,
//         outerViewBackgroundColor: avatarConfiguration.outerViewBackgroundColor,
//         nameTextStyle: avatarConfiguration.nameTextStyle ??
//             TextStyle(
//                 color: _theme.palette.getBackground(),
//                 fontSize: _theme.typography.name.fontSize,
//                 fontWeight: _theme.typography.name.fontWeight,
//                 fontFamily: _theme.typography.name.fontFamily),
//         outerViewBorder: avatarConfiguration.outerViewBorder,
//         outerViewSpacing: avatarConfiguration.outerViewSpacing,
//         outerViewWidth: avatarConfiguration.outerViewWidth,
//       );
//     } else {
//       return const SizedBox();
//     }
//   }
//
//   Widget getStatus(CometChatTheme _theme) {
//     if (inputData.containsKey("status") && inputData["status"] == "status") {
//       return CometChatUserPresence(
//         backgroundColor: isActive ? _theme.palette.getPrimary() : null,
//         // icon: ,
//         border: statusIndicatorConfiguration.border,
//         cornerRadius: statusIndicatorConfiguration.cornerRadius,
//         height: statusIndicatorConfiguration.height,
//         width: statusIndicatorConfiguration.width,
//       );
//     } else {
//       return const SizedBox();
//     }
//   }
//
//   Widget getTitle(
//       Map<String, dynamic> userObjectMap,
//       Map<String, dynamic> metadata,
//       CometChatTheme _theme,
//       UserListItemStyle _style) {
//     String _title;
//     if (userObjectMap.containsKey(inputData["title"])) {
//       _title = userObjectMap[inputData["title"]];
//     } else if (metadata.containsKey(inputData["title"])) {
//       _title = metadata[inputData["title"]];
//     } else {
//       return const SizedBox();
//     }
//
//     return Text(
//       _title,
//       style: _style.titleStyle ??
//           TextStyle(
//               color: _theme.palette.getAccent(),
//               fontWeight: _theme.typography.name.fontWeight,
//               fontSize: _theme.typography.name.fontSize,
//               fontFamily: _theme.typography.name.fontFamily),
//     );
//   }
//
//   Widget getSubtitle(
//       Map<String, dynamic> userObjectMap,
//       Map<String, dynamic> metadata,
//       CometChatTheme _theme,
//       UserListItemStyle _style) {
//     String _subtitle;
//     if (userObjectMap.containsKey(inputData["subtitle"])) {
//       _subtitle = userObjectMap[inputData["subtitle"]].toString();
//     } else if (metadata.containsKey(inputData["subtitle"])) {
//       _subtitle = metadata[inputData["subtitle"]].toString();
//     } else {
//       return const SizedBox();
//     }
//
//     return Text(
//       _subtitle,
//       maxLines: 1,
//       overflow: TextOverflow.ellipsis,
//       style: _style.subtitleStyle ??
//           TextStyle(
//               color: _theme.palette.getAccent600(),
//               fontSize: _theme.typography.subtitle1.fontSize,
//               fontWeight: _theme.typography.subtitle1.fontWeight,
//               fontFamily: _theme.typography.subtitle1.fontFamily),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     Map<String, dynamic> userObjectMap = userObject.toMap();
//     Map<String, dynamic> metadata = userObjectMap['metadata'];
//
//     CometChatTheme _theme = theme ?? cometChatTheme;
//
//     UserListItemStyle _style = style ?? const UserListItemStyle();
//
//     return Container(
//       alignment: Alignment.center,
//       height: _style.height ?? 65,
//       width: _style.width ?? MediaQuery.of(context).size.width,
//       decoration: BoxDecoration(
//           color: _style.background ?? _theme.palette.getBackground(),
//           border: _style.border,
//           borderRadius: BorderRadius.circular(_style.cornerRadius ?? 0)),
//       child: ListTile(
//         contentPadding: const EdgeInsets.all(0),
//         minVerticalPadding: 0,
//         dense: true,
//         minLeadingWidth: avatarConfiguration.width,
//         leading: inputData.containsKey("thumbnail")
//             ? Stack(
//                 children: [
//                   getAvatar(_theme, userObjectMap),
//                   if (inputData.containsKey("status"))
//                     Positioned(
//                       height: 12,
//                       width: 12,
//                       right: 1,
//                       bottom: 1,
//                       child: getStatus(_theme),
//                     )
//                 ],
//               )
//             : null,
//         title: inputData.containsKey("title")
//             ? getTitle(userObjectMap, metadata, _theme, _style)
//             : null,
//         subtitle: inputData.containsKey("subtitle")
//             ? getSubtitle(userObjectMap, metadata, _theme, _style)
//             : null,
//         trailing: SizedBox(
//           width: userOptions.length * 40,
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: userOptions,
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class UserListItemStyle {
//   ///class for the List Item style
//   const UserListItemStyle(
//       {this.height,
//       this.width,
//       this.background,
//       this.border,
//       this.cornerRadius,
//       this.titleStyle,
//       this.subtitleStyle});
//
//   ///[height] height of list item
//   final double? height;
//
//   ///[width] width of list item
//   final double? width;
//
//   ///[background] background color of list item
//   final Color? background;
//
//   ///[border] border of list item
//   final BoxBorder? border;
//
//   ///[cornerRadius] radius
//   final double? cornerRadius;
//
//   ///[titleStyle] TextStyle for List item title
//   final TextStyle? titleStyle;
//
//   ///[subtitleStyle] subtitle TextStyle
//   final TextStyle? subtitleStyle;
// }
